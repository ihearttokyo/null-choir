"""Exact later-consumer receipt joins and refusal controls; no native execution."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import unittest
import types
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('current_consumers_test', ROOT / 'tools/art_consumer_compatibility.py')
c = importlib.util.module_from_spec(spec)
spec.loader.exec_module(c)


class CurrentConsumers(unittest.TestCase):
    def test_actual_exact_generation_and_honest_scope(self):
        v = c.qualify(ROOT)
        if v['schema'] == 'null-choir-exact-current-art-consumers-v0096-v1':
            jobs = v['native_observation']['jobs']
            self.assertEqual({r['id'] for r in jobs}, set(c.EXPECTED96_JOBS))
            self.assertEqual(len(jobs), 22)
            self.assertTrue(all(r['frames'] for r in jobs))
            for key in ['new_three_pose_pistol_ABA_qualification', 'new_body_fullmatrix_or_555_qualification',
                        'new_gate_opening_or_fullview_qualification', 'new_art_grade_or_final_visual_acceptance',
                        'earned_combat_or_performance_or_package_qualification']:
                self.assertIs(v['scope'][key], False)
        else:
            self.assertEqual(v['native_observation']['frame_count'], 8)
            self.assertEqual(v['historical_native_observation']['frame_count'], 48)
            self.assertIs(v['scope']['old94_wall_rendering_reused_as_current95'], False)
            self.assertEqual([r['chapter'] for r in v['native_observation']['chapters']], list(range(8)))
            self.assertTrue(all(len(r['frames']) == 1 and r['strict_supervision'] == 'PASS'
                                for r in v['native_observation']['chapters']))
            for key in ['new_three_pose_pistol_ABA_qualification', 'new_body_fullmatrix_or_555_qualification',
                        'new_gate_opening_or_fullview_qualification', 'new_art_grade_or_final_visual_acceptance',
                        'earned_combat_or_performance_or_package_qualification']:
                self.assertIs(v['scope'][key], False)
            self.assertIn('idle only', v['scope']['pistol_pose_observed'])
            self.assertIn('visual correction', v['scope']['occlusion_limits'])

    def test_foreign_current_consumer_asset_and_import_refuse(self):
        c.qualify(ROOT) # A refused baseline cannot prove a foreign-source negative.
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
        doc = json.loads(read(ROOT, c.RECEIPT95))
        for change in ['missing', 'source', 'frame', 'scope']:
            value = copy.deepcopy(doc)
            if change == 'source': value['current_source_overrides']['game/scripts/wall_architecture.gd']['sha256'] = '0' * 64
            elif change == 'frame': value['native_observation']['chapters'][0]['frames'].pop()
            elif change == 'scope': value['scope']['new_three_pose_pistol_ABA_qualification'] = True
            data = json.dumps(value).encode()
            def altered(root, relative):
                if relative != c.RECEIPT95: return read(root, relative)
                if change == 'missing': raise FileNotFoundError('missing current receipt')
                return data
            with self.subTest(change=change), patch.object(c, 'read_resident', side_effect=altered):
                with self.assertRaises((ValueError, FileNotFoundError)): c.qualify(ROOT)

    def test_historical_sources_are_explicit_snapshots_not_current_hash_swaps(self):
        v = c.qualify(ROOT)
        if v['schema'] == 'null-choir-exact-current-art-consumers-v0096-v1':
            # Current qualification already verified the immutable94 parent;
            # historical-source semantics belong to that exact retained record.
            v = c.pinned_receipt(ROOT, c.RECEIPT, c.RECEIPT_SHA)
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

    def test_parent94_is_immutable_and_missing_or_changed_parent_refuses(self):
        raw = (ROOT / c.RECEIPT).read_bytes()
        self.assertEqual(c.sha(raw), c.RECEIPT_SHA)
        read = c.read_resident
        with patch.object(c, 'read_resident', side_effect=lambda r,p: read(r,p)+b'changed' if p==c.RECEIPT else read(r,p)):
            with self.assertRaises(ValueError): c.qualify(ROOT)

    def test95_override_and_export_only_bridge_remain_narrow(self):
        v = json.loads((ROOT / c.RECEIPT95).read_text())
        self.assertEqual(set(v['current_source_overrides']), {'game/scripts/build_info.gd','game/scripts/wall_architecture.gd'})
        self.assertEqual(v['native_observation']['frame_count'], 8)
        self.assertFalse(v['export_metadata_bridge']['native_rerun_claimed'])
        self.assertEqual(v['export_metadata_bridge']['after']['path'], 'game/export_presets.cfg')
        self.assertTrue(all(r['display_label_actual']=='Null Choir v0.095' and r['display_label_visible'] is True for r in v['native_observation']['chapters']))

    def test_public_receipt_has_no_private_paths_or_quality_numbers(self):
        text = (ROOT / c.RECEIPT).read_text().lower() + (ROOT / c.RECEIPT95).read_text().lower()
        for token in ['/users/', '/private/', '/tmp/', '/home/', 'argv', 'home=', 'rating', 'rubric', 'score']:
            self.assertNotIn(token, text)


class ArtCIDependencyContract(unittest.TestCase):
    """Plain lock/workflow schema checks; no pip/network/engine execution."""
    HASHES = (
        "62f5409336adb0663b7caa0da5c7d9e7bdbaae9ce761d34669420c2a801b2780",
        "4bfd07bc812fbd20395212969e41931001fd59eb55a60658b0e5710872e95286",
    )

    @staticmethod
    def tokens(text):
        return ' '.join(line.strip().replace('\\','') for line in text.splitlines()
                        if line.strip() and not line.lstrip().startswith('#')).split()

    def test_exact_decoder_lock_and_controlled_schema_negatives(self):
        text=(ROOT/'.github/requirements-art-ci.txt').read_text()
        expected=['Pillow==12.2.0']+['--hash=sha256:'+h for h in self.HASHES]
        self.assertEqual(self.tokens(text),expected)
        for bad in [text.replace('12.2.0','12.2.1'),text.replace(self.HASHES[0],'0'*64),
                    text.replace('    --hash=sha256:'+self.HASHES[1],''),text+'other==1\n']:
            with self.subTest(bad=bad[-80:]):self.assertNotEqual(self.tokens(bad),expected)

    def test_one_pinned_Pillow_supplies_all_qualified_png_decoders(self):
        workflow=(ROOT/'.github/workflows/ossuary-art.yml').read_text()
        self.assertIn('python -m pip --isolated install',workflow)
        for flag in ['--only-binary=:all:','--require-hashes','--no-deps','--index-url https://pypi.org/simple','-r .github/requirements-art-ci.txt']:
            self.assertIn(flag,workflow)
        self.assertIn("assert PIL.__version__ == '12.2.0'",workflow)
        self.assertIn('      - .github/requirements-art-ci.txt',workflow)
        self.assertEqual((ROOT/'tools/art_consumer_compatibility.py').read_text().count('from PIL import Image'),2)
        self.assertEqual((ROOT/'source/art/consumer-qualification-v0096/provenance/later22_producer.py').read_text().count('from PIL import Image'),1)
        self.assertIn("python: ['3.12', '3.14']",workflow)
        self.assertIn('    timeout-minutes: 12',workflow)
        self.assertIn('    runs-on: ubuntu-latest',workflow)
        self.assertIn('  contents: read',workflow)
        self.assertIn('          persist-credentials: false',workflow)
        site=(ROOT/'.github/workflows/site.yml').read_text()
        self.assertIn('    timeout-minutes: 6',site)
        self.assertIn('  contents: read',site)
        self.assertIn('python3 -B tests/test_splash.py',site)
        for forbidden in ['deploy-pages','upload-pages-artifact','pages: write','id-token: write']:
            self.assertNotIn(forbidden,site)
        checks=[line.strip() for line in workflow.splitlines() if line.strip().startswith('python -B tests/')]
        self.assertEqual(checks,['python -B tests/test_ossuary_buttress.py', 'python -B tests/test_art.py', 'python -B tests/test_actor_body_art_ledger.py', 'python -B tests/test_main_body_selftest_contract.py', 'python -B tests/test_build_iterations.py', 'python -B tests/test_macos_archive_identity.py', 'python -B tests/test_macos_import.py', 'python -B tests/test_macos_recorded_audio.py', 'python -B tests/test_seal_guardians.py', 'python -B tests/test_seal_guardian_save_contract.py', 'python -B tests/test_seal_guardian_fixture_contract.py', 'python -B tests/test_wall_architecture.py', 'python -B tests/test_floor_wall_contact_contract.py', 'python -B tests/test_terrain_legacy_fixture_contract.py', 'python -B tests/test_art_consumer_compatibility.py', 'python -B tests/test_actor_raw_metadata_privacy.py', 'python -B tests/test_worker_regions.py', 'python -B tests/test_weapon_raster_ledger.py', 'python -B tests/test_rivet_forward_art_ledger.py', 'python -B tests/test_threshold_art_ledger.py', 'python -B tests/test_title_theme.py'])



# Exact verifier-only derivation; existing observation remains historical source.
PIN=c.MAIN96_VERIFIER_DERIVATION
OLD=c.record(ROOT,PIN['observed_snapshot'])
NEW=c.read_resident(ROOT,'game/scripts/main.gd')
class VerifierDerivationReader:
 def __init__(self,resident=NEW,snapshot=OLD):self.resident=resident;self.snapshot=snapshot
 def read_resident(self,root,path):
  if path==PIN['observed_main']['path']:return self.resident
  if path==PIN['observed_snapshot']['path']:return self.snapshot
  return c.read_resident(root,path)
 def record(self,root,row):
  raw=self.read_resident(root,row['path'])
  if len(raw)!=row['bytes']or c.sha(raw)!=row['sha256']:raise ValueError('Exact record drift')
  return raw
 def pinned_receipt(self,root,path,sha):
  raw=self.read_resident(root,path)
  if c.sha(raw)!=sha:raise ValueError('Pinned receipt drift')
  return json.loads(raw)
 sha=staticmethod(c.sha)
 function=staticmethod(c.function)
class Derivation(unittest.TestCase):
 def derive(self,reader=None):return c.verifier_main_derivation96(ROOT,PIN['observed_main'],reader or VerifierDerivationReader())
 def test_exact_old_generation_still_unmodified_without_derivation(self):self.assertIsNone(self.derive(VerifierDerivationReader(OLD)))
 def test_exact_new_and_inverse_all_other_bytes(self):
  value=self.derive();self.assertTrue(value['outside_verifier_bytes_exact']);self.assertFalse(value['new_frames_claimed']);self.assertFalse(value['new_native_import_claimed']);self.assertFalse(value['new_gameplay_observation_claimed'])
  self.assertEqual(set(value['changed_functions']),{'_export_art_checks','_verify_export'});self.assertEqual(set(value['added_functions']),{'_export_wall_architecture_checks'})
 def test_outside_verifier_runtime_mutation_even_rehashed_fullnew_refuses_inverse(self):
  raw=NEW.replace(b'func _ready() -> void:',b'func _ready() -> void:\n\tprint("foreign runtime mutation")',1);self.assertNotEqual(raw,NEW)
  changed=copy.deepcopy(PIN);changed['derived_main'].update(bytes=len(raw),sha256=c.sha(raw))
  with patch.object(c,'MAIN96_VERIFIER_DERIVATION',changed),self.assertRaisesRegex(ValueError,'outside approved'):c.verifier_main_derivation96(ROOT,changed['observed_main'],VerifierDerivationReader(raw))
 def test_unapproved_changed_and_added_verifier_payload_even_fullnew_rehash_refuses(self):
  for marker in [b'func _export_art_checks() -> Dictionary:',b'func _export_wall_architecture_checks() -> Dictionary:',b'func _verify_export() -> void:']:
   raw=NEW.replace(marker,marker+b'\n\tprint("unapproved verifier payload")',1);changed=copy.deepcopy(PIN);changed['derived_main'].update(bytes=len(raw),sha256=c.sha(raw))
   with self.subTest(marker=marker),patch.object(c,'MAIN96_VERIFIER_DERIVATION',changed),self.assertRaisesRegex(ValueError,'function pin drift'):c.verifier_main_derivation96(ROOT,changed['observed_main'],VerifierDerivationReader(raw))
 def test_current_snapshot_parent_row_and_pin_mutations_refuse(self):
  for reader in [VerifierDerivationReader(NEW+b'foreign'),VerifierDerivationReader(snapshot=OLD+b'foreign')]:
   with self.assertRaisesRegex(ValueError,'drift'):self.derive(reader)
  changed=copy.deepcopy(PIN);changed['changed_functions']['_verify_export']['new_sha256']='0'*64
  with patch.object(c,'MAIN96_VERIFIER_DERIVATION',changed),self.assertRaisesRegex(ValueError,'pin drift'):self.derive()
  bad=dict(PIN['observed_main'],sha256='0'*64)
  with self.assertRaisesRegex(ValueError,'record drift'):c.verifier_main_derivation96(ROOT,bad,VerifierDerivationReader())
 def test_duplicate_function_top_level_payload_and_addition_refuse(self):
  for raw in [NEW+b'\nfunc _export_art_checks() -> Dictionary:\n\treturn {}\n',NEW.replace(b'func _export_art_checks()',b'const FOREIGN_RUNTIME = 1\nfunc _export_art_checks()',1)]:
   changed=copy.deepcopy(PIN);changed['derived_main'].update(bytes=len(raw),sha256=c.sha(raw))
   with patch.object(c,'MAIN96_VERIFIER_DERIVATION',changed),self.assertRaises(ValueError):c.verifier_main_derivation96(ROOT,changed['observed_main'],VerifierDerivationReader(raw))
 def test_historical_read_view_is_one_exact_row_not_general_ignore(self):
  base=VerifierDerivationReader();derived=self.derive(base);view=c._observed_main_reader96(ROOT,derived,base)
  self.assertEqual(view.record(ROOT,PIN['observed_main']),OLD)
  with self.assertRaises(ValueError):view.record(ROOT,dict(PIN['observed_main'],sha256='0'*64))
  with self.assertRaises(ValueError):view.record(ROOT,{'path':'game/scripts/player.gd','bytes':1,'sha256':'0'*64})
 def test_private_producer_projection_only_main_and_exact_root(self):
  paths=[];producer=types.SimpleNamespace(_regular=lambda root,path:paths.append((root,path))or Path(root)/path)
  view=c._observed_main_reader96(ROOT,self.derive(),VerifierDerivationReader());c._project_captured_main96(producer,ROOT,view)
  self.assertEqual(producer._regular(ROOT,'game/scripts/player.gd'),ROOT/'game/scripts/player.gd')
  self.assertEqual(producer._regular(ROOT,'game/scripts/main.gd'),ROOT/PIN['observed_snapshot']['path'])
  with self.assertRaisesRegex(ValueError,'root drift'):producer._regular(ROOT/'foreign','game/scripts/main.gd')
  self.assertEqual(len(paths),3)
 def test_derived_generation_retained22_Player_and_threshold_consumption(self):
  # Derived resident Main and the immutable observed generation are distinct.
  # Existing46othercode/262art/22contexts/244PNGs/imports remain strict;
  # this performs retained evidence validation, not new native execution.
  self.assertEqual(c.sha((ROOT/'game/scripts/main.gd').read_bytes()),PIN['derived_main']['sha256'])
  result=c.qualify96(ROOT)
  self.assertEqual(result['status'],'ACTUAL96_GAMEPLAY_WITH_VERIFIER_ONLY_SOURCE_DERIVATION')
  self.assertEqual(result['current_sources']['game/scripts/main.gd'],PIN['derived_main'])
  self.assertEqual(result['observed_current_sources']['game/scripts/main.gd'],PIN['observed_main'])
  self.assertEqual(len(result['native_observation']['jobs']),22)
  self.assertEqual(sum(len(j['frames'])for j in result['native_observation']['jobs']),244)
  self.assertEqual(c.sha((ROOT/c.RECEIPT96).read_bytes()),c.RECEIPT96_SHA)
  self.assertTrue(c.qualified96_generation96(result))
  # Full22 qualification above is real retained-evidence validation. Only reuse
  # its completed result at downstream call boundaries, never fabricate native.
  player=c.read_resident(ROOT,'game/scripts/player.gd')
  with patch.object(c,'qualify96',return_value=result):
   retained=c.qualified_player_consumption96(ROOT,player)
   self.assertEqual(c.sha(retained),c.PLAYER_V5_HISTORICAL['sha256'])
   with self.assertRaisesRegex(ValueError,'Supplied Player'):c.qualified_player_consumption96(ROOT,player+b'foreign')
  spec=importlib.util.spec_from_file_location('derived_threshold',ROOT/'tools/threshold_art_ledger.py');threshold=importlib.util.module_from_spec(spec);spec.loader.exec_module(threshold)
  compat={'qualify':lambda root:result,'record':c.record,'qualified96_generation96':c.qualified96_generation96}
  with patch.object(threshold,'_current_consumer_compatibility',return_value=compat):
   for relative in ['game/scripts/main.gd','game/scripts/level.gd']:
    historical=result['historical_sources'][relative]
    old=threshold._qualified96_threshold_source(ROOT,relative,c.read_resident(ROOT,relative),historical['sha256'])
    self.assertEqual(c.sha(old),historical['sha256'])
    with self.assertRaisesRegex(ValueError,'Supplied threshold'):threshold._qualified96_threshold_source(ROOT,relative,c.read_resident(ROOT,relative)+b'foreign',historical['sha256'])
  for field in ['verifier_source_derivation','observed_current_sources','current_sources']:
   bad=copy.deepcopy(result)
   if field=='verifier_source_derivation':bad[field]['new_frames_claimed']=True
   else:bad[field]['game/scripts/main.gd']['sha256']='0'*64
   self.assertFalse(c.qualified96_generation96(bad))
  bad=copy.deepcopy(result);bad['status']='ACTUAL_CURRENT96_MOVING_CONTEXTS_OBSERVED';self.assertFalse(c.qualified96_generation96(bad))


if __name__ == '__main__':
    unittest.main()
