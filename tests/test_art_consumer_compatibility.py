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
        if v['schema'] == 'null-choir-exact-current-art-consumers-v0097-v1':
            self.assertEqual(v['status'], 'ACTUAL_CURRENT97_ORDINARY_THREAT_CONTEXTS_OBSERVED')
            self.assertEqual(len(v['native_observation']['frames']),214)
            self.assertEqual(v['scope'],c.SCOPE97)
            self.assertEqual(len(v['historical_native_observation']['jobs']),22)
            self.assertIs(v['historical96_reuse']['current97_observation_claimed'],False)
        elif v['schema'] == 'null-choir-exact-current-art-consumers-v0096-v1':
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
        if v['schema'] in ('null-choir-exact-current-art-consumers-v0096-v1',
                           'null-choir-exact-current-art-consumers-v0097-v1'):
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
        self.assertEqual((ROOT/'tools/art_consumer_compatibility.py').read_text().count('from PIL import Image'),4)
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
# Historical verifier-only unit fixture, not the changed current97 Main.
NEW=c.read_resident(ROOT,'source/art/consumer-qualification-v0097/provenance/main-v96-verifier-only.gd')
assert c.sha(NEW) == PIN['derived_main']['sha256']
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
 def test_current97_is_not_a_verifier_only96_derivation(self):
  with self.assertRaisesRegex(ValueError,'resident Main drift'):
   c.verifier_main_derivation96(ROOT,PIN['observed_main'],VerifierDerivationReader(c.read_resident(ROOT,'game/scripts/main.gd')))


class Source97Scaffolding(unittest.TestCase):
 """Static binding and strict historical reuse; NOT current97 native acceptance."""
 def test_exact_static_inventory_and_scope(self):
  value=c.validate_source97(ROOT)
  self.assertEqual(set(value['current_sources']),c.REQUIRED97_SOURCES)
  self.assertEqual(len(value['current_art_resources']),262)
  self.assertEqual(set(value['historical96_snapshots']),c.HISTORICAL96_PATHS97)
  self.assertIs(value['scope']['new_native_observation'],False)
  self.assertIs(value['scope']['qualification'],False)
 def test_source_import_and_historical_mutation_refuse_before_receipt(self):
  source=c.validate_source97(ROOT);read=c.read_resident
  targets=['game/scripts/enemy_motion.gd','game/scripts/enemy_telegraph.gd',
           'game/scripts/player.gd','game/scripts/main.gd',
           'game/assets/art/weapons/native-v5/rivet_pistol.png',
           'game/assets/art/healing_machinery/models/capillary-organ.glb.import',
           source['historical96_snapshots']['game/scripts/player.gd']['snapshot']['path']]
  for target in targets:
   with self.subTest(target=target),patch.object(c,'read_resident',side_effect=lambda r,p:read(r,p)+(b'foreign' if p==target else b'')):
    with self.assertRaisesRegex(ValueError,'drift'):c.validate_source97(ROOT)
 def test_source_contract_rehash_or_receipt_pin_alone_cannot_qualify(self):
  read=c.read_resident;raw=read(ROOT,c.SOURCE97)
  with patch.object(c,'read_resident',side_effect=lambda r,p:raw+b' ' if p==c.SOURCE97 else read(r,p)):
   with self.assertRaisesRegex(ValueError,'receipt'):c.validate_source97(ROOT)
  if c.RECEIPT97_SHA is None:
   with self.assertRaisesRegex(ValueError,'remains unpinned'):c.qualify97(ROOT)
   with patch.object(c,'RECEIPT97_SHA','0'*64),self.assertRaises((ValueError,FileNotFoundError)):
    c.qualify97(ROOT)
 def test_historical_view_only_exact_rows_and_root(self):
  value=c.validate_source97(ROOT);view=c._historical96_reader97(ROOT,value)
  for relative,binding in value['historical96_snapshots'].items():
   old=view.record(ROOT,binding['observed96'])
   self.assertEqual(c.sha(old),binding['snapshot']['sha256'])
   with self.assertRaisesRegex(ValueError,'record drift'):view.record(ROOT,dict(binding['observed96'],sha256='0'*64))
  with self.assertRaisesRegex(ValueError,'root drift'):view.read_resident(ROOT/'foreign','game/scripts/player.gd')
  self.assertEqual(view.read_resident(ROOT,'game/scripts/enemy_motion.gd'),c.read_resident(ROOT,'game/scripts/enemy_motion.gd'))
 def test_full_retained96_evidence_is_explicitly_historical(self):
  result=c.validate_historical96_reuse97(ROOT)
  self.assertEqual(result['status'],'HISTORICAL96_REVALIDATED_NOT_CURRENT97')
  self.assertIs(result['current97_observation_claimed'],False)
  old=result['qualification']
  self.assertEqual(old['status'],'ACTUAL_CURRENT96_MOVING_CONTEXTS_OBSERVED')
  self.assertEqual(len(old['native_observation']['jobs']),22)
  self.assertEqual(sum(len(j['frames']) for j in old['native_observation']['jobs']),244)
  self.assertFalse(c.qualified97_generation97(old))
 def test_public97_contract_has_no_private_paths_or_quality_numbers(self):
  raw=c.read_resident(ROOT,c.SOURCE97).decode().lower()
  for token in ['/users/','/private/','/tmp/','/home/','argv','home=','rating','rubric','score']:
   self.assertNotIn(token,raw)


