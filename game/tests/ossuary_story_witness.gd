extends "res://tests/ossuary_second_loop_witness.gd"

const Second = preload("res://tests/ossuary_second_loop_witness.gd")
const STORY = {"id":"ossuary_story","kind":"story","cell":[1.5,15.5],"text":"The bone tags mark every locked carrier as containment. Your mission voice calls the same locks damaged transport."}
const STORY_CARRY = {"health":92,"armor":196,"ammo":[0,169,32,120,0,0],"owned_weapons":[0,1,2,3],"weapon":1}
const STORY_SUPPLIES = ["ossuary_first_return_rivets","ossuary_first_return_health"]
const OUTWARD = [[19.5,24.0],[19.5,20.5],[19.5,16.5],[19.5,13.5],[16.5,13.5],[14.5,13.5],[13.5,13.5],[9.5,13.5],[6.5,14.5],[3.5,14.5],[1.5,14.5],[1.5,14.75]]
const HOMEWARD = [[1.5,14.5],[3.5,14.5],[6.5,14.5],[9.5,13.5],[13.5,13.5],[14.5,13.5],[16.5,13.5],[19.5,13.5],[19.5,16.5],[19.5,20.5],[19.5,24.0],[24.0,24.0]]
const STORY_GUARD = "NATIVE RED Story requires one queued rebound E interaction, original marker drain, discovery5 and authored notification"
var first_frozen: Dictionary = {}
var entry_supplies: Dictionary = {}
var discoveries: Array = [3,4]
var pending_story: bool = false
var notification_seen: bool = false
var settings_image: Dictionary = {}
var preferences_image: Dictionary = {}
var player_capsule: Array = []
var entry_carry: Dictionary = {}

# Pistol only: native Second callbacks still prove cadence, contacts and ownership.
# The old measured169 in STORY_CARRY is not an authority for this component.
static func verified_pistol_carry(shot_rows: Array, pickup_rows: Array, returned: Dictionary, live: Dictionary) -> Dictionary:
	if shot_rows.is_empty() or shot_rows.size() > SHOTS or pickup_rows.size() > 512: return {}
	var last_tick: int = -1
	var last_time: float = -1.0
	for row in shot_rows:
		if not row is Array or row.size() != 4 or not row[0] is int or row[0] <= last_tick or not row[1] is float or not is_finite(row[1]) or row[1] <= last_time or row[2] != 1 or not row[3] is float or not is_finite(row[3]) or row[3] <= 0 or row[3] > 0.210001: return {}
		last_tick = row[0]
		last_time = row[1]
	var pistol: int = Second.FIXED_CARRY.ammo[1]
	var cursor: int = 0
	var seen: Array = []
	var supplies: Dictionary = {}
	var consumed_pistol: Dictionary = {}
	last_tick = -1
	for row in pickup_rows:
		if not row is Array or row.size() != 5 or not row[0] in Second.SECOND_SUPPLIES or not row[1] is int or row[1] < last_tick or not row[2] is Dictionary or not row[3] is Dictionary or not row[4] is bool: return {}
		if not row[2].get("ammo") is Array or not row[3].get("ammo") is Array or row[2].ammo.size() != 6 or row[3].ammo.size() != 6 or not row[2].ammo[1] is int or not row[3].ammo[1] is int: return {}
		var image: Array = [row[0],row[2],row[3]]
		if image in seen: return {} # Native after_pickup already deduplicates these.
		seen.append(image)
		supplies[row[0]] = true
		last_tick = row[1]
		# Player fires before its passive scan in the same native physics callback.
		while cursor < shot_rows.size() and shot_rows[cursor][0] <= row[1]:
			pistol -= 1
			cursor += 1
			if pistol < 0: return {}
		if row[2].ammo[1] != pistol: return {}
		var pistol_supply: bool = row[0] in [Second.SECOND_SUPPLIES[0],Second.SECOND_SUPPLIES[2]]
		var after: int = mini(180,pistol+45) if pistol_supply else pistol
		if row[3].ammo[1] != after: return {}
		if pistol_supply:
			if consumed_pistol.has(row[0]) or row[4] != (after != pistol): return {}
			if row[4]: consumed_pistol[row[0]] = true
		pistol = after
	if not Second.SECOND_SUPPLIES.all(func(id): return supplies.has(id)): return {}
	pistol -= shot_rows.size()-cursor
	if pistol < 0 or pistol > 180: return {}
	var expected: Dictionary = STORY_CARRY.duplicate(true)
	expected.ammo[1] = pistol
	return expected if returned == expected and live == expected else {}

