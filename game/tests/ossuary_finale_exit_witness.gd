extends "res://tests/ossuary_second_loop_witness.gd"

const CxBattle = preload("res://tests/ossuary_finale_battle_witness.gd")
const CxPreparation = preload("res://tests/ossuary_finale_witness.gd")
const CxCampaign = preload("res://scripts/campaign.gd")
const CX_APPROACH = [[22.5,33.5],[27.5,33.5],[27.5,37.5],[22.5,37.5],[22.5,37.0]]
const CX_EXIT = {"id":"ossuary_descent","kind":"exit","cell":[22.5,37.5],"requires":["blood","ivory"]}
const CX_GUARD = "NATIVE RED C requires real rebound E original Ossuary exit and saved Inversion intermission"
var cx_phase: String = "unbound"
var cx_records: Array = []
var cx_records_frozen: Array = []
var cx_gate_alias: Variant
var cx_world_alias: Variant
var cx_player_alias: Variant
var cx_world_ref: WeakRef
var cx_player_ref: WeakRef
var cx_actor_refs: Dictionary = {}
var cx_actor_poses: Dictionary = {}
var cx_saved_bytes: PackedByteArray = PackedByteArray()
var cx_expected: Dictionary = {}
var cx_expected_bytes: PackedByteArray = PackedByteArray()
var cx_expected_sha: String = ""
var cx_capture_document: Dictionary = {}
var cx_before_capture_document: Dictionary = {}
var cx_pending_capture: int = 0
var cx_pending_save: bool = false
var cx_trace: Array = []
var cx_ready: bool = false
var cx_retirement_verified: bool = false
var cx_settings_values: Dictionary = {}
var cx_preferences_values: Dictionary = {}
var cx_preferences_id: int = 0
var cx_music_id: int = 0
var cx_effects_id: int = 0
var cx_button: Button

# Retired aliases are projected only in C; canonical older comparisons stay strict.
static func matches(owner, fields: Array, frozen: Dictionary, aliases: Dictionary, verified_exit: bool) -> bool:
	if not is_instance_valid(owner) or fields.size() != frozen.size(): return false
	var actual_fields: Array = script_fields(owner)
	var seen: Dictionary = {}
	for name in fields:
		if not name is String or not actual_fields.has(name) or not frozen.has(name) or seen.has(name): return false
		seen[name] = true
	var remaining: Array = fields.duplicate()
	var expected: Dictionary = frozen.duplicate()
	for name in aliases:
		if not name in ["scene","player","route_level","route_player"]: return false
		var binding: Variant = aliases[name]
		if not fields.has(name) or not binding is Array or binding.size() != 2 or typeof(binding[0]) != TYPE_OBJECT or not binding[1] is int or binding[1] <= 0: return false
		if frozen[name] != {"object_id":binding[1]} or not is_same(owner.get(name),binding[0]): return false
		if is_instance_valid(binding[0]):
			if binding[0].get_instance_id() != binding[1]: return false
		elif verified_exit:
			remaining.erase(name)
			expected.erase(name)
	return fields_match(owner,remaining,expected)

static func entry_document(values: Dictionary) -> Dictionary:
	var entry: Dictionary = {"health":values.health,"armor":values.armor,"ammo":values.ammo.duplicate(),"owned_weapons":values.owned_weapons.duplicate(),"weapon":values.weapon,"keys":[],"removed":[],"floor_revision":1,"checkpoint_id":"entry","position":[0.0,0.0,0.0]}
	var document: Dictionary = entry.duplicate(true)
	document.merge({"version":2,"difficulty":1,"level_index":6,"discoveries":[3,4,5],"explored":[],"checkpoint":entry.duplicate(true),"level_start":entry.duplicate(true)},true)
	return document

static func before_capture_document(captured: Dictionary, previous_actors: Array, cached_yaw: Variant, cached_pitch: Variant) -> Dictionary:
	var before: Dictionary = captured.duplicate(true)
	before.actors = previous_actors.duplicate(true)
	before.yaw = cached_yaw
	before.pitch = cached_pitch
	return before

func cx_nested_world(value: Variant) -> bool:
	if typeof(value) == TYPE_OBJECT: return is_same(value,cx_world_alias) or is_same(value,cx_player_alias)
	if value is Array:
		for item in value:
			if cx_nested_world(item): return true
	elif value is Dictionary:
		for name in value:
			if cx_nested_world(value[name]): return true
	return false

