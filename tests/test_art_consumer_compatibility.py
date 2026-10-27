"""Exact later-consumer receipt joins and refusal controls; no native execution."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('current_consumers_test', ROOT / 'tools/art_consumer_compatibility.py')
c = importlib.util.module_from_spec(spec)
spec.loader.exec_module(c)


class CurrentConsumers(unittest.TestCase):
    def test_actual_exact_generation_and_honest_scope(self):
        v = c.qualify(ROOT)
        self.assertEqual(v['native_observation']['frame_count'], 48)
        self.assertEqual([r['chapter'] for r in v['native_observation']['chapters']], list(range(8)))
        self.assertTrue(all(len(r['frames']) == 6 and r['strict_supervision'] == 'PASS'
                            for r in v['native_observation']['chapters']))
        for key in ['new_three_pose_pistol_ABA_qualification', 'new_body_fullmatrix_or_555_qualification',
                    'new_gate_opening_or_fullview_qualification', 'new_art_grade_or_final_visual_acceptance',
                    'earned_combat_or_performance_or_package_qualification']:
            self.assertIs(v['scope'][key], False)
        self.assertIn('idle only', v['scope']['pistol_pose_observed'])
        self.assertIn('visual correction', v['scope']['occlusion_limits'])

    def test_foreign_current_consumer_asset_and_import_refuse(self):
        read = c.read_resident
        for target in ['game/scripts/main.gd', 'game/scripts/hud.gd', 'game/scripts/enemy.gd',
                       'game/scripts/level.gd', 'game/scripts/player.gd',
                       'game/assets/art/weapons/native-v5/rivet_pistol.png',
                       'game/assets/art/weapons/native-v5/rivet_pistol.png.import']:
            def altered(root, relative):
                data = read(root, relative)
                return data + b'\nforeign' if relative == target else data
            with self.subTest(target=target), patch.object(c, 'read_resident', side_effect=altered):
                with self.assertRaisesRegex(ValueError, 'drift'): c.qualify(ROOT)

    def test_missing_or_rehashed_current_receipt_refuses(self):
        read = c.read_resident
        doc = json.loads(read(ROOT, c.RECEIPT))
        for change in ['missing', 'source', 'frame', 'scope']:
            value = copy.deepcopy(doc)
            if change == 'source': value['current_sources']['game/scripts/main.gd']['sha256'] = '0' * 64
            elif change == 'frame': value['native_observation']['chapters'][0]['frames'].pop()
            elif change == 'scope': value['scope']['new_three_pose_pistol_ABA_qualification'] = True
            data = json.dumps(value).encode()
            def altered(root, relative):
                if relative != c.RECEIPT: return read(root, relative)
                if change == 'missing': raise FileNotFoundError('missing current receipt')
                return data
            with self.subTest(change=change), patch.object(c, 'read_resident', side_effect=altered):
                with self.assertRaises((ValueError, FileNotFoundError)): c.qualify(ROOT)

    def test_historical_sources_are_explicit_snapshots_not_current_hash_swaps(self):
        v = c.qualify(ROOT)
        for relative, row in v['historical_sources'].items():
            old = c.historical(ROOT, relative, row['sha256'])
            self.assertEqual(hashlib.sha256(old).hexdigest(), row['sha256'])
            self.assertNotEqual(old, (ROOT / relative).read_bytes())
            self.assertTrue(row['path'].startswith('source/art/consumer-qualification-v0094/provenance/'))
        with self.assertRaises(ValueError): c.historical(ROOT, 'game/scripts/main.gd', '0' * 64)
        with self.assertRaises(ValueError): c.historical(ROOT, 'game/scripts/foreign.gd', '0' * 64)

    def test_historical_snapshot_tamper_refuses(self):
        read = c.read_resident
        target = 'source/art/consumer-qualification-v0094/provenance/hud-before-v0094.gd'
        with patch.object(c, 'read_resident', side_effect=lambda r,p: read(r,p) + (b'changed' if p == target else b'')):
            with self.assertRaisesRegex(ValueError, 'drift'): c.qualify(ROOT)

    def test_no_follow_before_read_without_leaving_synthetic_symlinks(self):
        with patch.object(Path, 'is_symlink', return_value=True), patch.object(Path, 'read_bytes') as read:
            with self.assertRaisesRegex(ValueError, 'symlink'): c.read_resident(ROOT, c.RECEIPT)
            read.assert_not_called()

    def test_public_receipt_has_no_private_paths_or_quality_numbers(self):
        text = (ROOT / c.RECEIPT).read_text().lower()
        for token in ['/users/', '/private/', '/tmp/', '/home/', 'argv', 'home=', 'rating', 'rubric', 'score']:
            self.assertNotIn(token, text)


if __name__ == '__main__':
    unittest.main()
