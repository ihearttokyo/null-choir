extends "res://tests/test_processional_earned_exit.gd"

const R_PREFIX_SHA = "33b04dd865be7260da0bf92450687a82d3a720699e609798f25e7f20ecb82ec8"
const R_MAP_SHA = "939a0c10a73463a7c693fdf682362864758e2b9c21211a06a3ae99afccf43d92"
const R_LIMIT = 120
const R_SECONDS = 10
const R_CARRY = {"health":100,"armor":200,"ammo":[0,125,32,0,0,0],"owned_weapons":[0,1,2],"weapon":1}
# Independent authored table: id, role, HP, cell x/z, floor height, facing degrees.
const R_ACTORS = [
	["reliquary_enemy_00","crawler",50,4.5,19.5,-2.0,-128.66],
	["reliquary_enemy_01","crawler",50,10.5,20.5,-2.0,161.565],
	["reliquary_enemy_02","crawler",50,3.5,17.5,-2.0,-135.0],
	["reliquary_enemy_03","crawler",50,9.5,13.5,-2.0,-180.0],
	["reliquary_enemy_04","worker",90,11.5,14.5,-2.0,167.471],
	["reliquary_enemy_05","worker",90,4.5,12.5,-2.0,-155.556],
	["reliquary_enemy_06","worker",90,12.0,20.0,-2.0,144.462],
	["reliquary_enemy_07","caster",90,7.5,11.5,-2.0,-170.538],
	["reliquary_enemy_08","crawler",50,28.5,19.5,2.0,-165.964],
	["reliquary_enemy_09","crawler",50,35.5,19.5,2.0,123.69],
	["reliquary_enemy_10","crawler",50,27.5,12.5,2.0,-169.695],
	["reliquary_enemy_11","crawler",50,34.5,11.5,2.0,157.38],
	["reliquary_enemy_12","worker",90,35.5,16.5,2.0,139.399],
	["reliquary_enemy_13","worker",90,28.5,15.0,2.0,-173.29],
	["reliquary_enemy_14","worker",90,33.5,9.5,2.0,164.055],
	["reliquary_enemy_15","caster",90,31.5,9.5,2.0,171.87],
	["reliquary_enemy_16","crawler",50,15.5,12.5,-0.75,-75.964],
	["reliquary_enemy_17","worker",90,16.0,10.5,-0.5,-105.945],
	["reliquary_enemy_18","worker",90,18.5,10.5,0.0,-135.0],
	["reliquary_enemy_19","crawler",50,24.5,12.5,1.25,78.69],
	["reliquary_enemy_20","worker",90,22.5,13.5,0.25,56.31],
	["reliquary_enemy_21","worker",90,23.5,11.5,0.75,90.0],
	["reliquary_enemy_22","crawler",50,18.5,13.5,0.0,-18.435],
	["reliquary_enemy_23","crawler",50,20.5,14.5,0.0,14.036],
	["reliquary_enemy_24","worker",90,18.5,15.5,0.0,-11.31],
	["reliquary_enemy_25","worker",90,20.5,13.5,0.0,18.435],
	["reliquary_enemy_26","caster",90,19.5,15.5,0.0,0.0],
	["reliquary_enemy_27","crawler",50,19.5,5.5,0.0,-180.0],
	["reliquary_enemy_28","worker",90,18.5,4.5,0.0,-158.199],
	["reliquary_enemy_29","worker",90,20.5,5.5,0.0,146.31],
	["reliquary_enemy_30","caster",90,19.5,2.5,0.0,-180.0]]
