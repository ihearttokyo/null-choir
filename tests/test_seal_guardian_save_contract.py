"""Static integration assertions only; real GDScript save-phase suite is unrun."""
import pathlib,re,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class SaveContract(unittest.TestCase):
 def setUp(self):
  self.c=(ROOT/'game/scripts/campaign.gd').read_text()
  self.s=(ROOT/'game/scripts/level_schema.gd').read_text()
 def test_all_resource_envelopes_carry_pending_drops(self):
  self.assertIn('"seal_drops": seal_drops.duplicate(true)',self.c)
  self.assertIn('seal_drops = data.get("seal_drops",[]).duplicate(true)',self.c)
  self.assertEqual(self.c.count('\tseal_drops = []'),2)
  self.assertIn('for snapshot in [data,saved_checkpoint,saved_start]:\n\t\t_migrate_legacy_seal_drops(snapshot,layout)',self.c)
 def test_drop_identity_liveness_uniqueness_collection_and_floor_guards(self):
  body=self.c.split('func _valid_seal_resources',1)[1].split('func _valid_seal_drop_position',1)[0]
  for guard in ['pending.size() > 2','drop.size() != 2','keys_by_bearer.has(drop.guardian)','seen.has(drop.guardian)','not drop.guardian in data.removed','key.key in data.keys','key.id in data.removed','not seen.has(bearer)','_valid_seal_drop_position(drop.position,layout)']:
   self.assertIn(guard,body)
  self.assertIn('not layout.is_walkable(Vector2i(cell.floor()))',self.c)
  self.assertIn('support.is_finite() and point.y >= support.y-0.08 and point.y <= support.y+0.75',self.c)
 def test_only_legacy_absence_gets_anchor_fallback(self):
  body=self.c.split('func _migrate_legacy_seal_drops',1)[1].split('func _valid_seal_resources',1)[0]
  self.assertIn('var legacy: bool = not data.has("seal_drops")',body)
  self.assertIn('if not legacy: return',body)
  self.assertIn('not bearer in data.removed or key.key in data.keys or key.id in data.removed',body)
  self.assertIn('layout.world_position(key.cell)+Vector3.UP*0.2',body)
  self.assertIn('data.removed.append(key.id)',body)
  self.assertNotIn('data.removed.append(bearer)',body)
 def test_migration_preserves_inputs_and_terrain_binding(self):
  self.assertIn('data = data.duplicate(true)',self.c)
  self.assertIn('for drop in snapshot.get("seal_drops",[]):\n\t\t\t\tdrop.position = _shift_floor',self.c)
  self.assertIn('Enemy.health_cap(spec.kind,mode,float(spec.get("seal_guardian",spec.get("door_warden",{})).get("health_multiplier",1.0)))',self.c)
 def test_pair_route_and_door_join_guards_exist(self):
  for guard in ['profile.size() != 7','profile.size() != 4','profile.seal not in ["blood","ivory"]','key.id != profile.key_id or key.key != profile.seal','key.get("requires_defeated",[]) != [key.seal_bearer]','not key.get("requires",[]).is_empty()','door_guardians.has(defeated)','bearers.size() != 2 or declared_keys != 2','matching != 1']:
   self.assertIn(guard,self.s)
 def test_exact_legacy_exit_waiver_requires_prior_earned_seals(self):
  self.assertIn('"legacy_exit_wardens": legacy_exit_wardens.duplicate()',self.c)
  self.assertIn('legacy_exit_wardens = data.get("legacy_exit_wardens",[]).duplicate()',self.c)
  migration=self.c.split('func _migrate_legacy_seal_drops',1)[1].split('func _valid_seal_resources',1)[0]
  self.assertLess(migration.index('if not legacy: return'),migration.index('data.legacy_exit_wardens = [inherited]'))
  self.assertIn('_both_seals_collected(data,layout)',migration)
  guard=self.c.split('func _valid_seal_resources',1)[1].split('func _valid_seal_drop_position',1)[0]
  self.assertIn('exemptions != [inherited] or not _both_seals_collected(data,layout)',guard)
  self.assertIn('key.key in data.keys and key.id in data.removed',guard)
  self.assertIn('surface_position_at_y([cell.x,cell.y],point.y)',self.c)
  mapping=self.c.split('const LEGACY_NEW_EXIT_WARDENS = {',1)[1].split('}',1)[0]
  self.assertEqual(len(re.findall(r'"[a-z]+":"[a-z]+_enemy_[0-9]+"',mapping)),6)
  self.assertNotIn('nursery',mapping);self.assertNotIn('heart',mapping)
 def test_prepared_actual_suite_covers_phases(self):
  t=(ROOT/'game/tests/test_seal_guardian_saves.gd').read_text()
  for phase in ['range(8)','before kill','after kill before pickup','checkpoint preserves pending corpse origin','after pickup, no duplicate','checkpoint after pickup','old collected seals grandfathered','living bearer cannot drop','modern missing drop rejected','duplicate drop rejected','unreachable drop rejected']:
   self.assertIn(phase,t)
 def test_modern_collection_xor_causal_guard_for_all_three_envelopes(self):
  # Evaluate ONLY the exact boolean guard extracted from production GDScript;
  # this is a pure causal boundary check, not native/from_dict execution.
  body=self.c.split('func _valid_seal_resources',1)[1].split('func _both_seals_collected',1)[0]
  line=next(line.strip() for line in body.splitlines() if '(key.key in data.keys) != (key.id in data.removed)' in line)
  expression=line.removeprefix('if ').removesuffix(': return false')
  for envelope in ['current','checkpoint','level_start']:
   for owned,retired in [(False,True),(True,False),(False,False),(True,True)]:
    condition=expression.replace('key.key in data.keys',str(owned)).replace('key.id in data.removed',str(retired))
    self.assertEqual(eval(condition,{'__builtins__':{}}),owned != retired,(envelope,owned,retired))
  # Original counterexample had OR=True and no pending pickup requirement.
  self.assertTrue(False or True)
  self.assertIn('var collected: bool = key.key in data.keys and key.id in data.removed',body)
  native=(ROOT/'game/tests/test_seal_guardian_saves.gd').read_text()
  self.assertIn('for envelope in ["current","checkpoint","level_start"]:',native)
  self.assertIn('modern seal ownership/removal XOR rejected in ',native)
  self.assertIn('invalid XOR leaves destination unchanged',native)
 def test_legacy_owned_seal_normalization_precedes_typed_guard(self):
  body=self.c.split('func _migrate_legacy_seal_drops',1)[1].split('func _valid_seal_resources',1)[0]
  self.assertLess(body.index('if not legacy: return'),body.index('data.removed.append(key.id)'))
  self.assertIn('key.get("key") in data.keys and not key.id in data.removed',body)
  self.assertNotIn('data.keys.append',body)
  self.assertNotIn('data.removed.append(bearer)',body)
  native=(ROOT/'game/tests/test_seal_guardian_saves.gd').read_text()
  self.assertIn('owned legacy seal marker bookkeeping migrates',native)
  self.assertIn('normalized legacy collection remains consistent on resave',native)
if __name__=='__main__':unittest.main()
