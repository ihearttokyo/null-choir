extends "res://tests/test_reliquary_blood_story.gd"

const Q_BLOOD_SHA = "fb3c7286b7ddcca4944c2ae2ddcf48630fc69300f9227606e60e4a384d19b1fb"
const Q_IDS = ["reliquary_enemy_16","reliquary_enemy_17","reliquary_enemy_18"]
const Q_GROUP = {"id":"reliquary_halo_return","region":[16.5,10.0,18.5,13.0],"enemy_ids":Q_IDS,"requires":["blood"],"cue":{"text":"THE INDEX SENDS YOUR FACE AHEAD","light_ids":["reliquary_halo_return"],"sound":"seal_release"}}
const Q_PICKUPS = {"reliquary_halo_return_rivets":{"id":"reliquary_halo_return_rivets","kind":"ammo","cell":[15.5,11.5],"amount":45.0,"weapon":1.0},"reliquary_halo_return_shells":{"id":"reliquary_halo_return_shells","kind":"ammo","cell":[14.5,11.5],"amount":8.0,"weapon":2.0}}
const Q_CARRY = {"health":100,"armor":190,"ammo":[0,148,32,0,0,0],"owned_weapons":[0,1,2],"weapon":1}
const Q_APPROACH = [[1.5,17.5],[2.5,17.5],[4.5,17.5],[4.5,15.5],[4.5,13.5],[4.5,12.5],[7.5,12.5],[10.5,12.5],[12.5,12.5],[14.5,11.5],[15.5,11.5],[16.75,11.5]]
const Q_CLOSE = [[18.5,11.0],[19.0,11.0]]
# Three perfect pistol kills need13 hits/12*12.6=151.2 ticks; allow480 for real pursuit/role releases/misses, not guaranteed hits.
const Q_FIGHT_LIMIT = 480
const Q_IDLE = 6
const Q_LIMIT = 14*240+Q_FIGHT_LIMIT+Q_IDLE
const Q_SECONDS = float(Q_LIMIT)/60.0+2.0
const Q_BLOOD_FIELDS = ["b_ok","b_ticks","b_health_gain","b_health_calls","b_blood_calls","b_story_calls","b_removed","b_pending","b_inputs"]
const Q_FINAL_GUARD = "NATIVE RED Return requires actual Blood-gated region approach and Player fire, all3 provenanced native deaths, crawler/worker attacks and original central return closure"

