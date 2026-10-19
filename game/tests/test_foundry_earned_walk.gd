extends "res://tests/test_intake_complete_walk.gd"

const F_LIMIT = 7200
const F_SECONDS = 150
const F_FIGHT_LIMIT = 360
const F_MAP_SHA = "0b2a19a04ecc5d1b7d1b0631393657fdc3f306a6dfc947b43933556e82ccb738"
const ENTRY = [[15.0,29.0],[16.5,29.0],[16.5,26.5],[16.5,24.5],[12.5,24.5],[12.5,21.0],[10.5,20.5]]
const FURNACE = [[8.5,20.5],[6.5,19.5],[8.5,18.5],[6.5,18.5],[4.5,18.5],[4.5,17.5],[4.5,15.5],[4.5,13.5],[5.5,13.5],[5.5,11.5],[5.0,11.5]]
const WEST_RETURN = [[8.5,11.5],[9.0,11.5],[9.0,9.5],[9.0,8.5],[9.0,7.0],[12.0,7.0],[16.5,7.0],[16.5,10.0],[16.5,13.0],[16.5,16.0],[16.5,20.0],[12.5,20.5]]
const CRUCIBLE = [[16.5,20.5],[17.5,22.5],[20.5,22.5],[23.5,22.5],[23.5,21.5],[23.5,19.5],[23.5,16.5],[23.5,15.0],[26.5,14.5],[27.5,14.5],[26.5,14.5],[26.5,12.0],[26.5,9.5]]
const EAST_RETURN = [[25.0,9.5],[25.0,10.0],[22.0,10.0],[23.5,10.0],[23.5,7.0],[20.5,7.0],[17.0,7.0],[16.5,10.0],[16.5,13.0],[16.5,16.0],[16.5,20.5]]
const GATE_APPROACH = [[16.5,17.0],[16.5,13.0],[16.5,10.0],[16.5,8.5],[16.5,7.0],[13.0,7.0],[12.5,6.5],[13.0,5.7]]
const F_EXIT = [[13.0,3.5],[13.0,2.5],[12.5,1.5]]

