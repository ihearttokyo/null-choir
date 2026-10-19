extends "res://tests/ossuary_second_loop_witness.gd"

const Story = preload("res://tests/ossuary_story_witness.gd")
const PREP_CARRY = {"health":100,"armor":196,"ammo":[0,169,32,120,0,0],"owned_weapons":[0,1,2,3],"weapon":1}
const CHECKPOINT = {"id":"ossuary_checkpoint","kind":"checkpoint","cell":[22.5,28.5],"requires":["blood","ivory"],"text":"TRANSFER RECOVERY IMAGE STORED"}
const GATE = {"id":"ossuary_transfer_gate","cell":[22.5,29.7],"yaw":0.0,"size":[12.2,5.0,0.6],"requires":["blood","ivory"]}
const SUPPLY_IDS = ["ossuary_finale_rivets","ossuary_finale_shells","ossuary_finale_health","ossuary_finale_armor","ossuary_launcher_ammo"]
const APPROACH_GATE = [[22.5,24.0],[21.5,26.5],[22.5,27.5],[23.5,27.5],[23.5,26.5],[22.5,28.5],[22.5,28.7]]
const FINISH_GATE = [[22.5,30.5]]
const GATE_GUARD = "NATIVE RED preparation requires queued rebound E original gate after saved checkpoint"
var phase: String = "unbound"
var histories: Array = []
var gate_alias: Variant
var gate_id: int = 0
var gate_calls: int = 0
var gate_last_y: float = 0.0
var gate_pending: bool = false
var capture_pending: bool = false
var lifecycle: Array = []
var expected_actors: Array = []
var expected_document: Dictionary = {}
var expected_bytes: PackedByteArray = PackedByteArray()
var checkpoint_message_seen: bool = false
var gate_ready: bool = false
var settings_values: Dictionary = {}
var preferences_values: Dictionary = {}
var player_capsule: Array = []

static func canonical(value: float) -> float:
	if value < -PI or value >= PI: value = wrapf(value,-PI,PI)
	return Vector3(0,clampf(value,-3.1415925,3.1415925),0).y

static func digest(bytes: PackedByteArray) -> String:
	var context = HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(bytes) != OK: return ""
	return context.finish().hex_encode()

func freeze_owner(owner, fields: Array) -> void:
	histories.append({"owner":owner,"fields":fields.duplicate(),"image":fields_image(owner,fields)})

func prior_frozen() -> bool:
	for record in histories:
		if not fields_match(record.owner,record.fields,record.image): return false
	return not histories.is_empty() and main_fields.all(func(name): return not name.ends_with("_enabled") or not game.get(name)) and game.prefix_bookkeeping_retired

