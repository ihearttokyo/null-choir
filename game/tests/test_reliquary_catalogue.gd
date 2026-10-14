extends "res://tests/test_reliquary_wheel_return.gd"

const C_RETURN_SHA = "bb0e909a8966d4d7e9d98a76617ec5fbb49bf61618a80181eca5750fb32edf98"
const C_IDS = ["reliquary_enemy_22","reliquary_enemy_23","reliquary_enemy_24","reliquary_enemy_25","reliquary_enemy_26"]
const C_GROUP = {"id":"reliquary_catalogue","region":[17.0,9.0,21.9,9.5],"enemy_ids":C_IDS,"requires":["blood","ivory"],"cue":{"text":"THE COMMAND CHANNEL RECOGNIZES BOTH REGISTERS","light_ids":["reliquary_catalogue_feed"],"sound":"seal_release"}}
const C_CARRY = {"health":100,"armor":184,"ammo":[0,167,32,0,0,0],"owned_weapons":[0,1,2],"weapon":1}
const C_APPROACH = [[21.75,11],[21.75,9.25]]
const C_CLOSE = [[18.75,9.25],[17.5,9.25]]
const C_SHOT_CAP = 40
const C_FIGHT_LIMIT = 480
const C_DRAIN = 246
const C_LIMIT = 4*240+C_FIGHT_LIMIT+C_DRAIN
const C_SECONDS = float(C_LIMIT)/60.0+2.0
const C_ACTIVATION_GUARD = "NATIVE RED Catalogue requires actual both-seal-gated original region-driven Main._process activation"
const C_EARNING_GUARD = "NATIVE RED Catalogue requires all5 original provenanced native deaths and actual bounded Player pistol input before closure"
const C_RETURN_FIELDS = ["v_base","v_health_gain","v_pickup_calls","v_ok","v_ticks","v_activation","v_activated","v_removed","v_shots","v_last","v_slot","v_last_time","v_shot_start_age","v_shot_start_time","v_rivets","v_consumed","v_rejected","v_health_loss","v_absorbed","v_hurts","v_attacks","v_roles","v_deaths","v_finishes","v_release","v_melee_pending","v_damage_attacks"]

