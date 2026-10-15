extends "res://tests/test_reliquary_catalogue.gd"

const E_CATALOGUE_SHA = "f8b9ef72b8728fd0fc055a1af3c4d4689a0a4450126aa6976740784ed6eff063"
const E_IDS = ["reliquary_enemy_27","reliquary_enemy_28","reliquary_enemy_29","reliquary_enemy_30"]
const E_GROUP = {"id":"reliquary_exit","region":[18.0,2.7,20.9,6.5],"enemy_ids":E_IDS,"requires":["blood","ivory"],"cue":{"text":"THE ARCHIVE HAS FILED YOUR ARRIVAL","light_ids":["reliquary_exit_feed"],"sound":"seal_release"}}
const E_DOOR = {"id":"reliquary_index_gate","cell":[19.5,7.7],"size":[12.2,5.0,0.6],"requires":["blood","ivory"],"yaw":0.0}
const E_CHECKPOINT = {"id":"reliquary_checkpoint","kind":"checkpoint","cell":[19.5,10.5],"requires":["blood","ivory"],"text":"RECOVERY IMAGE STORED"}
const E_DESCENT = {"id":"reliquary_descent","kind":"exit","cell":[19.5,3.5],"requires":["blood","ivory"],"text":"MEMORY INDEX RESTORED / DESCEND"}
const E_PICKUPS = {
	"reliquary_exit_health":{"id":"reliquary_exit_health","kind":"health","cell":[18.5,11.5],"amount":30.0},
	"reliquary_exit_rivets":{"id":"reliquary_exit_rivets","kind":"ammo","cell":[19.5,10.5],"amount":40.0,"weapon":1.0}}
const E_CARRY = {"health":86,"armor":178,"ammo":[0,147,32,0,0,0],"owned_weapons":[0,1,2],"weapon":1}
const E_ROUTE_A = [[19.5,10.5],[19.5,8.6]]
const E_ROUTE_B = [[18.5,11.5],[19.5,10.5],[19.5,8.6]]
const E_APPROACH = [[19.5,6.25]]
const E_CLOSE = [[19.5,3.5]]
const E_SHOT_CAP = 48
const E_FIGHT_LIMIT = 720
const E_DRAIN = 246
const E_INPUT_LIMIT = 6
const E_GATE_WAIT = 60
const E_MENU_WAIT = 12
const E_EARNING_GUARD = "NATIVE RED Reliquary descent requires all31 CURRENT original HP zero/retired collisions and all4 provenanced native deaths, not retained records alone"
const E_GATE_GUARD = "NATIVE RED Reliquary gate requires real Player Input, both seals, original door retirement and independent checkpoint save"
const E_ACTIVATION_GUARD = "NATIVE RED Reliquary Exit4 requires actual original both-seal region-driven activation"
const E_C_FIELDS = ["c_base", "c_pickup_calls", "c_ok", "c_ticks", "c_shots", "c_last", "c_slot", "c_last_time", "c_shot_start_age", "c_shot_start_time", "c_health_loss", "c_absorbed", "c_removed", "c_activation", "c_activated", "c_attacks", "c_roles", "c_damage_attacks", "c_hurts", "c_deaths", "c_finishes", "c_births", "c_contacts", "c_projectile_used", "c_pending", "c_release", "c_melee_pending", "c_enemy_contacts", "c_enemy_pending", "c_enemy_used"]

