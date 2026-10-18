extends "res://tests/test_reliquary_earned_exit.gd"

const N_EXIT_SHA = "a53139b852cb1f0fdcf3ef46515fb4f178a22edfbd23ec99f5dbc8d2c221061a"
const N_MAP_SHA = "8e04f3d5f704ac4f5b3ee698b3442ff27670843c244baca8b2ffdcd426bfa257"
const N_LIMIT = 30
const N_SECONDS = 10
const N_ENTRY_GUARD = "NATIVE RED Nursery ENTRY requires actual unique connected Descend signal, same earned owner/profile and original fresh fifth scene within30 frames/10 seconds"
const N_CARRY = {"health":82,"armor":170,"ammo":[0,162,32,0,0,0],"owned_weapons":[0,1,2],"weapon":1}
const N_E_FIELDS = ["e_base","e_pickup_calls","e_ok","e_ticks","e_shots","e_last","e_slot","e_last_time","e_shot_start_age","e_shot_start_time","e_health_loss","e_absorbed","e_removed","e_activation","e_activated","e_attacks","e_roles","e_damage_attacks","e_hurts","e_deaths","e_finishes","e_births","e_contacts","e_projectile_used","e_pending","e_release","e_melee_pending","e_enemy_contacts","e_enemy_pending","e_enemy_used","e_route_b","e_health_gain","e_rivets","e_consumed","e_explored","e_last_cell","e_checkpoint","e_start","e_actor_image","e_captures","e_checkpoint_saves","e_exit_saves","e_checkpoint_doc","e_checkpoint_sha","e_save_sha","e_exit_expected","e_gate_calls","e_gate_intent","e_exit_intent","e_inputs","e_completed"]
# Independent authored rows: id, role, cell x/z, floor height, degrees, encounter index.
const N_GROUPS = ["nursery_first_commit","nursery_second_commit","nursery_first_return","nursery_second_return","nursery_finale"]
const N_ROLES = {"crawler":[50,0.42,1.1],"worker":[90,0.34,2.7],"caster":[90,0.34,2.7],"brute":[210,0.62,3.3],"guardian":[260,0.65,3.7],"summoner":[150,0.45,4.2],"nursery_warden":[1200,1.0,5.4]}
const N_ACTORS = [
	["nursery_enemy_00","crawler",2.5,12.5,2.0,-161.5651,0],
	["nursery_enemy_01","crawler",8.5,13.5,2.0,141.3402,0],
	["nursery_enemy_02","crawler",2.5,8.5,2.0,-168.6901,0],
	["nursery_enemy_03","crawler",8.5,8.5,2.0,158.1986,0],
	["nursery_enemy_04","brute",9.5,11.5,2.0,144.4623,0],
	["nursery_enemy_05","worker",3.5,7.5,2.0,-174.8056,0],
	["nursery_enemy_06","worker",1.5,11.5,2.0,-156.8014,0],
	["nursery_enemy_07","caster",6.5,7.5,2.0,169.6952,0],
	["nursery_enemy_08","crawler",16.5,27.5,-1.5,-14.0362,1],
	["nursery_enemy_09","crawler",22.5,28.5,-1.5,45.0,1],
	["nursery_enemy_10","crawler",16.5,32.5,-1.5,-6.3402,1],
	["nursery_enemy_11","crawler",21.5,33.5,-1.5,21.8014,1],
	["nursery_enemy_12","guardian",22.5,26.5,-1.5,59.0362,1],
	["nursery_enemy_13","worker",17.5,25.5,-1.5,0.0,1],
	["nursery_enemy_14","worker",20.5,33.5,-1.5,16.6992,1],
	["nursery_enemy_15","caster",20.5,26.5,-1.5,45.0,1],
	["nursery_enemy_16","crawler",14.5,13.5,0.0,0.0,2],
	["nursery_enemy_17","summoner",13.5,15.5,0.0,-11.3099,2],
	["nursery_enemy_18","worker",15.5,17.5,0.0,8.1301,2],
	["nursery_enemy_19","crawler",12.5,27.5,0.0,-180.0,3],
	["nursery_enemy_20","worker",11.5,25.5,0.0,-165.9638,3],
	["nursery_enemy_21","worker",13.5,24.5,0.0,168.6901,3],
	["nursery_enemy_22","crawler",26.5,8.5,0.0,172.4054,4],
	["nursery_enemy_23","crawler",34.5,9.5,0.0,125.8377,4],
	["nursery_enemy_24","worker",26.5,6.5,0.0,173.991,4],
	["nursery_enemy_25","worker",34.5,13.5,0.0,105.5241,4],
	["nursery_enemy_26","worker",31.5,5.5,0.0,150.2551,4],
	["nursery_enemy_27","caster",30.5,12.5,0.0,124.992,4],
	["nursery_warden","nursery_warden",30.5,9.5,0.0,180.0,4]]