func earlier_frozen() -> bool:
	return is_instance_valid(previous) and is_instance_valid(previous.previous) and fields_match(previous,script_fields(previous),previous_frozen) and fields_match(previous.previous,script_fields(previous.previous),first_frozen)

func prior_frozen() -> bool:
	return earlier_frozen() and not entry_carry.is_empty() and entry_carry == previous_frozen.get("ledger",{}) and fields_match(game,main_fields,main_frozen) and fields_match(fixture,fixture_fields,fixture_frozen) and main_fields.all(func(name): return not name.ends_with("_enabled") or not game.get(name)) and game.prefix_bookkeeping_retired

func adopt_after(tree, accepted) -> bool:
	var callers: Array = get_stack()
	if not require(callers.size() > 1 and callers[1].source == "res://tests/test_ossuary_story.gd" and callers[1].function == "_completed_ossuary_story","Story adoption requires admitted immediate caller before bindings"): return false
	var owner = tree.game
	if not require(is_instance_valid(accepted) and accepted.get_script() == Second and accepted.ok and accepted.current() and owner.transport_witness == null and accepted.prior_frozen() and accepted.previous == tree.ot_witness and accepted.keys == ["blood","ivory"] and owner.state.discoveries == [3,4] and accepted.deaths.size() == 22 and accepted.summons.is_empty() and accepted.waypoints == Second.APPROACH+Second.INDEX_RETURN+Second.CLOSE,"actual returned accepted Second and exact earned carry before Story adoption"): return false
	var verified: Dictionary = verified_pistol_carry(accepted.shots,accepted.pickups,accepted.ledger,owner.budget())
	if not require(not verified.is_empty(),"Story independently reconciles exact returned Second pistol before bindings"): return false
	fixture = tree
	previous = accepted
	game = owner
	entry_carry = verified.duplicate(true)
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
	if not require(current() and player.position.distance_to(scene.layout.world_position([24.0,24.0])+Vector3.UP*0.04) < 0.2 and not Input.is_action_pressed("interact") and game._interaction_pending_player == 0 and scene.get_children().filter(func(node): return node.get_script() == preload("res://scripts/projectile.gd")).is_empty(),"same settled junction; prior E and finite projectiles drained"): return false
	for name in ["ledger","keys","removed","explored","checkpoint","start","actor_image","map_image","originals","bindings","hp","markers","marker_values","activated","deaths","finishes"]:
		var value = accepted.get(name)
		set(name,value.duplicate(true) if value is Array or value is Dictionary else value)
	last_cell = accepted.last_cell
	saved_sha = SAVE_SHA
	settings_sha = accepted.settings_sha
	settings_image = game.settings.duplicate(true)
	preferences_image = fields_image(game.preferences,script_fields(game.preferences))
	entry_deaths = deaths.duplicate(true)
	for node in game.enemies:
		entry_actors[node.id] = [node.position,node.rotation.y,node.age,node.hp,node.active,node.alerted,node._summoned_total]
	var capsule: CollisionShape3D = player.get_child(0)
	player_capsule = [capsule.get_instance_id(),capsule.shape.get_instance_id()]
	gate_ref = accepted.gate_ref
	gate_transform = accepted.gate_transform
	if not require(scene.layout.data.interactions[3] == STORY and not STORY.id in removed and is_instance_valid(markers[STORY.id].get_ref()) and scene.markers.get(STORY.id) == markers[STORY.id].get_ref(),"original authored Story marker retained at adoption"): return false
	for id in STORY_SUPPLIES:
		var retired: bool = id in removed
		var marker = markers[id].get_ref()
		if not require((not scene.markers.has(id) and marker == null) if retired else (is_instance_valid(marker) and not marker.is_queued_for_deletion() and scene.markers.get(id) == marker),"discover retained or drained original supply: "+id): return false
		entry_supplies[id] = retired
	main_fields = script_fields(game).filter(func(name): return not name in tree.OT_PRODUCTION_FIELDS and name != "transport_witness")
	fixture_fields = script_fields(tree)
	main_frozen = fields_image(game,main_fields)
	fixture_frozen = fields_image(tree,fixture_fields)
	previous_frozen = fields_image(accepted,script_fields(accepted))
	first_frozen = fields_image(accepted.previous,script_fields(accepted.previous))
	return require(current() and prior_frozen() and FileAccess.get_sha256(profile) == SAVE_SHA and FileAccess.get_sha256(settings) == settings_sha,"stored-value freeze before synchronous Story dispatch installation")