func adopt_after(tree, accepted) -> bool:
	fixture = tree
	previous = accepted
	game = tree.game
	if not require(is_instance_valid(accepted) and accepted.get_script() == Story and accepted.ok and accepted.current() and accepted.prior_frozen() and game.transport_witness == null and accepted.ledger == PREP_CARRY and game.budget() == PREP_CARRY and accepted.waypoints == Story.OUTWARD+Story.HOMEWARD and accepted.notification_seen and accepted.inputs.size() == 1 and accepted.key_events.size() == 2 and accepted.discoveries == [3,4,5] and accepted.deaths.size() == 22 and accepted.summons.is_empty(),"actual returned completed Story, fixed carry and released dispatch"): return false
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
	if not require(current() and player.position.distance_to(scene.layout.world_position([24.0,24.0])+Vector3.UP*0.04) < 0.2 and not Input.is_action_pressed("interact") and not Input.is_physical_key_pressed(KEY_E) and game._interaction_pending_player == 0 and FileAccess.get_sha256(profile) == SAVE_SHA,"same settled Story junction, original save and drained E"): return false
	for name in ["ledger","keys","removed","explored","checkpoint","start","actor_image","map_image","originals","bindings","hp","markers","marker_values","activated","deaths","finishes"]:
		var value = accepted.get(name)
		set(name,value.duplicate(true) if value is Array or value is Dictionary else value)
	last_cell = accepted.last_cell
	saved_sha = SAVE_SHA
	settings_sha = accepted.settings_sha
	settings_values = game.settings.duplicate(true)
	preferences_values = fields_image(game.preferences,script_fields(game.preferences))
	entry_deaths = deaths.duplicate(true)
	for node in game.enemies:
		var proven: Array = accepted.entry_actors[node.id].duplicate(true)
		if not require(node.position == proven[0] and node.rotation.y == proven[1] and node.hp == hp[node.id] and node.active == proven[4] and node.alerted == proven[5],"native actor still matches prior-proven Story values"): return false
		proven[2] = node.age # Only the production clock advances between segments.
		entry_actors[node.id] = proven
	for spec in map_image.enemies:
		if hp[spec.id] <= 0: continue
		var entry: Array = entry_actors[spec.id]
		expected_actors.append({"id":spec.id,"hp":hp[spec.id],"position":[entry[0].x,entry[0].y,entry[0].z],"yaw":canonical(entry[1]),"alerted":false})
	gate_alias = accepted.gate_ref.get_ref()
	if not require(is_instance_valid(gate_alias) and scene.doors.get(GATE.id) == gate_alias and gate_alias.transform == accepted.gate_transform and scene.layout.data.doors == [GATE] and scene.layout.data.interactions[2] == CHECKPOINT and expected_actors.map(func(row): return row.id) == scene.layout.data.encounters[4].enemy_ids and expected_actors.size() == 5,"five prior-proven dormant originals and exact original gate/checkpoint"): return false
	gate_id = gate_alias.get_instance_id()
	gate_ref = weakref(gate_alias)
	gate_transform = accepted.gate_transform
	gate_last_y = gate_alias.position.y
	var capsule: CollisionShape3D = player.get_child(0)
	player_capsule = accepted.player_capsule.duplicate()
	if not require([capsule.get_instance_id(),capsule.shape.get_instance_id()] == player_capsule,"original prior-proven player capsule identities"): return false
	main_fields = script_fields(game).filter(func(name): return not name in tree.OT_PRODUCTION_FIELDS and name != "transport_witness")
	fixture_fields = script_fields(tree)
	freeze_owner(game,main_fields)
	freeze_owner(tree,fixture_fields)
	for witness in [accepted,accepted.previous,accepted.previous.previous]: freeze_owner(witness,script_fields(witness))
	phase = "preparation"
	return require(prior_frozen() and game.state.keys == ["blood","ivory"] and game.state.discoveries == [3,4,5] and scene.get_children().filter(func(node): return node.get_script() == preload("res://scripts/projectile.gd")).is_empty(),"all prior stored fields frozen before synchronous preparation dispatch")

func physics(delta: float) -> void:
	if not require(current() and Engine.is_in_physics_frame() and absf(delta-1.0/60.0) < 0.000001,"native current-map preparation observer"): return
	ticks += 1
	survey()
	if phase == "checkpoint_saved" and intent == GATE.id and game.nearest_interaction() == GATE: gate_ready = true

func before_pickup(id: String) -> Dictionary:
	if not require(current() and id in SUPPLY_IDS and not consumed.has(id),"only original preparation supplies"): return {}
	var rows: Array = map_image.pickups.filter(func(spec): return spec.id == id)
	if not require(rows.size() == 1,"unique preparation supply"): return {}
	var spec: Dictionary = rows[0]
	var marker = scene.markers.get(id)
	if not require(Engine.is_in_physics_frame() and stack("/main.gd","update_passive_triggers") and stack("/player.gd","_physics_process") and game.budget() == ledger and is_instance_valid(marker) and marker == markers[id].get_ref() and not marker.is_queued_for_deletion() and player.position.distance_to(scene.layout.world_position(spec.cell)) < 1.4 and game._passive_trigger_visible(spec),"actual native passive preparation attempt"): return {}
	var expected: Dictionary = ledger.duplicate(true)
	if spec.kind == "ammo":
		var index: int = int(spec.weapon)
		if not require(index in [1,2,4],"preparation ammo indices including unowned slot4"): return {}
		expected.ammo[index] = mini([0,180,32,240,24,120][index],int(expected.ammo[index])+int(spec.amount))
	elif spec.kind == "health": expected.health = mini(100,int(expected.health)+int(spec.amount))
	elif spec.kind == "armor": expected.armor = mini(200,int(expected.armor)+int(spec.amount))
	else:
		require(false,"preparation cannot acquire a weapon")
		return {}
	return {"id":id,"before":ledger.duplicate(true),"after":expected,"marker":marker}

