extends "res://tests/test_nursery_earned_campaign.gd"

const NS_CAMPAIGN_SHA = "257661504d65ae51237d281cce41e1a16a46bce89262dd85167e5fa480ee13c6"
const NS_CARRY = {"health":62,"armor":184,"ammo":[0,128,32,60,0,0],"owned_weapons":[0,1,2,3],"weapon":1}
# New phase only: 203.481m XZ at 9m/s, 23 legs with 12 settling ticks, two bounded fights.
const NS_LIMIT = 12000
const NS_SECONDS = 600
const NS_HOP = 900
const NS_FIGHT = 1800
# 960 new-group HP / worst frontal guardian rivet damage 7 plus moving-target margin.
const NS_SHOTS = 160
const NS_APPROACH = [[17.0,21.0],[17.0,23.5],[17.5,23.5],[18.5,23.5],[16.5,23.5],[17.0,23.5],[17.25,25.25]]
# Same authored waypoint cells; detour east of the actual capsule at [22,28].
const NS_SEEDS = [[22.6,25.25],[22.6,26.5],[22.6,30.5]]
const NS_RETURN = [[22.5,32.5],[22.5,33.5],[16.5,33.5],[16.5,31.5],[12.5,31.5],[12.5,29.5],[13.5,29.5],[12.5,29.5],[12.5,27.9]]
const NS_JUNCTION = [[12.5,26.5],[12.5,21.5],[12.5,21.0],[14.0,21.0]]
const NS_IVORY_GUARD = "NATIVE RED Nursery seeds require actual rebound E Ivory input, original marker retirement and seed seal lights"
const NS_NC_FIELDS = ["nc_ok","nc_ticks","nc_ledger","nc_removed","nc_keys","nc_pickups","nc_consumed","nc_shots","nc_last_time","nc_last_tick","nc_slot","nc_activated","nc_events","nc_deaths","nc_finishes","nc_hurts","nc_births","nc_contacts","nc_projectile_pending","nc_worker","nc_melee","nc_summons","nc_summon_attacks","nc_explored","nc_last_cell","nc_inputs","nc_capture_calls","nc_mouse_attempts","nc_save_calls","nc_start","nc_bindings","nc_markers","nc_select","nc_selections"]