func physics(delta: float) -> void:
	if not require(current() and Engine.is_in_physics_frame() and absf(delta-1.0/60.0) < 0.000001,"Story native current-map60Hz observer"): return
	ticks += 1
	survey()

func before_pickup(id: String) -> Dictionary:
	if not require(current() and id in STORY_SUPPLIES and entry_supplies.has(id) and not entry_supplies[id],"only retained first-return Story-route supplies"): return {}
	var rows: Array = scene.layout.data.pickups.filter(func(spec): return spec.id == id)
	if not require(rows.size() == 1,"unique authored Story-route supply"): return {}
	var spec: Dictionary = rows[0]
	var marker = scene.markers.get(id)
	if not require(Engine.is_in_physics_frame() and stack("/main.gd","update_passive_triggers") and stack("/player.gd","_physics_process") and game.budget() == ledger and not consumed.has(id) and is_instance_valid(marker) and marker == markers[id].get_ref() and not marker.is_queued_for_deletion() and player.position.distance_to(scene.layout.world_position(spec.cell)) < 1.4 and game._passive_trigger_visible(spec),"actual original visible passive Story-route pickup"): return {}
	var expected: Dictionary = ledger.duplicate(true)
	if id == STORY_SUPPLIES[0]:
		if not require(spec == {"id":id,"kind":"ammo","weapon":1.0,"amount":45.0,"cell":[14.5,13.5]},"exact authored rivet supply"): return {}
		expected.ammo[1] = mini(180,int(expected.ammo[1])+45)
	else:
		if not require(spec == {"id":id,"kind":"health","amount":20.0,"cell":[13.5,13.5]},"exact authored health supply"): return {}
		expected.health = mini(100,int(expected.health)+20)
	return {"id":id,"before":ledger.duplicate(true),"after":expected,"marker":marker}

func before_interact() -> void:
	if not require(current() and game.transport_witness == self and Engine.is_in_physics_frame() and stack("/player.gd","_physics_process") and Input.is_action_pressed("interact") and intent == STORY.id and inputs.is_empty() and not pending_story and key_events.size() == 1 and key_events[0][0] and key_events[0][1] <= Engine.get_physics_frames(),"Story callback needs recorded physical E and real Player physics stack"): return
	var marker = markers[STORY.id].get_ref()
	if not require(game.nearest_interaction() == STORY and discoveries == [3,4] and game.state.discoveries == discoveries and not STORY.id in game.state.removed and is_instance_valid(marker) and scene.markers.get(STORY.id) == marker and not marker.is_queued_for_deletion() and [marker.get_instance_id(),marker.transform] == marker_values[STORY.id] and player.position.distance_to(scene.layout.world_position(STORY.cell)) < 4.5 and prior_frozen(),"nearest original Story within native strict range/facing/LOS; frozen prior evidence"): return
	inputs.append([STORY.id,Engine.get_physics_frames(),player.position,player.rotation.y,player.camera.rotation.x,marker.get_instance_id()])
	# Stage expectation before production's synchronous interact; validate after it returns.
	discoveries = [3,4,5]
	removed.append(STORY.id)
	pending_story = true

func before_encounter(id: String) -> Dictionary:
	if current() and "encounter:"+id in removed: return {}
	require(false,"Story spur cannot activate a new encounter: "+id)
	return {}

func before_key(id: String) -> void:
	require(false,"Story spur cannot collect another key: "+id)

func after_key(_id: String) -> void:
	require(false,"Story spur cannot settle a key callback")

func before_shot(_weapon: int) -> void:
	require(false,"Story spur cannot fire")