class NurseryEntryMain:
	extends "res://tests/test_reliquary_earned_exit.gd".ReliquaryExitMain
	var n_enabled: bool = false
	var n_ok: bool = true
	var n_start_calls: int = 0
	var n_start_frames: Array = []
	var n_captures: int = 0
	var n_mouse_attempts: Array = []
	var n_bindings: Dictionary = {}
	var n_level_id: int = 0
	var n_player_id: int = 0
	var n_ticks: int = 0
	var n_explored: Array = []
	var n_last_cell: Vector2i = Vector2i(-1,-1)
	func n_handoff() -> Dictionary:
		var resources: Dictionary = N_CARRY.duplicate(true)
		resources.merge({"keys":[],"removed":[],"checkpoint_id":"entry","position":[0.0,0.0,0.0]},true)
		var document: Dictionary = resources.duplicate(true)
		document.merge({"version":1,"difficulty":1,"level_index":4,"discoveries":[3],"explored":[],"checkpoint":resources.duplicate(true),"level_start":resources.duplicate(true)},true)
		return document
	func n_originals() -> Array:
		var result: Array = []
		for spec in N_ACTORS:
			var point: Vector3 = Vector3(spec[2]*4.0,spec[4],spec[3]*4.0)+Vector3(0,0.03,0)
			if spec[1] == "caster": point.y += 1.0
			var native_yaw: float = Vector3(0,deg_to_rad(spec[5]),0).y
			result.append({"id":spec[0],"hp":N_ROLES[spec[1]][0],"position":[point.x,point.y,point.z],"yaw":e_yaw(native_yaw),"alerted":false})
		return result
	func n_start() -> Dictionary:
		var result: Dictionary = N_CARRY.duplicate(true)
		result.merge({"keys":[],"removed":[],"checkpoint_id":"entry","position":[18.0,0.0,134.0],"actors":n_originals(),"yaw":0.0,"pitch":0.0},true)
		return result
	func n_entry_document() -> Dictionary:
		var result: Dictionary = n_start()
		result.merge({"version":1,"difficulty":1,"level_index":4,"discoveries":[3],"explored":[],"checkpoint":n_start(),"level_start":n_start()},true)
		return result
	func n_current() -> bool:
		return n_enabled and playing and not get_tree().paused and not placement_pending and not loaded_positions and state.level_index == 4 and _scene_level_index == 4 and is_instance_valid(level) and not level.is_queued_for_deletion() and level.get_instance_id() == n_level_id and is_instance_valid(player) and not player.is_queued_for_deletion() and player.get_parent() == level and player.get_instance_id() == n_player_id
	func n_roster_matches() -> bool:
		var actual: Array = level.get_children().filter(func(node): return node is Enemy).map(func(node): return node.get_instance_id())
		var bound: Array = n_bindings.values().map(func(record): return record[0])
		actual.sort()
		bound.sort()
		return actual.size() == 29 and actual == bound
	func start_level() -> void:
		if not n_enabled:
			await super.start_level()
			return
		n_start_calls += 1
		var began: int = Engine.get_physics_frames()
		n_ok = n_ok and n_start_calls == 1 and state.to_dict() == n_handoff() and not playing and not placement_pending and not loaded_positions and level == null and player == null and get_tree().paused
		await super.start_level()
		n_start_frames.append([began,Engine.get_physics_frames()])
		n_ok = n_ok and n_current() and state.to_dict() == n_entry_document()
	func _capture_actor_state() -> bool:
		if not n_enabled: return super._capture_actor_state()
		n_captures += 1
		var expected: Dictionary = n_handoff()
		expected.merge({"position":[18.0,0.0,134.0],"yaw":0.0,"pitch":0.0},true)
		n_ok = n_ok and n_captures == 1 and not e_enabled and not playing and not placement_pending and not loaded_positions and state.to_dict() == expected and h_stack("/main.gd","start_level") and level.get_script() == Level and player.get_script() == Player and player.position == Vector3(18,0.04,134) and player.rotation.y == 0.0 and player.camera.rotation.x == 0.0 and enemies.size() == 29
		n_level_id = level.get_instance_id()
		n_player_id = player.get_instance_id()
		var records: Array = n_originals()
		for index in range(enemies.size()):
			var actor = enemies[index]
			if index >= N_ACTORS.size() or not is_instance_valid(actor):
				n_ok = false
				continue
			var spec: Array = N_ACTORS[index]
			var record: Dictionary = records[index]
			var capsule: CollisionShape3D = actor.get_child(0)
			n_ok = n_ok and actor.get_script() == Enemy and actor.id == spec[0] and actor.kind == spec[1] and actor.max_hp == record.hp and actor.hp == record.hp and actor.position == Vector3(record.position[0],record.position[1],record.position[2]) and actor.rotation.y == Vector3(0,deg_to_rad(spec[5]),0).y and actor.age == 0.0 and actor.encounter_id == N_GROUPS[spec[6]] and not actor.active and not actor.alerted and actor._current_map() and actor.get_parent() == level and not actor.is_queued_for_deletion() and actor.collision_layer == 4 and actor.collision_mask == 7 and not n_bindings.has(actor.id) and not actor.get_instance_id() in h_bindings.values()
			n_ok = n_ok and not capsule.disabled and capsule.shape is CapsuleShape3D and absf(capsule.shape.radius-N_ROLES[spec[1]][1]) < 0.000001 and absf(capsule.shape.height-N_ROLES[spec[1]][2]) < 0.000001 and capsule.position == Vector3(0,capsule.shape.height/2.0,0)
			n_bindings[actor.id] = [actor.get_instance_id(),capsule.get_instance_id(),capsule.shape.get_instance_id()]
		n_ok = n_ok and n_roster_matches()
		var result: bool = super._capture_actor_state()
		n_ok = n_ok and result and state.actors == records and state.yaw == 0.0 and state.pitch == 0.0
		return result
	func _capture_game_mouse() -> void:
		if n_enabled:
			n_mouse_attempts.append([state.level_index,_scene_level_index,get_instance_id(),level.get_instance_id(),player.get_instance_id(),Engine.get_physics_frames(),placement_pending,playing])
			n_ok = n_ok and n_current() and h_stack("/main.gd","start_level") and state.to_dict() == n_entry_document()
		# The existing retired prefix recorder stays retired; the production setter still runs.
		super._capture_game_mouse()
	func _physics_process(delta: float) -> void:
		super._physics_process(delta)
		if not n_enabled or not playing: return
		n_ticks += 1
		n_ok = n_ok and n_current() and absf(delta-1.0/60.0) < 0.000001
		var cell: Vector2i = Vector2i((Vector2(player.position.x,player.position.z)/4.0).floor())
		n_ok = n_ok and cell == Vector2i(4,33)
		if cell == n_last_cell: return
		n_last_cell = cell
		# Independent original entry room and zero-height floor; Survey writes its own observations.
		for x in range(2,7):
			for z in range(31,35):
				var end: Vector3 = Vector3((x+0.5)*4.0,1.55,(z+0.5)*4.0)
				var ray = PhysicsRayQueryParameters3D.create(player.camera.global_position,end,1)
				if Vector2i(x,z) == cell or level.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): n_explored.append([x,z])

