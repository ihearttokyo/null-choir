"""Resident recorder fixtures; simulated observations/PNG, no native renderer."""
import base64
import json
from pathlib import Path
import tempfile
import unittest

from tools.playtest_protocol import Controller, Journal
from tools.playtest_recorder import FrameRecorder
from tests.test_playtest_protocol import observation, reply

# Supplied synthetic PNG-framed test bytes, never a gameplay screenshot.
PNG = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a7L8AAAAASUVORK5CYII=')


class RecorderTests(unittest.TestCase):
    def test_action_completion_is_an_event_without_shifting_baseline(self):
        self.assertEqual(self.draw(0,1), 'frame-0000.png')
        self.assertEqual(self.draw(0.1,2,action_sequence=1), 'frame-0001.png')
        self.assertIsNone(self.draw(0.4,3,action_sequence=1))
        self.assertEqual(self.draw(0.5,4,action_sequence=1), 'frame-0002.png')

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix='null-choir-recorder-')
        self.root = Path(self.directory.name).resolve() / 'run'
        self.journal = Journal(self.root, 'run-01', 'a' * 64, 0)
        self.recorder = FrameRecorder(self.journal, byte_bound=1024)
        self.calls = []

    def tearDown(self):
        self.recorder.close()
        self.directory.cleanup()

    def produce(self, bound):
        self.calls.append(bound)
        return PNG

    def draw(self, now, frame, **changes):
        return self.recorder.frame_drawn(observation(frame=frame, **changes), now,
                                         self.produce, completed=True)

    def test_postdraw_acknowledgment_duplicate_and_cadence(self):
        for completed in (False, None, 1, 'yes'):
            self.assertIsNone(self.recorder.frame_drawn(observation(), 0, self.produce, completed=completed))
        self.assertEqual(self.calls, [])
        self.assertEqual(self.draw(0, 1), 'frame-0000.png')
        self.assertIsNone(self.draw(0.1, 1))
        self.assertIsNone(self.draw(0.2, 2))
        self.assertIsNone(self.draw(0.4999, 3))
        self.assertEqual(self.draw(0.5, 4), 'frame-0001.png')
        self.assertIsNone(self.draw(0.6, 5))
        self.assertEqual(self.draw(1, 6), 'frame-0002.png')
        self.assertEqual(self.calls, [1024] * 3)

    def test_lifecycle_objective_weapon_and_death_force_capture(self):
        changes = [dict(phase='menu'), dict(phase='alive'), dict(level_id=12),
                   dict(player_id=23), dict(objective='Fight visible enemies'),
                   dict(weapon=2), dict(health=0)]
        state = {}
        self.draw(0, 1)
        for index, change in enumerate(changes, 2):
            state.update(change)
            self.assertIsNotNone(self.draw(index * 0.01, index, **state))
        self.assertEqual(len(self.calls), 8)
        # Ordinary ammo/health changes do not encode at the physics-frame rate.
        self.assertIsNone(self.draw(0.1, 10, **{**state, 'ammo': [0, 30, 0, 0, 0, 0]}))

    def test_event_capture_does_not_postpone_regular_two_fps_frame(self):
        self.draw(0, 1)
        self.draw(0.2, 2, phase='menu')
        self.draw(0.3, 3, phase='alive')
        self.assertEqual(self.draw(0.5, 4), 'frame-0003.png')
        self.assertEqual(len(self.calls), 4)

    def test_action_sequence_cannot_regress_across_skipped_frames(self):
        self.draw(0, 1, action_sequence=0)
        # A changed action now forces an event capture on a new frame. Duplicate
        # post-draw notification still skips encoding but must track the sequence.
        self.assertIsNone(self.draw(0.1, 1, action_sequence=2))
        with self.assertRaises(ValueError):
            self.draw(0.2, 2, action_sequence=1)
        self.assertTrue(self.recorder.stopped)
        self.assertEqual(len(self.calls), 1)

    def test_missed_intervals_do_not_encode_a_catchup_burst(self):
        self.draw(0, 1)
        self.assertEqual(self.draw(2, 2), 'frame-0001.png')
        self.assertIsNone(self.draw(2.01, 3))
        self.assertEqual(len(self.calls), 2)

    def test_invalid_bounds_and_interrupt_close_without_more_frames(self):
        for bound in (0, -1, True, 1.5, float('nan'), 250 * 1024 * 1024 + 1):
            with self.assertRaises(ValueError):
                FrameRecorder(self.journal, byte_bound=bound)

        def interrupted(_bound):
            raise KeyboardInterrupt()

        with self.assertRaises(KeyboardInterrupt):
            self.recorder.frame_drawn(observation(), 0, interrupted, completed=True)
        self.assertTrue(self.recorder.stopped)
        self.assertTrue(self.journal.closed)
        self.assertEqual(self.journal.captures, 0)

    def test_preflight_count_and_bytes_stop_before_encoding(self):
        for limits in ({'max_captures': 1}, {'max_bytes': 1200}):
            with self.subTest(limits=limits):
                self.recorder.close()
                self.journal = Journal(self.root.parent / ('limited-' + next(iter(limits))),
                                       'run-01', 'a' * 64, 0, **limits)
                self.recorder = FrameRecorder(self.journal, byte_bound=1024)
                self.calls.clear()
                if 'max_captures' in limits:
                    self.draw(0, 1)
                before = len(self.calls)
                with self.assertRaises(ValueError):
                    self.draw(0.5, 2)
                self.assertEqual(len(self.calls), before)
                self.assertTrue(self.recorder.stopped)
                self.assertTrue(self.journal.closed)

    def test_invalid_frame_clock_identity_and_time_stop_before_producer(self):
        for now, changes in ((0.1, {'frame': 0}), (-1, {'frame': 2}),
                             (120, {'frame': 2}), (0.1, {'frame': 2, 'run_id': 'other'}),
                             (0.1, {'frame': 2, 'build_sha256': 'b' * 64}),
                             (0.1, {'frame': 2, 'health': float('nan')})):
            with self.subTest(now=now, changes=changes):
                self.recorder.close()
                self.journal = Journal(self.root.parent / f'case-{len(list(self.root.parent.iterdir()))}', 'run-01', 'a' * 64, 0)
                self.recorder = FrameRecorder(self.journal, byte_bound=1024)
                self.draw(0, 1)
                before = len(self.calls)
                with self.assertRaises(ValueError):
                    self.recorder.frame_drawn(observation(**changes), now, self.produce, completed=True)
                self.assertEqual(len(self.calls), before)
                self.assertTrue(self.recorder.stopped)

    def test_producer_errors_and_actual_bytes_fail_closed_without_retry(self):
        def failure(_bound):
            raise OSError('sensitive native path')

        for produce in (failure, lambda _: b'x' * 1025, lambda _: 'not bytes', lambda _: b'not PNG'):
            with self.subTest(produce=produce):
                self.recorder.close()
                self.journal = Journal(self.root.parent / f'bad-{len(list(self.root.parent.iterdir()))}', 'run-01', 'a' * 64, 0)
                self.recorder = FrameRecorder(self.journal, byte_bound=1024)
                with self.assertRaisesRegex(ValueError, '^Frame recording stopped'):
                    self.recorder.frame_drawn(observation(), 0, produce, completed=True)
                self.assertTrue(self.recorder.stopped)
                self.assertEqual(list(self.journal.root.iterdir()), [self.journal.root / 'index.jsonl'])
                with self.assertRaises(ValueError):
                    self.recorder.frame_drawn(observation(frame=9), 1, self.produce, completed=True)

    def test_snapshot_is_frozen_before_encoding_and_index_stays_private(self):
        state = observation(source='private code', path='/Users/private', account='private account')

        def mutate(_bound):
            state.update(player_id=99, phase='menu', frame=999)
            state['ammo'][1] = 0
            return PNG

        name = self.recorder.frame_drawn(state, 0, mutate, completed=True)
        row = json.loads((self.root / 'index.jsonl').read_text().splitlines()[-1])
        self.assertEqual((row['player_id'], row['frame'], row['state']['phase']), (22, 8, 'alive'))
        self.assertEqual(row['state']['ammo'][1], 37)
        self.assertNotIn('private', json.dumps(row))
        self.assertEqual((self.root / name).read_bytes(), PNG)
        self.assertEqual(self.root.stat().st_mode & 0o777, 0o700)
        self.assertEqual((self.root / name).stat().st_mode & 0o777, 0o600)

    def test_controller_journal_recorder_integration_stops_on_cap(self):
        self.recorder.close()
        self.journal = Journal(self.root.parent / 'integration', 'run-01', 'a' * 64, 0, max_captures=1)
        self.recorder = FrameRecorder(self.journal, byte_bound=1024)
        controller = Controller(0)
        state = observation(frame=1)
        ticket, _ = controller.begin(state, 0)
        plan = controller.accept(ticket, reply('fire'), state, 0.01)
        self.journal.record('action', state, 0.01, action=plan['action'])
        self.recorder.frame_drawn(state, 0.01, self.produce, completed=True)
        with self.assertRaises(ValueError):
            try:
                self.recorder.frame_drawn(observation(frame=2, phase='menu'), 0.02, self.produce, completed=True)
            except ValueError:
                controller.fail()  # Future native driver must apply its release plan.
                raise
        self.assertTrue(controller.stopped)
        self.assertIn('fire', controller.release_plan['release'])
        self.assertEqual(len(self.calls), 1)


if __name__ == '__main__':
    unittest.main()