func cx_record(participant, names: Array, image: Dictionary) -> bool:
	if not require(is_instance_valid(participant) and names.size() == image.size(),"C binds an existing complete prior field image"): return false
	var aliases: Dictionary = {}
	for name in names:
		var value: Variant = participant.get(name)
		if typeof(value) == TYPE_OBJECT and (is_same(value,cx_world_alias) or is_same(value,cx_player_alias)):
			if not require(name in ["scene","player","route_level","route_player"],"unlisted direct world alias refuses C adoption"): return false
			var identity: int = level_id if is_same(value,cx_world_alias) else player_id
			if not require(image[name] == {"object_id":identity},"prior image independently binds original world ID"): return false
			aliases[name] = [value,identity]
		elif value is Array or value is Dictionary:
			if not require(not cx_nested_world(value),"unlisted nested world alias refuses C adoption"): return false
	cx_records.append({"owner":participant,"fields":names.duplicate(),"image":image.duplicate(true),"aliases":aliases})
	return true

func cx_metadata() -> Variant:
	var result: Array = []
	for record in cx_records:
		if not record is Dictionary or record.size() != 4 or not is_instance_valid(record.get("owner")) or not record.get("fields") is Array or not record.get("image") is Dictionary or not record.get("aliases") is Dictionary: return null
		var aliases: Array = []
		for name in record.aliases:
			var binding: Variant = record.aliases[name]
			if not binding is Array or binding.size() != 2 or not binding[1] is int: return null
			aliases.append([name,binding[1]])
		aliases.sort_custom(func(a,b): return str(a[0]) < str(b[0]))
		result.append({"owner":record.owner.get_instance_id(),"fields":record.fields,"image":record.image,"aliases":aliases})
	return result

func cx_history_image(rows: Array) -> Variant:
	var result: Array = []
	for row in rows:
		if not row is Dictionary or row.size() != 3 or not is_instance_valid(row.get("owner")) or not row.get("fields") is Array or not row.get("image") is Dictionary: return null
		result.append({"owner":stored_image(row.owner),"fields":row.fields,"image":row.image})
	return result

func prior_frozen() -> bool:
	if cx_records_frozen.is_empty() or cx_metadata() != cx_records_frozen: return false
	for record in cx_records:
		var names: Array = record.fields.duplicate()
		var image: Dictionary = record.image.duplicate()
		if names.has("histories"):
			if not record.owner.get("histories") is Array or cx_history_image(record.owner.get("histories")) != image.histories: return false
			names.erase("histories")
			image.erase("histories")
		for name in record.aliases:
			var binding: Array = record.aliases[name]
			var expected: Variant = cx_world_alias if binding[1] == level_id else cx_player_alias
			if not binding[1] in [level_id,player_id] or not is_same(binding[0],expected): return false
		if not matches(record.owner,names,image,record.aliases,cx_retirement_verified): return false
	if not is_instance_valid(previous) or not is_same(previous.preparation_gate_alias,cx_gate_alias) or not is_same(previous.previous.gate_alias,cx_gate_alias): return false
	return is_instance_valid(game) and game.prefix_bookkeeping_retired and script_fields(game).filter(func(name): return name.ends_with("_enabled")).all(func(name): return not game.get(name))

