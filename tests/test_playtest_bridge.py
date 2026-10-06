"""Offline JSON/lease fixtures, never native input or hosted playtesting."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from tools import playtest_protocol as p
from tools import playtest_bridge as b
from tools.playtest_recorder import FrameRecorder
from tests.test_playtest_protocol import observation, reply
from tests.test_playtest_recorder import PNG


def plan(action='fire', sequence=0):
    state = observation(action_sequence=sequence)
    controller = p.Controller(10)
    ticket, _ = controller.begin(state, 10)
    return ticket, controller.accept(ticket, reply(action), state, 10.05), state


class BridgeTests(unittest.TestCase):
    def test_lossless_native_sized_ids_and_private_observation_wire(self):
        state = observation(level_id=2**63-1, player_id=2**63-2,
                            source='private source', account='private account', path='/Users/private')
        wire = b.encode_observation(state, 1000)
        packet = json.loads(wire)
        self.assertEqual(packet['level_id'], str(2**63-1))
        self.assertEqual(packet['player_id'], str(2**63-2))
        clean = b.decode_observation(wire)
        self.assertEqual(p.identity(clean), p.identity(state))
        self.assertNotIn(b'private', wire)
        self.assertTrue(clean['contacts'][0]['visible'])
        self.assertNotIn('run-01', json.dumps(p.build_request(clean)))

    def test_wire_rejects_unknown_duplicate_noncanonical_and_oversized_fields(self):
        encoded = b.encode_observation(observation(), 1000)
        packet = json.loads(encoded)
        bad = [b'x' * (b.MAX_WIRE_BYTES + 1), b'{"version":1,"version":1}', b'\xff',
               encoded.replace(b'"level_id":"11"', b'"level_id":11')]
        for change in ({'level_id': '011'}, {'player_id': str(2**63)}, {'version': True},
                       {'path': '/Users/private'}, {'clock_domain': 'shared'},
                       {'utc': '2026-01-01T00:00:00'}, {'monotonic': float('nan')}):
            bad.append(json.dumps({**packet, **change}).encode())
        for wire in bad:
            with self.subTest(wire=wire[:80]), self.assertRaises(ValueError):
                b.decode_observation(wire)

    def test_all_bounded_actions_and_unrelated_local_clock_epochs(self):
        for action in p.ACTIONS:
            with self.subTest(action=action):
                ticket, accepted, state = plan(action)
                receiver = b.InputLease('run-01', 'a' * 64, 1000)
                receiver.observe(state, 1000)
                wire = b.encode_command(ticket, accepted, state, 10.05)
                output = receiver.apply(wire, state, 1000.05)
                self.assertEqual(output['action'], action)
                self.assertLessEqual(output['duration_seconds'], 0.15 + 1e-9)
                self.assertLessEqual(abs(output['yaw_degrees']), 15)
                self.assertEqual(output['press'], [action] if action in p.HELD_INPUTS else [])
                self.assertEqual(set(receiver.tick(state, 1000.2)['release']), set(p.HELD_INPUTS))
                self.assertEqual(receiver.next_sequence, 1)
                self.assertFalse(receiver.stopped)

    def test_receiver_clamps_to_observation_deadline_not_sender_clock(self):
        ticket, accepted, state = plan()
        receiver = b.InputLease('run-01', 'a' * 64, 1000)
        receiver.observe(state, 1000)
        output = receiver.apply(b.encode_command(ticket, accepted, state, 10.05), state, 1000.19)
        self.assertLessEqual(output['duration_seconds'], 0.01 + 1e-9)
        self.assertEqual(receiver.tick(state, 1000.2)['reason'], 'lease')

    def test_no_command_replay_pending_replacement_or_lease_extension(self):
        ticket, accepted, state = plan()
        wire = b.encode_command(ticket, accepted, state, 10.05)
        for timing in ('active', 'completed'):
            with self.subTest(timing=timing):
                receiver = b.InputLease('run-01', 'a' * 64, 1000)
                receiver.observe(state, 1000)
                receiver.apply(wire, state, 1000.05)
                if timing == 'completed':
                    receiver.tick(state, 1000.2)
                    receiver.observe(observation(action_sequence=1), 1000.21)
                with self.assertRaises(ValueError):
                    receiver.apply(wire, state, 1000.22 if timing == 'completed' else 1000.1)
                self.assertTrue(receiver.stopped)
                self.assertEqual(set(receiver.release_plan['release']), set(p.HELD_INPUTS))
        receiver = b.InputLease('run-01', 'a' * 64, 1000)
        receiver.observe(state, 1000)
        receiver.apply(wire, state, 1000.05)
        with self.assertRaises(ValueError):
            receiver.observe(state, 1000.1)
        self.assertTrue(receiver.stopped)

    def test_menu_death_stale_frame_scene_and_missing_heartbeat_release(self):
        ticket, accepted, state = plan()
        wire = b.encode_command(ticket, accepted, state, 10.05)
        for change in ({'phase': 'menu'}, {'health': 0}, {'run_id': 'other'},
                       {'build_sha256': 'b' * 64}, {'player_id': 99}, {'level_id': 12},
                       {'action_sequence': 1}, {'frame': 7}, {'health': float('nan')}):
            with self.subTest(change=change):
                receiver = b.InputLease('run-01', 'a' * 64, 1000)
                receiver.observe(state, 1000)
                receiver.apply(wire, state, 1000.05)
                receiver.tick(observation(**change), 1000.1)
                self.assertTrue(receiver.stopped)
                self.assertEqual(set(receiver.release_plan['release']), set(p.HELD_INPUTS))
        receiver = b.InputLease('run-01', 'a' * 64, 1000)
        receiver.observe(state, 1000)
        self.assertEqual(receiver.tick(state, 1000.2)['reason'], 'heartbeat')
        self.assertTrue(receiver.stopped)

    def test_malformed_or_late_commands_fail_closed(self):
        ticket, accepted, state = plan()
        valid = json.loads(b.encode_command(ticket, accepted, state, 10.05))
        for change in ({'action': 'exec(code)'}, {'duration_seconds': 0.21},
                       {'duration_seconds': 0}, {'duration_seconds': True},
                       {'duration_seconds': float('nan')}, {'frame': 9},
                       {'action_sequence': 1}, {'level_id': '11.0'}, {'credential': 'private'}):
            with self.subTest(change=change):
                receiver = b.InputLease('run-01', 'a' * 64, 1000)
                receiver.observe(state, 1000)
                with self.assertRaises(ValueError):
                    receiver.apply(json.dumps({**valid, **change}).encode(), state, 1000.05)
                self.assertTrue(receiver.stopped)
        receiver = b.InputLease('run-01', 'a' * 64, 1000)
        receiver.observe(state, 1000)
        with self.assertRaises(ValueError):
            receiver.apply(json.dumps(valid).encode(), state, 1000.2)
        self.assertEqual(receiver.release_plan['reason'], 'failure')

    def test_clock_and_pilot_caps_release_without_input(self):
        for now in (999, 1120, float('nan')):
            receiver = b.InputLease('run-01', 'a' * 64, 1000)
            receiver.observe(observation(), 1000)
            receiver.tick(observation(), now)
            self.assertTrue(receiver.stopped)
            self.assertEqual(set(receiver.release_plan['release']), set(p.HELD_INPUTS))

    def test_reordered_frames_are_rejected_during_and_after_lease(self):
        ticket, accepted, state = plan()
        receiver = b.InputLease('run-01', 'a' * 64, 1000)
        receiver.observe(state, 1000)
        receiver.apply(b.encode_command(ticket, accepted, state, 10.05), state, 1000.05)
        receiver.tick(observation(frame=12), 1000.1)
        receiver.tick(observation(frame=10), 1000.15)
        self.assertTrue(receiver.stopped)
        receiver = b.InputLease('run-01', 'a' * 64, 1000)
        receiver.observe(state, 1000)
        receiver.apply(b.encode_command(ticket, accepted, state, 10.05), state, 1000.05)
        receiver.tick(state, 1000.2)
        with self.assertRaises(ValueError):
            receiver.observe(observation(action_sequence=1, frame=7), 1000.21)
        self.assertTrue(receiver.stopped)

    def test_command_encoder_rejects_lifecycle_changed_after_acceptance(self):
        ticket, accepted, state = plan()
        for change in ({'phase': 'menu'}, {'health': 0}, {'player_id': 99}):
            with self.assertRaises(ValueError):
                b.encode_command(ticket, accepted, {**state, **change}, 10.05)

    def test_receiver_interrupt_releases_and_preserves_interrupt(self):
        ticket, accepted, state = plan()
        receiver = b.InputLease('run-01', 'a' * 64, 1000)
        receiver.observe(state, 1000)
        with patch.object(b, '_decode', side_effect=KeyboardInterrupt()):
            with self.assertRaises(KeyboardInterrupt):
                receiver.apply(b.encode_command(ticket, accepted, state, 10.05), state, 1000.05)
        self.assertTrue(receiver.stopped)
        self.assertEqual(set(receiver.release_plan['release']), set(p.HELD_INPUTS))

    def test_two_controller_receiver_decisions_with_explicit_completed_ack(self):
        controller = p.Controller(10)
        receiver = b.InputLease('run-01', 'a' * 64, 1000)
        directory = tempfile.TemporaryDirectory(prefix='null-choir-wire-integration-')
        self.addCleanup(directory.cleanup)
        journal = p.Journal(Path(directory.name).resolve() / 'run', 'run-01', 'a' * 64, 10)
        self.addCleanup(journal.close)
        recorder = FrameRecorder(journal, byte_bound=1024)
        self.addCleanup(recorder.close)
        for sequence in range(2):
            offset = sequence * 0.5
            state = observation(action_sequence=sequence, frame=8 + sequence)
            wire = receiver.observe(state, 1000 + offset)
            decoded = b.decode_observation(wire)
            ticket, _ = controller.begin(decoded, 10 + offset)
            accepted = controller.accept(ticket, reply('fire'), decoded, 10.05 + offset)
            command = b.encode_command(ticket, accepted, decoded, 10.05 + offset)
            self.assertIn('fire', receiver.apply(command, state, 1000.05 + offset)['press'])
            journal.record('action', decoded, 10.05 + offset, action=accepted['action'])
            recorder.frame_drawn(decoded, 10.05 + offset, lambda _: PNG, completed=True)
            receiver.tick(state, 1000.2 + offset)
            advanced = observation(action_sequence=receiver.next_sequence, frame=9 + sequence)
            controller.tick(advanced, 10.2 + offset)
            journal.record('release', advanced, 10.2 + offset)
            self.assertFalse(receiver.stopped)
            self.assertFalse(controller.stopped)
        self.assertEqual(controller.attempts, 2)
        self.assertEqual(receiver.next_sequence, 2)
        rows = [json.loads(row) for row in (journal.root / 'index.jsonl').read_text().splitlines()]
        self.assertEqual([row['kind'] for row in rows], ['run', 'action', 'frame', 'release', 'action', 'frame', 'release'])
        self.assertEqual(journal.captures, 2)

    def test_receiver_completion_can_precede_controller_lease_deadline(self):
        controller = p.Controller(10)
        receiver = b.InputLease('run-01', 'a' * 64, 1000)
        state = observation()
        receiver.observe(state, 1000)
        ticket, _ = controller.begin(state, 10.04)
        accepted = controller.accept(ticket, reply('fire'), state, 10.1)
        receiver.apply(b.encode_command(ticket, accepted, state, 10.1), state, 1000.1)
        ack = receiver.tick(state, 1000.2)
        self.assertEqual(ack['reason'], 'lease')
        self.assertEqual(ack['action_sequence'], 1)
        self.assertIsNotNone(controller.active_ticket)
        # A future driver must defer this transition until the controller's own
        # deadline; it still checks fresh lifecycle/scene state at that boundary.
        advanced = observation(action_sequence=1, frame=9)
        self.assertEqual(controller.tick(advanced, ticket.expires_at)['reason'], 'lease')
        self.assertFalse(controller.stopped)
        controller.begin(advanced, ticket.expires_at + 0.01)


if __name__ == '__main__':
    unittest.main()
