extends "res://tests/test_processional_earned_organ.gd"

const L_LIMIT = 4500
const L_SECONDS = 100
const L_FIGHT_LIMIT = 360
const L_ORGAN_SHA = "589fbd4282c4553d4e7c0c078f0c7637a7f37d9afb71a4c2d6545ce74d2c5ba8"
const L_SUPPLIES = ["processional_palanquin_armor","processional_palanquin_health","processional_palanquin_shells","processional_palanquin_rivets","processional_return_health"]
const L_PICKUP_SPECS = {"processional_palanquin_armor":{"id":"processional_palanquin_armor","kind":"armor","cell":[30.5,15.5],"amount":60.0},"processional_palanquin_health":{"id":"processional_palanquin_health","kind":"health","cell":[23.5,10.5],"amount":30.0},"processional_palanquin_shells":{"id":"processional_palanquin_shells","kind":"ammo","cell":[29.5,20.5],"amount":16.0,"weapon":2.0},"processional_palanquin_rivets":{"id":"processional_palanquin_rivets","kind":"ammo","cell":[28.6,21.5],"amount":50.0,"weapon":1.0},"processional_return_health":{"id":"processional_return_health","kind":"health","cell":[24.5,24.5],"amount":25.0}}
const L_ACTOR_SPECS = [{"id":"processional_enemy_00","kind":"worker","cell":[15.5,20.65],"yaw":20.0},{"id":"processional_enemy_01","kind":"crawler","cell":[17.5,18.5],"yaw":87.0},{"id":"processional_enemy_02","kind":"crawler","cell":[12.25,8.5],"yaw":154.0},{"id":"processional_enemy_03","kind":"worker","cell":[6.5,23.5],"yaw":221.0},{"id":"processional_enemy_04","kind":"crawler","cell":[3.5,20.5],"yaw":288.0},{"id":"processional_enemy_05","kind":"worker","cell":[3.5,16.5],"yaw":355.0},{"id":"processional_enemy_06","kind":"crawler","cell":[4.5,11.5],"yaw":62.0},{"id":"processional_enemy_07","kind":"caster","cell":[9.5,15.5],"yaw":129.0},{"id":"processional_enemy_08","kind":"worker","cell":[10.5,11.5],"yaw":196.0},{"id":"processional_enemy_09","kind":"crawler","cell":[13.5,9.25],"yaw":263.0},{"id":"processional_enemy_10","kind":"worker","cell":[17.5,10.5],"yaw":330.0},{"id":"processional_enemy_11","kind":"caster","cell":[16.5,12.5],"yaw":37.0},{"id":"processional_enemy_12","kind":"crawler","cell":[15.5,12.5],"yaw":104.0},{"id":"processional_enemy_13","kind":"worker","cell":[25.5,24.5],"yaw":171.0},{"id":"processional_enemy_14","kind":"crawler","cell":[29.5,21.5],"yaw":238.0},{"id":"processional_enemy_15","kind":"worker","cell":[30.5,17.5],"yaw":305.0},{"id":"processional_enemy_16","kind":"crawler","cell":[29.5,14.5],"yaw":12.0},{"id":"processional_enemy_17","kind":"caster","cell":[24.5,12.5],"yaw":79.0},{"id":"processional_enemy_18","kind":"worker","cell":[30.0,10.5],"yaw":146.0},{"id":"processional_enemy_19","kind":"crawler","cell":[25.5,9.5],"yaw":213.0},{"id":"processional_enemy_20","kind":"caster","cell":[27.5,15.5],"yaw":280.0},{"id":"processional_enemy_21","kind":"worker","cell":[22.5,8.5],"yaw":347.0},{"id":"processional_enemy_22","kind":"crawler","cell":[20.5,8.5],"yaw":54.0},{"id":"processional_enemy_23","kind":"worker","cell":[15.5,2.5],"yaw":121.0},{"id":"processional_enemy_24","kind":"crawler","cell":[16.5,5.5],"yaw":188.0},{"id":"processional_enemy_25","kind":"worker","cell":[16.5,7.5],"yaw":255.0}]
const L_ACTORS = {"processional_enemy_00":{"id":"processional_enemy_00","kind":"worker","cell":[15.5,20.65],"yaw":20.0},"processional_enemy_01":{"id":"processional_enemy_01","kind":"crawler","cell":[17.5,18.5],"yaw":87.0},"processional_enemy_02":{"id":"processional_enemy_02","kind":"crawler","cell":[12.25,8.5],"yaw":154.0},"processional_enemy_03":{"id":"processional_enemy_03","kind":"worker","cell":[6.5,23.5],"yaw":221.0},"processional_enemy_04":{"id":"processional_enemy_04","kind":"crawler","cell":[3.5,20.5],"yaw":288.0},"processional_enemy_05":{"id":"processional_enemy_05","kind":"worker","cell":[3.5,16.5],"yaw":355.0},"processional_enemy_06":{"id":"processional_enemy_06","kind":"crawler","cell":[4.5,11.5],"yaw":62.0},"processional_enemy_07":{"id":"processional_enemy_07","kind":"caster","cell":[9.5,15.5],"yaw":129.0},"processional_enemy_08":{"id":"processional_enemy_08","kind":"worker","cell":[10.5,11.5],"yaw":196.0},"processional_enemy_09":{"id":"processional_enemy_09","kind":"crawler","cell":[13.5,9.25],"yaw":263.0},"processional_enemy_10":{"id":"processional_enemy_10","kind":"worker","cell":[17.5,10.5],"yaw":330.0},"processional_enemy_11":{"id":"processional_enemy_11","kind":"caster","cell":[16.5,12.5],"yaw":37.0},"processional_enemy_12":{"id":"processional_enemy_12","kind":"crawler","cell":[15.5,12.5],"yaw":104.0},"processional_enemy_13":{"id":"processional_enemy_13","kind":"worker","cell":[25.5,24.5],"yaw":171.0},"processional_enemy_14":{"id":"processional_enemy_14","kind":"crawler","cell":[29.5,21.5],"yaw":238.0},"processional_enemy_15":{"id":"processional_enemy_15","kind":"worker","cell":[30.5,17.5],"yaw":305.0},"processional_enemy_16":{"id":"processional_enemy_16","kind":"crawler","cell":[29.5,14.5],"yaw":12.0},"processional_enemy_17":{"id":"processional_enemy_17","kind":"caster","cell":[24.5,12.5],"yaw":79.0},"processional_enemy_18":{"id":"processional_enemy_18","kind":"worker","cell":[30.0,10.5],"yaw":146.0},"processional_enemy_19":{"id":"processional_enemy_19","kind":"crawler","cell":[25.5,9.5],"yaw":213.0},"processional_enemy_20":{"id":"processional_enemy_20","kind":"caster","cell":[27.5,15.5],"yaw":280.0},"processional_enemy_21":{"id":"processional_enemy_21","kind":"worker","cell":[22.5,8.5],"yaw":347.0},"processional_enemy_22":{"id":"processional_enemy_22","kind":"crawler","cell":[20.5,8.5],"yaw":54.0},"processional_enemy_23":{"id":"processional_enemy_23","kind":"worker","cell":[15.5,2.5],"yaw":121.0},"processional_enemy_24":{"id":"processional_enemy_24","kind":"crawler","cell":[16.5,5.5],"yaw":188.0},"processional_enemy_25":{"id":"processional_enemy_25","kind":"worker","cell":[16.5,7.5],"yaw":255.0}}
const L_IVORY = {"id":"processional_ivory","kind":"key","key":"ivory","cell":[30.5,9.5],"text":"PALANQUIN IVORY SEAL RECOVERED"}
const PALANQUIN = [[20.0,24.5],[24.5,24.5],[28.5,24.5],[29.5,23.0],[28.6,21.5],[29.5,20.5],[29.5,17.5],[30.5,15.5],[30.5,12.5],[29.5,12.5],[29.5,10.5],[30.0,9.5]]
# Stay 8m east of the automatic checkpoint; actual nave encounter remains legitimate.
const PALANQUIN_RETURN = [[27.5,9.5],[24.5,9.5],[23.5,10.5],[23.5,8.5],[20.5,8.5],[18.5,8.5],[18.5,11.5],[18.5,14.5],[16.5,14.5],[16.5,17.5],[16.5,21.0],[16.5,24.5]]
const L_BRANCH = ["processional_enemy_13","processional_enemy_14","processional_enemy_15","processional_enemy_16","processional_enemy_17","processional_enemy_18","processional_enemy_19","processional_enemy_20"]