func adopt_after(tree, accepted) -> bool:
	fixture = tree
	game = tree.game
	if not require(is_instance_valid(accepted) and accepted.get_script() == CxBattle and accepted.ok and accepted.current() and accepted.prior_frozen() and game.transport_witness == null and accepted.waypoints == CxBattle.PATROL and accepted.captures == 0 and accepted.saves == 0 and accepted.deaths.size() == 27 and accepted.summons.is_empty() and accepted.hp.size() == 27 and accepted.hp.values().all(func(value): return value == 0) and accepted.bindings.size() == 27 and game.enemies.size() == 27 and game.enemies.all(func(node): return node.hp == 0 and accepted.deaths.get(node.id) == 1 and accepted.finishes.get(node.id) in ["player","infighting"]) and game.budget() == accepted.ledger,"actual returned completed Battle with all27 earned original deaths"): return false
	previous = accepted
	scene = game.level
	player = game.player
	main_id = game.get_instance_id()
	campaign_id = game.state.get_instance_id()
	level_id = scene.get_instance_id()
	player_id = player.get_instance_id()
	profile = game.progress_path
	settings = game.settings_path
	epoch = Engine.get_physics_frames()
	wall = Time.get_ticks_usec()
	cx_world_alias = scene
	cx_player_alias = player
	cx_world_ref = weakref(scene)
	cx_player_ref = weakref(player)
	if not require(current() and not Input.is_action_pressed("interact") and not Input.is_physical_key_pressed(KEY_E) and not Input.is_action_pressed("fire") and game._interaction_pending_player == 0 and player.position.distance_to(scene.layout.world_position(CxBattle.PATROL[-1])+Vector3.UP*0.04) < 0.2 and scene.layout.data.interactions.filter(func(spec): return spec.kind == "exit") == [CX_EXIT],"same settled Battle endpoint, released E and original exit"): return false
	for name in ["ledger","keys","removed","explored","checkpoint","start","actor_image","map_image","originals","bindings","hp","markers","marker_values","activated","deaths","finishes"]:
		var value: Variant = accepted.get(name)
		set(name,value.duplicate(true) if value is Array or value is Dictionary else value)
	last_cell = accepted.last_cell
	saved_sha = accepted.saved_sha
	cx_saved_bytes = accepted.saved_bytes.duplicate()
	settings_sha = accepted.settings_sha
	cx_settings_values = accepted.settings_values.duplicate(true)
	cx_preferences_values = accepted.preferences_values.duplicate(true)
	cx_preferences_id = game.preferences.get_instance_id()
	cx_music_id = game.music.get_instance_id()
	cx_effects_id = game.effects.get_instance_id()
	for node in game.enemies:
		var entry: Array = accepted.entry_actors[node.id]
		if not require(actor(node) and node.get_child(0).get_instance_id() == bindings[node.id][1] and node.get_child(0).shape.get_instance_id() == bindings[node.id][2] and node.kind == originals[node.id][4] and node.encounter_id == originals[node.id][5] and node._summon_owner_id.is_empty() and node._summoned_total == entry[6],"same proven dead original and capsule metadata"): return false
		if entry[3] == 0 and not require(node.position == entry[0] and node.rotation.y == entry[1] and node.active == entry[4] and node.alerted == entry[5],"old22 corpse poses remain independently proven"): return false
		cx_actor_refs[node.id] = weakref(node)
		cx_actor_poses[node.id] = [node.position,node.rotation.y,node.active,node.alerted,node._summoned_total,node.age]
	cx_gate_alias = accepted.preparation_gate_alias
	if not require(typeof(cx_gate_alias) == TYPE_OBJECT and not is_instance_valid(cx_gate_alias) and is_same(accepted.previous.gate_alias,cx_gate_alias),"both existing already-freed gate aliases remain exact"): return false
	if not cx_record(accepted,script_fields(accepted),fields_image(accepted,script_fields(accepted))) or not cx_record(accepted.previous,accepted.preparation_fields,accepted.previous_frozen): return false
	for record in accepted.previous.histories:
		if not cx_record(record.owner,record.fields,record.image): return false
	var metadata: Variant = cx_metadata()
	if not require(metadata is Array and cx_records.size() >= 7,"complete Battle/Preparation/all earlier immutable participants"): return false
	cx_records_frozen = metadata.duplicate(true)
	cx_phase = "walking"
	return require(current() and prior_frozen() and game.budget() == ledger and FileAccess.get_file_as_bytes(profile) == cx_saved_bytes,"C synchronous adoption freezes prior records before dispatch installation")

func cx_identity() -> bool:
	return is_instance_valid(game) and game.get_instance_id() == main_id and is_instance_valid(game.state) and game.state.get_instance_id() == campaign_id and is_instance_valid(game.preferences) and is_instance_valid(game.music) and is_instance_valid(game.effects) and is_same(scene,cx_world_alias) and is_same(player,cx_player_alias) and not game.quitting and game.progress_path == profile and game.settings_path == settings and game.preferences.get_instance_id() == cx_preferences_id and game.music.get_instance_id() == cx_music_id and game.effects.get_instance_id() == cx_effects_id and game.settings == cx_settings_values and fields_image(game.preferences,script_fields(game.preferences)) == cx_preferences_values and FileAccess.get_sha256(settings) == settings_sha