# Reuse inherited budget/stack/cadence helpers; mutable nc observers remain retired.
class NurserySeedMain:
	extends "res://tests/test_nursery_earned_campaign.gd".NurseryCampaignMain
	var ns_enabled: bool = false
	var ns_ok: bool = true
	var ns_ticks: int = 0
	var ns_ledger: Dictionary = {}
	var ns_removed: Array = []
	var ns_keys: Array = []
	var ns_pickups: Array = []
	var ns_consumed: Dictionary = {}
	var ns_shots: Array = []
	var ns_last_time: Array = [-INF,-INF,-INF,-INF,-INF,-INF]
	var ns_last_tick: int = -1
	var ns_slot: float = -1.0
	var ns_activated: Dictionary = {}
	var ns_events: Array = []
	var ns_deaths: Dictionary = {}
	var ns_finishes: Dictionary = {}
	var ns_hurts: Array = []
	var ns_births: Dictionary = {}
	var ns_contacts: Dictionary = {}
	var ns_projectile_pending: Dictionary = {}
	var ns_worker: Dictionary = {}
	var ns_melee: Dictionary = {}
	var ns_summons: Dictionary = {}
	var ns_summon_attacks: Dictionary = {}
	var ns_explored: Array = []
	var ns_last_cell: Vector2i = Vector2i(-1,-1)
	var ns_inputs: Array = []
	var ns_capture_calls: int = 0
	var ns_mouse_attempts: Array = []
	var ns_save_calls: int = 0
	var ns_start: Dictionary = {}
	var ns_bindings: Dictionary = {}
	var ns_markers: Dictionary = {}
	var ns_select: int = -1
	var ns_selections: Array = []
	func ns_current() -> bool:
		return ns_enabled and playing and not get_tree().paused and not placement_pending and not loaded_positions and state.level_index == 4 and _scene_level_index == 4 and is_instance_valid(level) and not level.is_queued_for_deletion() and level.get_instance_id() == n_level_id and is_instance_valid(player) and not player.is_queued_for_deletion() and player.get_parent() == level and player.get_instance_id() == n_player_id
	func ns_actor(actor) -> bool:
		return is_instance_valid(actor) and actor.get_script() == Enemy and ns_bindings.has(actor.id) and ns_bindings[actor.id][0] == actor.get_instance_id() and actor._current_map() and actor.get_parent() == level and not actor.is_queued_for_deletion()
	func ns_survey() -> void:
		var cell: Vector2i = Vector2i((Vector2(player.position.x,player.position.z)/4.0).floor())
		if cell == ns_last_cell or not level.layout.is_walkable(cell): return
		ns_last_cell = cell
		for x in range(cell.x-2,cell.x+3):
			for z in range(cell.y-2,cell.y+3):
				var point: Vector2i = Vector2i(x,z)
				var saved: Array = [x,z]
				if not level.layout.is_walkable(point) or saved in ns_explored: continue
				var end: Vector3 = level.layout.world_position([x+0.5,z+0.5])+Vector3.UP*1.55
				if point == cell or level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(player.camera.global_position,end,1)).is_empty(): ns_explored.append(saved)
	func ns_register_summons() -> void:
		for actor in enemies:
			if ns_bindings.has(actor.id): continue
			var owner_id: String = actor._summon_owner_id
			var owner = enemies.filter(func(node): return node.id == owner_id)
			var number: int = int(actor.id.trim_prefix(owner_id+"_add_"))
			var tick: int = Engine.get_physics_frames()
			if owner.size() != 1 or not ns_actor(owner[0]) or owner[0].kind != "summoner" or not ns_summon_attacks.has(owner_id):
				ns_ok = false
				return
			var attack: Array = ns_summon_attacks[owner_id]
			ns_ok = ns_ok and actor.get_script() == Enemy and actor.kind == "crawler" and number > int(attack[1]) and number <= owner[0]._summoned_total and number <= 6 and tick-int(attack[0]) <= 1 and tick >= int(attack[0]) and actor.hp == 50 and actor.max_hp == 50 and actor.active and actor.alerted and actor.encounter_id.is_empty() and actor.target == owner[0]._committed_target and actor.get_parent() == level and actor._current_map() and actor.age <= 1.0/60.0+0.000001 and actor.position.distance_to(owner[0].position) <= 2.5 and state.removed.count("summon:"+owner_id+":"+str(number)) == 1
			var capsule: CollisionShape3D = actor.get_child(0)
			ns_bindings[actor.id] = [actor.get_instance_id(),capsule.get_instance_id(),capsule.shape.get_instance_id()]
			ns_summons[actor.id] = [owner_id,number,tick,weakref(actor),actor.position]
			ns_hp[actor.id] = 50
			ns_removed.append("summon:"+owner_id+":"+str(number))
		var living: Array = enemies.filter(func(actor): return actor.hp > 0 and not actor._summon_owner_id.is_empty())
		ns_ok = ns_ok and living.size() <= 4 and living.filter(func(actor): return actor._summon_owner_id == "nursery_enemy_17").size() <= 2
	func _physics_process(delta: float) -> void:
		super._physics_process(delta)
		if not ns_enabled: return
		ns_ok = ns_ok and ns_current() and absf(delta-1.0/60.0) < 0.000001
		if not ns_current(): return
		ns_ticks += 1
		if not Input.is_action_pressed("fire"): ns_slot = -1.0
		ns_register_summons()
		ns_survey()
		ns_sync_selection()
	func ns_sync_selection() -> void:
		if state.weapon == ns_ledger.weapon: return
		ns_ok = ns_ok and ns_current() and ns_select == state.weapon and Input.is_action_pressed("weapon_"+str(state.weapon+1)) and state.weapon in ns_ledger.owned_weapons and player._weapon_intent == -1
		ns_selections.append([Engine.get_physics_frames(),ns_ledger.weapon,state.weapon])
		ns_ledger.weapon = state.weapon
	func ns_removed_matches() -> bool:
		# Summon births have no callback; their validated observation can follow another same-tick death.
		var actual: Array = state.removed.duplicate()
		var expected: Array = ns_removed.duplicate()
		actual.sort()
		expected.sort()
		return actual == expected and expected.all(func(id): return expected.count(id) == 1)
	func shot(weapon: int) -> void:
		if ns_enabled:
			var tick: int = Engine.get_physics_frames()
			ns_slot = entry_slot(tick,ns_last_tick,ns_slot,weapon)
			ns_sync_selection()
			ns_ok = ns_ok and ns_current() and Engine.is_in_physics_frame() and h_stack("/player.gd","fire") and h_stack("/player.gd","_physics_process") and Input.is_action_pressed("fire") and weapon == 1 and weapon == state.weapon and not player._fire_release_required and player.shot_age(weapon) == 0.0 and ns_slot >= 0.0 and player.active_play_time > ns_last_time[weapon] and ns_shots.size() < NS_SHOTS
			ns_ledger.ammo[weapon] -= 1
			ns_shots.append([tick,player.active_play_time,weapon,player.cooldown])
			ns_last_time[weapon] = player.active_play_time
			ns_last_tick = tick
			ns_ok = ns_ok and ns_ledger.ammo[weapon] >= 0 and budget() == ns_ledger and player.cooldown > 0 and player.cooldown <= 0.21+0.000001
		super.shot(weapon)
	func collect_pickup(id: String) -> void:
		if not ns_enabled:
			super.collect_pickup(id)
			return
		var rows: Array = level.layout.data.pickups.filter(func(spec): return spec.id == id)
		if rows.size() != 1:
			ns_ok = false
			super.collect_pickup(id)
			return
		var spec: Dictionary = rows[0]
		var before: Dictionary = ns_ledger.duplicate(true)
		var expected: Dictionary = before.duplicate(true)
		var marker = level.markers.get(id)
		ns_ok = ns_ok and ns_current() and Engine.is_in_physics_frame() and budget() == before and h_stack("/main.gd","update_passive_triggers") and h_stack("/player.gd","_physics_process") and not ns_consumed.has(id) and is_instance_valid(marker) and marker == ns_markers[id].get_ref() and marker.get_parent() == level and not marker.is_queued_for_deletion() and player.position.distance_to(level.layout.world_position(spec.cell)) < 1.4 and _passive_trigger_visible(spec)
		if spec.kind in ["weapon","ammo"]:
			var index: int = int(spec.weapon)
			if spec.kind == "weapon" and not index in expected.owned_weapons:
				expected.owned_weapons.append(index)
				expected.weapon = index
			expected.ammo[index] = mini([0,180,32,240,24,120][index],int(expected.ammo[index])+int(spec.amount))
		elif spec.kind == "health": expected.health = mini(100,int(expected.health)+int(spec.amount))
		elif spec.kind == "armor": expected.armor = mini(200,int(expected.armor)+int(spec.amount))
		else: ns_ok = false
		super.collect_pickup(id)
		var granted: bool = expected != before
		ns_pickups.append([id,Engine.get_physics_frames(),before,expected.duplicate(true),granted])
		ns_ledger = expected
		if granted:
			ns_consumed[id] = 1
			ns_removed.append(id)
		ns_ok = ns_ok and budget() == expected and state.removed.count(id) == (1 if granted else 0) and (not level.markers.has(id) if granted else level.markers.get(id) == marker)
	func activate_encounter(id: String) -> void:
		if not ns_enabled or "encounter:"+id in state.removed:
			super.activate_encounter(id)
			return
		var rows: Array = level.layout.data.encounters.filter(func(spec): return spec.id == id)
		if rows.size() != 1:
			ns_ok = false
			return
		var spec: Dictionary = rows[0]
		var cell: Vector2 = Vector2(player.position.x,player.position.z)/4.0
		var region: Array = spec.region
		ns_ok = ns_ok and ns_current() and id in ["nursery_second_commit","nursery_second_return"] and not ns_activated.has(id) and h_stack("/main.gd","_process") and not h_stack("/enemy.gd","take_damage") and cell.is_equal_approx(cell.clamp(Vector2(region[0],region[1]),Vector2(region[2],region[3]))) and spec.requires.all(func(key): return key in ns_keys)
		super.activate_encounter(id)
		ns_activated[id] = [Engine.get_physics_frames(),cell,state.keys.duplicate()]
		ns_removed.append("encounter:"+id)
		for actor in enemies:
			if actor.id in spec.enemy_ids: ns_ok = ns_ok and ns_actor(actor) and actor.hp == actor.max_hp and actor.active and actor.alerted
		for light in spec.cue.light_ids:
			ns_ok = ns_ok and level.machine_lights.has(light) and level.machine_lights[light].light_color == (Color(1.0,0.76,0.44) if id == "nursery_second_commit" and "ivory" in ns_keys else Color(1.0,0.28,0.1))
	func enemy_event(actor, event: String) -> void:
		if ns_enabled:
			ns_ok = ns_ok and ns_current() and ns_actor(actor) and actor.active and Engine.is_in_physics_frame() and h_stack("/enemy.gd","_event")
			ns_events.append([actor.id,event,Engine.get_physics_frames(),actor.hp,actor._committed_variant,actor.phase])
			if event == "attack" and actor.kind == "worker":
				var origin: Vector3 = actor.global_position+Vector3.UP*1.4
				var end: Vector3 = origin+(actor._committed_aim-origin).normalized()*30.0
				var query = PhysicsRayQueryParameters3D.create(origin,end,1|2|4)
				query.exclude = [actor.get_rid()]
				query.hit_from_inside = true
				ns_worker = {"source":actor,"tick":Engine.get_physics_frames(),"hit":level.get_world_3d().direct_space_state.intersect_ray(query)}
				var victim = ns_worker.hit.get("collider")
				if ns_actor(victim) and victim.hp > 0: ns_damage(victim,actor,10,(end-origin).normalized(),ns_worker.hit)
			if event == "attack" and actor.kind == "summoner": ns_summon_attacks[actor.id] = [Engine.get_physics_frames(),actor._summoned_total]
			if event == "melee_contact":
				var intended = actor._committed_target
				var query = PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*0.6,intended.global_position+Vector3.UP*0.7,1|2|4)
				query.exclude = [actor.get_rid()]
				query.hit_from_inside = true
				ns_melee = {"source":actor,"tick":Engine.get_physics_frames(),"hit":level.get_world_3d().direct_space_state.intersect_ray(query)}
				var victim = ns_melee.hit.get("collider")
				if ns_actor(victim) and victim.hp > 0: ns_damage(victim,actor,24 if actor.kind == "brute" else 12,(query.to-query.from).normalized(),ns_melee.hit)
			if event == "death":
				var source = ns_projectile_pending.source if not ns_projectile_pending.is_empty() and ns_projectile_pending.hit.get("collider") == actor else actor.target
				var mode: String = "unproven"
				if source == player and h_stack("/player.gd","fire") and h_stack("/enemy.gd","take_damage") and not ns_shots.is_empty() and ns_shots[-1][0] == Engine.get_physics_frames() and Input.is_action_pressed("fire") and aim_observation.get("level") == level and aim_observation.get("player") == player and aim_observation.get("actor_id","") == actor.id and aim_observation.get("tick",-1) == Engine.get_physics_frames(): mode = "player"
				elif ns_native_contact(actor,source): mode = "infighting"
				ns_deaths[actor.id] = ns_deaths.get(actor.id,0)+1
				ns_finishes[actor.id] = mode
				ns_removed.append(actor.id)
				ns_ok = ns_ok and mode != "unproven" and actor.hp == 0 and actor.collision_layer == 0 and actor.collision_mask == 0 and ns_deaths[actor.id] == 1 and state.removed.count(actor.id) == 1
		super.enemy_event(actor,event)
	func ns_native_contact(victim, source) -> bool:
		if not ns_actor(source): return false
		var tick: int = Engine.get_physics_frames()
		if not ns_projectile_pending.is_empty():
			var pending: Dictionary = ns_projectile_pending
			if pending.source == source and pending.tick == tick and pending.hit.collider == victim and pending.hit.rid == victim.get_rid() and h_stack("/projectile.gd","_physics_process"):
				ns_projectile_pending.clear()
				return true
		if source.hp <= 0 or not source.active: return false
		for contact in [ns_worker,ns_melee]:
			if contact.get("source") == source and contact.get("tick",-1) == tick and contact.hit.get("collider") == victim and contact.hit.get("rid") == victim.get_rid() and h_stack("/enemy.gd","_attack") and h_stack("/enemy.gd","_release_attack" if source.kind == "worker" else "_try_melee"): return true
		return false
	func _debug_projectile_event(projectile: Node3D, event: String, data: Dictionary) -> void:
		if ns_enabled:
			var id: int = projectile.get_instance_id()
			var source = projectile.shooter
			ns_ok = ns_ok and ns_current() and OS.is_debug_build() and Engine.is_in_physics_frame() and ns_actor(source) and projectile.get_script() == preload("res://scripts/projectile.gd") and projectile.game == self and projectile._current_map() and projectile.get_parent() == level and projectile.is_physics_processing() and data.get("projectile") == projectile and data.get("source") == source and data.get("map") == level and data.get("player") == player and data.get("tick",-1) == Engine.get_physics_frames() and data.get("position") == projectile.global_position and data.get("velocity") == projectile.velocity and data.get("lifetime") == projectile.lifetime and projectile.blast_damage == 0 and projectile.velocity.is_finite() and is_equal_approx(projectile.velocity.length(),12.0) and projectile.lifetime > 0 and projectile.lifetime <= 4.0
			if event == "configured_birth":
				ns_ok = ns_ok and not ns_births.has(id) and source.hp > 0 and source.active and source.kind in ["caster","guardian"] and h_stack("/enemy.gd","_release_attack") and (h_stack("/enemy.gd","_fire_pattern") if source.kind == "guardian" else true) and h_stack("/projectile.gd","configure") and data.origin == source.global_position+Vector3.UP*(1.65 if source.kind == "guardian" else 1.4) and data.origin == projectile.global_position and data.origin.is_finite() and data.destination.is_finite() and projectile.velocity.is_equal_approx((data.destination-data.origin).normalized()*12.0) and projectile.lifetime == 4.0
				ns_births[id] = [weakref(projectile),source.get_instance_id(),Engine.get_physics_frames()]
			else:
				var hit: Dictionary = data.get("hit",{})
				var victim = hit.get("collider")
				ns_ok = ns_ok and event in ["queued_player_contact","queued_enemy_contact"] and ns_births.has(id) and not ns_contacts.has(id) and ns_births[id][0].get_ref() == projectile and ns_births[id][1] == source.get_instance_id() and Engine.get_physics_frames()-int(ns_births[id][2]) <= 241 and projectile.is_queued_for_deletion() and h_stack("/projectile.gd","_physics_process") and (victim == player if event == "queued_player_contact" else ns_actor(victim) and victim.hp > 0 and victim != source) and hit.get("rid") == victim.get_rid() and data.ray_start.is_finite() and data.ray_end.is_equal_approx(data.ray_start+projectile.velocity*minf(1.0/60.0,projectile.lifetime))
				var query = PhysicsRayQueryParameters3D.create(data.ray_start,data.ray_end,1|2|4)
				query.exclude = [source.get_rid()]
				query.hit_from_inside = true
				ns_ok = ns_ok and level.get_world_3d().direct_space_state.intersect_ray(query) == hit
				ns_contacts[id] = [event,source.id,victim.get_instance_id(),Engine.get_physics_frames(),hit.position]
				if victim != player: ns_damage(victim,source,14,projectile.velocity.normalized(),hit)
				if victim == player or ns_hp.get(victim.id,1) == 0:
					ns_ok = ns_ok and ns_projectile_pending.is_empty()
					ns_projectile_pending = {"id":id,"source":source,"tick":Engine.get_physics_frames(),"hit":hit,"projectile":projectile}
		super._debug_projectile_event(projectile,event,data)
	func hurt_player(amount: int) -> void:
		if ns_enabled:
			var source = null
			if not ns_projectile_pending.is_empty(): source = ns_projectile_pending.source
			else:
				for contact in [ns_worker,ns_melee]:
					if contact.get("tick",-1) == Engine.get_physics_frames() and contact.hit.get("collider") == player: source = contact.source

			var expected_amount: int = 14 if h_stack("/projectile.gd","_physics_process") else 10 if is_instance_valid(source) and source.kind == "worker" else 24 if is_instance_valid(source) and source.kind == "brute" else 12
			ns_ok = ns_ok and ns_current() and Engine.is_in_physics_frame() and budget() == ns_ledger and amount == expected_amount and state.difficulty == 1 and ns_native_contact(player,source)
			var absorbed: int = mini(int(ns_ledger.armor),int(amount/3))
			ns_ledger.armor -= absorbed
			ns_ledger.health = maxi(0,int(ns_ledger.health)-amount+absorbed)
			ns_hurts.append([Engine.get_physics_frames(),source.id if is_instance_valid(source) else "unproven",amount,absorbed])
		super.hurt_player(amount)
		if ns_enabled: ns_ok = ns_ok and budget() == ns_ledger
	func interact() -> void:
		if ns_enabled:
			var spec: Dictionary = nearest_interaction()
			ns_ok = ns_ok and ns_current() and Engine.is_in_physics_frame() and Input.is_action_pressed("interact") and h_stack("/player.gd","_physics_process") and spec.get("id","") == "nursery_ivory"
			ns_inputs.append([spec.get("id",""),Engine.get_physics_frames(),player.position])
		super.interact()
	func collect_key(id: String) -> void:
		if ns_enabled:
			ns_ok = ns_ok and ns_current() and id == "nursery_ivory" and ns_keys == ["blood"] and ns_inputs.size() == 1 and h_stack("/main.gd","interact") and h_stack("/player.gd","_physics_process") and Input.is_action_pressed("interact") and level.markers.get(id) == ns_markers[id].get_ref()
		super.collect_key(id)
		if ns_enabled:
			ns_keys.append("ivory")
			ns_removed.append(id)
			ns_ok = ns_ok and state.keys == ns_keys and state.removed.count(id) == 1 and not level.markers.has(id)
			for light in ["nursery_seed_feed","nursery_seed_core"]: ns_ok = ns_ok and level.machine_lights[light].light_color == Color(1.0,0.76,0.44)
	var ns_actor_image: Array = []
	var ns_checkpoint: Dictionary = {}
	var ns_saved_sha: String = ""
	func _capture_actor_state() -> bool:
		if not ns_enabled: return super._capture_actor_state()
		ns_capture_calls += 1
		ns_ok = false
		return false
	func _capture_game_mouse() -> void:
		if ns_enabled: ns_mouse_attempts.append([Engine.get_physics_frames(),state.level_index,placement_pending,playing])
		super._capture_game_mouse()
	func _save() -> Error:
		if not ns_enabled: return super._save()
		ns_save_calls += 1
		ns_ok = false
		return ERR_INVALID_DATA

	var ns_hp: Dictionary = {}
	var ns_damage_events: Array = []
	func ns_damage(victim, source, amount: int, direction: Vector3, hit: Dictionary) -> void:
		ns_ok = ns_ok and ns_current() and ns_actor(victim) and victim.hp > 0 and ns_hp.get(victim.id,-1) == victim.hp and Engine.is_in_physics_frame() and hit.get("collider") == victim and hit.get("rid") == victim.get_rid() and direction.is_finite() and is_equal_approx(direction.length(),1.0)
		var applied: int = amount
		var incoming: Vector3 = -direction
		incoming.y = 0
		if victim.kind == "guardian" and victim.telegraph_time <= 0 and victim.pose_time <= 0 and victim.recovery_time <= 0 and incoming.length_squared() > 0.0001 and (-victim.global_basis.z).dot(incoming.normalized()) > 0.5: applied = maxi(1,int(amount*0.35))
		ns_damage_events.append([Engine.get_physics_frames(),victim.id,source.get_instance_id(),amount,applied,victim.hp,hit.position,hit.rid])
		ns_hp[victim.id] = maxi(0,victim.hp-applied)
	func resolve_aim(origin: Vector3, direction: Vector3, max_range: float, melee: bool = false) -> Dictionary:
		var result: Dictionary = super.resolve_aim(origin,direction,max_range,melee)
		if not ns_enabled or not h_stack("/player.gd","fire"): return result
		ns_ok = ns_ok and ns_current() and h_stack("/player.gd","fire") and h_stack("/player.gd","_physics_process") and Input.is_action_pressed("fire") and state.weapon == 1 and not melee and max_range == 140.0 and not ns_shots.is_empty() and ns_shots[-1][0] == Engine.get_physics_frames()
		var query = PhysicsRayQueryParameters3D.create(origin,origin+result.direction*max_range,1|4)
		query.exclude = [player.get_rid()]
		var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(query)
		ns_ok = ns_ok and result.contact == hit
		var victim = hit.get("collider")
		if ns_actor(victim) and victim.hp > 0: ns_damage(victim,player,22,result.direction,hit)
		return result

