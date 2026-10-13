extends "res://tests/test_processional_earned_palanquin.gd"

const X_LIMIT = 2500
const X_SECONDS = 60
const X_PALANQUIN_SHA = "50f5541614bb32479f440afb75583c99a336f304e359490cdc12a198291cde5f"
const X_ROUTE = [[16.5,21.0],[16.5,17.5],[16.5,14.5],[16.5,11.5],[16.5,8.5],[15.5,8.5],[16.0,6.75],[16.0,5.7]]
const X_EXIT = [[16.0,3.5],[15.5,2.5],[15.5,1.5]]
const X_FINAL = ["processional_enemy_23","processional_enemy_24","processional_enemy_25"]
const X_SHELLS = {"id":"processional_gate_shells","kind":"ammo","cell":[15.5,8.5],"amount":12.0,"weapon":2.0}
const X_CHECKPOINT = {"id":"processional_checkpoint","kind":"checkpoint","cell":[16.5,8.5],"requires":["blood","ivory"],"text":"RECOVERY IMAGE STORED"}
const X_DOOR = {"id":"processional_gate","cell":[16.0,4.7],"size":[8.2,5.0,0.6],"requires":["blood","ivory"],"yaw":0.0}
const X_EXIT_SPEC = {"id":"processional_exit","kind":"exit","cell":[15.5,1.5],"requires":["blood","ivory"],"text":"AIR FEED RESTORED / DESCEND"}