func capture_context() -> bool:
	return ok and current() and game.transport_witness == self and prior_frozen() and Engine.is_in_physics_frame() and stack("/player.gd","_physics_process") and stack("/main.gd","update_passive_triggers") and game.budget() == ledger and game.state.keys == keys and keys == ["blood","ivory"] and game.state.discoveries == [3,4,5]

func checkpoint_resources() -> Dictionary:
	var expected: Dictionary = ledger.duplicate(true)
	expected.merge({"keys":keys.duplicate(),"removed":removed.duplicate(),"floor_revision":1,"checkpoint_id":CHECKPOINT.id,"position":[player.position.x,player.position.y,player.position.z],"actors":expected_actors.duplicate(true),"yaw":canonical(player.rotation.y),"pitch":clampf(player.camera.rotation.x,-1.35,1.35)},true)
	return expected

func before_capture() -> bool:
	if not require(capture_context() and stack("/test_ossuary_transport_loop.gd","_capture_actor_state") and not capture_pending,"earned current-map checkpoint capture context"): return false
	survey()
	if not require(game.state.explored == explored,"independent current-cell Survey before checkpoint capture"): return false
	if phase == "preparation":
		var marker = markers[CHECKPOINT.id].get_ref()
		var expected: Array = removed.duplicate()
		expected.append(CHECKPOINT.id)
		if not require(captures == 0 and saves == 0 and not stack("/main.gd","_save") and game.state.removed == expected and is_instance_valid(marker) and scene.markers.get(CHECKPOINT.id) == marker and [marker.get_instance_id(),marker.transform] == marker_values[CHECKPOINT.id] and not marker.is_queued_for_deletion() and player.position.distance_to(scene.layout.world_position(CHECKPOINT.cell)) < 3.2 and game._passive_trigger_visible(CHECKPOINT) and FileAccess.get_sha256(profile) == SAVE_SHA,"once-only original visible passive checkpoint capture1 after removed append"): return false
		removed.append(CHECKPOINT.id)
		checkpoint = checkpoint_resources()
		expected_document = checkpoint.duplicate(true)
		expected_document.merge({"version":2,"difficulty":1,"level_index":5,"discoveries":[3,4,5],"explored":explored.duplicate(true),"checkpoint":checkpoint.duplicate(true),"level_start":start.duplicate(true)},true)
		expected_bytes = JSON.stringify(expected_document,"",true,true).to_utf8_buffer()
		if not require(not expected_bytes.is_empty() and expected_bytes.size() <= 1048576,"bounded independently constructed canonical checkpoint bytes"): return false
		saved_sha = digest(expected_bytes)
		if not require(saved_sha.length() == 64,"predicted checkpoint SHA before production writes"): return false
		phase = "capturing"
	elif phase == "saving":
		if not require(captures == 1 and saves == 1 and stack("/main.gd","_save") and game.state.checkpoint == checkpoint and game.state.removed == removed,"save's exact nested checkpoint capture2"): return false
	else: return require(false,"checkpoint capture denied in phase "+phase)
	captures += 1
	capture_pending = true
	lifecycle.append(["capture_before",captures])
	return true

func after_capture(result: bool) -> void:
	if not require(capture_context() and stack("/test_ossuary_transport_loop.gd","_capture_actor_state") and capture_pending and not expected_document.is_empty() and not expected_bytes.is_empty() and digest(expected_bytes) == saved_sha and result and captures in [1,2] and game.state.actors == expected_actors and game.state.yaw == checkpoint.yaw and game.state.pitch == checkpoint.pitch,"actual production checkpoint actor/pose capture output"): return
	capture_pending = false
	actor_image = expected_actors.duplicate(true)
	lifecycle.append(["capture_after",captures,result])
	if captures == 1: phase = "captured"