var ns_started: bool = false
var ns_epoch: int = 0
var ns_wall: int = 0
var ns_frozen_fields: Array = []
var ns_frozen: Dictionary = {}
var ns_originals: Dictionary = {}
var ns_waypoints: Array = []

func run() -> void:
	if "--nursery-seeds-pin-rejection" in OS.get_cmdline_user_args():
		await nursery_seeds_pin_rejection()
		return
	var ok: bool = await walk_through_nursery_seeds(NurserySeedMain.new())
	if ok:
		if "--nursery-seeds-pose-corruption" in OS.get_cmdline_user_args():
			game.state.position += Vector3.RIGHT
			ok = expect(not nursery_seed_result(),"Current-pose corruption is rejected independently of resources")
		elif "--nursery-seeds-ledger-corruption" in OS.get_cmdline_user_args():
			game.state.ammo[1] += 1
			ok = expect(not live_route(),"Unobserved ammunition corruption is rejected")
		elif "--nursery-seeds-actor-corruption" in OS.get_cmdline_user_args():
			var untouched = game.enemies.filter(func(actor): return actor.id == "nursery_warden")
			untouched[0].hp -= 1
			ok = expect(not live_route(),"Untouched original finale actor corruption is rejected")
	if ok: print("PASS source proposal for SAME earned Nursery seed/Ivory/second-return/junction slice; native evidence only when executed. Not physical/GPU/listening/performance/packed/full-eight acceptance.")
	await finish(0 if ok else 1)