class ReturnMain:
	extends "res://tests/test_reliquary_blood_story.gd".BloodMain
	var q_enabled: bool = false
	var q_ok: bool = true
	var q_ticks: int = 0
	var q_activation: int = 0
	var q_activated: Dictionary = {}
	var q_removed: Array = []
	var q_shots: Array = []
	var q_last: int = -1
	var q_slot: float = -1.0
	var q_last_time: float = -INF
	var q_shot_start_age: float = INF
	var q_shot_start_time: float = 0.0
	var q_rivets: int = 0
	var q_consumed: Dictionary = {}
	var q_rejected: Dictionary = {}
	var q_health_loss: int = 0
	var q_absorbed: int = 0
	var q_hurts: Array = []
	var q_attacks: Dictionary = {}
	var q_roles: Dictionary = {}
	var q_deaths: Dictionary = {}
	var q_finishes: Dictionary = {}
	var q_release: Dictionary = {}
	var q_melee_pending: Dictionary = {}
	var q_damage_attacks: Dictionary = {}
	func q_current() -> bool:
		return h_current() and not h_enabled and not b_enabled and q_enabled
	func q_original(actor) -> bool:
		return is_instance_valid(actor) and actor.get_script() == Enemy and actor.id in Q_IDS and h_bindings.get(actor.id,-1) == actor.get_instance_id() and actor._current_map() and actor.get_parent() == level and not actor.is_queued_for_deletion()
	func q_worker_contact(victim, repeat_ray: bool) -> bool:
		var source = q_release.get("source")
		if not q_original(source) or source.kind != "worker" or source.hp <= 0 or not source.active or q_release.get("tick",-1) != Engine.get_physics_frames() or not h_stack("/enemy.gd","_attack") or not h_stack("/enemy.gd","_release_attack"): return false
		var key: String = source.id+":"+str(q_release.tick)
		var hit: Dictionary = q_release.hit
		if q_damage_attacks.has(key) or hit.get("collider") != victim or hit.get("rid") != victim.get_rid() or victim.get_parent() != level: return false
		var origin: Vector3 = source.global_position+Vector3.UP*1.4
		var end: Vector3 = origin+(source._committed_aim-origin).normalized()*30.0
		if origin != q_release.origin or end != q_release.end: return false
		if repeat_ray:
			var query = PhysicsRayQueryParameters3D.create(origin,end,1|2|4)
			query.exclude = [source.get_rid()]
			query.hit_from_inside = true
			if level.get_world_3d().direct_space_state.intersect_ray(query) != hit: return false
		return true
	func q_crawler_contact(victim, repeat_ray: bool) -> bool:
		if q_melee_pending.is_empty(): return false
		var source = q_melee_pending.source
		var tick: int = q_melee_pending.release_tick
		var age: int = Engine.get_physics_frames()-tick
		if not q_original(source) or source.kind != "crawler" or source.hp <= 0 or not source.active or q_melee_pending.tick != Engine.get_physics_frames() or q_melee_pending.map != level or q_melee_pending.player != player or q_attacks.get(source.id,-1) != tick or age < 0 or age > 12 or q_damage_attacks.has(source.id+":"+str(tick)) or not h_stack("/enemy.gd","_try_melee") or not h_stack("/enemy.gd","_attack"): return false
		var hit: Dictionary = q_melee_pending.hit
		if hit.get("collider") != victim or hit.get("rid") != victim.get_rid() or victim.get_parent() != level: return false
		var intended = q_melee_pending.intended
		if not is_instance_valid(intended) or source._committed_target != intended or source.global_position.distance_to(intended.global_position) >= 1.9: return false
		var origin: Vector3 = source.global_position+Vector3.UP*0.6
		var end: Vector3 = intended.global_position+Vector3.UP*0.7
		if origin != q_melee_pending.origin or end != q_melee_pending.end: return false
		if repeat_ray:
			var query = PhysicsRayQueryParameters3D.create(origin,end,1|2|4)
			query.exclude = [source.get_rid()]
			query.hit_from_inside = true
			if level.get_world_3d().direct_space_state.intersect_ray(query) != hit: return false
		else:
			if q_melee_pending.victim_hp <= 0 or q_melee_pending.victim_hp > 12: return false
		return true
	func q_resources() -> Dictionary:
		return {"health":100-q_health_loss,"armor":190-q_absorbed,"ammo":[0,148+q_rivets-q_shots.size(),32,0,0,0],"owned_weapons":[0,1,2],"weapon":1}
	func _physics_process(delta: float) -> void:
		super._physics_process(delta)
		if not q_enabled: return
		q_ticks += 1
		q_ok = q_ok and q_current() and q_melee_pending.is_empty() and absf(delta-1.0/60.0) < 0.000001
		if not Input.is_action_pressed("fire"): q_slot = -1.0
	func shot(weapon: int) -> void:
		if q_enabled:
			var tick: int = Engine.get_physics_frames()
			q_slot = entry_slot(tick,q_last,q_slot,weapon)
			q_ok = q_ok and q_current() and q_activation == 1 and Engine.is_in_physics_frame() and weapon == 1 and state.weapon == 1 and Input.is_action_pressed("fire") and q_slot >= 0.0 and player.shot_age(1) == 0.0 and h_stack("/player.gd","fire") and player.active_play_time > q_last_time and (q_shots.size() > 0 or q_shot_start_age+player.active_play_time-q_shot_start_time+0.000001 >= 0.21)
			q_shots.append([tick,player.active_play_time,q_slot,player.cooldown,weapon])
			q_last = tick
			q_last_time = player.active_play_time
			q_ok = q_ok and budget() == q_resources() and state.ammo[1] >= 0 and state.ammo[1] <= 180 and player.cooldown > 0 and player.cooldown <= 0.21+0.000001
		super.shot(weapon)
	func collect_pickup(id: String) -> void:
		if not q_enabled:
			super.collect_pickup(id)
			return
		if not Q_PICKUPS.has(id):
			q_ok = false
			super.collect_pickup(id)
			return
		var spec: Dictionary = Q_PICKUPS[id]
		var before: Dictionary = q_resources()
		var slot: int = int(spec.weapon)
		var gain: int = mini(180 if slot == 1 else 32,int(before.ammo[slot])+int(spec.amount))-int(before.ammo[slot])
		var marker = level.markers.get(id)
		q_ok = q_ok and q_current() and Engine.is_in_physics_frame() and budget() == before and not id in state.removed and is_instance_valid(marker) and marker.get_parent() == level and not marker.is_queued_for_deletion() and level.layout.data.pickups.filter(func(item): return item.id == id) == [spec] and player.position.distance_to(level.layout.world_position(spec.cell)) < 1.4 and _passive_trigger_visible(spec) and h_stack("/main.gd","update_passive_triggers") and h_stack("/player.gd","_physics_process")
		super.collect_pickup(id)
		if gain > 0:
			q_ok = q_ok and slot == 1
			q_rivets += gain
			q_consumed[id] = q_consumed.get(id,0)+1
			q_removed.append(id)
			q_ok = q_ok and q_consumed[id] == 1 and not level.markers.has(id) and state.removed.count(id) == 1
		else:
			q_rejected[id] = q_rejected.get(id,0)+1
			q_ok = q_ok and level.markers.get(id) == marker and not marker.is_queued_for_deletion() and not id in state.removed
		q_ok = q_ok and budget() == q_resources() and state.removed == q_removed
	func activate_encounter(id: String) -> void:
		if not q_enabled:
			super.activate_encounter(id)
			return
		var prior: bool = "encounter:"+id in state.removed
		q_ok = q_ok and q_current() and id in ["reliquary_halo_commit",Q_GROUP.id]
		if not prior:
			var cell: Vector2 = Vector2(player.position.x,player.position.z)/4.0
			q_ok = q_ok and id == Q_GROUP.id and q_activation == 0 and state.keys == ["blood"] and cell.is_equal_approx(cell.clamp(Vector2(16.5,10),Vector2(18.5,13))) and h_stack("/main.gd","_process") and not h_stack("/enemy.gd","take_damage")
		super.activate_encounter(id)
		if not prior:
			q_activation += 1
			q_removed.append("encounter:"+id)
			for actor in enemies:
				if actor.id in Q_IDS:
					q_ok = q_ok and q_original(actor) and actor.active and actor.alerted and actor.hp == actor.max_hp
					q_activated[actor.id] = [actor.get_instance_id(),Engine.get_physics_frames()]
			q_ok = q_ok and q_activation == 1 and q_activated.size() == 3 and state.removed == q_removed
	func enemy_event(actor, event: String) -> void:
		if q_enabled:
			q_ok = q_ok and q_current() and Engine.is_in_physics_frame() and q_original(actor) and actor.active and q_activated.has(actor.id) and h_stack("/enemy.gd","_event")
			if event == "attack":
				q_attacks[actor.id] = Engine.get_physics_frames()
				q_roles[actor.kind] = q_roles.get(actor.kind,0)+1
				q_release = {"source":actor,"tick":Engine.get_physics_frames()}
				if actor.kind == "worker":
					var origin: Vector3 = actor.global_position+Vector3.UP*1.4
					var end: Vector3 = origin+(actor._committed_aim-origin).normalized()*30.0
					var query = PhysicsRayQueryParameters3D.create(origin,end,1|2|4)
					query.exclude = [actor.get_rid()]
					query.hit_from_inside = true
					q_release.merge({"origin":origin,"end":end,"hit":level.get_world_3d().direct_space_state.intersect_ray(query)})
			if event == "melee_contact":
				var intended = actor._committed_target
				var tick: int = int(q_attacks.get(actor.id,-1000))
				var age: int = Engine.get_physics_frames()-tick
				if not OS.is_debug_build() or actor.kind != "crawler" or actor.hp <= 0 or not q_melee_pending.is_empty() or not actor._valid_target(intended) or intended.get_parent() != level or actor.global_position.distance_to(intended.global_position) >= 1.9 or age < 0 or age > 12 or q_damage_attacks.has(actor.id+":"+str(tick)) or not h_stack("/enemy.gd","_try_melee") or not h_stack("/enemy.gd","_physics_process"):
					q_ok = false
				else:
					var origin: Vector3 = actor.global_position+Vector3.UP*0.6
					var end: Vector3 = intended.global_position+Vector3.UP*0.7
					var query = PhysicsRayQueryParameters3D.create(origin,end,1|2|4)
					query.exclude = [actor.get_rid()]
					query.hit_from_inside = true
					var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(query)
					var victim = hit.get("collider")
					if not origin.is_finite() or not end.is_finite() or not (victim == player or q_original(victim) and victim.hp > 0) or hit.get("rid") != victim.get_rid():
						q_ok = false
					elif victim == player or victim.hp <= 12:
						q_melee_pending = {"source":actor,"release_tick":tick,"tick":Engine.get_physics_frames(),"map":level,"player":player,"intended":intended,"origin":origin,"end":end,"hit":hit,"victim_hp":0 if victim == player else victim.hp}
			if event == "death":
				q_deaths[actor.id] = q_deaths.get(actor.id,0)+1
				var player_fire: bool = actor.target == player and q_last == Engine.get_physics_frames() and player.shot_age(1) == 0.0 and Input.is_action_pressed("fire") and h_stack("/player.gd","fire") and aim_observation.get("actor_id","") == actor.id and aim_observation.get("tick",-1) == Engine.get_physics_frames() and aim_observation.get("level") == level and aim_observation.get("player") == player and aim_observation.get("weapon",-1) == 1
				var worker: bool = q_worker_contact(actor,false)
				var crawler: bool = q_crawler_contact(actor,false)
				if worker: q_damage_attacks[q_release.source.id+":"+str(q_release.tick)] = true
				if crawler:
					q_damage_attacks[q_melee_pending.source.id+":"+str(q_melee_pending.release_tick)] = true
					q_melee_pending.clear()
				q_finishes[actor.id] = "player" if player_fire else "infighting" if worker or crawler else "unproven"
				q_removed.append(actor.id)
				q_ok = q_ok and actor.hp == 0 and actor.collision_layer == 0 and actor.collision_mask == 0 and state.removed.count(actor.id) == 1 and q_deaths[actor.id] == 1 and (player_fire or worker or crawler) and state.removed == q_removed
		super.enemy_event(actor,event)
	func hurt_player(amount: int) -> void:
		if not q_enabled:
			super.hurt_player(amount)
			return
		var worker: bool = amount == 10 and q_worker_contact(player,true)
		var crawler: bool = amount == 12 and q_crawler_contact(player,true)
		q_ok = q_ok and q_current() and Engine.is_in_physics_frame() and state.difficulty == 1 and (worker or crawler) and budget() == q_resources()
		var source_id: String = "unproven"
		if worker:
			source_id = q_release.source.id
			q_damage_attacks[source_id+":"+str(q_release.tick)] = true
		if crawler:
			source_id = q_melee_pending.source.id
			q_damage_attacks[source_id+":"+str(q_melee_pending.release_tick)] = true
			q_melee_pending.clear()
		var absorbed: int = mini(190-q_absorbed,int(amount/3))
		q_absorbed += absorbed
		q_health_loss += amount-absorbed
		q_hurts.append([Engine.get_physics_frames(),source_id,amount,absorbed])
		super.hurt_player(amount)
		q_ok = q_ok and budget() == q_resources()
	func interact() -> void:
		if q_enabled: q_ok = false
		super.interact()
	func collect_key(id: String) -> void:
		if q_enabled: q_ok = false
		super.collect_key(id)
	func unlock_door(id: String) -> bool:
		if q_enabled: q_ok = false
		return super.unlock_door(id)
	func _capture_actor_state() -> bool:
		if q_enabled: q_ok = false
		return super._capture_actor_state()
	func _save() -> Error:
		if q_enabled: q_ok = false
		return super._save()
	func _debug_projectile_event(projectile: Node3D, event: String, data: Dictionary) -> void:
		if q_enabled: q_ok = false
		super._debug_projectile_event(projectile,event,data)