func before_save() -> bool:
	if not require(capture_context() and stack("/test_ossuary_transport_loop.gd","_save") and phase == "captured" and captures == 1 and saves == 0 and not capture_pending and game.state.removed == removed and game.state.explored == explored and game.state.checkpoint_id == CHECKPOINT.id and game.state.checkpoint == checkpoint and game.state.level_start == start and game.state.actors == expected_actors and FileAccess.get_sha256(profile) == SAVE_SHA,"one actual checkpoint save after capture/mark_checkpoint"): return false
	saves = 1
	phase = "saving"
	lifecycle.append(["save_before",1])
	return true

func after_save(result: Error) -> void:
	var expected_order: Array = [["capture_before",1],["capture_after",1,true],["save_before",1],["capture_before",2],["capture_after",2,true]]
	if not require(capture_context() and stack("/test_ossuary_transport_loop.gd","_save") and phase == "saving" and result == OK and captures == 2 and saves == 1 and not capture_pending and lifecycle == expected_order,"actual nested capture/save order and successful return"): return
	var loaded = game.Campaign.new()
	if not require(game.state.to_dict() == expected_document and FileAccess.get_file_as_bytes(profile) == expected_bytes and FileAccess.get_sha256(profile) == saved_sha and loaded.load_progress(profile) and loaded.to_dict() == expected_document,"predicted canonical checkpoint bytes/hash and separate validated reload"): return
	lifecycle.append(["save_after",1,result])
	phase = "checkpoint_saved"

func before_interact() -> void:
	if not require(ok and current() and game.transport_witness == self and phase == "checkpoint_saved" and checkpoint_message_seen and captures == 2 and saves == 1 and gate_calls == 0 and not gate_pending and inputs.is_empty() and key_events.size() == 1 and key_events[0][0] and intent == GATE.id and Input.is_action_pressed("interact") and Engine.is_in_physics_frame() and stack("/player.gd","_physics_process") and game.nearest_interaction() == GATE and is_instance_valid(gate_alias) and scene.doors.get(GATE.id) == gate_alias and gate_alias.get_instance_id() == gate_id and gate_alias.transform == gate_transform and prior_frozen(),"real queued E original gate only after independently saved checkpoint"): return
	inputs.append([GATE.id,Engine.get_physics_frames(),player.position,player.rotation.y,player.camera.rotation.x])
	gate_pending = true

func before_gate(id: String) -> bool:
	return require(ok and current() and game.transport_witness == self and phase == "checkpoint_saved" and Engine.is_in_physics_frame() and stack("/test_ossuary_transport_loop.gd","unlock_door") and id == GATE.id and gate_pending and gate_calls == 0 and inputs.size() == 1 and inputs[0][1] == Engine.get_physics_frames() and Input.is_action_pressed("interact") and stack("/main.gd","interact") and stack("/player.gd","_physics_process") and game.nearest_interaction() == GATE and scene.doors.get(id) == gate_alias and is_instance_valid(gate_alias) and gate_alias.transform == gate_transform and game.state.keys == keys and FileAccess.get_sha256(profile) == saved_sha and prior_frozen(),"exact native once-only gate permission and original body")

func after_gate(result: bool) -> void:
	if not require(ok and current() and game.transport_witness == self and phase == "checkpoint_saved" and Engine.is_in_physics_frame() and stack("/test_ossuary_transport_loop.gd","unlock_door") and stack("/main.gd","interact") and stack("/player.gd","_physics_process") and gate_pending and gate_calls == 0 and result and not scene.doors.has(GATE.id) and is_instance_valid(gate_alias) and gate_alias.collision_layer == 0 and game.state.removed.count(GATE.id) == 1 and not GATE.id in removed,"actual production gate opening result without save/capture"): return
	gate_pending = false
	gate_calls = 1
	removed.append(GATE.id)
	phase = "gate_open"

func before_encounter(id: String) -> Dictionary:
	if current() and "encounter:"+id in removed: return {}
	require(false,"preparation cannot enter a new encounter: "+id)
	return {}