class PalanquinMain:
	extends "res://tests/test_processional_earned_organ.gd".OrganMain
	var palanquin_enabled: bool = false
	var l_ok: bool = true
	var l_ticks: int = 0
	var l_ledger: Dictionary = {}
	var l_keys: Array = ["blood"]
	var l_shots: Array = [0,0,0,0,0,0]
	var l_last: Array = [-1,-1,-1,-1,-1,-1]
	var l_slots: Array = [-1.0,-1.0,-1.0,-1.0,-1.0,-1.0]
	var l_consumed: Dictionary = {}
	var l_rejected: Dictionary = {}
	var l_deaths: Dictionary = {}
	var l_finishes: Dictionary = {}
	var l_attacks: Dictionary = {}
	var l_attack_hits: Dictionary = {}
	var l_births: Dictionary = {}
	var l_contacts: Dictionary = {}
	var l_used: Dictionary = {}
	var l_pending: Dictionary = {}
	var l_projectile_hurts: int = 0
	var l_ivory_calls: int = 0
	static func palanquin_slot(tick: int, last: int, nominal: float, weapon: int) -> float:
		if weapon not in [1,2]: return -1.0
		var interval: float = 12.6 if weapon == 1 else 42.0
		if last >= 0 and (tick <= last or float(tick)+0.000001 < (nominal if nominal >= 0.0 else float(last)+interval)): return -1.0
		var result: float = float(tick)+interval if nominal < 0.0 else nominal+interval
		if result <= float(tick)+0.000001: result += (floorf((float(tick)+0.000001-result)/interval)+1.0)*interval
		return result
	func _physics_process(delta: float) -> void:
		super._physics_process(delta)
		if palanquin_enabled and playing and state.level_index == 2 and not get_tree().paused:
			l_ticks += 1
			l_ok = l_ok and absf(delta-1.0/60.0) < 0.000001
			if not Input.is_action_pressed("fire"): l_slots.fill(-1.0)
	func shot(weapon: int) -> void:
		if palanquin_enabled:
			if weapon not in [1,2]:
				l_ok = false
				super.shot(weapon)
				return
			var tick: int = Engine.get_physics_frames()
			l_slots[weapon] = palanquin_slot(tick,l_last[weapon],l_slots[weapon],weapon)
			var expected: Dictionary = l_ledger.duplicate(true)
			expected.ammo[weapon] -= 1
			l_ok = l_ok and Engine.is_in_physics_frame() and playing and state.level_index == 2 and player._current_map() and Input.is_action_pressed("fire") and not player._fire_release_required and state.weapon == weapon and weapon in state.owned_weapons and l_slots[weapon] >= 0.0 and player.shot_age(weapon) == 0.0 and player._last_shots[weapon] == player.active_play_time and budget() == expected and expected.ammo[weapon] >= 0
			l_ledger = expected
			l_shots[weapon] += 1
			l_last[weapon] = tick
		super.shot(weapon)
	func collect_pickup(id: String) -> void:
		if not palanquin_enabled:
			super.collect_pickup(id)
			return
		var matches: Array = level.layout.data.pickups.filter(func(spec): return spec.id == id)
		l_ok = l_ok and Engine.is_in_physics_frame() and playing and player._current_map() and id in ["processional_palanquin_armor","processional_palanquin_health","processional_palanquin_shells","processional_palanquin_rivets","processional_return_health"] and matches.size() == 1 and budget() == l_ledger
		if matches.size() != 1:
			super.collect_pickup(id)
			return
		var spec: Dictionary = L_PICKUP_SPECS.get(id,{})
		if matches[0] != spec:
			l_ok = false
			push_error("Independent authored Organ pickup fields reject loaded producer mutation: "+id)
			return
		var expected: Dictionary = l_ledger.duplicate(true)
		var ammo: bool = spec.kind == "ammo"
		var weapon: int = int(spec.get("weapon",1))
		var old: int = int(expected.ammo[weapon]) if ammo else int(expected[spec.kind])
		var cap: int = (180 if weapon == 1 else 32) if ammo else 100 if spec.kind == "health" else 200
		var consumed: bool = not id in state.removed and old < cap
		var rejected: bool = not id in state.removed and old >= cap
		var marker = level.markers.get(id)
		l_ok = l_ok and spec.kind in ["ammo","health","armor"] and is_instance_valid(marker) and marker.get_parent() == level and not marker.is_queued_for_deletion()
		if consumed:
			if ammo: expected.ammo[weapon] = mini(cap,old+int(spec.amount))
			else: expected[spec.kind] = mini(cap,old+int(spec.amount))
		super.collect_pickup(id)
		l_ok = l_ok and budget() == expected and state.removed.count(id) == (1 if consumed or l_consumed.has(id) else 0)
		if consumed:
			l_consumed[id] = l_consumed.get(id,0)+1
			l_ok = l_ok and l_consumed[id] == 1 and not level.markers.has(id)
		if rejected:
			l_rejected[id] = l_rejected.get(id,0)+1
			l_ok = l_ok and is_instance_valid(marker) and level.markers.get(id) == marker and marker.get_parent() == level and not marker.is_queued_for_deletion()
		l_ledger = expected
	func collect_key(id: String) -> void:
		if palanquin_enabled:
			var matches: Array = level.layout.data.interactions.filter(func(spec): return spec.id == id)
			if matches.size() != 1 or matches[0] != L_IVORY:
				l_ok = false
				return
			l_ok = l_ok and Engine.is_in_physics_frame() and playing and player._current_map() and Input.is_action_pressed("interact") and id == "processional_ivory" and l_keys == ["blood"] and state.keys == l_keys and not id in state.removed and budget() == l_ledger and get_stack().any(func(frame): return str(frame.get("source","")).ends_with("/main.gd") and frame.get("function","") == "interact")
		super.collect_key(id)
		if palanquin_enabled:
			l_ivory_calls += 1
			l_keys = ["blood","ivory"]
			l_ok = l_ok and l_ivory_calls == 1 and state.keys == l_keys and state.removed.count(id) == 1 and not level.markers.has(id) and budget() == l_ledger
	func enemy_event(actor, event: String) -> void:
		if palanquin_enabled:
			l_ok = l_ok and Engine.is_in_physics_frame() and playing and actor._current_map() and actor.active and p_originals.has(actor.id) and actor.get_instance_id() == p_originals.get(actor.id,{}).get("instance",-1) and actor.kind in ["worker","crawler","caster"]
			if event == "attack": l_attacks[actor.id] = Engine.get_physics_frames()
			if event == "death":
				l_deaths[actor.id] = l_deaths.get(actor.id,0)+1
				l_ok = l_ok and actor.hp == 0 and actor.collision_layer == 0 and actor.collision_mask == 0 and state.removed.count(actor.id) == 1 and l_deaths[actor.id] == 1
				l_finishes[actor.id] = state.weapon in [1,2] and Input.is_action_pressed("fire") and l_last[state.weapon] == Engine.get_physics_frames() and player.shot_age() == 0.0 and actor.target == player and aim_observation.get("actor_id","") == actor.id and aim_observation.get("tick",-1) == Engine.get_physics_frames() and aim_observation.get("level") == level and aim_observation.get("player") == player and aim_observation.get("weapon",-1) == state.weapon and get_stack().any(func(frame): return str(frame.get("source","")).ends_with("/player.gd") and frame.get("function","") == "fire")
		super.enemy_event(actor,event)
	func _debug_projectile_event(projectile: Node3D, event: String, data: Dictionary) -> void:
		if not palanquin_enabled:
			super._debug_projectile_event(projectile,event,data)
			return
		var common: bool = OS.is_debug_build() and Engine.is_in_physics_frame() and playing and state.level_index == 2 and not get_tree().paused and projectile.get_script() == preload("res://scripts/projectile.gd") and projectile.game == self and projectile._current_map() and projectile.is_physics_processing() and data.get("projectile") == projectile and data.get("map") == level and data.get("player") == player and is_instance_valid(player) and player._current_map() and data.get("tick",-1) == Engine.get_physics_frames() and data.get("source") == projectile.shooter and is_instance_valid(projectile.shooter) and projectile.shooter.get_script() == Enemy
		if not common:
			l_ok = false
			return
		if not (data.get("position") is Vector3 and data.get("velocity") is Vector3 and (data.get("lifetime") is float or data.get("lifetime") is int)):
			l_ok = false
			return
		var source = projectile.shooter
		var id: int = projectile.get_instance_id()
		l_ok = l_ok and source.id in ["processional_enemy_17","processional_enemy_20","processional_enemy_11"] and source.kind == "caster" and p_originals.has(source.id) and source.get_instance_id() == p_originals[source.id].instance and source._current_map() and not source.is_queued_for_deletion() and data.get("position") == projectile.global_position and data.get("velocity") == projectile.velocity and data.get("lifetime") == projectile.lifetime and data.get("blast_damage") == 0 and projectile.blast_damage == 0 and projectile.velocity.is_finite() and is_equal_approx(projectile.velocity.length(),12.0) and projectile.lifetime > 0 and projectile.lifetime <= 4.0
		if event == "configured_birth":
			l_ok = l_ok and not l_births.has(id) and not projectile.is_queued_for_deletion() and source.active and source.hp > 0 and l_attacks.get(source.id,-1) == Engine.get_physics_frames() and data.get("origin") is Vector3 and data.get("destination") is Vector3 and data.get("origin") == projectile.global_position and data.origin.is_finite() and data.destination.is_finite() and projectile.lifetime == 4.0 and projectile.get_child_count() == 2 and projectile.get_child(0) is MeshInstance3D and projectile.get_child(1) is OmniLight3D and projectile.velocity.is_equal_approx((data.destination-data.origin).normalized()*12.0) and get_stack().any(func(frame): return str(frame.get("source","")).ends_with("/enemy.gd") and frame.get("function","") == "_release_attack")
			l_births[id] = {"data":data.duplicate(true),"reference":weakref(projectile)}
			return
		if event != "queued_player_contact" or not l_births.has(id) or l_contacts.has(id) or l_used.has(id) or not l_pending.is_empty():
			l_ok = false
			return
		var birth: Dictionary = l_births[id].data
		for field in ["projectile","source","map","player"]:
			l_ok = l_ok and data.get(field) == birth.get(field)
		if not (data.get("hit") is Dictionary and data.get("ray_start") is Vector3 and data.get("ray_end") is Vector3):
			l_ok = false
			return
		var hit: Dictionary = data.hit
		l_ok = l_ok and projectile.is_queued_for_deletion() and data.tick >= birth.tick and data.tick-birth.tick <= 241 and data.ray_start.is_finite() and data.ray_end.is_finite() and hit.get("collider") == player and hit.get("position") is Vector3 and hit.get("normal") is Vector3 and hit.position.is_finite() and hit.normal.is_finite() and hit.get("rid") == player.get_rid() and projectile.global_position == hit.get("position") and data.ray_end.is_equal_approx(data.ray_start+projectile.velocity*minf(1.0/60.0,projectile.lifetime)) and get_stack().any(func(frame): return str(frame.get("source","")).ends_with("/projectile.gd") and frame.get("function","") == "_physics_process")
		if not l_ok: return
		# This repeats only the real reported native sweep; never guesses from queued objects.
		var query = PhysicsRayQueryParameters3D.create(data.ray_start,data.ray_end,1|2|4)
		query.exclude = [source.get_rid()]
		query.hit_from_inside = true
		var native_hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(query)
		l_ok = l_ok and not native_hit.is_empty() and native_hit == hit
		l_contacts[id] = data.duplicate(true)
		l_pending = {"id":id,"data":data.duplicate(true)}
	func hurt_player(amount: int) -> void:
		if not palanquin_enabled:
			super.hurt_player(amount)
			return
		var attributed: bool = false
		if amount == 14 and not l_pending.is_empty():
			var id: int = l_pending.id
			var data: Dictionary = l_pending.data
			var projectile = data.projectile
			attributed = l_births.has(id) and l_contacts.has(id) and not l_used.has(id) and data.tick == Engine.get_physics_frames() and is_instance_valid(projectile) and projectile.get_instance_id() == id and projectile.is_queued_for_deletion() and projectile._current_map() and data.map == level and data.player == player and data.source == projectile.shooter and data.source._current_map() and not data.source.is_queued_for_deletion() and data.hit.collider == player and get_stack().any(func(frame): return str(frame.get("source","")).ends_with("/projectile.gd") and frame.get("function","") == "_physics_process")
			if attributed:
				l_used[id] = true
				l_projectile_hurts += 1
			l_pending.clear()
		elif l_pending.is_empty() and amount in [10,12]:
			for actor in enemies:
				var tick: int = int(l_attacks.get(actor.id,-1000))
				var age: int = Engine.get_physics_frames()-tick
				var key: String = actor.id+":"+str(tick)
				if p_originals.has(actor.id) and actor.get_instance_id() == p_originals[actor.id].instance and actor._current_map() and actor.active and actor.hp > 0 and actor._committed_target == player and not l_attack_hits.has(key) and age >= 0 and ((actor.kind == "worker" and amount == 10 and age == 0) or (actor.kind == "crawler" and amount == 12 and age <= 12)):
					attributed = get_stack().any(func(frame): return str(frame.get("source","")).ends_with("/enemy.gd") and frame.get("function","") == "_attack")
					if attributed: l_attack_hits[key] = true
					break
		l_ok = l_ok and attributed and Engine.is_in_physics_frame() and playing and state.difficulty == 1 and player._current_map() and budget() == l_ledger
		var expected: Dictionary = l_ledger.duplicate(true)
		var absorbed: int = mini(int(expected.armor),int(amount/3))
		expected.armor -= absorbed
		expected.health = maxi(0,int(expected.health)-(amount-absorbed))
		super.hurt_player(amount)
		l_ok = l_ok and budget() == expected
		l_ledger = expected


