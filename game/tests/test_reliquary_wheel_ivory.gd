extends "res://tests/test_reliquary_halo_return.gd"

const W_RETURN_SHA = "4e25cf0b8e72a6be54ecc0dab1aa834c9d30179c0d10339ea7ee6dd3747a0a61"
const W_IDS = ["reliquary_enemy_08","reliquary_enemy_09","reliquary_enemy_10","reliquary_enemy_11","reliquary_enemy_12","reliquary_enemy_13","reliquary_enemy_14","reliquary_enemy_15"]
const W_GROUP = {"id":"reliquary_wheel_commit","region":[26.0,8.0,36.9,21.25],"enemy_ids":["reliquary_enemy_08","reliquary_enemy_09","reliquary_enemy_10","reliquary_enemy_11","reliquary_enemy_12","reliquary_enemy_13","reliquary_enemy_14","reliquary_enemy_15"],"requires":[],"cue":{"text":"THE MEMORY DRUM ANSWERS OUT OF ORDER","light_ids":["reliquary_wheel_feed","reliquary_wheel_core"],"sound":"seal_release"}}
const W_PICKUPS = {"reliquary_wheel_approach_rivets":{"id":"reliquary_wheel_approach_rivets","kind":"ammo","cell":[29.5,25.5],"amount":45.0,"weapon":1.0}}
const W_IVORY = {"id":"reliquary_ivory","kind":"key","key":"ivory","cell":[35.5,17.5],"text":"MEMORY DRUM IVORY SEAL RECOVERED"}
const W_CARRY = {"health":100,"armor":190,"ammo":[0,167,32,0,0,0],"owned_weapons":[0,1,2],"weapon":1}
const W_RETURN_FIELDS = ["q_ok","q_ticks","q_activation","q_activated","q_removed","q_shots","q_last","q_slot","q_last_time","q_shot_start_age","q_shot_start_time","q_rivets","q_consumed","q_rejected","q_health_loss","q_absorbed","q_hurts","q_attacks","q_roles","q_deaths","q_finishes","q_release","q_melee_pending","q_damage_attacks"]
const W_APPROACH = [[19,14],[19,17],[19,20],[19,23],[19,26],[19,28.5],[21.5,28.5],[24.5,28.5],[27,28.5],[29.5,28.5],[29.5,25.5],[29.5,23],[29.5,21]]
const W_CLOSE = [[31,20.75],[32.5,20.5],[35.5,20.5],[35.5,17.5]]
const W_SHOT_CAP = 48
const W_DRAIN = 246
const W_INPUT = 6
const W_LIMIT = 17*240+480+240+240+W_DRAIN+W_INPUT
const W_SECONDS = float(W_LIMIT)/60.0+2.0
const W_ACTIVATION_GUARD = "NATIVE RED Wheel requires actual original region-driven Main._process activation"
const W_EARNING_GUARD = "NATIVE RED Wheel requires all8 native provenanced deaths and real three-role releases/caster birth before Ivory"
const W_IVORY_GUARD = "NATIVE RED Ivory requires actual InputEventAction to Player to Main.interact and original marker consumption once"

