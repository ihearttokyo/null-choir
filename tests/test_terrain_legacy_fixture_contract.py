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
  body=self.save.split('func expected_legacy_codec(',1)[1].split('\nfunc ',1)[0]
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
 def test_removed_carrier_setup_is_explicit_and_never_repairs_negative_inputs(self):
  actor=(ROOT/'game/tests/test_actor_snapshot_trust.gd').read_text()
  helper=actor.split('func arrange_collected_removed_equipment(',1)[1].split('func expected_actor_disk_codec',1)[0]
  for term in ['if not grant.carrier in snapshot.removed: continue','snapshot.earned_supply.loot_drops.is_empty()','book.loot_claimed.append(grant.id)','grant.kind == "unlock"','snapshot.owned_weapons.append(int(grant.weapon))','supply.valid(book,snapshot,layout,difficulty)']:
   self.assertIn(term,helper)
  for forbidden in ['.ammo','.health','.armor','loot_drops = []','healing_remaining =']:
   self.assertNotIn(forbidden,helper)
  fresh=actor.split('func fresh_document(',1)[1].split('func check_births',1)[0]
  self.assertNotIn('arrange_collected_removed_equipment(',fresh)
  self.assertEqual(actor.count('arrange_collected_removed_equipment('),3) # definition +2 positive builders
  setup=self.scale.split('document.removed =',1)[1].split('documents.append(document)',1)[0]
  self.assertIn('arrange_collected_removed_equipment(document,old_layout,mode)',setup)
  self.assertIn('if not prepared:',setup);self.assertIn('if not prepared_envelopes:',setup)
  self.assertGreaterEqual(setup.count('write_map(path,source_text)'),3)
  self.assertIn('snapshot.actors.size()==1 and snapshot.earned_supply==document.earned_supply',setup)

 def test_pure_finite_collected_entitlements_model_and_negatives(self):
  registry=json.loads((ROOT/'game/data/earned_supplies.json').read_text())['chapters']
  def valid(snapshot,content):
   book=snapshot['earned_supply'];grants={g['id']:g for g in content['grants']};claimed=book['loot_claimed']
   return (not book['loot_drops'] and len(claimed)==len(set(claimed))
    and all(i in grants and (grants[i]['carrier']in snapshot['removed']or grants[i]['legacy_alias']in snapshot['removed']) and (grants[i]['kind']!='unlock'or grants[i]['weapon']in snapshot['owned_weapons'])for i in claimed)
    and all(g['carrier']not in snapshot['removed']or g['id']in claimed for g in grants.values())
    and all(0<=book['healing_remaining'][row['id']]<=row['capacity']for row in content['stations']))
  def arrange(snapshot,content):
   out=copy.deepcopy(snapshot)
   for g in content['grants']:
    if g['carrier']not in out['removed']:continue
    if g['id']not in out['earned_supply']['loot_claimed']:out['earned_supply']['loot_claimed'].append(g['id'])
    if g['kind']=='unlock'and g['weapon']not in out['owned_weapons']:out['owned_weapons'].append(g['weapon'])
   out['owned_weapons'].sort();return out
  for chapter in ['intake','nursery']:
   content=registry[chapter];carriers={g['carrier']for g in content['grants']};kept='intake_enemy_00'if chapter=='intake'else ''
   old={'removed':sorted(carriers-{kept}),'owned_weapons':[0,1],'ammo':[0,90,0,0,0,0],'health':73,'earned_supply':{'version':1,'revision':1,'loot_drops':[],'loot_claimed':[],'healing_remaining':{row['id']:row['capacity']for row in content['stations']}}}
   self.assertFalse(valid(old,content));new=arrange(old,content);self.assertTrue(valid(new,content))
   self.assertEqual(new['ammo'],old['ammo']);self.assertEqual(new['health'],old['health']);self.assertEqual(new['earned_supply']['healing_remaining'],old['earned_supply']['healing_remaining']);self.assertFalse(new['earned_supply']['loot_drops'])
   for mode in range(3):
    image={**copy.deepcopy(new),'checkpoint':copy.deepcopy(new),'level_start':copy.deepcopy(new)}
    for envelope in [image,image['checkpoint'],image['level_start']]:self.assertTrue(valid(envelope,content))
   for defect in ['missing','duplicate','foreign','stock']:
    bad=copy.deepcopy(new)
    if defect=='missing':bad['earned_supply']['loot_claimed'].pop()
    if defect=='duplicate':bad['earned_supply']['loot_claimed'].append(bad['earned_supply']['loot_claimed'][0])
    if defect=='foreign':bad['earned_supply']['loot_claimed'].append('foreign')
    if defect=='stock':bad['earned_supply']['healing_remaining'][content['stations'][0]['id']]=-1
    self.assertFalse(valid(bad,content),defect)
   if chapter=='nursery':
    bad=copy.deepcopy(new);bad['owned_weapons']=[0,1];self.assertFalse(valid(bad,content))

 def test_empty_living_positive_collects_exact_modern_seal_pairs(self):
  actor=(ROOT/'game/tests/test_actor_snapshot_trust.gd').read_text()
  positive=actor.split('var empty = document.duplicate(true)',1)[1].split('state.restore_level_start()',1)[0]
  for term in ['key.get("seal_bearer","") in empty.removed','empty.keys.append(key.key)','empty.removed.append(key.id)','arrange_collected_removed_equipment(empty,empty_layout,difficulty)']:
   self.assertIn(term,positive)
  self.assertNotIn('erase("seal_drops")',positive)
  for row in json.loads((ROOT/'game/data/01_intake.json').read_text())['interactions']:
   if row.get('kind')!='key':continue
   for owned,retired in [(False,False),(True,False),(False,True),(True,True)]:
    keys=[row['key']] if owned else [];removed=[row['seal_bearer']]+([row['id']] if retired else [])
    valid=(row['key'] in keys)==(row['id'] in removed) and (row['seal_bearer'] not in removed or row['key'] in keys)
    self.assertEqual(valid,owned and retired,'A defeated bearer needs BOTH ownership and pickup retirement')

 def test_actual_contact_scenes_use_existing_selected_chapter_constructor(self):
  for name in ['test_floor_door_contacts.gd','test_hero_floor_contacts.gd']:
   text=(ROOT/'game/tests'/name).read_text()
   for term in ['StaticSelectedLevel.fresh_selected(index,1)','if selected == null:','game.state=selected','await game.start_level()','not game.playing','game._scene_level_index!=index','quit(1)']:
    self.assertIn(term,text)
   self.assertNotIn('game.state.level_index=index',text)
  self.assertIn('rows.size()==40',(ROOT/'game/tests/test_floor_door_contacts.gd').read_text())
  hero=(ROOT/'game/tests/test_hero_floor_contacts.gd').read_text()
  self.assertIn('rows.size()==15 and queries==255',hero)
  helper=(ROOT/'game/tests/fixtures/static_selected_level.gd').read_text()
  for term in ['state.floor_revision = layout.floor_revision()','state.earned_supply = Supply.fresh(layout)','state.mark_checkpoint("entry",layout.world_position(layout.data.spawn))']:
   self.assertIn(term,helper)

 def test_shared_actor_disk_oracle_changes_only_earned_JSON_representation(self):
  actor=(ROOT/'game/tests/test_actor_snapshot_trust.gd').read_text()
  helper=actor.split('func expected_actor_disk_codec(',1)[1].split('func fresh_document',1)[0]
  self.assertIn('native_image.duplicate(true)',helper)
  self.assertIn('for snapshot in [expected,expected.checkpoint,expected.level_start]:',helper)
  self.assertIn('JSON.parse_string(JSON.stringify(snapshot.earned_supply,"",true,true))',helper)
  self.assertNotIn('.erase(',helper)
  self.assertIn('restored.to_dict() == expected_actor_disk_codec(before)',actor)
  # No tolerance/subset/whole-resource canonicalization replaces the actual comparison.
  self.assertNotIn('is_equal_approx',helper);self.assertNotIn('JSON.stringify(expected,',helper)

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
