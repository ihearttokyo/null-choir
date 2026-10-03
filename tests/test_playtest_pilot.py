"""Real private files; synthetic native peer/provider/clock. No engine or HTTP."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from tools import playtest_pilot as pilot
from tools import playtest_protocol as p
from tools import playtest_bridge as wire
from tools import playtest_mailbox as ipc
from tools import playtest_supervisor as supervisor
from tests.test_playtest_protocol import observation, reply


class Clock:
    def __init__(self):
        self.now = 0
        self.peer = None

    def __call__(self):
        return self.now

    def sleep(self, seconds):
        self.now += seconds
        if self.peer:
            self.peer.step()


class Peer:
    """Only an offline receiver simulation; not an implemented native backend."""
    def __init__(self, root, clock):
        self.root, self.clock = root, clock
        self.receiver = wire.InputLease('run-01', 'a'*64, 9000)
        self.last_request = self.frame = 0
        self.commands = []
        self.change = {}
        self.drop = None
        self.drop_reply = None
        self.ack_change = {}

    def step(self):
        if not (self.root / 'request.json').exists():
            return
        packet = json.loads((self.root / 'request.json').read_text())
        if packet['request_id'] == self.last_request or packet['kind'] == self.drop:
            return
        self.last_request = packet['request_id']
        self.frame += 1
        state = observation(frame=self.frame, action_sequence=self.receiver.next_sequence, **self.change)
        self.receiver.tick(state, 9000+self.clock.now)
        state['action_sequence'] = self.receiver.next_sequence
        ok = True
        if packet['kind'] == 'observe':
            if not self.receiver.stopped:
                self.receiver.observe(state, 9000+self.clock.now)
            self.clock.now += 0.02  # Observation ages before the sidecar sees it.
        elif packet['kind'] == 'command':
            command = (self.root / 'request.bin').read_bytes()
            self.commands.append(json.loads(command))
            try:
                self.receiver.apply(command, state, 9000+self.clock.now)
            except ValueError:
                ok = False
        elif packet['kind'] == 'stop':
            self.receiver.stop()
            state['phase'] = 'stopped'
        if packet['kind'] == self.drop_reply:
            return  # Action may have happened; deliberately withhold its ACK.
        if self.receiver.next_sequence:
            state.update(self.ack_change)
        payload = wire.encode_observation(state, 9000+self.clock.now)
        response = {**packet, 'ok': ok, 'payload_bytes': len(payload),
                    'payload_sha256': hashlib.sha256(payload).hexdigest()}
        for name, data in (('response.bin', payload), ('response.json', json.dumps(response).encode())):
            path = self.root / name
            path.write_bytes(data)
            path.chmod(0o600)


class PilotTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix='null-choir-pilot-')
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name).resolve()/'run'
        self.clock = Clock()
        self.journal = p.Journal(self.root, 'run-01', 'a'*64, 0,
                                 max_bytes=p.MAX_BYTES-ipc.IPC_RESERVED_BYTES)
        self.addCleanup(self.journal.close)
        self.controller = p.Controller(0, setup_fee_usd='0', pricing_verified=True, account_active=True)
        self.pilot = pilot.Pilot(self.controller, self.journal, clock=self.clock, sleep=self.clock.sleep)
        self.peer = self.clock.peer = Peer(self.root, self.clock)

    def worker(self, worker, args, timeout):
        self.assertGreater(timeout, 0)
        controller, payload, ticket, credential = args
        self.assertEqual(controller.pending, ticket)
        self.assertEqual(payload['model'], p.MODEL)
        self.assertEqual(credential, 'synthetic-not-real')
        self.clock.now += 0.02
        return reply('move_forward', private='synthetic provider details')

    def run_one(self):
        # No HTTP path: only a synthetic reply boundary and local simulated peer.
        with patch.object(supervisor.transport, 'LIVE_TEST_ENABLED', True), \
             patch.object(supervisor.time, 'monotonic', self.clock), \
             patch.object(supervisor, '_run_owned_worker', side_effect=self.worker):
            return self.pilot.run_one(credential='synthetic-not-real')

    def rows(self):
        return [json.loads(line) for line in (self.root/'index.jsonl').read_text().splitlines()]

    def test_default_activation_hold_never_sends_request_or_launches_worker(self):
        with patch.object(supervisor, '_run_owned_worker') as worker, self.assertRaises(pilot.PilotError):
            self.pilot.run_one(credential='synthetic-not-real')
        worker.assert_not_called()
        self.assertFalse((self.root/'request.json').exists())
        self.assertEqual(self.controller.attempts, 0)
        self.assertTrue(self.pilot.stopped)

    def test_two_decisions_bind_original_frame_and_defer_early_native_ack(self):
        first = self.run_one()
        self.assertEqual(first['action'], 'move_forward')
        self.assertEqual(first['acknowledged_sequence'], 1)
        self.assertGreaterEqual(self.clock.now, 0.23-1e-9)
        self.assertFalse(self.controller.stopped)
        self.assertIsNone(self.controller.active_ticket)
        self.assertEqual(self.peer.commands[0]['frame'], 1)
        second = self.run_one()
        self.assertEqual(second['acknowledged_sequence'], 2)
        self.assertEqual(len(self.peer.commands), 2)
        self.assertEqual(self.controller.attempts, 2)
        self.assertEqual(str(self.controller.reserved_usd), '0.005376')
        text = (self.root/'index.jsonl').read_text()
        self.assertNotIn('synthetic-not-real', text)
        self.assertNotIn('synthetic provider details', text)
        attempts = [row for row in self.rows() if row['kind'] == 'command_attempt']
        self.assertEqual(len(attempts), 2)
        self.assertEqual(attempts[0]['issued_frame'], self.peer.commands[0]['frame'])
        self.assertEqual(attempts[0]['duration_seconds'], self.peer.commands[0]['duration_seconds'])

    def test_menu_during_fresh_snapshot_stops_without_input_commit(self):
        original = self.worker
        def menu(*args):
            result = original(*args)
            self.peer.change = {'phase': 'menu', 'player_id': 0, 'level_id': 0}
            return result
        with patch.object(supervisor.transport, 'LIVE_TEST_ENABLED', True), \
             patch.object(supervisor.time, 'monotonic', self.clock), \
             patch.object(supervisor, '_run_owned_worker', side_effect=menu), self.assertRaises(pilot.PilotError):
            self.pilot.run_one(credential='synthetic-not-real')
        self.assertEqual(self.peer.commands, [])
        self.assertTrue(self.pilot.stopped)
        self.assertTrue(self.journal.closed)
        self.assertEqual(self.controller.attempts, 1)

    def bad_ack(self, change):
        self.peer.ack_change = change
        with self.assertRaises(pilot.PilotError):
            self.run_one()
        self.assertTrue(self.controller.stopped)
        self.assertEqual(self.controller.attempts, 1)
        self.assertEqual(len(self.peer.commands), 1)

    def test_stale_player_at_ack_stops_without_next_decision(self):
        self.bad_ack({'player_id': 99})

    def test_future_sequence_at_ack_stops_without_next_decision(self):
        self.bad_ack({'action_sequence': 2})

    def test_missing_command_ack_keeps_reservation_and_never_retries(self):
        self.peer.drop = 'command'
        with self.assertRaises(pilot.PilotError):
            self.run_one()
        self.assertEqual(self.controller.attempts, 1)
        self.assertEqual(str(self.controller.reserved_usd), '0.002688')
        self.assertTrue(self.journal.closed)
        with self.assertRaises(pilot.PilotError):
            self.run_one()
        self.assertEqual(self.controller.attempts, 1)

    def test_explicit_stop_is_idempotent_and_records_local_stop(self):
        self.run_one()
        self.pilot.stop()
        request = (self.root/'request.json').read_bytes()
        self.pilot.stop()
        self.assertEqual((self.root/'request.json').read_bytes(), request)
        self.assertEqual(json.loads(request)['kind'], 'stop')
        self.assertTrue(self.controller.stopped)
        self.assertTrue(self.journal.closed)
        self.assertEqual(self.rows()[-1]['kind'], 'stop')

    def test_reentrant_decision_is_rejected_without_stopping_outer_action(self):
        original = self.worker
        def reentrant(*args):
            with self.assertRaises(pilot.PilotError):
                self.pilot.run_one(credential='synthetic-not-real')
            self.assertFalse(self.pilot.stopped)
            return original(*args)
        with patch.object(supervisor.transport, 'LIVE_TEST_ENABLED', True), \
             patch.object(supervisor.time, 'monotonic', self.clock), \
             patch.object(supervisor, '_run_owned_worker', side_effect=reentrant):
            self.assertEqual(self.pilot.run_one(credential='synthetic-not-real')['acknowledged_sequence'], 1)
        self.assertEqual(self.controller.attempts, 1)

    def test_attempt_cap_stops_before_any_new_native_request(self):
        self.controller.attempts = p.MAX_ATTEMPTS  # Synthetic counter boundary.
        with self.assertRaises(pilot.PilotError):
            self.run_one()
        self.assertFalse((self.root/'request.json').exists())
        self.assertEqual(self.controller.attempts, p.MAX_ATTEMPTS)

    def test_lost_ack_after_simulated_commit_does_not_repeat_action(self):
        self.peer.drop_reply = 'command'
        with self.assertRaises(pilot.PilotError):
            self.run_one()
        self.assertEqual(len(self.peer.commands), 1)
        self.assertEqual(self.controller.attempts, 1)
        self.assertEqual(str(self.controller.reserved_usd), '0.002688')
        with self.assertRaises(pilot.PilotError):
            self.run_one()
        self.assertEqual(len(self.peer.commands), 1)

    def test_regressed_frame_at_ack_stops(self):
        self.bad_ack({'frame': 1})

    def test_menu_on_early_ack_stops_before_controller_lease_ends(self):
        self.bad_ack({'phase': 'menu'})

    def test_provider_interrupt_keeps_reservation_closes_journal_and_drops_secrets(self):
        with patch.object(supervisor.transport, 'LIVE_TEST_ENABLED', True), \
             patch.object(supervisor.time, 'monotonic', self.clock), \
             patch.object(supervisor, '_run_owned_worker', side_effect=KeyboardInterrupt('private details')), \
             self.assertRaises(KeyboardInterrupt):
            self.pilot.run_one(credential='synthetic-not-real')
        self.assertTrue(self.pilot.stopped)
        self.assertTrue(self.journal.closed)
        self.assertEqual(self.controller.attempts, 1)
        self.assertNotIn('private details', (self.root/'index.jsonl').read_text())

    def test_late_provider_reply_never_publishes_command(self):
        original = self.worker
        def late(*args):
            result = original(*args)
            self.clock.now += p.LEASE_SECONDS
            return result
        with patch.object(supervisor.transport, 'LIVE_TEST_ENABLED', True), \
             patch.object(supervisor.time, 'monotonic', self.clock), \
             patch.object(supervisor, '_run_owned_worker', side_effect=late), self.assertRaises(pilot.PilotError):
            self.pilot.run_one(credential='synthetic-not-real')
        self.assertEqual(self.peer.commands, [])
        self.assertEqual(self.controller.attempts, 1)
        self.assertEqual(str(self.controller.reserved_usd), '0.002688')

    def test_pilot_time_cap_stops_before_native_or_provider_request(self):
        self.clock.now = p.MAX_SECONDS
        with self.assertRaises(pilot.PilotError):
            self.run_one()
        self.assertFalse((self.root/'request.json').exists())
        self.assertEqual(self.controller.attempts, 0)

    def test_dead_initial_observation_never_launches_provider(self):
        self.peer.change = {'phase': 'dead', 'health': 0}
        with patch.object(supervisor.transport, 'LIVE_TEST_ENABLED', True), \
             patch.object(supervisor.time, 'monotonic', self.clock), \
             patch.object(supervisor, '_run_owned_worker') as worker, self.assertRaises(pilot.PilotError):
            self.pilot.run_one(credential='synthetic-not-real')
        worker.assert_not_called()
        self.assertEqual(self.controller.attempts, 0)


if __name__ == '__main__':
    unittest.main()
