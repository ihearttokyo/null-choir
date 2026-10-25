extends "res://tests/ossuary_transport_witness.gd"

# Conditional proposal: install beside the unchanged accepted helper only after review.
const SECOND_GROUPS = ["ossuary_second_commit","ossuary_second_return"]
const SECOND_SUPPLIES = ["ossuary_second_approach_rivets","ossuary_second_approach_shells","ossuary_second_return_rivets","ossuary_second_return_health"]
const FIXED_CARRY = {"health":100,"armor":200,"ammo":[0,165,32,120,0,0],"owned_weapons":[0,1,2,3],"weapon":1}
const IVORY = {"id":"ossuary_ivory","kind":"key","key":"ivory","cell":[33.5,13.5],"text":"BONE INDEX IVORY SEAL RECOVERED"}
const APPROACH = [[27.5,24.5],[27.5,21.5],[27.5,20.5],[28.5,20.5],[27.5,20.5],[27.5,18.5],[27.5,16.5],[33.5,16.5],[33.5,14.0]]
const INDEX_RETURN = [[33.5,10.5],[33.5,9.5],[30.5,9.5],[25.5,9.5],[25.5,11.5],[23.5,11.5],[22.5,11.5],[20.75,11.5],[19.5,11.5]]
const CLOSE = [[19.5,14.5],[19.5,20.5],[19.5,24.0],[24.0,24.0]]
const IVORY_GUARD = "NATIVE RED second loop requires queued rebound E Ivory, original marker drain and warmed mandala BEFORE second return"
var fixture
var previous
var main_fields: Array = []
var fixture_fields: Array = []
var main_frozen: Dictionary = {}
var fixture_frozen: Dictionary = {}
var previous_frozen: Dictionary = {}
var entry_actors: Dictionary = {}
var entry_deaths: Dictionary = {}
var key_events: Array = []
var guardian_releases: Dictionary = {}
var guardian_birth_ticks: Dictionary = {}
var shield_records: Array = []
var incoming_ray: Vector3 = Vector3.ZERO
var gate_ref
var gate_transform: Transform3D
var settings_sha: String = ""

# Freeze stored WeakRef identity, not its target's permitted later retirement.
static func stored_image(value):
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(stored_image(item) if item is Array or item is Dictionary or typeof(item) == TYPE_OBJECT else item)
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			var item: Variant = value[key]
			result[key] = stored_image(item) if item is Array or item is Dictionary or typeof(item) == TYPE_OBJECT else item
		return result
	if typeof(value) == TYPE_OBJECT:
		return {"object_id":value.get_instance_id() if is_instance_valid(value) else 0}
	return value

static func fields_image(object, fields: Array) -> Dictionary:
	var result: Dictionary = {}
	for name in fields: result[name] = stored_image(object.get(name))
	return result

static func script_fields(object) -> Array:
	var result: Array = []
	for property in object.get_property_list():
		if (int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE) != 0: result.append(str(property.name))
	result.sort()
	return result

# Reuse frozen containers only inside this synchronous, local comparison.
static func fields_match(object, fields: Array, frozen: Dictionary) -> bool:
	var actual: Dictionary = {}
	for name in fields:
		var value: Variant = object.get(name)
		if frozen.has(name) and typeof(value) != TYPE_OBJECT and typeof(value) == typeof(frozen[name]) and value == frozen[name]:
			actual[name] = frozen[name]
		else:
			actual[name] = stored_image(value)
	return actual == frozen

func prior_frozen() -> bool:
	return fields_match(game,main_fields,main_frozen) and fields_match(fixture,fixture_fields,fixture_frozen) and fields_match(previous,script_fields(previous),previous_frozen) and main_fields.all(func(name): return not name.ends_with("_enabled") or not game.get(name)) and game.prefix_bookkeeping_retired