func walk_through_nursery_seeds(observer: NurserySeedMain, profile_prefix: String = "") -> bool:
	if not expect(FileAccess.get_sha256("res://tests/test_nursery_earned_campaign.gd") == NS_CAMPAIGN_SHA and FileAccess.get_sha256("res://tests/test_nursery_earned_entry.gd") == NC_ENTRY_SHA and FileAccess.get_sha256("res://data/05_nursery.json") == N_MAP_SHA and NC_CORE_PINS.keys().all(func(path): return FileAccess.get_sha256(path) == NC_CORE_PINS[path]),"Accepted helper/original map/current core pins BEFORE scene or profile adoption"):
		if is_instance_valid(observer) and observer != game and observer.get_parent() == null and not observer.is_inside_tree(): observer.free()
		return false
	if not await walk_through_nursery(observer,profile_prefix): return false
	# The accepted helper already called nursery_segment_result on this same owner.
	var actual: Array = []
	for property in game.get_property_list():
		if str(property.name).begins_with("nc_") and property.name != "nc_enabled": actual.append(property.name)
	actual.sort()
	var declared: Array = NS_NC_FIELDS.duplicate()
	declared.sort()
	if not expect(actual == declared and game.nc_enabled and game.nc_ok and game.budget() == NS_CARRY and game.nc_deaths.size() == 11 and game.nc_births.size() == 2 and game.nc_contacts.size() == 1 and game.nc_summons.is_empty(),"Complete declared/reflected nc coverage and actual accepted62/184/128/32/60 boundary"): return false
	ns_frozen_fields = nc_frozen_fields+NS_NC_FIELDS
	ns_frozen = observer_witness(ns_frozen_fields)
	game.ns_ledger = NS_CARRY.duplicate(true)
	game.ns_keys = ["blood"]
	game.ns_removed = game.nc_removed.duplicate()
	game.ns_consumed = game.nc_consumed.duplicate(true)
	game.ns_bindings = game.nc_bindings.duplicate(true)
	game.ns_explored = game.nc_explored.duplicate(true)
	game.ns_last_cell = game.nc_last_cell
	game.ns_start = game.nc_start.duplicate(true)
	game.ns_checkpoint = game.state.checkpoint.duplicate(true)
	game.ns_actor_image = game.state.actors.duplicate(true)
	game.ns_saved_sha = FileAccess.get_sha256(r_profile)
	game.ns_births = game.nc_births.duplicate(true)
	game.ns_contacts = game.nc_contacts.duplicate(true)
	for actor in game.enemies:
		ns_originals[actor.id] = [actor.position,actor.rotation.y,actor.age,actor.max_hp,actor.kind,actor.encounter_id,actor.hp]
		game.ns_hp[actor.id] = actor.hp
	game.ns_last_time = game.nc_last_time.duplicate()
	game.ns_last_tick = game.nc_last_tick
	for id in route_level.markers: game.ns_markers[id] = weakref(route_level.markers[id])
	release_actions()
	game.nc_enabled = false
	ns_epoch = Engine.get_physics_frames()
	ns_wall = Time.get_ticks_usec()
	ns_started = true
	game.ns_enabled = true
	if not await nursery_seed_select_pistol(): return false
	if not await nursery_seed_route(NS_APPROACH) or not await nursery_seed_route(NS_SEEDS): return false
	if not await nursery_seed_fight("nursery_second_commit") or not await nursery_ivory_input(): return false
	if not await nursery_seed_route(NS_RETURN) or not await nursery_seed_fight("nursery_second_return") or not await nursery_seed_route(NS_JUNCTION): return false
	return nursery_seed_result()