var n_fields: Array = []
var n_frozen: Dictionary = {}
var n_saved_sha: String = ""
var n_epoch: int = 0
var n_wall: int = 0
var n_pressed: bool = false
var n_registration_frames: Array = []

func run() -> void:
	if "--nursery-entry-pin-rejection" in OS.get_cmdline_user_args():
		await nursery_pin_rejection()
		return
	if not await walk_into_nursery(NurseryEntryMain.new()):
		await finish(1)
		return
	print("PASS source-native virtual-input earned fifth ENTRY only; not full8, physical controls/mouse capture, render/audio/PCM/performance or packed-app acceptance")
	await finish(0)

func nursery_pin_rejection() -> void:
	if not expect(FileAccess.get_sha256("res://tests/test_reliquary_earned_exit.gd") != N_EXIT_SHA,"Pin refusal control requires parent-owned deliberate E mismatch"):
		await finish(1)
		return
	var fixture: String = "user://reliquary_catalogue_exit_nursery_pin_rejection_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	if not expect(["_campaign.json","_campaign.json.tmp","_preferences.json","_preferences.json.tmp"].all(func(suffix): return not FileAccess.file_exists(fixture+suffix)),"Pin control uses only a fresh unique fixture namespace"):
		await finish(1)
		return
	var observer = NurseryEntryMain.new()
	var reference = weakref(observer)
	var result: bool = await walk_into_nursery(observer,fixture)
	var untouched: bool = game == null and root.get_child_count() == 0 and not FileAccess.file_exists(fixture+"_campaign.json") and not FileAccess.file_exists(fixture+"_preferences.json")
	var rejected: bool = expect(not result and reference.get_ref() == null and untouched,"Wrong E pin frees only detached unadopted observer; unique fixture paths untouched")
	if is_instance_valid(observer): observer.free()
	prefix = fixture
	await finish(0 if rejected else 1)