class ExitMain:
	extends "res://tests/test_processional_earned_palanquin.gd".PalanquinMain
	var exit_enabled: bool = false
	var x_ok: bool = true
	var x_ticks: int = 0
	var x_ledger: Dictionary = {}
	var x_shots: int = 0
	var x_last: int = -1
	var x_slot: float = -1.0
	var x_deaths: Dictionary = {}
	var x_finishes: Dictionary = {}
	var x_infights: Dictionary = {}
	var x_infight_attacks: Dictionary = {}
	var x_attacks: Dictionary = {}
	var x_attack_hits: Dictionary = {}
	var x_removed: Array = []
	var x_bindings: Dictionary = {}
	var x_start: Dictionary = {}
	var x_checkpoint: Dictionary = {}
	var x_explored: Array = []
	var x_last_cell: Vector2i = Vector2i(-1,-1)
	var x_checkpoint_saves: int = 0
	var x_exit_saves: int = 0
	var x_save_sha: String = ""
	var x_exit_expected: Dictionary = {}
	var x_exit_intent: bool = false
	var x_gate_input: bool = false
	var x_shell_rejections: int = 0
	var x_shell_marker
	func _physics_process(delta: float) -> void:
		super._physics_process(delta)
		if state.level_index == 2 and _scene_level_index == 2 and playing and not get_tree().paused and is_instance_valid(player):
			# Independent native survey read before the child Survey runs; never changes its state.
			var cell = Vector2i((Vector2(player.position.x,player.position.z)/4.0).floor())
			if cell != x_last_cell and level.layout.is_walkable(cell):
				x_last_cell = cell
				for a in range(cell.x-2,cell.x+3):
					for b in range(cell.y-2,cell.y+3):
						var point = Vector2i(a,b)
						var saved: Array = [a,b]
						if not level.layout.is_walkable(point) or saved in x_explored: continue
						var destination: Vector3 = level.layout.world_position([a+0.5,b+0.5])+Vector3.UP*1.55
						var ray = PhysicsRayQueryParameters3D.create(player.camera.global_position,destination,1)
						if point == cell or level.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): x_explored.append(saved)
			if exit_enabled:
				x_ticks += 1
				x_ok = x_ok and absf(delta-1.0/60.0) < 0.000001
				if not Input.is_action_pressed("fire"): x_slot = -1.0
	func observed_yaw(value: float) -> float:
		# Independent of the production converter so jointly wrong saved facing cannot pass.
		if value < -PI or value >= PI: value = fposmod(value+PI,TAU)-PI
		return Vector3(0,clampf(value,-3.1415925,3.1415925),0).y
	func witnessed_infighting(victim) -> bool:
		var source = victim.target
		if not is_instance_valid(source) or source == victim or not source in enemies: return false
		if not source.id in X_FINAL or x_bindings.get(source.id,-1) != source.get_instance_id() or not source._current_map() or not source.active or source.hp <= 0: return false
		var tick: int = int(x_attacks.get(source.id,-1000))
		var age: int = Engine.get_physics_frames()-tick
		var key: String = source.id+":"+str(tick)
		if x_infight_attacks.has(key) or age < 0 or not ((source.kind == "worker" and age == 0) or (source.kind == "crawler" and age <= 12)): return false
		var stack: Array = get_stack()
		if not stack.any(func(frame): return str(frame.get("source","")).ends_with("/enemy.gd") and frame.get("function","") == "_attack") or not stack.any(func(frame): return str(frame.get("source","")).ends_with("/enemy.gd") and frame.get("function","") == "_physics_process"): return false
		x_infight_attacks[key] = true
		return true
	func original_capture() -> Array:
		var result: Array = []
		for actor in enemies:
			x_ok = x_ok and L_ACTORS.has(actor.id) and actor.kind == L_ACTORS[actor.id].kind and actor.max_hp == (50 if actor.kind == "crawler" else 90) and actor._current_map() and actor.position.is_finite() and is_finite(actor.rotation.y)
			if x_bindings.has(actor.id): x_ok = x_ok and actor.get_instance_id() == x_bindings[actor.id]
			else: x_bindings[actor.id] = actor.get_instance_id()
			if actor.hp > 0:
				result.append({"id":actor.id,"hp":actor.hp,"position":[actor.position.x,actor.position.y,actor.position.z],"yaw":observed_yaw(actor.rotation.y),"alerted":actor.alerted})
		return result
	func _capture_actor_state() -> bool:
		if state.level_index == 2 and _scene_level_index == 2 and is_instance_valid(level) and is_instance_valid(player) and level.layout.data.id == "processional":
			if x_start.is_empty():
				for actor in enemies:
					x_ok = x_ok and L_ACTORS.has(actor.id) and absf(angle_difference(actor.rotation.y,deg_to_rad(float(L_ACTORS[actor.id].yaw)))) <= 0.000001
				var originals: Array = original_capture()
				x_ok = x_ok and originals.size() == 26 and enemies.all(func(actor): return actor.hp == actor.max_hp) and state.keys.is_empty() and state.removed.is_empty()
				x_start = {"health":93,"armor":89,"ammo":[0,164,0,0,0,0],"owned_weapons":[0,1],"weapon":1,"keys":[],"removed":[],"checkpoint_id":"entry","position":[86.0,0.0,118.0],"actors":originals,"yaw":0.0,"pitch":0.0}
			if exit_enabled and "processional_checkpoint" in state.removed and not "processional_checkpoint" in x_removed:
				x_ok = x_ok and Engine.is_in_physics_frame() and state.keys == ["blood","ivory"] and player.position.distance_to(level.layout.world_position([16.5,8.5])) < 3.2 and get_stack().any(func(frame): return str(frame.get("source","")).ends_with("/main.gd") and frame.get("function","") == "update_passive_triggers")
				x_removed.append("processional_checkpoint")
		return super._capture_actor_state()
	func collect_pickup(id: String) -> void:
		var third: bool = state.level_index == 2
		var count: int = state.removed.count(id)
		if exit_enabled:
			var matches: Array = level.layout.data.pickups.filter(func(spec): return spec.id == id)
			x_ok = x_ok and id == "processional_gate_shells" and matches.size() == 1 and matches[0] == X_SHELLS and Engine.is_in_physics_frame() and budget() == x_ledger and state.ammo[2] == 32 and count == 0 and is_instance_valid(x_shell_marker) and level.markers.get(id) == x_shell_marker and not x_shell_marker.is_queued_for_deletion()
		super.collect_pickup(id)
		if third and count == 0 and state.removed.count(id) == 1: x_removed.append(id)
		if exit_enabled:
			x_shell_rejections += 1
			x_ok = x_ok and budget() == x_ledger and state.removed.count(id) == 0 and level.markers.get(id) == x_shell_marker and is_instance_valid(x_shell_marker) and not x_shell_marker.is_queued_for_deletion()
	func collect_key(id: String) -> void:
		var third: bool = state.level_index == 2
		var count: int = state.removed.count(id)
		if exit_enabled: x_ok = false
		super.collect_key(id)
		if third and count == 0 and state.removed.count(id) == 1: x_removed.append(id)
	func activate_encounter(id: String) -> void:
		var third: bool = state.level_index == 2
		var count: int = state.removed.count("encounter:"+id)
		if exit_enabled and count == 0: x_ok = x_ok and id == "processional_gate_release" and playing and state.keys == ["blood","ivory"]
		super.activate_encounter(id)
		if third and count == 0 and state.removed.count("encounter:"+id) == 1: x_removed.append("encounter:"+id)
	func enemy_event(actor, event: String) -> void:
		super.enemy_event(actor,event)
		if state.level_index == 2 and event == "death":
			x_deaths[actor.id] = x_deaths.get(actor.id,0)+1
			x_removed.append(actor.id)
			x_ok = x_ok and Engine.is_in_physics_frame() and actor._current_map() and x_bindings.get(actor.id,-1) == actor.get_instance_id() and actor.hp == 0 and actor.collision_layer == 0 and actor.collision_mask == 0 and state.removed.count(actor.id) == 1 and x_deaths[actor.id] == 1
		if exit_enabled:
			x_ok = x_ok and actor.id in ["processional_enemy_23","processional_enemy_24","processional_enemy_25"] and actor.active and actor._current_map() and actor.get_instance_id() == x_bindings[actor.id]
			if event == "attack": x_attacks[actor.id] = Engine.get_physics_frames()
			if event == "death": x_finishes[actor.id] = Input.is_action_pressed("fire") and x_last == Engine.get_physics_frames() and player.shot_age(1) == 0.0 and actor.target == player and aim_observation.get("actor_id","") == actor.id and aim_observation.get("tick",-1) == Engine.get_physics_frames() and aim_observation.get("level") == level and aim_observation.get("player") == player and aim_observation.get("weapon",-1) == 1 and get_stack().any(func(frame): return str(frame.get("source","")).ends_with("/player.gd") and frame.get("function","") == "fire")
			if event == "death": x_infights[actor.id] = witnessed_infighting(actor)
	func shot(weapon: int) -> void:
		if exit_enabled:
			var tick: int = Engine.get_physics_frames()
			x_slot = palanquin_slot(tick,x_last,x_slot,weapon)
			var expected: Dictionary = x_ledger.duplicate(true)
			expected.ammo[1] -= 1
			x_ok = x_ok and Engine.is_in_physics_frame() and playing and player._current_map() and weapon == 1 and state.weapon == 1 and Input.is_action_pressed("fire") and not player._fire_release_required and x_slot >= 0.0 and player.shot_age(1) == 0.0 and player._last_shots[1] == player.active_play_time and budget() == expected and expected.ammo[1] >= 0
			x_ledger = expected
			x_shots += 1
			x_last = tick
		super.shot(weapon)
	func hurt_player(amount: int) -> void:
		if not exit_enabled:
			super.hurt_player(amount)
			return
		var matched: String = ""
		for actor in enemies:
			var tick: int = int(x_attacks.get(actor.id,-1000))
			var age: int = Engine.get_physics_frames()-tick
			var key: String = actor.id+":"+str(tick)
			if actor.id in ["processional_enemy_23","processional_enemy_24","processional_enemy_25"] and actor.get_instance_id() == x_bindings[actor.id] and actor._current_map() and actor.active and actor.hp > 0 and actor._committed_target == player and not x_attack_hits.has(key) and age >= 0 and ((actor.kind == "worker" and amount == 10 and age == 0) or (actor.kind == "crawler" and amount == 12 and age <= 12)):
				matched = key
				break
		x_ok = x_ok and Engine.is_in_physics_frame() and not matched.is_empty() and budget() == x_ledger and get_stack().any(func(frame): return str(frame.get("source","")).ends_with("/enemy.gd") and frame.get("function","") == "_attack")
		if not matched.is_empty(): x_attack_hits[matched] = true
		var expected: Dictionary = x_ledger.duplicate(true)
		var absorbed: int = mini(int(expected.armor),int(amount/3))
		expected.armor -= absorbed
		expected.health = maxi(0,int(expected.health)-(amount-absorbed))
		super.hurt_player(amount)
		x_ok = x_ok and budget() == expected
		x_ledger = expected
	func _debug_projectile_event(projectile: Node3D, event: String, data: Dictionary) -> void:
		if not exit_enabled: super._debug_projectile_event(projectile,event,data)
		else: x_ok = false # All four original casters are already dead at this handoff.
	func unlock_door(id: String) -> bool:
		if exit_enabled:
			var matches: Array = level.layout.data.doors.filter(func(spec): return spec.id == id)
			x_ok = x_ok and x_gate_input and id == "processional_gate" and matches.size() == 1 and matches[0] == X_DOOR and Engine.is_in_physics_frame() and Input.is_action_pressed("interact") and state.keys == ["blood","ivory"] and state.removed.count(id) == 0 and budget() == x_ledger
		var result: bool = super.unlock_door(id)
		if exit_enabled:
			x_removed.append(id)
			x_ok = x_ok and result and state.removed.count(id) == 1 and not level.doors.has(id) and budget() == x_ledger
		return result
	func checkpoint_resources() -> Dictionary:
		var expected: Dictionary = x_ledger.duplicate(true)
		expected.merge({"keys":["blood","ivory"],"removed":x_removed.duplicate(),"checkpoint_id":"processional_checkpoint","position":[player.position.x,player.position.y,player.position.z],"actors":original_capture(),"yaw":observed_yaw(player.rotation.y),"pitch":clampf(player.camera.rotation.x,-1.35,1.35)},true)
		return expected
	func _save() -> Error:
		if not exit_enabled: return super._save()
		var checkpoint_save: bool = state.level_index == 2
		var expected: Dictionary
		if checkpoint_save:
			x_ok = x_ok and x_checkpoint_saves == 0 and state.checkpoint_id == "processional_checkpoint" and "processional_checkpoint" in x_removed and Engine.is_in_physics_frame() and get_stack().any(func(frame): return str(frame.get("source","")).ends_with("/main.gd") and frame.get("function","") == "update_passive_triggers")
			x_checkpoint = checkpoint_resources()
			expected = x_checkpoint.duplicate(true)
			expected.merge({"version":1,"difficulty":1,"level_index":2,"discoveries":[],"explored":x_explored.duplicate(true),"checkpoint":x_checkpoint.duplicate(true),"level_start":x_start.duplicate(true)},true)
		else:
			x_ok = x_ok and state.level_index == 3 and x_exit_intent and Engine.is_in_physics_frame() and Input.is_action_pressed("interact") and get_stack().any(func(frame): return str(frame.get("source","")).ends_with("/main.gd") and frame.get("function","") == "interact")
			expected = x_exit_expected.duplicate(true)
		var original_level = level
		var original_player = player
		var result: Error = super._save()
		var saved = state.get_script().new()
		x_save_sha = FileAccess.get_sha256(progress_path)
		x_ok = x_ok and result == OK and level == original_level and player == original_player and is_instance_valid(original_level) and not original_level.is_queued_for_deletion() and is_instance_valid(original_player) and original_player.get_parent() == original_level and x_save_sha.length() == 64 and saved.load_progress(progress_path) and saved.to_dict() == expected and state.to_dict() == expected
		if checkpoint_save: x_checkpoint_saves += 1
		else: x_exit_saves += 1
		return result