class ReliquaryExitMain:
	extends "res://tests/test_reliquary_catalogue.gd".CatalogueMain
	var e_enabled: bool = false
	var e_base: Dictionary = {}
	var e_pickup_calls: Array = []
	var e_ok: bool = true
	var e_ticks: int = 0
	var e_shots: Array = []
	var e_last: int = -1
	var e_slot: float = -1.0
	var e_last_time: float = -INF
	var e_shot_start_age: float = INF
	var e_shot_start_time: float = 0.0
	var e_health_loss: int = 0
	var e_absorbed: int = 0
	var e_removed: Array = []
	var e_activation: int = 0
	var e_activated: Dictionary = {}
	var e_attacks: Dictionary = {}
	var e_roles: Dictionary = {}
	var e_damage_attacks: Dictionary = {}
	var e_hurts: Array = []
	var e_deaths: Dictionary = {}
	var e_finishes: Dictionary = {}
	var e_births: Dictionary = {}
	var e_contacts: Dictionary = {}
	var e_projectile_used: Dictionary = {}
	var e_pending: Dictionary = {}
	var e_release: Dictionary = {}
	var e_melee_pending: Dictionary = {}
	var e_enemy_contacts: Dictionary = {}
	var e_enemy_pending: Dictionary = {}
	var e_enemy_used: Dictionary = {}
	func e_current() -> bool:
		return h_current() and not h_enabled and not b_enabled and not q_enabled and not w_enabled and not v_enabled and not c_enabled and e_enabled and not e_completed
	func e_resources() -> Dictionary:
		return {"health":e_base.health+e_health_gain-e_health_loss,"armor":e_base.armor-e_absorbed,"ammo":[0,int(e_base.ammo[1])+e_rivets-e_shots.size(),32,0,0,0],"owned_weapons":[0,1,2],"weapon":1}
	func e_original(actor) -> bool:
		return is_instance_valid(actor) and actor.get_script() == Enemy and actor.id in E_IDS and h_bindings.get(actor.id,-1) == actor.get_instance_id() and actor._current_map() and actor.get_parent() == level and not actor.is_queued_for_deletion()
	func e_worker_contact(victim, repeat_ray: bool) -> bool:
		var source = e_release.get("source")
		if not e_original(source) or source.kind != "worker" or source.hp <= 0 or not source.active or e_release.get("tick",-1) != Engine.get_physics_frames() or not h_stack("/enemy.gd","_attack") or not h_stack("/enemy.gd","_release_attack"): return false
		var key: String = source.id+":"+str(e_release.tick)
		var hit: Dictionary = e_release.hit
		if e_damage_attacks.has(key) or hit.get("collider") != victim or hit.get("rid") != victim.get_rid() or victim.get_parent() != level: return false
		var origin: Vector3 = source.global_position+Vector3.UP*1.4
		var end: Vector3 = origin+(source._committed_aim-origin).normalized()*30.0
		if origin != e_release.origin or end != e_release.end: return false
		if repeat_ray:
			var query = PhysicsRayQueryParameters3D.create(origin,end,1|2|4)
			query.exclude = [source.get_rid()]
			query.hit_from_inside = true
			if level.get_world_3d().direct_space_state.intersect_ray(query) != hit: return false
		return true
	func e_crawler_contact(victim, repeat_ray: bool) -> bool:
		if e_melee_pending.is_empty(): return false
		var source = e_melee_pending.source
		var tick: int = e_melee_pending.release_tick
		var age: int = Engine.get_physics_frames()-tick
		if not e_original(source) or source.kind != "crawler" or source.hp <= 0 or not source.active or e_melee_pending.tick != Engine.get_physics_frames() or e_melee_pending.map != level or e_melee_pending.player != player or e_attacks.get(source.id,-1) != tick or age < 0 or age > 12 or e_damage_attacks.has(source.id+":"+str(tick)) or not h_stack("/enemy.gd","_try_melee") or not h_stack("/enemy.gd","_attack"): return false
		var hit: Dictionary = e_melee_pending.hit
		if hit.get("collider") != victim or hit.get("rid") != victim.get_rid() or victim.get_parent() != level: return false
		var intended = e_melee_pending.intended
		if not is_instance_valid(intended) or source._committed_target != intended or source.global_position.distance_to(intended.global_position) >= 1.9: return false
		var origin: Vector3 = source.global_position+Vector3.UP*0.6
		var end: Vector3 = intended.global_position+Vector3.UP*0.7
		if origin != e_melee_pending.origin or end != e_melee_pending.end: return false
		if repeat_ray:
			var query = PhysicsRayQueryParameters3D.create(origin,end,1|2|4)
			query.exclude = [source.get_rid()]
			query.hit_from_inside = true
			if level.get_world_3d().direct_space_state.intersect_ray(query) != hit: return false
		else:
			if e_melee_pending.victim_hp <= 0 or e_melee_pending.victim_hp > 12: return false
		return true
	func e_projectile_death(victim) -> bool:
		if e_enemy_pending.is_empty(): return false
		var id: int = e_enemy_pending.id
		var data: Dictionary = e_enemy_pending.data
		var projectile = data.projectile
		if not e_births.has(id) or not e_enemy_contacts.has(id) or e_enemy_used.has(id) or not is_instance_valid(projectile): return false
		var birth: Dictionary = e_births[id]
		return data.tick == Engine.get_physics_frames() and data.hit.collider == victim and data.hit.rid == victim.get_rid() and data.victim_id == victim.get_instance_id() and data.victim_hp > 0 and data.victim_hp <= 14 and data.map == level and data.player == player and birth.source == data.source and birth.reference.get_ref() == projectile and e_original(data.source) and projectile.shooter == data.source and projectile.is_queued_for_deletion() and projectile._current_map() and h_stack("/projectile.gd","_physics_process") and h_stack("/enemy.gd","take_damage")
	func _physics_process(delta: float) -> void:
		super._physics_process(delta)
		if not e_enabled or e_completed: return
		if not e_current():
			e_ok = false
			return
		e_survey()
		e_ok = e_ok and e_enemy_pending.is_empty() and e_melee_pending.is_empty() and e_current() and absf(delta-1.0/60.0) < 0.000001
		e_ticks += 1
		if not Input.is_action_pressed("fire"): e_slot = -1.0
	func shot(weapon: int) -> void:
		if e_enabled:
			var tick: int = Engine.get_physics_frames()
			e_slot = entry_slot(tick,e_last,e_slot,weapon)
			var elapsed: float = player.active_play_time-e_shot_start_time
			e_ok = e_ok and e_current() and Engine.is_in_physics_frame() and not player._fire_release_required and player._last_shots[1] == player.active_play_time and weapon == 1 and state.weapon == 1 and Input.is_action_pressed("fire") and e_slot >= 0.0 and player.shot_age(1) == 0.0 and h_stack("/player.gd","fire") and player.active_play_time > e_last_time and (e_shots.size() > 0 or e_shot_start_age+elapsed+0.000001 >= 0.21)
			e_ok = e_ok and e_activation == 1 and e_shots.size() < E_SHOT_CAP
			e_shots.append([tick,player.active_play_time,e_slot,player.cooldown,weapon])
			e_last = tick
			e_last_time = player.active_play_time
			e_ok = e_ok and budget() == e_resources() and state.ammo[1] >= 0 and state.ammo[1] <= 180 and player.cooldown > 0 and player.cooldown <= 0.21+0.000001
		super.shot(weapon)
	func collect_pickup(id: String) -> void:
		if not e_enabled:
			super.collect_pickup(id)
			return
		var before: Dictionary = e_resources()
		var spec: Dictionary = E_PICKUPS.get(id,{})
		if spec.is_empty():
			e_ok = false
			super.collect_pickup(id)
			return
		var health: bool = spec.kind == "health"
		var old: int = before.health if health else before.ammo[1]
		var gain: int = mini(100 if health else 180,old+int(spec.amount))-old
		var marker = level.markers.get(id)
		e_pickup_calls.append([id,Engine.get_physics_frames(),before.duplicate(true),gain])
		e_ok = e_ok and e_current() and Engine.is_in_physics_frame() and budget() == before and gain > 0 and not e_consumed.has(id) and e_activation == 0 and e_shots.is_empty() and e_hurts.is_empty() and is_instance_valid(marker) and marker.get_parent() == level and not marker.is_queued_for_deletion() and level.layout.data.pickups.filter(func(item): return item.id == id) == [spec] and player.position.distance_to(level.layout.world_position(spec.cell)) < 1.4 and _passive_trigger_visible(spec) and h_stack("/main.gd","update_passive_triggers") and h_stack("/player.gd","_physics_process")
		if health:
			e_ok = e_ok and e_route_b and gain == 14 and e_consumed.is_empty()
			e_health_gain += gain
		else:
			e_ok = e_ok and gain == 33 and e_health_gain == (14 if e_route_b else 0)
			e_rivets += gain
		super.collect_pickup(id)
		e_consumed[id] = 1
		e_removed.append(id)
		e_ok = e_ok and budget() == e_resources() and not level.markers.has(id) and state.removed == e_removed and state.removed.count(id) == 1
	func activate_encounter(id: String) -> void:
		if not e_enabled:
			super.activate_encounter(id)
			return
		var prior: bool = "encounter:"+id in state.removed
		e_ok = e_ok and e_current() and (prior or id == E_GROUP.id)
		if not prior:
			var cell: Vector2 = Vector2(player.position.x,player.position.z)/4.0
			e_ok = e_ok and id == E_GROUP.id and e_activation == 0 and state.keys == ["blood","ivory"] and cell.is_equal_approx(cell.clamp(Vector2(18,2.7),Vector2(20.9,6.5))) and h_stack("/main.gd","_process") and not h_stack("/enemy.gd","take_damage")
		super.activate_encounter(id)
		if not prior:
			e_activation += 1
			e_removed.append("encounter:"+id)
			for actor in enemies:
				if actor.id in E_IDS:
					e_ok = e_ok and e_original(actor) and actor.active and actor.alerted and actor.hp == actor.max_hp
					e_activated[actor.id] = [actor.get_instance_id(),Engine.get_physics_frames()]
			e_ok = e_ok and e_activation == 1 and e_activated.size() == 4 and state.removed == e_removed and message == E_GROUP.cue.text
	func enemy_event(actor, event: String) -> void:
		e_observe_enemy(actor,event)
		super.enemy_event(actor,event)
	func e_observe_enemy(actor, event: String) -> void:
		if e_enabled:
			e_ok = e_ok and e_current() and Engine.is_in_physics_frame() and e_original(actor) and actor.active and e_activated.has(actor.id) and h_stack("/enemy.gd","_event")
			if event == "attack":
				e_attacks[actor.id] = Engine.get_physics_frames()
				e_roles[actor.kind] = e_roles.get(actor.kind,0)+1
				e_release = {"source":actor,"tick":Engine.get_physics_frames()}
				if actor.kind == "worker":
					var origin: Vector3 = actor.global_position+Vector3.UP*1.4
					var end: Vector3 = origin+(actor._committed_aim-origin).normalized()*30.0
					var query = PhysicsRayQueryParameters3D.create(origin,end,1|2|4)
					query.exclude = [actor.get_rid()]
					query.hit_from_inside = true
					e_release.merge({"origin":origin,"end":end,"hit":level.get_world_3d().direct_space_state.intersect_ray(query)})
			if event == "melee_contact":
				var intended = actor._committed_target
				var tick: int = int(e_attacks.get(actor.id,-1000))
				var age: int = Engine.get_physics_frames()-tick
				if not OS.is_debug_build() or actor.kind != "crawler" or actor.hp <= 0 or not e_melee_pending.is_empty() or not actor._valid_target(intended) or intended.get_parent() != level or actor.global_position.distance_to(intended.global_position) >= 1.9 or age < 0 or age > 12 or e_damage_attacks.has(actor.id+":"+str(tick)) or not h_stack("/enemy.gd","_try_melee") or not h_stack("/enemy.gd","_physics_process"):
					e_ok = false
					return
				var origin: Vector3 = actor.global_position+Vector3.UP*0.6
				var end: Vector3 = intended.global_position+Vector3.UP*0.7
				var query = PhysicsRayQueryParameters3D.create(origin,end,1|2|4)
				query.exclude = [actor.get_rid()]
				query.hit_from_inside = true
				var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(query)
				var victim = hit.get("collider")
				if not origin.is_finite() or not end.is_finite() or not (victim == player or e_original(victim) and victim.hp > 0) or hit.get("rid") != victim.get_rid():
					e_ok = false
					return
				if victim == player or victim.hp <= 12:
					e_melee_pending = {"source":actor,"release_tick":tick,"tick":Engine.get_physics_frames(),"map":level,"player":player,"intended":intended,"origin":origin,"end":end,"hit":hit,"victim_hp":0 if victim == player else victim.hp}
			if event == "death":
				e_deaths[actor.id] = e_deaths.get(actor.id,0)+1
				var player_fire: bool = actor.target == player and e_last == Engine.get_physics_frames() and player.shot_age(1) == 0.0 and Input.is_action_pressed("fire") and h_stack("/player.gd","fire") and aim_observation.get("actor_id","") == actor.id and aim_observation.get("tick",-1) == Engine.get_physics_frames() and aim_observation.get("level") == level and aim_observation.get("player") == player and aim_observation.get("weapon",-1) == 1
				var worker: bool = e_worker_contact(actor,false)
				var caster: bool = e_projectile_death(actor)
				var crawler: bool = e_crawler_contact(actor,false)
				var infighting: bool = worker or caster or crawler
				if crawler:
					e_damage_attacks[e_melee_pending.source.id+":"+str(e_melee_pending.release_tick)] = true
					e_melee_pending.clear()
				if worker: e_damage_attacks[e_release.source.id+":"+str(e_release.tick)] = true
				if caster:
					e_enemy_used[e_enemy_pending.id] = true
					e_enemy_pending.clear()
				e_finishes[actor.id] = "player" if player_fire else "infighting" if infighting else "unproven"
				e_removed.append(actor.id)
				e_ok = e_ok and actor.hp == 0 and actor.collision_layer == 0 and actor.collision_mask == 0 and state.removed.count(actor.id) == 1 and e_deaths[actor.id] == 1 and (player_fire or infighting) and state.removed == e_removed
	func _debug_projectile_event(projectile: Node3D, event: String, data: Dictionary) -> void:
		if e_enabled: e_observe_projectile(projectile,event,data)
		super._debug_projectile_event(projectile,event,data)
	func e_observe_projectile(projectile: Node3D, event: String, data: Dictionary) -> void:
		var source = projectile.shooter
		var id: int = projectile.get_instance_id()
		e_ok = e_ok and e_current() and OS.is_debug_build() and Engine.is_in_physics_frame() and projectile.get_script() == preload("res://scripts/projectile.gd") and projectile.game == self and projectile._current_map() and projectile.is_physics_processing() and e_original(source) and source.id == "reliquary_enemy_30" and source.kind == "caster" and data.get("projectile") == projectile and data.get("source") == source and data.get("map") == level and data.get("player") == player and data.get("tick",-1) == Engine.get_physics_frames() and data.get("position") == projectile.global_position and data.get("velocity") == projectile.velocity and data.get("lifetime") == projectile.lifetime and projectile.blast_damage == 0 and data.get("blast_damage") == 0 and projectile.velocity.is_finite() and is_equal_approx(projectile.velocity.length(),12.0) and projectile.lifetime > 0 and projectile.lifetime <= 4.0
		if event == "configured_birth":
			e_ok = e_ok and not e_births.has(id) and source.hp > 0 and source.active and e_attacks.get(source.id,-1) == Engine.get_physics_frames() and projectile.lifetime == 4.0 and not projectile.is_queued_for_deletion() and data.get("origin") is Vector3 and data.get("destination") is Vector3 and h_stack("/enemy.gd","_release_attack")
			if data.get("origin") is Vector3 and data.get("destination") is Vector3:
				e_ok = e_ok and data.origin.is_finite() and data.destination.is_finite() and data.origin == projectile.global_position and projectile.velocity.is_equal_approx((data.destination-data.origin).normalized()*12.0)
			e_births[id] = {"source":source,"tick":Engine.get_physics_frames(),"reference":weakref(projectile),"map":level,"player":player}
			return
		if not event in ["queued_player_contact","queued_enemy_contact"] or not e_births.has(id) or e_contacts.has(id) or e_enemy_contacts.has(id) or not e_pending.is_empty() or not e_enemy_pending.is_empty() or not (data.get("hit") is Dictionary and data.get("ray_start") is Vector3 and data.get("ray_end") is Vector3):
			e_ok = false
			return
		var birth: Dictionary = e_births[id]
		var hit: Dictionary = data.hit
		var victim = hit.get("collider")
		var victim_ok: bool = victim == player if event == "queued_player_contact" else e_original(victim) and victim != source and victim.hp > 0
		if not victim_ok:
			e_ok = false
			return
		e_ok = e_ok and source == birth.source and birth.reference.get_ref() == projectile and birth.map == level and birth.player == player and projectile.is_queued_for_deletion() and data.tick >= birth.tick and data.tick-birth.tick <= 241 and hit.get("rid") == victim.get_rid() and hit.get("position") == projectile.global_position and data.ray_start.is_finite() and data.ray_end.is_finite() and data.ray_end.is_equal_approx(data.ray_start+projectile.velocity*minf(1.0/60.0,projectile.lifetime)) and h_stack("/projectile.gd","_physics_process")
		var query = PhysicsRayQueryParameters3D.create(data.ray_start,data.ray_end,1|2|4)
		query.exclude = [source.get_rid()]
		query.hit_from_inside = true
		e_ok = e_ok and level.get_world_3d().direct_space_state.intersect_ray(query) == hit
		if event == "queued_player_contact":
			e_contacts[id] = data.duplicate(true)
			e_pending = {"id":id,"data":data.duplicate(true)}
		else:
			var contact: Dictionary = data.duplicate(true)
			contact.merge({"victim_id":victim.get_instance_id(),"victim_hp":victim.hp})
			e_enemy_contacts[id] = contact
			if victim.hp <= 14: e_enemy_pending = {"id":id,"data":contact}
	func hurt_player(amount: int) -> void:
		if not e_enabled:
			super.hurt_player(amount)
			return
		var attributed: bool = false
		var source_id: String = ""
		if amount == 14 and not e_pending.is_empty():
			var id: int = e_pending.id
			var data: Dictionary = e_pending.data
			attributed = e_births.has(id) and e_contacts.has(id) and not e_projectile_used.has(id) and data.tick == Engine.get_physics_frames() and is_instance_valid(data.projectile) and data.projectile.is_queued_for_deletion() and data.projectile._current_map() and e_original(data.source) and data.map == level and data.player == player and data.hit.collider == player and h_stack("/projectile.gd","_physics_process")
			if attributed:
				e_projectile_used[id] = true
				source_id = data.source.id
				e_pending.clear()
		elif e_pending.is_empty() and amount == 10:
			attributed = e_worker_contact(player,true)
			if attributed:
				source_id = e_release.source.id
				e_damage_attacks[source_id+":"+str(e_release.tick)] = true
		elif e_pending.is_empty() and amount == 12:
			attributed = e_crawler_contact(player,true)
			if attributed:
				source_id = e_melee_pending.source.id
				e_damage_attacks[source_id+":"+str(e_melee_pending.release_tick)] = true
				e_melee_pending.clear()
		e_ok = e_ok and e_current() and Engine.is_in_physics_frame() and attributed and state.difficulty == 1 and budget() == e_resources()
		var absorbed: int = mini(e_base.armor-e_absorbed,int(amount/3))
		e_absorbed += absorbed
		e_health_loss += amount-absorbed
		e_hurts.append([Engine.get_physics_frames(),source_id,amount,absorbed])
		super.hurt_player(amount)
		e_ok = e_ok and budget() == e_resources()
	var e_route_b: bool = true
	var e_health_gain: int = 0
	var e_rivets: int = 0
	var e_consumed: Dictionary = {}
	var e_explored: Array = []
	var e_last_cell: Vector2i
	var e_checkpoint: Dictionary = {}
	var e_start: Dictionary = {}
	var e_actor_image: Variant
	var e_captures: Array = []
	var e_checkpoint_saves: int = 0
	var e_exit_saves: int = 0
	var e_checkpoint_doc: Dictionary = {}
	var e_checkpoint_sha: String = ""
	var e_save_sha: String = ""
	var e_exit_expected: Dictionary = {}
	var e_gate_calls: int = 0
	var e_gate_intent: bool = false
	var e_exit_intent: bool = false
	var e_inputs: Array = []
	var e_completed: bool = false
	func e_survey() -> void:
		var cell = Vector2i((Vector2(player.position.x,player.position.z)/4.0).floor())
		if cell == e_last_cell or not level.layout.is_walkable(cell): return
		e_last_cell = cell
		for x in range(cell.x-2,cell.x+3):
			for z in range(cell.y-2,cell.y+3):
				var point = Vector2i(x,z)
				var saved: Array = [x,z]
				if not level.layout.is_walkable(point) or saved in e_explored: continue
				var end: Vector3 = level.layout.world_position([x+0.5,z+0.5])+Vector3.UP*1.55
				var query = PhysicsRayQueryParameters3D.create(player.camera.global_position,end,1)
				if point == cell or level.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): e_explored.append(saved)
	func e_yaw(value: float) -> float:
		if value < -PI or value >= PI: value = wrapf(value,-PI,PI)
		return Vector3(0,clampf(value,-3.1415925,3.1415925),0).y
	func e_capture() -> Array:
		var records: Array = []
		e_ok = e_ok and enemies.size() == 31 and scene_roster_matches()
		for actor in enemies:
			e_ok = e_ok and is_instance_valid(actor) and actor.get_script() == Enemy and actor.get_instance_id() == h_bindings.get(actor.id,-1) and actor._current_map() and actor.get_parent() == level and not actor.is_queued_for_deletion() and actor.position.is_finite() and is_finite(actor.rotation.y)
			if actor.hp > 0:
				records.append({"id":actor.id,"hp":actor.hp,"position":[actor.position.x,actor.position.y,actor.position.z],"yaw":e_yaw(actor.rotation.y),"alerted":actor.alerted})
		return records
	func e_all_dead() -> bool:
		return enemies.size() == 31 and scene_roster_matches() and enemies.all(func(actor): return is_instance_valid(actor) and actor.get_script() == Enemy and h_bindings.get(actor.id,-1) == actor.get_instance_id() and actor._current_map() and actor.get_parent() == level and not actor.is_queued_for_deletion() and actor.hp == 0 and actor.collision_layer == 0 and actor.collision_mask == 0 and state.removed.count(actor.id) == 1) and e_activation == 1 and e_deaths.size() == 4 and E_IDS.all(func(id): return e_deaths.get(id,0) == 1 and e_finishes.get(id,"unproven") in ["player","infighting"]) and not e_shots.is_empty()
	func _capture_actor_state() -> bool:
		if not e_enabled: return super._capture_actor_state()
		if state.level_index == 4:
			e_ok = e_ok and e_exit_intent and h_stack("/main.gd","interact") and state.to_dict() == e_handoff() and e_exit_expected == e_handoff()
			var result: bool = super._capture_actor_state()
			e_ok = e_ok and result and state.to_dict() == e_handoff() and e_exit_expected == e_handoff()
			e_captures.append(["handoff",Engine.get_physics_frames()])
			return result
		var passive: bool = h_stack("/main.gd","update_passive_triggers") and h_stack("/player.gd","_physics_process")
		e_ok = e_ok and e_current() and Engine.is_in_physics_frame() and (passive or e_exit_intent and h_stack("/main.gd","interact"))
		if passive and not E_CHECKPOINT.id in e_removed:
			e_ok = e_ok and e_checkpoint_saves == 0 and state.checkpoint_id == "entry" and state.keys == ["blood","ivory"] and state.removed == e_removed+[E_CHECKPOINT.id] and player.position.distance_to(level.layout.world_position(E_CHECKPOINT.cell)) < 3.2 and _passive_trigger_visible(E_CHECKPOINT)
			e_removed.append(E_CHECKPOINT.id)
		var records: Array = e_capture()
		var yaw: float = e_yaw(player.rotation.y)
		var pitch: float = clampf(player.camera.rotation.x,-1.35,1.35)
		e_ok = e_ok and is_finite(yaw) and is_finite(pitch) and absf(player.camera.rotation.x) <= Vector3(1.35,0,0).x
		if e_exit_intent: e_ok = e_ok and e_all_dead() and records.is_empty()
		else: e_ok = e_ok and records.size() == 4 and records.map(func(record): return record.id) == E_IDS
		var result: bool = super._capture_actor_state()
		e_ok = e_ok and result and state.actors == records and state.yaw == yaw and state.pitch == pitch
		e_actor_image = records.duplicate(true)
		e_captures.append(["checkpoint" if passive else "exit",Engine.get_physics_frames(),records.duplicate(true),yaw,pitch])
		return result
	func e_checkpoint_resources() -> Dictionary:
		var resources: Dictionary = e_resources().duplicate(true)
		resources.merge({"keys":["blood","ivory"],"removed":e_removed.duplicate(),"checkpoint_id":E_CHECKPOINT.id,"position":[player.position.x,player.position.y,player.position.z],"actors":e_capture(),"yaw":e_yaw(player.rotation.y),"pitch":clampf(player.camera.rotation.x,-1.35,1.35)},true)
		return resources
	func e_handoff() -> Dictionary:
		var resources: Dictionary = e_resources().duplicate(true)
		resources.merge({"keys":[],"removed":[],"checkpoint_id":"entry","position":[0.0,0.0,0.0]},true)
		var document: Dictionary = resources.duplicate(true)
		document.merge({"version":1,"difficulty":1,"level_index":4,"discoveries":[3],"explored":[],"checkpoint":resources.duplicate(true),"level_start":resources.duplicate(true)},true)
		return document
	func _save() -> Error:
		if not e_enabled: return super._save()
		var checkpoint_save: bool = state.level_index == 3
		var expected: Dictionary
		if checkpoint_save:
			e_ok = e_ok and e_checkpoint_saves == 0 and e_current() and Engine.is_in_physics_frame() and h_stack("/main.gd","update_passive_triggers") and h_stack("/player.gd","_physics_process") and state.checkpoint_id == E_CHECKPOINT.id
			e_checkpoint = e_checkpoint_resources()
			expected = e_checkpoint.duplicate(true)
			expected.merge({"version":1,"difficulty":1,"level_index":3,"discoveries":[3],"explored":e_explored.duplicate(true),"checkpoint":e_checkpoint.duplicate(true),"level_start":e_start.duplicate(true)},true)
		else:
			e_ok = e_ok and state.level_index == 4 and e_exit_saves == 0 and e_exit_intent and Engine.is_in_physics_frame() and Input.is_action_pressed("interact") and h_stack("/main.gd","interact")
			expected = e_handoff()
			e_ok = e_ok and e_exit_expected == expected
		var scene = level
		var observer = player
		var result: Error = super._save()
		var saved = Campaign.new()
		var raw = JSON.parse_string(FileAccess.get_file_as_string(progress_path))
		e_save_sha = FileAccess.get_sha256(progress_path)
		e_ok = e_ok and result == OK and level == scene and player == observer and is_instance_valid(scene) and not scene.is_queued_for_deletion() and is_instance_valid(observer) and observer.get_parent() == scene and e_save_sha.length() == 64 and raw is Dictionary and raw == JSON.parse_string(JSON.stringify(expected,"",true,true)) and saved.load_progress(progress_path) and saved.to_dict() == expected and state.to_dict() == expected
		if checkpoint_save:
			e_checkpoint_saves += 1
			e_checkpoint_doc = expected.duplicate(true)
			e_checkpoint_sha = e_save_sha
		else: e_exit_saves += 1
		return result
	func interact() -> void:
		if not e_enabled:
			super.interact()
			return
		var spec: Dictionary = nearest_interaction()
		e_ok = e_ok and e_current() and Engine.is_in_physics_frame() and Input.is_action_pressed("interact") and h_stack("/player.gd","_physics_process") and spec in [E_DOOR,E_DESCENT] and (e_gate_intent if spec == E_DOOR else e_exit_intent and e_all_dead())
		e_inputs.append([spec.get("id",""),Engine.get_physics_frames(),player.position,player.rotation.y,player.camera.rotation.x])
		if not e_ok: return
		super.interact()
		if e_exit_intent: e_completed = state.level_index == 4 and not playing and level == null and player == null and e_exit_saves == 1
	func unlock_door(id: String) -> bool:
		if not e_enabled: return super.unlock_door(id)
		e_ok = e_ok and e_current() and e_gate_intent and not e_exit_intent and id == E_DOOR.id and e_gate_calls == 0 and e_checkpoint_saves == 1 and Engine.is_in_physics_frame() and Input.is_action_pressed("interact") and h_stack("/player.gd","_physics_process") and h_stack("/main.gd","interact") and nearest_interaction() == E_DOOR and state.keys == ["blood","ivory"] and level.layout.data.doors.filter(func(spec): return spec.id == id) == [E_DOOR]
		var result: bool = super.unlock_door(id)
		e_gate_calls += 1
		e_removed.append(id)
		e_ok = e_ok and result and not level.doors.has(id) and state.removed == e_removed and budget() == e_resources()
		return result
	func collect_key(id: String) -> void:
		if e_enabled: e_ok = false
		super.collect_key(id)

