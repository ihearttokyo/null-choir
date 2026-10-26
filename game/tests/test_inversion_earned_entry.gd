extends "res://tests/test_ossuary_finale_exit.gd"

const INVERSION_PINS = {
	"res://tests/test_ossuary_finale_exit.gd":"2771ce5b8dda381a49f736fc6354c608b504943d14de07363300ead2b0f5e5a3",
	"res://tests/ossuary_finale_exit_witness.gd":"f7bb71ad33519fcaf53f765bf6303b40c750ae50239297f22318a23e00f3cb3b",
	"res://data/07_inversion.json":"915049c8798c85f4e5878ae3321346d8fb5ef55f75ac9c43f63f674d9e128904",
	"res://audio/music.gd":"8c61ac03dd45868b2d747eaba00c98cc86806d088edb6f585117d5466ede0080",
	"res://audio/effects.gd":"3940a44f4917a5325f3f7288179cbc2bbf0990bf7bee2a75846e186295dfc759"}
const INVERSION_ALIASES = ["scene","player","cx_world_alias","cx_player_alias","cx_gate_alias","cx_button"]
const INVERSION_LIMIT = 30
const INVERSION_SECONDS = 10
const INVERSION_GUARD = "NATIVE RED Inversion ENTRY requires actual connected Descend and synchronous fresh seventh scene within30 frames/10 seconds"
const INVERSION_NONPUBLISHING = ["--inversion-entry-pin-rejection","--omit-inversion-entry-menu"]
const INVERSION_GROUPS = ["inversion_first_commit","inversion_second_commit","inversion_first_return","inversion_second_return","inversion_finale"]
const INVERSION_ROLES = {"crawler":[50,0.42,1.1],"worker":[90,0.34,2.7],"caster":[90,0.34,2.7],"brute":[210,0.62,3.3],"guardian":[260,0.65,3.7],"summoner":[150,0.45,4.2]}
# Independent revision-one triangle floors: role, cell x/z, floor, degrees, encounter index; IDs follow row order.
# Entry-room x16..20 column floors; each is constant over z34..38.
const INVERSION_ENTRY_FLOORS = [0.9375,0.3125,0.0,0.0,0.0]
const INVERSION_ACTORS = [
	["brute",4.5,21.5,5.5,198,0],
	["crawler",9.5,22.5,4.0,117,0],
	["worker",10.5,19.5,3.0,124,0],
	["crawler",4.5,18.5,5.5,194,0],
	["worker",3.5,14.5,5.5,217,0],
	["caster",9.5,14.5,4.0,149,0],
	["crawler",6.5,12.5,5.5,180,0],
	["worker",10.5,16.5,3.0,124,0],
	["worker",2.5,20.5,5.5,236,0],
	["guardian",27.5,19.5,-3.5,180,1],
	["crawler",33.5,19.5,-5.0,104,1],
	["worker",34.5,16.5,-5.0,127,1],
	["crawler",26.5,14.5,-2.5,194,1],
	["worker",34.5,12.5,-5.0,149,1],
	["caster",29.5,10.5,-5.0,187,1],
	["crawler",27.5,11.5,-3.125,180,1],
	["worker",32.5,8.5,-5.0,180,1],
	["worker",35.5,14.5,-5.0,117,1],
	["summoner",14.5,13.5,2.1875,0,2],
	["crawler",13.5,18.5,2.5,346,2],
	["worker",15.5,22.5,1.5625,14,2],
	["worker",19.5,10.5,0.0,0,3],
	["crawler",18.5,15.5,0.0,346,3],
	["crawler",20.5,20.5,0.0,14,3],
	["worker",38.5,23.5,-5.0,166,4],
	["crawler",40.5,26.5,-5.0,108,4],
	["caster",38.5,31.5,-5.0,342,4],
	["crawler",39.5,34.5,-5.0,0,4],
	["worker",40.5,30.5,-5.0,45,4],
	["crawler",37.5,33.5,-5.0,333,4]]

static func inversion_history_same(owner, fields: Array, image: Dictionary, aliases: Dictionary) -> bool:
	if not is_instance_valid(owner) or fields != Exit.script_fields(owner) or image.size() != fields.size() or aliases.size() != INVERSION_ALIASES.size(): return false
	for name in INVERSION_ALIASES:
		if not aliases.has(name) or typeof(aliases[name]) != TYPE_OBJECT or not is_same(owner.get(name),aliases[name]): return false
	return Exit.fields_match(owner,fields,image)

func inversion_pins_match() -> bool:
	return exit_pins_match() and INVERSION_PINS.keys().all(func(path): return FileAccess.get_sha256(path) == INVERSION_PINS[path])