var q_started: bool = false
var q_epoch: int = 0
var q_wall: int = 0
var q_fields: Array = []
var q_frozen: Dictionary = {}
var q_actors: Array = []
var q_markers: Dictionary = {}
var q_time: float = 0.0
var q_actor_image: Variant
var q_closed: bool = false
var q_fighting: bool = false

func run() -> void:
	if not await walk_through_halo_return(ReturnMain.new()):
		await finish(1)
		return
	print("PASS source-native virtual-input original west Halo return from earned Blood/story; not full-fourth/eight, physical controls, rendered/audio/performance or standalone acceptance")
	await finish(0)

func walk_through_halo_return(observer: ReturnMain, profile_prefix: String = "") -> bool:
	if not expect(FileAccess.get_sha256("res://tests/test_reliquary_blood_story.gd") == Q_BLOOD_SHA,"Exact next-slice Blood extraction; reconcile parent adoption and source pins"):
		if is_instance_valid(observer) and observer != game and not observer.is_inside_tree(): observer.free()
		return false
	if not await walk_through_blood_story(observer,profile_prefix if not profile_prefix.is_empty() else "user://reliquary_halo_return_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())) or not start_return():
		return false
	if not "--omit-return-approach" in OS.get_cmdline_user_args():
		if not await blood_story_route(Q_APPROACH):
			return false
	q_fighting = true
	for frame in range(Q_FIGHT_LIMIT):
		if game.q_deaths.size() == 3 or game.state.health <= 24: break
		release_actions()
		east_fire()
		if not await route_tick():
			return false
	q_fighting = false
	release_actions()
	# Omitted inputs reach the same final guard, never a blocked closure/setup surrogate.
	if game.q_activation == 1 and game.q_deaths.size() == 3:
		if not await blood_story_route(Q_CLOSE):
			return false
		q_closed = true
	for idle in range(Q_IDLE):
		if not await route_tick():
			return false
	await process_frame
	if not return_result():
		return false
	return true

func start_return() -> bool:
	if not expect(game is ReturnMain and game.b_enabled and game.b_ok and blood_story_result() and game.budget() == Q_CARRY and route_player.position.distance_to(route_level.layout.world_position(B_STORY.cell)) < 0.2,"Accepted actual Blood/story boundary at original story location, not respawn/cloned state"): return false
	if not expect(Q_LIMIT == (Q_APPROACH.size()+Q_CLOSE.size())*HOP_LIMIT+Q_FIGHT_LIMIT+Q_IDLE,"Fresh14 fixed hops+480 fight+6 idle bound, no blanket deadline inflation"): return false
	if not expect(route_level.layout.data.encounters.filter(func(item): return item.id == Q_GROUP.id) == [Q_GROUP],"Original Blood-gated3 actor return region and cue"): return false
	for id in Q_PICKUPS:
		if not expect(route_level.layout.data.pickups.filter(func(spec): return spec.id == id) == [Q_PICKUPS[id]] and route_level.markers.has(id),"Original finite return supply: "+id): return false
	for actor in game.enemies:
		q_actors.append({"instance":actor.get_instance_id(),"age":actor.age,"position":actor.position,"yaw":actor.rotation.y,"active":actor.active,"alerted":actor.alerted,"shape_disabled":(actor.get_child(0) as CollisionShape3D).disabled})
	for id in route_level.markers: q_markers[id] = weakref(route_level.markers[id])
	q_fields = b_fields+Q_BLOOD_FIELDS
	q_frozen = observer_witness(q_fields)
	q_actor_image = game.state.actors.duplicate(true) if game.state.actors is Array else game.state.actors
	game.q_removed = game.state.removed.duplicate()
	q_time = route_player.active_play_time
	game.q_shot_start_time = q_time
	game.q_shot_start_age = route_player.shot_age(1)
	release_actions()
	# Only the completed Blood observer retires; all native supers remain unconditional.
	game.b_enabled = false
	q_epoch = Engine.get_physics_frames()
	q_wall = Time.get_ticks_usec()
	game.q_enabled = true
	q_started = true
	return live_route()

func east_elapsed() -> int:
	return Engine.get_physics_frames()-q_epoch if q_started else super.east_elapsed()

func route_tick() -> bool:
	if not q_started: return await super.route_tick()
	if not live_route(): return false
	await physics_frame
	return live_route()

func east_fire() -> bool:
	if not q_started: return super.east_fire()
	Input.action_release("fire")
	if not q_fighting or game.q_activation != 1 or "--omit-return-fire" in OS.get_cmdline_user_args() or game.state.weapon != 1: return false
	var selected = null
	var nearest: float = 140.0
	for actor in game.enemies:
		if not game.q_original(actor) or not actor.active or actor.hp <= 0: continue
		if game.q_roles.get(actor.kind,0) == 0 and game.enemies.filter(func(other): return game.q_original(other) and other.kind == actor.kind and other.hp > 0).size() == 1: continue
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
	if not q_started: return super.clear_point(cell)
	if cell[0] < 0.0 or cell[0] > 19.0 or cell[1] < 10.0 or cell[1] > 18.0: return null
	var layout = route_level.layout
	if not layout.is_walkable(Vector2i(floori(cell[0]),floori(cell[1]))): return null
	var point: Vector3 = layout.world_position(cell)
	var space = route_level.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*2.0,point-Vector3.UP*0.5,1))
	if not hit.is_empty() and absf(hit.position.y-point.y) <= 0.08 and hit.normal.y >= 0.7:
		var collider: CollisionShape3D = route_player.get_child(0)
		var pose: Vector3 = point+Vector3.UP*0.04
		var query = PhysicsShapeQueryParameters3D.new()
		query.shape = collider.shape
		query.transform = Transform3D(Basis.IDENTITY,pose+collider.position)
		query.collision_mask = route_player.collision_mask
		query.exclude = [route_player.get_rid()]
		return pose if space.intersect_shape(query,1).is_empty() else null
	return null