class CatalogueMain:
	extends "res://tests/test_reliquary_wheel_return.gd".WheelReturnMain
	var c_enabled: bool = false
	var c_base: Dictionary = {}
	var c_pickup_calls: Array = []
	var c_ok: bool = true
	var c_ticks: int = 0
	var c_shots: Array = []
	var c_last: int = -1
	var c_slot: float = -1.0
	var c_last_time: float = -INF
	var c_shot_start_age: float = INF
	var c_shot_start_time: float = 0.0
	var c_health_loss: int = 0
	var c_absorbed: int = 0
	var c_removed: Array = []
	var c_activation: int = 0
	var c_activated: Dictionary = {}
	var c_attacks: Dictionary = {}
	var c_roles: Dictionary = {}
	var c_damage_attacks: Dictionary = {}
	var c_hurts: Array = []
	var c_deaths: Dictionary = {}
	var c_finishes: Dictionary = {}
	var c_births: Dictionary = {}
	var c_contacts: Dictionary = {}
	var c_projectile_used: Dictionary = {}
	var c_pending: Dictionary = {}
	var c_release: Dictionary = {}
	var c_melee_pending: Dictionary = {}
	var c_enemy_contacts: Dictionary = {}
	var c_enemy_pending: Dictionary = {}
	var c_enemy_used: Dictionary = {}
	func c_current() -> bool:
		return h_current() and not h_enabled and not b_enabled and not q_enabled and not w_enabled and not v_enabled and c_enabled
	func c_resources() -> Dictionary:
		return {"health":c_base.health-c_health_loss,"armor":c_base.armor-c_absorbed,"ammo":[0,int(c_base.ammo[1])-c_shots.size(),32,0,0,0],"owned_weapons":[0,1,2],"weapon":1}
	func c_original(actor) -> bool:
		return is_instance_valid(actor) and actor.get_script() == Enemy and actor.id in C_IDS and h_bindings.get(actor.id,-1) == actor.get_instance_id() and actor._current_map() and actor.get_parent() == level and not actor.is_queued_for_deletion()
	func c_worker_contact(victim, repeat_ray: bool) -> bool:
		var source = c_release.get("source")
		if not c_original(source) or source.kind != "worker" or source.hp <= 0 or not source.active or c_release.get("tick",-1) != Engine.get_physics_frames() or not h_stack("/enemy.gd","_attack") or not h_stack("/enemy.gd","_release_attack"): return false
		var key: String = source.id+":"+str(c_release.tick)
		var hit: Dictionary = c_release.hit
		if c_damage_attacks.has(key) or hit.get("collider") != victim or hit.get("rid") != victim.get_rid() or victim.get_parent() != level: return false
		var origin: Vector3 = source.global_position+Vector3.UP*1.4
		var end: Vector3 = origin+(source._committed_aim-origin).normalized()*30.0
		if origin != c_release.origin or end != c_release.end: return false
		if repeat_ray:
			var query = PhysicsRayQueryParameters3D.create(origin,end,1|2|4)
			query.exclude = [source.get_rid()]
			query.hit_from_inside = true
			if level.get_world_3d().direct_space_state.intersect_ray(query) != hit: return false
		return true
	func c_crawler_contact(victim, repeat_ray: bool) -> bool:
		if c_melee_pending.is_empty(): return false
		var source = c_melee_pending.source
		var tick: int = c_melee_pending.release_tick
		var age: int = Engine.get_physics_frames()-tick
		if not c_original(source) or source.kind != "crawler" or source.hp <= 0 or not source.active or c_melee_pending.tick != Engine.get_physics_frames() or c_melee_pending.map != level or c_melee_pending.player != player or c_attacks.get(source.id,-1) != tick or age < 0 or age > 12 or c_damage_attacks.has(source.id+":"+str(tick)) or not h_stack("/enemy.gd","_try_melee") or not h_stack("/enemy.gd","_attack"): return false
		var hit: Dictionary = c_melee_pending.hit
		if hit.get("collider") != victim or hit.get("rid") != victim.get_rid() or victim.get_parent() != level: return false
		var intended = c_melee_pending.intended
		if not is_instance_valid(intended) or source._committed_target != intended or source.global_position.distance_to(intended.global_position) >= 1.9: return false
		var origin: Vector3 = source.global_position+Vector3.UP*0.6
		var end: Vector3 = intended.global_position+Vector3.UP*0.7
		if origin != c_melee_pending.origin or end != c_melee_pending.end: return false
		if repeat_ray:
			var query = PhysicsRayQueryParameters3D.create(origin,end,1|2|4)
			query.exclude = [source.get_rid()]
			query.hit_from_inside = true
			if level.get_world_3d().direct_space_state.intersect_ray(query) != hit: return false
		else:
			if c_melee_pending.victim_hp <= 0 or c_melee_pending.victim_hp > 12: return false
		return true
	func c_projectile_death(victim) -> bool:
		if c_enemy_pending.is_empty(): return false
		var id: int = c_enemy_pending.id
		var data: Dictionary = c_enemy_pending.data
		var projectile = data.projectile
		if not c_births.has(id) or not c_enemy_contacts.has(id) or c_enemy_used.has(id) or not is_instance_valid(projectile): return false
		var birth: Dictionary = c_births[id]
		return data.tick == Engine.get_physics_frames() and data.hit.collider == victim and data.hit.rid == victim.get_rid() and data.victim_id == victim.get_instance_id() and data.victim_hp > 0 and data.victim_hp <= 14 and data.map == level and data.player == player and birth.source == data.source and birth.reference.get_ref() == projectile and c_original(data.source) and projectile.shooter == data.source and projectile.is_queued_for_deletion() and projectile._current_map() and h_stack("/projectile.gd","_physics_process") and h_stack("/enemy.gd","take_damage")
	func _physics_process(delta: float) -> void:
		super._physics_process(delta)
		if not c_enabled: return
		c_ok = c_ok and c_enemy_pending.is_empty() and c_melee_pending.is_empty() and c_current() and absf(delta-1.0/60.0) < 0.000001
		c_ticks += 1
		if not Input.is_action_pressed("fire"): c_slot = -1.0
	func shot(weapon: int) -> void:
		if c_enabled:
			var tick: int = Engine.get_physics_frames()
			c_slot = entry_slot(tick,c_last,c_slot,weapon)
			var elapsed: float = player.active_play_time-c_shot_start_time
			c_ok = c_ok and c_current() and Engine.is_in_physics_frame() and weapon == 1 and state.weapon == 1 and Input.is_action_pressed("fire") and c_slot >= 0.0 and player.shot_age(1) == 0.0 and h_stack("/player.gd","fire") and player.active_play_time > c_last_time and (c_shots.size() > 0 or c_shot_start_age+elapsed+0.000001 >= 0.21)
			c_ok = c_ok and c_activation == 1 and c_shots.size() < C_SHOT_CAP
			c_shots.append([tick,player.active_play_time,c_slot,player.cooldown,weapon])
			c_last = tick
			c_last_time = player.active_play_time
			c_ok = c_ok and budget() == c_resources() and state.ammo[1] >= 0 and state.ammo[1] <= 180 and player.cooldown > 0 and player.cooldown <= 0.21+0.000001
		super.shot(weapon)
	func collect_pickup(id: String) -> void:
		if c_enabled:
			c_pickup_calls.append([id,Engine.get_physics_frames(),budget().duplicate(true)])
			c_ok = false
		super.collect_pickup(id)
	func activate_encounter(id: String) -> void:
		if not c_enabled:
			super.activate_encounter(id)
			return
		var prior: bool = "encounter:"+id in state.removed
		c_ok = c_ok and c_current() and id in [V_GROUP.id,C_GROUP.id]
		if not prior:
			var cell: Vector2 = Vector2(player.position.x,player.position.z)/4.0
			c_ok = c_ok and id == C_GROUP.id and c_activation == 0 and state.keys == ["blood","ivory"] and cell.is_equal_approx(cell.clamp(Vector2(17,9),Vector2(21.9,9.5))) and h_stack("/main.gd","_process") and not h_stack("/enemy.gd","take_damage")
		super.activate_encounter(id)
		if not prior:
			c_activation += 1
			c_removed.append("encounter:"+id)
			for actor in enemies:
				if actor.id in C_IDS:
					c_ok = c_ok and c_original(actor) and actor.active and actor.alerted and actor.hp == actor.max_hp
					c_activated[actor.id] = [actor.get_instance_id(),Engine.get_physics_frames()]
			c_ok = c_ok and c_activation == 1 and c_activated.size() == 5 and state.removed == c_removed and message == C_GROUP.cue.text
	func enemy_event(actor, event: String) -> void:
		c_observe_enemy(actor,event)
		super.enemy_event(actor,event)
	func c_observe_enemy(actor, event: String) -> void:
		if c_enabled:
			c_ok = c_ok and c_current() and Engine.is_in_physics_frame() and c_original(actor) and actor.active and c_activated.has(actor.id) and h_stack("/enemy.gd","_event")
			if event == "attack":
				c_attacks[actor.id] = Engine.get_physics_frames()
				c_roles[actor.kind] = c_roles.get(actor.kind,0)+1
				c_release = {"source":actor,"tick":Engine.get_physics_frames()}
				if actor.kind == "worker":
					var origin: Vector3 = actor.global_position+Vector3.UP*1.4
					var end: Vector3 = origin+(actor._committed_aim-origin).normalized()*30.0
					var query = PhysicsRayQueryParameters3D.create(origin,end,1|2|4)
					query.exclude = [actor.get_rid()]
					query.hit_from_inside = true
					c_release.merge({"origin":origin,"end":end,"hit":level.get_world_3d().direct_space_state.intersect_ray(query)})
			if event == "melee_contact":
				var intended = actor._committed_target
				var tick: int = int(c_attacks.get(actor.id,-1000))
				var age: int = Engine.get_physics_frames()-tick
				if not OS.is_debug_build() or actor.kind != "crawler" or actor.hp <= 0 or not c_melee_pending.is_empty() or not actor._valid_target(intended) or intended.get_parent() != level or actor.global_position.distance_to(intended.global_position) >= 1.9 or age < 0 or age > 12 or c_damage_attacks.has(actor.id+":"+str(tick)) or not h_stack("/enemy.gd","_try_melee") or not h_stack("/enemy.gd","_physics_process"):
					c_ok = false
					return
				var origin: Vector3 = actor.global_position+Vector3.UP*0.6
				var end: Vector3 = intended.global_position+Vector3.UP*0.7
				var query = PhysicsRayQueryParameters3D.create(origin,end,1|2|4)
				query.exclude = [actor.get_rid()]
				query.hit_from_inside = true
				var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(query)
				var victim = hit.get("collider")
				if not origin.is_finite() or not end.is_finite() or not (victim == player or c_original(victim) and victim.hp > 0) or hit.get("rid") != victim.get_rid():
					c_ok = false
					return
				if victim == player or victim.hp <= 12:
					c_melee_pending = {"source":actor,"release_tick":tick,"tick":Engine.get_physics_frames(),"map":level,"player":player,"intended":intended,"origin":origin,"end":end,"hit":hit,"victim_hp":0 if victim == player else victim.hp}
			if event == "death":
				c_deaths[actor.id] = c_deaths.get(actor.id,0)+1
				var player_fire: bool = actor.target == player and c_last == Engine.get_physics_frames() and player.shot_age(1) == 0.0 and Input.is_action_pressed("fire") and h_stack("/player.gd","fire") and aim_observation.get("actor_id","") == actor.id and aim_observation.get("tick",-1) == Engine.get_physics_frames() and aim_observation.get("level") == level and aim_observation.get("player") == player and aim_observation.get("weapon",-1) == 1
				var worker: bool = c_worker_contact(actor,false)
				var caster: bool = c_projectile_death(actor)
				var crawler: bool = c_crawler_contact(actor,false)
				var infighting: bool = worker or caster or crawler
				if crawler:
					c_damage_attacks[c_melee_pending.source.id+":"+str(c_melee_pending.release_tick)] = true
					c_melee_pending.clear()
				if worker: c_damage_attacks[c_release.source.id+":"+str(c_release.tick)] = true
				if caster:
					c_enemy_used[c_enemy_pending.id] = true
					c_enemy_pending.clear()
				c_finishes[actor.id] = "player" if player_fire else "infighting" if infighting else "unproven"
				c_removed.append(actor.id)
				c_ok = c_ok and actor.hp == 0 and actor.collision_layer == 0 and actor.collision_mask == 0 and state.removed.count(actor.id) == 1 and c_deaths[actor.id] == 1 and (player_fire or infighting) and state.removed == c_removed
	func _debug_projectile_event(projectile: Node3D, event: String, data: Dictionary) -> void:
		if c_enabled: c_observe_projectile(projectile,event,data)
		super._debug_projectile_event(projectile,event,data)
	func c_observe_projectile(projectile: Node3D, event: String, data: Dictionary) -> void:
		var source = projectile.shooter
		var id: int = projectile.get_instance_id()
		c_ok = c_ok and c_current() and OS.is_debug_build() and Engine.is_in_physics_frame() and projectile.get_script() == preload("res://scripts/projectile.gd") and projectile.game == self and projectile._current_map() and projectile.is_physics_processing() and c_original(source) and source.id == "reliquary_enemy_26" and source.kind == "caster" and data.get("projectile") == projectile and data.get("source") == source and data.get("map") == level and data.get("player") == player and data.get("tick",-1) == Engine.get_physics_frames() and data.get("position") == projectile.global_position and data.get("velocity") == projectile.velocity and data.get("lifetime") == projectile.lifetime and projectile.blast_damage == 0 and data.get("blast_damage") == 0 and projectile.velocity.is_finite() and is_equal_approx(projectile.velocity.length(),12.0) and projectile.lifetime > 0 and projectile.lifetime <= 4.0
		if event == "configured_birth":
			c_ok = c_ok and not c_births.has(id) and source.hp > 0 and source.active and c_attacks.get(source.id,-1) == Engine.get_physics_frames() and projectile.lifetime == 4.0 and not projectile.is_queued_for_deletion() and data.get("origin") is Vector3 and data.get("destination") is Vector3 and h_stack("/enemy.gd","_release_attack")
			if data.get("origin") is Vector3 and data.get("destination") is Vector3:
				c_ok = c_ok and data.origin.is_finite() and data.destination.is_finite() and data.origin == projectile.global_position and projectile.velocity.is_equal_approx((data.destination-data.origin).normalized()*12.0)
			c_births[id] = {"source":source,"tick":Engine.get_physics_frames(),"reference":weakref(projectile),"map":level,"player":player}
			return
		if not event in ["queued_player_contact","queued_enemy_contact"] or not c_births.has(id) or c_contacts.has(id) or c_enemy_contacts.has(id) or not c_pending.is_empty() or not c_enemy_pending.is_empty() or not (data.get("hit") is Dictionary and data.get("ray_start") is Vector3 and data.get("ray_end") is Vector3):
			c_ok = false
			return
		var birth: Dictionary = c_births[id]
		var hit: Dictionary = data.hit
		var victim = hit.get("collider")
		var victim_ok: bool = victim == player if event == "queued_player_contact" else c_original(victim) and victim != source and victim.hp > 0
		if not victim_ok:
			c_ok = false
			return
		c_ok = c_ok and source == birth.source and birth.reference.get_ref() == projectile and birth.map == level and birth.player == player and projectile.is_queued_for_deletion() and data.tick >= birth.tick and data.tick-birth.tick <= 241 and hit.get("rid") == victim.get_rid() and hit.get("position") == projectile.global_position and data.ray_start.is_finite() and data.ray_end.is_finite() and data.ray_end.is_equal_approx(data.ray_start+projectile.velocity*minf(1.0/60.0,projectile.lifetime)) and h_stack("/projectile.gd","_physics_process")
		var query = PhysicsRayQueryParameters3D.create(data.ray_start,data.ray_end,1|2|4)
		query.exclude = [source.get_rid()]
		query.hit_from_inside = true
		c_ok = c_ok and level.get_world_3d().direct_space_state.intersect_ray(query) == hit
		if event == "queued_player_contact":
			c_contacts[id] = data.duplicate(true)
			c_pending = {"id":id,"data":data.duplicate(true)}
		else:
			var contact: Dictionary = data.duplicate(true)
			contact.merge({"victim_id":victim.get_instance_id(),"victim_hp":victim.hp})
			c_enemy_contacts[id] = contact
			if victim.hp <= 14: c_enemy_pending = {"id":id,"data":contact}
	func hurt_player(amount: int) -> void:
		if not c_enabled:
			super.hurt_player(amount)
			return
		var attributed: bool = false
		var source_id: String = ""
		if amount == 14 and not c_pending.is_empty():
			var id: int = c_pending.id
			var data: Dictionary = c_pending.data
			attributed = c_births.has(id) and c_contacts.has(id) and not c_projectile_used.has(id) and data.tick == Engine.get_physics_frames() and is_instance_valid(data.projectile) and data.projectile.is_queued_for_deletion() and data.projectile._current_map() and c_original(data.source) and data.map == level and data.player == player and data.hit.collider == player and h_stack("/projectile.gd","_physics_process")
			if attributed:
				c_projectile_used[id] = true
				source_id = data.source.id
				c_pending.clear()
		elif c_pending.is_empty() and amount == 10:
			attributed = c_worker_contact(player,true)
			if attributed:
				source_id = c_release.source.id
				c_damage_attacks[source_id+":"+str(c_release.tick)] = true
		elif c_pending.is_empty() and amount == 12:
			attributed = c_crawler_contact(player,true)
			if attributed:
				source_id = c_melee_pending.source.id
				c_damage_attacks[source_id+":"+str(c_melee_pending.release_tick)] = true
				c_melee_pending.clear()
		c_ok = c_ok and c_current() and Engine.is_in_physics_frame() and attributed and state.difficulty == 1 and budget() == c_resources()
		var absorbed: int = mini(c_base.armor-c_absorbed,int(amount/3))
		c_absorbed += absorbed
		c_health_loss += amount-absorbed
		c_hurts.append([Engine.get_physics_frames(),source_id,amount,absorbed])
		super.hurt_player(amount)
		c_ok = c_ok and budget() == c_resources()
	func interact() -> void:
		if c_enabled: c_ok = false
		super.interact()
	func collect_key(id: String) -> void:
		if c_enabled: c_ok = false
		super.collect_key(id)
	func unlock_door(id: String) -> bool:
		if c_enabled: c_ok = false
		return super.unlock_door(id)
	func _capture_actor_state() -> bool:
		if c_enabled: c_ok = false
		return super._capture_actor_state()
	func _save() -> Error:
		if c_enabled: c_ok = false
		return super._save()