var exit_started: bool = false
var x_epoch: int = 0
var x_wall_us: int = 0
var x_main_id: int = 0
var x_profile: String = ""
var x_start_shots: int = 0
var x_ages: Dictionary = {}
var x_marker_refs: Dictionary = {}

func run() -> void:
	prefix = "user://processional_earned_exit_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	if not await walk_to_processional_exit(ExitMain.new(),prefix):
		await finish(1)
		return
	print("PASS source-debug candidate earned Intake/Foundry/complete Processional exit and fourth-level menu only; native virtual Input/original actors/private-save evidence. Not physical input, full eight-level campaign, rendering/audio/performance or packed-app acceptance.")
	await finish(0)

func walk_to_processional_exit(observer, profile_prefix: String) -> bool:
	prefix = profile_prefix
	if not await walk_to_palanquin_loop(observer,prefix) or not start_exit_stage():
		return false
	if not await exit_route(X_ROUTE) or not await gate_input_final() or not await exit_route(X_EXIT) or not await organ_fight(X_FINAL) or not await processional_exit():
		return false
	return true

func start_exit_stage() -> bool:
	var earned: Dictionary = {"health":100,"armor":200,"ammo":[0,138,32,0,0,0],"owned_weapons":[0,1,2],"weapon":1}
	if not expect(FileAccess.get_sha256("res://tests/test_processional_earned_palanquin.gd") == X_PALANQUIN_SHA and game.l_ok and game.x_ok and game.budget() == earned and game.state.keys == ["blood","ivory"] and game.l_deaths.size() == 23 and game.x_deaths.size() == 23 and game.enemies.size() == 26 and game.state.removed == game.x_removed and game.state.explored == game.x_explored and game.state.checkpoint == game.x_start and game.state.level_start == game.x_start,"Exact gated Palanquin handoff/resources/23 observed deaths/independent original entry envelope and survey precede final epoch"): return false
	for id in X_FINAL:
		var matches: Array = game.enemies.filter(func(actor): return actor.id == id)
		if not expect(matches.size() == 1 and matches[0].hp == (50 if matches[0].kind == "crawler" else 90) and not matches[0].active,"Remaining original gate actors start unmodified and dormant: "+id): return false
	for actor in game.enemies: x_ages[actor.id] = actor.age
	x_main_id = game.get_instance_id()
	x_profile = game.progress_path
	for id in route_level.markers: x_marker_refs[id] = weakref(route_level.markers[id])
	if not expect(route_level.markers.has("processional_gate_shells") and route_level.doors.has("processional_gate") and route_level.layout.data.interactions.filter(func(spec): return spec.id == "processional_checkpoint") == [X_CHECKPOINT] and route_level.layout.data.interactions.filter(func(spec): return spec.id == "processional_exit") == [X_EXIT_SPEC],"Frozen original gate/checkpoint/exit/shell marker targets"): return false
	game.x_shell_marker = route_level.markers.processional_gate_shells
	release_actions()
	game.palanquin_enabled = false
	game.x_ledger = earned.duplicate(true)
	game.x_last = game.l_last[1]
	x_start_shots = game.shots
	x_epoch = Engine.get_physics_frames()
	x_wall_us = Time.get_ticks_usec()
	game.exit_enabled = true
	exit_started = true
	return live_route()

