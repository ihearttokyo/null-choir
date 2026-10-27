"""Pure authored-data/source-contract tests; not native combat or save execution."""
from pathlib import Path
from collections import deque
import json,math,re,unittest
ROOT=Path(__file__).resolve().parents[1]
HP={'crawler':50,'worker':90,'caster':90,'brute':210,'guardian':260,'summoner':150,'nursery_warden':1200,'choir_avatar':1600}
class Guardians(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.maps=[json.loads(p.read_text()) for p in sorted((ROOT/'game/data').glob('0*.json'))]
  cls.main=(ROOT/'game/scripts/main.gd').read_text();cls.enemy=(ROOT/'game/scripts/enemy.gd').read_text();cls.helper=(ROOT/'game/scripts/seal_guardians.gd').read_text()
 def test_all_eight_have_two_named_seal_bearers_and_existing_door_warden(self):
  self.assertEqual(len(self.maps),8)
  names=[]
  for d in self.maps:
   bearers=[e for e in d['enemies'] if 'seal_guardian' in e];doors=[e for e in d['enemies'] if 'door_warden' in e]
   self.assertEqual(len(bearers),2);self.assertEqual(len(doors),1)
   self.assertEqual({e['seal_guardian']['seal'] for e in bearers},{'blood','ivory'})
   self.assertEqual(len({e['id'] for e in bearers+doors}),3)
   names.extend(e.get('seal_guardian',e.get('door_warden'))['name'] for e in bearers+doors)
  self.assertEqual(len(names),len(set(names)))
 def test_key_ids_match_exactly_one_dead_bearer_not_floor_freebie(self):
  for d in self.maps:
   es={e['id']:e for e in d['enemies']}
   for key in (k for k in d['interactions'] if k['kind']=='key'):
    bearer=es[key['seal_bearer']];p=bearer['seal_guardian']
    self.assertEqual((p['key_id'],p['seal']),(key['id'],key['key']))
    self.assertEqual(key['requires_defeated'],[bearer['id']]);self.assertEqual(key.get('requires',[]),[])
    groups=[g for g in d['encounters'] if bearer['id'] in g['enemy_ids']]
    self.assertEqual(len(groups),1);self.assertEqual(groups[0]['requires'],[])
 def test_both_seal_routes_have_static_floor_access_with_gate_closed(self):
  # Tile connectivity is only authored topology, not native capsule/nav proof.
  for d in self.maps:
   tiles={(x,z) for a,b,c,e in d['rects'] for x in range(a,c+1) for z in range(b,e+1)}
   for gate in d['doors']:
    # Conservatively close the entire floor tile containing each locked gate.
    tiles.discard(tuple(math.floor(n) for n in gate['cell']))
   start=tuple(math.floor(n) for n in d['spawn']);seen={start};q=deque([start])
   while q:
    x,z=q.popleft()
    for n in [(x+1,z),(x-1,z),(x,z+1),(x,z-1)]:
     if n in tiles and n not in seen:seen.add(n);q.append(n)
   for e in d['enemies']:
    if 'seal_guardian' in e:self.assertIn(tuple(math.floor(n) for n in e['cell']),seen,d['id'])
 def test_named_warden_is_in_exit_arena_and_mandatory_for_new_games(self):
  for d in self.maps:
   w=next(e for e in d['enemies'] if 'door_warden' in e)
   exit=next(k for k in d['interactions'] if k['kind']=='exit')
   self.assertIn(w['id'],exit['requires_defeated'])
   self.assertLess(math.dist(w['cell'],exit['cell']),10)
 def test_modest_health_budget_not_three_hp_sponges(self):
  for d in self.maps:
   baseline=sum(HP[e['kind']] for e in d['enemies']);new=0
   for e in d['enemies']:
    p=e.get('seal_guardian',e.get('door_warden',{}));new+=int(HP[e['kind']]*p.get('health_multiplier',1))
    if p:self.assertGreaterEqual(p['attack_windup'],.8);self.assertGreaterEqual(p['recovery'],1.1)
   self.assertGreater(new,baseline);self.assertLess(new,baseline*1.15)
 def test_ordinary_art_capsules_worker_regions_remain(self):
  for role in HP:self.assertIn('"'+role+'": "res://assets/art/sprites/bodies-v1/'+role+'.png"',self.enemy)
  self.assertIn('WorkerHitRegions.bind(sprite,WORKER_REGION_MANIFEST)',self.enemy)
  self.assertIn('_try_worker_clutch(source,context)',self.enemy)
  self.assertNotIn('sprite.scale =',self.enemy)
 def test_death_records_after_defeat_before_notification_and_never_spawns_key_early(self):
  death=self.enemy.split('if hp == 0:',1)[1].split('elif telegraph_time',1)[0]
  self.assertLess(death.index('game.state.removed.append(id)'),death.index('game.guardian_defeated(self)'))
  self.assertIn('not drop_for(state,spec.seal_bearer).is_empty()',self.helper)
  self.assertIn('marker.visible = not spec.id in game.state.removed and available(game.state,spec)',self.helper)
  self.assertIn('marker.position = interaction_position(game,spec)',self.helper)
  self.assertIn('surface_position_at_y([cell.x,cell.y],actor.position.y+.08)',self.helper)
 def test_collection_and_prompt_share_same_drop_gate(self):
  collect=self.main.split('func collect_key',1)[1].split('func collect_pickup',1)[0]
  nearest=self.main.split('func nearest_interaction',1)[1].split('func interact()',1)[0]
  self.assertIn('if not SealGuardians.available(state,spec): return',collect)
  self.assertIn('if not SealGuardians.available(state,spec): continue',nearest)
  self.assertIn('SealGuardians.interaction_position(self,spec)',nearest)
  self.assertIn('drop.guardian != spec.seal_bearer',collect)
 def test_save_capture_includes_and_validates_pending_drops(self):
  cap=self.main.split('func _capture_actor_state',1)[1].split('func _valid_saved_position',1)[0]
  self.assertIn('"seal_drops":state.seal_drops.duplicate(true)',cap)
  self.assertIn('state._valid_seal_resources(snapshot,level.layout)',cap)
 def test_legacy_exit_only_exemption_does_not_fake_death(self):
  body=self.main.split('"exit":',1)[1].split('var prior =',1)[0]
  self.assertIn('SealGuardians.exit_warden_required(state,id)',body)
  self.assertIn('return not guardian in state.removed and not guardian in state.legacy_exit_wardens',self.helper)
  self.assertNotIn('state.removed.append',body)
 def test_named_telegraph_recovery_and_depth_tested_identity(self):
  self.assertIn('return maxf(WINDUPS[kind],champion.get("attack_windup",0.0))',self.enemy)
  self.assertIn('champion.get("recovery",0.0)',self.enemy)
  for text in ['label.no_depth_test = false','COMMITTED — EVADE','RECOVERING','champion.name']:
   self.assertIn(text,self.helper)
 def test_role_identity_persists_in_idle_windup_and_recovery_for_all_champions(self):
  # Execute the two exact source-extracted status assignments, not native/UI.
  body=self.helper.split('static func present_identity',1)[1].split('static func defeated',1)[0]
  self.assertIn('label.text = actor.champion.name+"\\n"+status',body)
  self.assertNotIn('actor.kind',body) # Same identity rule for every actor role.
  assignments=[]
  for condition in ['if actor.telegraph_time > 0:', 'elif actor.recovery_time > 0:']:
   line=next(x.strip() for x in body.splitlines() if x.strip().startswith(condition))
   statement=line.split(':',1)[1].strip()
   match=re.fullmatch(r'status (\+=|=) "([^"\\]*)"',statement)
   self.assertIsNotNone(match,line);assignments.append(match.groups())
  profiles=[e.get('seal_guardian',e.get('door_warden')) for d in self.maps for e in d['enemies'] if 'seal_guardian' in e or 'door_warden' in e]
  self.assertEqual(len(profiles),24)
  for profile in profiles:
   role=profile['seal'].upper()+' SEAL' if 'seal' in profile else 'DOOR WARDEN'
   for phase in ['idle','windup','recovery']:
    status=role
    if phase!='idle':
     operation,value=assignments[0 if phase=='windup' else 1]
     status=status+value if operation=='+=' else value
    label=profile['name']+'\n'+status
    self.assertEqual(label.splitlines()[0],profile['name'])
    self.assertIn(role,label.splitlines()[1],(profile['name'],phase,label))
    self.assertEqual(len(label.splitlines()),2)
    if phase=='windup':self.assertIn('COMMITTED',status);self.assertIn('EVADE',status)
    elif phase=='recovery':self.assertIn('RECOVERING',status)
 def test_build_identity_main_only_and_no_userdata_rename(self):
  self.assertIn('get_window().title = BuildInfo.DISPLAY_NAME',self.main)
  self.assertIn('_show_menu(BuildInfo.DISPLAY_NAME,',self.main)
  self.assertIn('build_label.text = BuildInfo.DISPLAY_NAME',self.main)
  self.assertIn('config/name="NULL CHOIR"',(ROOT/'game/project.godot').read_text())
 def test_survey_uses_actual_drop_cell_without_fog_leak(self):
  s=(ROOT/'game/scripts/survey.gd').read_text().split('func draw_state()',1)[1].split('func _draw',1)[0]
  for term in ['if not SealGuardians.available(game.state,spec): continue','SealGuardians.interaction_position(game,spec)','if not cell in cells or spec.id in game.state.removed: continue']:
   self.assertIn(term,s)
  self.assertLess(s.index('interaction_position'),s.index('if not cell in cells'))
 def test_hud_uses_shared_exit_predicate_not_raw_death_only(self):
  s=(ROOT/'game/scripts/hud.gd').read_text()
  self.assertEqual(s.count('SealGuardians.exit_warden_required(state,id)'),2)
  self.assertIn('"BREAK THE RESTRAINT" if pending_manifestation else "REACH DESCENT"',s)
 def test_export_verifier_requires_typed_hidden_or_real_drop_not_old_free_key(self):
  s=self.main.split('func _export_art_checks()',1)[1].split('func _export_title_audio_checks',1)[0]
  for term in ['SealGuardians.available(state,spec)','SealGuardians.interaction_position(self,spec)','marker.is_visible_in_tree() == expected_visible','marker.position.is_equal_approx(expected_position)','marker_meshes.all(func(part): return part.is_visible_in_tree())']:
   self.assertIn(term,s)
  fixture=(ROOT/'game/tests/test_seal_guardians.gd').read_text()
  for term in ['live free floor marker rejected','dead persisted drop passes verifier','old floor location rejected after death']:
   self.assertIn(term,fixture)
if __name__=='__main__':unittest.main()