var c_started: bool = false
var c_epoch: int = 0
var c_wall: int = 0
var c_fields: Array = []
var c_frozen: Dictionary = {}
var c_actors: Array = []
var c_markers: Dictionary = {}
var c_time: float = 0.0
var c_actor_image: Variant
var c_closed: bool = false
var c_fighting: bool = false
var c_closure_frames: int = 0
var c_drain_frames: int = 0

func run() -> void:
	if "--catalogue-pin-rejection" in OS.get_cmdline_user_args():
		await catalogue_pin_rejection()
		return
	if not await walk_through_catalogue(CatalogueMain.new()):
		await finish(1)
		return
	print("PASS source-native virtual-input original Catalogue5 after continuous earned first3/Halo/Blood/story/Return/Wheel/Ivory/Wheel RETURN; not full-fourth/eight, physical controls, rendered/audio/GPU/performance or standalone acceptance")
	await finish(0)

func catalogue_pin_rejection() -> void:
	if not expect(FileAccess.get_sha256("res://tests/test_reliquary_wheel_return.gd") != C_RETURN_SHA,"Pin rejection requires parent-owned deliberate dependency mismatch"):
		await finish(1)
		return
	var rejected_prefix: String = "user://reliquary_catalogue_pin_rejection_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	var observer = CatalogueMain.new()
	var reference = weakref(observer)
	var result: bool = await walk_through_catalogue(observer,rejected_prefix)
	var untouched: bool = game == null and root.get_child_count() == 0 and not FileAccess.file_exists(rejected_prefix+"_campaign.json") and not FileAccess.file_exists(rejected_prefix+"_preferences.json")
	var accepted: bool = expect(not result and reference.get_ref() == null and untouched,"Rejected pin frees only fresh unadopted observer; check unique fixture files, not unrelated default save")
	if is_instance_valid(observer): observer.free()
	await finish(0 if accepted else 1)

