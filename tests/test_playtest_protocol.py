"""Offline protocol logic/filesystem tests; observations/replies/frames are simulated."""
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = Path(os.environ.get('PLAYTEST_TEST_TMPDIR', tempfile.gettempdir()))
spec = importlib.util.spec_from_file_location('playtest_protocol', ROOT / 'tools/playtest_protocol.py')
p = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)


def observation(**changes):
    value = {'run_id': 'run-01', 'build_sha256': 'a' * 64, 'level_id': 11,
             'player_id': 22, 'action_sequence': 0, 'frame': 8, 'phase': 'alive',
             'health': 73, 'armor': 21, 'ammo': [0, 37, 0, 0, 0, 0], 'weapon': 1,
             'pose': [1.5, 0, 2], 'yaw': 0, 'sensitivity': 1,
             'objective': 'Find the visible exit',
             'contacts': [{'visible': True, 'kind': 'enemy', 'distance': 8, 'bearing': 20}],
             'obstacles': [{'visible': True, 'kind': 'door', 'distance': 2, 'bearing': -5}]}
    value.update(changes)
    return value


def reply(choice='move_forward', **changes):
    value = {'model': 'jev-1.13.0', 'answers': {'action': {'type': 'choice',
             'choice': choice, 'probabilities': {name: int(name == choice) for name in p.ACTIONS}, 'confidence': 1}},
             'usage': {'input_tokens': 100, 'output_tokens': 10}}
    value.update(changes)
    return value


