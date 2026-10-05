extends SceneTree

const STEP = 1.0/60.0
const HERO_IDS = [["skin_bell","siphon_heart"],["vertebral_furnace","marrow_crucible"],["walking_bone_organ","ossified_palanquin"],["reliquary_face_halo","reliquary_memory_wheel"]]
const SPAWNS = [[14.5,28.5],[14.5,30.5],[21.5,29.5],[19.5,38.5]]
const NAVES = [[14.5,17.5],[14,19],[16.5,20.5],[9.5,21.5]]
const TOTALS = [23,23,26,31]
const AMMO_TOTALS = [{1:170},{1:325},{1:135,2:70},{1:340,2:68}]
const GATE_CELLS = [[Vector2i(13,5),Vector2i(14,5)],[Vector2i(12,4),Vector2i(13,4)],[Vector2i(15,4),Vector2i(16,4)],[Vector2i(18,7),Vector2i(19,7),Vector2i(20,7)]]
const GATE_SUPPLIES = ["gate_ammo","foundry_gate_ammo","processional_gate_shells","reliquary_exit_rivets"]
const PREPARATION_SUPPLIES = [
	[["upper_ammo",[5.5,20.5]],["siphon_ammo",[23.0,20.5]]],
	[["furnace_ammo",[6.5,19.5]],["crucible_ammo",[23.5,19.5]]],
	[["processional_organ_shells",[3.5,20.5]],["processional_palanquin_shells",[29.5,20.5]]],
	[["reliquary_halo_approach_rivets",[9.5,25.5]],["reliquary_wheel_approach_rivets",[29.5,25.5]]]]
# One existing solid prop per map: exact authored cover and a six-meter native flank.
const COVER_CASES = [
	{"art":"drain_altar","cell":[8.25,16.0],"solid":[3.0,1.6,2.2],"side":1},
	{"art":"containment_capsule","cell":[5.0,15.0],"solid":[2.2,4.9,1.8],"side":-1},
	{"art":"containment_capsule","cell":[9.0,16.7],"solid":[2.2,4.9,1.8],"side":1},
	{"art":"containment_capsule","cell":[6.0,20.0],"solid":[2.2,4.9,1.8],"side":1}]

var game
var level_index = 0
var test_prefix = "user://test_encounters_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())

func _initialize() -> void: call_deferred("run")

func run() -> void:
	# Load only the existing layout before RED; missing new APIs cannot mask this assertion.
	for index in range(4):
		var layout = load("res://scripts/level_data.gd").new()
		if not expect(layout.load_level(index),"SETUP: existing authored map must load"): return
		var groups = layout.data.get("encounters",[])
		if not expect(groups is Array and groups.size() >= 3,layout.data.id+" requires authored landmark and seal-return encounter data (intended RED)"): return
		if not check_authored(layout,index): return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="): level_index = int(arg.trim_prefix("--level="))
	if not expect(level_index >= 0 and level_index < 4,"SETUP: --level must select a current map"): return
	game = load("res://scripts/main.gd").new()
	game.progress_path = test_prefix+"_campaign.json"
	game.settings_path = test_prefix+"_preferences.json"
	root.add_child(game)
	AudioServer.set_bus_mute(0,true)
	for check in [check_entry,check_regions,check_hit_activation,check_persistence,check_machine_seals,check_cover]:
		if not await check.call(): return
	cleanup()
	print("PASS native authored encounters level=",level_index," membership, regions/seals, firing isolation, hit activation, one-shot cues, restoration, machine lights, cover/flank and entry safeguards")
	quit()