func live_route() -> bool:
	if not q_started: return super.live_route()
	if not expect(east_elapsed() <= Q_LIMIT and Time.get_ticks_usec()-q_wall <= Q_SECONDS*1000000,"Fresh Return epoch/bounds independent of all completed phases"): return false
	if not expect(game.q_ok and game.q_current() and not paused and game.get_instance_id() == r_main_id and game.state.get_instance_id() == r_campaign_id and game.progress_path == r_profile and game.settings_path == game.r_settings_origin and game.level == route_level and game.player == route_player and not game.loaded_positions and game.is_processing() and game.is_physics_processing() and route_player.is_physics_processing() and route_player.position.is_finite() and game.enemies.size() == 31 and game.scene_roster_matches(),"Same native Main/Campaign/profile/Player/original31; no recovery, unregistered actor or scene replacement"): return false
	if not expect(observer_witness(q_fields) == q_frozen and observer_witness(b_fields) == b_frozen and observer_witness(h_fields) == h_frozen and observers_retired() and not game.h_enabled and not game.b_enabled and retired.all(func(ref): return ref.get_ref() == null) and x_marker_refs.values().all(func(ref): return ref.get_ref() == null),"All accepted prefix/Halo/Blood history frozen, only Blood observer retired"): return false
	for index in range(R_ACTORS.size()):
		var spec: Array = R_ACTORS[index]
		var actor = game.enemies[index]
		var prior: Dictionary = q_actors[index]
		if not expect(is_instance_valid(actor) and actor.id == spec[0] and actor.get_instance_id() == prior.instance and actor.get_instance_id() == game.h_bindings[actor.id] and actor.get_script() == game.Enemy and actor.kind == spec[1] and actor.max_hp == spec[2] and actor._current_map() and actor.is_physics_processing() and actor.age-prior.age >= float(east_elapsed()-2)/60.0 and (actor.get_child(0) as CollisionShape3D).disabled == prior.shape_disabled,"Original native identity/age/capsule: "+spec[0]): return false
		if actor.id in Q_IDS:
			if game.q_activation == 0 and not expect(actor.hp == spec[2] and actor.position == prior.position and actor.rotation.y == prior.yaw and not actor.alerted,"Return actors retain original fullHP/pose until real region activation"): return false
			if not expect(game.q_original(actor) and actor.hp >= 0 and actor.hp <= spec[2] and actor.active == (game.q_activation == 1) and actor.alerted == (game.q_activation == 1) and (actor.hp > 0 or game.q_deaths.get(actor.id,0) == 1 and game.q_finishes.get(actor.id,"unproven") in ["player","infighting"] and actor.collision_layer == 0 and actor.collision_mask == 0 and game.state.removed.count(actor.id) == 1),"Only three original return actors change through automatic activation/native combat"): return false
			if actor.hp > 0 and not expect(actor.collision_layer == 4 and actor.collision_mask == 7,"Living return capsule stays native"): return false
		elif not expect(actor.position == prior.position and actor.rotation.y == prior.yaw and actor.active == prior.active and actor.alerted == prior.alerted and (actor.hp == 0 and actor.collision_layer == 0 and actor.collision_mask == 0 and game.state.removed.count(actor.id) == 1 if actor.id in H_IDS else actor.hp == spec[2] and not actor.active and not actor.alerted and actor.collision_layer == 4 and actor.collision_mask == 7),"Original8 corpses and other20 inactive/fullHP/poses unchanged"): return false
	for id in q_markers:
		if game.q_consumed.has(id):
			if not expect(not route_level.markers.has(id) and game.state.removed.count(id) == 1,"Allowed original supply removed once"): return false
		elif not expect(route_level.markers.has(id) and q_markers[id].get_ref() == route_level.markers[id] and not route_level.markers[id].is_queued_for_deletion() and not id in game.state.removed,"Every other original marker owner preserved: "+id): return false
	if not expect(route_level.markers.size() == q_markers.size()-game.q_consumed.size(),"No extra/replacement markers"): return false
	return expect(game.budget() == game.q_resources() and game.state.health > 0 and game.state.health <= 100 and game.state.armor >= 0 and game.state.armor <= 190 and game.state.ammo[1] >= 0 and game.state.ammo[1] <= 180 and game.state.keys == ["blood"] and game.state.discoveries == [3] and game.state.removed == game.q_removed and game.state.checkpoint_id == "entry" and game.state.checkpoint == h_frozen.r_start and game.state.level_start == h_frozen.r_start and game.state.actors == q_actor_image and FileAccess.get_sha256(r_profile) == r_saved_sha and game.q_ticks >= east_elapsed()-2 and absf(route_player.active_play_time-q_time-float(east_elapsed())/60.0) <= 2.0/60.0,"Actual ammo/pickup/hurt ledger and earned Blood/story; original actor image/start/checkpoint/disk exact")