const R_THIRD_FIELDS = [
	"p_ok","p_ticks","p_shots","p_last","p_slots","p_selected",
	"p_ledger","p_originals","p_consumed","p_pickups","p_deaths","p_finishes",
	"p_attacks","p_damage_attacks","o_ok","o_ticks","o_ledger","o_keys",
	"o_shots","o_last","o_slots","o_consumed","o_rejected","o_deaths",
	"o_finishes","o_attacks","o_attack_hits","o_births","o_contacts","o_used",
	"o_pending","o_projectile_hurts","o_blood_calls","l_ok","l_ticks","l_ledger",
	"l_keys","l_shots","l_last","l_slots","l_consumed","l_rejected",
	"l_deaths","l_finishes","l_attacks","l_attack_hits","l_births","l_contacts",
	"l_used","l_pending","l_projectile_hurts","l_ivory_calls","x_ok","x_ticks",
	"x_ledger","x_shots","x_last","x_slot","x_deaths","x_finishes",
	"x_infights","x_infight_attacks","x_attacks","x_attack_hits","x_removed","x_bindings",
	"x_start","x_checkpoint","x_explored","x_last_cell","x_checkpoint_saves","x_exit_saves",
	"x_save_sha","x_exit_expected","x_exit_intent","x_gate_input","x_shell_rejections"]

const R_INHERITED_FIELDS = ["shots", "hits", "impacts", "attacks", "deaths", "last_shot", "rate_ok", "shot_ok", "feedback_ok", "player_finish", "west_firing_id", "west_deaths", "west_finishes", "shot_clock_ok", "nave_calls", "nave_reward_ok", "f_ok", "f_ticks", "f_shots", "f_last_shot", "f_slot", "f_ledger", "f_consumed", "f_deaths", "f_finishes", "f_attacks", "f_checkpoint_saves", "f_level_start"]