func adopt_after(tree, first) -> bool:
	fixture = tree
	previous = first
	game = tree.game
	# Earlier assertions run unchanged and finish before their immutable value freeze.
	if not require(first == tree.ot_witness and game.transport_witness == first and first.validate() and tree.transport_prior_frozen() and first.summons.is_empty() and first.deaths.size() == 11 and first.activated.keys() == GROUPS and first.keys == ["blood"] and first.ledger == FIXED_CARRY and game.budget() == FIXED_CARRY,"verified fixed106/normal105 first-loop carry"): return false
	scene = game.level
	player = game.player
	main_id = game.get_instance_id()
	campaign_id = game.state.get_instance_id()
	level_id = scene.get_instance_id()
	player_id = player.get_instance_id()
	profile = game.progress_path
	settings = game.settings_path
	if not require(current() and scene.get_children().filter(func(node): return node.get_script() == preload("res://scripts/projectile.gd")).is_empty() and player.position.distance_to(scene.layout.world_position([24.0,24.0])+Vector3.UP*0.04) < 0.2,"same earned junction; finite first-loop projectiles already drained"): return false
	epoch = Engine.get_physics_frames()
	wall = Time.get_ticks_usec()
	# Only observer data is copied. Production resources, actors and recovery stay untouched.
	for name in ["ledger","keys","removed","explored","checkpoint","start","actor_image","map_image","originals","bindings","hp","markers","marker_values","activated","deaths","finishes"]:
		var value = first.get(name)
		set(name,value.duplicate(true) if value is Array or value is Dictionary else value)
	last_cell = first.last_cell
	saved_sha = SAVE_SHA
	settings_sha = FileAccess.get_sha256(settings)
	entry_deaths = deaths.duplicate(true)
	for node in game.enemies:
		entry_actors[node.id] = [node.position,node.rotation.y,node.age,node.hp,node.active,node.alerted,node._summoned_total]
	gate_ref = weakref(scene.doors.get("ossuary_transfer_gate"))
	if not require(is_instance_valid(gate_ref.get_ref()),"original closed transfer gate retained"): return false
	gate_transform = gate_ref.get_ref().transform
	main_fields = script_fields(game).filter(func(name): return not name in tree.OT_PRODUCTION_FIELDS and name != "transport_witness")
	fixture_fields = script_fields(tree)
	main_frozen = fields_image(game,main_fields)
	fixture_frozen = fields_image(tree,fixture_fields)
	previous_frozen = fields_image(first,script_fields(first))
	return require(current() and prior_frozen() and game.budget() == ledger and FileAccess.get_sha256(profile) == SAVE_SHA,"frozen adoption before synchronous dispatch-slot handoff")

func before_pickup(id: String) -> Dictionary:
	var rows: Array = scene.layout.data.pickups.filter(func(spec): return spec.id == id)
	if not require(rows.size() == 1 and id in SECOND_SUPPLIES,"only four authored second-loop supplies; launcher remains outside route"): return {}
	var spec: Dictionary = rows[0]
	var marker = scene.markers.get(id)
	if not require(current() and Engine.is_in_physics_frame() and game.budget() == ledger and stack("/main.gd","update_passive_triggers") and stack("/player.gd","_physics_process") and not consumed.has(id) and marker == markers[id].get_ref() and is_instance_valid(marker) and not marker.is_queued_for_deletion() and player.position.distance_to(scene.layout.world_position(spec.cell)) < 1.4 and game._passive_trigger_visible(spec),"original visible once-only second-loop production pickup: "+id): return {}
	var expected: Dictionary = ledger.duplicate(true)
	if spec.kind == "ammo":
		var index: int = int(spec.weapon)
		if not require(index in [1,2] and index in expected.owned_weapons,"pistol/shell pickup without selection or ownership change"): return {}
		expected.ammo[index] = mini([0,180,32,240,24,120][index],int(expected.ammo[index])+int(spec.amount))
	elif spec.kind == "health": expected.health = mini(100,int(expected.health)+int(spec.amount))
	else:
		require(false,"unexpected second-loop pickup kind")
		return {}
	return {"id":id,"before":ledger.duplicate(true),"after":expected,"marker":marker}