var e_started: bool = false
var e_epoch: int = 0
var e_wall: int = 0
var e_fields: Array = []
var e_frozen: Dictionary = {}
var e_actors: Array = []
var e_markers: Dictionary = {}
var e_time: float = 0.0
var e_fighting: bool = false
var e_gate_ref
var e_retired: Array = []
var e_drain_frames: int = 0
var e_limit: int = 0
var e_seconds: float = 0.0

func run() -> void:
	if "--reliquary-exit-pin-rejection" in OS.get_cmdline_user_args():
		await reliquary_exit_pin_rejection()
		return
	if not await walk_through_reliquary_exit(ReliquaryExitMain.new()):
		await finish(1)
		return
	print("PASS source-native virtual-input earned Reliquary completion menu; Nursery remains unstarted; not physical controls, rendered/audio/PCM/performance, full eight or standalone acceptance")
	await finish(0)

func reliquary_exit_pin_rejection() -> void:
	if not expect(FileAccess.get_sha256("res://tests/test_reliquary_catalogue.gd") != E_CATALOGUE_SHA,"Pin rejection requires deliberate parent-owned Catalogue mismatch"):
		await finish(1)
		return
	var fixture_prefix: String = "user://reliquary_catalogue_exit_pin_rejection_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	var observer = ReliquaryExitMain.new()
	var reference = weakref(observer)
	var result: bool = await walk_through_reliquary_exit(observer,fixture_prefix)
	var untouched: bool = game == null and root.get_child_count() == 0 and not FileAccess.file_exists(fixture_prefix+"_campaign.json") and not FileAccess.file_exists(fixture_prefix+"_preferences.json")
	var rejected: bool = expect(not result and reference.get_ref() == null and untouched,"Wrong pin frees only fresh detached supplied observer and checks unique fixture files, never unrelated default-save absence")
	if is_instance_valid(observer): observer.free()
	await finish(0 if rejected else 1)