class ReliquaryMain:
	extends "res://tests/test_processional_earned_exit.gd".ExitMain
	var r_ok: bool = true
	var r_main_origin: int = 0
	var r_campaign_origin: int = 0
	var r_profile_origin: String = ""
	var r_settings_origin: String = ""
	var r_captures: int = 0
	var r_capture_attempts: Array = []
	var r_bindings: Dictionary = {}
	var r_level_id: int = 0
	var r_player_id: int = 0
	var r_start: Dictionary = {}
	var r_ticks: int = 0
	var r_explored: Array = []
	var r_last_cell: Vector2i = Vector2i(-1,-1)
	func _ready() -> void:
		r_main_origin = get_instance_id()
		r_campaign_origin = state.get_instance_id()
		r_profile_origin = progress_path
		r_settings_origin = settings_path
		super._ready()
	func fourth_scene() -> bool:
		return state.level_index == 3 and _scene_level_index == 3 and is_instance_valid(level) and not level.is_queued_for_deletion() and is_instance_valid(player) and not player.is_queued_for_deletion() and player.get_parent() == level and level.layout.data.id == "reliquary"
	func _capture_game_mouse() -> void:
		# Count real default-setter attempts, including the whole unchanged prefix.
		r_capture_attempts.append([state.level_index,_scene_level_index,get_instance_id(),level.get_instance_id() if is_instance_valid(level) else 0,player.get_instance_id() if is_instance_valid(player) else 0,Engine.get_physics_frames(),placement_pending,playing])
		super._capture_game_mouse()
	func scene_roster_matches() -> bool:
		var actual: Array = level.get_children().filter(func(node): return node is Enemy).map(func(node): return node.get_instance_id())
		var bound: Array = r_bindings.values()
		actual.sort()
		bound.sort()
		return actual.size() == 31 and actual == bound
	func expected_originals() -> Array:
		var result: Array = []
		for spec in R_ACTORS:
			var point: Vector3 = Vector3(spec[3]*4.0,spec[5],spec[4]*4.0)+Vector3(0,0.03,0)
			if spec[1] == "caster": point.y += 1.0
			# Preserve authored -180 before native precision crosses the periodic boundary.
			var facing: float = deg_to_rad(spec[6])
			result.append({"id":spec[0],"hp":spec[2],"position":[point.x,point.y,point.z],"yaw":observed_yaw(facing),"alerted":false})
		return result
	func _capture_actor_state() -> bool:
		if fourth_scene():
			r_captures += 1
			r_ok = r_ok and r_captures == 1 and not playing and not placement_pending and not loaded_positions and state.position == Vector3(78,0,154) and player.position == Vector3(78,0.04,154) and player.rotation.y == 0.0 and player.camera.rotation.x == 0.0 and state.keys.is_empty() and state.removed.is_empty() and state.explored.is_empty() and state.actors == null and get_stack().any(func(frame): return str(frame.get("source","")).ends_with("/main.gd") and frame.get("function","") == "start_level")
			r_level_id = level.get_instance_id()
			r_player_id = player.get_instance_id()
			var expected: Array = expected_originals()
			r_ok = r_ok and enemies.size() == 31
			for index in range(enemies.size()):
				var actor = enemies[index]
				if index >= R_ACTORS.size() or not is_instance_valid(actor):
					r_ok = false
					continue
				var spec: Array = R_ACTORS[index]
				var record: Dictionary = expected[index]
				r_ok = r_ok and actor.get_script() == Enemy and actor.id == spec[0] and actor.kind == spec[1] and actor.max_hp == spec[2] and actor.hp == spec[2] and actor.position == Vector3(record.position[0],record.position[1],record.position[2]) and actor.rotation.y == Vector3(0,deg_to_rad(spec[6]),0).y and actor._current_map() and actor.get_parent() == level and not actor.active and not actor.alerted and actor.age == 0.0 and actor.collision_layer == 4 and actor.collision_mask == 7 and not r_bindings.has(actor.id) and not actor.get_instance_id() in x_bindings.values()
				var body_shape: CollisionShape3D = actor.get_child(0)
				r_ok = r_ok and not body_shape.disabled and body_shape.shape is CapsuleShape3D and absf(body_shape.shape.height-(1.1 if spec[1] == "crawler" else 2.7)) < 0.000001 and absf(body_shape.shape.radius-(0.42 if spec[1] == "crawler" else 0.34)) < 0.000001
				r_bindings[actor.id] = actor.get_instance_id()
			r_ok = r_ok and scene_roster_matches()
			r_start = R_CARRY.duplicate(true)
			r_start.merge({"keys":[],"removed":[],"checkpoint_id":"entry","position":[78.0,0.0,154.0],"actors":expected,"yaw":0.0,"pitch":0.0},true)
		var result: bool = super._capture_actor_state()
		if fourth_scene(): r_ok = r_ok and result and state.actors == r_start.actors and state.yaw == 0.0 and state.pitch == 0.0
		return result
	func _physics_process(delta: float) -> void:
		super._physics_process(delta)
		if not fourth_scene() or not playing or get_tree().paused: return
		r_ticks += 1
		r_ok = r_ok and absf(delta-1.0/60.0) < 0.000001 and level.get_instance_id() == r_level_id and player.get_instance_id() == r_player_id
		var cell: Vector2i = Vector2i((Vector2(player.position.x,player.position.z)/4.0).floor())
		r_ok = r_ok and cell == Vector2i(19,38)
		if cell == r_last_cell: return
		r_last_cell = cell
		# Independent entry-room tiles/heights; native Survey remains untouched.
		for x in range(cell.x-2,cell.x+3):
			for z in range(cell.y-2,cell.y+3):
				if x < 17 or x > 22 or z < 35 or z > 39: continue
				var destination: Vector3 = Vector3((x+0.5)*4.0,1.55,(z+0.5)*4.0)
				var ray = PhysicsRayQueryParameters3D.create(player.camera.global_position,destination,1)
				if Vector2i(x,z) == cell or level.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): r_explored.append([x,z])

var r_epoch: int = 0
var r_wall_us: int = 0
var r_main_id: int = 0
var r_campaign_id: int = 0
var r_profile: String = ""
var r_capture_baseline: int = 0
var r_prior_attempts: Array = []
var r_third: Dictionary = {}
var r_inherited: Dictionary = {}
var r_tick_baseline: int = 0
var r_saved_expected: Dictionary = {}
var r_saved_sha: String = ""
var r_pressed: bool = false