func east_elapsed() -> int:
	return Engine.get_physics_frames()-x_epoch if exit_started else super.east_elapsed()

func route_tick() -> bool:
	if not exit_started: return await super.route_tick()
	if not live_route(): return false
	await physics_frame
	return live_route()

func exit_route(cells: Array) -> bool:
	print("PROCESSIONAL_FINAL_BLOCK cells=",cells," frames=",east_elapsed()," ledger=",game.x_ledger)
	for cell in cells:
		var tick: int = east_elapsed()
		if not await east_route([cell]) or not expect(east_elapsed()-tick <= HOP_LIMIT,"NATIVE RED final hop including process wait; target="+str(cell)+" position="+str(route_player.position)+" ledger="+str(game.x_ledger)): return false
	return true

func gate_input_final() -> bool:
	if not live_route() or not expect(game.x_checkpoint_saves == 1 and game.state.checkpoint == game.x_checkpoint and game.state.level_start == game.x_start and game.x_shell_rejections > 0,"Actual independent two-seal checkpoint/save and rejected full shells precede door input"): return false
	var gate = route_level.doors.processional_gate
	var reference = weakref(gate)
	var revision: int = route_level.get_node("NavigationRoutes").revision
	aim_interaction([16.0,4.7],2.5)
	game.x_gate_input = true
	interaction_input(true)
	if not await route_tick(): return false
	await process_frame
	if not live_route(): return false
	interaction_input(false)
	if not await route_tick(): return false
	if not expect(not route_level.doors.has("processional_gate") and is_instance_valid(reference.get_ref()) and reference.get_ref().collision_layer == 0 and route_level.get_node("NavigationRoutes").revision > revision,"Actual Input removes original door collision and invalidates routes"): return false
	for frame in range(60):
		east_fire()
		if not await route_tick(): return false
		await process_frame
	release_actions()
	return expect(reference.get_ref() == null,"Original gate tween/node drains within frozen 60 native waits")

