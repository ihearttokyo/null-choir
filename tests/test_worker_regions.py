"""CPU-only synthetic mask validation + static integration contracts.

These tests do not execute GDScript, native physics, GPU rendering or gameplay.
"""
import copy
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('prepare_worker_regions', ROOT/'tools/prepare_worker_regions.py')
regions = importlib.util.module_from_spec(spec)
spec.loader.exec_module(regions)


class WorkerRegionContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Deliberately synthetic, not produced from the artwork, never installed.
        cls.beauty = bytes([48, 32, 16, 255])*(regions.WIDTH*regions.HEIGHT)
        ids = bytearray(regions.WIDTH*regions.HEIGHT)
        for frame in range(32):
            ids[(frame//8*128+7)*1024+frame % 8*128+9] = 1
        cls.mask = bytes(ids)
        cls.manifest = regions.make_manifest(cls.beauty, cls.mask, b'SYNTHETIC PNG',
                                             b'SYNTHETIC BLEND', ['SYNTHETIC clutch object'])

    def test_explicit_synthetic_subset(self):
        self.assertEqual(regions.validate(self.beauty, self.mask, self.manifest), 32)

    def test_wrong_atlas_content_even_same_alpha_rejected(self):
        changed = bytearray(self.beauty); changed[0] ^= 1
        with self.assertRaisesRegex(ValueError, 'beauty RGBA hash'):
            regions.validate(bytes(changed), self.mask, self.manifest)

    def test_wrong_mask_hash_rejected(self):
        changed = bytearray(self.mask); changed[0] = 1
        with self.assertRaisesRegex(ValueError, 'mask hash'):
            regions.validate(self.beauty, bytes(changed), self.manifest)

    def test_source_identity_required(self):
        for key in ['source_blend_sha256', 'beauty_source_sha256']:
            invalid = copy.deepcopy(self.manifest); invalid[key] = ''
            with self.subTest(key=key), self.assertRaises(ValueError):
                regions.validate(self.beauty, self.mask, invalid)

    def test_frame_direction_pose_and_hash_bound(self):
        for key, value in [('frame', 1), ('direction', 7), ('pose', 2), ('labels', 9), ('mask_sha256', '0'*64), ('beauty_rgba_sha256', '0'*64)]:
            invalid = copy.deepcopy(self.manifest); invalid['frames'][0][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                regions.validate(self.beauty, self.mask, invalid)

    def test_unknown_id_not_silently_ordinary(self):
        changed = bytearray(self.mask); changed[0] = 2
        with self.assertRaisesRegex(ValueError, 'unknown material ID'):
            regions.make_manifest(self.beauty, bytes(changed), b'PNG', b'BLEND', ['clutch'])

    def test_exact_alpha_cutoff(self):
        index = next(i for i, value in enumerate(self.mask) if value)
        for alpha in [0, 1, 127, 128, 255]:
            changed = bytearray(self.beauty); changed[index*4+3] = alpha
            with self.subTest(alpha=alpha):
                if alpha < 128:
                    with self.assertRaisesRegex(ValueError, 'outside exact accepted beauty alpha'):
                        regions.make_manifest(bytes(changed), self.mask, b'PNG', b'BLEND', ['clutch'])
                else:
                    regions.make_manifest(bytes(changed), self.mask, b'PNG', b'BLEND', ['clutch'])

    def test_alpha_is_not_anatomy(self):
        # Even wholly opaque accepted art may not become wholly weakpoint.
        ids = bytes([1])*(regions.WIDTH*regions.CELL)+bytes(regions.WIDTH*(regions.HEIGHT-regions.CELL))
        with self.assertRaisesRegex(ValueError, 'strict per-frame subset'):
            regions.make_manifest(self.beauty, ids, b'PNG', b'BLEND', ['clutch'])

    def test_dead_pose_has_no_weakpoint(self):
        changed = bytearray(self.mask); changed[4*128*1024] = 1
        with self.assertRaisesRegex(ValueError, 'dead and vent poses'):
            regions.make_manifest(self.beauty, bytes(changed), b'PNG', b'BLEND', ['clutch'])

    def test_empty_mask_cannot_be_shipped(self):
        with self.assertRaisesRegex(ValueError, 'empty anatomy'):
            regions.make_manifest(self.beauty, bytes(len(self.mask)), b'PNG', b'BLEND', ['clutch'])

    def test_real_object_names_required_not_inferred(self):
        with self.assertRaisesRegex(ValueError, 'authored object'):
            regions.make_manifest(self.beauty, self.mask, b'PNG', b'BLEND', [])

    def test_material_id_raster_decodes_only_exact_bytes(self):
        rgba = bytes([0, 0, 0, 255])*(1024*768)
        self.assertEqual(regions.ids_from_rgba(rgba), bytes(1024*768))
        for bad in [(255, 0, 0, 255), (1, 1, 0, 255), (1, 0, 0, 127), (1, 0, 0, 0)]:
            with self.subTest(pixel=bad), self.assertRaisesRegex(ValueError, 'exact opaque region bytes'):
                regions.ids_from_rgba(bytes(bad)+rgba[4:])

    def test_no_synthetic_mask_installed(self):
        import json
        manifest = ROOT/'game/assets/art/regions/worker-clutch-v1.json'
        if manifest.exists():
            actual = json.loads(manifest.read_text())
            self.assertFalse(any('synthetic' in name.lower() for name in actual.get('authored_objects', [])))
        else:
            self.assertEqual(list((ROOT/'game').rglob('*.regions')), [])

    def test_player_forwards_real_query_contact_both_direct_paths(self):
        source = (ROOT/'game/scripts/player.gd').read_text()
        self.assertEqual(source.count('"sprite_contact":_sprite_contact(hit)'), 2)
        self.assertIn('if hit.get("coverage") != "visible_sprite": return {}', source)
        self.assertIn('"sprite_pixel":hit.get("sprite_pixel"),"frame_pixel":hit.get("frame_pixel")', source)

    def test_manual_query_invalidation_checks_exact_generation(self):
        source = (ROOT/'game/scripts/worker_hit_regions.gd').read_text()
        self.assertIn('"query_cache":cache', source)
        self.assertIn('_query_cache_current(cached,texture)', source)
        self.assertIn('_query_cache_current(binding,sprite.texture)', source)
        check = source.split('static func _query_cache_current', 1)[1].split('static func _hash_string', 1)[0]
        self.assertIn('texture.has_meta(SpriteHitQuery.CACHE_KEY)', check)
        self.assertIn('is_same(texture.get_meta(SpriteHitQuery.CACHE_KEY),binding.get("query_cache"))', check)
        self.assertNotIn('_texture_cache(', check)
        self.assertNotIn('sha256(', check)
        self.assertNotIn('get_image(', check)

    def test_ordinary_damage_transaction_preserved(self):
        modified = (ROOT/'game/scripts/enemy.gd').read_text().split('func take_damage(', 1)[1].split('\n\t# Leave the complete ordinary-hit', 1)[0]
        modified = modified.replace('\n\t\tclutch_vent_time = 0', '')
        self.assertEqual(regions.digest(modified.rstrip().encode()), "c6daf26f01abfee086a8abe10e65a8e63148048f0630c0a8e3144e9e48915b9c")

    def test_consequence_is_not_damage_multiplier_blast_or_new_save(self):
        source = (ROOT/'game/scripts/enemy.gd').read_text()
        consequence = source.split('func _try_worker_clutch(', 1)[1].split('\n\nfunc _next_step', 1)[0]
        self.assertNotIn('hp =', consequence)
        self.assertIn('context.get("attack_kind") not in ["melee","hitscan","piercing"]', consequence)
        self.assertIn('source != game.player', consequence)
        self.assertIn('_worker_clutch_spent = true', consequence)
        self.assertIn('_counter_time = maxf(_counter_time,1.4)', consequence)
        snapshot = source.split('func snapshot()', 1)[1].split('func restore_snapshot', 1)[0]
        self.assertNotIn('clutch', snapshot)


    def test_legacy_export_patterns_do_not_cover_raw_mask(self):
        import fnmatch
        mask = 'assets/art/regions/worker-clutch-v1.regions'
        self.assertFalse(any(fnmatch.fnmatchcase(mask, p) for p in ['*.json','*.mid','*.sf2','*.txt']))

    def test_actual_export_presets_explicitly_cover_raw_mask(self):
        import fnmatch
        import re
        source = (ROOT/'game/export_presets.cfg').read_text()
        mask = 'assets/art/regions/worker-clutch-v1.regions'
        filters = re.findall(r'^include_filter="([^"]*)"$', source, re.M)
        self.assertGreater(len(filters), 0)
        for value in filters:
            patterns = value.split(',')
            self.assertIn(mask, patterns)
            self.assertTrue(any(fnmatch.fnmatchcase(mask, p) for p in patterns))

if __name__ == '__main__':
    unittest.main(verbosity=2)
