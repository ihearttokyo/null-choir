extends "res://tests/test_reliquary_wheel_ivory.gd"

const V_WHEEL_SHA = "d9c55f4afda847fd7b9cad78f765159e6de7fcbfad0486462f967c723deffc33"
const V_IDS = ["reliquary_enemy_19","reliquary_enemy_20","reliquary_enemy_21"]
const V_GROUP = {"id":"reliquary_wheel_return","region":[21.5,11.0,22.5,14.0],"enemy_ids":V_IDS,"requires":["ivory"],"cue":{"text":"A MEMORY LEAVES THE DRUM WITHOUT YOU","light_ids":["reliquary_wheel_return"],"sound":"seal_release"}}
const V_PICKUPS = {
	"reliquary_wheel_recess_health":{"id":"reliquary_wheel_recess_health","kind":"health","cell":[36.5,19.5],"amount":25.0},
	"reliquary_wheel_return_rivets":{"id":"reliquary_wheel_return_rivets","kind":"ammo","cell":[23.5,12.5],"amount":45.0,"weapon":1.0},
	"reliquary_wheel_return_shells":{"id":"reliquary_wheel_return_shells","kind":"ammo","cell":[24.5,13.5],"amount":8.0,"weapon":2.0}}
const V_CARRY = {"health":86,"armor":184,"ammo":[0,148,32,0,0,0],"owned_weapons":[0,1,2],"weapon":1}
const V_APPROACH = [[35.5,19.5],[36.5,19.5],[35.5,19.5],[35.5,16.5],[35.5,13.5],[35.5,12],[32.5,12],[29.5,12],[26.5,12],[23.5,12],[23.5,12.5],[22.25,12.5]]
const V_CLOSE = [[21,12.5]]
const V_SHOT_CAP = 24
const V_FIGHT_LIMIT = 240
const V_DRAIN = 6
const V_LIMIT = 13*240+V_FIGHT_LIMIT+V_DRAIN
const V_SECONDS = float(V_LIMIT)/60.0+2.0
const V_ACTIVATION_GUARD = "NATIVE RED Wheel RETURN requires actual Ivory-gated original region-driven Main._process activation"
const V_EARNING_GUARD = "NATIVE RED Wheel RETURN requires all3 original provenanced native deaths and actual bounded Player pistol input before closure"
const V_WHEEL_FIELDS = ["w_base","w_ivory_calls","w_pending_key","w_inputs","w_pickup_calls","w_ok","w_ticks","w_shots","w_last","w_slot","w_last_time","w_shot_start_age","w_shot_start_time","w_rivets","w_health_loss","w_absorbed","w_consumed","w_rejected","w_removed","w_activation","w_activated","w_attacks","w_roles","w_damage_attacks","w_hurts","w_deaths","w_finishes","w_births","w_contacts","w_projectile_used","w_pending","w_release","w_melee_pending","w_enemy_contacts","w_enemy_pending","w_enemy_used"]

