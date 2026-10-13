extends "res://tests/test_processional_earned_entry.gd"

const O_LIMIT = 4000
const O_SECONDS = 90
const O_FIGHT_LIMIT = 360
const O_ENTRY_SHA = "8f693113f83d7871c2962da17e79133d798029c106293be8b66e4e0b6fc821df"
const O_PROJECTILE_SHA = "bbda549a1c3d964bea81171dfc44d0395084023e804e3bdb72e22d285f87e873"
const ORGAN = [[13.5,24.5],[10.5,24.5],[7.5,24.5],[4.5,24.5],[3.5,24.5],[3.5,23.0],[3.5,21.5],[3.5,20.5],[3.5,18.5],[3.5,17.5],[2.7,17.5],[3.5,17.5],[6.5,17.5],[9.5,17.5],[9.5,18.5],[9.5,17.5],[6.5,17.5],[3.5,17.5],[3.5,14.5],[3.5,11.5],[4.0,10.5]]
const ORGAN_RETURN = [[7.0,10.5],[9.5,10.5],[12.5,11.5],[12.5,8.5],[16.5,8.5],[14.75,8.5],[14.75,11.5],[14.75,14.5],[16.5,14.5],[16.5,17.5],[16.5,21.0],[16.5,24.5]]
const O_SUPPLIES = ["processional_organ_shells","processional_organ_armor","processional_organ_health","processional_organ_rivets","processional_north_shells","processional_gate_shells"]
const O_PICKUP_SPECS = {"processional_organ_shells":{"id":"processional_organ_shells","kind":"ammo","cell":[3.5,20.5],"amount":14.0,"weapon":2.0},"processional_organ_armor":{"id":"processional_organ_armor","kind":"armor","cell":[2.7,17.5],"amount":60.0},"processional_organ_health":{"id":"processional_organ_health","kind":"health","cell":[9.5,18.5],"amount":30.0},"processional_organ_rivets":{"id":"processional_organ_rivets","kind":"ammo","cell":[9.5,10.5],"amount":50.0,"weapon":1.0},"processional_north_shells":{"id":"processional_north_shells","kind":"ammo","cell":[12.5,8.5],"amount":12.0,"weapon":2.0},"processional_gate_shells":{"id":"processional_gate_shells","kind":"ammo","cell":[15.5,8.5],"amount":12.0,"weapon":2.0}}
const O_BRANCH = ["processional_enemy_03","processional_enemy_04","processional_enemy_05","processional_enemy_06","processional_enemy_07","processional_enemy_08"]