func walk_through_reliquary_exit(observer: ReliquaryExitMain, profile_prefix: String = "") -> bool:
	if not expect(FileAccess.get_sha256("res://tests/test_reliquary_catalogue.gd") == E_CATALOGUE_SHA,"Exact provisional Catalogue hash before any observer/profile/scene adoption"):
		if is_instance_valid(observer) and observer != game and observer.get_parent() == null and not observer.is_inside_tree(): observer.free()
		return false
	var fixture_prefix: String = profile_prefix if not profile_prefix.is_empty() else "user://reliquary_catalogue_exit_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	if not expect(game == null and is_instance_valid(observer) and observer.get_parent() == null and not observer.is_inside_tree() and fixture_prefix.begins_with("user://reliquary_catalogue_exit_") and not fixture_prefix.contains("..") and not fixture_prefix.trim_prefix("user://").contains("/") and not fixture_prefix.contains("\\") and not FileAccess.file_exists(fixture_prefix+"_campaign.json") and not FileAccess.file_exists(fixture_prefix+"_preferences.json"),"Fresh detached same CatalogueMain subclass and unique Catalogue-compatible exit namespace"):
		if is_instance_valid(observer) and observer != game and observer.get_parent() == null and not observer.is_inside_tree(): observer.free()
		return false
	if not await walk_through_catalogue(observer,fixture_prefix) or not start_reliquary_exit(): return false
	if not await blood_story_route(E_ROUTE_B if game.e_route_b else E_ROUTE_A): return false
	if not expect(game.e_checkpoint_saves == 1 and game.state.checkpoint == game.e_checkpoint and game.state.level_start == game.e_start and game.e_rivets == 33 and game.e_health_gain == (14 if game.e_route_b else 0),"Automatic physics-owned checkpoint with its actual permitted pickup ordering; independently derived native actor image/facing/resources/save"): return false
	if not await reliquary_gate_input(): return false
	if not "--omit-reliquary-exit-approach" in OS.get_cmdline_user_args():
		if not await blood_story_route(E_APPROACH): return false
	if not expect(game.e_activation == 1 and game.e_activated.size() == 4,E_ACTIVATION_GUARD): return false
	e_fighting = true
	for frame in range(E_FIGHT_LIMIT):
		if game.e_deaths.size() == 4: break
		release_actions()
		east_fire()
		if not await route_tick(): return false
	e_fighting = false
	release_actions()
	if not reliquary_exit_earned(): return false
	var began: int = east_elapsed()
	for frame in range(E_DRAIN):
		if not await route_tick(): return false
	e_drain_frames = east_elapsed()-began
	await process_frame
	if not expect(e_drain_frames == E_DRAIN and game.e_births.size() > 0 and game.e_births.values().all(func(birth): return birth.reference.get_ref() == null) and game.e_pending.is_empty() and game.e_enemy_pending.is_empty() and game.e_melee_pending.is_empty() and game.e_projectile_used.size() == game.e_contacts.size(),"Finite original caster births and every current-map contact consumed; late-dead shooter projectiles actually drain before descent"): return false
	if not await blood_story_route(E_CLOSE): return false
	return await reliquary_completion_input()