func check_authored(layout, index: int) -> bool:
	var data = layout.data
	if not expect(data.enemies.size() == TOTALS[index] and data.loops.size() == 2 and data.heroes.size() == 2 and data.spawn == SPAWNS[index],"Preserve enemy totals, two loops, two heroes and original safe spawn: "+data.id): return false
	var enemies = {}
	for spec in data.enemies:
		if not expect(not enemies.has(spec.id) and not spec.has("encounter"),"Stable enemy IDs; encounters array alone owns membership"): return false
		enemies[spec.id] = spec
	for number in range(TOTALS[index]):
		if not expect(enemies.has(data.id+"_enemy_%02d"%number),"Preserve every existing enemy identity"): return false
	var ids = {}
	var members = {}
	var required_return = false
	var landmark_entry = false
	var lights = {}
	for light in data.lights:
		if light.has("id"):
			if not expect(not lights.has(light.id),"Light identifiers must be unique"): return false
			lights[light.id] = true
	for spec in data.encounters:
		if not expect(spec is Dictionary and spec.get("id","") is String and not spec.get("id","").is_empty() and not ids.has(spec.get("id")),"Encounter identifiers must be nonempty and unique"): return false
		ids[spec.id] = true
		var region = spec.get("region",[])
		if not expect(region is Array and region.size() == 4,"Encounter requires bounded cell-space rectangle"): return false
		for value in region:
			if not expect((value is float or value is int) and is_finite(float(value)),"Region coordinates must be finite numbers"): return false
		if not expect(region[0] < region[2] and region[1] < region[3] and not contains(region,Vector2(data.spawn[0],data.spawn[1])),"Ordered nonempty encounter bounds must exclude the safe entry"): return false
		if not expect(spec.get("enemy_ids",[]) is Array and spec.get("enemy_ids",[]).size() >= 2,"Encounter must author its real enemy membership"): return false
		for id in spec.enemy_ids:
			if not expect(enemies.has(id) and not members.has(id),"Every group member exists and belongs to exactly one authored group"): return false
			members[id] = spec.id
		var required = spec.get("requires",[])
		if not expect(required is Array,"Required seals must be an array"): return false
		for seal in required:
			if not expect(seal in ["blood","ivory"] and required.count(seal) == 1,"Only unique existing seals may condition a return"): return false
		required_return = required_return or not required.is_empty()
		landmark_entry = landmark_entry or required.is_empty()
		var cue = spec.get("cue",{})
		if not expect(cue is Dictionary and cue.get("text","") is String and not cue.get("text","").is_empty() and cue.get("sound","") == "seal_release" and cue.get("light_ids",[]) is Array and not cue.get("light_ids",[]).is_empty(),"Each encounter authors original text and existing sound/light cues"): return false
		for id in cue.light_ids:
			if not expect(lights.has(id),"Encounter cue references a real stable light"): return false
	if not expect(required_return and landmark_entry,"Every map authors ungated landmark entry and a seal-conditioned return"): return false
	if not expect(data.lights.filter(func(light): return light.get("shadow",false)).size() == 4,"Preserve four existing shadowed lights; encounter cues cannot add shadows"): return false
	for i in range(2):
		var hero = data.heroes[i]
		var loop = data.loops[i]
		if not expect(hero.id == HERO_IDS[index][i] and loop.hero == hero.id and loop.route[0] == loop.route[-1] and hero.base[1] == 0.55,"Preserve original loop/hero identities and low collision bases"): return false
		if not expect(hero.get("seal","") == ["blood","ivory"][i] and hero.get("light_ids",[]) is Array and not hero.get("light_ids",[]).is_empty(),"Each original machine associates its earned seal with persistent lights"): return false
		for id in hero.light_ids:
			if not expect(lights.has(id),"Machine references an existing authored light"): return false
		for j in range(loop.route.size()-1):
			if not expect(load("res://tests/test_level.gd").reachable(layout,Vector2i(loop.route[j][0],loop.route[j][1]),Vector2i(loop.route[j+1][0],loop.route[j+1][1])),"Existing closed route stays connected"): return false
	var stories = data.interactions.filter(func(spec): return spec.kind == "story")
	if not expect(stories.size() == 1 and not stories[0].has("requires"),"Optional story stays ungated by encounter completion"): return false
	var ammo = {}
	for pickup in data.pickups:
		if pickup.kind in ["ammo","weapon"]: ammo[int(pickup.weapon)] = ammo.get(int(pickup.weapon),0)+int(pickup.amount)
		if pickup.id == GATE_SUPPLIES[index]:
			if not expect(load("res://tests/test_level.gd").reachable(layout,Vector2i(data.spawn[0],data.spawn[1]),Vector2i(pickup.cell[0],pickup.cell[1]),GATE_CELLS[index]),"Final commitment ammunition must be reachable before opening its gate"): return false
	if not expect(ammo == AMMO_TOTALS[index] and data.pickups.any(func(spec): return spec.id == GATE_SUPPLIES[index]),"Keep existing supplies and ammunition totals during first rollout"): return false
	for preparation in PREPARATION_SUPPLIES[index]:
		if not expect(data.pickups.any(func(spec): return spec.id == preparation[0] and spec.cell == preparation[1]),"Existing supplies move to the frozen preparation pocket before each landmark commitment"): return false
		if not expect(not data.encounters.any(func(spec): return spec.get("requires",[]).is_empty() and contains(spec.region,Vector2(preparation[1][0],preparation[1][1]))),"Preparation supply cannot itself trigger an ungated encounter"): return false
	for feature in data.enemies+data.pickups+data.interactions+data.heroes:
		if not expect(layout.is_walkable(Vector2i(floori(feature.cell[0]),floori(feature.cell[1]))),"Every authored feature stays on real walkable floor"): return false
	return true