func before_encounter(id: String) -> Dictionary:
	if "encounter:"+id in game.state.removed: return {}
	var rows: Array = scene.layout.data.encounters.filter(func(spec): return spec.id == id)
	if not require(rows.size() == 1 and id in SECOND_GROUPS,"only authored second commit/return regions"): return {}
	var spec: Dictionary = rows[0]
	var cell: Vector2 = Vector2(player.position.x,player.position.z)/4.0
	var region: Array = spec.region
	if not require(current() and not activated.has(id) and Engine.is_in_physics_frame() and stack("/main.gd","update_encounter_triggers") and stack("/player.gd","_physics_process") and not stack("/enemy.gd","take_damage") and cell.is_equal_approx(cell.clamp(Vector2(region[0],region[1]),Vector2(region[2],region[3]))) and spec.requires.all(func(key): return key in keys),"earned inclusive region/key activation: "+id): return {}
	return spec

# Production's shield uses hit geometry, idle state and strict front-bearing >0.5.
static func guarded_amount(amount: int, incoming: Vector3, forward: Vector3, idle: bool) -> int:
	if incoming.is_finite(): incoming.y = 0
	if idle and incoming.is_finite() and incoming.length_squared() > 0.0001 and forward.dot(incoming.normalized()) > 0.5: return maxi(1,int(amount*0.35))
	return amount

func observe_damage(victim, source, amount: int, hit: Dictionary, mode: String, caller: String) -> void:
	if actor(victim) and victim.kind == "guardian":
		var incoming: Vector3 = Vector3.ZERO
		if caller in ["player","projectile"]: incoming = -incoming_ray
		elif caller == "worker": incoming = -(source._committed_aim-(source.global_position+Vector3.UP*1.4)).normalized()
		elif caller == "melee": incoming = -(source._committed_target.global_position+Vector3.UP*0.7-(source.global_position+Vector3.UP*0.6)).normalized()
		if not require(incoming.is_finite() and incoming.length_squared() > 0 and caller in ["player","projectile","worker","melee"],"guardian damage requires actual incoming geometry"): return
		var idle: bool = victim.telegraph_time <= 0 and victim.pose_time <= 0 and victim.recovery_time <= 0
		var applied: int = guarded_amount(amount,incoming,-victim.global_basis.z,idle)
		shield_records.append([Engine.get_physics_frames(),caller,amount,applied,incoming,-victim.global_basis.z,victim.telegraph_time,victim.pose_time,victim.recovery_time,hit.get("rid")])
		amount = applied
	super.observe_damage(victim,source,amount,hit,mode,caller)

func after_aim(origin: Vector3, max_range: float, melee: bool, result: Dictionary) -> void:
	incoming_ray = result.get("direction",Vector3.ZERO).normalized()
	super.after_aim(origin,max_range,melee,result)
	incoming_ray = Vector3.ZERO

func before_enemy(node, event: String) -> void:
	super.before_enemy(node,event)
	if not ok: return
	if node.kind == "guardian" and event == "attack":
		if not require(node.id == "ossuary_enemy_08" and stack("/enemy.gd","_release_attack") and node._released and is_instance_valid(node._committed_target) and node._committed_aim.is_finite(),"native original guardian committed release"): return
		var tick: int = Engine.get_physics_frames()
		if not require(not guardian_releases.has(tick),"one guardian release per native tick"): return
		guardian_releases[tick] = [node.get_instance_id(),node._committed_aim]