class WheelReturnMain:
	extends "res://tests/test_reliquary_wheel_ivory.gd".WheelMain
	var v_enabled: bool = false
	var v_base: Dictionary = {}
	var v_health_gain: int = 0
	var v_pickup_calls: Array = []
	var v_ok: bool = true
	var v_ticks: int = 0
	var v_activation: int = 0
	var v_activated: Dictionary = {}
	var v_removed: Array = []
	var v_shots: Array = []
	var v_last: int = -1
	var v_slot: float = -1.0
	var v_last_time: float = -INF
	var v_shot_start_age: float = INF
	var v_shot_start_time: float = 0.0
	var v_rivets: int = 0
	var v_consumed: Dictionary = {}
	var v_rejected: Dictionary = {}
	var v_health_loss: int = 0
	var v_absorbed: int = 0
	var v_hurts: Array = []
	var v_attacks: Dictionary = {}
	var v_roles: Dictionary = {}
	var v_deaths: Dictionary = {}
	var v_finishes: Dictionary = {}
	var v_release: Dictionary = {}
	var v_melee_pending: Dictionary = {}
	var v_damage_attacks: Dictionary = {}
	func v_current() -> bool:
		return h_current() and not h_enabled and not b_enabled and not q_enabled and not w_enabled and v_enabled
	func v_original(actor) -> bool:
		return is_instance_valid(actor) and actor.get_script() == Enemy and actor.id in V_IDS and h_bindings.get(actor.id,-1) == actor.get_instance_id() and actor._current_map() and actor.get_parent() == level and not actor.is_queued_for_deletion()
	func v_worker_contact(victim, repeat_ray: bool) -> bool:
		var source = v_release.get("source")
		if not v_original(source) or source.kind != "worker" or source.hp <= 0 or not source.active or v_release.get("tick",-1) != Engine.get_physics_frames() or not h_stack("/enemy.gd","_attack") or not h_stack("/enemy.gd","_release_attack"): return false
		var key: String = source.id+":"+str(v_release.tick)
		var hit: Dictionary = v_release.hit
		if v_damage_attacks.has(key) or hit.get("collider") != victim or hit.get("rid") != victim.get_rid() or victim.get_parent() != level: return false
		var origin: Vector3 = source.global_position+Vector3.UP*1.4
		var end: Vector3 = origin+(source._committed_aim-origin).normalized()*30.0
		if origin != v_release.origin or end != v_release.end: return false
		if repeat_ray:
			var query = PhysicsRayQueryParameters3D.create(origin,end,1|2|4)
			query.exclude = [source.get_rid()]
			query.hit_from_inside = true
			if level.get_world_3d().direct_space_state.intersect_ray(query) != hit: return false
		return true
	func v_crawler_contact(victim, repeat_ray: bool) -> bool:
		if v_melee_pending.is_empty(): return false
		var source = v_melee_pending.source
		var tick: int = v_melee_pending.release_tick
		var age: int = Engine.get_physics_frames()-tick
		if not v_original(source) or source.kind != "crawler" or source.hp <= 0 or not source.active or v_melee_pending.tick != Engine.get_physics_frames() or v_melee_pending.map != level or v_melee_pending.player != player or v_attacks.get(source.id,-1) != tick or age < 0 or age > 12 or v_damage_attacks.has(source.id+":"+str(tick)) or not h_stack("/enemy.gd","_try_melee") or not h_stack("/enemy.gd","_attack"): return false
		var hit: Dictionary = v_melee_pending.hit
		if hit.get("collider") != victim or hit.get("rid") != victim.get_rid() or victim.get_parent() != level: return false
		var intended = v_melee_pending.intended
		if not is_instance_valid(intended) or source._committed_target != intended or source.global_position.distance_to(intended.global_position) >= 1.9: return false
		var origin: Vector3 = source.global_position+Vector3.UP*0.6
		var end: Vector3 = intended.global_position+Vector3.UP*0.7
		if origin != v_melee_pending.origin or end != v_melee_pending.end: return false
		if repeat_ray:
			var query = PhysicsRayQueryParameters3D.create(origin,end,1|2|4)
			query.exclude = [source.get_rid()]
			query.hit_from_inside = true
			if level.get_world_3d().direct_space_state.intersect_ray(query) != hit: return false
		else:
			if v_melee_pending.victim_hp <= 0 or v_melee_pending.victim_hp > 12: return false
		return true
	func v_resources() -> Dictionary:
		return {"health":v_base.health+v_health_gain-v_health_loss,"armor":v_base.armor-v_absorbed,"ammo":[0,int(v_base.ammo[1])+v_rivets-v_shots.size(),32,0,0,0],"owned_weapons":[0,1,2],"weapon":1}
	func _physics_process(delta: float) -> void:
		super._physics_process(delta)
		if not v_enabled: return
		v_ticks += 1
		v_ok = v_ok and v_current() and v_melee_pending.is_empty() and absf(delta-1.0/60.0) < 0.000001
		if not Input.is_action_pressed("fire"): v_slot = -1.0
	func shot(weapon: int) -> void:
		if v_enabled:
			var tick: int = Engine.get_physics_frames()
			v_slot = entry_slot(tick,v_last,v_slot,weapon)
			v_ok = v_ok and v_current() and v_activation == 1 and Engine.is_in_physics_frame() and weapon == 1 and state.weapon == 1 and Input.is_action_pressed("fire") and v_slot >= 0.0 and player.shot_age(1) == 0.0 and h_stack("/player.gd","fire") and player.active_play_time > v_last_time and (v_shots.size() > 0 or v_shot_start_age+player.active_play_time-v_shot_start_time+0.000001 >= 0.21)
			v_ok = v_ok and v_shots.size() < V_SHOT_CAP
			v_shots.append([tick,player.active_play_time,v_slot,player.cooldown,weapon])
			v_last = tick
			v_last_time = player.active_play_time
			v_ok = v_ok and budget() == v_resources() and state.ammo[1] >= 0 and state.ammo[1] <= 180 and player.cooldown > 0 and player.cooldown <= 0.21+0.000001
		super.shot(weapon)
	func collect_pickup(id: String) -> void:
		if not v_enabled:
			super.collect_pickup(id)
			return
		if not V_PICKUPS.has(id):
			v_ok = false
			super.collect_pickup(id)
			return
		var spec: Dictionary = V_PICKUPS[id]
		var before: Dictionary = v_resources()
		var ammo: bool = spec.kind == "ammo"
		var slot: int = int(spec.get("weapon",0))
		var old: int = int(before.ammo[slot] if ammo else before.health)
		var cap: int = (180 if slot == 1 else 32) if ammo else 100
		var gain: int = mini(cap,old+int(spec.amount))-old
		var marker = level.markers.get(id)
		v_pickup_calls.append([id,Engine.get_physics_frames(),before.duplicate(true),gain])
		v_ok = v_ok and v_current() and Engine.is_in_physics_frame() and budget() == before and not id in state.removed and is_instance_valid(marker) and marker.get_parent() == level and not marker.is_queued_for_deletion() and level.layout.data.pickups.filter(func(item): return item.id == id) == [spec] and player.position.distance_to(level.layout.world_position(spec.cell)) < 1.4 and _passive_trigger_visible(spec) and h_stack("/main.gd","update_passive_triggers") and h_stack("/player.gd","_physics_process")
		super.collect_pickup(id)
		if gain > 0:
			v_ok = v_ok and v_activation == 0 and v_shots.is_empty() and v_health_loss == 0 and v_absorbed == 0
			if ammo:
				v_ok = v_ok and slot == 1 and gain == 32 and v_health_gain == 14 and before.ammo[1] == 148
				v_rivets += gain
			else:
				v_ok = v_ok and id == "reliquary_wheel_recess_health" and before == v_base and gain == 14
				v_health_gain += gain
			v_consumed[id] = v_consumed.get(id,0)+1
			v_removed.append(id)
			v_ok = v_ok and v_consumed[id] == 1 and not level.markers.has(id) and state.removed.count(id) == 1
		else:
			v_rejected[id] = v_rejected.get(id,0)+1
			v_ok = v_ok and id == "reliquary_wheel_return_shells" and before.ammo[2] == 32 and level.markers.get(id) == marker and not marker.is_queued_for_deletion() and not id in state.removed
		v_ok = v_ok and budget() == v_resources() and state.removed == v_removed
	func activate_encounter(id: String) -> void:
		if not v_enabled:
			super.activate_encounter(id)
			return
		var prior: bool = "encounter:"+id in state.removed
		v_ok = v_ok and v_current() and id in [W_GROUP.id,V_GROUP.id]
		if not prior:
			var cell: Vector2 = Vector2(player.position.x,player.position.z)/4.0
			v_ok = v_ok and id == V_GROUP.id and v_activation == 0 and state.keys == ["blood","ivory"] and cell.is_equal_approx(cell.clamp(Vector2(21.5,11),Vector2(22.5,14))) and h_stack("/main.gd","_process") and not h_stack("/enemy.gd","take_damage")
		super.activate_encounter(id)
		if not prior:
			v_activation += 1
			v_removed.append("encounter:"+id)
			for actor in enemies:
				if actor.id in V_IDS:
					v_ok = v_ok and v_original(actor) and actor.active and actor.alerted and actor.hp == actor.max_hp
					v_activated[actor.id] = [actor.get_instance_id(),Engine.get_physics_frames()]
			v_ok = v_ok and v_activation == 1 and v_activated.size() == 3 and state.removed == v_removed and message == V_GROUP.cue.text
	func enemy_event(actor, event: String) -> void:
		if v_enabled:
			v_ok = v_ok and v_current() and Engine.is_in_physics_frame() and v_original(actor) and actor.active and v_activated.has(actor.id) and h_stack("/enemy.gd","_event")
			if event == "attack":
				v_attacks[actor.id] = Engine.get_physics_frames()
				v_roles[actor.kind] = v_roles.get(actor.kind,0)+1
				v_release = {"source":actor,"tick":Engine.get_physics_frames()}
				if actor.kind == "worker":
					var origin: Vector3 = actor.global_position+Vector3.UP*1.4
					var end: Vector3 = origin+(actor._committed_aim-origin).normalized()*30.0
					var query = PhysicsRayQueryParameters3D.create(origin,end,1|2|4)
					query.exclude = [actor.get_rid()]
					query.hit_from_inside = true
					v_release.merge({"origin":origin,"end":end,"hit":level.get_world_3d().direct_space_state.intersect_ray(query)})
			if event == "melee_contact":
				var intended = actor._committed_target
				var tick: int = int(v_attacks.get(actor.id,-1000))
				var age: int = Engine.get_physics_frames()-tick
				if not OS.is_debug_build() or actor.kind != "crawler" or actor.hp <= 0 or not v_melee_pending.is_empty() or not actor._valid_target(intended) or intended.get_parent() != level or actor.global_position.distance_to(intended.global_position) >= 1.9 or age < 0 or age > 12 or v_damage_attacks.has(actor.id+":"+str(tick)) or not h_stack("/enemy.gd","_try_melee") or not h_stack("/enemy.gd","_physics_process"):
					v_ok = false
				else:
					var origin: Vector3 = actor.global_position+Vector3.UP*0.6
					var end: Vector3 = intended.global_position+Vector3.UP*0.7
					var query = PhysicsRayQueryParameters3D.create(origin,end,1|2|4)
					query.exclude = [actor.get_rid()]
					query.hit_from_inside = true
					var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(query)
					var victim = hit.get("collider")
					if not origin.is_finite() or not end.is_finite() or not (victim == player or v_original(victim) and victim.hp > 0) or hit.get("rid") != victim.get_rid():
						v_ok = false
					elif victim == player or victim.hp <= 12:
						v_melee_pending = {"source":actor,"release_tick":tick,"tick":Engine.get_physics_frames(),"map":level,"player":player,"intended":intended,"origin":origin,"end":end,"hit":hit,"victim_hp":0 if victim == player else victim.hp}
			if event == "death":
				v_deaths[actor.id] = v_deaths.get(actor.id,0)+1
				var player_fire: bool = actor.target == player and v_last == Engine.get_physics_frames() and player.shot_age(1) == 0.0 and Input.is_action_pressed("fire") and h_stack("/player.gd","fire") and aim_observation.get("actor_id","") == actor.id and aim_observation.get("tick",-1) == Engine.get_physics_frames() and aim_observation.get("level") == level and aim_observation.get("player") == player and aim_observation.get("weapon",-1) == 1
				var worker: bool = v_worker_contact(actor,false)
				var crawler: bool = v_crawler_contact(actor,false)
				if worker: v_damage_attacks[v_release.source.id+":"+str(v_release.tick)] = true
				if crawler:
					v_damage_attacks[v_melee_pending.source.id+":"+str(v_melee_pending.release_tick)] = true
					v_melee_pending.clear()
				v_finishes[actor.id] = "player" if player_fire else "infighting" if worker or crawler else "unproven"
				v_removed.append(actor.id)
				v_ok = v_ok and actor.hp == 0 and actor.collision_layer == 0 and actor.collision_mask == 0 and state.removed.count(actor.id) == 1 and v_deaths[actor.id] == 1 and (player_fire or worker or crawler) and state.removed == v_removed
		super.enemy_event(actor,event)
	func hurt_player(amount: int) -> void:
		if not v_enabled:
			super.hurt_player(amount)
			return
		var worker: bool = amount == 10 and v_worker_contact(player,true)
		var crawler: bool = amount == 12 and v_crawler_contact(player,true)
		v_ok = v_ok and v_current() and Engine.is_in_physics_frame() and state.difficulty == 1 and (worker or crawler) and budget() == v_resources()
		var source_id: String = "unproven"
		if worker:
			source_id = v_release.source.id
			v_damage_attacks[source_id+":"+str(v_release.tick)] = true
		if crawler:
			source_id = v_melee_pending.source.id
			v_damage_attacks[source_id+":"+str(v_melee_pending.release_tick)] = true
			v_melee_pending.clear()
		var absorbed: int = mini(int(v_base.armor)-v_absorbed,int(amount/3))
		v_absorbed += absorbed
		v_health_loss += amount-absorbed
		v_hurts.append([Engine.get_physics_frames(),source_id,amount,absorbed])
		super.hurt_player(amount)
		v_ok = v_ok and budget() == v_resources()
	func interact() -> void:
		if v_enabled: v_ok = false
		super.interact()
	func collect_key(id: String) -> void:
		if v_enabled: v_ok = false
		super.collect_key(id)
	func unlock_door(id: String) -> bool:
		if v_enabled: v_ok = false
		return super.unlock_door(id)
	func _capture_actor_state() -> bool:
		if v_enabled: v_ok = false
		return super._capture_actor_state()
	func _save() -> Error:
		if v_enabled: v_ok = false
		return super._save()
	func _debug_projectile_event(projectile: Node3D, event: String, data: Dictionary) -> void:
		if v_enabled: v_ok = false
		super._debug_projectile_event(projectile,event,data)