var palanquin_started: bool = false
var l_epoch: int = 0
var l_wall_us: int = 0
var l_main_id: int = 0
var l_profile: String = ""
var l_start_shots: int = 0
var l_start_removed: Array = []
var l_ages: Dictionary = {}
var l_markers: Dictionary = {}

func run() -> void:
	prefix = "user://processional_earned_palanquin_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	if not await walk_to_palanquin_loop(PalanquinMain.new(),prefix):
		await finish(1)
		return
	print("PASS source-debug candidate second Palanquin loop/ivory/return only; actual virtual Input and original native actors, debug caster provenance. NOT third gate/exit/full campaign, physical controls, rendered/audio/performance or packed-app attribution.")
	await finish(0)

func walk_to_palanquin_loop(observer, profile_prefix: String) -> bool:
	prefix = profile_prefix
	if not await walk_to_organ_loop(observer,prefix) or not start_palanquin():
		return false
	if not await palanquin_route(PALANQUIN) or not await organ_fight(L_BRANCH) or not await palanquin_ivory() or not await palanquin_route(PALANQUIN_RETURN) or not await organ_fight(["processional_enemy_10","processional_enemy_11","processional_enemy_12","processional_enemy_21","processional_enemy_22"]) or not await palanquin_result():
		return false
	return true