func live_route() -> bool:
	if not exit_started: return super.live_route()
	if not expect(east_elapsed() <= X_LIMIT and Time.get_ticks_usec()-x_wall_us <= X_SECONDS*1000000,"NATIVE RED frozen final epoch 2500 physics frames/60 wall seconds"): return false
	if not expect(not paused and game.playing and not game.placement_pending and game.state.level_index == 2 and game.get_instance_id() == x_main_id and game.progress_path == x_profile and is_instance_valid(route_level) and is_instance_valid(route_player) and game.level == route_level and game.player == route_player and route_player._current_map() and game.is_processing() and game.is_physics_processing() and route_player.is_physics_processing() and game.enemies.size() == 26 and route_level.layout.data.enemies == L_ACTOR_SPECS,"Same live automatic Main/profile/Player/map and all original actors before real exit"): return false
	var seen: Dictionary = {}
	for actor in game.enemies:
		if not expect(is_instance_valid(actor) and game.x_bindings.get(actor.id,-1) == actor.get_instance_id() and not seen.has(actor.id) and actor.kind == L_ACTORS[actor.id].kind and actor.max_hp == (50 if actor.kind == "crawler" else 90) and actor.hp >= 0 and actor.hp <= actor.max_hp and actor._current_map() and actor.is_physics_processing() and actor.age-x_ages[actor.id] >= float(east_elapsed()-2)/60.0,"Native original identity/role/HP/age: "+actor.id): return false
		seen[actor.id] = true
		if actor.hp == 0:
			if not expect(game.x_deaths.get(actor.id,0) == 1 and actor.collision_layer == 0 and actor.collision_mask == 0 and game.state.removed.count(actor.id) == 1,"Each original death/removal/collision once"): return false
		elif not expect(actor.id in X_FINAL and actor.collision_layer == 4 and actor.collision_mask == 7,"Only unchanged final three can remain living"): return false
	if not expect(not route_level.get_children().any(func(node): return node.get_script() == preload("res://scripts/projectile.gd")),"No new projectile is legitimate after all casters have died"): return false
	return expect(seen.size() == 26 and game.x_ok and game.rate_ok and game.feedback_ok and game.shot_clock_ok and game.x_ticks >= east_elapsed()-2 and game.shots-x_start_shots == game.x_shots and game.budget() == game.x_ledger and game.state.health > 0 and game.state.health <= 100 and game.state.armor >= 0 and game.state.armor <= 200 and game.state.ammo[1] >= 0 and game.state.ammo[1] <= 180 and game.state.ammo == [0,game.x_ledger.ammo[1],32,0,0,0] and game.state.owned_weapons == [0,1,2] and game.state.weapon == 1 and game.state.keys == ["blood","ivory"] and game.state.removed == game.x_removed and game.state.explored == game.x_explored and game.state.discoveries.is_empty() and game.state.level_start == game.x_start and game.state.checkpoint == (game.x_checkpoint if game.x_checkpoint_saves == 1 else game.x_start),"Independent final shot/damage/removal/survey ledger and complete original/checkpoint envelopes")