static func inversion_button_same(owner, button) -> bool:
	if not is_instance_valid(owner) or not is_instance_valid(button) or not button is Button or button.is_queued_for_deletion(): return false
	var offered: Array = owner.menu.get_children().filter(func(node): return node is Button and node.text == "Descend to The Inversion")
	if offered.size() != 1 or not is_same(offered[0],button) or button.get_parent() != owner.menu or not button.visible or not button.is_visible_in_tree() or button.disabled or not owner.menu_scroll.visible: return false
	var connections: Array = button.get_signal_connection_list("pressed")
	return connections.size() == 1 and connections[0].callable == Callable(owner,"start_level")

func run() -> void:
	if "--inversion-entry-pin-rejection" in OS.get_cmdline_user_args():
		await inversion_pin_rejection()
		return
	var result: bool = await walk_through_inversion_entry()
	if result: print("PASS bounded earned Inversion fresh ENTRY only; connected signal, not physical click/mouse capture/hearing/app/full campaign")
	await finish(0 if result else 1)

func walk_through_inversion_entry(profile_prefix: String = "") -> bool:
	return not (await _completed_inversion_entry(profile_prefix)).is_empty()

func accepted_inversion_entry(profile_prefix: String = "") -> Dictionary:
	if INVERSION_NONPUBLISHING.any(func(flag): return flag in OS.get_cmdline_user_args()): return {}
	return await _completed_inversion_entry(profile_prefix)

func inversion_pin_rejection() -> void:
	if not expect(not inversion_pins_match() and exit_pins_match(),"one entry-only pin mismatch with valid inherited Exit pins"):
		quit(1)
		return
	var isolated_prefix: String = "user://CONTROLLED_inversion_pin_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	var suffixes: Array = ["_campaign.json","_campaign.json.tmp","_preferences.json","_preferences.json.tmp"]
	if not expect(game == null and root.get_child_count() == 0 and suffixes.all(func(suffix): return not FileAccess.file_exists(isolated_prefix+suffix)),"fresh entry-pin namespace before allocation"):
		quit(1)
		return
	var result: bool = await walk_through_inversion_entry(isolated_prefix)
	var passed: bool = expect(not result and game == null and root.get_child_count() == 0 and suffixes.all(func(suffix): return not FileAccess.file_exists(isolated_prefix+suffix)),"entry pin mismatch refuses before inherited prefix/scene/profile allocation")
	if passed: print("PASS CONTROLLED Inversion entry-only pin refusal; no earned adoption")
	quit(0 if passed else 1)

func inversion_current(accepted, scene, player) -> bool:
	return accepted.cx_identity() and is_same(accepted.fixture,self) and is_same(accepted.game,game) and game.transport_witness == null and game.playing and not paused and not game.placement_pending and not game.loaded_positions and game.state.level_index == 6 and game._scene_level_index == 6 and is_instance_valid(scene) and is_same(game.level,scene) and scene.get_script() == game.Level and scene.get_instance_id() != accepted.level_id and scene.game == game and scene.get_parent() == game and scene.is_inside_tree() and not scene.is_queued_for_deletion() and is_instance_valid(player) and is_same(game.player,player) and player.get_script() == game.Player and player.get_instance_id() != accepted.player_id and player.game == game and player.get_parent() == scene and not player.is_queued_for_deletion() and player._current_map() and game.is_processing() and game.is_physics_processing() and scene.can_process() and player.is_physics_processing() and not game.menu_scroll.visible and game.pending_action.is_empty() and game.pending_button == null and game._interaction_pending_player == 0

func inversion_originals() -> Array:
	var records: Array = []
	for index in range(INVERSION_ACTORS.size()):
		var spec: Array = INVERSION_ACTORS[index]
		var point: Vector3 = Vector3(spec[1]*4.0,spec[3],spec[2]*4.0)+Vector3(0,0.03,0)
		if spec[0] == "caster": point.y += 1.0
		var native_yaw: float = Vector3(0,deg_to_rad(spec[4]),0).y
		records.append({"id":"inversion_enemy_%02d" % index,"hp":INVERSION_ROLES[spec[0]][0],"position":[point.x,point.y,point.z],"yaw":Finale.canonical(native_yaw),"alerted":false})
	return records