class FoundryMain:
	extends "res://tests/test_intake_complete_walk.gd".CompleteMain
	var foundry_enabled: bool = false
	var f_ok: bool = true
	var f_ticks: int = 0
	var f_shots: int = 0
	var f_last_shot: int = -1
	var f_slot: float = -1.0
	var f_ledger: Dictionary = {}
	var f_consumed: Dictionary = {}
	var f_deaths: Dictionary = {}
	var f_finishes: Dictionary = {}
	var f_attacks: Dictionary = {}
	var f_checkpoint_saves: int = 0
	var f_level_start: Dictionary = {}
	static func next_slot(tick: int, last: int, nominal: float) -> float:
		var interval: float = Player.WEAPONS[1].interval*60.0
		if last >= 0 and (tick <= last or float(tick)+0.000001 < (nominal if nominal >= 0.0 else float(last)+interval)): return -1.0
		var result: float = float(tick)+interval if nominal < 0.0 else nominal+interval
		if result <= float(tick)+0.000001: result += (floorf((float(tick)+0.000001-result)/interval)+1.0)*interval
		return result
	static func checkpoint_expectation(current: Dictionary, budget: Dictionary, capture: Dictionary, start: Dictionary) -> Dictionary:
		var expected: Dictionary = current.duplicate(true)
		var recovered: Dictionary = capture.duplicate(true)
		recovered.merge(budget.duplicate(true),true)
		expected.checkpoint = recovered
		expected.level_start = start.duplicate(true)
		return expected
	func budget() -> Dictionary:
		return {"health":state.health,"armor":state.armor,"ammo":state.ammo.duplicate(),"owned_weapons":state.owned_weapons.duplicate(),"weapon":state.weapon}
	func _physics_process(delta: float) -> void:
		super._physics_process(delta)
		if foundry_enabled and playing and state.level_index == 1 and not get_tree().paused:
			f_ticks += 1
			f_ok = f_ok and absf(delta-1.0/60.0) < 0.000001
			if not Input.is_action_pressed("fire"): f_slot = -1.0
	func shot(weapon: int) -> void:
		if foundry_enabled:
			var tick: int = Engine.get_physics_frames()
			f_slot = next_slot(tick,f_last_shot,f_slot)
			var expected: Dictionary = f_ledger.duplicate(true)
			expected.ammo[1] -= 1
			f_ok = f_ok and Engine.is_in_physics_frame() and playing and state.level_index == 1 and is_instance_valid(player) and player._current_map() and weapon == 1 and Input.is_action_pressed("fire") and f_slot >= 0.0 and player.shot_age(1) == 0.0 and player._last_shots[1] == player.active_play_time and budget() == expected and expected.ammo[1] >= 0
			f_ledger = expected
			f_shots += 1
			f_last_shot = tick
		# Intake shot_ok/shot_slot are irrelevant only after its independently verified exit.
		# Keep super dispatch for actual Main noise/effects and inherited feedback observers.
		super.shot(weapon)
	func collect_pickup(id: String) -> void:
		if not foundry_enabled:
			super.collect_pickup(id)
			return
		var matches: Array = level.layout.data.pickups.filter(func(spec): return spec.id == id)
		f_ok = f_ok and Engine.is_in_physics_frame() and player._current_map() and matches.size() == 1 and budget() == f_ledger
		if matches.size() != 1:
			super.collect_pickup(id)
			return
		var spec: Dictionary = matches[0]
		var expected: Dictionary = f_ledger.duplicate(true)
		var old: int = int(expected.ammo[1]) if spec.kind == "ammo" else int(expected[spec.kind])
		var cap: int = 180 if spec.kind == "ammo" else 100 if spec.kind == "health" else 200
		var consumed: bool = old < cap and not id in state.removed
		var full_rejection: bool = old >= cap and not id in state.removed
		var original_marker = level.markers.get(id)
		if consumed:
			if spec.kind == "ammo": expected.ammo[1] = mini(cap,old+int(spec.amount))
			else: expected[spec.kind] = mini(cap,old+int(spec.amount))
		super.collect_pickup(id)
		f_ok = f_ok and spec.kind in ["ammo","health","armor"] and budget() == expected and state.removed.count(id) == (1 if consumed or f_consumed.has(id) else 0)
		if consumed:
			f_consumed[id] = f_consumed.get(id,0)+1
			f_ok = f_ok and f_consumed[id] == 1 and not level.markers.has(id)
		if full_rejection:
			f_ok = f_ok and is_instance_valid(original_marker) and level.markers.get(id) == original_marker and original_marker.get_parent() == level and not original_marker.is_queued_for_deletion()
		f_ledger = expected
	func enemy_event(actor, event: String) -> void:
		if foundry_enabled:
			f_ok = f_ok and playing and actor._current_map() and actor.active and actor.id.begins_with("foundry_enemy_")
			if event == "attack" and actor._committed_target == player: f_attacks[actor.id] = Engine.get_physics_frames()
			if event == "death":
				f_deaths[actor.id] = f_deaths.get(actor.id,0)+1
				f_ok = f_ok and Engine.is_in_physics_frame() and actor.hp == 0 and actor.collision_layer == 0 and actor.collision_mask == 0 and state.removed.count(actor.id) == 1 and f_deaths[actor.id] == 1
				f_finishes[actor.id] = Input.is_action_pressed("fire") and f_last_shot == Engine.get_physics_frames() and actor.target == player and aim_observation.get("actor_id","") == actor.id and aim_observation.get("tick",-1) == Engine.get_physics_frames() and aim_observation.get("level") == level and aim_observation.get("player") == player
		super.enemy_event(actor,event)
	func hurt_player(amount: int) -> void:
		if not foundry_enabled:
			super.hurt_player(amount)
			return
		var original_attack: bool = false
		for actor in enemies:
			var age: int = Engine.get_physics_frames()-int(f_attacks.get(actor.id,-1000))
			if actor._current_map() and actor.active and actor.hp > 0 and actor._committed_target == player and age >= 0 and ((actor.kind == "worker" and amount == 10 and age == 0) or (actor.kind == "crawler" and amount == 12 and age <= 12)): original_attack = true
		# shortcut: source-debug stack attribution; packed-app attribution is a separate gate.
		var stack_attack: bool = get_stack().any(func(frame): return str(frame.get("source","")).ends_with("/enemy.gd") and frame.get("function","") == "_attack")
		f_ok = f_ok and Engine.is_in_physics_frame() and original_attack and stack_attack and budget() == f_ledger
		var expected: Dictionary = f_ledger.duplicate(true)
		var absorbed: int = mini(int(expected.armor),int(amount/3))
		expected.armor -= absorbed
		expected.health = maxi(0,int(expected.health)-(amount-absorbed))
		super.hurt_player(amount)
		f_ok = f_ok and budget() == expected
		f_ledger = expected
	func _save() -> Error:
		var expected: Dictionary = state.to_dict().duplicate(true)
		if foundry_enabled and state.level_index == 1 and state.checkpoint_id == "foundry_checkpoint":
			var capture: Dictionary = state._resources().duplicate(true)
			capture.position = [player.position.x,player.position.y,player.position.z]
			capture.actors = enemies.filter(func(actor): return actor._current_map() and actor.hp > 0).map(func(actor): return actor.snapshot())
			capture.yaw = Enemy.canonical_yaw(player.rotation.y)
			capture.pitch = clampf(player.camera.rotation.x,-1.35,1.35)
			expected = checkpoint_expectation(expected,f_ledger,capture,f_level_start)
		var result: Error = super._save()
		if foundry_enabled and state.level_index == 1 and state.checkpoint_id == "foundry_checkpoint":
			var saved = state.get_script().new()
			f_checkpoint_saves += 1
			f_ok = f_ok and Engine.is_in_physics_frame() and result == OK and saved.load_progress(progress_path) and saved.to_dict() == expected and state.to_dict() == expected and state.keys == ["blood","ivory"] and budget() == f_ledger
		return result