func start_palanquin() -> bool:
	var earned: Dictionary = {"health":100,"armor":140,"ammo":[0,174,32,0,0,0],"owned_weapons":[0,1,2],"weapon":1}
	if not expect(FileAccess.get_sha256("res://tests/test_processional_earned_organ.gd") == L_ORGAN_SHA and FileAccess.get_sha256("res://data/03_processional.json") == P_MAP_SHA and OS.is_debug_build() and game.o_ok and game.budget() == earned and game.state.keys == ["blood"] and game.o_deaths.size() == 11 and game.enemies.size() == 26 and route_level.layout.data.enemies == L_ACTOR_SPECS and game.o_pending.is_empty(),"Gated Organ helper must pass exact earned resources/blood/11 deaths before independent Palanquin epoch"): return false
	for actor in game.enemies:
		if not expect(game.p_originals.has(actor.id) and actor.get_instance_id() == game.p_originals[actor.id].instance and actor.kind == L_ACTORS[actor.id].kind and actor.max_hp == (50 if actor.kind == "crawler" else 90) and actor._current_map() and actor.is_physics_processing(),"All 26 original actor bindings survive exact stage handoff"): return false
		l_ages[actor.id] = actor.age
	l_main_id = game.get_instance_id()
	l_profile = game.progress_path
	l_start_removed = game.state.removed.duplicate()
	for id in L_SUPPLIES+["processional_ivory"]:
		if not expect(route_level.markers.has(id) and is_instance_valid(route_level.markers[id]) and not route_level.markers[id].is_queued_for_deletion(),"Original Palanquin marker present: "+id): return false
		l_markers[id] = weakref(route_level.markers[id])
	release_actions()
	game.organ_enabled = false
	game.l_ledger = earned.duplicate(true)
	game.l_deaths = game.o_deaths.duplicate(true)
	# Preserve actual previous pistol cadence across stage handoff, not a fresh cooldown.
	game.l_last = game.o_last.duplicate()
	l_start_shots = game.shots
	l_epoch = Engine.get_physics_frames()
	l_wall_us = Time.get_ticks_usec()
	game.palanquin_enabled = true
	palanquin_started = true
	return live_route()