func start_reliquary_exit() -> bool:
	if not expect(game is ReliquaryExitMain and game.c_enabled and game.c_ok and catalogue_result() and game.budget() == E_CARRY and route_player.position.distance_to(route_level.layout.world_position([17.5,9.25])) < 0.2,"Exact current same-observer Catalogue boundary86HP178armor147pistol32shells and untouched checkpoint/start/profile"): return false
	if not expect(route_level.layout.data.doors == [E_DOOR] and route_level.layout.data.interactions.filter(func(spec): return spec.id == E_CHECKPOINT.id) == [E_CHECKPOINT] and route_level.layout.data.interactions.filter(func(spec): return spec.id == E_DESCENT.id) == [E_DESCENT] and route_level.layout.data.encounters.filter(func(spec): return spec.id == E_GROUP.id) == [E_GROUP],"Exact original float-variant JSON gate/checkpoint/descent and Exit4 group; descent has no defeated-ID contract"): return false
	for id in E_PICKUPS:
		if not expect(route_level.layout.data.pickups.filter(func(spec): return spec.id == id) == [E_PICKUPS[id]] and route_level.markers.has(id),"Exact finite permitted exit pickup: "+id): return false
	for actor in game.enemies:
		var capsule: CollisionShape3D = actor.get_child(0)
		e_actors.append({"instance":actor.get_instance_id(),"age":actor.age,"position":actor.position,"yaw":actor.rotation.y,"active":actor.active,"alerted":actor.alerted,"shape_disabled":capsule.disabled,"capsule":capsule.get_instance_id(),"shape":capsule.shape.get_instance_id(),"capsule_position":capsule.position,"radius":capsule.shape.radius,"height":capsule.shape.height})
	for id in route_level.markers: e_markers[id] = weakref(route_level.markers[id])
	var actual: Array = []
	for property in game.get_property_list():
		if str(property.name).begins_with("c_") and property.name != "c_enabled": actual.append(property.name)
	actual.sort()
	var declared: Array = E_C_FIELDS.duplicate()
	declared.sort()
	if not expect(actual == declared,"Freeze EVERY c_ field except retired c_enabled, including all prior contacts/births/current-HP evidence"): return false
	e_fields = c_fields+E_C_FIELDS
	e_frozen = observer_witness(e_fields)
	game.e_base = E_CARRY.duplicate(true)
	game.e_removed = game.state.removed.duplicate()
	game.e_start = game.state.level_start.duplicate(true)
	game.e_actor_image = game.state.actors.duplicate(true) if game.state.actors is Array else game.state.actors
	game.e_explored = game.state.explored.duplicate(true)
	game.e_last_cell = Vector2i((Vector2(route_player.position.x,route_player.position.z)/4.0).floor())
	game.e_route_b = not "--reliquary-exit-route-a" in OS.get_cmdline_user_args()
	e_limit = ((E_ROUTE_B.size() if game.e_route_b else E_ROUTE_A.size())+E_APPROACH.size()+E_CLOSE.size())*HOP_LIMIT+E_FIGHT_LIMIT+E_DRAIN+2*E_INPUT_LIMIT+E_GATE_WAIT+E_MENU_WAIT
	e_seconds = float(e_limit)/60.0+2.0
	e_gate_ref = weakref(route_level.doors[E_DOOR.id])
	var door = e_gate_ref.get_ref()
	var colliders: Array = door.get_children().filter(func(child): return child is CollisionShape3D)
	if not expect(door.get_script() == null and door.collision_layer == 1 and colliders.size() == 1 and not colliders[0].disabled and colliders[0].shape is BoxShape3D and colliders[0].shape.size.is_equal_approx(Vector3(12.2,5.0,0.6)) and door.position.is_equal_approx(route_level.layout.world_position(E_DOOR.cell)+Vector3.UP*2.5),"Original native gate/collider dimensions and placement before interaction"): return false
	e_time = route_player.active_play_time
	game.e_shot_start_time = e_time
	game.e_shot_start_age = route_player.shot_age(1)
	release_actions()
	game.c_enabled = false
	e_epoch = Engine.get_physics_frames()
	e_wall = Time.get_ticks_usec()
	game.e_enabled = true
	e_started = true
	return live_route()