var foundry_started: bool = false
var f_epoch: int = 0
var f_wall_us: int = 0
var f_markers: Dictionary = {}
var f_blood_input: bool = false
var f_ivory_input: bool = false
var f_kind: Dictionary = {}
var f_shots_before: int = 0

func run() -> void:
	prefix = "user://foundry_earned_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	if not await walk_to_foundry_exit(FoundryMain.new(),prefix):
		await finish(1)
		return
	print("PASS source-native candidate earned Intake->Foundry two-loop finite-input traversal and actual exit. Scripted aim/virtual Input; not physical input, full campaign, GPU/audio/performance or packed-app acceptance.")
	await finish(0)

func walk_to_foundry_exit(observer, profile_prefix: String) -> bool:
	prefix = profile_prefix
	if not expect(has_method("walk_to_intake_exit"),"DEPENDENCY: exact non-quitting Intake helper patch must be integrated first"):
		return false
	if not await call("walk_to_intake_exit",observer,prefix) or not await descend_foundry():
		return false
	for block in [ENTRY,FURNACE]:
		if not await foundry_route(block):
			return false
	if not await fight_ids(["foundry_enemy_03","foundry_enemy_04","foundry_enemy_05","foundry_enemy_21"]) or not await seal_input("foundry_blood",[4.5,11.5],"blood") or not await foundry_route(WEST_RETURN):
		return false
	if not expect(route_player.position.distance_to(route_level.layout.world_position([12.5,20.5])+Vector3.UP*0.04) < 0.2,"First authored loop returns to the same junction") or not await foundry_route(CRUCIBLE) or not await fight_ids(["foundry_enemy_11","foundry_enemy_12","foundry_enemy_13","foundry_enemy_14","foundry_enemy_22"]) or not await seal_input("foundry_ivory",[27.5,9.5],"ivory") or not await foundry_route(EAST_RETURN):
		return false
	if not expect(route_player.position.distance_to(route_level.layout.world_position([16.5,20.5])+Vector3.UP*0.04) < 0.2,"Second authored loop returns to its original junction") or not await foundry_route(GATE_APPROACH) or not await foundry_gate() or not await foundry_route(F_EXIT) or not await fight_ids(f_kind.keys()) or not await foundry_exit():
		return false
	return true