var v_started: bool = false
var v_epoch: int = 0
var v_wall: int = 0
var v_fields: Array = []
var v_frozen: Dictionary = {}
var v_actors: Array = []
var v_markers: Dictionary = {}
var v_time: float = 0.0
var v_actor_image: Variant
var v_closed: bool = false
var v_fighting: bool = false
var v_closure_frames: int = 0
var v_drain_frames: int = 0

func run() -> void:
	if "--wheel-return-pin-rejection" in OS.get_cmdline_user_args():
		await wheel_return_pin_rejection()
		return
	if not await walk_through_wheel_return(WheelReturnMain.new()):
		await finish(1)
		return
	print("PASS source-native virtual-input original Wheel RETURN3 after continuous earned first3/Halo/Blood/story/Return/Wheel/Ivory; not full-fourth/eight, physical controls, rendered/audio/GPU/performance or standalone acceptance")
	await finish(0)

func wheel_return_pin_rejection() -> void:
	if not expect(FileAccess.get_sha256("res://tests/test_reliquary_wheel_ivory.gd") != V_WHEEL_SHA,"Pin rejection requires parent-owned deliberate dependency mismatch"):
		await finish(1)
		return
	var rejected_prefix: String = "user://reliquary_wheel_return_pin_rejection_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	var observer = WheelReturnMain.new()
	var reference = weakref(observer)
	var result: bool = await walk_through_wheel_return(observer,rejected_prefix)
	var untouched: bool = game == null and root.get_child_count() == 0 and not FileAccess.file_exists(rejected_prefix+"_campaign.json") and not FileAccess.file_exists(rejected_prefix+"_preferences.json")
	var accepted: bool = expect(not result and reference.get_ref() == null and untouched,"Rejected pin frees only fresh unadopted observer; check unique fixture files, not unrelated default save")
	if is_instance_valid(observer): observer.free()
	await finish(0 if accepted else 1)