func before_key(_id: String) -> void: require(false,"preparation cannot collect a key")
func after_key(_id: String) -> void: require(false,"preparation cannot settle a key")
func before_shot(_weapon: int) -> void: require(false,"preparation cannot fire")
func before_enemy(_node, _event: String) -> void: require(false,"preparation cannot create combat")
func before_projectile(_node: Node3D, _event: String, _data: Dictionary) -> void: require(false,"preparation cannot create a projectile")
func before_hurt(_amount: int) -> void: require(false,"preparation cannot take damage")
func after_hurt() -> void: require(false,"preparation cannot settle damage")
func after_aim(_origin: Vector3, _range: float, _melee: bool, _result: Dictionary) -> void: require(current() and not stack("/player.gd","fire"),"only HUD aim observation during preparation")
func fire_input() -> bool: return false

func validate() -> bool:
	if not require(ok and current() and game.transport_witness == self and prior_frozen(),"preparation exact identities/dispatch and frozen history"): return false
	require(scene.layout.data == map_image and Engine.get_physics_frames()-epoch <= LIMIT and Time.get_ticks_usec()-wall <= SECONDS*1000000 and abs(Engine.get_physics_frames()-epoch-ticks) <= 2,"unchanged map and original new-phase12000-frame/600s bounds")
	require(game.is_processing() and game.is_physics_processing() and player.is_physics_processing() and player.position.is_finite() and game.state.difficulty == 1,"live native processing and original difficulty")
	var child_ids: Array = scene.get_children().filter(func(node): return node.get_script() == game.Enemy).map(func(node): return node.get_instance_id())
	var bound_ids: Array = bindings.values().map(func(binding): return binding[0])
	var listed_ids: Array = game.enemies.map(func(node): return node.get_instance_id())
	child_ids.sort()
	bound_ids.sort()
	listed_ids.sort()
	require(child_ids == bound_ids and listed_ids == bound_ids and bindings.size() == 27 and summons.is_empty() and game.enemies.filter(func(node): return node.hp > 0).size() == 5,"same27 originals/22 corpses/five finale originals; zero births")
	for node in game.enemies:
		if not require(actor(node) and entry_actors.has(node.id),"bound original Story actor"): return false
		var entry: Array = entry_actors[node.id]
		var capsule: CollisionShape3D = node.get_child(0)
		var role: Array = ROLES[node.kind]
		require(node.position == entry[0] and node.rotation.y == entry[1] and node.hp == entry[3] and node.active == entry[4] and node.alerted == entry[5] and node._summoned_total == entry[6] and node._summon_owner_id.is_empty() and node.kind == originals[node.id][4] and node.encounter_id == originals[node.id][5] and node.max_hp == role[0] and node.is_physics_processing() and node.age-entry[2] >= float(Engine.get_physics_frames()-epoch-2)/60.0,"actor pose/HP/role stable with native age progression: "+node.id)
		require(capsule.get_instance_id() == bindings[node.id][1] and capsule.shape.get_instance_id() == bindings[node.id][2] and capsule.shape is CapsuleShape3D and not capsule.disabled and absf(capsule.shape.radius-role[1]) < 0.000001 and absf(capsule.shape.height-role[2]) < 0.000001 and capsule.position == Vector3(0,capsule.shape.height/2,0),"original actor capsule: "+node.id)
		if node.hp == 0: require(deaths.get(node.id,0) == 1 and finishes.get(node.id,"") in ["player","infighting"] and node.collision_layer == 0 and node.collision_mask == 0,"accepted corpse and provenance remain stable")
		else:
			var floor_hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(node.position+Vector3.UP*0.5,node.position-Vector3.UP*6,1))
			require(node.hp == node.max_hp and not node.active and not node.alerted and node.collision_layer == 4 and node.collision_mask == 7 and not floor_hit.is_empty() and floor_hit.normal.y >= 0.7 and absf(node.position.y-floor_hit.position.y-(1.0 if node.kind == "caster" else 0.0)) <= (0.25 if node.kind == "caster" else 0.15),"five dormant/full finale originals on native floor")
	for id in markers:
		var marker = markers[id].get_ref()
		if id in removed and id != CHECKPOINT.id: require(not scene.markers.has(id) and (not is_instance_valid(marker) or marker.is_queued_for_deletion()),"original retired marker: "+id)
		else: require(is_instance_valid(marker) and not marker.is_queued_for_deletion() and scene.markers.get(id) == marker and [marker.get_instance_id(),marker.transform] == marker_values[id],"original retained marker: "+id)
	require(scene.markers.keys().all(func(id): return markers.has(id) and (not id in removed or id == CHECKPOINT.id)) and scene.get_children().filter(func(node): return node.get_script() == preload("res://scripts/projectile.gd")).is_empty(),"marker roster unchanged except verified retirements; no projectiles")
	var capsule: CollisionShape3D = player.get_child(0)
	var support: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(player.position+Vector3.UP*0.5,player.position-Vector3.UP*0.5,1))
	require([capsule.get_instance_id(),capsule.shape.get_instance_id()] == player_capsule and player.collision_layer == 2 and player.collision_mask == 5 and not capsule.disabled and capsule.shape is CapsuleShape3D and capsule.shape.radius == Vector3(0.32,0,0).x and capsule.shape.height == Vector3(1.65,0,0).x and capsule.position == Vector3(0,0.85,0) and not support.is_empty() and support.normal.y >= 0.7 and absf(player.position.y-support.position.y) <= 0.15,"original Player capsule and actual floor support")
	if phase == "checkpoint_saved" and not checkpoint_message_seen:
		if not require(game.message == CHECKPOINT.text and game.message_time > 0 and game.message_time <= 3.0,"actual authored checkpoint-saved notification"): return false
		checkpoint_message_seen = true
	if gate_calls == 0:
		require(is_instance_valid(gate_alias) and scene.doors.get(GATE.id) == gate_alias and gate_alias.get_instance_id() == gate_id and gate_alias.transform == gate_transform and gate_alias.collision_layer == 1 and not GATE.id in removed,"original closed gate before real queued E")
	elif is_instance_valid(gate_alias):
		require(phase == "gate_open" and not scene.doors.has(GATE.id) and gate_alias.get_parent() == scene and gate_alias.collision_layer == 0 and gate_alias.transform.basis == gate_transform.basis and gate_alias.position.x == gate_transform.origin.x and gate_alias.position.z == gate_transform.origin.z and gate_alias.position.y >= gate_last_y-0.00001 and gate_alias.position.y <= gate_transform.origin.y+6.00001,"production gate collision/tween geometry remains bounded and monotone")
		gate_last_y = gate_alias.position.y
	else: require(phase == "gate_open" and gate_ref.get_ref() == null and not scene.doors.has(GATE.id),"original gate body drains through production tween ownership")
	var actual_removed: Array = game.state.removed.duplicate()
	var expected_removed: Array = removed.duplicate()
	actual_removed.sort()
	expected_removed.sort()
	require(game.budget() == ledger and ledger.health == 100 and game.state.keys == keys and keys == ["blood","ivory"] and game.state.discoveries == [3,4,5] and game.state.owned_weapons == [0,1,2,3] and game.state.weapon == 1 and game.state.explored == explored and actual_removed == expected_removed and removed.all(func(id): return removed.count(id) == 1) and deaths == entry_deaths and activated == previous.activated,"independent preparation carry/Survey/removal and unchanged combat provenance")
	require(game.state.checkpoint_id == ("entry" if captures == 0 else CHECKPOINT.id) and game.state.checkpoint == checkpoint and game.state.level_start == start and game.state.actors == actor_image and game.state.level_load_error.is_empty() and FileAccess.get_sha256(profile) == saved_sha and FileAccess.get_sha256(settings) == settings_sha and game.settings == settings_values and fields_image(game.preferences,script_fields(game.preferences)) == preferences_values,"only predicted checkpoint recovery/disk changes; original preferences and entry image")
	if saves == 1: require(FileAccess.get_file_as_bytes(profile) == expected_bytes,"saved checkpoint bytes remain exact after gate/movement")
	require(shots.is_empty() and events.is_empty() and damage.is_empty() and hurts.is_empty() and births.is_empty() and contacts.is_empty() and pending_player.is_empty() and lethal.is_empty() and summons.is_empty() and captures <= 2 and saves <= 1 and mouse_attempts == 0 and starts == 0 and restarts == 0,"zero combat/births/unapproved lifecycle effects")
	return ok