func return_result() -> bool:
	print("RELIQUARY_HALO_RETURN_LIMIT frames=",east_elapsed()," wall_us=",Time.get_ticks_usec()-q_wall," position=",route_player.position," resources=",game.q_resources()," shots=",game.q_shots," consumed=",game.q_consumed," rejected=",game.q_rejected," roles=",game.q_roles," hurts=",game.q_hurts," deaths=",game.q_deaths," provenance=",game.q_finishes)
	return live_route() and expect(game.q_activation == 1 and game.q_activated.size() == 3 and Q_IDS.all(func(id): return game.q_activated.has(id) and game.q_deaths.get(id,0) == 1 and game.q_finishes.get(id,"unproven") in ["player","infighting"]) and game.q_deaths.size() == 3 and ["crawler","worker"].all(func(role): return game.q_roles.get(role,0) > 0) and game.q_shots.size() > 0 and game.q_melee_pending.is_empty() and q_closed and route_player.position.distance_to(route_level.layout.world_position(Q_CLOSE.back())) < 0.2 and game.q_consumed == {"reliquary_halo_return_rivets":1} and game.q_rivets == 32 and q_markers["reliquary_halo_return_rivets"].get_ref() == null and game.q_rejected.get("reliquary_halo_return_shells",0) > 0 and q_markers["reliquary_halo_return_shells"].get_ref() == route_level.markers.get("reliquary_halo_return_shells"),Q_FINAL_GUARD)
