extends "res://tests/ossuary_second_loop_witness.gd"

const Preparation = preload("res://tests/ossuary_finale_witness.gd")
const BATTLE_CARRY = {"health":100,"armor":200,"ammo":[0,180,32,120,8,0],"owned_weapons":[0,1,2,3],"weapon":1}
const FINALE = {"id":"ossuary_finale","region":[17.0,31.0,31.9,38.9],"requires":["blood","ivory"],"enemy_ids":["ossuary_enemy_22","ossuary_enemy_23","ossuary_enemy_24","ossuary_enemy_25","ossuary_enemy_26"],"cue":{"text":"ALL CONTAINED CARRIERS ARE NOW IN TRANSIT","light_ids":["ossuary_transfer_feed"],"sound":"seal_release"}}
const PATROL = [[22.5,31.5],[22.5,33.5],[27.5,33.5],[27.5,37.5],[22.5,37.5],[17.5,37.5],[17.5,32.0],[22.5,31.5]]
const BATTLE_GUARD = "NATIVE RED Battle requires real pistol input and five new original finale deaths after earned activation"
var preparation_fields: Array = []
var preparation_gate_alias: Variant
var saved_bytes: PackedByteArray = PackedByteArray()
var settings_values: Dictionary = {}
var preferences_values: Dictionary = {}
var player_capsule: Array = []
var entry_activated: Dictionary = {}
var encounter_pending: Dictionary = {}
var activation_record: Array = []
var omission: bool = false
var omission_ready: bool = false

func freeze_preparation(accepted) -> bool:
	if not require(is_instance_valid(accepted) and accepted.get_script() == Preparation and typeof(accepted.gate_alias) == TYPE_OBJECT and not is_instance_valid(accepted.gate_alias),"actual Preparation participant has an already-retired raw gate alias"): return false
	previous = accepted
	preparation_gate_alias = accepted.gate_alias
	preparation_fields = script_fields(accepted)
	previous_frozen = fields_image(accepted,preparation_fields)
	return preparation_fields_unchanged()

func preparation_fields_unchanged() -> bool:
	if not (is_instance_valid(previous) and previous.get_script() == Preparation and is_same(previous.gate_alias,preparation_gate_alias)): return false
	var fields: Array = preparation_fields.duplicate()
	var frozen: Dictionary = previous_frozen.duplicate()
	fields.erase("histories")
	frozen.erase("histories")
	if not fields_match(previous,fields,frozen) or not previous_frozen.get("histories") is Array: return false
	var histories: Array = []
	for source in previous.histories:
		if not source is Dictionary or source.size() != 3 or not source.has("owner") or typeof(source.owner) != TYPE_OBJECT or not is_instance_valid(source.owner) or not source.get("fields") is Array or not source.get("image") is Dictionary: return false
		# Preparation's stored images are already canonical; normalize only live owners.
		var record: Dictionary = source.duplicate()
		record.owner = stored_image(source.owner)
		histories.append(record)
	return histories == previous_frozen.histories

func prior_frozen() -> bool:
	return preparation_fields_unchanged() and previous.prior_frozen()