class ProtocolTests(unittest.TestCase):
    def test_official_choice_answer_map(self):
        # https://docs.typesafe.ai/api: answers is keyed by the request question ID.
        official = {'model': p.MODEL, 'answers': {'action': {
            'type': 'choice', 'choice': 'wait', 'confidence': 1,
            'probabilities': {name: int(name == 'wait') for name in p.ACTIONS}}},
            'usage': {'input_tokens': 512, 'output_tokens': 34}}
        self.assertEqual(p.reply_choice(official), 'wait')

    def test_legacy_answer_list_is_rejected(self):
        legacy = {'model': p.MODEL, 'answers': [{'question': 'action',
            'type': 'choice', 'choice': 'wait', 'confidence': 1,
            'probabilities': {'wait': 1}}],
            'usage': {'input_tokens': 100, 'output_tokens': 10}}
        with self.assertRaises(ValueError):
            p.reply_choice(legacy)

    def test_complete_choice_probabilities_are_required(self):
        for change in ('missing', 'extra', 'bad_total'):
            item = reply('wait')
            probabilities = item['answers']['action']['probabilities']
            if change == 'missing':
                probabilities.pop('fire')
            elif change == 'extra':
                probabilities['launch_browser'] = 0
            else:
                probabilities['wait'] = 0.5
            controller = p.Controller(0)
            ticket, _ = controller.begin(observation(), 0)
            with self.assertRaises(ValueError):
                controller.accept(ticket, item, observation(), 0.1)
            self.assertTrue(controller.stopped)
            self.assertEqual(set(controller.release_plan['release']), set(p.HELD_INPUTS))

    def test_request_privacy_and_nested_allowlist(self):
        state = observation(source='private code', path='/Users/private', screenshot='image',
                            hidden_map={'secret': 1}, account={'token': 'private'})
        state['contacts'][0].update(path='/Users/private', source='private code', hidden={'enemy': 9})
        state['contacts'].append({'visible': False, 'kind': 'enemy', 'distance': 2, 'bearing': 1})
        payload = p.build_request(state)
        encoded = json.dumps(payload)
        for forbidden in ('private', 'hidden', 'screenshot', 'run-01', 'a' * 64):
            self.assertNotIn(forbidden, encoded)
        self.assertEqual(payload['model'], p.MODEL)
        self.assertEqual(payload['questions']['action']['type'], 'choice')
        self.assertEqual(len(json.loads(payload['state'])['contacts']), 1)

    def test_invalid_state(self):
        for changes in ({'health': float('nan')}, {'pose': [1, 2, float('inf')]},
                        {'ammo': [1]}, {'weapon': True}, {'objective': '/Users/private'},
                        {'contacts': [{'visible': True, 'kind': 'enemy', 'distance': -1, 'bearing': 0}]},
                        {'source': 'x' * 40000}, {'phase': 'unknown'}):
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                p.build_request(observation(**changes))
        cyclic = observation()
        cyclic['hidden'] = cyclic
        with self.assertRaises(ValueError):
            p.build_request(cyclic)

    def test_objective_is_not_an_arbitrary_text_channel(self):
        for objective in ('skPrivate123', 'print health', 'Alice personal details'):
            with self.assertRaises(ValueError):
                p.build_request(observation(objective=objective))

    def test_only_alive_requests(self):
        for phase in ('menu', 'loading', 'title', 'dead', 'stopped'):
            with self.assertRaises(ValueError):
                p.Controller(0).begin(observation(phase=phase), 0)
        with self.assertRaises(ValueError):
            p.Controller(0).begin(observation(health=0), 0)

    def test_absent_scene_identity_in_nonplaying_observations(self):
        state = observation(phase='title', level_id=0, player_id=0)
        self.assertEqual(p.telemetry(state)['phase'], 'title')
        controller = p.Controller(0)
        ticket, _ = controller.begin(observation(), 0)
        controller.accept(ticket, reply('fire'), observation(), 0.01)
        self.assertIn('fire', controller.tick(state, 0.1)['release'])
        for changes in ({'level_id': 0}, {'player_id': 0}):
            with self.assertRaises(ValueError):
                p.Controller(0).begin(observation(**changes), 0)

    def test_single_inflight_normal_and_duplicate(self):
        controller = p.Controller(0)
        ticket, payload = controller.begin(observation(), 0)
        with self.assertRaises(ValueError):
            controller.begin(observation(), 0.01)
        plan = controller.accept(ticket, reply(), observation(), 0.05)
        self.assertEqual(plan['press'], ['move_forward'])
        self.assertLessEqual(plan['duration_seconds'], 0.15 + 1e-9)
        with self.assertRaises(ValueError):
            controller.accept(ticket, reply(), observation(), 0.06)
        self.assertTrue(controller.stopped)
        self.assertIn('move_forward', controller.release_plan['release'])

    def test_reentrant_attempt_observes_lifecycle_stop(self):
        for change in ({'phase': 'menu'}, {'health': 0}, {'level_id': 99}, {'action_sequence': 1}):
            controller = p.Controller(0)
            ticket, _ = controller.begin(observation(), 0)
            controller.accept(ticket, reply('fire'), observation(), 0.01)
            with self.assertRaises(ValueError):
                controller.begin(observation(**change), 0.1)
            self.assertTrue(controller.stopped)
            self.assertIn('fire', controller.release_plan['release'])

    def test_stale_identity_and_restart(self):
        for change in ({'run_id': 'run-02'}, {'build_sha256': 'b' * 64}, {'level_id': 12},
                       {'player_id': 23}, {'action_sequence': 1}, {'phase': 'loading'}, {'health': 0}):
            with self.subTest(change=change):
                controller = p.Controller(0)
                ticket, _ = controller.begin(observation(), 0)
                with self.assertRaises(ValueError):
                    controller.accept(ticket, reply(), observation(**change), 0.1)
                self.assertTrue(controller.stopped)
                self.assertEqual(set(controller.release_plan['release']), set(p.HELD_INPUTS))

    def test_invalid_reply_fail_closed(self):
        bad = [reply(model='other'), reply(choice='exec(code)'), reply(usage={'input_tokens': 64001, 'output_tokens': 0}),
               reply(answers={'other': reply()['answers']['action']}),
               reply(answers={'action': reply()['answers']['action'], 'other': reply()['answers']['action']})]
        for field, value in [('type', 'text'), ('confidence', float('nan')),
                             ('probabilities', {'move_forward': float('inf')})]:
            item = reply()
            item['answers']['action'][field] = value
            bad.append(item)
        for item in bad:
            controller = p.Controller(0)
            ticket, _ = controller.begin(observation(), 0)
            with self.assertRaises(ValueError):
                controller.accept(ticket, item, observation(), 0.1)
            self.assertTrue(controller.stopped)

    def test_expiration_pause_death_failure_stop_release(self):
        for reason in ('timeout', 'pause', 'death', 'failure', 'stop', 'stale'):
            controller = p.Controller(0)
            ticket, _ = controller.begin(observation(), 0)
            controller.accept(ticket, reply('fire'), observation(), 0.01)
            if reason == 'failure':
                controller.fail()
            elif reason == 'stop':
                controller.stop()
            else:
                changed = {'pause': {'phase': 'menu'}, 'death': {'health': 0},
                           'stale': {'player_id': 99}}.get(reason, {})
                controller.tick(observation(**changed), 0.2 if reason == 'timeout' else 0.1)
            self.assertIn('fire', controller.release_plan['release'])
            self.assertFalse(controller.held)
        controller = p.Controller(0)
        ticket, _ = controller.begin(observation(), 0)
        with self.assertRaises(ValueError):
            controller.accept(ticket, reply(), observation(), 0.2)

    def test_actions_duration_turn_and_interaction(self):
        for choice in p.ACTIONS:
            controller = p.Controller(0)
            ticket, _ = controller.begin(observation(sensitivity=0.1), 0)
            plan = controller.accept(ticket, reply(choice), observation(sensitivity=0.1), 0.1)
            self.assertLessEqual(plan['duration_seconds'], 0.2)
            self.assertLessEqual(abs(plan['yaw_degrees']), 15)
            self.assertTrue(set(plan['press']) <= set(p.HELD_INPUTS))
            if choice == 'turn_left':
                self.assertLess(plan['screen_relative_x'], 0)  # Player.look subtracts mouse delta.

    def test_pilot_attempt_time_and_no_retry_caps(self):
        controller = p.Controller(0)
        for index in range(240):
            state = observation(action_sequence=index)
            ticket, _ = controller.begin(state, index * 0.21)
            controller.accept(ticket, reply('wait'), state, index * 0.21 + 0.01)
            controller.tick(state, index * 0.21 + 0.2)
        self.assertEqual(controller.attempts, 240)
        with self.assertRaises(ValueError):
            controller.begin(observation(action_sequence=240), 51)
        with self.assertRaises(ValueError):
            p.Controller(0).begin(observation(), 120)
        controller = p.Controller(0)
        controller.begin(observation(), 0)
        controller.fail()
        self.assertEqual(controller.attempts, 1)
        with self.assertRaises(ValueError):
            controller.begin(observation(action_sequence=1), 0.1)

    def test_cost_reservation_and_gates(self):
        controller = p.Controller(0, setup_fee_usd='4.999', pricing_verified=True, account_active=True)
        with self.assertRaises(ValueError):
            controller.begin(observation(), 0)
        self.assertEqual(controller.attempts, 0)
        controller = p.Controller(0, setup_fee_usd='1.25', pricing_verified=True, account_active=True)
        controller.begin(observation(), 0)
        self.assertEqual(str(controller.reserved_usd), '1.252688')
        for changes in ({}, {'setup_fee_usd': '0'}, {'setup_fee_usd': '0', 'pricing_verified': True}):
            self.assertFalse(p.Controller(0, **changes).budget_verified)
        self.assertFalse(controller.paid_activation_allowed)
        for fee in ('NaN', '-1', '5.01'):
            with self.assertRaises(ValueError):
                p.Controller(0, setup_fee_usd=fee)

    def test_clock_and_sequence_do_not_regress(self):
        controller = p.Controller(1)
        with self.assertRaises(ValueError):
            controller.begin(observation(), 0.5)
        controller = p.Controller(0)
        ticket, _ = controller.begin(observation(), 0)
        controller.accept(ticket, reply('wait'), observation(), 0.01)
        controller.tick(observation(), 0.2)
        with self.assertRaises(ValueError):
            controller.begin(observation(), 0.21)

    def test_completed_bridge_acknowledgment_allows_next_decision(self):
        controller = p.Controller(0)
        state = observation()
        ticket, _ = controller.begin(state, 0)
        controller.accept(ticket, reply('fire'), state, 0.01)
        advanced = observation(action_sequence=1)
        released = controller.tick(advanced, 0.2)
        self.assertEqual(released['reason'], 'lease')
        self.assertFalse(controller.stopped)
        next_ticket, _ = controller.begin(advanced, 0.21)
        self.assertEqual(next_ticket.identity[-1], 1)
        self.assertEqual(controller.attempts, 2)

    def test_completed_ack_does_not_weaken_pending_early_or_stale_guards(self):
        for pending, now, change in ((True, 0.2, {'action_sequence': 1}),
                                    (False, 0.1, {'action_sequence': 1}),
                                    (False, 0.2, {'action_sequence': 2}),
                                    (False, 0.2, {'action_sequence': 1, 'player_id': 99}),
                                    (False, 0.2, {'action_sequence': 1, 'phase': 'menu'}),
                                    (False, 0.2, {'action_sequence': 1, 'health': 0})):
            with self.subTest(pending=pending, now=now, change=change):
                controller = p.Controller(0)
                ticket, _ = controller.begin(observation(), 0)
                if not pending:
                    controller.accept(ticket, reply('fire'), observation(), 0.01)
                self.assertEqual(controller.tick(observation(**change), now)['reason'], 'stale')
                self.assertTrue(controller.stopped)
                self.assertEqual(set(controller.release_plan['release']), set(p.HELD_INPUTS))

    def test_native_sized_identities(self):
        ticket, _ = p.Controller(0).begin(observation(level_id=2**63-1, player_id=2**63-2), 0)
        self.assertEqual(ticket.identity[2], 2**63-1)

    def test_global_action_deadline(self):
        controller = p.Controller(0)
        ticket, _ = controller.begin(observation(), 119.9)
        plan = controller.accept(ticket, reply('fire'), observation(), 119.95)
        self.assertLessEqual(ticket.expires_at, 120)
        self.assertLessEqual(plan['duration_seconds'], 0.05 + 1e-9)

    def test_huge_number_releases_on_failure(self):
        controller = p.Controller(0)
        ticket, _ = controller.begin(observation(), 0)
        with self.assertRaises(ValueError):
            controller.accept(ticket, reply(), observation(health=10**1000), 0.1)
        self.assertTrue(controller.stopped)
        self.assertEqual(set(controller.release_plan['release']), set(p.HELD_INPUTS))


class JournalTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='protocol-test-', dir=EVIDENCE)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()

    def journal(self, **kwargs):
        journal = p.Journal(self.root / 'run', 'run-01', 'a' * 64, 0, **kwargs)
        self.addCleanup(journal.close)
        return journal

    def test_fixture_directory_respects_private_override(self):
        expected = Path(os.environ.get('PLAYTEST_TEST_TMPDIR', tempfile.gettempdir()))
        self.assertEqual(EVIDENCE, expected)

    def test_real_index_append_and_simulated_frame(self):
        journal = self.journal()
        journal.record('state', observation(source='private code'), 0)
        journal.record('action', observation(), 0.1, action='fire')
        journal.capture('frame-0001.png', b'simulated frame, not PNG evidence', observation(), 0.2)
        rows = [json.loads(row) for row in (journal.root / 'index.jsonl').read_text().splitlines()]
        self.assertEqual([row['sequence'] for row in rows], [0, 1, 2, 3])
        self.assertTrue(all(row['run_id'] == 'run-01' and row['build_sha256'] == 'a' * 64 for row in rows))
        self.assertNotIn('private code', (journal.root / 'index.jsonl').read_text())
        self.assertEqual(journal.root.stat().st_mode & 0o777, 0o700)
        self.assertEqual((journal.root / 'index.jsonl').stat().st_mode & 0o777, 0o600)
        self.assertEqual(rows[-1]['frame'], 8)
        self.assertEqual(rows[-1]['capture'], 'frame-0001.png')

    def test_disposed_scene_is_journaled_without_claiming_gameplay(self):
        journal = self.journal()
        journal.record('stop', observation(phase='title', level_id=0, player_id=0), 0)
        row = json.loads((journal.root / 'index.jsonl').read_text().splitlines()[-1])
        self.assertEqual((row['level_id'], row['player_id'], row['state']['phase']), (0, 0, 'title'))

    def test_reopen_wrong_run_and_symlink(self):
        journal = self.journal()
        with self.assertRaises(ValueError):
            p.Journal(journal.root, 'run-02', 'b' * 64, 0)
        (self.root / 'alias').symlink_to(journal.root, target_is_directory=True)
        with self.assertRaises(ValueError):
            p.Journal(self.root / 'alias' / 'another', 'run-01', 'a' * 64, 0)
        outside = self.root / 'outside'
        outside.write_bytes(b'untouched')
        (journal.root / 'link.png').symlink_to(outside)
        with self.assertRaises(ValueError):
            journal.capture('link.png', b'changed', observation(), 0)
        self.assertEqual(outside.read_bytes(), b'untouched')

    def test_capture_paths_and_no_overwrite(self):
        for path in ('../frame.png', '/tmp/frame.png', 'a/b.png', 'a\\b.png', '.hidden.png', 'script.py', 'a'*129+'.png'):
            journal = p.Journal(self.root / ('run' + str(len(list(self.root.iterdir())))), 'run-01', 'a' * 64, 0)
            self.addCleanup(journal.close)
            with self.assertRaises(ValueError):
                journal.capture(path, b'fixture', observation(), 0)
        journal = self.journal()
        journal.capture('same.png', b'first', observation(), 0)
        with self.assertRaises(ValueError):
            journal.capture('same.png', b'second', observation(), 0.1)
        self.assertEqual((journal.root / 'same.png').read_bytes(), b'first')

    def test_capture_count_byte_time_preflight(self):
        journal = self.journal(max_captures=1, max_bytes=4000)
        journal.check_capture(100, 0, state=observation(), relative_path='one.png')
        journal.capture('one.png', b'fixture', observation(), 0)
        with self.assertRaises(ValueError):
            journal.check_capture(1, 0.1)
        self.assertEqual(len(list(journal.root.glob('*.png'))), 1)
        journal2 = p.Journal(self.root / 'small', 'run-01', 'a' * 64, 0, max_bytes=2000)
        self.addCleanup(journal2.close)
        with self.assertRaises(ValueError):
            journal2.check_capture(2000, 0)
        with self.assertRaises(ValueError):
            journal2.check_capture(1, 120)
        self.assertFalse(list(journal2.root.glob('*.png')))

    def test_bad_metadata_and_no_raw_reply_journaling(self):
        journal = self.journal()
        for state in (observation(run_id='other'), observation(build_sha256='b' * 64), observation(frame=-1)):
            with self.assertRaises(ValueError):
                journal.record('state', state, 0)
        with self.assertRaises(ValueError):
            journal.record('raw_response', observation(), 0)
        with self.assertRaises(ValueError):
            journal.record('action', observation(), 0, action='Bearer private')
        journal.record('state', observation(frame=20), 0)
        with self.assertRaises(ValueError):
            journal.record('state', observation(frame=19), 0.1)
        self.assertNotIn('Bearer', (journal.root / 'index.jsonl').read_text())

    def test_sequence_regression(self):
        journal = self.journal()
        journal.record('state', observation(action_sequence=4), 0)
        with self.assertRaises(ValueError):
            journal.record('state', observation(action_sequence=3), 0.1)

    def test_time_cannot_rewind_after_deadline(self):
        journal = self.journal()
        with self.assertRaises(ValueError):
            journal.check_capture(1, 120)
        with self.assertRaises(ValueError):
            journal.record('state', observation(action_sequence=5), 119)

    def test_run_path_traversal(self):
        with self.assertRaises(ValueError):
            p.Journal(self.root / 'nested' / '..' / 'escape', 'run-01', 'a'*64, 0)

    def test_real_write_failure_closes(self):
        fault = p.Journal(self.root / 'fault', 'run-01', 'a'*64, 0)
        self.addCleanup(fault.close)
        os.close(fault.index_fd)
        # A real read-only owned descriptor forces an OS write error, not a mocked helper.
        fault.index_fd = os.open('index.jsonl', os.O_RDONLY, dir_fd=fault.dir_fd)
        with self.assertRaises(OSError):
            fault.record('state', observation(), 0)
        self.assertTrue(fault.closed)
        with self.assertRaises(ValueError):
            fault.record('state', observation(), 0.1)


if __name__ == '__main__':
    unittest.main()