static func valid_angles(live_yaw: float, live_pitch: float, saved_yaw: Variant, saved_pitch: Variant) -> bool:
	# Queued interaction and route steering precede the Player's stored-pose update.
	if not (saved_yaw is float or saved_yaw is int) or not (saved_pitch is float or saved_pitch is int): return false
	return is_finite(live_yaw) and is_finite(live_pitch) and absf(live_pitch) <= Vector3(1.35,0,0).x and is_finite(saved_yaw) and saved_yaw >= -PI and saved_yaw < PI and is_finite(saved_pitch) and absf(saved_pitch) <= 1.35

func validate() -> bool:
	if not require(ok and cx_identity() and game.transport_witness == self and prior_frozen() and Time.get_ticks_usec()-wall <= SECONDS*1000000,"C current identities/dispatch/preferences/history and600s bound"): return false
	if cx_phase == "intermission": return require(cx_menu(false),"verified saved intermission remains exact")
	if not require(current() and Engine.get_physics_frames()-epoch <= LIMIT and abs(Engine.get_physics_frames()-epoch-ticks) <= 2 and scene.layout.data == map_image and game.budget() == ledger and game.state.keys == keys and keys == ["blood","ivory"] and game.state.removed == removed and game.state.explored == explored and game.state.discoveries == [3,4,5] and game.state.checkpoint == checkpoint and game.state.level_start == start and game.state.actors == actor_image and FileAccess.get_file_as_bytes(profile) == cx_saved_bytes and FileAccess.get_sha256(profile) == saved_sha,"unchanged living-world C resources/recovery before real exit"): return false
	var roster: Array = scene.get_children().filter(func(node): return node.get_script() == game.Enemy).map(func(node): return node.id)
	roster.sort()
	var expected: Array = cx_actor_refs.keys()
	expected.sort()
	var listed: Array = game.enemies.map(func(node): return node.id)
	listed.sort()
	if not require(roster == expected and listed == expected and game.enemies.size() == 27 and game.enemies.all(func(node): return actor(node) and cx_actor_refs[node.id].get_ref() == node and node.hp == 0 and node.collision_layer == 0 and node.collision_mask == 0 and [node.position,node.rotation.y,node.active,node.alerted,node._summoned_total] == cx_actor_poses[node.id].slice(0,5) and node.age-cx_actor_poses[node.id][5] >= float(Engine.get_physics_frames()-epoch-2)/60.0) and scene.get_children().filter(func(node): return node.get_script() == preload("res://scripts/projectile.gd")).is_empty(),"all proven27 corpses fixed/processing and no new actor/projectile"): return false
	for node in game.enemies:
		var capsule: CollisionShape3D = node.get_child(0)
		var role: Array = ROLES[node.kind]
		if not require(node.is_physics_processing() and [capsule.get_instance_id(),capsule.shape.get_instance_id()] == bindings[node.id].slice(1) and not capsule.disabled and capsule.shape is CapsuleShape3D and absf(capsule.shape.radius-role[1]) < 0.000001 and absf(capsule.shape.height-role[2]) < 0.000001 and capsule.position == Vector3(0,capsule.shape.height/2,0),"same native dead-actor capsule identities/geometry"): return false
	var player_capsule: CollisionShape3D = player.get_child(0)
	var floor_hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(player.position+Vector3.UP*0.5,player.position-Vector3.UP*0.5,1))
	if not require(game.is_processing() and game.is_physics_processing() and player.is_physics_processing() and [player_capsule.get_instance_id(),player_capsule.shape.get_instance_id()] == previous.player_capsule and not player_capsule.disabled and player_capsule.shape is CapsuleShape3D and player_capsule.shape.radius == Vector3(0.32,0,0).x and player_capsule.shape.height == Vector3(1.65,0,0).x and player_capsule.position == Vector3(0,0.85,0) and player.collision_layer == 2 and player.collision_mask == 5 and not floor_hit.is_empty() and floor_hit.normal.y >= 0.7 and absf(player.position.y-floor_hit.position.y) <= 0.15 and game.state.position == player.position and valid_angles(player.rotation.y,player.camera.rotation.x,game.state.yaw,game.state.pitch) and game.state.difficulty == 1 and game.state.level_load_error.is_empty(),"same native Player capsule/floor/processing and finite current campaign pose"): return false
	for id in markers:
		var target = markers[id].get_ref()
		if id in removed and id != CxPreparation.CHECKPOINT.id:
			if not require(target == null and not scene.markers.has(id),"collected original marker stays retired"): return false
		elif not require(is_instance_valid(target) and not target.is_queued_for_deletion() and scene.markers.get(id) == target and [target.get_instance_id(),target.transform] == marker_values[id],"same untouched original marker"): return false
	return require(shots.is_empty() and damage.is_empty() and hurts.is_empty() and births.is_empty() and contacts.is_empty() and pickups.is_empty() and pickup_attempts.is_empty() and captures == 0 and saves == 0 and pending_player.is_empty() and lethal.is_empty(),"C walking has no combat/pickup/lifecycle transaction")