func run() -> void:
	prefix = "user://reliquary_earned_entry_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	if not expect(FileAccess.get_sha256("res://tests/test_processional_earned_exit.gd") == R_PREFIX_SHA and FileAccess.get_sha256("res://data/04_reliquary.json") == R_MAP_SHA,"Pinned accepted helper and authored fourth map before unchanged continuous prefix"):
		await finish(1)
		return
	if not await walk_to_processional_exit(ReliquaryMain.new(),prefix) or not freeze_reliquary_boundary() or not await descend_reliquary():
		await finish(1)
		return
	print("PASS source-debug continuous earned three-map prefix to actual Reliquary ENTRY: same Main/Campaign/profile, original31 actors, exact phase envelopes and native floor/capsule. Default capture setter attempts only; virtual Input/scripted aim, not physical input, fourth combat/exit, cancellation, rendering/audio/performance, packed-app or full-eight acceptance.")
	await finish(0)

func observer_witness(fields: Array) -> Dictionary:
	var result: Dictionary = {}
	for field in fields:
		var value = game.get(field)
		result[field] = value.duplicate(true) if value is Array or value is Dictionary else value
	return result

func observers_retired() -> bool:
	return not game.foundry_enabled and not game.entry_enabled and not game.organ_enabled and not game.palanquin_enabled and not game.exit_enabled

func freeze_reliquary_boundary() -> bool:
	var zero_entry: Dictionary = R_CARRY.duplicate(true)
	zero_entry.merge({"keys":[],"removed":[],"checkpoint_id":"entry","position":[0.0,0.0,0.0]},true)
	r_saved_expected = zero_entry.duplicate(true)
	r_saved_expected.merge({"version":1,"difficulty":1,"level_index":3,"discoveries":[],"explored":[],"checkpoint":zero_entry.duplicate(true),"level_start":zero_entry.duplicate(true)},true)
	if not expect(game.state.to_dict() == r_saved_expected and game.x_exit_expected == r_saved_expected and game.x_deaths.size() == 26 and game.x_exit_saves == 1 and game.x_ok and game.r_captures == 0 and game.r_bindings.is_empty() and game.r_start.is_empty() and game.level == null and game.player == null and retired.all(func(reference): return reference.get_ref() == null) and x_marker_refs.values().all(func(reference): return reference.get_ref() == null),"Completed helper returns unchanged earned three-map state, provenance and drain witnesses before fourth observation"): return false
	r_main_id = game.get_instance_id()
	r_campaign_id = game.state.get_instance_id()
	r_profile = game.progress_path
	if not expect(r_main_id == game.r_main_origin and r_campaign_id == game.r_campaign_origin and r_profile == game.r_profile_origin and r_profile == prefix+"_campaign.json" and game.settings_path == game.r_settings_origin and game.settings_path == prefix+"_preferences.json" and not game.loaded_positions and game.exit_enabled and not game.foundry_enabled and not game.entry_enabled and not game.organ_enabled and not game.palanquin_enabled,"Same once-created Main/Campaign/isolated profile reaches fresh boundary with only completed Exit observer enabled"): return false
	r_third = observer_witness(R_THIRD_FIELDS)
	r_inherited = observer_witness(R_INHERITED_FIELDS)
	r_tick_baseline = game.ticks
	r_saved_sha = FileAccess.get_sha256(r_profile)
	r_capture_baseline = game.r_capture_attempts.size()
	r_prior_attempts = game.r_capture_attempts.duplicate(true)
	if not expect(r_saved_sha == game.x_save_sha and r_capture_baseline >= 3 and r_prior_attempts.all(func(record): return record[2] == r_main_id and record[0] == record[1] and record[0] in [0,1,2] and not record[6] and record[7]),"Real default capture attempts throughout prefix are retained before fourth baseline"): return false
	release_actions()
	game.exit_enabled = false
	return true