func nursery_seeds_pin_rejection() -> void:
	if not expect(FileAccess.get_sha256("res://tests/test_nursery_earned_campaign.gd") != NS_CAMPAIGN_SHA,"Control requires deliberate parent-owned accepted-helper mismatch"):
		await finish(1)
		return
	var fixture: String = "user://reliquary_catalogue_exit_nursery_seeds_pin_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	var suffixes: Array = ["_campaign.json","_campaign.json.tmp","_preferences.json","_preferences.json.tmp"]
	if not expect(suffixes.all(func(suffix): return not FileAccess.file_exists(fixture+suffix)),"Fresh unique pin-control namespace only"):
		quit(1)
		return
	var observer = NurserySeedMain.new()
	var reference = weakref(observer)
	var result: bool = await walk_through_nursery_seeds(observer,fixture)
	var ok: bool = expect(not result and reference.get_ref() == null and game == null and root.get_child_count() == 0 and suffixes.all(func(suffix): return not FileAccess.file_exists(fixture+suffix)),"Wrong pin frees ONLY detached unadopted observer; only fresh namespace checked")
	prefix = fixture
	await finish(0 if ok else 1)

func live_route() -> bool:
	if not ns_started: return super.live_route()
	if not expect(Engine.get_physics_frames()-ns_epoch <= NS_LIMIT and Time.get_ticks_usec()-ns_wall <= NS_SECONDS*1000000,"New-only frame/time caps; accepted ancestor caps unchanged"): return false
	if not expect(game.ns_ok and game.ns_current() and game.get_instance_id() == r_main_id and game.state.get_instance_id() == r_campaign_id and game.progress_path == r_profile and game.settings_path == game.r_settings_origin and game.level == route_level and game.player == route_player and game.is_processing() and game.is_physics_processing() and route_player.is_physics_processing() and route_player._current_map() and route_player.position.is_finite() and game.state.health > 0,"Same earned Main/Campaign/profile/native Player, live input and production processing"): return false
	if not expect(observer_witness(ns_frozen_fields) == ns_frozen and not game.nc_enabled and not game.n_enabled and not game.e_enabled and observers_retired() and e_retired.all(func(ref): return ref.get_ref() == null) and e_markers.values().all(func(ref): return ref.get_ref() == null) and retired.all(func(ref): return ref.get_ref() == null) and x_marker_refs.values().all(func(ref): return ref.get_ref() == null),"EVERY accepted prior observer field/history remains frozen; retired scenes remain drained"): return false
	game.ns_register_summons()
	game.ns_sync_selection()
	var children: Array = route_level.get_children().filter(func(node): return node.get_script() == game.Enemy).map(func(node): return node.get_instance_id())
	var bound: Array = game.ns_bindings.values().map(func(record): return record[0])
	children.sort()
	bound.sort()
	if not expect(children == bound and game.enemies.size() == bound.size() and bound.size() == 29+game.ns_summons.size(),"Exact original29 actor instances plus only genuinely observed budgeted summons"): return false
	for actor in game.enemies:
		var capsule: CollisionShape3D = actor.get_child(0)
		var binding: Array = game.ns_bindings[actor.id]
		if not expect(game.ns_actor(actor) and actor.is_physics_processing() and capsule.get_instance_id() == binding[1] and capsule.shape.get_instance_id() == binding[2] and not capsule.disabled and capsule.shape is CapsuleShape3D and absf(capsule.shape.radius-N_ROLES[actor.kind][1]) < 0.000001 and absf(capsule.shape.height-N_ROLES[actor.kind][2]) < 0.000001 and capsule.position == Vector3(0,capsule.shape.height/2,0) and actor.position.is_finite() and is_finite(actor.rotation.y) and actor.hp >= 0 and actor.hp <= actor.max_hp and actor.hp == game.ns_hp.get(actor.id,-1),"Original native actor/capsule/processing: "+actor.id): return false
		if ns_originals.has(actor.id):
			var original: Array = ns_originals[actor.id]
			if not expect(actor.max_hp == original[3] and actor.kind == original[4] and actor.encounter_id == original[5] and actor.age-original[2] >= float(Engine.get_physics_frames()-ns_epoch-2)/60.0,"Original group/role/HP ceiling and native age: "+actor.id): return false
			if original[6] == 0:
				if not expect(actor.hp == 0 and actor.position == original[0] and actor.rotation.y == original[1] and game.nc_deaths.get(actor.id,0) == 1 and game.nc_finishes.get(actor.id,"") in ["player","infighting"],"First11 accepted corpses/provenance preserved: "+actor.id): return false
			elif not game.ns_activated.has(actor.encounter_id) and not expect(actor.hp == actor.max_hp and actor.position == original[0] and actor.rotation.y == original[1] and not actor.active and not actor.alerted,"Unentered actors stay original fullHP/dormant: "+actor.id): return false
		if actor.hp > 0:
			if not expect(actor.collision_layer == 4 and actor.collision_mask == 7,"Living collision semantics"): return false
			var floor_hit: Dictionary = route_level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(actor.position+Vector3.UP*0.5,actor.position-Vector3.UP*6,1))
			if not expect(not floor_hit.is_empty() and floor_hit.normal.y >= 0.7 and absf(actor.position.y-floor_hit.position.y-(1.0 if actor.kind == "caster" else 0.0)) <= (0.25 if actor.kind == "caster" else 0.15),"Actual native actor floor support: "+actor.id): return false
		elif not expect((game.nc_deaths.get(actor.id,0) == 1 and game.nc_finishes.get(actor.id,"") in ["player","infighting"] or game.ns_deaths.get(actor.id,0) == 1 and game.ns_finishes.get(actor.id,"") in ["player","infighting"]) and actor.collision_layer == 0 and actor.collision_mask == 0 and game.state.removed.count(actor.id) == 1,"Once-only original or new native death/collision retirement: "+actor.id): return false
	for id in game.ns_markers:
		if id in game.ns_removed and id != "nursery_checkpoint":
			if not expect(not route_level.markers.has(id),"Earned marker retirement: "+id): return false
		elif not expect(route_level.markers.get(id) == game.ns_markers[id].get_ref() and is_instance_valid(game.ns_markers[id].get_ref()) and not game.ns_markers[id].get_ref().is_queued_for_deletion(),"Unclaimed/checkpoint original marker retained: "+id): return false
	for node in route_level.get_children():
		if node.get_script() == preload("res://scripts/projectile.gd") and not node.is_queued_for_deletion():
			if not expect(game.ns_births.has(node.get_instance_id()) and game.ns_births[node.get_instance_id()][0].get_ref() == node and game.ns_actor(node.shooter) and node._current_map() and node.is_physics_processing() and node.lifetime > 0 and node.lifetime <= 4.0,"Live projectile birth/shooter/native lifetime retained"): return false
	var player_capsule: CollisionShape3D = route_player.get_child(0)
	var floor_hit: Dictionary = route_level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(route_player.position+Vector3.UP*0.5,route_player.position-Vector3.UP*0.5,1))
	if not expect(not player_capsule.disabled and player_capsule.shape is CapsuleShape3D and player_capsule.shape.radius == Vector3(0.32,0,0).x and player_capsule.shape.height == Vector3(1.65,0,0).x and player_capsule.position == Vector3(0,0.85,0) and route_player.collision_layer == 2 and route_player.collision_mask == 5 and not floor_hit.is_empty() and floor_hit.normal.y >= 0.7 and absf(route_player.position.y-floor_hit.position.y) <= 0.15,"Live production Player capsule/collision and actual floor support"): return false
	return expect(game.ns_ok and game.ns_capture_calls == 0 and game.ns_save_calls == 0 and game.budget() == game.ns_ledger and game.state.keys == game.ns_keys and game.ns_removed_matches() and game.state.explored == game.ns_explored and game.state.discoveries == [3] and game.state.checkpoint_id == game.ns_checkpoint.checkpoint_id and game.state.checkpoint == game.ns_checkpoint and game.state.level_start == game.ns_start and game.state.actors == game.ns_actor_image and FileAccess.get_sha256(r_profile) == game.ns_saved_sha and game.ns_mouse_attempts.is_empty() and game.ns_projectile_pending.is_empty(),"Independent finite pickup/ammo/damage/activation/Survey ledger; live versus recovery/disk envelopes")