func walk_through_catalogue(observer: CatalogueMain, profile_prefix: String = "") -> bool:
	if not expect(FileAccess.get_sha256("res://tests/test_reliquary_wheel_return.gd") == C_RETURN_SHA,"Exact provisional nonquitting Wheel RETURN helper before observer/scene/profile adoption"):
		if is_instance_valid(observer) and observer != game and not observer.is_inside_tree() and observer.get_parent() == null: observer.free()
		return false
	var fixture_prefix: String = profile_prefix if not profile_prefix.is_empty() else "user://reliquary_catalogue_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	if not expect(game == null and is_instance_valid(observer) and observer.get_parent() == null and not observer.is_inside_tree() and fixture_prefix.begins_with("user://reliquary_catalogue_") and not fixture_prefix.contains("..") and not fixture_prefix.trim_prefix("user://").contains("/") and not fixture_prefix.contains("\\") and not FileAccess.file_exists(fixture_prefix+"_campaign.json") and not FileAccess.file_exists(fixture_prefix+"_preferences.json"),"Fresh detached supplied observer and unique Catalogue fixture paths before prefix adoption"):
		if is_instance_valid(observer) and observer != game and not observer.is_inside_tree() and observer.get_parent() == null: observer.free()
		return false
	if not await walk_through_wheel_return(observer,fixture_prefix) or not start_catalogue(): return false
	if not "--omit-catalogue-approach" in OS.get_cmdline_user_args():
		if not await blood_story_route(C_APPROACH): return false
	if not expect(game.c_activation == 1 and game.c_activated.size() == 5,C_ACTIVATION_GUARD): return false
	c_fighting = true
	for frame in range(C_FIGHT_LIMIT):
		if game.c_deaths.size() == 5: break
		release_actions()
		east_fire()
		if not await route_tick(): return false
	c_fighting = false
	release_actions()
	if not catalogue_earned(): return false
	var began: int = east_elapsed()
	if not await blood_story_route(C_CLOSE): return false
	c_closure_frames = east_elapsed()-began
	c_closed = true
	began = east_elapsed()
	for frame in range(C_DRAIN):
		if not await route_tick(): return false
	c_drain_frames = east_elapsed()-began
	await process_frame
	return catalogue_result()