func walk_through_wheel_return(observer: WheelReturnMain, profile_prefix: String = "") -> bool:
	if not expect(FileAccess.get_sha256("res://tests/test_reliquary_wheel_ivory.gd") == V_WHEEL_SHA,"Exact unchanged nonquitting Ivory helper before observer/scene/profile adoption"):
		if is_instance_valid(observer) and observer != game and not observer.is_inside_tree(): observer.free()
		return false
	if not await walk_through_wheel_ivory(observer,profile_prefix if not profile_prefix.is_empty() else "user://reliquary_wheel_return_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())) or not start_wheel_return(): return false
	if not "--omit-wheel-return-approach" in OS.get_cmdline_user_args():
		if not await blood_story_route(V_APPROACH): return false
	if not expect(game.v_activation == 1 and game.v_activated.size() == 3,V_ACTIVATION_GUARD): return false
	v_fighting = true
	for frame in range(V_FIGHT_LIMIT):
		if game.v_deaths.size() == 3: break
		release_actions()
		east_fire()
		if not await route_tick(): return false
	v_fighting = false
	release_actions()
	if not wheel_return_earned(): return false
	var began: int = east_elapsed()
	if not await blood_story_route(V_CLOSE): return false
	v_closure_frames = east_elapsed()-began
	v_closed = true
	began = east_elapsed()
	for frame in range(V_DRAIN):
		if not await route_tick(): return false
	v_drain_frames = east_elapsed()-began
	await process_frame
	return wheel_return_result()

func start_wheel_return() -> bool:
	if not expect(game is WheelReturnMain and game.w_enabled and game.w_ok and wheel_result() and game.budget() == V_CARRY and route_player.position.distance_to(route_level.layout.world_position(W_IVORY.cell)) < 0.2,"Exact actual reviewed Ivory boundary86HP184armor148pistol32shells; same live scene, not a loaded substitute"): return false
	if not expect(V_LIMIT == (V_APPROACH.size()+V_CLOSE.size())*HOP_LIMIT+V_FIGHT_LIMIT+V_DRAIN,"Fresh13 split hops plus240 combat and6 drain frames; old budgets unchanged"): return false
	if not expect(route_level.layout.data.encounters.filter(func(item): return item.id == V_GROUP.id) == [V_GROUP],"Original Ivory-gated Wheel RETURN region/group/cue"): return false
	for id in V_PICKUPS:
		if not expect(route_level.layout.data.pickups.filter(func(item): return item.id == id) == [V_PICKUPS[id]] and route_level.markers.has(id),"Original finite Wheel RETURN supply: "+id): return false
	for actor in game.enemies:
		var capsule: CollisionShape3D = actor.get_child(0)
		v_actors.append({"instance":actor.get_instance_id(),"age":actor.age,"position":actor.position,"yaw":actor.rotation.y,"active":actor.active,"alerted":actor.alerted,"shape_disabled":capsule.disabled,"capsule":capsule.get_instance_id(),"shape":capsule.shape.get_instance_id(),"capsule_position":capsule.position,"radius":capsule.shape.radius,"height":capsule.shape.height})
	for id in route_level.markers: v_markers[id] = weakref(route_level.markers[id])
	var actual_fields: Array = []
	for property in game.get_property_list():
		if str(property.name).begins_with("w_") and property.name != "w_enabled": actual_fields.append(property.name)
	actual_fields.sort()
	var declared: Array = V_WHEEL_FIELDS.duplicate()
	declared.sort()
	if not expect(actual_fields == declared,"Freeze EVERY Wheel w_ field except retired flag, including all resources/inputs/contacts/projectiles"): return false
	v_fields = w_fields+V_WHEEL_FIELDS
	v_frozen = observer_witness(v_fields)
	v_actor_image = game.state.actors.duplicate(true) if game.state.actors is Array else game.state.actors
	game.v_base = game.w_resources().duplicate(true)
	game.v_removed = game.state.removed.duplicate()
	v_time = route_player.active_play_time
	game.v_shot_start_time = v_time
	game.v_shot_start_age = route_player.shot_age(1)
	release_actions()
	game.w_enabled = false
	v_epoch = Engine.get_physics_frames()
	v_wall = Time.get_ticks_usec()
	game.v_enabled = true
	v_started = true
	return live_route()

func east_elapsed() -> int:
	return Engine.get_physics_frames()-v_epoch if v_started else super.east_elapsed()

func route_tick() -> bool:
	if not v_started: return await super.route_tick()
	if not live_route() or not expect(game.state.health > 24,"Finite Wheel RETURN survival stop before Recovery; do not weaken for omitted-fire diagnostics"): return false
	await physics_frame
	return live_route() and expect(game.state.health > 24,"Finite Wheel RETURN survival stop before Recovery; do not weaken for omitted-fire diagnostics")

func east_fire() -> bool:
	if not v_started: return super.east_fire()
	Input.action_release("fire")
	if not v_fighting or game.v_activation != 1 or "--omit-wheel-return-fire" in OS.get_cmdline_user_args() or game.v_shots.size() >= V_SHOT_CAP or game.state.weapon != 1: return false
	var selected = null
	var nearest: float = 140.0
	for actor in game.enemies:
		if not game.v_original(actor) or not actor.active or actor.hp <= 0: continue
		var point: Vector3 = actor.global_position+actor.get_child(0).position
		var distance: float = route_player.camera.global_position.distance_to(point)
		if distance >= nearest: continue
		var query = PhysicsRayQueryParameters3D.create(route_player.camera.global_position,point,1|4)
		query.exclude = [route_player.get_rid()]
		var hit: Dictionary = route_level.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider == actor:
			selected = actor
			nearest = distance
	if selected == null: return false
	var aim: Vector3 = selected.global_position+selected.get_child(0).position
	var heading: Vector3 = aim-route_player.camera.global_position
	route_player.rotation.y = atan2(-heading.x,-heading.z)
	route_player.camera.look_at(aim,Vector3.UP)
	Input.action_press("fire")
	return true

func clear_point(cell: Array):
	if not v_started: return super.clear_point(cell)
	if cell[0] < 20.75 or cell[0] > 36.75 or cell[1] < 11.75 or cell[1] > 19.75: return null
	var layout = route_level.layout
	if not layout.is_walkable(Vector2i(floori(cell[0]),floori(cell[1]))): return null
	# world_position interpolates the same [0,1,2]/[0,2,3] native floor triangles, including ramp seams.
	var point: Vector3 = layout.world_position(cell)
	var space = route_level.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*2.0,point-Vector3.UP*0.5,1))
	if hit.is_empty() or absf(hit.position.y-point.y) > 0.08 or hit.normal.y < 0.7: return null
	var collider: CollisionShape3D = route_player.get_child(0)
	var pose: Vector3 = point+Vector3.UP*0.04
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.transform = Transform3D(Basis.IDENTITY,pose+collider.position)
	query.collision_mask = route_player.collision_mask
	query.exclude = [route_player.get_rid()]
	return pose if space.intersect_shape(query,1).is_empty() else null