class OrganMain:
	extends "res://tests/test_processional_earned_entry.gd".EntryMain
	var organ_enabled: bool = false
	var o_ok: bool = true
	var o_ticks: int = 0
	var o_ledger: Dictionary = {}
	var o_keys: Array = []
	var o_shots: Array = [0,0,0,0,0,0]
	var o_last: Array = [-1,-1,-1,-1,-1,-1]
	var o_slots: Array = [-1.0,-1.0,-1.0,-1.0,-1.0,-1.0]
	var o_consumed: Dictionary = {}
	var o_rejected: Dictionary = {}
	var o_deaths: Dictionary = {}
	var o_finishes: Dictionary = {}
	var o_attacks: Dictionary = {}
	var o_attack_hits: Dictionary = {}
	var o_births: Dictionary = {}
	var o_contacts: Dictionary = {}
	var o_used: Dictionary = {}
	var o_pending: Dictionary = {}
	var o_projectile_hurts: int = 0
	var o_blood_calls: int = 0
	func _physics_process(delta: float) -> void:
		super._physics_process(delta)
		if organ_enabled and playing and state.level_index == 2 and not get_tree().paused:
			o_ticks += 1
			o_ok = o_ok and absf(delta-1.0/60.0) < 0.000001
			if not Input.is_action_pressed("fire"): o_slots.fill(-1.0)
	func shot(weapon: int) -> void:
		if organ_enabled:
			if weapon not in [1,2]:
				o_ok = false
				super.shot(weapon)
				return
			var tick: int = Engine.get_physics_frames()
			o_slots[weapon] = entry_slot(tick,o_last[weapon],o_slots[weapon],weapon)
			var expected: Dictionary = o_ledger.duplicate(true)
			expected.ammo[weapon] -= 1
			o_ok = o_ok and Engine.is_in_physics_frame() and playing and state.level_index == 2 and player._current_map() and Input.is_action_pressed("fire") and not player._fire_release_required and state.weapon == weapon and weapon in state.owned_weapons and o_slots[weapon] >= 0.0 and player.shot_age(weapon) == 0.0 and player._last_shots[weapon] == player.active_play_time and budget() == expected and expected.ammo[weapon] >= 0
			o_ledger = expected
			o_shots[weapon] += 1
			o_last[weapon] = tick
		super.shot(weapon)
	func collect_pickup(id: String) -> void:
		if not organ_enabled:
			super.collect_pickup(id)
			return
		var matches: Array = level.layout.data.pickups.filter(func(spec): return spec.id == id)
		o_ok = o_ok and Engine.is_in_physics_frame() and playing and player._current_map() and id in ["processional_organ_shells","processional_organ_armor","processional_organ_health","processional_organ_rivets","processional_north_shells","processional_gate_shells"] and matches.size() == 1 and budget() == o_ledger
		if matches.size() != 1:
			super.collect_pickup(id)
			return
		var spec: Dictionary = O_PICKUP_SPECS.get(id,{})
		if matches[0] != spec:
			o_ok = false
			push_error("Independent authored Organ pickup fields reject loaded producer mutation: "+id)
			return
		var expected: Dictionary = o_ledger.duplicate(true)
		var ammo: bool = spec.kind == "ammo"
		var weapon: int = int(spec.get("weapon",1))
		var old: int = int(expected.ammo[weapon]) if ammo else int(expected[spec.kind])
		var cap: int = Player.WEAPONS[weapon].max_ammo if ammo else 100 if spec.kind == "health" else 200
		var consumed: bool = not id in state.removed and old < cap
		var rejected: bool = not id in state.removed and old >= cap
		var marker = level.markers.get(id)
		o_ok = o_ok and spec.kind in ["ammo","health","armor"] and is_instance_valid(marker) and marker.get_parent() == level and not marker.is_queued_for_deletion()
		if consumed:
			if ammo: expected.ammo[weapon] = mini(cap,old+int(spec.amount))
			else: expected[spec.kind] = mini(cap,old+int(spec.amount))
		super.collect_pickup(id)
		o_ok = o_ok and budget() == expected and state.removed.count(id) == (1 if consumed or o_consumed.has(id) else 0)
		if consumed:
			o_consumed[id] = o_consumed.get(id,0)+1
			o_ok = o_ok and o_consumed[id] == 1 and not level.markers.has(id)
		if rejected:
			o_rejected[id] = o_rejected.get(id,0)+1
			o_ok = o_ok and is_instance_valid(marker) and level.markers.get(id) == marker and marker.get_parent() == level and not marker.is_queued_for_deletion()
		o_ledger = expected
	func collect_key(id: String) -> void:
		if organ_enabled:
			o_ok = o_ok and Engine.is_in_physics_frame() and playing and player._current_map() and Input.is_action_pressed("interact") and id == "processional_blood" and o_keys.is_empty() and state.keys == o_keys and not id in state.removed and budget() == o_ledger and get_stack().any(func(frame): return str(frame.get("source","")).ends_with("/main.gd") and frame.get("function","") == "interact")
		super.collect_key(id)
		if organ_enabled:
			o_blood_calls += 1
			o_keys = ["blood"]
			o_ok = o_ok and o_blood_calls == 1 and state.keys == o_keys and state.removed.count(id) == 1 and not level.markers.has(id) and budget() == o_ledger
	func enemy_event(actor, event: String) -> void:
		if organ_enabled:
			o_ok = o_ok and Engine.is_in_physics_frame() and playing and actor._current_map() and actor.active and p_originals.has(actor.id) and actor.get_instance_id() == p_originals.get(actor.id,{}).get("instance",-1) and actor.kind in ["worker","crawler","caster"]
			if event == "attack": o_attacks[actor.id] = Engine.get_physics_frames()
			if event == "death":
				o_deaths[actor.id] = o_deaths.get(actor.id,0)+1
				o_ok = o_ok and actor.hp == 0 and actor.collision_layer == 0 and actor.collision_mask == 0 and state.removed.count(actor.id) == 1 and o_deaths[actor.id] == 1
				o_finishes[actor.id] = state.weapon in [1,2] and Input.is_action_pressed("fire") and o_last[state.weapon] == Engine.get_physics_frames() and player.shot_age() == 0.0 and actor.target == player and aim_observation.get("actor_id","") == actor.id and aim_observation.get("tick",-1) == Engine.get_physics_frames() and aim_observation.get("level") == level and aim_observation.get("player") == player and aim_observation.get("weapon",-1) == state.weapon and get_stack().any(func(frame): return str(frame.get("source","")).ends_with("/player.gd") and frame.get("function","") == "fire")
		super.enemy_event(actor,event)
	func _debug_projectile_event(projectile: Node3D, event: String, data: Dictionary) -> void:
		if not organ_enabled: return
		if event == "queued_enemy_contact": return
		var common: bool = OS.is_debug_build() and Engine.is_in_physics_frame() and playing and state.level_index == 2 and not get_tree().paused and projectile.get_script() == preload("res://scripts/projectile.gd") and projectile.game == self and projectile._current_map() and projectile.is_physics_processing() and data.get("projectile") == projectile and data.get("map") == level and data.get("player") == player and is_instance_valid(player) and player._current_map() and data.get("tick",-1) == Engine.get_physics_frames() and data.get("source") == projectile.shooter and is_instance_valid(projectile.shooter) and projectile.shooter.get_script() == Enemy
		if not common:
			o_ok = false
			return
		if not (data.get("position") is Vector3 and data.get("velocity") is Vector3 and (data.get("lifetime") is float or data.get("lifetime") is int)):
			o_ok = false
			return
		var source = projectile.shooter
		var id: int = projectile.get_instance_id()
		o_ok = o_ok and source.id == "processional_enemy_07" and source.kind == "caster" and p_originals.has(source.id) and source.get_instance_id() == p_originals[source.id].instance and source._current_map() and not source.is_queued_for_deletion() and data.get("position") == projectile.global_position and data.get("velocity") == projectile.velocity and data.get("lifetime") == projectile.lifetime and data.get("blast_damage") == 0 and projectile.blast_damage == 0 and projectile.velocity.is_finite() and is_equal_approx(projectile.velocity.length(),12.0) and projectile.lifetime > 0 and projectile.lifetime <= 4.0
		if event == "configured_birth":
			o_ok = o_ok and not o_births.has(id) and not projectile.is_queued_for_deletion() and source.active and source.hp > 0 and o_attacks.get(source.id,-1) == Engine.get_physics_frames() and data.get("origin") is Vector3 and data.get("destination") is Vector3 and data.get("origin") == projectile.global_position and data.origin.is_finite() and data.destination.is_finite() and projectile.lifetime == 4.0 and projectile.get_child_count() == 2 and projectile.get_child(0) is MeshInstance3D and projectile.get_child(1) is OmniLight3D and projectile.velocity.is_equal_approx((data.destination-data.origin).normalized()*12.0) and get_stack().any(func(frame): return str(frame.get("source","")).ends_with("/enemy.gd") and frame.get("function","") == "_release_attack")
			o_births[id] = {"data":data.duplicate(true),"reference":weakref(projectile)}
			return
		if event != "queued_player_contact" or not o_births.has(id) or o_contacts.has(id) or o_used.has(id) or not o_pending.is_empty():
			o_ok = false
			return
		var birth: Dictionary = o_births[id].data
		for field in ["projectile","source","map","player"]:
			o_ok = o_ok and data.get(field) == birth.get(field)
		if not (data.get("hit") is Dictionary and data.get("ray_start") is Vector3 and data.get("ray_end") is Vector3):
			o_ok = false
			return
		var hit: Dictionary = data.hit
		o_ok = o_ok and projectile.is_queued_for_deletion() and data.tick >= birth.tick and data.tick-birth.tick <= 241 and data.ray_start.is_finite() and data.ray_end.is_finite() and hit.get("collider") == player and hit.get("position") is Vector3 and hit.get("normal") is Vector3 and hit.position.is_finite() and hit.normal.is_finite() and hit.get("rid") == player.get_rid() and projectile.global_position == hit.get("position") and data.ray_end.is_equal_approx(data.ray_start+projectile.velocity*minf(1.0/60.0,projectile.lifetime)) and get_stack().any(func(frame): return str(frame.get("source","")).ends_with("/projectile.gd") and frame.get("function","") == "_physics_process")
		if not o_ok: return
		# This repeats only the real reported native sweep; never guesses from queued objects.
		var query = PhysicsRayQueryParameters3D.create(data.ray_start,data.ray_end,1|2|4)
		query.exclude = [source.get_rid()]
		query.hit_from_inside = true
		var native_hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(query)
		o_ok = o_ok and not native_hit.is_empty() and native_hit == hit
		o_contacts[id] = data.duplicate(true)
		o_pending = {"id":id,"data":data.duplicate(true)}
	func hurt_player(amount: int) -> void:
		if not organ_enabled:
			super.hurt_player(amount)
			return
		var attributed: bool = false
		if amount == 14 and not o_pending.is_empty():
			var id: int = o_pending.id
			var data: Dictionary = o_pending.data
			var projectile = data.projectile
			attributed = o_births.has(id) and o_contacts.has(id) and not o_used.has(id) and data.tick == Engine.get_physics_frames() and is_instance_valid(projectile) and projectile.get_instance_id() == id and projectile.is_queued_for_deletion() and projectile._current_map() and data.map == level and data.player == player and data.source == projectile.shooter and data.source._current_map() and not data.source.is_queued_for_deletion() and data.hit.collider == player and get_stack().any(func(frame): return str(frame.get("source","")).ends_with("/projectile.gd") and frame.get("function","") == "_physics_process")
			if attributed:
				o_used[id] = true
				o_projectile_hurts += 1
			o_pending.clear()
		elif o_pending.is_empty() and amount in [10,12]:
			for actor in enemies:
				var tick: int = int(o_attacks.get(actor.id,-1000))
				var age: int = Engine.get_physics_frames()-tick
				var key: String = actor.id+":"+str(tick)
				if p_originals.has(actor.id) and actor.get_instance_id() == p_originals[actor.id].instance and actor._current_map() and actor.active and actor.hp > 0 and actor._committed_target == player and not o_attack_hits.has(key) and age >= 0 and ((actor.kind == "worker" and amount == 10 and age == 0) or (actor.kind == "crawler" and amount == 12 and age <= 12)):
					attributed = get_stack().any(func(frame): return str(frame.get("source","")).ends_with("/enemy.gd") and frame.get("function","") == "_attack")
					if attributed: o_attack_hits[key] = true
					break
		o_ok = o_ok and attributed and Engine.is_in_physics_frame() and playing and state.difficulty == 1 and player._current_map() and budget() == o_ledger
		var expected: Dictionary = o_ledger.duplicate(true)
		var absorbed: int = mini(int(expected.armor),int(amount/3))
		expected.armor -= absorbed
		expected.health = maxi(0,int(expected.health)-(amount-absorbed))
		super.hurt_player(amount)
		o_ok = o_ok and budget() == expected
		o_ledger = expected