func route_tick() -> bool:
	if not ns_started: return await super.route_tick()
	if not live_route(): return false
	await physics_frame
	return live_route()

func nursery_seed_fire() -> bool:
	Input.action_release("fire")
	if game.state.weapon != 1 or game.state.ammo[1] <= 0 or game.ns_shots.size() >= NS_SHOTS: return false
	var selected = null
	var nearest: float = game.Player.WEAPONS[1].range
	for actor in game.enemies:
		if not game.ns_actor(actor) or actor.hp <= 0 or not actor.active: continue
		var aim: Vector3 = actor.global_position+actor.get_child(0).position
		var distance: float = route_player.camera.global_position.distance_to(aim)
		if distance >= nearest: continue
		var query = PhysicsRayQueryParameters3D.create(route_player.camera.global_position,aim,1|4)
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

func nursery_seed_route(cells: Array) -> bool:
	for cell in cells:
		var target: Vector3 = route_level.layout.world_position(cell)+Vector3.UP*0.04
		var began: int = Engine.get_physics_frames()
		while true:
			if not live_route() or not expect(Engine.get_physics_frames()-began < NS_HOP,"Nursery-only clearance/movement cap at "+str(cell)): return false
			var clear: bool = clear_point(cell) != null
			var start: Vector3 = route_player.position
			var samples: int = ceili(start.distance_to(target)/0.5)
			for sample in range(samples+1):
				var point: Vector3 = start.lerp(target,float(sample)/maxi(1,samples))
				var grounded = clear_point([point.x/4,point.z/4])
				if grounded == null: clear = false
				if sample > 0:
					var prior: Vector3 = start.lerp(target,float(sample-1)/maxi(1,samples))
					if not nursery_seed_sweep([prior.x/4,prior.z/4],[point.x/4,point.z/4]): clear = false
			if clear: break
			release_actions()
			if not expect(nursery_seed_fire(),"Blocked original route must have a finite visible active actor, never idle/retry navigation"): return false
			if not await route_tick(): return false
		while Vector2(route_player.position.x-target.x,route_player.position.z-target.z).length() > 0.12:
			if not live_route() or not expect(Engine.get_physics_frames()-began < NS_HOP,"Nursery-only movement deadline at "+str(cell)): return false
			release_actions()
			if not nursery_seed_fire(): route_player.look_at(Vector3(target.x,route_player.position.y,target.z),Vector3.UP)
			var direction: Vector3 = target-route_player.position
			direction.y = 0
			var deadzone: float = 0.0
			for action in ["move_left","move_right","move_forward","move_back"]: deadzone += InputMap.action_get_deadzone(action)/4.0
			var axes: Vector3 = route_player.basis.inverse()*direction.normalized()*(deadzone+(1.0-deadzone)*minf(1.0,direction.length()*6.0/9.0))
			for action in [["move_right",axes.x],["move_left",-axes.x],["move_back",axes.z],["move_forward",-axes.z]]: Input.action_press(action[0],maxf(0,action[1]))
			if not await route_tick(): return false
		release_actions()
		for frame in range(12):
			if not expect(Engine.get_physics_frames()-began < NS_HOP,"Nursery settling shares leg deadline"): return false
			nursery_seed_fire()
			if not await route_tick(): return false
		release_actions()
		await process_frame
		if not live_route() or not expect(route_player.position.distance_to(target) < 0.2 and clear_point(cell) != null,"Actual native settled Nursery waypoint: "+str(cell)): return false
		ns_waypoints.append(cell.duplicate())
		print("NURSERY_SEED_HOP cell=",cell," frame=",Engine.get_physics_frames()-ns_epoch," resources=",game.ns_ledger)
	return true