func boot() -> void:
	game.state.new_campaign(1)
	game.state.level_index = level_index
	game.start_level()
	freeze()
	await settle()

func freeze() -> void:
	game.set_process(false)
	game.player.set_physics_process(false)
	game.player.set_process_unhandled_input(false)
	game.music.stop()
	for actor in game.enemies: actor.set_physics_process(false)

func settle() -> void:
	await physics_frame
	await physics_frame

func place(cell: Array) -> void:
	game.player.position = game.level.layout.world_position(cell)+Vector3.UP*0.04
	game.player.velocity = Vector3.ZERO
	game.state.position = game.player.position

func contains(region: Array, cell: Vector2) -> bool:
	return cell.x >= region[0] and cell.y >= region[1] and cell.x <= region[2] and cell.y <= region[3]

func actor_with_id(id: String):
	for actor in game.enemies:
		if actor.id == id: return actor
	return null

func isolated_cell(spec: Dictionary) -> Array:
	var region = spec.region
	for x in range(ceili(region[0]),floori(region[2])):
		for z in range(ceili(region[1]),floori(region[3])):
			var cell = Vector2(x+0.5,z+0.5)
			if game.level.layout.is_walkable(Vector2i(x,z)) and contains(region,cell) and not game.level.layout.data.encounters.any(func(other): return other.id != spec.id and contains(other.region,cell)):
				return [cell.x,cell.y]
	return []

func check_entry() -> bool:
	for mode in range(3):
		game.state.new_campaign(mode)
		game.state.level_index = level_index
		game.start_level()
		freeze()
		await settle()
		for frame in range(600):
			game._process(STEP)
			for actor in game.enemies: actor._physics_process(STEP)
			await physics_frame
			if game.state.health == 0: break
		print("ENCOUNTER_ENTRY level=",level_index," mode=",mode," health=",game.state.health)
		if not expect(game.state.health == 100 and not game.state.removed.any(func(id): return id.begins_with("encounter:")),"Ten-second native idle entry stays safe on every fixed difficulty without activation"): return false
		place(NAVES[level_index])
		await settle()
		game._process(0)
		for actor in game.enemies: actor._physics_process(0)
		if not expect(game.enemies.any(func(actor): return actor.active and actor.alerted),"Leaving entry still reaches a live nave engagement"): return false
	return true

func check_regions() -> bool:
	await boot()
	var group = game.level.layout.data.encounters.filter(func(spec): return spec.get("requires",[]).is_empty())[0]
	var r = group.region
	var middle = [(r[0]+r[2])/2.0,(r[1]+r[3])/2.0]
	var flag = "encounter:"+group.id
	for point in [[r[0]-0.01,middle[1]],[r[2]+0.01,middle[1]],[middle[0],r[1]-0.01],[middle[0],r[3]+0.01]]:
		place(point)
		game._process(0)
		if not expect(not flag in game.state.removed,"Each rectangle edge excludes points just outside the trigger"): return false
	var member = actor_with_id(group.enemy_ids[0])
	if not expect(member != null and not member.active,"Authored group members begin dormant"): return false
	# Firing close to a real dormant member proves isolation independently of its region.
	game.player.position = member.position+Vector3(0,0,2)
	game.shot(1)
	member._physics_process(0)
	if not expect(not member.active and not member.alerted and not flag in game.state.removed,"Nearby firing and sight cannot activate or alert a dormant group"): return false
	var cell = isolated_cell(group)
	if not expect(not cell.is_empty(),"Authored encounter requires an independently enterable region"): return false
	var before = {}
	for actor in game.enemies: before[actor.id] = actor.active
	var initial_lights = light_state(group.cue.light_ids)
	if not expect(initial_lights.size() == group.cue.light_ids.size(),"SETUP: every cue light must exist in the real scene"): return false
	place(cell)
	game._process(0)
	if not expect(flag in game.state.removed and game.state.removed.count(flag) == 1 and game.message == group.cue.text and game.effects.players[group.cue.sound].playing,"Entering region activates once and presents its authored text/sound cue"): return false
	for actor in game.enemies:
		if not expect(actor.active == (true if actor.id in group.enemy_ids else before[actor.id]),"Region activates exactly its authored IDs, never neighboring groups"): return false
	await create_timer(1.0).timeout
	if not expect(light_state(group.cue.light_ids) != initial_lights,"Activation changes real machine lighting without extra geometry"): return false
	game.effects.players[group.cue.sound].stop()
	game.message_time = 1.0
	game._process(0)
	if not expect(game.message_time == 1.0 and not game.effects.players[group.cue.sound].playing and game.state.removed.count(flag) == 1,"Repeated region tick cannot replay text/sound or duplicate activation"): return false
	for point in [[r[0],middle[1]],[r[2],middle[1]],[middle[0],r[1]],[middle[0],r[3]]]:
		await boot()
		place(point)
		game._process(0)
		if not expect(flag in game.state.removed,"Trigger includes its exact authored rectangle boundaries"): return false
	await boot()
	var required = game.level.layout.data.encounters.filter(func(spec): return not spec.get("requires",[]).is_empty())[0]
	cell = isolated_cell(required)
	if not expect(not cell.is_empty(),"Seal-conditioned return needs its own enterable region"): return false
	place(cell)
	game._process(0)
	if not expect(not "encounter:"+required.id in game.state.removed,"Region without earned seals cannot activate the return"): return false
	for seal in required.requires:
		var key = game.level.layout.data.interactions.filter(func(spec): return spec.kind == "key" and spec.key == seal)[0]
		game.collect_key(key.id)
		game._process(0)
		if not expect(("encounter:"+required.id in game.state.removed) == game._has_keys(required.requires),"Return activates only after every required seal is earned"): return false
	return true