func start_catalogue() -> bool:
	if not expect(game is CatalogueMain and game.v_enabled and game.v_ok and wheel_return_result() and game.budget() == C_CARRY and route_player.position.distance_to(route_level.layout.world_position([21,12.5])) < 0.2,"Exact live Wheel RETURN boundary100HP184armor167pistol32shells; same supplied observer/scene/profile"): return false
	if not expect(C_LIMIT == (C_APPROACH.size()+C_CLOSE.size())*HOP_LIMIT+C_FIGHT_LIMIT+C_DRAIN and C_LIMIT == 1686 and C_SECONDS == 30.1,"Fresh4 hops including settling plus480 combat and246 drain; upstream budgets unchanged"): return false
	if not expect(route_level.layout.data.encounters.filter(func(item): return item.id == C_GROUP.id) == [C_GROUP],"Exact original both-seal Catalogue group/region/cue"): return false
	for actor in game.enemies:
		var capsule: CollisionShape3D = actor.get_child(0)
		c_actors.append({"instance":actor.get_instance_id(),"age":actor.age,"position":actor.position,"yaw":actor.rotation.y,"active":actor.active,"alerted":actor.alerted,"shape_disabled":capsule.disabled,"capsule":capsule.get_instance_id(),"shape":capsule.shape.get_instance_id(),"capsule_position":capsule.position,"radius":capsule.shape.radius,"height":capsule.shape.height})
	for id in route_level.markers: c_markers[id] = weakref(route_level.markers[id])
	var actual_fields: Array = []
	for property in game.get_property_list():
		if str(property.name).begins_with("v_") and property.name != "v_enabled": actual_fields.append(property.name)
	actual_fields.sort()
	var declared: Array = C_RETURN_FIELDS.duplicate()
	declared.sort()
	if not expect(actual_fields == declared,"Freeze EVERY Wheel RETURN v_ field except retired flag, including all resources/inputs/contacts"): return false
	c_fields = v_fields+C_RETURN_FIELDS
	c_frozen = observer_witness(c_fields)
	c_actor_image = game.state.actors.duplicate(true) if game.state.actors is Array else game.state.actors
	game.c_base = game.v_resources().duplicate(true)
	game.c_removed = game.state.removed.duplicate()
	c_time = route_player.active_play_time
	game.c_shot_start_time = c_time
	game.c_shot_start_age = route_player.shot_age(1)
	release_actions()
	game.v_enabled = false
	c_epoch = Engine.get_physics_frames()
	c_wall = Time.get_ticks_usec()
	game.c_enabled = true
	c_started = true
	return live_route()