func processional_exit() -> bool:
	if not live_route(): return false
	if not expect(game.x_deaths.size() == 26 and game.enemies.all(func(actor): return actor.hp == 0 and game.x_deaths.get(actor.id,0) == 1 and game.state.removed.count(actor.id) == 1 and actor.collision_layer == 0 and actor.collision_mask == 0) and X_FINAL.all(func(id): return game.x_finishes.get(id,false) or game.x_infights.get(id,false)),"All26 originals naturally die once, with witnessed Player-fire or original native infighting provenance for every final death, before teardown"): return false
	if not expect(game.x_shell_rejections > 0 and is_instance_valid(game.x_shell_marker) and route_level.markers.get("processional_gate_shells") == game.x_shell_marker and not game.x_shell_marker.is_queued_for_deletion() and not "processional_gate_shells" in game.state.removed,"Rejected full-cap original shell marker survives through actual exit boundary"): return false
	for group in route_level.layout.data.encounters:
		if not expect(game.state.removed.count("encounter:"+group.id) == 1,"Each original Processional encounter activated once: "+group.id): return false
	var resources: Dictionary = game.x_ledger.duplicate(true)
	resources.merge({"keys":[],"removed":[],"checkpoint_id":"entry","position":[0.0,0.0,0.0]},true)
	game.x_exit_expected = resources.duplicate(true)
	game.x_exit_expected.merge({"version":1,"difficulty":1,"level_index":3,"discoveries":[],"explored":[],"checkpoint":resources.duplicate(true),"level_start":resources.duplicate(true)},true)
	for node in [route_level,route_player]+game.enemies: retired.append(weakref(node))
	aim_interaction([15.5,1.5])
	game.x_exit_intent = true
	interaction_input(true)
	await physics_frame
	await process_frame
	interaction_input(false)
	release_actions()
	await process_frame
	await process_frame
	var saved = game.state.get_script().new()
	if not expect(game.x_ok and game.x_exit_saves == 1 and game.state.to_dict() == game.x_exit_expected and saved.load_progress(game.progress_path) and saved.to_dict() == game.x_exit_expected and FileAccess.get_sha256(game.progress_path) == game.x_save_sha and game.state.level_index == 3 and not game.playing and game.level == null and game.player == null and retired.all(func(reference): return reference.get_ref() == null) and x_marker_refs.values().all(func(reference): return reference.get_ref() == null) and east_elapsed() <= X_LIMIT and Time.get_ticks_usec()-x_wall_us <= X_SECONDS*1000000,"Actual Processional exit preserves whole earned next-level/current/save/recovery state and drains original nodes within fixed bounds"): return false
	var offered: bool = false
	var completed: bool = false
	for node in game.menu.get_children():
		if node is Button and node.text == "Descend to The Reliquary" and not node.is_queued_for_deletion(): offered = true
		if node is Label and node.text == "THE PROCESSIONAL RESTORED": completed = true
	print("PROCESSIONAL_EARNED_EXIT frames=",east_elapsed()," shots=",game.x_shots," ledger=",game.x_ledger," checkpoint_sha/exit_sha=",game.x_save_sha," observed_original_deaths=",game.x_deaths.size())
	return expect(offered and completed,"Actual completed Processional title exposes fourth-level descent without starting it")