func east_elapsed() -> int:
	return Engine.get_physics_frames()-l_epoch if palanquin_started else super.east_elapsed()

func route_tick() -> bool:
	if not palanquin_started: return await super.route_tick()
	if not live_route(): return false
	await physics_frame
	return live_route()

func east_fire() -> bool:
	# The inherited Organ aim helper uses only actual current-map LOS and pistol Input.
	return super.east_fire()

func palanquin_route(cells: Array) -> bool:
	print("PALANQUIN_BLOCK cells=",cells," frames=",east_elapsed()," ledger=",game.l_ledger)
	for cell in cells:
		var started: int = east_elapsed()
		if not await east_route([cell]) or not expect(east_elapsed()-started <= HOP_LIMIT,"Palanquin native hop including process wait within 240 frames; target="+str(cell)+" position="+str(route_player.position)+" shots="+str(game.l_shots)+" ledger="+str(game.l_ledger)): return false
	return true

func palanquin_ivory() -> bool:
	if not expect(game.state.keys == ["blood"] and ["processional_enemy_17","processional_enemy_20"].any(func(id): return game.l_deaths.get(id,0) == 1 and game.l_finishes.get(id,false)),"Natural player finish of an original Palanquin caster precedes actual ivory"): return false
	aim_interaction([30.5,9.5])
	interaction_input(true)
	if not await route_tick(): return false
	# Hold through actual Main consumption; physics_frame precedes the buffered press callback.
	await process_frame
	if not live_route(): return false
	interaction_input(false)
	if not await route_tick(): return false
	release_actions()
	await process_frame
	return expect(game.l_ivory_calls == 1 and game.state.keys == ["blood","ivory"] and game.state.removed.count("processional_ivory") == 1 and l_markers.processional_ivory.get_ref() == null,"Actual interaction earns and drains original ivory once without granting resources")