func descend_foundry() -> bool:
	var carried: Dictionary = resource_snapshot()
	if not expect(carried == {"health":70,"armor":0,"ammo":[0,81,0,0,0,0],"owned_weapons":[0,1],"weapon":1,"keys":[]} and game.shots == 89 and carried.ammo[1] == 125+45-game.shots and saved_exit_matches(game.state) and retired.all(func(reference): return reference.get_ref() == null),"Exact independently verified Intake exit precedes all Foundry observer changes"): return false
	var main_id: int = game.get_instance_id()
	var profile: String = game.progress_path
	release_actions()
	if not press_menu("Descend to The Foundry"): return false
	for frame in range(118):
		if game.playing and not game.placement_pending and is_instance_valid(game.player): break
		await physics_frame
	await physics_frame
	await physics_frame
	if not expect(game.playing and not paused and not game.placement_pending and game.state.level_index == 1 and game.get_instance_id() == main_id and game.progress_path == profile and resource_snapshot() == carried,"Actual Descend uses same Main/profile and exact earned resources within 120 frames"): return false
	route_level = game.level
	route_player = game.player
	var data: Dictionary = route_level.layout.data
	if not expect(FileAccess.get_sha256("res://data/02_foundry.json") == F_MAP_SHA and data.id == "foundry" and data.spawn == [14.5,30.5] and data.cell_size == 4 and data.enemies.size() == 23 and data.loops.map(func(loop): return loop.hero) == ["vertebral_furnace","marrow_crucible"] and data.pickups.all(func(spec): return spec.kind != "weapon"),"Pin complete authored Foundry source, both loops, geometry, supply types and no weapon grant"): return false
	actors.clear()
	for actor in game.enemies:
		var specs: Array = data.enemies.filter(func(spec): return spec.id == actor.id and spec.kind == actor.kind)
		if not expect(specs.size() == 1 and not actors.has(actor.id) and actor.hp == (90 if actor.kind == "worker" else 50),"Every original Foundry actor starts full-health with its authored identity/type"): return false
		actors[actor.id] = [actor.get_instance_id(),actor.age]
		f_kind[actor.id] = actor.kind
	for id in route_level.markers: f_markers[id] = weakref(route_level.markers[id])
	if not expect(actors.size() == 23 and route_player.position.distance_to(route_level.layout.world_position(data.spawn)+Vector3.UP*0.04) < 0.1 and clear_point(data.spawn) != null and game.state.keys.is_empty() and game.state.removed.is_empty() and game.state.checkpoint_id == "entry","Foundry starts at actual native spawn with all original nodes and clear capsule"): return false
	walk_ticks = 0
	origin = route_player.position
	previous = origin
	f_epoch = Engine.get_physics_frames()
	f_wall_us = Time.get_ticks_usec()
	f_shots_before = game.shots
	game.f_ledger = game.budget()
	game.f_level_start = game.state.level_start.duplicate(true)
	if not expect(game.f_level_start.health == carried.health and game.f_level_start.armor == carried.armor and game.f_level_start.ammo == carried.ammo and game.f_level_start.owned_weapons == carried.owned_weapons and game.f_level_start.weapon == carried.weapon and game.f_level_start.keys == [] and game.f_level_start.removed == [] and game.f_level_start.checkpoint_id == "entry","Retain the earned original Foundry level-start resource baseline before later checkpoint capture"): return false
	game.foundry_enabled = true
	foundry_started = true
	return await select_pistol()

func foundry_route(cells: Array) -> bool:
	print("FOUNDRY_BLOCK cells=",cells," native_frames=",east_elapsed()," ledger=",game.f_ledger)
	for cell in cells:
		var started: int = east_elapsed()
		if not await super.east_route([cell]): return false
		if not expect(east_elapsed()-started <= HOP_LIMIT,"Foundry hop including final process wait shares the 240-frame limit"): return false
	for id in game.f_consumed:
		if not expect(game.f_consumed[id] == 1 and f_markers[id].get_ref() == null,"Consumed original supply node must actually drain: "+id): return false
	return true