func check_hit_activation() -> bool:
	await boot()
	var group = game.level.layout.data.encounters[0]
	var victim = actor_with_id(group.enemy_ids[0])
	var before = {}
	for actor in game.enemies: before[actor.id] = actor.active
	var hp = victim.hp
	victim.take_damage(7,game.player)
	if not expect(victim.hp == hp-7 and "encounter:"+group.id in game.state.removed,"Dormant member stays vulnerable and a real hit activates its group"): return false
	for actor in game.enemies:
		if not expect(actor.active == (true if actor.id in group.enemy_ids else before[actor.id]),"Hit activation wakes the whole authored group and no unrelated members"): return false
	return true

func check_persistence() -> bool:
	await boot()
	var group = game.level.layout.data.encounters[0]
	var flag = "encounter:"+group.id
	var dead_id = group.enemy_ids[0]
	game.state.mark_checkpoint("encounter_before",game.player.position)
	actor_with_id(dead_id).take_damage(1000,game.player)
	if not expect(flag in game.state.removed and dead_id in game.state.removed,"Lethal first hit records group activation and original enemy removal"): return false
	game.hurt_player(300)
	await game.restore_checkpoint()
	freeze()
	await settle()
	if not expect(not flag in game.state.removed and not dead_id in game.state.removed and actor_with_id(dead_id) != null and not actor_with_id(dead_id).active,"Pre-encounter checkpoint rewinds activation and restores killed members dormant"): return false
	actor_with_id(dead_id).take_damage(1000,game.player)
	game.state.ammo[1] = game.player.WEAPONS[1].max_ammo+17 # Valid older over-cap reserves remain valid.
	game.player.cooldown = 0
	if not expect(game.player.fire(),"SETUP: real firing consumes a checkpoint resource"): return false
	game.hurt_player(27)
	var ammo = game.state.ammo.duplicate()
	var health = game.state.health
	game.state.mark_checkpoint("encounter_active",game.player.position)
	await create_timer(1.0).timeout
	var lights = light_state(group.cue.light_ids)
	game.hurt_player(300)
	await game.restore_checkpoint()
	freeze()
	await settle()
	if not expect(restored_group(group,dead_id) and game.state.health == health and game.state.ammo == ammo,"Active checkpoint restores exact resources, survivor activity and permanent member removal"): return false
	if not expect(game._save() == OK,"SETUP: unique fixture progress must save through the real game path"): return false
	game.show_title()
	await game.continue_campaign()
	freeze()
	await settle()
	if not expect(restored_group(group,dead_id) and game.state.health == health and game.state.ammo == ammo and game.state.to_dict().version == 1,"Continue preserves activated survivors, dead IDs and valid older over-cap ammo without a save migration"): return false
	if not expect(game.message == game.level.layout.data.mission and light_state(group.cue.light_ids) == lights,"Continue restores lighting silently rather than replaying the encounter cue"): return false
	await game.restart_level()
	freeze()
	await settle()
	return expect(not flag in game.state.removed and actor_with_id(dead_id) != null and not actor_with_id(dead_id).active and game.state.health == 100 and game.state.ammo[1] == 90 and game.state.checkpoint_id == "entry","Restart restores original entry resources and all encounter members dormant")