func adopt_after(tree, accepted) -> bool:
	fixture = tree
	game = tree.game
	if not require(is_instance_valid(accepted) and accepted.get_script() == Preparation and accepted.ok and accepted.current() and accepted.prior_frozen() and game.transport_witness == null and accepted.phase == "gate_open" and accepted.captures == 2 and accepted.saves == 1 and accepted.gate_calls == 1 and accepted.checkpoint_message_seen and accepted.waypoints == Preparation.APPROACH_GATE+Preparation.FINISH_GATE and accepted.ledger == BATTLE_CARRY and game.budget() == BATTLE_CARRY and accepted.deaths.size() == 22 and accepted.summons.is_empty() and game.enemies.size() == 27 and accepted.bindings.size() == 27 and game.enemies.filter(func(node): return node.hp > 0).size() == 5 and accepted.inputs.size() == 1 and accepted.key_events.size() == 2 and not accepted.key_events[-1][0],"actual returned successful Preparation, ended route/carry and released dispatch"): return false
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
	if not require(current() and player.position.distance_to(scene.layout.world_position([22.5,30.5])+Vector3.UP*0.04) < 0.2 and not Input.is_action_pressed("interact") and not Input.is_physical_key_pressed(KEY_E) and not Input.is_action_pressed("fire") and game._interaction_pending_player == 0 and not accepted.gate_pending and not accepted.capture_pending and accepted.gate_ref.get_ref() == null and not scene.doors.has(Preparation.GATE.id) and scene.layout.data.encounters[4] == FINALE and game.state.keys == ["blood","ivory"] and game.state.discoveries == [3,4,5],"same settled preparation endpoint, original drained gate and authored finale"): return false
	for name in ["ledger","keys","removed","explored","checkpoint","start","actor_image","map_image","originals","bindings","hp","markers","marker_values","activated","deaths","finishes"]:
		var value = accepted.get(name)
		set(name,value.duplicate(true) if value is Array or value is Dictionary else value)
	last_cell = accepted.last_cell
	saved_sha = accepted.saved_sha
	saved_bytes = accepted.expected_bytes.duplicate()
	settings_sha = accepted.settings_sha
	settings_values = accepted.settings_values.duplicate(true)
	preferences_values = accepted.preferences_values.duplicate(true)
	player_capsule = accepted.player_capsule.duplicate()
	entry_deaths = deaths.duplicate(true)
	entry_activated = activated.duplicate(true)
	gate_ref = accepted.gate_ref
	gate_transform = accepted.gate_transform
	if not require(saved_bytes == JSON.stringify(accepted.expected_document,"",true,true).to_utf8_buffer() and Preparation.digest(saved_bytes) == saved_sha and FileAccess.get_file_as_bytes(profile) == saved_bytes and FileAccess.get_sha256(profile) == saved_sha and game.state.checkpoint == checkpoint and game.state.level_start == start and game.state.actors == actor_image and actor_image == accepted.expected_actors and actor_image.map(func(row): return row.id) == FINALE.enemy_ids and not "encounter:"+FINALE.id in removed,"prior independently predicted saved five-actor checkpoint, not a new disk/snapshot baseline"): return false
	for node in game.enemies:
		if not require(actor(node) and accepted.entry_actors.has(node.id),"prior-bound original actor at Battle adoption"): return false
		var entry: Array = accepted.entry_actors[node.id].duplicate(true)
		if not require(node.position == entry[0] and node.rotation.y == entry[1] and node.hp == entry[3] and node.hp == hp[node.id] and node.active == entry[4] and node.alerted == entry[5] and node._summoned_total == entry[6],"prior-proven native actor state remains unchanged"): return false
		entry[2] = node.age # Refresh only the production clock in this new witness.
		entry_actors[node.id] = entry
	omission = "--omit-ossuary-battle-fire" in OS.get_cmdline_user_args()
	if not freeze_preparation(accepted): return false
	return require(prior_frozen() and scene.get_children().filter(func(node): return node.get_script() == preload("res://scripts/projectile.gd")).is_empty(),"complete Preparation/earlier fields frozen before synchronous Battle dispatch")

func before_encounter(id: String) -> Dictionary:
	if not require(ok and current() and game.transport_witness == self and prior_frozen(),"Battle encounter current identity/dispatch/history"): return {}
	if "encounter:"+id in removed: return {}
	var cell: Vector2 = Vector2(player.position.x,player.position.z)/4.0
	var region: Array = FINALE.region
	if not require(id == FINALE.id and scene.layout.data.encounters[4] == FINALE and not activated.has(id) and encounter_pending.is_empty() and activation_record.is_empty() and stack("/main.gd","_process") and stack("/test_ossuary_transport_loop.gd","activate_encounter") and not stack("/enemy.gd","take_damage") and cell.is_equal_approx(cell.clamp(Vector2(region[0],region[1]),Vector2(region[2],region[3]))) and game.state.keys == keys and keys == FINALE.requires and FINALE.enemy_ids.all(func(actor_id): return hp[actor_id] == ROLES[originals[actor_id][4]][0]),"original finale only through actual region/key Main process activation"): return {}
	encounter_pending = {"spec":FINALE.duplicate(true),"tick":Engine.get_physics_frames(),"position":player.position}
	return FINALE