func wheel_return_earned() -> bool:
	print("RELIQUARY_WHEEL_RETURN_EARNING position=",route_player.position," frames=",east_elapsed()," activation=",game.v_activation," deaths=",game.v_deaths," provenance=",game.v_finishes," shots=",game.v_shots," survivors=",game.enemies.filter(func(actor): return game.v_original(actor) and actor.hp > 0).map(func(actor): return [actor.id,actor.position,actor.hp]))
	return live_route() and expect(game.v_activation == 1 and game.v_activated.size() == 3 and game.v_deaths.size() == 3 and V_IDS.all(func(id): return game.v_activated.has(id) and game.v_deaths.get(id,0) == 1 and game.v_finishes.get(id,"unproven") in ["player","infighting"]) and game.v_shots.size() > 0 and game.v_shots.size() <= V_SHOT_CAP,V_EARNING_GUARD)

func wheel_return_result() -> bool:
	var view: Dictionary = game.hud.view
	var resources: Dictionary = game.v_resources()
	if not expect(view.get("seals",[]) == [{"key":"blood","owned":true},{"key":"ivory","owned":true}] and view.get("objective","") == "OPEN GATE" and view.get("health",-1) == resources.health and view.get("armor",-1) == resources.armor and view.get("weapon_name","") == "RIVET PISTOL" and view.get("ammo","") == str(resources.ammo[1]) and view.get("capacity","") == "CAP 180","Automatic Wheel RETURN HUD model reflects both earned seals and independent resources"): return false
	if not expect(game.hud.labels.Objective.text == "OPEN GATE" and game.hud.labels.SealState.text == "BLOOD [+]  IVORY [+]" and game.hud.labels.VitalValue.text == str(resources.health) and game.hud.labels.ArmorValue.text == str(resources.armor) and game.hud.labels.WeaponName.text == "RIVET PISTOL" and game.hud.labels.AmmoValue.text == str(resources.ammo[1]) and game.hud.labels.AmmoCapacity.text == "CAP 180","Actual automatic native HUD labels; models/text are not pixels"): return false
	print("RELIQUARY_WHEEL_RETURN_LIMIT frames=",east_elapsed()," wall_us=",Time.get_ticks_usec()-v_wall," closure_frames=",v_closure_frames," drain_frames=",v_drain_frames," position=",route_player.position," resources=",resources," shots=",game.v_shots," consumed=",game.v_consumed," pickup_calls=",game.v_pickup_calls," roles=",game.v_roles," hurts=",game.v_hurts," deaths=",game.v_deaths," provenance=",game.v_finishes)
	return wheel_return_earned() and expect(v_closed and v_closure_frames > 0 and v_closure_frames <= HOP_LIMIT and v_drain_frames == V_DRAIN and route_player.position.distance_to(route_level.layout.world_position(V_CLOSE.back())) < 0.2 and game.v_consumed == {"reliquary_wheel_recess_health":1,"reliquary_wheel_return_rivets":1} and game.v_health_gain == 14 and game.v_rivets == 32 and v_markers["reliquary_wheel_recess_health"].get_ref() == null and v_markers["reliquary_wheel_return_rivets"].get_ref() == null and v_markers["reliquary_wheel_return_shells"].get_ref() == route_level.markers.get("reliquary_wheel_return_shells") and game.v_melee_pending.is_empty(),"Exact3 original earned deaths before measured bounded closure/drain; two original capped supplies once, shells and later branch untouched")