func east_elapsed() -> int:
	return Engine.get_physics_frames()-c_epoch if c_started else super.east_elapsed()

func route_tick() -> bool:
	if not c_started: return await super.route_tick()
	if not live_route() or not expect(game.state.health > 24,"Finite Catalogue survival stop before Recovery; do not weaken for omitted-fire diagnostics"): return false
	await physics_frame
	return live_route() and expect(game.state.health > 24,"Finite Catalogue survival stop before Recovery; do not weaken for omitted-fire diagnostics")

func east_fire() -> bool:
	if not c_started: return super.east_fire()
	Input.action_release("fire")
	if not c_fighting or game.c_activation != 1 or "--omit-catalogue-fire" in OS.get_cmdline_user_args() or game.c_shots.size() >= C_SHOT_CAP or game.state.weapon != 1: return false
	var selected = null
	var nearest: float = 140.0
	for actor in game.enemies:
		if not game.c_original(actor) or not actor.active or actor.hp <= 0: continue
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
	if not c_started: return super.clear_point(cell)
	if cell[0] < 17.25 or cell[0] > 21.9 or cell[1] < 9.0 or cell[1] > 12.75: return null
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

func catalogue_earned() -> bool:
	print("RELIQUARY_CATALOGUE_EARNING position=",route_player.position," frames=",east_elapsed()," activation=",game.c_activation," deaths=",game.c_deaths," provenance=",game.c_finishes," shots=",game.c_shots," survivors=",game.enemies.filter(func(actor): return game.c_original(actor) and actor.hp > 0).map(func(actor): return [actor.id,actor.position,actor.hp]))
	return live_route() and expect(game.c_activation == 1 and game.c_activated.size() == 5 and game.c_deaths.size() == 5 and C_IDS.all(func(id): return game.c_activated.has(id) and game.c_deaths.get(id,0) == 1 and game.c_finishes.get(id,"unproven") in ["player","infighting"]) and game.enemies.filter(func(actor): return game.c_original(actor)).all(func(actor): return actor.hp == 0) and game.c_shots.size() > 0 and game.c_shots.size() <= C_SHOT_CAP,C_EARNING_GUARD)