func before_projectile(projectile: Node3D, event: String, data: Dictionary) -> void:
	var source = projectile.shooter
	if event == "configured_birth" and actor(source) and source.kind == "guardian":
		var id: int = projectile.get_instance_id()
		var tick: int = Engine.get_physics_frames()
		var origin: Vector3 = source.global_position+Vector3.UP*1.65
		var destination: Vector3 = origin+(source._committed_aim-origin).normalized()*30.0
		if not require(current() and OS.is_debug_build() and Engine.is_in_physics_frame() and source.id == "ossuary_enemy_08" and source.hp > 0 and source.active and activated.has(source.encounter_id) and source._released and guardian_releases.has(tick) and guardian_releases[tick] == [source.get_instance_id(),source._committed_aim] and not guardian_birth_ticks.has(tick) and stack("/enemy.gd","_fire_pattern") and stack("/enemy.gd","_release_late_attack") and stack("/enemy.gd","_release_attack") and stack("/projectile.gd","configure"),"guardian projectile uses actual single-pattern release, not caster assumptions"): return
		if not require(projectile.get_script() == preload("res://scripts/projectile.gd") and projectile.game == game and projectile._current_map() and projectile.get_parent() == scene and projectile.is_physics_processing() and not projectile.is_queued_for_deletion() and data.get("projectile") == projectile and data.get("source") == source and data.get("map") == scene and data.get("player") == player and data.get("tick",-1) == tick and data.get("origin") == origin and data.get("destination") == destination and data.get("position") == origin and projectile.global_position == origin and data.get("velocity") == projectile.velocity and projectile.velocity.is_finite() and is_equal_approx(projectile.velocity.length(),12.0) and projectile.velocity.is_equal_approx((destination-origin).normalized()*12.0) and data.get("lifetime") == 4.0 and projectile.lifetime == 4.0 and data.get("blast_damage",-1) == 0 and projectile.blast_damage == 0 and not births.has(id) and births.size() < 160,"original guardian birth identity/origin1.65/pattern direction/speed12/lifetime4/budget"): return
		births[id] = [weakref(projectile),source.get_instance_id(),tick]
		guardian_birth_ticks[tick] = id
		return
	# Shared actual swept ray/RID/once-only/caller/player armor checks cover both roles.
	incoming_ray = projectile.velocity.normalized()
	super.before_projectile(projectile,event,data)
	incoming_ray = Vector3.ZERO

func before_interact() -> void:
	var spec: Dictionary = game.nearest_interaction()
	require(current() and Engine.is_in_physics_frame() and Input.is_action_pressed("interact") and stack("/player.gd","_physics_process") and spec == IVORY and intent == IVORY.id and inputs.is_empty() and key_events.size() == 1 and key_events[0][0],"only actual queued physical E Ivory interaction")
	inputs.append([spec.get("id",""),Engine.get_physics_frames(),player.position,player.rotation.y,player.camera.rotation.x])

func before_key(id: String) -> void:
	require(current() and id == IVORY.id and keys == ["blood"] and intent == id and stack("/main.gd","interact") and stack("/player.gd","_physics_process") and Engine.is_in_physics_frame() and Input.is_action_pressed("interact") and game.nearest_interaction() == IVORY,"original Ivory through production queued interaction")

func after_key(id: String) -> void:
	keys.append("ivory")
	removed.append(id)
	require(game.state.keys == keys and game.state.removed.count(id) == 1 and not scene.markers.has(id) and game.budget() == ledger,"Ivory marker/key retirement without resource grant")
	for light in ["ossuary_mandala_feed","ossuary_mandala_core"]: require(scene.machine_lights[light].light_color == Color(1.0,0.76,0.44),"earned warmed mandala light")

func all_dead(group: String) -> bool:
	return activated.has(group) and game.enemies.filter(func(node): return node.encounter_id == group).all(func(node): return actor(node) and node.hp == 0 and deaths.get(node.id,0) == 1 and finishes.get(node.id,"") in ["player","infighting"])