func live_route() -> bool:
	if not v_started: return super.live_route()
	if not expect(east_elapsed() <= V_LIMIT and Time.get_ticks_usec()-v_wall <= V_SECONDS*1000000,"Fresh Wheel RETURN epoch/bounds independent of all completed phases"): return false
	if not expect(game.v_ok and game.v_current() and not paused and game.get_instance_id() == r_main_id and game.state.get_instance_id() == r_campaign_id and game.progress_path == r_profile and game.settings_path == game.r_settings_origin and game.level == route_level and game.player == route_player and not game.loaded_positions and game.is_processing() and game.is_physics_processing() and route_player.is_physics_processing() and route_player.position.is_finite() and game.enemies.size() == 31 and game.scene_roster_matches(),"Same native Main/Campaign/profile/Player/original31; no recovery, unregistered actor or scene replacement"): return false
	if not expect(observer_witness(v_fields) == v_frozen and observer_witness(w_fields) == w_frozen and observer_witness(b_fields) == b_frozen and observer_witness(h_fields) == h_frozen and observers_retired() and not game.h_enabled and not game.b_enabled and not game.q_enabled and not game.w_enabled and observer_witness(q_fields) == q_frozen and retired.all(func(ref): return ref.get_ref() == null) and x_marker_refs.values().all(func(ref): return ref.get_ref() == null),"All accepted prefix/Halo/Blood/Return/Wheel/Ivory history frozen; only completed Wheel flag retired"): return false
	for refs in [h_marker_refs,b_markers,q_markers,w_markers]:
		for id in refs:
			if id in v_frozen.w_removed and not expect(refs[id].get_ref() == null,"Every old consumed marker drains: "+id): return false
	for index in range(R_ACTORS.size()):
		var spec: Array = R_ACTORS[index]
		var actor = game.enemies[index]
		var prior: Dictionary = v_actors[index]
		var capsule: CollisionShape3D = actor.get_child(0)
		if not expect(capsule.get_instance_id() == prior.capsule and capsule.shape.get_instance_id() == prior.shape and capsule.position == prior.capsule_position and capsule.shape.radius == prior.radius and capsule.shape.height == prior.height,"All31 original capsule and shape identities/dimensions"): return false
		if not expect(is_instance_valid(actor) and actor.id == spec[0] and actor.get_instance_id() == prior.instance and actor.get_instance_id() == game.h_bindings[actor.id] and actor.get_script() == game.Enemy and actor.kind == spec[1] and actor.max_hp == spec[2] and actor._current_map() and actor.is_physics_processing() and actor.age-prior.age >= float(east_elapsed()-2)/60.0 and (actor.get_child(0) as CollisionShape3D).disabled == prior.shape_disabled,"Original native identity/age/capsule: "+spec[0]): return false
		if actor.id in V_IDS:
			if game.v_activation == 0 and not expect(actor.hp == spec[2] and actor.position == prior.position and actor.rotation.y == prior.yaw and not actor.alerted,"Wheel RETURN actors retain original fullHP/pose until real region activation"): return false
			if not expect(game.v_original(actor) and actor.hp >= 0 and actor.hp <= spec[2] and actor.active == (game.v_activation == 1) and actor.alerted == (game.v_activation == 1) and (actor.hp > 0 or game.v_deaths.get(actor.id,0) == 1 and game.v_finishes.get(actor.id,"unproven") in ["player","infighting"] and actor.collision_layer == 0 and actor.collision_mask == 0 and game.state.removed.count(actor.id) == 1),"Only three original Wheel RETURN actors change through automatic activation/native combat"): return false
			if actor.hp > 0 and not expect(actor.collision_layer == 4 and actor.collision_mask == 7,"Living Wheel RETURN capsule stays native"): return false
		elif not expect(actor.position == prior.position and actor.rotation.y == prior.yaw and actor.active == prior.active and actor.alerted == prior.alerted and (actor.hp == 0 and actor.collision_layer == 0 and actor.collision_mask == 0 and game.state.removed.count(actor.id) == 1 if actor.id in H_IDS+Q_IDS+W_IDS else actor.hp == spec[2] and not actor.active and not actor.alerted and actor.collision_layer == 4 and actor.collision_mask == 7),"Original19 corpses and other9 inactive/fullHP/poses unchanged"): return false
	for id in v_markers:
		if game.v_consumed.has(id):
			if not expect(not route_level.markers.has(id) and game.state.removed.count(id) == 1,"Allowed original supply removed once"): return false
		elif not expect(route_level.markers.has(id) and v_markers[id].get_ref() == route_level.markers[id] and route_level.markers[id].get_parent() == route_level and not route_level.markers[id].is_queued_for_deletion() and not id in game.state.removed,"Every other original marker owner preserved: "+id): return false
	if not expect(route_level.markers.size() == v_markers.size()-game.v_consumed.size(),"No extra/replacement markers"): return false
	if not expect(game.v_melee_pending.is_empty(),"All native contact witnesses consumed synchronously"): return false
	return expect(game.budget() == game.v_resources() and game.state.health > 0 and game.state.health <= 100 and game.state.armor >= 0 and game.state.armor <= int(game.v_base.armor) and game.state.ammo[1] >= 0 and game.state.ammo[1] <= 180 and game.state.keys == ["blood","ivory"] and game.state.discoveries == [3] and game.state.removed == game.v_removed and game.state.checkpoint_id == "entry" and game.state.checkpoint == h_frozen.r_start and game.state.level_start == h_frozen.r_start and game.state.actors == v_actor_image and FileAccess.get_sha256(r_profile) == r_saved_sha and game.v_ticks >= east_elapsed()-2 and absf(route_player.active_play_time-v_time-float(east_elapsed())/60.0) <= 2.0/60.0,"Actual ammo/pickup/hurt ledger and earned Blood/story; original actor image/start/checkpoint/disk exact")