func after_encounter(spec: Dictionary) -> void:
	if spec.is_empty(): return
	if not require(ok and current() and game.transport_witness == self and spec == FINALE and not encounter_pending.is_empty() and encounter_pending.spec == spec and encounter_pending.tick == Engine.get_physics_frames() and stack("/main.gd","_process") and stack("/test_ossuary_transport_loop.gd","activate_encounter") and game.state.removed.count("encounter:"+FINALE.id) == 1 and not "encounter:"+FINALE.id in removed and game.message == FINALE.cue.text and game.message_time > 0 and game.message_time <= 5.0,"matching once-only native finale activation result/cue"): return
	super.after_encounter(spec)
	if not ok: return
	activation_record = [Engine.get_physics_frames(),encounter_pending.position,FINALE.enemy_ids.duplicate(),keys.duplicate()]
	encounter_pending = {}
	if omission:
		if not require(shots.is_empty() and deaths == entry_deaths and FINALE.enemy_ids.all(func(id): return hp[id] == ROLES[originals[id][4]][0]) and game.enemies.filter(func(node): return node.encounter_id == FINALE.id).all(func(node): return actor(node) and node.hp == node.max_hp and node.active and node.alerted) and prior_frozen(),"omitted-fire READY uses five actual full activated originals and frozen history"): return
		omission_ready = true
		print("OSSUARY_BATTLE_OMITTED_FIRE_READY finale_active=true five_full_originals=true shots_absent=true prior_frozen=true")

func before_shot(weapon: int) -> void:
	if not require(ok and current() and game.transport_witness == self and not omission and activated.has(FINALE.id) and weapon == 1 and game.state.weapon == 1 and Engine.is_in_physics_frame() and stack("/player.gd","fire") and stack("/player.gd","_physics_process") and Input.is_action_pressed("fire") and not player._fire_release_required and player.shot_age(1) == 0.0 and game.entry_slot(Engine.get_physics_frames(),last_tick,slot,weapon) >= 0 and player.active_play_time > last_time and shots.size() < SHOTS and ledger.ammo[1] > 0 and prior_frozen(),"Battle pistol entry guard before any observer debit"): return
	super.before_shot(weapon)

func before_pickup(_id: String) -> Dictionary:
	require(false,"Battle cannot attempt another pickup")
	return {}
func before_interact() -> void: require(false,"Battle cannot interact or exit")
func before_key(_id: String) -> void: require(false,"Battle cannot collect a key")
func after_key(_id: String) -> void: require(false,"Battle cannot settle a key")

func tick() -> bool:
	# Stop the reused route promptly after the genuine omitted-fire activation READY.
	if omission and omission_ready: return false
	return await super.tick()