func nursery_seed_fight(group_id: String) -> bool:
	if not expect(game.ns_activated.has(group_id),"Original group earned through its actual region: "+group_id): return false
	for frame in range(NS_FIGHT):
		if not live_route(): return false
		if game.enemies.all(func(actor): return actor.hp == 0 or actor.encounter_id != group_id and actor._summon_owner_id.is_empty()):
			release_actions()
			return true
		release_actions()
		if not expect(nursery_seed_fire(),"Finite seed-loop fight requires visible live native target, not idle waiting"): return false
		if not await route_tick(): return false
	release_actions()
	return expect(false,"Nursery-only1800-frame combat cap: "+group_id)

func nursery_seed_sweep(from_cell: Array, to_cell: Array) -> bool:
	var from_point = clear_point(from_cell)
	var to_point = clear_point(to_cell)
	if from_point == null or to_point == null: return false
	var capsule: CollisionShape3D = route_player.get_child(0)
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = capsule.shape
	query.transform = Transform3D(Basis.IDENTITY,from_point+capsule.position)
	query.motion = to_point-from_point
	query.collision_mask = route_player.collision_mask
	query.exclude = [route_player.get_rid()]
	var fractions = route_level.get_world_3d().direct_space_state.cast_motion(query)
	return fractions.size() == 2 and fractions[0] >= 1.0 and fractions[1] >= 1.0