func east_elapsed() -> int:
	return Engine.get_physics_frames()-e_epoch if e_started else super.east_elapsed()

func route_tick() -> bool:
	if not e_started: return await super.route_tick()
	if not live_route() or not expect(game.state.health > 24,"Original finite exit survival floor above24HP before and after each physics step"): return false
	await physics_frame
	return live_route() and expect(game.state.health > 24,"Original finite exit survival floor above24HP before and after each physics step")

func reliquary_gate_input() -> bool:
	if not live_route(): return false
	var revision: int = route_level.get_node("NavigationRoutes").revision
	aim_interaction(E_DOOR.cell,2.5)
	game.e_gate_intent = true
	if not "--omit-reliquary-exit-gate" in OS.get_cmdline_user_args(): interaction_input(true)
	for frame in range(E_INPUT_LIMIT):
		if not await route_tick(): return false
		if game.e_gate_calls == 1: break
	interaction_input(false)
	release_actions()
	game.e_gate_intent = false
	if not expect(game.e_gate_calls == 1 and not route_level.doors.has(E_DOOR.id) and is_instance_valid(e_gate_ref.get_ref()) and e_gate_ref.get_ref().collision_layer == 0 and route_level.get_node("NavigationRoutes").revision > revision,E_GATE_GUARD): return false
	for frame in range(E_GATE_WAIT):
		if not await route_tick(): return false
		await process_frame
	return expect(e_gate_ref.get_ref() == null,"Original gate tween/node drains within60 physics waits, not a replaced or hidden collision")