var organ_started: bool = false
var o_epoch: int = 0
var o_wall_us: int = 0
var o_main_id: int = 0
var o_profile: String = ""
var o_start_shots: int = 0
var o_start_removed: Array = []
var o_ages: Dictionary = {}
var o_markers: Dictionary = {}

func run() -> void:
	prefix = "user://processional_earned_organ_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	if not await walk_to_organ_loop(OrganMain.new(),prefix):
		await finish(1)
		return
	print("PASS source-debug candidate earned first Organ loop/blood/return only. Actual virtual Input, native original actors and exact debug projectile pairing; not physical input, full Processional/campaign, audio/GPU/performance or packed-app attribution.")
	await finish(0)

func walk_to_organ_loop(observer, profile_prefix: String) -> bool:
	prefix = profile_prefix
	if not await walk_to_processional_entry(observer,prefix) or not await start_organ():
		return false
	if not await organ_route([[16.5,24.5]]) or not await organ_route(ORGAN) or not await organ_fight(O_BRANCH) or not await organ_blood() or not await organ_route(ORGAN_RETURN) or not await organ_result():
		return false
	return true

func start_organ() -> bool:
	var earned: Dictionary = {"health":86,"armor":80,"ammo":[0,180,13,0,0,0],"owned_weapons":[0,1,2],"weapon":2}
	if not expect(OS.is_debug_build() and FileAccess.get_sha256("res://tests/test_processional_earned_entry.gd") == O_ENTRY_SHA and FileAccess.get_sha256("res://scripts/projectile.gd") == O_PROJECTILE_SHA and game.budget() == earned and game.p_ok and game.p_deaths.size() == 2 and game.enemies.size() == 26 and game.state.keys.is_empty(),"Accepted unchanged earned entry and exact debug observer dependency precede Organ handoff"): return false
	o_main_id = game.get_instance_id()
	o_profile = game.progress_path
	o_epoch = Engine.get_physics_frames()
	o_wall_us = Time.get_ticks_usec()
	o_start_removed = game.state.removed.duplicate()
	for actor in game.enemies: o_ages[actor.id] = actor.age
	for id in O_SUPPLIES+["processional_blood"]:
		if not expect(route_level.markers.has(id),"Original first-loop marker retained: "+id): return false
		o_markers[id] = weakref(route_level.markers[id])
	release_actions()
	game.entry_enabled = false
	# Normal Player weapon_2 selection; fail if any resource changes during these two native waits.
	action_input("weapon_2",true)
	await physics_frame
	await physics_frame
	action_input("weapon_2",false)
	earned.weapon = 1
	if not expect(game.budget() == earned and game.state.keys.is_empty(),"Actual weapon_2 Input selects existing pistol without resources or ownership changes"): return false
	game.o_ledger = earned.duplicate(true)
	game.o_deaths = game.p_deaths.duplicate(true)
	o_start_shots = game.shots
	game.organ_enabled = true
	organ_started = true
	return live_route()

