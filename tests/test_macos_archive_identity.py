"""Pure exported-artifact selection/identity controls; no native or app launches."""
import importlib.util,json
from pathlib import Path
import tempfile,unittest
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('macos_archive_validator',ROOT/'tests/test_macos.py')
validator=importlib.util.module_from_spec(spec);spec.loader.exec_module(validator)
spec=importlib.util.spec_from_file_location('macos_archive_builder',ROOT/'tools/build_macos.py')
builder=importlib.util.module_from_spec(spec);spec.loader.exec_module(builder)
class ArchiveIdentity(unittest.TestCase):
 def fixture(self,root,next_version=False):
  data=json.loads((ROOT/validator._versions.LEDGER).read_text())
  if next_version:data=validator._versions.reserve(data,'synthetic-next-validator-test',validator._versions.validate(data))
  p=root/validator._versions.LEDGER;p.parent.mkdir(parents=True);p.write_text(json.dumps(data))
  return data
 def test_current_default_matches_canonical_builder(self):
  current=validator._versions.validate(json.loads((ROOT/validator._versions.LEDGER).read_text()))
  self.assertEqual(validator.build_identity()['archive_name'],f'Null-Choir-v0.{current:03d}.zip')
  self.assertEqual(builder.OUTPUT,ROOT/'builds/macos'/validator.build_identity()['archive_name'])
  with tempfile.TemporaryDirectory() as tmp:
   root=Path(tmp);self.fixture(root);p=root/'builds/macos'/validator.build_identity(root)['archive_name'];p.parent.mkdir(parents=True);p.write_bytes(b'path-selection-only')
   self.assertEqual(validator.selected_archive([],root),p)
 def test_synthetic_next_version_is_derived_from_current_ledger(self):
  with tempfile.TemporaryDirectory() as tmp:
   root=Path(tmp);data=self.fixture(root,True)
   next_ordinal=validator._versions.validate(data)
   self.assertEqual(validator.build_identity(root)['version'],f'0.{next_ordinal:03d}')
   p=root/'builds/macos'/f'Null-Choir-v0.{next_ordinal:03d}.zip';p.parent.mkdir(parents=True);p.write_bytes(b'path-selection-only')
   self.assertEqual(validator.selected_archive([],root),p)
 def test_explicit_artifact_override_retained(self):
  with tempfile.TemporaryDirectory() as tmp:
   root=Path(tmp);self.fixture(root);p=root/'explicit-other-location.zip';p.write_bytes(b'path-selection-only')
   self.assertEqual(validator.selected_archive([str(p)],root),p)
 def test_missing_current_refuses_even_with_old_stale_archive_present(self):
  with tempfile.TemporaryDirectory() as tmp:
   root=Path(tmp);self.fixture(root);p=root/'builds/macos/NULL CHOIR-arm64.zip';p.parent.mkdir(parents=True);p.write_bytes(b'old-stale')
   current=validator.build_identity(root)
   if current['ordinal']>94:
    previous=p.parent/validator._versions.identity(current['ordinal']-1)['archive_name'];previous.write_bytes(b'previous-issued-artifact')
   with self.assertRaises(FileNotFoundError) as error:validator.selected_archive([],root)
   self.assertIn(current['archive_name'],str(error.exception))
 def test_missing_explicit_override_does_not_fall_back_to_current(self):
  with tempfile.TemporaryDirectory() as tmp:
   root=Path(tmp);self.fixture(root);p=root/'builds/macos'/validator.build_identity(root)['archive_name'];p.parent.mkdir(parents=True);p.write_bytes(b'current')
   with self.assertRaises(FileNotFoundError):validator.selected_archive([str(root/'missing-override.zip')],root)
 def test_no_native_or_temp_extraction_when_default_missing(self):
  with patch.object(validator,'selected_archive',side_effect=FileNotFoundError('missing current')),patch.object(validator.subprocess,'run') as run,patch.object(validator.tempfile,'TemporaryDirectory') as temp:
   with self.assertRaises(FileNotFoundError):validator.main()
   run.assert_not_called();temp.assert_not_called()
 def test_main_uses_one_identity_snapshot_for_selection_and_verification(self):
  class StopBeforeExtraction(Exception):pass
  expected=validator.build_identity()
  with patch.object(validator,'build_identity',return_value=expected) as identity,patch.object(validator,'selected_archive',side_effect=StopBeforeExtraction) as select:
   with self.assertRaises(StopBeforeExtraction):validator.main()
   identity.assert_called_once_with();select.assert_called_once_with(identity=expected)
 def test_bundle_identity_current_next_and_stale_refusal(self):
  current=validator.build_identity()['ordinal']
  for ordinal in [current,current+1]:
   identity=validator._versions.identity(ordinal)
   info={'CFBundleName':identity['display_name'],'CFBundleShortVersionString':identity['version'],'CFBundleVersion':identity['cfbundle_version']}
   app=Path(identity['app_name']);validator.require_build_identity(app,info,identity)
   for field,value in [('CFBundleName','NULL CHOIR'),('CFBundleShortVersionString','0.2.3'),('CFBundleVersion','0.2.3'),('CFBundleDisplayName','Stale app')]:
    bad={**info,field:value}
    with self.assertRaises(AssertionError):validator.require_build_identity(app,bad,identity)
   with self.assertRaises(AssertionError):validator.require_build_identity(Path('NULL CHOIR.app'),info,identity)
 def test_historical94_is_named_fixture_not_current_default(self):
  historical=validator._versions.identity(94)
  self.assertEqual(historical['archive_name'],'Null-Choir-v0.094.zip')
  self.assertEqual(historical['version'],'0.094')
  self.assertEqual(historical['cfbundle_version'],'94')
  current=validator.build_identity()
  if current['ordinal']!=94:
   old_info={'CFBundleName':historical['display_name'],'CFBundleShortVersionString':historical['version'],'CFBundleVersion':historical['cfbundle_version']}
   with self.assertRaises(AssertionError):validator.require_build_identity(Path(historical['app_name']),old_info,current)
 def test_explicit_path_is_not_a_bundle_identity_waiver(self):
  identity=validator.build_identity()
  with self.assertRaises(AssertionError):validator.require_build_identity(Path('Old.app'),{'CFBundleShortVersionString':'0.2.3','CFBundleVersion':'0.2.3'},identity)
 def test_failed_latest_refuses_before_extraction_even_with_existing_artifact(self):
  original_identity=validator.build_identity
  with tempfile.TemporaryDirectory() as tmp:
   root=Path(tmp);data=self.fixture(root);ordinal=validator._versions.validate(data)
   expected=validator._versions.identity(ordinal)
   failed=validator._versions.mark_failed(data,data['allocations'][-1]['candidate'],ordinal,'pure validator retired-candidate fixture')
   (root/validator._versions.LEDGER).write_text(json.dumps(failed))
   self.assertEqual(validator._versions.validate(failed),ordinal) # History/reserve validation stays legal.
   archive=root/'builds/macos'/expected['archive_name'];archive.parent.mkdir(parents=True);archive.write_bytes(b'existing-but-failed-candidate')
   with self.assertRaisesRegex(ValueError,'Failed ordinal is retired'):validator.selected_archive([],root)
   for arguments in [[],[str(archive)]]:
    with patch.object(validator.sys,'argv',['test_macos.py',*arguments]),patch.object(validator,'build_identity',side_effect=lambda:original_identity(root)),patch.object(validator.subprocess,'run') as run,patch.object(validator.subprocess,'check_output') as output,patch.object(validator.tempfile,'TemporaryDirectory') as extraction:
     with self.assertRaisesRegex(ValueError,'Failed ordinal is retired'):validator.main()
     run.assert_not_called();output.assert_not_called();extraction.assert_not_called()
 def test_invalid_ledger_and_extra_arguments_refuse(self):
  with tempfile.TemporaryDirectory() as tmp:
   root=Path(tmp);data=self.fixture(root);data['allocations'][0]['ordinal']+=1
   (root/validator._versions.LEDGER).write_text(json.dumps(data))
   with self.assertRaises(ValueError):validator.selected_archive([],root)
  with self.assertRaises(ValueError):validator.selected_archive(['one.zip','two.zip'])
if __name__=='__main__':unittest.main()