func reliquary_exit_earned() -> bool:
	return live_route() and expect(game.e_all_dead() and game.e_activation == 1 and game.e_activated.size() == 4 and game.e_shots.size() <= E_SHOT_CAP,E_EARNING_GUARD)

func reliquary_completion_input() -> bool:
	if not reliquary_exit_earned(): return false
	for group in route_level.layout.data.encounters:
		if not expect(game.state.removed.count("encounter:"+group.id) == 1,"Every original group activated exactly once: "+group.id): return false
	var resources: Dictionary = game.e_resources().duplicate(true)
	resources.merge({"keys":[],"removed":[],"checkpoint_id":"entry","position":[0.0,0.0,0.0]},true)
	game.e_exit_expected = resources.duplicate(true)
	game.e_exit_expected.merge({"version":1,"difficulty":1,"level_index":4,"discoveries":[3],"explored":[],"checkpoint":resources.duplicate(true),"level_start":resources.duplicate(true)},true)
	for node in [route_level,route_player]+game.enemies: e_retired.append(weakref(node))
	aim_interaction(E_DESCENT.cell)
	game.e_exit_intent = true
	if not "--omit-reliquary-exit-descent" in OS.get_cmdline_user_args(): interaction_input(true)
	for frame in range(E_INPUT_LIMIT):
		await physics_frame
		if game.e_completed: break
		if not live_route(): return false
	interaction_input(false)
	release_actions()
	if not expect(game.e_completed,"NATIVE RED earned descent must produce real completion/menu/save instead of directly starting Nursery"): return false
	for frame in range(E_MENU_WAIT): await process_frame
	return reliquary_completion_result()

func reliquary_completion_result() -> bool:
	var saved = game.Campaign.new()
	var offered: bool = false
	var completed: bool = false
	for node in game.menu.get_children():
		if node is Button and node.text == "Descend to The Nursery" and not node.is_queued_for_deletion():
			var connections: Array = node.get_signal_connection_list("pressed")
			offered = node.visible and not node.disabled and connections.size() == 1 and connections[0].callable == Callable(game,"start_level")
		if node is Label and node.text == "THE RELIQUARY RESTORED" and not node.is_queued_for_deletion(): completed = node.visible
	print("RELIQUARY_EARNED_EXIT frames=",east_elapsed()," wall_us=",Time.get_ticks_usec()-e_wall," route_b=",game.e_route_b," resources=",game.e_resources()," shots=",game.e_shots," hurts=",game.e_hurts," births=",game.e_births.size()," contacts=",game.e_contacts.size()," enemy_contacts=",game.e_enemy_contacts.size()," deaths=",game.e_deaths," provenance=",game.e_finishes," checkpoint_sha=",game.e_checkpoint_sha," final_sha=",game.e_save_sha)
	return expect(game.e_ok and game.e_completed and game.e_exit_expected == game.e_handoff() and game.e_inputs.size() == 2 and game.e_inputs.map(func(item): return item[0]) == [E_DOOR.id,E_DESCENT.id] and observer_witness(e_fields) == e_frozen and game.get_instance_id() == r_main_id and game.state.get_instance_id() == r_campaign_id and game.progress_path == r_profile and game.settings_path == game.r_settings_origin and game.e_checkpoint_saves == 1 and game.e_exit_saves == 1 and game.e_captures.size() == 4 and game.e_captures.filter(func(item): return item[0] == "checkpoint").size() == 2 and game.e_captures.filter(func(item): return item[0] == "exit").size() == 1 and game.e_captures.filter(func(item): return item[0] == "handoff").size() == 1 and game.state.to_dict() == game.e_exit_expected and saved.load_progress(r_profile) and saved.to_dict() == game.e_exit_expected and FileAccess.get_sha256(r_profile) == game.e_save_sha and game.e_save_sha != game.e_checkpoint_sha and game.state.level_index == 4 and game.state.actors == null and game.state.yaw == null and game.state.pitch == null and not game.playing and game.level == null and game.player == null and paused and game.menu_scroll.visible and offered and completed and e_retired.all(func(ref): return ref.get_ref() == null) and e_markers.values().all(func(ref): return ref.get_ref() == null) and east_elapsed() <= e_limit and Time.get_ticks_usec()-e_wall <= e_seconds*1000000,"Independent earned fresh Nursery handoff live/loaded/save envelopes, actual completion labels/button and retired original scene; return same Main/profile without quitting or starting Nursery")

func east_fire() -> bool:
	if not e_started: return super.east_fire()
	Input.action_release("fire")
	if not e_fighting or game.e_activation != 1 or "--omit-reliquary-exit-fire" in OS.get_cmdline_user_args() or game.e_shots.size() >= E_SHOT_CAP or game.state.weapon != 1: return false
	var selected = null
	var nearest: float = 140.0
	for actor in game.enemies:
		if not game.e_original(actor) or not actor.active or actor.hp <= 0: continue
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
	if not e_started: return super.clear_point(cell)
	if cell[0] < 17.25 or cell[0] > 21.75 or cell[1] < 2.7 or cell[1] > 12.0: return null
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