func validate() -> bool:
	if not require(current() and game.transport_witness == self and prior_frozen(),"same native identities/live dispatch; every earlier Main/fixture/first-witness stored value frozen"): return false
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
		var capsule: CollisionShape3D = node.get_child(0)
		var role: Array = ROLES[node.kind]
		var binding: Array = bindings[node.id]
		var original: Array = originals[node.id]
		var entry: Array = entry_actors[node.id]
		require(node.is_physics_processing() and capsule.get_instance_id() == binding[1] and capsule.shape.get_instance_id() == binding[2] and not capsule.disabled and capsule.shape is CapsuleShape3D and absf(capsule.shape.radius-role[1]) < 0.000001 and absf(capsule.shape.height-role[2]) < 0.000001 and capsule.position == Vector3(0,capsule.shape.height/2,0) and node.position.is_finite() and is_finite(node.rotation.y) and node.hp == hp[node.id] and node.hp >= 0 and node.max_hp == role[0] and node.kind == original[4] and node.encounter_id == original[5] and node._summon_owner_id.is_empty() and node._summoned_total == entry[6] and node.age-entry[2] >= float(Engine.get_physics_frames()-epoch-2)/60.0,"original native role/capsule/HP/age/processing: "+node.id)
		if entry[3] == 0:
			require(node.hp == 0 and node.position == entry[0] and node.rotation.y == entry[1] and node.active == entry[4] and node.alerted == entry[5] and entry_deaths.get(node.id,0) == 1,"accepted first-loop corpse unchanged: "+node.id)
		elif not activated.has(node.encounter_id): require(node.hp == node.max_hp and node.position == entry[0] and node.rotation.y == entry[1] and not node.active and not node.alerted,"unentered original dormant/fullHP/pose: "+node.id)
		if node.hp > 0:
			var floor_hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(node.position+Vector3.UP*0.5,node.position-Vector3.UP*6,1))
			require(node.collision_layer == 4 and node.collision_mask == 7 and not floor_hit.is_empty() and floor_hit.normal.y >= 0.7 and absf(node.position.y-floor_hit.position.y-(1.0 if node.kind == "caster" else 0.0)) <= (0.25 if node.kind == "caster" else 0.15),"native living actor floor/collision")
		else: require(deaths.get(node.id,0) == 1 and finishes.get(node.id,"") in ["player","infighting"] and node.collision_layer == 0 and node.collision_mask == 0 and game.state.removed.count(node.id) == 1,"all deaths once-only with retained native provenance")
	for id in markers:
		var ref = markers[id].get_ref()
		if id in removed: require(not scene.markers.has(id) and (not is_instance_valid(ref) or ref.is_queued_for_deletion()),"claimed marker retired: "+id)
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
	var gate = gate_ref.get_ref()
	require(is_instance_valid(gate) and scene.doors.get("ossuary_transfer_gate") == gate and gate.transform == gate_transform and gate.collision_layer == 1 and not "ossuary_transfer_gate" in removed,"original transfer gate closed and unmoved")
	require(game.budget() == ledger and game.state.keys == keys and actual_removed == expected_removed and removed.all(func(id): return removed.count(id) == 1) and game.state.explored == explored and game.state.discoveries == [3,4] and game.state.owned_weapons == [0,1,2,3] and game.state.weapon == 1 and game.state.ammo[2] == 32 and game.state.ammo[3] == 120 and game.state.ammo[4] == 0 and game.state.checkpoint_id == "entry" and game.state.checkpoint == checkpoint and game.state.level_start == start and game.state.actors == actor_image and FileAccess.get_sha256(profile) == SAVE_SHA and saved_sha == SAVE_SHA and FileAccess.get_sha256(settings) == settings_sha and saves == 0 and captures == 0 and mouse_attempts == 0 and starts == 0 and restarts == 0 and pending_player.is_empty() and lethal.is_empty() and incoming_ray == Vector3.ZERO,"independent budget/Survey/removals; immutable recovery/disk/preferences; no transfer/finale")
	return ok

func tick() -> bool:
	if not validate(): return false
	await fixture.physics_frame
	return validate()