class WheelMain:
	extends "res://tests/test_reliquary_halo_return.gd".ReturnMain
	var w_enabled: bool = false
	var w_base: Dictionary = {}
	var w_ivory_calls: int = 0
	var w_pending_key: String = ""
	var w_inputs: Array = []
	var w_pickup_calls: Array = []
	var w_ok: bool = true
	var w_ticks: int = 0
	var w_shots: Array = []
	var w_last: int = -1
	var w_slot: float = -1.0
	var w_last_time: float = -INF
	var w_shot_start_age: float = INF
	var w_shot_start_time: float = 0.0
	var w_rivets: int = 0
	var w_health_loss: int = 0
	var w_absorbed: int = 0
	var w_consumed: Dictionary = {}
	var w_rejected: Dictionary = {}
	var w_removed: Array = []
	var w_activation: int = 0
	var w_activated: Dictionary = {}
	var w_attacks: Dictionary = {}
	var w_roles: Dictionary = {}
	var w_damage_attacks: Dictionary = {}
	var w_hurts: Array = []
	var w_deaths: Dictionary = {}
	var w_finishes: Dictionary = {}
	var w_births: Dictionary = {}
	var w_contacts: Dictionary = {}
	var w_projectile_used: Dictionary = {}
	var w_pending: Dictionary = {}
	var w_release: Dictionary = {}
	var w_melee_pending: Dictionary = {}
	var w_enemy_contacts: Dictionary = {}
	var w_enemy_pending: Dictionary = {}
	var w_enemy_used: Dictionary = {}
	func w_current() -> bool:
		return h_current() and not h_enabled and not b_enabled and not q_enabled and w_enabled
	func w_resources() -> Dictionary:
		return {"health":w_base.health-w_health_loss,"armor":w_base.armor-w_absorbed,"ammo":[0,int(w_base.ammo[1])+w_rivets-w_shots.size(),32,0,0,0],"owned_weapons":[0,1,2],"weapon":1}
	func w_original(actor) -> bool:
		return is_instance_valid(actor) and actor.get_script() == Enemy and actor.id in W_IDS and h_bindings.get(actor.id,-1) == actor.get_instance_id() and actor._current_map() and actor.get_parent() == level and not actor.is_queued_for_deletion()
	func w_worker_contact(victim, repeat_ray: bool) -> bool:
		var source = w_release.get("source")
		if not w_original(source) or source.kind != "worker" or source.hp <= 0 or not source.active or w_release.get("tick",-1) != Engine.get_physics_frames() or not h_stack("/enemy.gd","_attack") or not h_stack("/enemy.gd","_release_attack"): return false
		var key: String = source.id+":"+str(w_release.tick)
		var hit: Dictionary = w_release.hit
		if w_damage_attacks.has(key) or hit.get("collider") != victim or hit.get("rid") != victim.get_rid() or victim.get_parent() != level: return false
		var origin: Vector3 = source.global_position+Vector3.UP*1.4
		var end: Vector3 = origin+(source._committed_aim-origin).normalized()*30.0
		if origin != w_release.origin or end != w_release.end: return false
		if repeat_ray:
			var query = PhysicsRayQueryParameters3D.create(origin,end,1|2|4)
			query.exclude = [source.get_rid()]
			query.hit_from_inside = true
			if level.get_world_3d().direct_space_state.intersect_ray(query) != hit: return false
		return true
	func w_crawler_contact(victim, repeat_ray: bool) -> bool:
		if w_melee_pending.is_empty(): return false
		var source = w_melee_pending.source
		var tick: int = w_melee_pending.release_tick
		var age: int = Engine.get_physics_frames()-tick
		if not w_original(source) or source.kind != "crawler" or source.hp <= 0 or not source.active or w_melee_pending.tick != Engine.get_physics_frames() or w_melee_pending.map != level or w_melee_pending.player != player or w_attacks.get(source.id,-1) != tick or age < 0 or age > 12 or w_damage_attacks.has(source.id+":"+str(tick)) or not h_stack("/enemy.gd","_try_melee") or not h_stack("/enemy.gd","_attack"): return false
		var hit: Dictionary = w_melee_pending.hit
		if hit.get("collider") != victim or hit.get("rid") != victim.get_rid() or victim.get_parent() != level: return false
		var intended = w_melee_pending.intended
		if not is_instance_valid(intended) or source._committed_target != intended or source.global_position.distance_to(intended.global_position) >= 1.9: return false
		var origin: Vector3 = source.global_position+Vector3.UP*0.6
		var end: Vector3 = intended.global_position+Vector3.UP*0.7
		if origin != w_melee_pending.origin or end != w_melee_pending.end: return false
		if repeat_ray:
			var query = PhysicsRayQueryParameters3D.create(origin,end,1|2|4)
			query.exclude = [source.get_rid()]
			query.hit_from_inside = true
			if level.get_world_3d().direct_space_state.intersect_ray(query) != hit: return false
		else:
			if w_melee_pending.victim_hp <= 0 or w_melee_pending.victim_hp > 12: return false
		return true
	func w_projectile_death(victim) -> bool:
		if w_enemy_pending.is_empty(): return false
		var id: int = w_enemy_pending.id
		var data: Dictionary = w_enemy_pending.data
		var projectile = data.projectile
		if not w_births.has(id) or not w_enemy_contacts.has(id) or w_enemy_used.has(id) or not is_instance_valid(projectile): return false
		var birth: Dictionary = w_births[id]
		return data.tick == Engine.get_physics_frames() and data.hit.collider == victim and data.hit.rid == victim.get_rid() and data.victim_id == victim.get_instance_id() and data.victim_hp > 0 and data.victim_hp <= 14 and data.map == level and data.player == player and birth.source == data.source and birth.reference.get_ref() == projectile and w_original(data.source) and projectile.shooter == data.source and projectile.is_queued_for_deletion() and projectile._current_map() and h_stack("/projectile.gd","_physics_process") and h_stack("/enemy.gd","take_damage")
	func _physics_process(delta: float) -> void:
		super._physics_process(delta)
		if not w_enabled: return
		w_ok = w_ok and w_enemy_pending.is_empty() and w_melee_pending.is_empty() and w_current() and absf(delta-1.0/60.0) < 0.000001
		w_ticks += 1
		if not Input.is_action_pressed("fire"): w_slot = -1.0
	func shot(weapon: int) -> void:
		if w_enabled:
			var tick: int = Engine.get_physics_frames()
			w_slot = entry_slot(tick,w_last,w_slot,weapon)
			var elapsed: float = player.active_play_time-w_shot_start_time
			w_ok = w_ok and w_current() and Engine.is_in_physics_frame() and weapon == 1 and state.weapon == 1 and Input.is_action_pressed("fire") and w_slot >= 0.0 and player.shot_age(1) == 0.0 and h_stack("/player.gd","fire") and player.active_play_time > w_last_time and (w_shots.size() > 0 or w_shot_start_age+elapsed+0.000001 >= 0.21)
			w_ok = w_ok and w_activation == 1 and w_shots.size() < W_SHOT_CAP
			w_shots.append([tick,player.active_play_time,w_slot,player.cooldown,weapon])
			w_last = tick
			w_last_time = player.active_play_time
			w_ok = w_ok and budget() == w_resources() and state.ammo[1] >= 0 and state.ammo[1] <= 180 and player.cooldown > 0 and player.cooldown <= 0.21+0.000001
		super.shot(weapon)
	func collect_pickup(id: String) -> void:
		if not w_enabled:
			super.collect_pickup(id)
			return
		if not W_PICKUPS.has(id):
			w_pickup_calls.append([id,Engine.get_physics_frames(),budget().duplicate(true)])
			w_ok = false
			super.collect_pickup(id)
			return
		var spec: Dictionary = W_PICKUPS[id]
		var before: Dictionary = w_resources()
		w_pickup_calls.append([id,Engine.get_physics_frames(),before.duplicate(true)])
		var slot: int = int(spec.weapon)
		var gain: int = mini(180 if slot == 1 else 32,int(before.ammo[slot])+int(spec.amount))-int(before.ammo[slot])
		var marker = level.markers.get(id)
		w_ok = w_ok and w_current() and Engine.is_in_physics_frame() and budget() == before and not id in state.removed and is_instance_valid(marker) and marker.get_parent() == level and not marker.is_queued_for_deletion() and level.layout.data.pickups.filter(func(item): return item.id == id) == [spec] and player.position.distance_to(level.layout.world_position(spec.cell)) < 1.4 and _passive_trigger_visible(spec) and h_stack("/main.gd","update_passive_triggers") and h_stack("/player.gd","_physics_process")
		super.collect_pickup(id)
		if gain > 0:
			w_ok = w_ok and slot == 1 and before == w_base and w_activation == 0 and w_shots.is_empty() and gain == 13
			w_rivets += gain
			w_consumed[id] = w_consumed.get(id,0)+1
			w_removed.append(id)
			w_ok = w_ok and w_consumed[id] == 1 and not level.markers.has(id) and state.removed.count(id) == 1
		else:
			w_rejected[id] = w_rejected.get(id,0)+1
			w_ok = w_ok and level.markers.get(id) == marker and not marker.is_queued_for_deletion() and not id in state.removed
		w_ok = w_ok and budget() == w_resources() and state.removed == w_removed
	func activate_encounter(id: String) -> void:
		if not w_enabled:
			super.activate_encounter(id)
			return
		var prior: bool = "encounter:"+id in state.removed
		w_ok = w_ok and w_current() and id in ["reliquary_halo_return",W_GROUP.id]
		if not prior:
			var cell: Vector2 = Vector2(player.position.x,player.position.z)/4.0
			w_ok = w_ok and id == W_GROUP.id and w_activation == 0 and cell.is_equal_approx(cell.clamp(Vector2(26,8),Vector2(36.9,21.25))) and h_stack("/main.gd","_process") and not h_stack("/enemy.gd","take_damage") and state.keys == ["blood"]
		super.activate_encounter(id)
		if not prior:
			w_activation += 1
			w_removed.append("encounter:"+id)
			for actor in enemies:
				if actor.id in W_IDS:
					w_ok = w_ok and w_original(actor) and actor.active and actor.alerted and actor.hp == actor.max_hp
					w_activated[actor.id] = [actor.get_instance_id(),Engine.get_physics_frames()]
			w_ok = w_ok and w_activation == 1 and w_activated.size() == 8 and state.removed == w_removed
	func enemy_event(actor, event: String) -> void:
		w_observe_enemy(actor,event)
		super.enemy_event(actor,event)
	func w_observe_enemy(actor, event: String) -> void:
		if w_enabled:
			w_ok = w_ok and w_current() and Engine.is_in_physics_frame() and w_original(actor) and actor.active and w_activated.has(actor.id) and h_stack("/enemy.gd","_event")
			if event == "attack":
				w_attacks[actor.id] = Engine.get_physics_frames()
				w_roles[actor.kind] = w_roles.get(actor.kind,0)+1
				w_release = {"source":actor,"tick":Engine.get_physics_frames()}
				if actor.kind == "worker":
					var origin: Vector3 = actor.global_position+Vector3.UP*1.4
					var end: Vector3 = origin+(actor._committed_aim-origin).normalized()*30.0
					var query = PhysicsRayQueryParameters3D.create(origin,end,1|2|4)
					query.exclude = [actor.get_rid()]
					query.hit_from_inside = true
					w_release.merge({"origin":origin,"end":end,"hit":level.get_world_3d().direct_space_state.intersect_ray(query)})
			if event == "melee_contact":
				var intended = actor._committed_target
				var tick: int = int(w_attacks.get(actor.id,-1000))
				var age: int = Engine.get_physics_frames()-tick
				if not OS.is_debug_build() or actor.kind != "crawler" or actor.hp <= 0 or not w_melee_pending.is_empty() or not actor._valid_target(intended) or intended.get_parent() != level or actor.global_position.distance_to(intended.global_position) >= 1.9 or age < 0 or age > 12 or w_damage_attacks.has(actor.id+":"+str(tick)) or not h_stack("/enemy.gd","_try_melee") or not h_stack("/enemy.gd","_physics_process"):
					w_ok = false
					return
				var origin: Vector3 = actor.global_position+Vector3.UP*0.6
				var end: Vector3 = intended.global_position+Vector3.UP*0.7
				var query = PhysicsRayQueryParameters3D.create(origin,end,1|2|4)
				query.exclude = [actor.get_rid()]
				query.hit_from_inside = true
				var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(query)
				var victim = hit.get("collider")
				if not origin.is_finite() or not end.is_finite() or not (victim == player or w_original(victim) and victim.hp > 0) or hit.get("rid") != victim.get_rid():
					w_ok = false
					return
				if victim == player or victim.hp <= 12:
					w_melee_pending = {"source":actor,"release_tick":tick,"tick":Engine.get_physics_frames(),"map":level,"player":player,"intended":intended,"origin":origin,"end":end,"hit":hit,"victim_hp":0 if victim == player else victim.hp}
			if event == "death":
				w_deaths[actor.id] = w_deaths.get(actor.id,0)+1
				var player_fire: bool = actor.target == player and w_last == Engine.get_physics_frames() and player.shot_age(1) == 0.0 and Input.is_action_pressed("fire") and h_stack("/player.gd","fire") and aim_observation.get("actor_id","") == actor.id and aim_observation.get("tick",-1) == Engine.get_physics_frames() and aim_observation.get("level") == level and aim_observation.get("player") == player and aim_observation.get("weapon",-1) == 1
				var worker: bool = w_worker_contact(actor,false)
				var caster: bool = w_projectile_death(actor)
				var crawler: bool = w_crawler_contact(actor,false)
				var infighting: bool = worker or caster or crawler
				if crawler:
					w_damage_attacks[w_melee_pending.source.id+":"+str(w_melee_pending.release_tick)] = true
					w_melee_pending.clear()
				if worker: w_damage_attacks[w_release.source.id+":"+str(w_release.tick)] = true
				if caster:
					w_enemy_used[w_enemy_pending.id] = true
					w_enemy_pending.clear()
				w_finishes[actor.id] = "player" if player_fire else "infighting" if infighting else "unproven"
				w_removed.append(actor.id)
				w_ok = w_ok and actor.hp == 0 and actor.collision_layer == 0 and actor.collision_mask == 0 and state.removed.count(actor.id) == 1 and w_deaths[actor.id] == 1 and (player_fire or infighting) and state.removed == w_removed
	func _debug_projectile_event(projectile: Node3D, event: String, data: Dictionary) -> void:
		if w_enabled: w_observe_projectile(projectile,event,data)
		super._debug_projectile_event(projectile,event,data)
	func w_observe_projectile(projectile: Node3D, event: String, data: Dictionary) -> void:
		var source = projectile.shooter
		var id: int = projectile.get_instance_id()
		w_ok = w_ok and w_current() and OS.is_debug_build() and Engine.is_in_physics_frame() and projectile.get_script() == preload("res://scripts/projectile.gd") and projectile.game == self and projectile._current_map() and projectile.is_physics_processing() and w_original(source) and source.id == "reliquary_enemy_15" and source.kind == "caster" and data.get("projectile") == projectile and data.get("source") == source and data.get("map") == level and data.get("player") == player and data.get("tick",-1) == Engine.get_physics_frames() and data.get("position") == projectile.global_position and data.get("velocity") == projectile.velocity and data.get("lifetime") == projectile.lifetime and projectile.blast_damage == 0 and data.get("blast_damage") == 0 and projectile.velocity.is_finite() and is_equal_approx(projectile.velocity.length(),12.0) and projectile.lifetime > 0 and projectile.lifetime <= 4.0
		if event == "configured_birth":
			w_ok = w_ok and not w_births.has(id) and source.hp > 0 and source.active and w_attacks.get(source.id,-1) == Engine.get_physics_frames() and projectile.lifetime == 4.0 and not projectile.is_queued_for_deletion() and data.get("origin") is Vector3 and data.get("destination") is Vector3 and h_stack("/enemy.gd","_release_attack")
			if data.get("origin") is Vector3 and data.get("destination") is Vector3:
				w_ok = w_ok and data.origin.is_finite() and data.destination.is_finite() and data.origin == projectile.global_position and projectile.velocity.is_equal_approx((data.destination-data.origin).normalized()*12.0)
			w_births[id] = {"source":source,"tick":Engine.get_physics_frames(),"reference":weakref(projectile),"map":level,"player":player}
			return
		if not event in ["queued_player_contact","queued_enemy_contact"] or not w_births.has(id) or w_contacts.has(id) or w_enemy_contacts.has(id) or not w_pending.is_empty() or not w_enemy_pending.is_empty() or not (data.get("hit") is Dictionary and data.get("ray_start") is Vector3 and data.get("ray_end") is Vector3):
			w_ok = false
			return
		var birth: Dictionary = w_births[id]
		var hit: Dictionary = data.hit
		var victim = hit.get("collider")
		var victim_ok: bool = victim == player if event == "queued_player_contact" else w_original(victim) and victim != source and victim.hp > 0
		if not victim_ok:
			w_ok = false
			return
		w_ok = w_ok and source == birth.source and birth.reference.get_ref() == projectile and birth.map == level and birth.player == player and projectile.is_queued_for_deletion() and data.tick >= birth.tick and data.tick-birth.tick <= 241 and hit.get("rid") == victim.get_rid() and hit.get("position") == projectile.global_position and data.ray_start.is_finite() and data.ray_end.is_finite() and data.ray_end.is_equal_approx(data.ray_start+projectile.velocity*minf(1.0/60.0,projectile.lifetime)) and h_stack("/projectile.gd","_physics_process")
		var query = PhysicsRayQueryParameters3D.create(data.ray_start,data.ray_end,1|2|4)
		query.exclude = [source.get_rid()]
		query.hit_from_inside = true
		w_ok = w_ok and level.get_world_3d().direct_space_state.intersect_ray(query) == hit
		if event == "queued_player_contact":
			w_contacts[id] = data.duplicate(true)
			w_pending = {"id":id,"data":data.duplicate(true)}
		else:
			var contact: Dictionary = data.duplicate(true)
			contact.merge({"victim_id":victim.get_instance_id(),"victim_hp":victim.hp})
			w_enemy_contacts[id] = contact
			if victim.hp <= 14: w_enemy_pending = {"id":id,"data":contact}
	func hurt_player(amount: int) -> void:
		if not w_enabled:
			super.hurt_player(amount)
			return
		var attributed: bool = false
		var source_id: String = ""
		if amount == 14 and not w_pending.is_empty():
			var id: int = w_pending.id
			var data: Dictionary = w_pending.data
			attributed = w_births.has(id) and w_contacts.has(id) and not w_projectile_used.has(id) and data.tick == Engine.get_physics_frames() and is_instance_valid(data.projectile) and data.projectile.is_queued_for_deletion() and data.projectile._current_map() and w_original(data.source) and data.map == level and data.player == player and data.hit.collider == player and h_stack("/projectile.gd","_physics_process")
			if attributed:
				w_projectile_used[id] = true
				source_id = data.source.id
				w_pending.clear()
		elif w_pending.is_empty() and amount == 10:
			attributed = w_worker_contact(player,true)
			if attributed:
				source_id = w_release.source.id
				w_damage_attacks[source_id+":"+str(w_release.tick)] = true
		elif w_pending.is_empty() and amount == 12:
			attributed = w_crawler_contact(player,true)
			if attributed:
				source_id = w_melee_pending.source.id
				w_damage_attacks[source_id+":"+str(w_melee_pending.release_tick)] = true
				w_melee_pending.clear()
		w_ok = w_ok and w_current() and Engine.is_in_physics_frame() and attributed and state.difficulty == 1 and budget() == w_resources()
		var absorbed: int = mini(w_base.armor-w_absorbed,int(amount/3))
		w_absorbed += absorbed
		w_health_loss += amount-absorbed
		w_hurts.append([Engine.get_physics_frames(),source_id,amount,absorbed])
		super.hurt_player(amount)
		w_ok = w_ok and budget() == w_resources()
	func interact() -> void:
		if not w_enabled:
			super.interact()
			return
		var spec: Dictionary = nearest_interaction()
		var valid: bool = spec == W_IVORY and w_selection(spec) and w_pending_key.is_empty() and w_deaths.size() == 8 and W_IDS.all(func(id): return w_deaths.get(id,0) == 1 and w_finishes.get(id,"unproven") in ["player","infighting"]) and budget() == w_resources()
		w_ok = w_ok and valid
		if valid:
			w_pending_key = spec.id
			w_inputs.append([spec.id,Engine.get_physics_frames(),player.get_instance_id(),level.get_instance_id()])
		super.interact()
		w_pending_key = ""
	func w_selection(spec: Dictionary) -> bool:
		if not w_current() or not Engine.is_in_physics_frame() or not Input.is_action_pressed("interact") or not h_stack("/player.gd","_physics_process") or spec.is_empty(): return false
		var marker = level.markers.get(spec.id)
		if not is_instance_valid(marker) or marker.get_parent() != level or marker.is_queued_for_deletion() or spec.id in state.removed: return false
		# Repeat the actual nearest/range/bearing/static-LOS selection independently.
		var selected: Dictionary = {}
		var distance: float = 4.5
		for candidate in level.layout.data.interactions+level.layout.data.doors:
			if candidate.id in state.removed or candidate.get("kind") == "checkpoint": continue
			var point: Vector3 = level.layout.world_position(candidate.cell)
			var gap: float = player.position.distance_to(point)
			var aim: Vector3 = point+Vector3.UP*(float(candidate.size[1])/2.0 if candidate.has("size") else 0.7)
			if gap >= distance or (-player.camera.global_basis.z).dot((aim-player.camera.global_position).normalized()) <= 0.4: continue
			var ray = PhysicsRayQueryParameters3D.create(player.camera.global_position,aim,1)
			var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(ray)
			if not hit.is_empty() and hit.collider != level.doors.get(candidate.id): continue
			selected = candidate
			distance = gap
		return selected == spec
	func collect_key(id: String) -> void:
		if w_enabled:
			w_ok = w_ok and id == W_IVORY.id and w_pending_key == id and w_selection(W_IVORY) and h_stack("/main.gd","interact") and state.keys == ["blood"] and w_ivory_calls == 0 and w_deaths.size() == 8 and budget() == w_resources()
		super.collect_key(id)
		if w_enabled:
			w_ivory_calls += 1
			w_removed.append(id)
			w_ok = w_ok and w_ivory_calls == 1 and state.keys == ["blood","ivory"] and state.removed == w_removed and state.removed.count(id) == 1 and not level.markers.has(id) and message == W_IVORY.text and budget() == w_resources()
	func unlock_door(id: String) -> bool:
		if w_enabled: w_ok = false
		return super.unlock_door(id)
	func _capture_actor_state() -> bool:
		if w_enabled: w_ok = false
		return super._capture_actor_state()
	func _save() -> Error:
		if w_enabled: w_ok = false
		return super._save()