func live_route() -> bool:
	if not palanquin_started: return super.live_route()
	if not expect(east_elapsed() <= L_LIMIT and Time.get_ticks_usec()-l_wall_us <= L_SECONDS*1000000,"NATIVE RED frozen second-loop 4500 native frames/100 seconds; no budget inflation"): return false
	if not expect(not paused and game.playing and not game.placement_pending and game.state.level_index == 2 and game.get_instance_id() == l_main_id and game.progress_path == l_profile and is_instance_valid(route_level) and is_instance_valid(route_player) and game.level == route_level and game.player == route_player and route_player._current_map() and not route_level.is_queued_for_deletion() and game.is_processing() and game.is_physics_processing() and route_player.is_physics_processing() and game.enemies.size() == 26 and route_level.layout.data.enemies == L_ACTOR_SPECS,"Same automatic Main/profile/Player/map and immutable authored 26-actor baseline"): return false
	var seen: Dictionary = {}
	for actor in game.enemies:
		if not expect(is_instance_valid(actor) and game.p_originals.has(actor.id) and L_ACTORS.has(actor.id) and not seen.has(actor.id),"Distinct original actor remains admitted"): return false
		var pin: Dictionary = game.p_originals[actor.id]
		if not expect(actor.get_instance_id() == pin.instance and actor.kind == L_ACTORS[actor.id].kind and actor.max_hp == (50 if actor.kind == "crawler" else 90) and actor.hp >= 0 and actor.hp <= actor.max_hp and actor._current_map() and actor.is_physics_processing() and actor.age-l_ages[actor.id] >= float(east_elapsed()-2)/60.0,"Original native identity/role/HP/age: "+actor.id): return false
		seen[actor.id] = true
		if actor.hp == 0:
			if not expect(game.l_deaths.get(actor.id,0) == 1 and game.state.removed.count(actor.id) == 1 and actor.collision_layer == 0 and actor.collision_mask == 0,"Natural original death/removal/collision retires once"): return false
		elif not expect(actor.collision_layer == 4 and actor.collision_mask == 7,"Living original retains native collision"): return false
	for node in route_level.get_children():
		if node.get_script() == preload("res://scripts/projectile.gd") and not expect(game.l_births.has(node.get_instance_id()),"Every native new-stage projectile has its exact validated birth"): return false
	var recovery_expected: Dictionary = {"health":93,"armor":89,"ammo":[0,164,0,0,0,0],"owned_weapons":[0,1],"weapon":1,"keys":[]}
	for recovery in [game.state.checkpoint,game.state.level_start]:
		for field in recovery_expected:
			if not expect(recovery.get(field) == recovery_expected[field],"Independent earned level-entry envelope field: "+field): return false
	for id in game.state.removed:
		if not expect(id in l_start_removed or game.l_consumed.has(id) or game.l_deaths.has(id) or (id == "processional_ivory" and game.l_ivory_calls == 1) or id in ["encounter:processional_palanquin_escort","encounter:processional_palanquin_return","encounter:processional_nave_response"],"No unrelated story/checkpoint/gate/exit mutation in second-loop scope: "+id): return false
	return expect(seen.size() == 26 and game.l_ok and game.rate_ok and game.feedback_ok and game.shot_clock_ok and game.l_ticks >= east_elapsed()-2 and game.shots-l_start_shots == game.l_shots[1]+game.l_shots[2] and game.budget() == game.l_ledger and game.state.health > 0 and game.state.health <= 100 and game.state.armor >= 0 and game.state.armor <= 200 and game.state.ammo[1] >= 0 and game.state.ammo[1] <= 180 and game.state.ammo[2] >= 0 and game.state.ammo[2] <= 32 and game.state.ammo.slice(3) == [0,0,0] and game.state.ammo[0] == 0 and game.state.owned_weapons == [0,1,2] and game.state.weapon == 1 and game.state.keys == game.l_keys and game.state.discoveries.is_empty() and game.state.checkpoint_id == "entry" and game.state.checkpoint == p_recovery and game.state.level_start == p_start and game.l_pending.is_empty(),"Exact independent second-loop ledger/cadence/provenance and independently grounded untouched entry envelopes")