func fire_input() -> bool:
	Input.action_release("fire")
	if "--omit-ossuary-second-fire" in OS.get_cmdline_user_args() or game.state.weapon != 1 or ledger.ammo[1] <= 0 or shots.size() >= SHOTS: return false
	var selected = null
	var nearest: float = 140.0
	for node in game.enemies:
		if not actor(node) or node.hp <= 0 or not node.active or node.encounter_id not in SECOND_GROUPS: continue
		var aim: Vector3 = node.global_position+node.get_child(0).position
		var distance: float = player.camera.global_position.distance_to(aim)
		if distance >= nearest: continue
		var query = PhysicsRayQueryParameters3D.create(player.camera.global_position,aim,1|4)
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

func route(cells: Array) -> bool:
	# Accepted XZ sample + independent native floor/capsule/sweep per sample.
	for cell in cells:
		var target: Vector3 = scene.layout.world_position(cell)+Vector3.UP*0.04
		var began: int = Engine.get_physics_frames()
		var arrived: bool = false
		for frame in range(LEG):
			if not validate(): return false
			var start_point: Vector3 = player.position
			var clear: bool = fixture.clear_point(cell) != null
			var samples: int = ceili(Vector2(start_point.x-target.x,start_point.z-target.z).length()/0.5)
			for sample in range(samples+1):
				var point: Vector3 = start_point.lerp(target,float(sample)/maxi(1,samples))
				if fixture.clear_point([point.x/4.0,point.z/4.0]) == null: clear = false
				if sample > 0:
					var prior: Vector3 = start_point.lerp(target,float(sample-1)/maxi(1,samples))
					if not fixture.nursery_seed_sweep([prior.x/4.0,prior.z/4.0],[point.x/4.0,point.z/4.0]): clear = false
			fixture.release_actions()
			if not clear:
				if not require(fire_input(),"blocked second-loop leg needs visible active native target: "+str(cell)): return false
			else:
				if Vector2(start_point.x-target.x,start_point.z-target.z).length() <= 0.12:
					arrived = true
					break
				if not fire_input(): player.look_at(Vector3(target.x,player.position.y,target.z),Vector3.UP)
				fixture.nursery_finale_move(target)
			if not await tick(): return false
		if not require(arrived and Engine.get_physics_frames()-began+12 < LEG,"finite900-frame second-loop leg including settle: "+str(cell)): return false
		fixture.release_actions()
		for frame in range(12):
			fire_input()
			if not await tick(): return false
		fixture.release_actions()
		await fixture.process_frame
		if not validate() or not require(player.position.distance_to(target) < 0.2 and fixture.clear_point(cell) != null,"settled actual floor/capsule endpoint"): return false
		waypoints.append(cell.duplicate())
		print("OSSUARY_SECOND_HOP cell=",cell," frames=",Engine.get_physics_frames()-epoch," resources=",ledger)
	return true

func fight(group: String) -> bool:
	if not require(activated.has(group),"fight follows earned region: "+group): return false
	for frame in range(FIGHT):
		if not validate(): return false
		if all_dead(group):
			fixture.release_actions()
			await fixture.process_frame
			return validate()
		fixture.release_actions()
		var ready: bool = fire_input()
		if not ready:
			print("OSSUARY_SECOND_FIRE_REFUSAL group=",group," shots=",shots.size()," ammo=",ledger.ammo[1]," player=",player.position)
			for node in game.enemies:
				if not actor(node) or node.hp <= 0 or node.encounter_id not in SECOND_GROUPS: continue
				var query = PhysicsRayQueryParameters3D.create(player.camera.global_position,node.global_position+node.get_child(0).position,1|4)
				query.exclude = [player.get_rid()]
				var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(query)
				print("OSSUARY_SECOND_BLOCKER id=",node.id," hp=",node.hp," active=",node.active," position=",node.position," hit=",hit.get("collider")," rid=",hit.get("rid"))
		if not require(ready,"finite committed second-loop fight needs visible native target: "+group): return false
		if not await tick(): return false
	fixture.release_actions()
	return require(false,"finite1800-frame second-loop fight cap: "+group)