func physics(delta: float) -> void:
	if cx_phase == "intermission": return
	if not require(current() and Engine.is_in_physics_frame() and absf(delta-1.0/60.0) < 0.000001,"C observes real current60Hz physics"): return
	ticks += 1
	survey()
	if cx_phase == "walking" and intent == CX_EXIT.id and game.nearest_interaction() == CX_EXIT: cx_ready = true

func before_exit() -> bool:
	if not require(cx_phase == "walking" and current() and game.transport_witness == self and Engine.is_in_physics_frame() and stack("/player.gd","_physics_process") and stack("/test_ossuary_transport_loop.gd","interact") and Input.is_action_pressed("interact") and key_events.size() == 1 and key_events[0][0] and intent == CX_EXIT.id and game.nearest_interaction() == CX_EXIT and cx_ready,"C exit only through original queued rebound E Player physics"): return false
	survey()
	if not validate(): return false
	cx_expected = entry_document(ledger)
	cx_expected_bytes = JSON.stringify(cx_expected,"",true,true).to_utf8_buffer()
	cx_expected_sha = CxPreparation.digest(cx_expected_bytes)
	var resources: Dictionary = ledger.duplicate(true)
	resources.merge({"keys":keys.duplicate(),"removed":removed.duplicate(),"floor_revision":1,"checkpoint_id":CxPreparation.CHECKPOINT.id,"position":[player.position.x,player.position.y,player.position.z],"actors":[],"yaw":CxPreparation.canonical(player.rotation.y),"pitch":clampf(player.camera.rotation.x,-1.35,1.35)},true)
	cx_capture_document = resources.duplicate(true)
	cx_capture_document.merge({"version":2,"difficulty":1,"level_index":5,"discoveries":[3,4,5],"explored":explored.duplicate(true),"checkpoint":checkpoint.duplicate(true),"level_start":start.duplicate(true)},true)
	cx_before_capture_document = before_capture_document(cx_capture_document,actor_image,game.state.yaw,game.state.pitch)
	cx_phase = "exit_pending"
	cx_trace.append("exit_before")
	return true

func before_capture() -> bool:
	if not require(cx_phase in ["exit_pending","save_pending"] and cx_pending_capture == 0 and cx_identity() and game.transport_witness == self and Engine.is_in_physics_frame() and stack("/player.gd","_physics_process") and stack("/main.gd","interact") and stack("/test_ossuary_transport_loop.gd","_capture_actor_state") and prior_frozen(),"C exact capture context before production effects"): return false
	if cx_phase == "exit_pending":
		if not require(captures == 0 and saves == 0 and not stack("/main.gd","_save") and current() and game.budget() == ledger and game.state.actors == actor_image,"C first capture is actual old world with27 earned deaths"): return false
		cx_pending_capture = 1
	else:
		if not require(captures == 1 and saves == 0 and cx_pending_save and stack("/main.gd","_save") and game._scene_level_index == 5 and game.state.level_index == 6 and game.state.to_dict() == cx_expected,"C nested capture2 is production scene-index mismatch no-op"): return false
		cx_pending_capture = 2
	cx_trace.append("capture%d_before" % cx_pending_capture)
	return true

func after_capture(result: bool) -> void:
	if not require(cx_pending_capture in [1,2] and game.transport_witness == self and stack("/main.gd","interact"),"C capture callback matches pending original invocation"): return
	var ordinal: int = cx_pending_capture
	cx_pending_capture = 0
	captures += 1
	cx_trace.append("capture%d_after:%s" % [ordinal,str(result)])
	if not result:
		cx_phase = "capture_failed"
		return
	if ordinal == 1:
		if not require(game.state.to_dict() == cx_capture_document and game.state.actors == [],"capture1 actual complete post-capture document has no living actors"): return
		cx_phase = "captured"
	else: require(game.state.to_dict() == cx_expected,"capture2 leaves predicted entry document unchanged")