func inversion_actors_same(scene, records: Array, bindings: Dictionary, elapsed: int) -> bool:
	if not expect(game.enemies.size() == 30 and bindings.size() == 30,"exact30 bound original Inversion actors"): return false
	for index in range(INVERSION_ACTORS.size()):
		var spec: Array = INVERSION_ACTORS[index]
		var record: Dictionary = records[index]
		var actor = game.enemies[index]
		if not expect(is_instance_valid(actor) and actor.get_script() == game.Enemy and actor.get_child_count() >= 1 and actor.get_child(0) is CollisionShape3D and actor.get_child(0).shape is CapsuleShape3D,"native original actor and capsule exist"): return false
		var capsule: CollisionShape3D = actor.get_child(0)
		var role: Array = INVERSION_ROLES[spec[0]]
		if not expect(bindings.get(record.id,[]) == [actor.get_instance_id(),capsule.get_instance_id(),capsule.shape.get_instance_id()] and actor.id == record.id and actor.kind == spec[0] and actor.game == game and actor.hp == record.hp and actor.max_hp == record.hp and actor.encounter_id == INVERSION_GROUPS[spec[5]] and not actor.active and not actor.alerted and actor._summon_owner_id.is_empty() and actor._summoned_total == 0 and actor._current_map() and actor.get_parent() == scene and actor.is_physics_processing() and not actor.is_queued_for_deletion() and actor.collision_layer == 4 and actor.collision_mask == 7 and actor.position == Vector3(record.position[0],record.position[1],record.position[2]) and actor.rotation.y == Vector3(0,deg_to_rad(spec[4]),0).y and actor.age >= float(maxi(0,elapsed-1))/60.0-0.000001 and actor.age <= float(elapsed+1)/60.0+0.000001 and (actor.age == 0.0 if elapsed == 0 else actor.age > 0.0) and not capsule.disabled and capsule.shape is CapsuleShape3D and absf(capsule.shape.radius-role[1]) < 0.000001 and absf(capsule.shape.height-role[2]) < 0.000001 and capsule.position == Vector3(0,capsule.shape.height/2.0,0),"independent original actor role/HP/pose/facing/group/capsule/native age: "+record.id): return false
	var actual: Array = scene.get_children().filter(func(node): return node is CharacterBody3D).map(func(node): return node.get_instance_id())
	var expected: Array = bindings.values().map(func(binding): return binding[0])+[game.player.get_instance_id()]
	actual.sort()
	expected.sort()
	return expect(actual == expected and scene.get_children().filter(func(node): return node.get_script() == preload("res://scripts/projectile.gd")).is_empty(),"exact Player/30-original native scene bodies and no summon/projectile")

func inversion_entry_explored(scene, player) -> Array:
	var explored: Array = []
	# Independent authored entry-room heights; sample before Survey's first registered physics pass.
	for x in range(16,21):
		for z in range(34,39):
			var ray = PhysicsRayQueryParameters3D.create(player.camera.global_position,Vector3((x+0.5)*4.0,INVERSION_ENTRY_FLOORS[x-16]+1.55,(z+0.5)*4.0),1)
			if Vector2i(x,z) == Vector2i(18,36) or scene.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): explored.append([x,z])
	return explored