func before_enemy(_node, event: String) -> void:
	require(false,"Story spur cannot create a combat event: "+event)

func before_projectile(_projectile: Node3D, event: String, _data: Dictionary) -> void:
	require(false,"Story spur cannot create a projectile event: "+event)

func before_hurt(_amount: int) -> void:
	require(false,"Story spur cannot take damage")

func after_hurt() -> void:
	require(false,"Story spur cannot settle damage")

func after_aim(_origin: Vector3, _max_range: float, _melee: bool, _result: Dictionary) -> void:
	require(current() and not stack("/player.gd","fire"),"Story permits HUD aim observation but cannot resolve a fired shot")

func fire_input() -> bool:
	# Reuse sampled Second.route, but blocked legs fail rather than entering combat.
	return false

func validate() -> bool:
	if not require(ok and current() and game.transport_witness == self and prior_frozen(),"Story identities/dispatch and every earlier stored field frozen"): return false
	if pending_story:
		if not require(game.state.discoveries == discoveries and game.state.removed.count(STORY.id) == 1 and not scene.markers.has(STORY.id) and game.message == STORY.text and game.message_time > 0 and game.message_time <= 12.0,"production Story result and exact authored notification after synchronous interact"): return false
		notification_seen = true
		pending_story = false
	require(scene.layout.data == map_image and Engine.get_physics_frames()-epoch <= LIMIT and Time.get_ticks_usec()-wall <= SECONDS*1000000 and abs(Engine.get_physics_frames()-epoch-ticks) <= 2,"unchanged map and bounded new Story clock")
	require(game.is_processing() and game.is_physics_processing() and player.is_physics_processing() and player.position.is_finite() and game.state.difficulty == 1 and game.state.health > 0,"live processing and finite surviving Story player")
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
		if id in removed: require(not scene.markers.has(id) and (not is_instance_valid(marker) or marker.is_queued_for_deletion()),"original retired marker: "+id)
		else: require(is_instance_valid(marker) and not marker.is_queued_for_deletion() and scene.markers.get(id) == marker and [marker.get_instance_id(),marker.transform] == marker_values[id],"original retained marker: "+id)
	require(scene.markers.keys().all(func(id): return markers.has(id) and not id in removed) and scene.get_children().filter(func(node): return node.get_script() == preload("res://scripts/projectile.gd")).is_empty(),"marker roster unchanged except verified retirements; no projectiles")
	var capsule: CollisionShape3D = player.get_child(0)
	var support: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(player.position+Vector3.UP*0.5,player.position-Vector3.UP*0.5,1))
	require([capsule.get_instance_id(),capsule.shape.get_instance_id()] == player_capsule and player.collision_layer == 2 and player.collision_mask == 5 and not capsule.disabled and capsule.shape is CapsuleShape3D and capsule.shape.radius == Vector3(0.32,0,0).x and capsule.shape.height == Vector3(1.65,0,0).x and capsule.position == Vector3(0,0.85,0) and not support.is_empty() and support.normal.y >= 0.7 and absf(player.position.y-support.position.y) <= 0.15,"original Player capsule and actual floor support")
	var actual_removed: Array = game.state.removed.duplicate()
	var expected_removed: Array = removed.duplicate()
	actual_removed.sort()
	expected_removed.sort()
	var gate = gate_ref.get_ref()
	require(is_instance_valid(gate) and scene.doors.get("ossuary_transfer_gate") == gate and gate.transform == gate_transform and gate.collision_layer == 1 and not "ossuary_transfer_gate" in removed,"original transfer gate closed and unmoved")
	for hero in scene.layout.data.heroes:
		if hero.get("seal","") in keys:
			for id in hero.get("light_ids",[]): require(scene.machine_lights[id].light_color == Color(1.0,0.76,0.44),"earned seal lighting remains warm")
	require(game.budget() == ledger and game.state.keys == keys and keys == ["blood","ivory"] and game.state.discoveries == discoveries and game.state.explored == explored and actual_removed == expected_removed and removed.all(func(id): return removed.count(id) == 1) and deaths == entry_deaths and activated == previous.activated,"independent Story carry/Survey/removals and retained deaths/encounters")
	require(game.state.checkpoint_id == "entry" and game.state.checkpoint == checkpoint and game.state.level_start == start and game.state.actors == actor_image and game.state.level_load_error.is_empty() and FileAccess.get_sha256(profile) == SAVE_SHA and saved_sha == SAVE_SHA and FileAccess.get_sha256(settings) == settings_sha and game.settings == settings_image and fields_image(game.preferences,script_fields(game.preferences)) == preferences_image,"unchanged recovery, original disk save and preferences")
	require(shots.is_empty() and events.is_empty() and damage.is_empty() and hurts.is_empty() and births.is_empty() and contacts.is_empty() and pending_player.is_empty() and lethal.is_empty() and summons.is_empty() and saves == 0 and captures == 0 and mouse_attempts == 0 and starts == 0 and restarts == 0,"zero new combat/projectiles/summons/capture/save/mouse/start/restart")
	return ok