func before_save() -> bool:
	if not require(cx_phase == "captured" and captures == 1 and saves == 0 and not cx_pending_save and cx_pending_capture == 0 and cx_identity() and game.transport_witness == self and Engine.is_in_physics_frame() and stack("/player.gd","_physics_process") and stack("/main.gd","interact") and stack("/test_ossuary_transport_loop.gd","_save") and game.state.to_dict() == cx_expected and FileAccess.get_file_as_bytes(profile) == cx_saved_bytes and prior_frozen(),"C once-only real save after completion before nested capture"): return false
	cx_pending_save = true
	cx_phase = "save_pending"
	cx_trace.append("save_before")
	return true

func after_save(result: Error) -> void:
	if not require(cx_pending_save and cx_phase == "save_pending" and captures == 2 and cx_pending_capture == 0 and saves == 0 and game.transport_witness == self and stack("/main.gd","interact"),"C save callback follows actual nested capture"): return
	cx_pending_save = false
	saves += 1
	cx_trace.append("save_after:%d" % result)
	if result != OK:
		cx_phase = "save_failed"
		return
	var reload = CxCampaign.new()
	if not require(game.state.to_dict() == cx_expected and FileAccess.get_file_as_bytes(profile) == cx_expected_bytes and FileAccess.get_sha256(profile) == cx_expected_sha and reload.load_progress(profile) and reload.to_dict() == cx_expected,"actual atomic bytes/hash and separate validated reload equal independent before-capture prediction"): return
	cx_phase = "saved"

func cx_menu(drained: bool) -> bool:
	if not cx_identity() or Input.mouse_mode != Input.MOUSE_MODE_VISIBLE or game.state.level_index != 6 or game._scene_level_index != -1 or game.level != null or game.player != null or not game.enemies.is_empty() or game.playing or game.placement_pending or game.loaded_positions or game.quitting or not game.get_tree().paused or not game.pending_action.is_empty() or game.pending_button != null or game._interaction_pending_player != 0: return false
	if not game.menu.visible or not game.menu_scroll.visible or game.menu.get_children().filter(func(node): return node is Label and node.text == "THE OSSUARY RESTORED").size() != 1: return false
	var buttons: Array = game.menu.get_children().filter(func(node): return node is Button and node.text == "Descend to The Inversion")
	if buttons.size() != 1 or buttons[0].disabled or not buttons[0].pressed.is_connected(Callable(game,"start_level")): return false
	var returns: Array = game.menu.get_children().filter(func(node): return node is Button and node.text == "Return to title")
	if game.menu.get_children().filter(func(node): return node is Button).size() != 2 or returns.size() != 1 or returns[0].disabled or not returns[0].pressed.is_connected(Callable(game,"show_title")): return false
	if cx_button != null and buttons[0] != cx_button: return false
	if not game.music.player.playing or game.music.player.stream_paused or not game.music.player.stream is AudioStreamOggVorbis or game.music.player.stream.resource_path != game.music.title_track or game.effects.players.values().any(func(node): return node.playing): return false
	if game.state.to_dict() != cx_expected or FileAccess.get_file_as_bytes(profile) != cx_expected_bytes or FileAccess.get_sha256(profile) != cx_expected_sha: return false
	if drained and (cx_world_ref.get_ref() != null or cx_player_ref.get_ref() != null or cx_actor_refs.values().any(func(ref): return ref.get_ref() != null) or markers.values().any(func(ref): return ref.get_ref() != null)): return false
	return true

func after_exit() -> void:
	if cx_phase in ["capture_failed","save_failed"]:
		var expected: Dictionary = cx_capture_document if cx_phase == "save_failed" else cx_before_capture_document
		require(game.state.to_dict() == expected,"failed capture/completion preserves its independently predicted recovery document")
		require(FileAccess.get_file_as_bytes(profile) == cx_saved_bytes and current(),"failed exit leaves old checkpoint bytes and live world")
		require(false,"C production capture/save refused exit; no publication")
		return
	if not require(cx_phase == "saved" and cx_pending_capture == 0 and not cx_pending_save and captures == 2 and saves == 1 and stack("/test_ossuary_transport_loop.gd","interact") and stack("/player.gd","_physics_process") and cx_menu(false) and is_instance_valid(scene) and scene.is_queued_for_deletion() and is_same(scene,cx_world_alias) and is_same(player,cx_player_alias),"only actual successful saved intermission admits natural original-world retirement"): return
	cx_button = game.menu.get_children().filter(func(node): return node is Button and node.text == "Descend to The Inversion")[0]
	cx_trace.append("exit_after")
	cx_retirement_verified = true
	cx_phase = "intermission"