func restored_group(group: Dictionary, dead_id: String) -> bool:
	if not "encounter:"+group.id in game.state.removed or actor_with_id(dead_id) != null: return false
	for id in group.enemy_ids:
		if id != dead_id and (actor_with_id(id) == null or not actor_with_id(id).active): return false
	return true

func light_state(ids: Array) -> Array:
	var result = []
	for id in ids:
		var spec = game.level.layout.data.lights.filter(func(light): return light.get("id","") == id)[0]
		var point = game.level.layout.world_position(spec.cell)+Vector3.UP*spec.height
		for node in game.level.get_children():
			if node is Light3D and node.position.is_equal_approx(point): result.append([node.light_color,node.light_energy])
	return result

func check_machine_seals() -> bool:
	await boot()
	var saved = []
	var gate = game.level.layout.data.doors[0]
	if not expect(not game.unlock_door(gate.id),"Existing exit gate still requires both earned seals"): return false
	for hero in game.level.layout.data.heroes:
		var before = light_state(hero.light_ids)
		var key = game.level.layout.data.interactions.filter(func(spec): return spec.kind == "key" and spec.key == hero.seal)[0]
		game.collect_key(key.id)
		await create_timer(1.0).timeout
		var after = light_state(hero.light_ids)
		if not expect(before.size() == hero.light_ids.size() and after != before and hero.seal in game.state.keys,"Recovering each seal changes its actual machine lights"): return false
		saved.append(after)
		if game.state.keys.size() == 1 and not expect(not game.unlock_door(gate.id),"A single seal still cannot open the original exit gate"): return false
	if not expect(game.unlock_door(gate.id),"Both original seals still unlock the actual exit gate"): return false
	if not expect(game._save() == OK,"SETUP: earned seal fixture must save"): return false
	game.show_title()
	await game.continue_campaign()
	freeze()
	await settle()
	for i in range(2):
		if not expect(light_state(game.level.layout.data.heroes[i].light_ids) == saved[i],"Machine consequence persists from earned seals through Continue"): return false
	game.effects.players.seal_release.stop()
	game.message_time = 1.0
	game.level.apply_encounter_cue(game.level.layout.data.encounters[0],true)
	return expect(game.message_time == 1.0 and not game.effects.players.seal_release.playing,"Restoring an encounter applies light state without text/audio transients")

func check_cover() -> bool:
	await boot()
	var wanted = COVER_CASES[level_index]
	var specs = game.level.layout.data.scenery.filter(func(spec): return spec.art == wanted.art and spec.cell == wanted.cell and spec.get("solid",[]) == wanted.solid and is_zero_approx(float(spec.get("yaw",0))))
	if not expect(specs.size() == 1,"Signature encounter uses the frozen existing-art tactical cover placement"): return false
	var p = game.level.layout.world_position(wanted.cell)
	var query = PhysicsRayQueryParameters3D.create(p+Vector3(0,1.4,3),p+Vector3(0,1.4,-3),1)
	var hit = game.level.get_world_3d().direct_space_state.intersect_ray(query)
	if not expect(not hit.is_empty() and hit.collider is StaticBody3D and hit.collider.position.is_equal_approx(p+Vector3.UP*wanted.solid[1]/2.0),"Actual authored solid envelope blocks a representative 1.4-meter firing ray"): return false
	for actor in game.enemies: actor.collision_layer = 0
	game.settings.head_bob = false
	game.settings.camera_shake = false
	game.player.rotation = Vector3.ZERO
	game.player.position = p+Vector3(wanted.side*2.5,0.04,3)
	game.player.velocity = Vector3.ZERO
	var target = p+Vector3(wanted.side*2.5,0.0,-3)
	await settle()
	Input.action_press("move_forward")
	var reached = false
	for frame in range(130):
		await physics_frame
		game.player._physics_process(STEP)
		var offset = game.player.position-target
		offset.y = 0
		if offset.length() < 0.25:
			reached = true
			break
	Input.action_release("move_forward")
	return expect(reached and absf(game.player.position.y-p.y) < 0.3,"Real player capsule traverses the open flank without jumping, collision removal or falling")

func cleanup() -> void:
	if InputMap.has_action("move_forward"): Input.action_release("move_forward")
	if is_instance_valid(game):
		game.show_title()
		game.free()
	paused = false
	for suffix in ["_campaign.json","_campaign.json.tmp"]:
		var path = test_prefix+suffix
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

func expect(condition: bool, detail: String) -> bool:
	if not condition:
		push_error("Encounter contract: "+detail)
		cleanup()
		quit(1)
	return condition