func descend_reliquary() -> bool:
	var offered: Array = game.menu.get_children().filter(func(node): return node is Button and not node.is_queued_for_deletion() and node.text == "Descend to The Reliquary")
	if not expect(offered.size() == 1 and offered[0].get_signal_connection_list("pressed").any(func(connection): return connection.callable == Callable(game,"start_level")),"Fourth descent is the original connected production start_level menu action"): return false
	r_epoch = Engine.get_physics_frames()
	r_wall_us = Time.get_ticks_usec()
	r_pressed = press_menu("Descend to The Reliquary")
	for frame in range(R_LIMIT-2):
		if game.playing and not game.placement_pending and is_instance_valid(game.player): break
		if Time.get_ticks_usec()-r_wall_us > R_SECONDS*1000000: break
		await physics_frame
	# Query registration/sampling waits, not a claim that fresh Main took its restored branch.
	await physics_frame
	await physics_frame
	await process_frame
	return reliquary_entry_result()

func reliquary_entry_result() -> bool:
	if not expect(r_pressed and Engine.get_physics_frames()-r_epoch <= R_LIMIT and Time.get_ticks_usec()-r_wall_us <= R_SECONDS*1000000 and game.playing and not paused and not game.placement_pending and game.state.level_index == 3 and game._scene_level_index == 3 and game.get_instance_id() == r_main_id and game.state.get_instance_id() == r_campaign_id and game.progress_path == r_profile and game.fourth_scene(),"NATIVE RED fourth ENTRY requires actual connected Descend, same Main/Campaign/profile and fresh native readiness within120 frames/10 wall seconds"): return false
	route_level = game.level
	route_player = game.player
	var data: Dictionary = route_level.layout.data
	if not expect(data.id == "reliquary" and data.spawn == [19.5,38.5] and data.spawn_yaw == 0 and data.cell_size == 4 and data.enemies.size() == 31 and game.enemies.size() == 31 and route_level.get_script() == game.Level and route_player.get_script() == game.Player and route_level.get_instance_id() == game.r_level_id and route_player.get_instance_id() == game.r_player_id and route_player._current_map() and route_player.is_physics_processing() and game.is_processing() and game.is_physics_processing() and not game.menu_scroll.visible,"Native original fourth Level/Player and authored entry, not stale third references"): return false
	for index in range(R_ACTORS.size()):
		var spec: Array = R_ACTORS[index]
		var authored: Dictionary = {"id":spec[0],"kind":spec[1],"cell":[spec[3],spec[4]],"yaw":spec[6]}
		var actor = game.enemies[index]
		var record: Dictionary = game.r_start.actors[index]
		if not expect(data.enemies[index] == authored and is_instance_valid(actor) and actor.id == spec[0] and game.r_bindings.get(actor.id,-1) == actor.get_instance_id() and not actor.get_instance_id() in game.x_bindings.values() and actor.get_script() == game.Enemy and actor.kind == spec[1] and actor.hp == spec[2] and actor.max_hp == spec[2] and actor._current_map() and actor.is_physics_processing() and not actor.active and not actor.alerted and actor.collision_layer == 4 and actor.collision_mask == 7 and actor.age > 0.0 and actor.age <= float(Engine.get_physics_frames()-r_epoch+1)/60.0+0.000001 and actor.position == Vector3(record.position[0],record.position[1],record.position[2]) and actor.rotation.y == Vector3(0,deg_to_rad(spec[6]),0).y,"Independent authored original31 identity/role/full HP and live automatic age: "+spec[0]): return false
		if not expect(not (actor.get_child(0) as CollisionShape3D).disabled,"Original fourth native actor collider remains enabled: "+spec[0]): return false
	if not expect(game.scene_roster_matches(),"Actual native fourth scene contains exactly31 bound originals; no unregistered Enemy children"): return false
	var collider: CollisionShape3D = route_player.get_child(0)
	if not expect(not collider.disabled and route_player.collision_layer == 2 and route_player.collision_mask == 5 and collider.shape is CapsuleShape3D and collider.shape.radius == Vector3(0.32,0,0).x and collider.shape.height == Vector3(1.65,0,0).x and collider.position == Vector3(0,0.85,0) and route_player.position.is_finite() and route_player.position.x == 78.0 and route_player.position.z == 154.0 and absf(route_player.position.y) <= 0.05 and route_player.rotation.y == 0.0 and route_player.camera.rotation.x == 0.0,"Independent native player capsule and bounded automatic entry settling; no pose writes"): return false
	var space = route_level.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(78,2,154),Vector3(78,-0.5,154),1))
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.transform = collider.global_transform
	query.collision_mask = 1|4
	query.exclude = [route_player.get_rid()]
	if not expect(not hit.is_empty() and absf(hit.position.y) <= 0.08 and hit.normal.y >= 0.7 and space.intersect_shape(query,1).is_empty(),"Actual native independent zero-height floor and original live capsule clearance"): return false
	var expected: Dictionary = game.r_start.duplicate(true)
	# Current position is read from the independently bounded, native-clear Player, not Campaign.
	expected.position = [route_player.position.x,route_player.position.y,route_player.position.z]
	expected.merge({"version":1,"difficulty":1,"level_index":3,"discoveries":[],"explored":game.r_explored.duplicate(true),"checkpoint":game.r_start.duplicate(true),"level_start":game.r_start.duplicate(true)},true)
	var saved = game.state.get_script().new()
	if not expect(game.r_ok and game.r_captures == 1 and game.r_bindings.size() == 31 and game.r_start.actors == game.expected_originals() and game.r_ticks >= 1 and not game.r_explored.is_empty() and game.state.to_dict() == expected and game.budget() == R_CARRY and saved.load_progress(r_profile) and saved.to_dict() == r_saved_expected and FileAccess.get_sha256(r_profile) == r_saved_sha,"Exact independent fourth current/fresh checkpoint/level_start versus unchanged zero-position on-disk next-entry envelope and legitimate Survey"): return false
	if not expect(observer_witness(R_INHERITED_FIELDS) == r_inherited and game.ticks-r_tick_baseline == game.r_ticks and game.shot_slot == -1.0,"Inherited callback counters/flags remain unchanged; only the actual fourth physics clock advances"): return false
	if not expect(observers_retired() and observer_witness(R_THIRD_FIELDS) == r_third and retired.all(func(reference): return reference.get_ref() == null) and x_marker_refs.values().all(func(reference): return reference.get_ref() == null) and game.r_capture_attempts.size() == r_capture_baseline+1 and game.r_capture_attempts.slice(0,r_capture_baseline) == r_prior_attempts,"Completed third observations and prior capture history remain unchanged; original retired nodes stay drained"): return false
	var attempt: Array = game.r_capture_attempts[-1]
	if not expect(attempt[0] == 3 and attempt[1] == 3 and attempt[2] == r_main_id and attempt[3] == route_level.get_instance_id() and attempt[4] == route_player.get_instance_id() and attempt[5] >= r_epoch and attempt[5]-r_epoch <= R_LIMIT and not attempt[6] and attempt[7],"Exactly one fourth default mouse-capture setter attempt follows real fresh readiness; headless getter is not physical capture proof"): return false
	print("RELIQUARY_EARNED_ENTRY frames=",Engine.get_physics_frames()-r_epoch," wall_us=",Time.get_ticks_usec()-r_wall_us," originals=",game.r_bindings.size()," prefix_capture_attempts=",r_capture_baseline," fresh_captures=",game.r_captures," saved_sha=",r_saved_sha)
	return true