func release_preparation_input() -> bool:
	var released: bool = true
	if key_events.size() == 1 and key_events[0][0]: released = physical_key(false)
	if is_instance_valid(game) and is_instance_valid(player): game._cancel_interaction_input(player)
	if is_instance_valid(fixture): fixture.release_actions()
	intent = ""
	return released and not Input.is_action_pressed("interact") and not Input.is_physical_key_pressed(KEY_E) and (not is_instance_valid(game) or game._interaction_pending_player == 0)

func gate_input() -> bool:
	if not validate() or not require(phase == "checkpoint_saved" and captures == 2 and saves == 1,"saved checkpoint before gate input"): return false
	fixture.aim_interaction(GATE.cell,GATE.size[1]/2.0)
	intent = GATE.id
	var omitted: bool = "--omit-ossuary-preparation-gate" in OS.get_cmdline_user_args()
	if not omitted and not physical_key(true): return false
	for frame in range(6):
		if not await tick(): return false
		if not inputs.is_empty(): break
	if not omitted and not physical_key(false): return false
	fixture.release_actions()
	intent = ""
	await fixture.process_frame
	if not validate(): return false
	if omitted:
		if not require(gate_ready and phase == "checkpoint_saved" and inputs.is_empty() and key_events.is_empty() and gate_calls == 0 and is_instance_valid(gate_alias) and scene.doors.get(GATE.id) == gate_alias and gate_alias.transform == gate_transform and gate_alias.collision_layer == 1 and not GATE.id in game.state.removed and expected_actors.size() == 5 and prior_frozen(),"omitted gate READY requires real saved checkpoint/live original gate/five dormant/frozen history"): return false
		print("OSSUARY_PREPARATION_OMITTED_GATE_READY checkpoint_saved=true gate_live=true finale_dormant=true prior_frozen=true")
	return require(phase == "gate_open" and gate_calls == 1 and inputs.size() == 1 and inputs[0][0] == GATE.id and key_events.size() == 2 and key_events[0][0] and not key_events[1][0] and not gate_pending,GATE_GUARD)