func fight_ids(ids: Array) -> bool:
	for frame in range(F_FIGHT_LIMIT):
		if not live_route(): return false
		if game.enemies.filter(func(actor): return actor.id in ids).all(func(actor): return actor.hp == 0): break
		release_actions()
		if not expect(east_fire(),"NATIVE RED bounded Foundry fight has no visible live original target; no damage/pose workaround"): return false
		if not await route_tick(): return false
	release_actions()
	return expect(ids.all(func(id): return game.f_deaths.get(id,0) == 1),"All specified originals must naturally die within 360 frames: "+str(ids))

func seal_input(id: String, cell: Array, key: String) -> bool:
	if key == "blood": f_blood_input = true
	else: f_ivory_input = true
	if not expect(route_level.markers.has(id) and game.state.removed.count(id) == 0,"Original uncollected seal precedes its actual input"): return false
	var before: Dictionary = game.budget()
	aim_interaction(cell)
	for pulse in range(2):
		interaction_input(true)
		if not await route_tick(): return false
		interaction_input(false)
		if not await route_tick(): return false
		await process_frame
		var expected_keys: Array = ["blood"] if key == "blood" else ["blood","ivory"]
		if not live_route() or not expect(game.state.keys == expected_keys and game.state.removed.count(id) == 1 and not route_level.markers.has(id) and game.state.ammo == before.ammo and game.state.health <= before.health,"Production interact earns only the intended seal once, including repeated input"): return false
	return expect(f_markers[id].get_ref() == null,"Collected original seal marker must drain")

func foundry_gate() -> bool:
	if not expect(game.state.checkpoint_id == "foundry_checkpoint" and game.f_checkpoint_saves == 1 and game.state.removed.count("foundry_checkpoint") == 1 and route_level.doors.has("foundry_gate"),"Actual automatic two-seal checkpoint/save precedes the still-physical gate"): return false
	var reference = weakref(route_level.doors.foundry_gate)
	var revision: int = route_level.get_node("NavigationRoutes").revision
	aim_interaction([13.0,4.7],2.5)
	interaction_input(true)
	if not await route_tick(): return false
	interaction_input(false)
	if not await route_tick(): return false
	if not expect(game.state.removed.count("foundry_gate") == 1 and not route_level.doors.has("foundry_gate") and reference.get_ref().collision_layer == 0 and route_level.get_node("NavigationRoutes").revision > revision,"Input-earned seals retire authored physical gate collision and invalidate navigation"): return false
	for frame in range(60):
		east_fire()
		if not await route_tick(): return false
		await process_frame
	release_actions()
	return expect(reference.get_ref() == null,"Actual gate node drains within 60 native waits")

func east_elapsed() -> int:
	return Engine.get_physics_frames()-f_epoch if foundry_started else super.east_elapsed()

func route_tick() -> bool:
	if not foundry_started: return await super.route_tick()
	if not live_route(): return false
	await physics_frame
	walk_ticks += 1
	return live_route()

func live_route() -> bool:
	if not foundry_started: return super.live_route()
	if not expect(east_elapsed() <= F_LIMIT and Time.get_ticks_usec()-f_wall_us <= F_SECONDS*1000000,"NATIVE RED frozen 7200-native-frame/150-second Foundry budget includes process waits"): return false
	if not expect(not paused and game.playing and not game.placement_pending and game.state.level_index == 1 and is_instance_valid(route_level) and is_instance_valid(route_player) and game.level == route_level and game.player == route_player and route_player._current_map() and not route_level.is_queued_for_deletion() and game.is_processing() and game.is_physics_processing() and route_player.is_physics_processing() and game.enemies.size() == 23 and actors.size() == 23,"Foundry retains live automatic original Main/Player/map and all 23 actors; no recovery/replacement"): return false
	var seen: Dictionary = {}
	for actor in game.enemies:
		if not expect(is_instance_valid(actor) and actors.has(actor.id) and actor.get_instance_id() == actors[actor.id][0] and actor.kind == f_kind[actor.id] and actor._current_map() and actor.is_physics_processing() and actor.age-actors[actor.id][1] >= float(east_elapsed()-2)/60.0,"Original Foundry actor retains native identity/type/age: "+actor.id): return false
		seen[actor.id] = true
		if actor.hp == 0 and not expect(game.f_deaths.get(actor.id,0) == 1 and game.state.removed.count(actor.id) == 1 and actor.collision_layer == 0 and actor.collision_mask == 0,"Observed natural death retires collision/removal once"): return false
	if not f_blood_input and not expect(game.state.keys.is_empty(),"Blood cannot precede input"): return false
	if f_blood_input and not f_ivory_input and not expect(game.state.keys in [[],["blood"]],"Ivory cannot precede input"): return false
	return expect(seen.size() == 23 and game.f_ok and game.rate_ok and game.feedback_ok and game.f_ticks >= east_elapsed()-2 and game.shots-f_shots_before == game.f_shots and game.budget() == game.f_ledger and game.state.health > 0 and game.state.health <= 100 and game.state.armor >= 0 and game.state.armor <= 200 and game.state.ammo[1] >= 0 and game.state.ammo[1] <= 180 and game.state.ammo.slice(2) == [0,0,0,0] and game.state.ammo[0] == 0 and game.state.owned_weapons == [0,1] and game.state.weapon == 1 and game.state.discoveries.is_empty(),"Independent Foundry native cadence/shot-age/capped callback ledger and pistol-only inventory remain exact")