func live_route() -> bool:
	if not e_started: return super.live_route()
	if not expect(east_elapsed() <= e_limit and Time.get_ticks_usec()-e_wall <= e_seconds*1000000,"Fresh Reliquary exit epoch/bounds independent of all completed phases"): return false
	if not expect(game.e_ok and game.e_current() and not paused and game.get_instance_id() == r_main_id and game.state.get_instance_id() == r_campaign_id and game.progress_path == r_profile and game.settings_path == game.r_settings_origin and game.level == route_level and game.player == route_player and not game.loaded_positions and game.is_processing() and game.is_physics_processing() and route_player.is_physics_processing() and route_player.position.is_finite() and game.enemies.size() == 31 and game.scene_roster_matches(),"Same native Main/Campaign/profile/Player/original31; no recovery, unregistered actor or scene replacement"): return false
	if not expect(observer_witness(e_fields) == e_frozen and observer_witness(v_fields) == v_frozen and observer_witness(w_fields) == w_frozen and observer_witness(b_fields) == b_frozen and observer_witness(h_fields) == h_frozen and observers_retired() and not game.h_enabled and not game.b_enabled and not game.q_enabled and not game.w_enabled and not game.v_enabled and not game.c_enabled and observer_witness(q_fields) == q_frozen and retired.all(func(ref): return ref.get_ref() == null) and x_marker_refs.values().all(func(ref): return ref.get_ref() == null),"All accepted prefix/Halo/Blood/Return/Wheel/Ivory/Wheel RETURN history frozen; only c_enabled retired for this phase"): return false
	for refs in [h_marker_refs,b_markers,q_markers,w_markers,v_markers]:
		for id in refs:
			if id in e_frozen.c_removed and not expect(refs[id].get_ref() == null,"Every old consumed marker drains: "+id): return false
	for index in range(R_ACTORS.size()):
		var spec: Array = R_ACTORS[index]
		var actor = game.enemies[index]
		var prior: Dictionary = e_actors[index]
		var capsule: CollisionShape3D = actor.get_child(0)
		if not expect(capsule.get_instance_id() == prior.capsule and capsule.shape.get_instance_id() == prior.shape and capsule.position == prior.capsule_position and capsule.shape.radius == prior.radius and capsule.shape.height == prior.height,"All31 original capsule and shape identities/dimensions"): return false
		if not expect(is_instance_valid(actor) and actor.id == spec[0] and actor.get_instance_id() == prior.instance and actor.get_instance_id() == game.h_bindings[actor.id] and actor.get_script() == game.Enemy and actor.kind == spec[1] and actor.max_hp == spec[2] and actor._current_map() and actor.is_physics_processing() and actor.age-prior.age >= float(east_elapsed()-2)/60.0 and (actor.get_child(0) as CollisionShape3D).disabled == prior.shape_disabled,"Original native identity/age/capsule: "+spec[0]): return false
		if actor.id in E_IDS:
			if game.e_activation == 0 and not expect(actor.hp == spec[2] and actor.position == prior.position and actor.rotation.y == prior.yaw and not actor.alerted,"Exit actors retain original fullHP/pose until real region activation"): return false
			if not expect(game.e_original(actor) and actor.hp >= 0 and actor.hp <= spec[2] and actor.active == (game.e_activation == 1) and actor.alerted == (game.e_activation == 1) and (actor.hp > 0 or game.e_deaths.get(actor.id,0) == 1 and game.e_finishes.get(actor.id,"unproven") in ["player","infighting"] and actor.collision_layer == 0 and actor.collision_mask == 0 and game.state.removed.count(actor.id) == 1),"Only four original Exit actors change through automatic activation/native combat"): return false
			if actor.hp > 0 and not expect(actor.collision_layer == 4 and actor.collision_mask == 7,"Living Exit capsule stays native"): return false
		elif not expect(actor.position == prior.position and actor.rotation.y == prior.yaw and actor.active == prior.active and actor.alerted == prior.alerted and (actor.hp == 0 and actor.collision_layer == 0 and actor.collision_mask == 0 and game.state.removed.count(actor.id) == 1 if actor.id in H_IDS+Q_IDS+W_IDS+V_IDS+C_IDS else actor.hp == spec[2] and not actor.active and not actor.alerted and actor.collision_layer == 4 and actor.collision_mask == 7),"Original27 corpses and Exit4 inactive/fullHP/poses unchanged"): return false
	for id in e_markers:
		if game.e_consumed.has(id):
			if not expect(not route_level.markers.has(id) and game.state.removed.count(id) == 1,"Allowed original pickup removed once: "+id): return false
		elif not expect(route_level.markers.has(id) and e_markers[id].get_ref() == route_level.markers[id] and route_level.markers[id].get_parent() == route_level and not route_level.markers[id].is_queued_for_deletion() and (not id in game.state.removed or id == E_CHECKPOINT.id and game.e_checkpoint_saves == 1),"Every other original marker identity/owner including checkpoint retained: "+id): return false
	if not expect(route_level.markers.size() == e_markers.size()-game.e_consumed.size(),"Exact marker set; unintended or capped pickup callbacks fail"): return false
	if not expect(game.e_pending.is_empty() and game.e_enemy_pending.is_empty() and game.e_melee_pending.is_empty(),"All native damage contact witnesses consumed synchronously"): return false
	for node in route_level.get_children():
		if node.get_script() == preload("res://scripts/projectile.gd"):
			var id: int = node.get_instance_id()
			if not expect(game.e_births.has(id) and game.e_births[id].reference.get_ref() == node and node.shooter == game.e_births[id].source and node.get_parent() == route_level and node._current_map() and node.is_physics_processing(),"Every actual current-level projectile has its original native birth/shooter; no orphan or replacement"): return false
	var checkpoint_saved: bool = game.e_checkpoint_saves == 1
	return expect(game.budget() == game.e_resources() and game.state.health > 24 and game.state.health <= 100 and game.state.armor >= 0 and game.state.armor <= 178 and game.state.ammo[1] >= 0 and game.state.ammo[1] <= 180 and game.state.keys == ["blood","ivory"] and game.state.discoveries == [3] and game.state.removed == game.e_removed and game.state.explored == game.e_explored and game.state.checkpoint_id == (E_CHECKPOINT.id if checkpoint_saved else "entry") and game.state.checkpoint == (game.e_checkpoint if checkpoint_saved else game.e_start) and game.state.level_start == game.e_start and game.state.actors == game.e_actor_image and FileAccess.get_sha256(r_profile) == (game.e_checkpoint_sha if checkpoint_saved else r_saved_sha) and game.e_ticks >= east_elapsed()-2 and absf(route_player.active_play_time-e_time-float(east_elapsed())/60.0) <= 2.0/60.0,"Independent fresh shot/pickup/damage/survey ledger and permitted checkpoint actor image/facing/disk; original level_start preserved")