class Current97Joins(unittest.TestCase):
 """Exact retained technical evidence and refusals; no engine/visual grading."""
 def test_actual_portable_join_and_historical_Player_binding(self):
  value=c.qualify97(ROOT)
  self.assertTrue(c.qualified97_generation97(value))
  self.assertFalse(c.qualified96_generation96(value))
  self.assertEqual(value['scope'],c.SCOPE97)
  current=c.read_resident(ROOT,'game/scripts/player.gd')
  # Reuse the completed strict result only at downstream boundaries.
  with patch.object(c,'qualify',return_value=value):
   old=c.qualified_player_consumption96(ROOT,current)
   self.assertEqual(c.sha(old),c.PLAYER_V5_HISTORICAL['sha256'])
   with self.assertRaisesRegex(ValueError,'Supplied Player'):
    c.qualified_player_consumption96(ROOT,current+b'foreign')
  self.assertNotEqual(old,current)
 def test_missing_changed_or_self_rehashed97_receipt_refuses(self):
  raw=c.read_resident(ROOT,c.RECEIPT97);read=c.read_resident
  for mode in ('missing','source','frame','scope'):
   value=json.loads(raw)
   if mode=='source':value['current_sources']['game/scripts/enemy_motion.gd']['sha256']='0'*64
   if mode=='frame':value['native_observation']['frames'].pop()
   if mode=='scope':value['scope']['human_input_or_listening']=True
   changed=json.dumps(value).encode()
   def altered(root,path):
    if path!=c.RECEIPT97:return read(root,path)
    if mode=='missing':raise FileNotFoundError('missing97 receipt')
    return changed
   with self.subTest(mode=mode),patch.object(c,'read_resident',side_effect=altered):
    with self.assertRaises((ValueError,FileNotFoundError)):c.qualify97(ROOT)
 def test_unknown_missing_partial_report_and_native_identity_refuse(self):
  receipt=c.pinned_receipt(ROOT,c.RECEIPT97,c.RECEIPT97_SHA);contract=c.validate_source97(ROOT)
  read=c._public97_json
  for mode in ('unknown_frame','missing_frame','partial','native'):
   def altered(root,row):
    value=copy.deepcopy(read(root,row))
    if row==c.PUBLIC97_BINDINGS['trace']:
     if mode=='unknown_frame':value['frames'][0]['file']='foreign.png'
     if mode=='missing_frame':value['frames'].pop()
     if mode=='partial':value['completed_chapters'].pop()
    if row==c.PUBLIC97_BINDINGS['native_identity'] and mode=='native':value['rendering_driver']='foreign'
    return value
   with self.subTest(mode=mode),patch.object(c,'_public97_json',side_effect=altered):
    with self.assertRaises(ValueError):c.validate_capture_context_join97(ROOT,receipt,contract)
 def test_frame_producer_trace_and_memo_replay_tamper_refuse(self):
  # Warm a real completed audit, then alter actual read bytes underneath it.
  value=c.qualify97(ROOT);read=Path.read_bytes
  targets=[ROOT/value['native_observation']['frames'][0]['path'],
           ROOT/value['native_observation']['supplement']['frames'][0]['path'],
           ROOT/c.PUBLIC97_BINDINGS['producer']['path'],
           ROOT/c.PUBLIC97_SUPPLEMENT_BINDINGS['producer']['path'],
           ROOT/c.PUBLIC97_BINDINGS['trace']['path'],
           ROOT/'game/scripts/enemy_motion.gd',
           ROOT/'game/assets/art/weapons/painted-v3/impact_tool.png']
  for target in targets:
   with self.subTest(target=str(target.relative_to(ROOT))),patch.object(Path,'read_bytes',lambda path:read(path)+(b'foreign' if path==target else b'')):
    with self.assertRaises(ValueError):c.qualify97(ROOT)
 def test_threshold_dispatch_is_explicit97_and_exact_source_only(self):
  value=c.qualify97(ROOT)
  spec=importlib.util.spec_from_file_location('threshold97',ROOT/'tools/threshold_art_ledger.py')
  threshold=importlib.util.module_from_spec(spec);spec.loader.exec_module(threshold)
  compat={'qualify':lambda root:value,'record':c.record,
          'qualified96_generation96':c.qualified96_generation96,
          'qualified97_generation97':c.qualified97_generation97}
  with patch.object(threshold,'_current_consumer_compatibility',return_value=compat):
   for relative in ('game/scripts/main.gd','game/scripts/level.gd'):
    current=c.read_resident(ROOT,relative);row=value['historical_sources'][relative]
    old=threshold._qualified96_threshold_source(ROOT,relative,current,row['sha256'])
    self.assertEqual(c.sha(old),row['sha256'])
    with self.assertRaisesRegex(ValueError,'Supplied threshold'):
     threshold._qualified96_threshold_source(ROOT,relative,current+b'foreign',row['sha256'])
 def test_unknown_source_directory_member_refuses_even_after_memo(self):
  c.qualify97(ROOT)
  glob=Path.glob
  def extra(path,pattern):
   rows=list(glob(path,pattern))
   if path==ROOT/'game/scripts' and pattern=='*.gd':rows.append(path/'foreign.gd')
   return iter(rows)
  with patch.object(Path,'glob',extra),self.assertRaisesRegex(ValueError,'foreign source script'):
   c.qualify97(ROOT)
 def test_receipt_and_public_metadata_privacy(self):
  paths=[c.RECEIPT97,*[row['path'] for key,row in c.PUBLIC97_BINDINGS.items() if key!='producer'],
         *[row['path'] for key,row in c.PUBLIC97_SUPPLEMENT_BINDINGS.items() if key not in ('producer','base_producer')]]
  for path in paths:
   raw=c.read_resident(ROOT,path).decode().lower()
   for token in ('/users/','/private/','/tmp/','/home/','argv','home=','rating','rubric','score'):
    self.assertNotIn(token,raw)
 def test_supplement_missing_unknown_UI_and_timing_controls_refuse(self):
  receipt=c.pinned_receipt(ROOT,c.RECEIPT97,c.RECEIPT97_SHA);contract=c.validate_source97(ROOT)
  read=c._public97_json
  for mode in ('partial','unknown_frame','UI','timing'):
   def altered(root,row):
    value=copy.deepcopy(read(root,row))
    if row==c.PUBLIC97_SUPPLEMENT_BINDINGS['trace']:
     if mode=='partial':value['completed_chapters'].pop()
     if mode=='unknown_frame':value['frames'][0]['file']='foreign.png'
     if mode=='UI':
      drain=next(x for x in value['arrangements'] if x['kind']=='natural_UI_transient_drain_before_pair')
      drain['damage_flash']=.5
     if mode=='timing':
      event=next(x for x in value['events'] if x['kind']=='warmed_alternating_draw_readback_not_GPU_or_FPS')
      event['batches'][1]['energy']=.65
    return value
   with self.subTest(mode=mode),patch.object(c,'_public97_json',side_effect=altered):
    with self.assertRaises(ValueError):c.validate_supplement_join97(ROOT,receipt,contract)


if __name__ == '__main__':
    unittest.main()