func _completed_inversion_entry(profile_prefix: String = "") -> Dictionary:
	if "--inversion-entry-pin-rejection" in OS.get_cmdline_user_args() and not inversion_pins_match() and exit_pins_match(): return {}
	if not expect(inversion_pins_match(),"exact entry/C/ancestor/core/Inversion/audio pins BEFORE prefix allocation"): return {}
	var accepted = await accepted_ossuary_exit(profile_prefix)
	if accepted == null: return {}
	var epoch: int = Engine.get_physics_frames()
	var wall: int = Time.get_ticks_usec()
	if not expect(accepted.get_script() == Exit and accepted.ok and accepted.cx_phase == "intermission" and accepted.cx_retirement_verified and accepted.prior_frozen() and accepted.cx_identity() and accepted.cx_menu(true) and is_same(accepted.fixture,self) and is_same(accepted.game,game) and game.transport_witness == null and game.state.position == Vector3.ZERO and game.state.actors == null and game.state.yaw == null and game.state.pitch == null and inversion_input_released(),"actual returned earned C, drained originals, released E/actions and zero-position handoff"): return {}
	var fields: Array = Exit.script_fields(accepted)
	var image: Dictionary = Exit.fields_image(accepted,fields)
	var aliases: Dictionary = {}
	for name in INVERSION_ALIASES: aliases[name] = accepted.get(name)
	var records: Array = inversion_originals()
	var entry: Dictionary = accepted.ledger.duplicate(true)
	entry.merge({"keys":[],"removed":[],"floor_revision":1,"checkpoint_id":"entry","position":[74.0,0.0,146.0],"actors":records.duplicate(true),"yaw":0.0,"pitch":0.0},true)
	var expected: Dictionary = entry.duplicate(true)
	expected.merge({"version":2,"difficulty":1,"level_index":6,"discoveries":[3,4,5],"explored":[],"checkpoint":entry.duplicate(true),"level_start":entry.duplicate(true)},true)
	if not expect(inversion_history_same(accepted,fields,image,aliases) and inversion_button_same(game,accepted.cx_button),"complete C image/raw aliases and unique exact connected original Descend BEFORE emission"): return {}
	var emitted: int = Engine.get_physics_frames()
	if not "--omit-inversion-entry-menu" in OS.get_cmdline_user_args(): accepted.cx_button.pressed.emit()
	else:
		if not expect(accepted.cx_menu(true) and accepted.prior_frozen() and inversion_history_same(accepted,fields,image,aliases),"omission preserves actual C menu/history/disk without button emission"): return {}
		print("INVERSION_ENTRY_OMITTED_READY C_intermission=true prior_frozen=true saved_handoff=true")
	var scene = game.level
	var player = game.player
	if not expect(inversion_current(accepted,scene,player) and Engine.get_physics_frames() == emitted and Time.get_ticks_usec()-wall <= INVERSION_SECONDS*1000000,INVERSION_GUARD): return {}
	if not expect(game.state.to_dict() == expected and game.budget() == accepted.ledger and player.position == Vector3(74,0.04,146) and player.rotation.y == 0.0 and player.camera.get_parent() == player and player.camera.current and player.camera.rotation.x == 0.0,"synchronous production fresh checkpoint/level_start independently predicted before any registration wait"): return {}
	var data: Dictionary = scene.layout.data
	var map_image: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/07_inversion.json"))
	if not expect(data == map_image and data.id == "inversion" and data.cell_size == 4 and data.spawn == [18.5,36.5] and data.spawn_yaw == 0 and data.enemies.size() == 30 and data.encounters.map(func(group): return group.id) == INVERSION_GROUPS,"exact original seventh source map/spawn/roster/encounter order"): return {}
	for group_index in range(INVERSION_GROUPS.size()):
		var ids: Array = []
		for index in range(INVERSION_ACTORS.size()):
			if INVERSION_ACTORS[index][5] == group_index: ids.append(records[index].id)
		if not expect(data.encounters[group_index].enemy_ids == ids,"exact authored encounter membership: "+INVERSION_GROUPS[group_index]): return {}
	var bindings: Dictionary = {}
	for index in range(INVERSION_ACTORS.size()):
		var spec: Array = INVERSION_ACTORS[index]
		if not expect(data.enemies[index] == {"id":records[index].id,"kind":spec[0],"cell":[spec[1],spec[2]],"yaw":float(spec[4])} and game.enemies.size() == 30 and is_instance_valid(game.enemies[index]) and game.enemies[index].get_child_count() >= 1 and game.enemies[index].get_child(0) is CollisionShape3D,"independent authored actor row and original native body"): return {}
		var actor = game.enemies[index]
		var capsule: CollisionShape3D = actor.get_child(0)
		if not expect(capsule.shape is CapsuleShape3D and accepted.bindings.values().all(func(binding): return actor.get_instance_id() != binding[0]),"fresh actor/capsule rather than retired Ossuary original"): return {}
		bindings[records[index].id] = [actor.get_instance_id(),capsule.get_instance_id(),capsule.shape.get_instance_id()]
	if not inversion_actors_same(scene,records,bindings,0): return {}
	if not expect(player.get_child_count() >= 1 and player.get_child(0) is CollisionShape3D and player.get_child(0).shape is CapsuleShape3D,"fresh native Player capsule exists"): return {}
	var player_capsule: CollisionShape3D = player.get_child(0)
	var player_binding: Array = [player_capsule.get_instance_id(),player_capsule.shape.get_instance_id()]
	var registration_frames: Array = []
	var explored: Array = []
	# Fresh start is synchronous; these waits register physics, not restored placement.
	for frame in range(2):
		await physics_frame
		registration_frames.append(Engine.get_physics_frames())
		if not expect(inversion_current(accepted,scene,player) and Engine.get_physics_frames()-epoch <= INVERSION_LIMIT and Time.get_ticks_usec()-wall <= INVERSION_SECONDS*1000000,INVERSION_GUARD): return {}
		if frame == 0: explored = inversion_entry_explored(scene,player)
	await process_frame
	var elapsed: int = Engine.get_physics_frames()-epoch
	if not expect(inversion_current(accepted,scene,player) and elapsed <= INVERSION_LIMIT and Time.get_ticks_usec()-wall <= INVERSION_SECONDS*1000000 and registration_frames[0] > emitted and registration_frames[1] == registration_frames[0]+1,INVERSION_GUARD): return {}
	if not inversion_actors_same(scene,records,bindings,elapsed): return {}
	if not expect(is_instance_valid(player_capsule) and player_capsule.shape is CapsuleShape3D and player.get_child_count() >= 1 and player_capsule == player.get_child(0) and player_binding == [player_capsule.get_instance_id(),player_capsule.shape.get_instance_id()] and not player_capsule.disabled and player_capsule.shape.radius == Vector3(0.32,0,0).x and player_capsule.shape.height == Vector3(1.65,0,0).x and player_capsule.position == Vector3(0,0.85,0) and player.collision_layer == 2 and player.collision_mask == 5 and player.position.is_finite() and player.position.x == 74.0 and player.position.z == 146.0 and absf(player.position.y) <= 0.05 and player.rotation.y == 0.0 and player.camera.rotation.x == 0.0,"same original Player capsule/facing and bounded automatic entry settling"): return {}
	var space = scene.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(74,2,146),Vector3(74,-0.5,146),1))
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = player_capsule.shape
	query.transform = player_capsule.global_transform
	query.collision_mask = 1|4
	query.exclude = [player.get_rid()]
	if not expect(not hit.is_empty() and hit.normal.y >= 0.7 and absf(hit.position.y) <= 0.05 and absf(player.position.y-hit.position.y) <= 0.15 and space.intersect_shape(query,1).is_empty(),"actual independent native floor/support and capsule clearance"): return {}
	expected.position = [player.position.x,player.position.y,player.position.z]
	expected.explored = explored.duplicate(true)
	var reloaded = game.Campaign.new()
	if not expect(scene.layout.data == map_image and not explored.is_empty() and game.hud.survey._level == scene and game.hud.survey._last_cell == Vector2i(18,36) and game.state.to_dict() == expected and game.state.position == player.position and game.state.level_load_error.is_empty() and game.budget() == accepted.ledger and game.state.keys.is_empty() and game.state.removed.is_empty() and FileAccess.get_file_as_bytes(accepted.profile) == accepted.cx_expected_bytes and FileAccess.get_sha256(accepted.profile) == accepted.cx_expected_sha and reloaded.load_progress(accepted.profile) and reloaded.to_dict() == accepted.cx_expected,"independent Survey/current/checkpoint/start image versus unchanged separately reloaded C disk handoff"): return {}
	if not expect(accepted.prior_frozen() and inversion_history_same(accepted,fields,image,aliases) and accepted.cx_world_ref.get_ref() == null and accepted.cx_player_ref.get_ref() == null and accepted.cx_actor_refs.values().all(func(ref): return ref.get_ref() == null) and accepted.markers.values().all(func(ref): return ref.get_ref() == null) and observers_retired() and nf_retired.all(func(ref): return ref.get_ref() == null) and nf_marker_refs.values().all(func(ref): return ref.get_ref() == null) and e_retired.all(func(ref): return ref.get_ref() == null) and e_markers.values().all(func(ref): return ref.get_ref() == null) and retired.all(func(ref): return ref.get_ref() == null) and x_marker_refs.values().all(func(ref): return ref.get_ref() == null) and inversion_input_released(),"complete C/all prior frozen history, exact raw aliases, retired observers/weak targets and released input"): return {}
	if not expect(game.music.get_script() == game.Music and game.effects.get_script() == game.Effects and game.music.player.stream != null and game.music.player.stream.resource_path == "res://audio/suno/inversion.mp3" and game.music.player.playing and not game.music.player.stream_paused and not game.effects.paused and game.effects.players.values().all(func(node): return not node.playing),"same retained music/effects owners with seventh recording selected; not hearing acceptance"): return {}
	if not expect(Engine.get_physics_frames()-epoch <= INVERSION_LIMIT and Time.get_ticks_usec()-wall <= INVERSION_SECONDS*1000000,INVERSION_GUARD): return {}
	print("INVERSION_EARNED_ENTRY frames=",elapsed," wall_us=",Time.get_ticks_usec()-wall," emission_frame=",emitted," registration_frames=",registration_frames," originals=",bindings.size()," explored=",explored," saved_sha=",accepted.cx_expected_sha," C_history_exact=true")
	return {"previous":accepted,"level":scene,"player":player,"fields":fields,"image":image,"aliases":aliases,"bindings":bindings}

func inversion_input_released() -> bool:
	return not Input.is_physical_key_pressed(KEY_E) and InputMap.get_actions().all(func(action): return not Input.is_action_pressed(action)) and game._interaction_pending_player == 0