func east_elapsed() -> int:
	return Engine.get_physics_frames()-o_epoch if organ_started else super.east_elapsed()

func route_tick() -> bool:
	if not organ_started: return await super.route_tick()
	if not live_route(): return false
	await physics_frame
	return live_route()

func east_fire() -> bool:
	if not organ_started: return super.east_fire()
	Input.action_release("fire")
	game.west_firing_id = ""
	if game.state.weapon != 1: return false
	var selected = null
	var nearest: float = WeaponPlayer.WEAPONS[1].range
	for actor in game.enemies:
		if not is_instance_valid(actor) or not actor._current_map() or not actor.active or actor.hp <= 0: continue
		var point: Vector3 = actor.global_position+actor.get_child(0).position
		var distance: float = route_player.camera.global_position.distance_to(point)
		if distance >= nearest: continue
		var query = PhysicsRayQueryParameters3D.create(route_player.camera.global_position,point,1|4)
		query.exclude = [route_player.get_rid()]
		var hit = route_level.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider == actor:
			selected = actor
			nearest = distance
	if selected == null: return false
	var aim: Vector3 = selected.global_position+selected.get_child(0).position
	var heading: Vector3 = aim-route_player.camera.global_position
	route_player.rotation.y = atan2(-heading.x,-heading.z)
	route_player.camera.look_at(aim,Vector3.UP)
	game.west_firing_id = selected.id
	Input.action_press("fire")
	return true