func validate() -> bool:
	if not require(ok and current() and game.transport_witness == self and prior_frozen(),"same native identities/live dispatch; every earlier Main/fixture/first-witness stored value frozen"): return false
	register_summons()
	require(scene.layout.data == map_image and Engine.get_physics_frames()-epoch <= LIMIT and Time.get_ticks_usec()-wall <= SECONDS*1000000,"unchanged map and new-only12000-frame/600s bounds")
	require(abs(Engine.get_physics_frames()-epoch-ticks) <= 2 and game.is_processing() and game.is_physics_processing() and player.is_physics_processing() and player.position.is_finite() and game.state.health > 0 and game.state.difficulty == 1,"live native processing/pose/survival")
	var child_ids: Array = scene.get_children().filter(func(node): return node.get_script() == game.Enemy).map(func(node): return node.get_instance_id())
	var bound_ids: Array = bindings.values().map(func(binding): return binding[0])
	var listed_ids: Array = game.enemies.map(func(node): return node.get_instance_id())
	child_ids.sort()
	bound_ids.sort()
	listed_ids.sort()
	require(child_ids == bound_ids and listed_ids == bound_ids and bindings.size() == 27 and game.enemies.size() == 27 and summons.is_empty(),"same27 originals; dead first-loop summoner cannot create a birth")
	for node in game.enemies:
		if not require(actor(node),"bound original actor identity"): return false
		var actor_capsule: CollisionShape3D = node.get_child(0)
		var role: Array = ROLES[node.kind]
		var binding: Array = bindings[node.id]
		var original: Array = originals[node.id]
		var entry: Array = entry_actors[node.id]
		require(node.is_physics_processing() and actor_capsule.get_instance_id() == binding[1] and actor_capsule.shape.get_instance_id() == binding[2] and not actor_capsule.disabled and actor_capsule.shape is CapsuleShape3D and absf(actor_capsule.shape.radius-role[1]) < 0.000001 and absf(actor_capsule.shape.height-role[2]) < 0.000001 and actor_capsule.position == Vector3(0,actor_capsule.shape.height/2,0) and node.position.is_finite() and is_finite(node.rotation.y) and node.hp == hp[node.id] and node.hp >= 0 and node.max_hp == role[0] and node.kind == original[4] and node.encounter_id == original[5] and node._summon_owner_id.is_empty() and node._summoned_total == entry[6] and node.age-entry[2] >= float(Engine.get_physics_frames()-epoch-2)/60.0,"original native role/capsule/HP/age/processing: "+node.id)
		if entry[3] == 0:
			require(node.hp == 0 and node.position == entry[0] and node.rotation.y == entry[1] and node.active == entry[4] and node.alerted == entry[5] and entry_deaths.get(node.id,0) == 1,"accepted first-loop corpse unchanged: "+node.id)
		elif not activated.has(node.encounter_id): require(node.hp == node.max_hp and node.position == entry[0] and node.rotation.y == entry[1] and not node.active and not node.alerted,"unentered original dormant/fullHP/pose: "+node.id)
		if node.hp > 0:
			var floor_hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(node.position+Vector3.UP*0.5,node.position-Vector3.UP*6,1))
			require(node.collision_layer == 4 and node.collision_mask == 7 and not floor_hit.is_empty() and floor_hit.normal.y >= 0.7 and absf(node.position.y-floor_hit.position.y-(1.0 if node.kind == "caster" else 0.0)) <= (0.25 if node.kind == "caster" else 0.15),"native living actor floor/collision")
		else: require(deaths.get(node.id,0) == 1 and finishes.get(node.id,"") in ["player","infighting"] and node.collision_layer == 0 and node.collision_mask == 0 and game.state.removed.count(node.id) == 1,"all deaths once-only with retained native provenance")
	for id in markers:
		var ref = markers[id].get_ref()
		if id in removed and id != Preparation.CHECKPOINT.id: require(not scene.markers.has(id) and (not is_instance_valid(ref) or ref.is_queued_for_deletion()),"claimed marker retired: "+id)
		else: require(is_instance_valid(ref) and not ref.is_queued_for_deletion() and scene.markers.get(id) == ref and [ref.get_instance_id(),ref.transform] == marker_values[id],"uncollected original marker identity/transform: "+id)
	for node in scene.get_children():
		if node.get_script() != preload("res://scripts/projectile.gd") or node.is_queued_for_deletion(): continue
		require(births.has(node.get_instance_id()) and births[node.get_instance_id()][0].get_ref() == node and actor(node.shooter) and node._current_map() and node.is_physics_processing() and node.lifetime > 0 and node.lifetime <= 4.0,"every live caster/guardian projectile has actual finite birth")
	var capsule: CollisionShape3D = player.get_child(0)
	var support: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(player.position+Vector3.UP*0.5,player.position-Vector3.UP*0.5,1))
	require(player.collision_layer == 2 and player.collision_mask == 5 and not capsule.disabled and capsule.shape is CapsuleShape3D and capsule.shape.radius == Vector3(0.32,0,0).x and capsule.shape.height == Vector3(1.65,0,0).x and capsule.position == Vector3(0,0.85,0) and not support.is_empty() and support.normal.y >= 0.7 and absf(player.position.y-support.position.y) <= 0.15,"original Player capsule and actual floor triangles")
	var actual_removed: Array = game.state.removed.duplicate()
	var expected_removed: Array = removed.duplicate()
	actual_removed.sort()
	expected_removed.sort()
	for hero in scene.layout.data.heroes:
		if hero.get("seal","") in keys:
			for id in hero.get("light_ids",[]): require(scene.machine_lights.has(id) and scene.machine_lights[id].light_color == Color(1.0,0.76,0.44),"earned seal lights remain warm: "+id)
	require(gate_ref.get_ref() == null and not scene.doors.has(Preparation.GATE.id) and Preparation.GATE.id in removed,"original gate remains retired after its saved checkpoint")
	require([capsule.get_instance_id(),capsule.shape.get_instance_id()] == player_capsule and scene.markers.keys().all(func(id): return markers.has(id) and (not id in removed or id == Preparation.CHECKPOINT.id)),"original Player capsule and unchanged marker roster")
	require(game.budget() == ledger and game.state.keys == keys and keys == ["blood","ivory"] and actual_removed == expected_removed and removed.all(func(id): return removed.count(id) == 1) and game.state.explored == explored and game.state.discoveries == [3,4,5] and game.state.owned_weapons == [0,1,2,3] and game.state.weapon == 1 and game.state.ammo[0] == 0 and game.state.ammo[2] == 32 and game.state.ammo[3] == 120 and game.state.ammo[4] == 8 and game.state.ammo[5] == 0 and game.state.checkpoint_id == Preparation.CHECKPOINT.id and game.state.checkpoint == checkpoint and game.state.level_start == start and game.state.actors == actor_image and game.state.level_load_error.is_empty() and FileAccess.get_file_as_bytes(profile) == saved_bytes and FileAccess.get_sha256(profile) == saved_sha and FileAccess.get_sha256(settings) == settings_sha and game.settings == settings_values and fields_image(game.preferences,script_fields(game.preferences)) == preferences_values,"independent Battle budget/Survey/removals; prior recovery/checkpoint bytes/preferences unchanged")
	require(pickups.is_empty() and pickup_attempts.is_empty() and consumed.is_empty() and inputs.is_empty() and key_events.is_empty() and summons.is_empty() and captures == 0 and saves == 0 and mouse_attempts == 0 and starts == 0 and restarts == 0 and pending_player.is_empty() and lethal.is_empty() and incoming_ray == Vector3.ZERO and encounter_pending.is_empty(),"no pickup/key/input/lifecycle/birth or unresolved native transaction")
	for id in entry_deaths: require(deaths.get(id,0) == entry_deaths[id] and finishes.get(id) == previous.finishes[id],"old death provenance remains exact: "+id)
	for id in entry_activated: require(activated.get(id) == entry_activated[id],"old activation record remains exact: "+id)
	require(activated.keys().all(func(id): return entry_activated.has(id) or id == FINALE.id) and deaths.keys().all(func(id): return entry_deaths.has(id) or id in FINALE.enemy_ids),"only five finale originals/new group may extend the old ledgers")

	return ok