func preparation_route() -> bool:
	if not await route(APPROACH_GATE) or not await gate_input(): return false
	for frame in range(LEG):
		if gate_ref.get_ref() == null: break
		fixture.release_actions()
		if not await tick(): return false
		await fixture.process_frame
	if not require(gate_ref.get_ref() == null,"finite original gate body/tween drain before crossing"): return false
	if not await route(FINISH_GATE) or not validate(): return false
	var final_carry: Dictionary = {"health":100,"armor":200,"ammo":[0,180,32,120,8,0],"owned_weapons":[0,1,2,3],"weapon":1}
	if not require(ledger == final_carry and captures == 2 and saves == 1 and gate_calls == 1 and checkpoint_message_seen and [SUPPLY_IDS[0],SUPPLY_IDS[1],SUPPLY_IDS[3],SUPPLY_IDS[4]].all(func(id): return pickup_attempts.get(id,0) > 0) and [SUPPLY_IDS[0],SUPPLY_IDS[3],SUPPLY_IDS[4]].all(func(id): return consumed.get(id,0) == 1 and markers[id].get_ref() == null) and not consumed.has(SUPPLY_IDS[1]),"actual clamped preparation scans/grants, unowned ammo4 without weapon and exact two-capture/one-save/gate budget"): return false
	var target: Vector3 = scene.layout.world_position(FINISH_GATE[0])+Vector3.UP*0.04
	if not require(waypoints == APPROACH_GATE+FINISH_GATE and player.position.distance_to(target) < 0.2 and player.position.z/4.0 < 31.0 and game.state.position == player.position and game.state.yaw == canonical(player.rotation.y) and game.state.pitch == clampf(player.camera.rotation.x,-1.35,1.35) and prior_frozen(),"settled gate crossing below finale region; actual current pose and frozen history"): return false
	print("OSSUARY_PREPARATION_EARNED frames=",Engine.get_physics_frames()-epoch," resources=",ledger," captures=",captures," saves=",saves," gate=",gate_calls," pickups=",pickups," attempts=",pickup_attempts," lifecycle=",lifecycle," checkpoint_sha=",saved_sha," prior_frozen=",prior_frozen())
	return true

func run_route() -> bool:
	var result: bool = await preparation_route()
	var released: bool = release_preparation_input()
	return result and require(released,"preparation owns E-up and pending cleanup before inherited finish")
