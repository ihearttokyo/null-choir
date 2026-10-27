"""Pure fixture lifecycle checks, not execution of Godot or the seal feature."""
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SealFixtureContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = (ROOT / 'game/tests/test_seal_guardians.gd').read_text()
        cls.setup = cls.text.split('for index in chapters:', 1)[1].split('var keys: Array', 1)[0]

    def test_entry_rebuilds_all_envelopes_after_selecting_chapter(self):
        # Source-evidenced original mismatch: Intake revision2 checkpoint/start
        # cannot be retained after selecting Ossuary revision3 at the root.
        revisions = {p.name: json.loads(p.read_text())['floor_revision']
                     for p in (ROOT / 'game/data').glob('0*.json')}
        self.assertEqual(len(revisions), 8)
        self.assertNotEqual(revisions['01_intake.json'], revisions['06_ossuary.json'])
        order = ['game.state.new_campaign(1)', 'game.state.level_index = index',
                 'game.state._label_floor()', 'game.state.mark_checkpoint("entry",Vector3.ZERO)',
                 'var entry: Dictionary = game.state.to_dict()', 'validated.from_dict(entry)',
                 'await game.start_level()']
        self.assertEqual(sorted(self.setup.index(term) for term in order),
                         [self.setup.index(term) for term in order])

    def test_startup_failfast_before_player_dereference(self):
        gate = self.setup.split('var started: bool =', 1)[1].split('game.player.set_physics_process(false)', 1)[0]
        for term in ['is_instance_valid(game.level)', 'is_instance_valid(game.player)',
                     'not game.player.is_queued_for_deletion()', 'game.player.get_parent() == game.level',
                     'game.playing', 'not game.placement_pending', 'game._scene_level_index == index',
                     'if not check(started,', 'await finish()', 'return']:
            self.assertIn(term, gate)
        self.assertIn('production start created current playing player: "+game.message', gate)
        self.assertIn('SEAL_FIXTURE_CHAPTER_BEGIN', self.setup)

    def test_settlement_waits_are_finite_and_do_not_override_production_gates(self):
        self.assertEqual(self.setup.count('await physics_frame'), 2)
        self.assertLess(self.setup.index('await game.start_level()'), self.setup.index('actor.set_physics_process(false)'))
        for forbidden in ['game.playing = true', 'game.placement_pending = false',
                          'game.state.actors =', 'func _capture_actor_state', 'func start_level',
                          'func from_dict', 'func _valid_actor_resources']:
            self.assertNotIn(forbidden, self.text)
        self.assertIn('game.loaded_positions = false', self.setup)

    def test_all8_default_or_exact_single_shard_without_silent_skip(self):
        self.assertIn('var chapters: Array = range(8)', self.text)
        self.assertIn('for index in chapters:', self.text)
        self.assertIn('argument.begins_with("--seal-chapter=")', self.text)
        self.assertIn('not selected and value in ["0","1","2","3","4","5","6","7"]', self.text)
        self.assertIn('chapters = [int(value)]', self.text)
        self.assertIn('if index%2 == 1: keys.reverse()', self.text)
        self.assertIn('SEAL_FIXTURE_CHAPTER_END', self.text)
        self.assertIn('actual snapshot reload chapters=', self.text)

    def test_old_death_drop_capture_collection_and_tamper_controls_remain(self):
        for context in ['one actual bearer', 'seal bearer stronger than base role',
                        'visible depth-tested named identity', 'live guardian blocks direct collection',
                        'live guardian has no free floor marker', 'live free floor marker rejected',
                        'real death records defeat', 'corpse releases pending seal',
                        'drop comes from corpse, not original key cell', 'real marker is at drop origin',
                        'dead persisted drop passes verifier', 'old floor location rejected after death',
                        'complete living-state capture', 'actual pending-drop snapshot reloads',
                        'save reload keeps exact corpse origins', 'corpse seal collected',
                        'collection consumes only its drop', 'no duplicate pickup', 'collected marker retired']:
            self.assertIn('"' + context + '"', self.text)
        self.assertIn('restored.from_dict(data)', self.text)
        self.assertIn('actor.take_damage(actor.hp+1000,game.player)', self.text)

    def test_failure_does_not_print_success_and_always_cleans_owned_game(self):
        finish = self.text.split('func finish() -> void:', 1)[1].split('func check', 1)[0]
        self.assertIn('if is_instance_valid(game):', finish)
        self.assertIn('game.music.stop()', finish)
        self.assertIn('game.queue_free()', finish)
        self.assertIn('if failures.is_empty(): print("PASS', finish)
        self.assertIn('quit(0 if failures.is_empty() else 1)', finish)


if __name__ == '__main__':
    unittest.main()