func release_story_input() -> bool:
	var released: bool = true
	if key_events.size() == 1 and key_events[0][0]: released = physical_key(false)
	if is_instance_valid(game) and is_instance_valid(player): game._cancel_interaction_input(player)
	if is_instance_valid(fixture): fixture.release_actions()
	intent = ""
	return released and not Input.is_action_pressed("interact") and not Input.is_physical_key_pressed(KEY_E) and (not is_instance_valid(game) or game._interaction_pending_player == 0)

func story_input() -> bool:
	if not validate(): return false
	fixture.aim_interaction(STORY.cell)
	intent = STORY.id
	var omitted: bool = "--omit-ossuary-story-interact" in OS.get_cmdline_user_args()
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
		var marker = markers[STORY.id].get_ref()
		if not require(discoveries == [3,4] and game.state.discoveries == [3,4] and inputs.is_empty() and key_events.is_empty() and not STORY.id in removed and not STORY.id in game.state.removed and is_instance_valid(marker) and not marker.is_queued_for_deletion() and scene.markers.get(STORY.id) == marker and prior_frozen(),"omitted Story requires live original marker, absent discovery and frozen history before actual assertion"): return false
		print("OSSUARY_STORY_OMITTED_READY marker_live=true discovery_absent=true prior_frozen=true")
	return require(discoveries == [3,4,5] and inputs.size() == 1 and inputs[0][0] == STORY.id and key_events.size() == 2 and key_events[0][0] and not key_events[1][0] and notification_seen and not pending_story and not scene.markers.has(STORY.id) and markers[STORY.id].get_ref() == null,STORY_GUARD)

func run_route() -> bool:
	var result: bool = await story_route()
	var released: bool = release_story_input()
	return result and require(released,"Story owns E-up and pending-input cleanup on every exit")

func story_route() -> bool:
	if not await route(OUTWARD) or not await story_input() or not await route(HOMEWARD): return false
	if not validate(): return false
	var expected: Dictionary = entry_carry.duplicate(true)
	for id in STORY_SUPPLIES:
		if entry_supplies[id]:
			if not require(not pickup_attempts.has(id) and not consumed.has(id),"already retired supply stays retired without a Story attempt"): return false
		else:
			if not require(pickup_attempts.get(id,0) >= 1 and consumed.get(id,0) == 1 and pickups.filter(func(row): return row[0] == id and row[4]).size() == 1 and markers[id].get_ref() == null,"retained supply actually attempted, granted once and drained"): return false
			if id == STORY_SUPPLIES[0]: expected.ammo[1] = mini(180,entry_carry.ammo[1]+45)
			else: expected.health = 100
	if not require(ledger == expected and waypoints == OUTWARD+HOMEWARD and player.position.distance_to(scene.layout.world_position([24.0,24.0])+Vector3.UP*0.04) < 0.2 and game.state.position == player.position and game.state.yaw == game.Enemy.canonical_yaw(player.rotation.y) and game.state.pitch == clampf(player.camera.rotation.x,-1.35,1.35),"Story spur returns to junction with independently reconciled carry and production current pose"): return false
	print("OSSUARY_STORY_EARNED frames=",Engine.get_physics_frames()-epoch," discoveries=",discoveries," resources=",ledger," entry_supplies=",entry_supplies," attempts=",pickup_attempts," pickups=",pickups," inputs=",inputs," physical_E=",key_events," saved_sha=",saved_sha," prior_frozen=",prior_frozen())
	return true
