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


# Exact, declared current additions only; the original ordinary-body SHA below
# remains the authority. This does not qualify current96 artwork or consumers.
FINITE_DEATH_HOOK = '\n\t\tif game.has_method("earned_defeated") and not game.earned_defeated(self): return'
NURSERY_WINDOW = (
    '\n\t# A masked front-node precision bonus; ordinary damage and interruption stay identical.'
    '\n\tif kind == "nursery_warden" and Engine.is_in_physics_frame() and WardenPressureWindow.eligible(_warden_node_binding,sprite,context.get("sprite_contact",{}),get_instance_id(),source,game.player,game,game.level,kind,telegraph_time,_committed_variant,context,Engine.get_physics_frames()):'
    '\n\t\tamount = WardenPressureWindow.bonus_damage(amount)'
)


def ordinary_transaction_with_exact_death_hook(text):
    if text.count('func take_damage(') != 1:
        raise AssertionError('Exactly one ordinary damage function required')
    body = text.split('func take_damage(', 1)[1].split('\n\t# Leave the complete ordinary-hit', 1)[0]
    live_guard = '\n\tif hp <= 0 or amount <= 0 or not _current_map() or not game.playing: return'
    armor_guard = '\n\tif kind == "guardian" and telegraph_time <= 0 and pose_time <= 0 and recovery_time <= 0:'
    if body.count(NURSERY_WINDOW) != 1 or body.count(live_guard+NURSERY_WINDOW+armor_guard) != 1:
        raise AssertionError('Exact Nursery-only current-physics/context block required before guardian armor')
    if body.count(FINITE_DEATH_HOOK) != 1 or body.count('\n\tif hp == 0:'+FINITE_DEATH_HOOK+'\n\t\t_committed_variant = -1') != 1:
        raise AssertionError('Exact finite-death false-return hook required first in hp==0 before reset')
    hook = '\n\t\tif game.has_method("guardian_defeated"): game.guardian_defeated(self)'
    if body.count(hook) != 1:
        raise AssertionError('Exactly one named seal-death hook required')
    death = body.split('\n\tif hp == 0:', 1)[1].split('\n\telif telegraph_time', 1)[0]
    if hook not in death or not death.index('game.state.removed.append(id)') < death.index(hook) < death.index('_event("death")'):
        raise AssertionError('Seal hook must follow recorded death, before notification, never live/nonlethal')
    vent = '\n\t\tclutch_vent_time = 0'
    if body.count(vent) != 1 or death.count('\n\t\tstagger_time = 0'+vent+'\n\t\trecovery_time = 0') != 1:
        raise AssertionError('Exactly one ordinary Worker reset required in the recorded death branch')
    for exact in [NURSERY_WINDOW, FINITE_DEATH_HOOK, hook, vent]:
        body = body.replace(exact, '', 1)
    return body


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
        modified = ordinary_transaction_with_exact_death_hook((ROOT/'game/scripts/enemy.gd').read_text())
        self.assertEqual(regions.digest(modified.rstrip().encode()), "c6daf26f01abfee086a8abe10e65a8e63148048f0630c0a8e3144e9e48915b9c")

    def test_only_exact_recorded_death_hook_is_compatible(self):
        source = (ROOT/'game/scripts/enemy.gd').read_text()
        hook = '\n\t\tif game.has_method("guardian_defeated"): game.guardian_defeated(self)'
        moved = source.replace(hook, '', 1).replace('\n\t\t_event("death")', '\n\t\t_event("death")'+hook, 1)
        nonlethal = source.replace(hook, '', 1).replace('\n\telif telegraph_time > 0 and _counter_time <= 0:', '\n\telif telegraph_time > 0 and _counter_time <= 0:'+hook, 1)
        live = source.replace(hook, '', 1).replace('\n\tif hp == 0:', '\n\tif hp > 0:'+hook+'\n\tif hp == 0:', 1)
        early = source.replace(hook, '', 1).replace('\n\t\tif not id in game.state.removed:', hook+'\n\t\tif not id in game.state.removed:', 1)
        for bad in [source.replace(hook, '', 1), source.replace(hook, hook+hook, 1),
                    source.replace('game.guardian_defeated(self)', 'game.guardian_defeated(null)', 1), moved, nonlethal, live, early]:
            with self.assertRaises(AssertionError): ordinary_transaction_with_exact_death_hook(bad)

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


    def test_exact_finite_death_hook_rejects_mutation_or_relocation(self):
        source = (ROOT/'game/scripts/enemy.gd').read_text()
        moved = source.replace(FINITE_DEATH_HOOK, '', 1).replace('\n\t\t_committed_variant = -1', '\n\t\t_committed_variant = -1'+FINITE_DEATH_HOOK, 1)
        live = source.replace(FINITE_DEATH_HOOK, '', 1).replace('\n\tif hp == 0:', FINITE_DEATH_HOOK+'\n\tif hp == 0:', 1)
        variants = [source.replace(FINITE_DEATH_HOOK, '', 1), source.replace(FINITE_DEATH_HOOK, FINITE_DEATH_HOOK*2, 1), moved, live]
        for old,new in [('earned_defeated(self)', 'earned_defeated(null)'), ('earned_defeated(self)', 'earned_defeated(game.player)'), ('and not game.earned_defeated', 'and game.earned_defeated'), ('): return', '): pass')]:
            variants.append(source.replace(FINITE_DEATH_HOOK, FINITE_DEATH_HOOK.replace(old,new), 1))
        for number,bad in enumerate(variants):
            with self.subTest(number=number), self.assertRaises(AssertionError):
                ordinary_transaction_with_exact_death_hook(bad)

    def test_exact_nursery_window_rejects_mutation_or_relocation(self):
        source = (ROOT/'game/scripts/enemy.gd').read_text()
        moved = source.replace(NURSERY_WINDOW, '', 1).replace('\n\thp = maxi(0,hp-amount)', NURSERY_WINDOW+'\n\thp = maxi(0,hp-amount)', 1)
        variants = [source.replace(NURSERY_WINDOW, '', 1), source.replace(NURSERY_WINDOW, NURSERY_WINDOW*2, 1), moved]
        changes = [('kind == "nursery_warden" and ', ''), ('kind == "nursery_warden"', 'kind == "worker"'), ('Engine.is_in_physics_frame() and ', ''), ('context.get("sprite_contact",{})', '{}'), ('source,game.player', 'game.player,source'), ('Engine.get_physics_frames()', '0'), ('bonus_damage(amount)', 'bonus_damage(amount)*2')]
        for old,new in changes:
            variants.append(source.replace(NURSERY_WINDOW, NURSERY_WINDOW.replace(old,new), 1))
        for number,bad in enumerate(variants):
            with self.subTest(number=number), self.assertRaises(AssertionError):
                ordinary_transaction_with_exact_death_hook(bad)

    def test_unknown_pipeline_mutations_survive_normalization_and_fail_frozen_hash(self):
        source = (ROOT/'game/scripts/enemy.gd').read_text()
        frozen = "c6daf26f01abfee086a8abe10e65a8e63148048f0630c0a8e3144e9e48915b9c"
        for old,new in [('hp-amount', 'hp-amount*2'), ('amount*0.35', 'amount*0.50'), ('_counter_time = 1.4', '_counter_time = 0.0'), ('collision_layer = 0', 'collision_layer = 4'), ('source.get_parent() == game.level', 'true')]:
            bad = source.replace(old,new,1)
            self.assertNotEqual(bad,source)
            with self.subTest(change=old):
                self.assertNotEqual(regions.digest(ordinary_transaction_with_exact_death_hook(bad).rstrip().encode()),frozen)

    def test_worker_consequence_and_five_field_actor_functions_exact_historical_source(self):
        # Exact function bytes independently equal merged847c6cc3 before earned
        # supplies/Nursery changes. These are source contracts, not art receipts.
        import re
        source = (ROOT/'game/scripts/enemy.gd').read_text()
        expected = {'_try_worker_clutch':'b2f62ea4daf9b1a2270cfc6675dd0bfca015627b291252fc315cef1943b99f96',
                    'snapshot':'29e774d4cd965f6156c98a2ff6a23438d7cc30933725bae003967d62067fdb17',
                    'restore_snapshot':'3cf95d7ed1deb43b34fa39256c53ea5fa6b4af36b9ddb60c50c6c02422126dbf'}
        for name,digest in expected.items():
            body = re.search(r'^func '+name+r'\([^\n]*\n(.*?)(?=^func |\Z)', source, re.M|re.S).group(0)
            with self.subTest(function=name): self.assertEqual(regions.digest(body.encode()),digest)
        campaign = (ROOT/'game/scripts/campaign.gd').read_text()
        self.assertIn('record.size() != 5',campaign)
        self.assertIn('for field in ["id","hp","position","yaw","alerted"]:',campaign)
        self.assertIn('var snapshots = [data,saved_checkpoint,saved_start]',campaign)
        self.assertIn('for snapshot in [data,saved_checkpoint,saved_start]:',campaign)

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