func catalogue_result() -> bool:
	var view: Dictionary = game.hud.view
	var resources: Dictionary = game.c_resources()
	if not expect(view.get("seals",[]) == [{"key":"blood","owned":true},{"key":"ivory","owned":true}] and view.get("objective","") == "OPEN GATE" and view.get("health",-1) == resources.health and view.get("armor",-1) == resources.armor and view.get("weapon_name","") == "RIVET PISTOL" and view.get("ammo","") == str(resources.ammo[1]) and view.get("capacity","") == "CAP 180","Automatic Catalogue HUD model reflects both earned seals and independent resources"): return false
	if not expect(game.hud.labels.Objective.text == "OPEN GATE" and game.hud.labels.SealState.text == "BLOOD [+]  IVORY [+]" and game.hud.labels.VitalValue.text == str(resources.health) and game.hud.labels.ArmorValue.text == str(resources.armor) and game.hud.labels.WeaponName.text == "RIVET PISTOL" and game.hud.labels.AmmoValue.text == str(resources.ammo[1]) and game.hud.labels.AmmoCapacity.text == "CAP 180","Actual automatic native HUD labels; models/text are not pixels"): return false
	print("RELIQUARY_CATALOGUE_LIMIT frames=",east_elapsed()," wall_us=",Time.get_ticks_usec()-c_wall," births=",game.c_births.size()," contacts=",game.c_contacts.size()," enemy_contacts=",game.c_enemy_contacts.size()," closure_frames=",c_closure_frames," drain_frames=",c_drain_frames," position=",route_player.position," resources=",resources," shots=",game.c_shots," pickup_calls=",game.c_pickup_calls," roles=",game.c_roles," hurts=",game.c_hurts," deaths=",game.c_deaths," provenance=",game.c_finishes)
	return catalogue_earned() and expect(c_closed and c_closure_frames > 0 and c_closure_frames <= C_CLOSE.size()*HOP_LIMIT and c_drain_frames == C_DRAIN and route_player.position.distance_to(route_level.layout.world_position(C_CLOSE.back())) < 0.2 and game.c_pickup_calls.is_empty() and game.c_projectile_used.size() == game.c_contacts.size() and game.c_births.values().all(func(birth): return birth.reference.get_ref() == null) and game.c_pending.is_empty() and game.c_enemy_pending.is_empty() and game.c_melee_pending.is_empty(),"Exact5 original deaths before bounded two-hop closure and finite projectile drain; all supplies and checkpoint untouched")