func palanquin_result() -> bool:
	release_actions()
	await process_frame
	if not live_route(): return false
	if not expect(route_player.position.distance_to(route_level.layout.world_position([16.5,24.5])+Vector3.UP*0.04) < 0.2 and game.state.keys == ["blood","ivory"] and not game.l_births.is_empty() and game.l_ivory_calls == 1,"Second authored loop returns to original junction with earned ivory and positive actual caster birth"): return false
	for id in ["processional_palanquin_escort","processional_palanquin_return","processional_nave_response"]:
		if not expect(game.state.removed.count("encounter:"+id) == 1,"Actual legitimate second-loop encounter activates once: "+id): return false
	for id in L_SUPPLIES:
		if not expect(game.l_consumed.has(id) or game.l_rejected.has(id),"Original Palanquin supply receives real native proximity callback: "+id): return false
	for id in game.l_consumed:
		if not expect(game.l_consumed[id] == 1 and l_markers[id].get_ref() == null,"Actual consumed supply drains once: "+id): return false
	for id in game.l_rejected:
		if not game.l_consumed.has(id):
			var original = l_markers[id].get_ref()
			if not expect(is_instance_valid(original) and route_level.markers.get(id) == original and original.get_parent() == route_level and not original.is_queued_for_deletion() and not id in game.state.removed,"Every rejected unconsumed Palanquin original marker survives final result: "+id): return false
	for id in game.o_rejected:
		if not game.o_consumed.has(id):
			var original = o_markers[id].get_ref()
			if not expect(is_instance_valid(original) and route_level.markers.get(id) == original and original.get_parent() == route_level and not original.is_queued_for_deletion() and not id in game.state.removed,"Prior rejected Organ marker remains intact through second loop: "+id): return false
	for id in game.l_births:
		if not expect(game.l_births[id].reference.get_ref() == null,"Admitted caster projectile drains naturally before result"): return false
	if not expect(game.l_contacts.size() == game.l_used.size() and game.l_projectile_hurts == game.l_used.size(),"Each actual received projectile contact matches one synchronous hurt; zero hits is not positive hit-path evidence"): return false
	var view: Dictionary = game.hud.view
	if not expect(view.get("weapon_name","") == "RIVET PISTOL" and view.get("ammo","") == str(game.state.ammo[1]),"Actual automatically updated HUD fields show earned pistol/current ammo; not rendered-quality evidence"): return false
	print("PROCESSIONAL_PALANQUIN native_frames=",east_elapsed()," shots=",game.l_shots," consumed=",game.l_consumed," rejected=",game.l_rejected," caster_births=",game.l_births.size()," actual_caster_hurts=",game.l_projectile_hurts," deaths=",game.l_deaths," resources=",game.l_ledger)
	return true