func fire_input() -> bool:
	Input.action_release("fire")
	if omission or not ok or not current() or not activated.has(FINALE.id) or game.state.weapon != 1 or ledger.ammo[1] <= 0 or shots.size() >= SHOTS: return false
	var selected = null
	var nearest: float = 140.0
	for node in game.enemies:
		if not actor(node) or node.hp <= 0 or not node.active or node.encounter_id != FINALE.id: continue
		var candidate_aim: Vector3 = node.global_position+node.get_child(0).position
		var distance: float = player.camera.global_position.distance_to(candidate_aim)
		if distance >= nearest: continue
		var query = PhysicsRayQueryParameters3D.create(player.camera.global_position,candidate_aim,1|4)
		query.exclude = [player.get_rid()]
		var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.get("collider") == node:
			selected = node
			nearest = distance
	if selected == null: return false
	var aim: Vector3 = selected.global_position+selected.get_child(0).position
	var heading: Vector3 = aim-player.camera.global_position
	player.rotation.y = atan2(-heading.x,-heading.z)
	player.camera.look_at(aim,Vector3.UP)
	Input.action_press("fire")
	return true

func release_battle_input() -> bool:
	var released: bool = true
	if not key_events.is_empty() and key_events[-1][0]: released = physical_key(false)
	if is_instance_valid(game):
		var target = player if is_instance_valid(player) else game.player
		if is_instance_valid(target): game._cancel_interaction_input(target)
	if is_instance_valid(fixture): fixture.release_actions()
	intent = ""
	return released and not Input.is_action_pressed("interact") and not Input.is_physical_key_pressed(KEY_E) and ["fire","move_forward","move_back","move_left","move_right"].all(func(action): return not Input.is_action_pressed(action)) and (not is_instance_valid(game) or game._interaction_pending_player == 0)