func forbidden(label: String) -> void: require(false,"C forbids "+label)
func before_interact() -> void: forbidden("generic interaction")
func before_pickup(_id: String) -> Dictionary:
	forbidden("pickup")
	return {}
func before_encounter(id: String) -> Dictionary:
	# Main polls earned regions each render; only their unchanged no-op is allowed.
	require(ok and current() and game.transport_witness == self and prior_frozen() and activated.has(id) and removed.count("encounter:"+id) == 1 and game.state.removed == removed and stack("/main.gd","_update_encounters") and (stack("/main.gd","_process") or (Engine.is_in_physics_frame() and stack("/main.gd","update_encounter_triggers") and stack("/player.gd","_physics_process"))) and stack("/test_ossuary_transport_loop.gd","activate_encounter"),"C only repeats already-earned encounter without effects")
	return {}
func before_shot(_weapon: int) -> void: forbidden("shot")
func before_hurt(_amount: int) -> void: forbidden("damage")
func before_key(_id: String) -> void: forbidden("key")
func fire_input() -> bool:
	Input.action_release("fire")
	return false

func tick() -> bool:
	if not validate(): return false
	await fixture.physics_frame
	await fixture.process_frame
	return validate()

func release_exit_input() -> bool:
	var released: bool = true
	if not key_events.is_empty() and key_events[-1][0]: released = physical_key(false)
	if is_instance_valid(game) and is_instance_valid(player): game._cancel_interaction_input(player)
	if is_instance_valid(fixture): fixture.release_actions()
	intent = ""
	return released and not Input.is_action_pressed("interact") and not Input.is_physical_key_pressed(KEY_E) and ["fire","move_forward","move_back","move_left","move_right"].all(func(action): return not Input.is_action_pressed(action)) and (not is_instance_valid(game) or game._interaction_pending_player == 0)

func exit_route() -> bool:
	if not await route(CX_APPROACH): return false
	fixture.aim_interaction(CX_EXIT.cell)
	intent = CX_EXIT.id
	for frame in range(6):
		if not await tick(): return false
		if cx_ready: break
	if not require(cx_ready and validate() and captures == 0 and saves == 0 and cx_trace.is_empty(),"actual nearest original exit reached before C capture/save"): return false
	if "--omit-ossuary-exit" in OS.get_cmdline_user_args():
		print("OSSUARY_EXIT_OMITTED_READY original_nearest=true deaths27=true prior_frozen=true captures0=true saves0=true old_checkpoint=true")
		return require(false,CX_GUARD)
	if not physical_key(true): return false
	for frame in range(6):
		await fixture.physics_frame
		await fixture.process_frame
		if cx_phase == "intermission" or not ok: break
	var released: bool = release_exit_input()
	if not require(released and ok and cx_phase == "intermission",CX_GUARD): return false
	for frame in range(16):
		if cx_world_ref.get_ref() == null: break
		await fixture.process_frame
	if not validate() or not require(cx_menu(true) and cx_retirement_verified and waypoints == CX_APPROACH and key_events.size() == 2 and key_events[0][0] and not key_events[1][0] and cx_trace == ["exit_before","capture1_before","capture1_after:true","save_before","capture2_before","capture2_after:true","save_after:0","exit_after"] and prior_frozen(),"complete real exit/capture/save/no-op/menu/drain trace and exact history"): return false
	print("OSSUARY_EXIT_EARNED frames=",Engine.get_physics_frames()-epoch," resources=",ledger," captures=",captures," saves=",saves," lifecycle=",cx_trace," saved_sha=",cx_expected_sha," original_world_drained=true prior_frozen=true")
	return true

func run_route() -> bool:
	var result: bool = await exit_route()
	var released: bool = release_exit_input()
	return result and require(released,"C owns physical E/actions/pending cleanup before dispatch release")