func foundry_exit() -> bool:
	if not live_route(): return false
	var witnesses: Array = game.enemies.map(func(actor): return {"id":actor.id,"hp":actor.hp,"removed":game.state.removed.count(actor.id),"layer":actor.collision_layer,"mask":actor.collision_mask})
	if not expect(all_original_defeated(witnesses) and game.f_deaths.size() == 23 and game.f_finishes.get("foundry_enemy_03",false) and game.f_finishes.get("foundry_enemy_13",false),"All 23 original deaths precede teardown, with observed player finishes for both key-branch workers"): return false
	var living: Array = witnesses.duplicate(true)
	living[-1].hp = 1
	if not expect(not all_original_defeated(living),"A surviving non-required actor must fail the completion oracle"): return false
	for group in route_level.layout.data.encounters:
		if not expect(game.state.removed.count("encounter:"+group.id) == 1,"Every authored encounter is naturally activated once: "+group.id): return false
	var resources: Dictionary = game.f_ledger.duplicate(true)
	resources.merge({"keys":[],"removed":[],"floor_revision":1,"checkpoint_id":"entry","position":[0.0,0.0,0.0]})
	var expected: Dictionary = resources.duplicate(true)
	expected.merge({"version":2,"difficulty":1,"level_index":2,"discoveries":[],"explored":[],"checkpoint":resources.duplicate(true),"level_start":resources.duplicate(true)})
	for node in [route_level,route_player]+game.enemies: retired.append(weakref(node))
	aim_interaction([12.5,1.5])
	interaction_input(true)
	await physics_frame
	interaction_input(false)
	release_actions()
	await process_frame
	await process_frame
	var saved = game.state.get_script().new()
	if not expect(completion_matches(game.state.to_dict(),expected) and saved.load_progress(game.progress_path) and completion_matches(saved.to_dict(),expected) and game.state.level_index == 2 and not game.playing and game.level == null and game.player == null and retired.all(func(reference): return reference.get_ref() == null) and f_markers.values().all(func(reference): return reference.get_ref() == null) and east_elapsed() <= F_LIMIT and Time.get_ticks_usec()-f_wall_us <= F_SECONDS*1000000,"Actual Foundry exit preserves independent earned resources in both recovery envelopes/save and drains all original nodes within bounds"): return false
	var corrupt: Dictionary = expected.duplicate(true)
	corrupt.checkpoint.ammo[1] += 1
	if not expect(not completion_matches(corrupt,expected),"Independent save oracle rejects a stale recovery resource"): return false
	var offered: bool = false
	for node in game.menu.get_children():
		if node is Button and not node.is_queued_for_deletion() and node.text == "Descend to The Processional": offered = true
	print("FOUNDRY_EARNED_EXIT native_frames=",east_elapsed()," shots=",game.f_shots," actual_consumed=",game.f_consumed," resources=",game.f_ledger)
	return expect(offered,"Actual completion exposes Processional descent, without starting a third map")

static func completion_matches(actual: Dictionary, expected: Dictionary) -> bool:
	return actual == expected