func battle_route() -> bool:
	var entered: bool = await route([PATROL[0]])
	if omission:
		if not require(ok and omission_ready and activation_record.size() == 4 and shots.is_empty() and prior_frozen(),"omission reached actual finale activation READY before dedicated Battle guard"): return false
		return require(false,BATTLE_GUARD)
	if not entered or not await route(PATROL.slice(1)) or not await fight(FINALE.id): return false
	fixture.release_actions()
	for frame in range(LEG):
		if scene.get_children().filter(func(node): return node.get_script() == preload("res://scripts/projectile.gd")).is_empty(): break
		if not await tick(): return false
		await fixture.process_frame
	if not validate(): return false
	if not require(FINALE.enemy_ids.all(func(id): return deaths.get(id,0) == 1 and not entry_deaths.has(id)) and deaths.size() == 27 and all_dead(FINALE.id) and activation_record.size() == 4 and not damage.is_empty() and shots.size() > 0 and shots.size() <= SHOTS and ledger.ammo[1] == 180-shots.size() and game.enemies.all(func(node): return node.hp == 0) and scene.get_children().filter(func(node): return node.get_script() == preload("res://scripts/projectile.gd")).is_empty(),BATTLE_GUARD): return false
	var target: Vector3 = scene.layout.world_position(PATROL[-1])+Vector3.UP*0.04
	if not require(waypoints == PATROL and player.position.distance_to(target) < 0.2 and game.state.position == player.position and game.state.yaw == Preparation.canonical(player.rotation.y) and game.state.pitch == clampf(player.camera.rotation.x,-1.35,1.35) and prior_frozen(),"full finite native finale patrol/settled return and frozen Preparation history"): return false
	print("OSSUARY_BATTLE_EARNED frames=",Engine.get_physics_frames()-epoch," shots=",shots.size()," new_deaths=",FINALE.enemy_ids," provenance=",finishes," resources=",ledger," damage=",damage," hurts=",hurts," births=",births.size()," contacts=",contacts," saved_sha=",saved_sha," prior_frozen=",prior_frozen())
	return true

func run_route() -> bool:
	var result: bool = await battle_route()
	var released: bool = release_battle_input()
	return result and require(released,"Battle owns fire/movement/E-up and pending cleanup before inherited finish")
