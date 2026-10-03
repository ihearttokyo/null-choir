"""Real owned Mac workers and private pipes; no engine or hosted network."""
import importlib.util
import json
import multiprocessing
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools import playtest_supervisor as s

spec = importlib.util.spec_from_file_location('protocol_fixtures', ROOT / 'tests/test_playtest_protocol.py')
fixtures = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixtures)


def successful_worker(value):
    print('synthetic credential must not be public output')
    return value


def broken_worker(value):
    raise RuntimeError('Bearer synthetic credential must not be public error')


def hanging_worker(pidfile):
    descendant = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(30)'])
    Path(pidfile).write_text(json.dumps({'worker': os.getpid(), 'descendant': descendant.pid}))
    time.sleep(30)


def marker_worker(path):
    Path(path).write_text('worker actually executed')
    return {'fixture': 1}


def descendant_worker(pidfile, fail):
    descendant = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(30)'])
    ids = {'worker': os.getpid(), 'descendant': descendant.pid}
    Path(pidfile).write_text(json.dumps(ids))
    if fail:
        raise RuntimeError('synthetic sensitive details')
    return ids


def simulated_reply(controller, payload, ticket, credential, epoch_offset):
    assert controller.pending == ticket and controller.attempts == 1
    assert controller.budget_verified
    assert payload['model'] == 'jev-1.13.0'
    assert credential == 'synthetic-not-real'
    return {'model': 'jev-1.13.0', 'answers': {'action': {'type': 'choice',
            'choice': 'wait', 'probabilities': {name: int(name == 'wait') for name in s.protocol.ACTIONS}, 'confidence': 1}},
            'usage': {'input_tokens': 100, 'output_tokens': 10}}


def stalled_decision_worker(controller, payload, ticket, credential, epoch_offset):
    time.sleep(30)