func nursery_ivory_key(pressed: bool) -> bool:
	var event = InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = pressed
	if not expect(InputMap.event_is_action(event,"interact"),"NATIVE RED Ivory requires the live physical E binding"): return false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	return true

func nursery_ivory_input() -> bool:
	aim_interaction([22.5,30.5])
	if not "--omit-nursery-ivory" in OS.get_cmdline_user_args() and not nursery_ivory_key(true): return false
	for frame in range(6):
		if not await route_tick(): return false
		if "ivory" in game.state.keys: break
	if not nursery_ivory_key(false): return false
	release_actions()
	await process_frame
	return live_route() and expect(game.ns_keys == ["blood","ivory"] and game.ns_inputs.size() == 1 and game.ns_inputs[0][0] == "nursery_ivory" and game.ns_markers["nursery_ivory"].get_ref() == null and ["nursery_seed_feed","nursery_seed_core"].all(func(id): return route_level.machine_lights[id].light_color == Color(1.0,0.76,0.44)),NS_IVORY_GUARD)

func nursery_seed_result() -> bool:
	if not live_route(): return false
	var yaw: float = route_player.rotation.y
	if yaw < -PI or yaw >= PI: yaw = wrapf(yaw,-PI,PI)
	yaw = Vector3(0,clampf(yaw,-3.1415925,3.1415925),0).y
	if not expect(game.state.position == route_player.position and game.state.yaw == yaw and game.state.pitch == clampf(route_player.camera.rotation.x,-1.35,1.35),"Independent settled current position/yaw/pitch equals actual Player, not merely resource agreement"): return false
	var expected: Array = N_ACTORS.filter(func(spec): return spec[6] in [1,3]).map(func(spec): return spec[0])+game.ns_summons.keys()
	if not expect(expected.all(func(id): return game.ns_deaths.get(id,0) == 1 and game.ns_finishes.get(id,"") in ["player","infighting"]) and game.ns_deaths.size() == expected.size() and game.ns_activated.keys() == ["nursery_second_commit","nursery_second_return"] and game.state.keys == ["blood","ivory"] and game.state.owned_weapons == [0,1,2,3] and game.state.ammo[2] == 32 and game.state.ammo[3] == 60 and game.ns_inputs.size() == 1 and route_player.position.distance_to(route_level.layout.world_position([14.0,21.0])) < 0.2 and clear_point([14.0,21.0]) != null and game.ns_shots.size() > 0 and game.ns_shots.size() <= NS_SHOTS and ns_waypoints == NS_APPROACH+NS_SEEDS+NS_RETURN+NS_JUNCTION,"Same nonquitting original seed loop, actual Ivory, all8+3 new deaths and live original junction; untouched finale remains dormant"): return false
	print("NURSERY_SEED_SEGMENT frames=",Engine.get_physics_frames()-ns_epoch," wall_us=",Time.get_ticks_usec()-ns_wall," shots=",game.ns_shots," damage=",game.ns_damage_events," hurts=",game.ns_hurts," pickups=",game.ns_pickups," deaths=",game.ns_deaths," provenance=",game.ns_finishes," births_total=",game.ns_births.size()," contacts_total=",game.ns_contacts.size()," new_summons=",game.ns_summons.size()," resources=",game.ns_ledger," capture_calls=",game.ns_capture_calls," save_calls=",game.ns_save_calls," saved_sha=",game.ns_saved_sha)
	return true

func nursery_seed_select_pistol() -> bool:
	release_actions()
	game.ns_select = 1
	var event = InputEventAction.new()
	event.action = "weapon_2"
	event.pressed = true
	event.strength = 1.0
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	for frame in range(2):
		if not await route_tick(): return false
	game.ns_selections.append([Engine.get_physics_frames(),1,game.state.weapon])
	Input.action_release("weapon_2")
	return expect(game.state.weapon == 1 and game.ns_ledger.weapon == 1 and route_player._weapon_intent == -1,"Queued owned-pistol selection consumed by actual production Player; earned shells/repeater retained")