func live_route() -> bool:
	if not c_started: return super.live_route()
	if not expect(east_elapsed() <= C_LIMIT and Time.get_ticks_usec()-c_wall <= C_SECONDS*1000000,"Fresh Catalogue epoch/bounds independent of all completed phases"): return false
	if not expect(game.c_ok and game.c_current() and not paused and game.get_instance_id() == r_main_id and game.state.get_instance_id() == r_campaign_id and game.progress_path == r_profile and game.settings_path == game.r_settings_origin and game.level == route_level and game.player == route_player and not game.loaded_positions and game.is_processing() and game.is_physics_processing() and route_player.is_physics_processing() and route_player.position.is_finite() and game.enemies.size() == 31 and game.scene_roster_matches(),"Same native Main/Campaign/profile/Player/original31; no recovery, unregistered actor or scene replacement"): return false
	if not expect(observer_witness(c_fields) == c_frozen and observer_witness(v_fields) == v_frozen and observer_witness(w_fields) == w_frozen and observer_witness(b_fields) == b_frozen and observer_witness(h_fields) == h_frozen and observers_retired() and not game.h_enabled and not game.b_enabled and not game.q_enabled and not game.w_enabled and not game.v_enabled and observer_witness(q_fields) == q_frozen and retired.all(func(ref): return ref.get_ref() == null) and x_marker_refs.values().all(func(ref): return ref.get_ref() == null),"All accepted prefix/Halo/Blood/Return/Wheel/Ivory/Wheel RETURN history frozen; only v_enabled retired"): return false
	for refs in [h_marker_refs,b_markers,q_markers,w_markers,v_markers]:
		for id in refs:
			if id in c_frozen.v_removed and not expect(refs[id].get_ref() == null,"Every old consumed marker drains: "+id): return false
	for index in range(R_ACTORS.size()):
		var spec: Array = R_ACTORS[index]
		var actor = game.enemies[index]
		var prior: Dictionary = c_actors[index]
		var capsule: CollisionShape3D = actor.get_child(0)
		if not expect(capsule.get_instance_id() == prior.capsule and capsule.shape.get_instance_id() == prior.shape and capsule.position == prior.capsule_position and capsule.shape.radius == prior.radius and capsule.shape.height == prior.height,"All31 original capsule and shape identities/dimensions"): return false
		if not expect(is_instance_valid(actor) and actor.id == spec[0] and actor.get_instance_id() == prior.instance and actor.get_instance_id() == game.h_bindings[actor.id] and actor.get_script() == game.Enemy and actor.kind == spec[1] and actor.max_hp == spec[2] and actor._current_map() and actor.is_physics_processing() and actor.age-prior.age >= float(east_elapsed()-2)/60.0 and (actor.get_child(0) as CollisionShape3D).disabled == prior.shape_disabled,"Original native identity/age/capsule: "+spec[0]): return false
		if actor.id in C_IDS:
			if game.c_activation == 0 and not expect(actor.hp == spec[2] and actor.position == prior.position and actor.rotation.y == prior.yaw and not actor.alerted,"Catalogue actors retain original fullHP/pose until real region activation"): return false
			if not expect(game.c_original(actor) and actor.hp >= 0 and actor.hp <= spec[2] and actor.active == (game.c_activation == 1) and actor.alerted == (game.c_activation == 1) and (actor.hp > 0 or game.c_deaths.get(actor.id,0) == 1 and game.c_finishes.get(actor.id,"unproven") in ["player","infighting"] and actor.collision_layer == 0 and actor.collision_mask == 0 and game.state.removed.count(actor.id) == 1),"Only five original Catalogue actors change through automatic activation/native combat"): return false
			if actor.hp > 0 and not expect(actor.collision_layer == 4 and actor.collision_mask == 7,"Living Catalogue capsule stays native"): return false
		elif not expect(actor.position == prior.position and actor.rotation.y == prior.yaw and actor.active == prior.active and actor.alerted == prior.alerted and (actor.hp == 0 and actor.collision_layer == 0 and actor.collision_mask == 0 and game.state.removed.count(actor.id) == 1 if actor.id in H_IDS+Q_IDS+W_IDS+V_IDS else actor.hp == spec[2] and not actor.active and not actor.alerted and actor.collision_layer == 4 and actor.collision_mask == 7),"Original22 corpses and other4 inactive/fullHP/poses unchanged"): return false
	for id in c_markers:
		if not expect(route_level.markers.has(id) and c_markers[id].get_ref() == route_level.markers[id] and route_level.markers[id].get_parent() == route_level and not route_level.markers[id].is_queued_for_deletion() and not id in game.state.removed,"Every original marker identity AND level owner preserved: "+id): return false
	if not expect(route_level.markers.size() == c_markers.size() and game.c_pickup_calls.is_empty(),"Exact marker set; even rejected/capped supply collisions fail"): return false
	if not expect(game.c_pending.is_empty() and game.c_enemy_pending.is_empty() and game.c_melee_pending.is_empty(),"All native damage contact witnesses consumed synchronously"): return false
	for node in route_level.get_children():
		if node.get_script() == preload("res://scripts/projectile.gd"):
			var id: int = node.get_instance_id()
			if not expect(game.c_births.has(id) and game.c_births[id].reference.get_ref() == node and node.shooter == game.c_births[id].source and node.get_parent() == route_level and node._current_map() and node.is_physics_processing(),"Every actual current-level projectile has its original native birth/shooter; no orphan or replacement"): return false
	return expect(game.budget() == game.c_resources() and game.state.health > 0 and game.state.health <= 100 and game.state.armor >= 0 and game.state.armor <= int(game.c_base.armor) and game.state.ammo[1] >= 0 and game.state.ammo[1] <= 180 and game.state.keys == ["blood","ivory"] and game.state.discoveries == [3] and game.state.removed == game.c_removed and game.state.checkpoint_id == "entry" and game.state.checkpoint == h_frozen.r_start and game.state.level_start == h_frozen.r_start and game.state.actors == c_actor_image and FileAccess.get_sha256(r_profile) == r_saved_sha and game.c_ticks >= east_elapsed()-2 and absf(route_player.active_play_time-c_time-float(east_elapsed())/60.0) <= 2.0/60.0,"Actual ammo/pickup/hurt ledger and earned Blood/story; original actor image/start/checkpoint/disk exact")
