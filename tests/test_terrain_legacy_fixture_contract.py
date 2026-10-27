"""Pure fixture contract/model checks only; does not execute GDScript or Godot."""
from pathlib import Path
import copy,json,re,unittest,posixpath
ROOT=Path(__file__).resolve().parents[1]
EXPECTED={0:'intake_enemy_19',1:'foundry_enemy_17',2:'processional_enemy_23',3:'reliquary_enemy_28',5:'ossuary_enemy_25',6:'inversion_enemy_26'}
def expected_model(document,index):
 result=copy.deepcopy(document)
 for envelope in [result,result['checkpoint'],result['level_start']]:
  if 'seal_drops' in envelope or 'legacy_exit_wardens' in envelope:return {}
  envelope['seal_drops']=[]
  envelope['legacy_exit_wardens']=[EXPECTED[index]] if index in EXPECTED else []
 return result
class LegacyFixtureContract(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.save=(ROOT/'game/tests/test_terrain_save_migration.gd').read_text()
  cls.scale=(ROOT/'game/tests/test_terrain_scale_migration.gd').read_text()
 def test_original_failure_is_invalid_modern_staging_not_product_waiver(self):
  product=(ROOT/'game/scripts/campaign.gd').read_text()
  self.assertIn('if (key.key in data.keys) != (key.id in data.removed): return false',product)
  for owned,retired in [(True,False),(False,True)]:self.assertNotEqual(owned,retired)
  self.assertNotIn('Campaign._migrate',self.save)
 def test_exact_six_independent_exit_expectations_no_old_boss_waiver(self):
  block=self.save.split('const LEGACY_CODEC_EXIT_WARDENS = {',1)[1].split('}',1)[0]
  parsed={int(i):name for i,name in re.findall(r'(\d):"([a-z_0-9]+)"',block)}
  self.assertEqual(parsed,EXPECTED)
  self.assertNotIn(4,parsed);self.assertNotIn(7,parsed)
 def test_both_collected_keys_stage_matching_ids_and_absent_fields_each_envelope(self):
  stage=self.save.split('func staged_document(',1)[1].split('func mesh_witness',1)[0]
  self.assertIn('for snapshot in [document,document.checkpoint,document.level_start]:',stage)
  for line in ['snapshot.erase("seal_drops")','snapshot.erase("legacy_exit_wardens")','snapshot.keys = keys','if key.kind == "key" and not key.id in snapshot.removed: snapshot.removed.append(key.id)']:
   self.assertIn(line,stage)
  self.assertIn('var input_image: PackedByteArray = var_to_bytes(document)',self.save)
  self.assertIn('var_to_bytes(document) == input_image',self.save)
 def test_canonical_expectation_adds_only_two_explicit_fields(self):
  body=self.save.split('func expected_legacy_codec(',1)[1].split('func canonical_codec_equal',1)[0]
  self.assertIn('document.duplicate(true)',body)
  self.assertNotIn('.erase(',body)
  self.assertNotIn('Campaign.',body)
  self.assertIn('snapshot["seal_drops"] = []',body)
  self.assertIn('snapshot["legacy_exit_wardens"] = [LEGACY_CODEC_EXIT_WARDENS[index]] if LEGACY_CODEC_EXIT_WARDENS.has(index) else []',body)
  self.assertIn('JSON.stringify(actual,"",true,true) == JSON.stringify(expected,"",true,true)',self.save)
  resources={'health':73,'ammo':[0,37,0,0,0,0],'keys':['blood','ivory'],'removed':['blood_key','ivory_key'],'actors':[{'id':'living','hp':50,'position':[1,2,3],'yaw':.73,'alerted':False}],'position':[4,5,6]}
  original={**copy.deepcopy(resources),'checkpoint':copy.deepcopy(resources),'level_start':copy.deepcopy(resources),'version':1}
  before=copy.deepcopy(original)
  for index in range(8):
   expected=expected_model(original,index)
   self.assertNotEqual(json.dumps(expected,sort_keys=True),json.dumps(original,sort_keys=True)) # Raw old byte-parity fails by design.
   for name in ['current','checkpoint','level_start']:
    old=original if name=='current' else original[name];new=expected if name=='current' else expected[name]
    for key in old:
     if key not in ['checkpoint','level_start']:self.assertEqual(new[key],old[key])
   self.assertEqual(original,before)
  modern=copy.deepcopy(original);modern['checkpoint']['seal_drops']=[]
  self.assertEqual(expected_model(modern,0),{})
 def test_independent_full_image_negatives_each_envelope(self):
  body=self.save.split('func check_canonical_parity_negatives',1)[1].split('func staged_document',1)[0]
  self.assertIn('for envelope in ["current","checkpoint","level_start"]:',body)
  for field in ['health','ammo','actor','seal_drops','legacy_exit_wardens','foreign-field']:self.assertIn('"'+field+'"',body)
  self.assertIn('not canonical_codec_equal(bad,expected)',body)
  for term in ['func check_modern_seal_negatives','owned-without-retired','retired-without-owned','not destination.from_dict(bad) and destination.to_dict() == before']:
   self.assertIn(term,self.save)
  for env in ['current','checkpoint','level_start']:
   resources={'health':73,'ammo':[0,37],'actors':[{'hp':50}]}
   original={'checkpoint':copy.deepcopy(resources),'level_start':copy.deepcopy(resources),**copy.deepcopy(resources)}
   expected=expected_model(original,0)
   for field in ['health','ammo','actors','seal_drops','legacy_exit_wardens','foreign-field']:
    bad=copy.deepcopy(expected);target=bad if env=='current' else bad[env];target[field]='different'
    self.assertNotEqual(json.dumps(bad,sort_keys=True),json.dumps(expected,sort_keys=True))
 def test_scale_control_has_no_missing_pending_drops_or_fabricated_inventory(self):
  setup=self.scale.split('document.removed =',1)[1].split('var state = Campaign.new()',1)[0]
  for line in ['document.erase("seal_drops")','document.erase("legacy_exit_wardens")','document.keys.append(key.key)','document.removed.append(key.id)']:self.assertIn(line,setup)
  self.assertNotIn('document.ammo',setup);self.assertNotIn('document.health',setup)
  for guard in ['Actual world XZ preserved','Actual native','Rescaled load is exactly idempotent']:
   if guard=='Actual native':self.assertIn('actual native collision',self.scale)
   else:self.assertIn(guard,self.scale)
 def test_original_terrain_atomic_negative_cases_retained(self):
  for defect in ['old-below-floor','nonfinite','overflow','future','mixed-revision','health','future-floor','zero-v2','nan','revision-bool','revision-fraction']:
   self.assertIn('"'+defect+'"',self.save)
  self.assertIn('not state.from_dict(bad) and state.to_dict() == migrated and var_to_bytes(bad) == untouched',self.save)
  self.assertIn('Unsafe transformed headroom rejects atomically AFTER legacy geometry validation',self.save)
 def test_optional_home_override_preserves_exact_disposable_guards(self):
  for source,home_var in [(self.save,'private_home'),(self.scale,'home')]:
   for term in ['OS.get_environment("NULL_CHOIR_TERRAIN_FIXTURE_HOME")','home_override.is_empty() or (home_override.is_absolute_path()','home_override == home_override.simplify_path()','home_override.get_file() in ["home","validation-home"]','not home_override in ["/root","/var/root","/Users/"+user,"/home/"+user]','if not override_safe or fixture.is_empty()','OS.get_environment("HOME")','OS.get_user_data_dir().begins_with('+home_var+'+"/")']:
    self.assertIn(term,source)
  # Pure path/guard model only. No native, HOME mutation or filesystem writes.
  def admit(fixture,override,env_home,userdata,project,user='fixture-user'):
   derived=posixpath.dirname(posixpath.dirname(fixture))+'/home'
   private=override or derived
   safe=not override or (override.startswith('/') and override==posixpath.normpath(override) and posixpath.basename(override) in ['home','validation-home'] and posixpath.dirname(override)!='/' and override not in ['/root','/var/root','/Users/'+user,'/home/'+user])
   return bool(safe and fixture and project==fixture and env_home==private and userdata.startswith(private+'/'))
  fixture='/tmp/fixture/project/game';default='/tmp/fixture/home';dedicated='/owned/K/terrain-ci01/validation-home'
  self.assertTrue(admit(fixture,'',default,default+'/userdata',fixture))
  self.assertTrue(admit(fixture,dedicated,dedicated,dedicated+'/userdata',fixture))
  for override,home,data,project in [('/Users/fixture-user','/Users/fixture-user','/Users/fixture-user/userdata',fixture),('/home/fixture-user','/home/fixture-user','/home/fixture-user/userdata',fixture),('/', '/', '/userdata',fixture),('relative/home','relative/home','relative/home/userdata',fixture),('/owned/../owned/home','/owned/../owned/home','/owned/../owned/home/userdata',fixture),(dedicated,default,dedicated+'/userdata',fixture),(dedicated,dedicated,dedicated+'-other/userdata',fixture),(dedicated,dedicated,dedicated+'/userdata','/different/game')]:
   self.assertFalse(admit(fixture,override,home,data,project),(override,home,data,project))
if __name__=='__main__':unittest.main()