func walk_into_nursery(observer: NurseryEntryMain, profile_prefix: String = "") -> bool:
	if not expect(FileAccess.get_sha256("res://tests/test_reliquary_earned_exit.gd") == N_EXIT_SHA and FileAccess.get_sha256("res://data/05_nursery.json") == N_MAP_SHA,"Exact accepted E and original fifth map before observer/profile adoption"):
		if is_instance_valid(observer) and observer != game and observer.get_parent() == null and not observer.is_inside_tree(): observer.free()
		return false
	var fixture: String = profile_prefix if not profile_prefix.is_empty() else "user://reliquary_catalogue_exit_nursery_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	if not expect(game == null and is_instance_valid(observer) and not observer.n_enabled and observer.n_start_calls == 0 and observer.n_captures == 0 and observer.n_bindings.is_empty() and observer.r_main_origin == 0 and observer.get_parent() == null and not observer.is_inside_tree() and fixture.begins_with("user://reliquary_catalogue_exit_nursery_") and not fixture.contains("..") and not fixture.trim_prefix("user://").contains("/") and not fixture.contains("\\") and not FileAccess.file_exists(fixture+"_campaign.json") and not FileAccess.file_exists(fixture+"_preferences.json") and not FileAccess.file_exists(fixture+"_campaign.json.tmp") and not FileAccess.file_exists(fixture+"_preferences.json.tmp"),"Fresh detached E subclass and unique transitive-compatible Nursery namespace"):
		if is_instance_valid(observer) and observer != game and observer.get_parent() == null and not observer.is_inside_tree(): observer.free()
		return false
	if not await walk_through_reliquary_exit(observer,fixture) or not freeze_nursery_boundary(): return false
	return await descend_nursery()

func freeze_nursery_boundary() -> bool:
	if not expect(game is NurseryEntryMain and game.e_enabled and game.e_route_b and game.e_completed and game.e_ok and game.budget() == N_CARRY and game.state.to_dict() == game.n_handoff() and game.e_exit_expected == game.n_handoff() and observer_witness(e_fields) == e_frozen,"Accepted complete default B E history and independent82/170/162/32 fresh menu envelope before retirement"): return false
	var saved = game.Campaign.new()
	n_saved_sha = FileAccess.get_sha256(r_profile)
	if not expect(game.get_instance_id() == r_main_id and game.state.get_instance_id() == r_campaign_id and game.progress_path == r_profile and r_profile == prefix+"_campaign.json" and game.settings_path == game.r_settings_origin and game.settings_path == prefix+"_preferences.json" and saved.load_progress(r_profile) and saved.to_dict() == game.n_handoff() and n_saved_sha == game.e_save_sha and game.state.actors == null and game.state.yaw == null and game.state.pitch == null and not game.playing and not game.placement_pending and not game.loaded_positions and paused and game.level == null and game.player == null and game.prefix_bookkeeping_retired and observers_retired() and e_retired.all(func(ref): return ref.get_ref() == null) and e_markers.values().all(func(ref): return ref.get_ref() == null),"Same actual owner/profile and E-pinned loaded fresh handoff; fourth scene/Player/actors/markers remain drained"): return false
	var actual: Array = []
	for property in game.get_property_list():
		if str(property.name).begins_with("e_") and property.name != "e_enabled": actual.append(property.name)
	actual.sort()
	var declared: Array = N_E_FIELDS.duplicate()
	declared.sort()
	if not expect(actual == declared,"Freeze EVERY declared/reflected e_ field except retired e_enabled, preserving all accepted prior history"): return false
	n_fields = e_fields+N_E_FIELDS+["prefix_bookkeeping_retired"]
	n_frozen = observer_witness(n_fields)
	release_actions()
	game.e_enabled = false
	n_epoch = Engine.get_physics_frames()
	n_wall = Time.get_ticks_usec()
	game.n_enabled = true
	return true