func organ_route(cells: Array) -> bool:
	print("ORGAN_BLOCK cells=",cells," frames=",east_elapsed()," resources=",game.o_ledger)
	for cell in cells:
		var start: int = east_elapsed()
		if not await east_route([cell]) or not expect(east_elapsed()-start <= HOP_LIMIT,"Frozen 240-frame Organ hop includes process wait: "+str(cell)+" position="+str(route_player.position)): return false
	return true

func organ_fight(ids: Array) -> bool:
	for frame in range(O_FIGHT_LIMIT):
		if not live_route(): return false
		if game.enemies.filter(func(actor): return actor.id in ids).all(func(actor): return actor.hp == 0): break
		release_actions()
		east_fire()
		if not await route_tick(): return false
	release_actions()
	return expect(game.enemies.filter(func(actor): return actor.id in ids).all(func(actor): return actor.hp == 0),"NATIVE RED first-loop originals need real LOS/fire within 360-frame fight; position="+str(route_player.position)+" ledger="+str(game.o_ledger))

func organ_blood() -> bool:
	if not expect(game.o_deaths.get("processional_enemy_07",0) == 1 and game.o_finishes.get("processional_enemy_07",false) and game.state.keys.is_empty(),"Natural input-fired original caster07 finish precedes first seal"): return false
	aim_interaction([3.5,10.5])
	interaction_input(true)
	if not await route_tick(): return false
	# physics_frame resumes before Main consumes the buffered press; hold through its callback.
	await process_frame
	if not live_route(): return false
	interaction_input(false)
	if not await route_tick(): return false
	release_actions()
	await process_frame
	return expect(game.o_blood_calls == 1 and game.state.keys == ["blood"] and game.state.removed.count("processional_blood") == 1 and o_markers.processional_blood.get_ref() == null,"Actual interact earns and drains only the original blood seal")