var w_started: bool = false
var w_epoch: int = 0
var w_wall: int = 0
var w_fields: Array = []
var w_frozen: Dictionary = {}
var w_actors: Array = []
var w_markers: Dictionary = {}
var w_time: float = 0.0
var w_actor_image: Variant
var w_fighting: bool = false

func run() -> void:
	if not await walk_through_wheel_ivory(WheelMain.new()):
		await finish(1)
		return
	print("PASS source-native virtual-input original Wheel8 and explicit Ivory after earned first3/Halo/Blood/story/Return; not full-fourth/eight, physical controls, rendered/audio/performance or standalone acceptance")
	await finish(0)

func walk_through_wheel_ivory(observer: WheelMain, profile_prefix: String = "") -> bool:
	if not expect(FileAccess.get_sha256("res://tests/test_reliquary_halo_return.gd") == W_RETURN_SHA,"Exact nonquitting Return extraction; parent reconciles adoption"):
		if is_instance_valid(observer) and observer != game and not observer.is_inside_tree(): observer.free()
		return false
	if not await walk_through_halo_return(observer,profile_prefix if not profile_prefix.is_empty() else "user://reliquary_wheel_ivory_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())) or not start_wheel(): return false
	if not "--omit-wheel-approach" in OS.get_cmdline_user_args():
		if not await blood_story_route(W_APPROACH): return false
	if not expect(game.w_activation == 1 and game.w_activated.size() == 8,W_ACTIVATION_GUARD): return false
	w_fighting = true
	if not await wheel_fight(480): return false
	if "--omit-wheel-fire" in OS.get_cmdline_user_args(): return wheel_earned()
	if not await blood_story_route(W_CLOSE.slice(0,3)) or not await wheel_fight(240) or not await blood_story_route(W_CLOSE.slice(3)) or not await wheel_fight(240): return false
	w_fighting = false
	release_actions()
	if not wheel_earned(): return false
	for frame in range(W_DRAIN):
		if not await route_tick(): return false
	await process_frame
	if not expect(game.w_births.values().all(func(birth): return birth.reference.get_ref() == null) and game.w_pending.is_empty() and game.w_enemy_pending.is_empty(),"Original finite caster projectiles drain before explicit Ivory"): return false
	if not await wheel_ivory_input(): return false
	return wheel_result()

func start_wheel() -> bool:
	if not expect(game is WheelMain and game.q_enabled and game.q_ok and return_result() and game.budget() == W_CARRY and route_player.position.distance_to(route_level.layout.world_position([19,11])) < 0.2,"Exact actual reviewed Return boundary100HP190armor167pistol32shells at original central endpoint; not a save surrogate"): return false
	if not expect(W_LIMIT == (W_APPROACH.size()+W_CLOSE.size())*HOP_LIMIT+480+240+240+W_DRAIN+W_INPUT,"Fresh17 split hops plus fixed combat/drain/input budgets"): return false
	if not expect(route_level.layout.data.encounters.filter(func(item): return item.id == W_GROUP.id) == [W_GROUP] and route_level.layout.data.interactions.filter(func(item): return item.id == W_IVORY.id) == [W_IVORY],"Exact original Wheel group/cue and explicit Ivory"): return false
	for id in W_PICKUPS:
		if not expect(route_level.layout.data.pickups.filter(func(item): return item.id == id) == [W_PICKUPS[id]] and route_level.markers.has(id),"Original finite Wheel approach rivets"): return false
	for actor in game.enemies:
		var capsule: CollisionShape3D = actor.get_child(0)
		w_actors.append({"instance":actor.get_instance_id(),"age":actor.age,"position":actor.position,"yaw":actor.rotation.y,"active":actor.active,"alerted":actor.alerted,"shape_disabled":capsule.disabled,"capsule":capsule.get_instance_id(),"shape":capsule.shape.get_instance_id(),"capsule_position":capsule.position,"radius":capsule.shape.radius,"height":capsule.shape.height})
	for id in route_level.markers: w_markers[id] = weakref(route_level.markers[id])
	var actual_fields: Array = []
	for property in game.get_property_list():
		if str(property.name).begins_with("q_") and property.name != "q_enabled": actual_fields.append(property.name)
	actual_fields.sort()
	var declared: Array = W_RETURN_FIELDS.duplicate()
	declared.sort()
	if not expect(actual_fields == declared,"Freeze EVERY Return q_ field except the retired flag, including shot/resource/release/contact witnesses"): return false
	w_fields = q_fields+W_RETURN_FIELDS
	w_frozen = observer_witness(w_fields)
	w_actor_image = game.state.actors.duplicate(true) if game.state.actors is Array else game.state.actors
	game.w_base = game.q_resources().duplicate(true)
	game.w_removed = game.state.removed.duplicate()
	w_time = route_player.active_play_time
	game.w_shot_start_time = w_time
	game.w_shot_start_age = route_player.shot_age(1)
	release_actions()
	game.q_enabled = false
	w_epoch = Engine.get_physics_frames()
	w_wall = Time.get_ticks_usec()
	game.w_enabled = true
	w_started = true
	return live_route()

func east_elapsed() -> int:
	return Engine.get_physics_frames()-w_epoch if w_started else super.east_elapsed()

func route_tick() -> bool:
	if not w_started: return await super.route_tick()
	if not live_route() or not expect(game.state.health > 24,"Finite Wheel survival stop before Recovery; no inferred health safety"): return false
	await physics_frame
	return live_route() and expect(game.state.health > 24,"Finite Wheel survival stop before Recovery; no inferred health safety")

func wheel_fight(limit: int) -> bool:
	for frame in range(limit):
		if game.w_deaths.size() == 8: break
		release_actions()
		east_fire()
		if not await route_tick(): return false
	release_actions()
	return live_route()

func east_fire() -> bool:
	if not w_started: return super.east_fire()
	Input.action_release("fire")
	if not w_fighting or game.w_activation != 1 or "--omit-wheel-fire" in OS.get_cmdline_user_args() or game.w_shots.size() >= W_SHOT_CAP or game.state.weapon != 1: return false
	var selected = null
	var nearest: float = 140.0
	for actor in game.enemies:
		if not game.w_original(actor) or not actor.active or actor.hp <= 0: continue
		if actor.kind == "caster" and game.w_births.is_empty(): continue
		if game.w_roles.get(actor.kind,0) == 0 and game.enemies.filter(func(other): return game.w_original(other) and other.kind == actor.kind and other.hp > 0).size() == 1: continue
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
	if not w_started: return super.clear_point(cell)
	if cell[0] < 18.75 or cell[0] > 35.75 or cell[1] < 10.75 or cell[1] > 28.75: return null
	var layout = route_level.layout
	if not layout.is_walkable(Vector2i(floori(cell[0]),floori(cell[1]))): return null
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

func wheel_earned() -> bool:
	return live_route() and expect(game.w_deaths.size() == 8 and W_IDS.all(func(id): return game.w_deaths.get(id,0) == 1 and game.w_finishes.get(id,"unproven") in ["player","infighting"]) and ["crawler","worker","caster"].all(func(role): return game.w_roles.get(role,0) > 0) and not game.w_births.is_empty() and game.w_shots.size() > 0 and game.w_shots.size() <= W_SHOT_CAP,W_EARNING_GUARD)

func wheel_ivory_input() -> bool:
	aim_interaction(W_IVORY.cell)
	var began: int = east_elapsed()
	if not "--omit-ivory-interact" in OS.get_cmdline_user_args(): interaction_input(true)
	if not await route_tick(): return false
	await process_frame
	if not live_route(): return false
	interaction_input(false)
	if not await route_tick(): return false
	release_actions()
	await process_frame
	return live_route() and expect(east_elapsed()-began <= W_INPUT and game.w_ivory_calls == 1 and game.w_inputs.size() == 1 and game.state.keys == ["blood","ivory"] and game.state.removed.count(W_IVORY.id) == 1 and w_markers[W_IVORY.id].get_ref() == null,W_IVORY_GUARD)

func wheel_result() -> bool:
	var view: Dictionary = game.hud.view
	var resources: Dictionary = game.w_resources()
	if not expect(view.get("seals",[]) == [{"key":"blood","owned":true},{"key":"ivory","owned":true}] and view.get("objective","") == "OPEN GATE" and view.get("health",-1) == resources.health and view.get("armor",-1) == resources.armor and view.get("weapon_name","") == "RIVET PISTOL" and view.get("ammo","") == str(resources.ammo[1]) and view.get("capacity","") == "CAP 180","Automatic Wheel HUD reflects earned seals/objective and independent resource ledger"):
		return false
	if not expect(game.hud.labels.Objective.text == "OPEN GATE" and game.hud.labels.SealState.text == "BLOOD [+]  IVORY [+]" and game.hud.labels.VitalValue.text == str(resources.health) and game.hud.labels.ArmorValue.text == str(resources.armor) and game.hud.labels.WeaponName.text == "RIVET PISTOL" and game.hud.labels.AmmoValue.text == str(resources.ammo[1]) and game.hud.labels.AmmoCapacity.text == "CAP 180","Actual native Wheel HUD labels reflect earned state; not rendered-quality evidence"):
		return false
	print("RELIQUARY_WHEEL_IVORY_LIMIT frames=",east_elapsed()," wall_us=",Time.get_ticks_usec()-w_wall," position=",route_player.position," resources=",game.w_resources()," shots=",game.w_shots," consumed=",game.w_consumed," pickup_calls=",game.w_pickup_calls," roles=",game.w_roles," births=",game.w_births.size()," contacts=",game.w_contacts.size()," enemy_contacts=",game.w_enemy_contacts.size()," hurts=",game.w_hurts," deaths=",game.w_deaths," provenance=",game.w_finishes," ivory_inputs=",game.w_inputs)
	return wheel_earned() and expect(game.w_ivory_calls == 1 and game.w_inputs.size() == 1 and game.w_consumed == {"reliquary_wheel_approach_rivets":1} and game.w_rivets == 13 and w_markers["reliquary_wheel_approach_rivets"].get_ref() == null and game.w_projectile_used.size() == game.w_contacts.size() and game.w_births.values().all(func(birth): return birth.reference.get_ref() == null) and route_player.position.distance_to(route_level.layout.world_position(W_IVORY.cell)) < 0.2,"Exact8 native Wheel deaths plus explicit Ivory once; only13 capped native rivets, observed damage and all projectile/marker drains")

func live_route() -> bool:
	if not w_started: return super.live_route()
	if not expect(east_elapsed() <= W_LIMIT and Time.get_ticks_usec()-w_wall <= W_SECONDS*1000000,"Fresh Wheel epoch/bounds independent of all completed phases"): return false
	if not expect(game.w_ok and game.w_current() and not paused and game.get_instance_id() == r_main_id and game.state.get_instance_id() == r_campaign_id and game.progress_path == r_profile and game.settings_path == game.r_settings_origin and game.level == route_level and game.player == route_player and not game.loaded_positions and game.is_processing() and game.is_physics_processing() and route_player.is_physics_processing() and route_player.position.is_finite() and game.enemies.size() == 31 and game.scene_roster_matches(),"Same native Main/Campaign/profile/Player/original31; no recovery, unregistered actor or scene replacement"): return false
	if not expect(observer_witness(w_fields) == w_frozen and observer_witness(b_fields) == b_frozen and observer_witness(h_fields) == h_frozen and observers_retired() and not game.h_enabled and not game.b_enabled and not game.q_enabled and observer_witness(q_fields) == q_frozen and retired.all(func(ref): return ref.get_ref() == null) and x_marker_refs.values().all(func(ref): return ref.get_ref() == null),"All accepted prefix/Halo/Blood history frozen, only Return observer retired"): return false
	for refs in [h_marker_refs,b_markers,q_markers]:
		for id in refs:
			if id in w_frozen.q_removed and not expect(refs[id].get_ref() == null,"Every old consumed marker drains: "+id): return false
	for index in range(R_ACTORS.size()):
		var spec: Array = R_ACTORS[index]
		var actor = game.enemies[index]
		var prior: Dictionary = w_actors[index]
		var capsule: CollisionShape3D = actor.get_child(0)
		if not expect(capsule.get_instance_id() == prior.capsule and capsule.shape.get_instance_id() == prior.shape and capsule.position == prior.capsule_position and capsule.shape.radius == prior.radius and capsule.shape.height == prior.height,"All31 original capsule and shape identities/dimensions"): return false
		if not expect(is_instance_valid(actor) and actor.id == spec[0] and actor.get_instance_id() == prior.instance and actor.get_instance_id() == game.h_bindings[actor.id] and actor.get_script() == game.Enemy and actor.kind == spec[1] and actor.max_hp == spec[2] and actor._current_map() and actor.is_physics_processing() and actor.age-prior.age >= float(east_elapsed()-2)/60.0 and (actor.get_child(0) as CollisionShape3D).disabled == prior.shape_disabled,"Original native identity/age/capsule: "+spec[0]): return false
		if actor.id in W_IDS:
			if game.w_activation == 0 and not expect(actor.hp == spec[2] and actor.position == prior.position and actor.rotation.y == prior.yaw and not actor.alerted,"Wheel actors retain original fullHP/pose until real region activation"): return false
			if not expect(game.w_original(actor) and actor.hp >= 0 and actor.hp <= spec[2] and actor.active == (game.w_activation == 1) and actor.alerted == (game.w_activation == 1) and (actor.hp > 0 or game.w_deaths.get(actor.id,0) == 1 and game.w_finishes.get(actor.id,"unproven") in ["player","infighting"] and actor.collision_layer == 0 and actor.collision_mask == 0 and game.state.removed.count(actor.id) == 1),"Only eight original Wheel actors change through automatic activation/native combat"): return false
			if actor.hp > 0 and not expect(actor.collision_layer == 4 and actor.collision_mask == 7,"Living Wheel capsule stays native"): return false
		elif not expect(actor.position == prior.position and actor.rotation.y == prior.yaw and actor.active == prior.active and actor.alerted == prior.alerted and (actor.hp == 0 and actor.collision_layer == 0 and actor.collision_mask == 0 and game.state.removed.count(actor.id) == 1 if actor.id in H_IDS+Q_IDS else actor.hp == spec[2] and not actor.active and not actor.alerted and actor.collision_layer == 4 and actor.collision_mask == 7),"Original11 corpses and other12 inactive/fullHP/poses unchanged"): return false
	for id in w_markers:
		if game.w_consumed.has(id) or id == W_IVORY.id and game.w_ivory_calls == 1:
			if not expect(not route_level.markers.has(id) and game.state.removed.count(id) == 1,"Allowed original supply removed once"): return false
		elif not expect(route_level.markers.has(id) and w_markers[id].get_ref() == route_level.markers[id] and not route_level.markers[id].is_queued_for_deletion() and not id in game.state.removed,"Every other original marker owner preserved: "+id): return false
	if not expect(route_level.markers.size() == w_markers.size()-game.w_consumed.size()-game.w_ivory_calls,"No extra/replacement markers"): return false
	if not expect(game.w_pending.is_empty() and game.w_enemy_pending.is_empty() and game.w_melee_pending.is_empty(),"All native contact witnesses consumed synchronously"): return false
	return expect(game.budget() == game.w_resources() and game.state.health > 0 and game.state.health <= 100 and game.state.armor >= 0 and game.state.armor <= 190 and game.state.ammo[1] >= 0 and game.state.ammo[1] <= 180 and game.state.keys == (["blood","ivory"] if game.w_ivory_calls == 1 else ["blood"]) and game.state.discoveries == [3] and game.state.removed == game.w_removed and game.state.checkpoint_id == "entry" and game.state.checkpoint == h_frozen.r_start and game.state.level_start == h_frozen.r_start and game.state.actors == w_actor_image and FileAccess.get_sha256(r_profile) == r_saved_sha and game.w_ticks >= east_elapsed()-2 and absf(route_player.active_play_time-w_time-float(east_elapsed())/60.0) <= 2.0/60.0,"Actual ammo/pickup/hurt ledger and earned Blood/story; original actor image/start/checkpoint/disk exact")