func descend_nursery() -> bool:
	var offered: Array = game.menu.get_children().filter(func(node): return node is Button and not node.is_queued_for_deletion() and node.text == "Descend to The Nursery")
	if not expect(offered.size() == 1 and offered[0].visible and offered[0].is_visible_in_tree() and not offered[0].disabled and game.menu_scroll.visible,"Actual unique visible enabled Nursery menu Button"): return false
	var connections: Array = offered[0].get_signal_connection_list("pressed")
	if not expect(connections.size() == 1 and connections[0].callable == Callable(game,"start_level"),"Exactly one actual Nursery pressed callback to this same Main.start_level"): return false
	if not "--omit-nursery-entry-menu" in OS.get_cmdline_user_args():
		offered[0].pressed.emit()
		n_pressed = true
	for frame in range(N_LIMIT-2):
		if game.playing and not game.placement_pending and is_instance_valid(game.player): break
		if Time.get_ticks_usec()-n_wall > N_SECONDS*1000000: break
		await physics_frame
	# Fresh Main skips restored placement; these are two real registration/sampling waits.
	for frame in range(2):
		await physics_frame
		n_registration_frames.append(Engine.get_physics_frames())
	await process_frame
	return nursery_entry_result()

func nursery_entry_result() -> bool:
	var elapsed: int = Engine.get_physics_frames()-n_epoch
	if not expect(n_pressed and game.n_start_calls == 1 and game.n_current() and elapsed <= N_LIMIT and Time.get_ticks_usec()-n_wall <= N_SECONDS*1000000 and game.get_instance_id() == r_main_id and game.state.get_instance_id() == r_campaign_id and game.progress_path == r_profile and game.settings_path == game.r_settings_origin,N_ENTRY_GUARD): return false
	route_level = game.level
	route_player = game.player
	var scene = route_level
	var player = route_player
	var data: Dictionary = scene.layout.data
	if not expect(data.id == "nursery" and data.spawn == [4.5,33.5] and data.spawn_yaw == 0 and data.cell_size == 4 and data.enemies.size() == 29 and game.enemies.size() == 29 and scene.get_script() == game.Level and player.get_script() == game.Player and scene.get_instance_id() != game.h_level and player.get_instance_id() != game.h_player and player._current_map() and player.is_physics_processing() and game.is_processing() and game.is_physics_processing() and not game.menu_scroll.visible and data.encounters.map(func(group): return group.id) == N_GROUPS,"Original fifth Level/Player/spawn and29-source roster; native processing stays live"): return false
	for group_index in range(N_GROUPS.size()):
		if not expect(data.encounters[group_index].enemy_ids == N_ACTORS.filter(func(spec): return spec[6] == group_index).map(func(spec): return spec[0]),"Original exact inactive encounter membership: "+N_GROUPS[group_index]): return false
	var records: Array = game.n_originals()
	for index in range(N_ACTORS.size()):
		var spec: Array = N_ACTORS[index]
		var actor = game.enemies[index]
		var record: Dictionary = records[index]
		var capsule: CollisionShape3D = actor.get_child(0)
		if not expect(data.enemies[index] == {"id":spec[0],"kind":spec[1],"cell":[spec[2],spec[3]],"yaw":spec[5]} and is_instance_valid(actor) and actor.get_script() == game.Enemy and game.n_bindings.get(actor.id,[]) == [actor.get_instance_id(),capsule.get_instance_id(),capsule.shape.get_instance_id()] and actor.id == spec[0] and actor.kind == spec[1] and actor.hp == record.hp and actor.max_hp == record.hp and actor.encounter_id == N_GROUPS[spec[6]] and not actor.active and not actor.alerted and actor._current_map() and actor.get_parent() == scene and actor.is_physics_processing() and not actor.is_queued_for_deletion() and actor.collision_layer == 4 and actor.collision_mask == 7 and actor.position == Vector3(record.position[0],record.position[1],record.position[2]) and actor.rotation.y == Vector3(0,deg_to_rad(spec[5]),0).y and actor.age > 0.0 and actor.age <= float(elapsed+1)/60.0+0.000001 and not capsule.disabled and capsule.shape is CapsuleShape3D and absf(capsule.shape.radius-N_ROLES[spec[1]][1]) < 0.000001 and absf(capsule.shape.height-N_ROLES[spec[1]][2]) < 0.000001 and capsule.position == Vector3(0,capsule.shape.height/2.0,0),"Independent original native actor role/HP/pose/capsule/group/age: "+spec[0]): return false
	var collider: CollisionShape3D = player.get_child(0)
	if not expect(game.n_roster_matches() and game.n_bindings.size() == 29 and not collider.disabled and player.collision_layer == 2 and player.collision_mask == 5 and collider.shape is CapsuleShape3D and collider.shape.radius == Vector3(0.32,0,0).x and collider.shape.height == Vector3(1.65,0,0).x and collider.position == Vector3(0,0.85,0) and player.position.is_finite() and player.position.x == 18.0 and player.position.z == 134.0 and absf(player.position.y) <= 0.05 and player.rotation.y == 0.0 and player.camera.rotation.x == 0.0,"Exact29 scene children and original native Player capsule with bounded automatic spawn settling"): return false
	var space = scene.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(18,2,134),Vector3(18,-0.5,134),1))
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.transform = collider.global_transform
	query.collision_mask = 1|4
	query.exclude = [player.get_rid()]
	if not expect(not hit.is_empty() and absf(hit.position.y) <= 0.08 and hit.normal.y >= 0.7 and space.intersect_shape(query,1).is_empty(),"Actual independent zero-height authored floor and safe native capsule support/clearance"): return false
	var expected: Dictionary = game.n_entry_document()
	expected.position = [player.position.x,player.position.y,player.position.z]
	expected.explored = game.n_explored.duplicate(true)
	var saved = game.Campaign.new()
	if not expect(game.n_ok and game.n_captures == 1 and game.n_ticks >= 1 and not game.n_explored.is_empty() and game.state.to_dict() == expected and game.budget() == N_CARRY and game.state.keys.is_empty() and game.state.removed.is_empty() and saved.load_progress(r_profile) and saved.to_dict() == game.n_handoff() and FileAccess.get_sha256(r_profile) == n_saved_sha,"Independent fresh checkpoint/level_start/actor/facing/current/Survey versus unchanged E-pinned zero-entry disk envelope"): return false
	if not expect(observer_witness(n_fields) == n_frozen and observer_witness(e_fields) == e_frozen and not game.e_enabled and observers_retired() and not game.h_enabled and not game.b_enabled and not game.q_enabled and not game.w_enabled and not game.v_enabled and not game.c_enabled and e_retired.all(func(ref): return ref.get_ref() == null) and e_markers.values().all(func(ref): return ref.get_ref() == null) and retired.all(func(ref): return ref.get_ref() == null) and x_marker_refs.values().all(func(ref): return ref.get_ref() == null),"Every frozen E and accepted prefix field/history retained; old scenes/capsules/markers remain drained"): return false
	if not expect(game.n_start_frames.size() == 1 and game.n_start_frames[0][0] == n_epoch and game.n_start_frames[0][1] == n_epoch and n_registration_frames.size() == 2 and n_registration_frames[0] > n_epoch and n_registration_frames[1] == n_registration_frames[0]+1 and game.n_mouse_attempts.size() == 1,"Observed synchronous production fresh branch, both actual registration waits and one fresh default capture attempt"): return false
	var attempt: Array = game.n_mouse_attempts[0]
	if not expect(attempt == [4,4,r_main_id,game.n_level_id,game.n_player_id,n_epoch,false,true],"Fresh capture belongs to actual fifth generation/Player after readiness; inherited retired recorder/history remain intact"): return false
	print("NURSERY_EARNED_ENTRY frames=",elapsed," wall_us=",Time.get_ticks_usec()-n_wall," originals=",game.n_bindings.size()," captures=",game.n_captures," production_start_frames=",game.n_start_frames," registration_frames=",n_registration_frames," explored=",game.n_explored," saved_sha=",n_saved_sha)
	return true