func live_route() -> bool:
	if not organ_started: return super.live_route()
	if not expect(east_elapsed() <= O_LIMIT and Time.get_ticks_usec()-o_wall_us <= O_SECONDS*1000000,"NATIVE RED frozen Organ 4000-native-frame/90-second epoch; no deadline inflation"): return false
	if not expect(not paused and game.playing and not game.placement_pending and game.state.level_index == 2 and game.get_instance_id() == o_main_id and game.progress_path == o_profile and is_instance_valid(route_level) and is_instance_valid(route_player) and game.level == route_level and game.player == route_player and route_player._current_map() and not route_level.is_queued_for_deletion() and game.is_processing() and game.is_physics_processing() and route_player.is_physics_processing() and game.enemies.size() == 26,"Same live Main/profile/map/player and 26 automatic originals throughout first loop"): return false
	var seen: Dictionary = {}
	for actor in game.enemies:
		if not expect(is_instance_valid(actor) and game.p_originals.has(actor.id) and not seen.has(actor.id),"Retain each distinct original Organ actor"): return false
		var pin: Dictionary = game.p_originals[actor.id]
		if not expect(actor.get_instance_id() == pin.instance and actor.kind == pin.kind and actor.max_hp == pin.max_hp and actor.hp >= 0 and actor.hp <= pin.max_hp and actor._current_map() and actor.is_physics_processing() and actor.age-o_ages[actor.id] >= float(east_elapsed()-2)/60.0,"Original actor identity/role/health/native age: "+actor.id): return false
		seen[actor.id] = true
		if actor.hp == 0:
			if not expect(game.o_deaths.get(actor.id,0) == 1 and game.state.removed.count(actor.id) == 1 and actor.collision_layer == 0 and actor.collision_mask == 0,"Each original death retires collision/removal once"): return false
		elif not expect(actor.collision_layer == 4 and actor.collision_mask == 7,"Living original retains collision"): return false
		if actor.kind == "caster" and actor.id != "processional_enemy_07" and not expect(not actor.active and actor.hp == pin.max_hp,"Other three casters remain dormant without ivory or east branch"): return false
	var recovery_expected: Dictionary = {"health":93,"armor":89,"ammo":[0,164,0,0,0,0],"owned_weapons":[0,1],"weapon":1,"keys":[]}
	for recovery in [game.state.checkpoint,game.state.level_start]:
		for field in recovery_expected:
			if not expect(recovery.get(field) == recovery_expected[field],"Independent earned level-entry recovery field cannot stale together: "+field): return false
	for node in route_level.get_children():
		if node.get_script() == preload("res://scripts/projectile.gd") and not expect(game.o_births.has(node.get_instance_id()),"Every actual first-loop projectile must have its own admitted birth"): return false
	for id in game.state.removed:
		if not expect(id in o_start_removed or game.o_consumed.has(id) or game.o_deaths.has(id) or (id == "processional_blood" and game.o_blood_calls == 1) or id in ["encounter:processional_organ_answer","encounter:processional_organ_return"],"No unrelated seal/story/checkpoint/gate/exit grant: "+id): return false
	return expect(seen.size() == 26 and game.o_ok and game.rate_ok and game.feedback_ok and game.shot_clock_ok and game.o_ticks >= east_elapsed()-2 and game.shots-o_start_shots == game.o_shots[1]+game.o_shots[2] and game.budget() == game.o_ledger and game.state.health > 0 and game.state.health <= 100 and game.state.armor >= 0 and game.state.armor <= 200 and game.state.ammo[1] >= 0 and game.state.ammo[1] <= 180 and game.state.ammo[2] >= 0 and game.state.ammo[2] <= 32 and game.state.ammo.slice(3) == [0,0,0] and game.state.ammo[0] == 0 and game.state.owned_weapons == [0,1,2] and game.state.weapon == 1 and game.state.keys == game.o_keys and game.state.discoveries.is_empty() and game.state.checkpoint_id == "entry" and game.state.checkpoint == p_recovery and game.state.level_start == p_start and game.o_pending.is_empty(),"Exact independent Organ callback/cadence/cap/keys ledger and unchanged independently grounded entry envelopes")