class SupervisorTests(unittest.TestCase):
    def test_worker_clock_translates_real_elapsed_time_into_logical_epoch(self):
        controller=s.protocol.Controller(9000,setup_fee_usd='0',pricing_verified=True,account_active=True)
        ticket,payload=controller.begin(fixtures.observation(),9000)
        offset=9000-time.monotonic()
        def exchange(received_controller,received_payload,received_ticket,credential,clock):
            self.assertIs(received_controller,controller)
            self.assertIs(received_ticket,ticket)
            self.assertIs(received_payload,payload)
            before=clock()
            time.sleep(0.01)
            after=clock()
            self.assertGreaterEqual(before,9000)
            self.assertGreater(after,before)
            self.assertLess(after,ticket.expires_at)
            controller._clock(after)
            return fixtures.reply('wait')
        with patch.object(s.transport,'_exchange',side_effect=exchange):
            result=s._http_worker(controller,payload,ticket,'synthetic-not-real',offset)
        self.assertEqual(result['model'],s.protocol.MODEL)

    def test_frozen_injected_clock_cannot_extend_real_owned_worker_deadline(self):
        controller=s.protocol.Controller(9000,setup_fee_usd='0',pricing_verified=True,account_active=True)
        started=time.monotonic()
        with patch.object(s.transport,'LIVE_TEST_ENABLED',True), \
             patch.object(s,'_http_worker',stalled_decision_worker), self.assertRaises(s.WorkerError):
            s.decide(controller,fixtures.observation(),credential='synthetic-not-real',
                     observe=fixtures.observation,clock=lambda:9000)
        self.assertLess(time.monotonic()-started,3)
        self.assertEqual(controller.attempts,1)
        self.assertEqual(str(controller.reserved_usd),'0.002688')
        self.assertTrue(controller.stopped)
        self.assertIsNone(controller.pending)

    def test_regressing_injected_clock_rejects_before_launch_without_refund(self):
        controller=s.protocol.Controller(9000,setup_fee_usd='0',pricing_verified=True,account_active=True)
        times=iter((9000,8999))
        with patch.object(s.transport,'LIVE_TEST_ENABLED',True), \
             patch.object(s,'_run_owned_worker') as worker, self.assertRaises(s.WorkerError):
            s.decide(controller,fixtures.observation(),credential='synthetic-not-real',
                     observe=fixtures.observation,clock=lambda:next(times))
        worker.assert_not_called()
        self.assertEqual(controller.attempts,1)
        self.assertEqual(str(controller.reserved_usd),'0.002688')
        self.assertTrue(controller.stopped)

    def test_target_does_not_run_without_parent_acknowledgment(self):
        with tempfile.TemporaryDirectory(prefix='null-choir-worker-ack-', dir='/private/tmp') as temp:
            marker = Path(temp)/'started'
            ctx = multiprocessing.get_context('spawn')
            receiver, sender = ctx.Pipe(duplex=True)
            process = ctx.Process(target=s._child_main, args=(sender, marker_worker, (str(marker),)))
            process.start()
            sender.close()
            try:
                self.assertTrue(receiver.poll(2))
                self.assertEqual(json.loads(receiver.recv_bytes(s.MAX_FRAME_BYTES)), {'ready': True})
                self.assertFalse(receiver.poll(0.1), 'Worker ran before parent accepted session ownership')
                self.assertFalse(marker.exists())
            finally:
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                process.join()
                process.close()
                receiver.close()

    def test_private_success_and_failures(self):
        self.assertEqual(s._run_owned_worker(successful_worker, ({'fixture': 1},), 2), {'fixture': 1})
        for worker, value in ((broken_worker, {}), (successful_worker, {'large': 'x'*40000})):
            with self.assertRaises(s.WorkerError) as caught:
                s._run_owned_worker(worker, (value,), 2)
            self.assertNotIn('synthetic credential', str(caught.exception))

    def test_timeout_owns_and_reaps_worker_and_descendant(self):
        with tempfile.TemporaryDirectory(prefix='null-choir-worker-', dir='/private/tmp') as temp:
            pidfile = Path(temp)/'owned-pids.json'
            started = time.monotonic()
            with self.assertRaises(s.WorkerError):
                s._run_owned_worker(hanging_worker, (str(pidfile),), 0.5)
            self.assertLess(time.monotonic()-started, 3)
            self.assertTrue(pidfile.exists(), 'OS Python worker must actually run before timeout')
            ids = json.loads(pidfile.read_text())
            for pid in ids.values():
                row = subprocess.run(['ps', '-p', str(pid), '-o', 'stat='], text=True, capture_output=True)
                self.assertTrue(row.returncode != 0 or row.stdout.strip().startswith('Z'), 'Owned live descendant survived timeout')

    def test_success_and_failure_also_close_owned_descendants(self):
        with tempfile.TemporaryDirectory(prefix='null-choir-worker-outcomes-', dir='/private/tmp') as temp:
            for fail in (False, True):
                pidfile = Path(temp)/str(fail)
                if fail:
                    with self.assertRaises(s.WorkerError):
                        s._run_owned_worker(descendant_worker, (str(pidfile), fail), 2)
                else:
                    result = s._run_owned_worker(descendant_worker, (str(pidfile), fail), 2)
                    self.assertEqual(result, json.loads(pidfile.read_text()))
                for pid in json.loads(pidfile.read_text()).values():
                    row = subprocess.run(['ps', '-p', str(pid), '-o', 'stat='], text=True, capture_output=True)
                    self.assertTrue(row.returncode != 0 or row.stdout.strip().startswith('Z'))

    def test_limits_and_production_activation_hold(self):
        for timeout in (0, -1, float('nan'), float('inf'), 121):
            with self.assertRaises(s.WorkerError):
                s._run_owned_worker(successful_worker, ({},), timeout)
        controller = s.protocol.Controller(time.monotonic(), setup_fee_usd='0', pricing_verified=True, account_active=True)
        with patch.object(s, '_run_owned_worker') as launch, self.assertRaises(s.WorkerError):
            s.decide(controller, fixtures.observation(), credential='synthetic-not-real', observe=fixtures.observation)
        launch.assert_not_called()
        self.assertTrue(controller.stopped)
        self.assertEqual(controller.attempts, 0)

    def test_parent_reserves_once_and_revalidates_scene(self):
        controller = s.protocol.Controller(time.monotonic(), setup_fee_usd='0', pricing_verified=True, account_active=True)
        # Local boundary response avoids flaky cold-spawn latency in this decision identity test.
        def local(worker, args, timeout):
            self.assertGreater(timeout, 0)
            self.assertLessEqual(timeout, 0.2)
            return simulated_reply(*args)
        with patch.object(s.transport, 'LIVE_TEST_ENABLED', True), patch.object(s, '_run_owned_worker', side_effect=local):
            result = s.decide(controller, fixtures.observation(), credential='synthetic-not-real', observe=fixtures.observation)
        self.assertEqual(result['plan']['action'], 'wait')
        self.assertEqual(controller.attempts, 1)
        self.assertEqual(str(controller.reserved_usd), '0.002688')
        controller = s.protocol.Controller(time.monotonic(), setup_fee_usd='0', pricing_verified=True, account_active=True)
        with patch.object(s.transport, 'LIVE_TEST_ENABLED', True), patch.object(s, '_run_owned_worker', side_effect=local), self.assertRaises(s.WorkerError):
            s.decide(controller, fixtures.observation(), credential='synthetic-not-real',
                     observe=lambda: fixtures.observation(phase='menu', player_id=0, level_id=0))
        self.assertTrue(controller.stopped)
        self.assertFalse(controller.held)
        self.assertEqual(controller.attempts, 1)


if __name__ == '__main__':
    unittest.main()