func physical_key(pressed: bool) -> bool:
	var event = InputEventKey.new()
	event.physical_keycode = KEY_E
	event.keycode = KEY_E
	event.pressed = pressed
	if not require(InputMap.event_is_action(event,"interact"),"actual rebound physical E binding"): return false
	key_events.append([pressed,Engine.get_physics_frames()])
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	return true

func ivory_input() -> bool:
	if not validate(): return false
	fixture.aim_interaction(IVORY.cell)
	intent = IVORY.id
	var omitted: bool = "--omit-ossuary-second-ivory" in OS.get_cmdline_user_args()
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
		if not require(keys == ["blood"] and inputs.is_empty() and key_events.is_empty() and is_instance_valid(markers[IVORY.id].get_ref()) and scene.markers.get(IVORY.id) == markers[IVORY.id].get_ref() and not activated.has(SECOND_GROUPS[1]) and prior_frozen(),"omitted-Ivory control precondition; return never entered"): return false
		print("OSSUARY_SECOND_OMITTED_IVORY_READY key_absent=true marker_live=true return_absent=true prior_frozen=true")
	return require(keys == ["blood","ivory"] and inputs.size() == 1 and inputs[0][0] == IVORY.id and key_events.size() == 2 and not scene.markers.has(IVORY.id) and markers[IVORY.id].get_ref() == null and ["ossuary_mandala_feed","ossuary_mandala_core"].all(func(id): return scene.machine_lights[id].light_color == Color(1.0,0.76,0.44)),IVORY_GUARD)

func run_route() -> bool:
	if not await route(APPROACH) or not await ivory_input(): return false
	if not await route(INDEX_RETURN) or not await fight(SECOND_GROUPS[0]) or not await fight(SECOND_GROUPS[1]) or not await route(CLOSE): return false
	for frame in range(246):
		fixture.release_actions()
		if not await tick(): return false
		await fixture.process_frame
	if not validate(): return false
	var new_ids: Array = scene.layout.data.encounters[1].enemy_ids+scene.layout.data.encounters[3].enemy_ids
	if not require(new_ids.size() == 11 and new_ids.all(func(id): return deaths.get(id,0) == 1 and not entry_deaths.has(id)) and deaths.size() == 22 and activated.keys() == GROUPS+SECOND_GROUPS and SECOND_GROUPS.all(func(id): return all_dead(id)) and game.enemies.filter(func(node): return node.hp > 0).size() == 5 and shots.size() > 0 and shots.size() <= SHOTS and shield_records.size() > 0,"eleven new original deaths;22 cumulative;five dormant finale originals;guardian geometry independently observed"): return false
	if not require(waypoints == APPROACH+INDEX_RETURN+CLOSE and player.position.distance_to(scene.layout.world_position([24.0,24.0])+Vector3.UP*0.04) < 0.2 and game.state.position == player.position and game.state.yaw == game.Enemy.canonical_yaw(player.rotation.y) and game.state.pitch == clampf(player.camera.rotation.x,-1.35,1.35) and SECOND_SUPPLIES.all(func(id): return pickup_attempts.has(id)) and keys == ["blood","ivory"] and game.state.discoveries == [3,4],"full second-loop return and four actual production supply scans;Story lies on first-loop detour"): return false
	if not require(scene.get_children().filter(func(node): return node.get_script() == preload("res://scripts/projectile.gd")).is_empty() and guardian_releases.keys().all(func(tick): return guardian_birth_ticks.has(tick)) and markers.keys().all(func(id): return not id in removed or markers[id].get_ref() == null),"all actual guardian releases/births reconciled;projectiles and collected markers fully drained"): return false
	print("OSSUARY_SECOND_EARNED frames=",Engine.get_physics_frames()-epoch," shots=",shots.size()," new_deaths=",new_ids," provenance=",finishes," resources=",ledger," shield=",shield_records," guardian_births=",guardian_birth_ticks," pickups=",pickups," saved_sha=",saved_sha," prior_frozen=",prior_frozen())
	return true