func organ_result() -> bool:
	release_actions()
	await process_frame
	if not live_route(): return false
	if not expect(route_player.position.distance_to(route_level.layout.world_position([16.5,24.5])+Vector3.UP*0.04) < 0.2 and game.o_finishes.get("processional_enemy_07",false) and game.o_deaths.get("processional_enemy_07",0) == 1 and game.state.keys == ["blood"] and game.state.removed.count("encounter:processional_organ_answer") == 1 and game.state.removed.count("encounter:processional_organ_return") == 1,"First authored Organ loop returns to junction with natural caster finish and input-earned blood"): return false
	for id in game.o_consumed:
		if not expect(game.o_consumed[id] == 1 and o_markers[id].get_ref() == null,"Consumed original supply drains once: "+id): return false
	for id in O_SUPPLIES:
		if not expect(game.o_consumed.has(id) or game.o_rejected.has(id),"First-loop original supply must receive actual native proximity callback: "+id): return false
	for id in game.o_rejected:
		if not game.o_consumed.has(id):
			var original = o_markers[id].get_ref()
			if not expect(is_instance_valid(original) and route_level.markers.get(id) == original and original.get_parent() == route_level and not original.is_queued_for_deletion() and not id in game.state.removed,"Rejected unconsumed original marker survives through completion: "+id): return false
	if not expect(not game.o_births.is_empty(),"First Organ loop must witness at least one validated actual caster birth"): return false
	for id in game.o_births:
		if not expect(game.o_births[id].reference.get_ref() == null,"All actual caster07 projectiles naturally drain before loop completion"): return false
	if not expect(game.o_used.size() == game.o_contacts.size() and game.o_projectile_hurts == game.o_used.size(),"Every actual queued player contact receives exactly one matched real hurt; zero received hits is explicit, never forced"): return false
	print("PROCESSIONAL_ORGAN native_frames=",east_elapsed()," shots=",game.o_shots," consumed=",game.o_consumed," rejected=",game.o_rejected," caster_births=",game.o_births.size()," actual_caster_hurts=",game.o_projectile_hurts," deaths=",game.o_deaths," resources=",game.o_ledger)
	return true
