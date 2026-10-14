extends "res://tests/test_nursery_earned_entry.gd"

const NC_CORE_PINS = {"res://scripts/main.gd":"9cae27c174c1bef643e78d685d39afea289355aaaff83b68ecaeea6ae097f459","res://scripts/player.gd":"ebb1b4dba137a736db5450024723b2ff25ac942b0f100c0856a4ac6c87fc2bb4","res://scripts/enemy.gd":"704327020410ec93786ffca26e3d52cc1c03186853b0be3a981d5c47753a5a95","res://scripts/projectile.gd":"bbda549a1c3d964bea81171dfc44d0395084023e804e3bdb72e22d285f87e873","res://scripts/campaign.gd":"34f9c3347acb72534140335106c6e8a74d778e2f2ad30d25da1028b8830bca6f","res://scripts/level.gd":"bfd64a31f8d9df56e5e9dfbd5a4e16ce5df5ec738423a4e75436750318bee053","res://scripts/level_data.gd":"40b6946232de22af2cd60c6f98db3852a6ebac9eb6cd42b8994ef4345a777674","res://scripts/preferences.gd":"e225e74aabaafdd3f3e25a31b22264a5ba365e4ba7d0f6e3709f67b10f327139"}
const NC_ENTRY_SHA = "e261d3a3b98783554721a47911bd07b329602774c05480af2aab716d4c659527"
# Entry corridor + gestation loop is 350.89m at 9m/s; combat/clearance has separate finite caps.
const NC_LIMIT = 12000
const NC_SECONDS = 600
const NC_HOP = 900
const NC_FIGHT = 1800
const NC_SHOTS = 100
const NC_APPROACH = [[3.5,33.5],[3.5,32.5],[4.5,32.5],[5.5,32.5],[4.5,32.5],[4.5,26.5],[4.5,21.5],[14.0,21.5],[14.5,21.5],[14.0,21.0],[14.0,21.5],[4.5,21.5],[4.5,21.0],[4.0,18.5],[4.0,17.0],[4.0,13.0]]
# Detour around the authored capsule at [2,10], while visiting every original loop waypoint.
const NC_GESTATION = [[2.0,13.0],[2.8,13.0],[2.8,7.0],[2.0,7.0],[9.0,7.0],[9.0,9.0],[9.5,9.5],[9.5,12.5]]
const NC_RETURN = [[9.5,9.5],[9.0,9.0],[14.0,9.0],[14.0,10.5],[14.0,12.0]]
const NC_JUNCTION = [[14.0,15.0],[14.0,17.0],[14.0,21.0]]
const NC_BLOOD_GUARD = "NATIVE RED Nursery gestation requires actual rebound E Blood input, original marker retirement and seal lights"
const NC_N_FIELDS = ["n_ok","n_start_calls","n_start_frames","n_captures","n_mouse_attempts","n_bindings","n_level_id","n_player_id","n_ticks","n_explored","n_last_cell"]

class NurseryCampaignMain:
	extends "res://tests/test_nursery_earned_entry.gd".NurseryEntryMain
	var nc_enabled: bool = false
	var nc_ok: bool = true
	var nc_ticks: int = 0
	var nc_ledger: Dictionary = {}
	var nc_removed: Array = []
	var nc_keys: Array = []
	var nc_pickups: Array = []
	var nc_consumed: Dictionary = {}
	var nc_shots: Array = []
	var nc_last_time: Array = [-INF,-INF,-INF,-INF,-INF,-INF]
	var nc_last_tick: int = -1
	var nc_slot: float = -1.0
	var nc_activated: Dictionary = {}
	var nc_events: Array = []
	var nc_deaths: Dictionary = {}
	var nc_finishes: Dictionary = {}
	var nc_hurts: Array = []
	var nc_births: Dictionary = {}
	var nc_contacts: Dictionary = {}
	var nc_projectile_pending: Dictionary = {}
	var nc_worker: Dictionary = {}
	var nc_melee: Dictionary = {}
	var nc_summons: Dictionary = {}
	var nc_summon_attacks: Dictionary = {}
	var nc_explored: Array = []
	var nc_last_cell: Vector2i = Vector2i(-1,-1)
	var nc_inputs: Array = []
	var nc_capture_calls: int = 0
	var nc_mouse_attempts: Array = []
	var nc_save_calls: int = 0
	var nc_start: Dictionary = {}
	var nc_bindings: Dictionary = {}
	var nc_markers: Dictionary = {}
	var nc_select: int = -1
	var nc_selections: Array = []
	func nc_current() -> bool:
		return nc_enabled and playing and not get_tree().paused and not placement_pending and not loaded_positions and state.level_index == 4 and _scene_level_index == 4 and is_instance_valid(level) and not level.is_queued_for_deletion() and level.get_instance_id() == n_level_id and is_instance_valid(player) and not player.is_queued_for_deletion() and player.get_parent() == level and player.get_instance_id() == n_player_id
	func nc_actor(actor) -> bool:
		return is_instance_valid(actor) and actor.get_script() == Enemy and nc_bindings.has(actor.id) and nc_bindings[actor.id][0] == actor.get_instance_id() and actor._current_map() and actor.get_parent() == level and not actor.is_queued_for_deletion()
	func nc_survey() -> void:
		var cell: Vector2i = Vector2i((Vector2(player.position.x,player.position.z)/4.0).floor())
		if cell == nc_last_cell or not level.layout.is_walkable(cell): return
		nc_last_cell = cell
		for x in range(cell.x-2,cell.x+3):
			for z in range(cell.y-2,cell.y+3):
				var point: Vector2i = Vector2i(x,z)
				var saved: Array = [x,z]
				if not level.layout.is_walkable(point) or saved in nc_explored: continue
				var end: Vector3 = level.layout.world_position([x+0.5,z+0.5])+Vector3.UP*1.55
				if point == cell or level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(player.camera.global_position,end,1)).is_empty(): nc_explored.append(saved)
	func nc_register_summons() -> void:
		for actor in enemies:
			if nc_bindings.has(actor.id): continue
			var owner_id: String = actor._summon_owner_id
			var owner = enemies.filter(func(node): return node.id == owner_id)
			var number: int = int(actor.id.trim_prefix(owner_id+"_add_"))
			var tick: int = Engine.get_physics_frames()
			if owner.size() != 1 or not nc_actor(owner[0]) or owner[0].kind != "summoner" or not nc_summon_attacks.has(owner_id):
				nc_ok = false
				return
			var attack: Array = nc_summon_attacks[owner_id]
			nc_ok = nc_ok and actor.get_script() == Enemy and actor.kind == "crawler" and number > int(attack[1]) and number <= owner[0]._summoned_total and number <= 6 and tick-int(attack[0]) <= 1 and tick >= int(attack[0]) and actor.hp == 50 and actor.max_hp == 50 and actor.active and actor.alerted and actor.encounter_id.is_empty() and actor.target == owner[0]._committed_target and actor.get_parent() == level and actor._current_map() and actor.age <= 1.0/60.0+0.000001 and actor.position.distance_to(owner[0].position) <= 2.5 and state.removed.count("summon:"+owner_id+":"+str(number)) == 1
			var capsule: CollisionShape3D = actor.get_child(0)
			nc_bindings[actor.id] = [actor.get_instance_id(),capsule.get_instance_id(),capsule.shape.get_instance_id()]
			nc_summons[actor.id] = [owner_id,number,tick,weakref(actor),actor.position]
			nc_removed.append("summon:"+owner_id+":"+str(number))
		var living: Array = enemies.filter(func(actor): return actor.hp > 0 and not actor._summon_owner_id.is_empty())
		nc_ok = nc_ok and living.size() <= 4 and living.filter(func(actor): return actor._summon_owner_id == "nursery_enemy_17").size() <= 2
	func _physics_process(delta: float) -> void:
		super._physics_process(delta)
		if not nc_enabled: return
		nc_ok = nc_ok and nc_current() and absf(delta-1.0/60.0) < 0.000001
		if not nc_current(): return
		nc_ticks += 1
		if not Input.is_action_pressed("fire"): nc_slot = -1.0
		nc_register_summons()
		nc_survey()
		nc_sync_selection()
	func nc_sync_selection() -> void:
		if state.weapon == nc_ledger.weapon: return
		nc_ok = nc_ok and nc_current() and nc_select == state.weapon and Input.is_action_pressed("weapon_"+str(state.weapon+1)) and state.weapon in nc_ledger.owned_weapons and player._weapon_intent == -1
		nc_selections.append([Engine.get_physics_frames(),nc_ledger.weapon,state.weapon])
		nc_ledger.weapon = state.weapon
	func nc_removed_matches() -> bool:
		# Summon births have no callback; their validated observation can follow another same-tick death.
		var actual: Array = state.removed.duplicate()
		var expected: Array = nc_removed.duplicate()
		actual.sort()
		expected.sort()
		return actual == expected and expected.all(func(id): return expected.count(id) == 1)
	func shot(weapon: int) -> void:
		if nc_enabled:
			var tick: int = Engine.get_physics_frames()
			nc_slot = entry_slot(tick,nc_last_tick,nc_slot,weapon)
			nc_sync_selection()
			nc_ok = nc_ok and nc_current() and Engine.is_in_physics_frame() and h_stack("/player.gd","fire") and h_stack("/player.gd","_physics_process") and Input.is_action_pressed("fire") and weapon == 1 and weapon == state.weapon and not player._fire_release_required and player.shot_age(weapon) == 0.0 and nc_slot >= 0.0 and player.active_play_time > nc_last_time[weapon] and nc_shots.size() < NC_SHOTS
			nc_ledger.ammo[weapon] -= 1
			nc_shots.append([tick,player.active_play_time,weapon,player.cooldown])
			nc_last_time[weapon] = player.active_play_time
			nc_last_tick = tick
			nc_ok = nc_ok and nc_ledger.ammo[weapon] >= 0 and budget() == nc_ledger and player.cooldown > 0 and player.cooldown <= Player.WEAPONS[weapon].interval+0.000001
		super.shot(weapon)
	func collect_pickup(id: String) -> void:
		if not nc_enabled:
			super.collect_pickup(id)
			return
		var rows: Array = level.layout.data.pickups.filter(func(spec): return spec.id == id)
		if rows.size() != 1:
			nc_ok = false
			super.collect_pickup(id)
			return
		var spec: Dictionary = rows[0]
		var before: Dictionary = nc_ledger.duplicate(true)
		var expected: Dictionary = before.duplicate(true)
		var marker = level.markers.get(id)
		nc_ok = nc_ok and nc_current() and Engine.is_in_physics_frame() and budget() == before and h_stack("/main.gd","update_passive_triggers") and h_stack("/player.gd","_physics_process") and not nc_consumed.has(id) and is_instance_valid(marker) and marker == nc_markers[id].get_ref() and marker.get_parent() == level and not marker.is_queued_for_deletion() and player.position.distance_to(level.layout.world_position(spec.cell)) < 1.4 and _passive_trigger_visible(spec)
		if spec.kind in ["weapon","ammo"]:
			var index: int = int(spec.weapon)
			if spec.kind == "weapon" and not index in expected.owned_weapons:
				expected.owned_weapons.append(index)
				expected.weapon = index
			expected.ammo[index] = mini(Player.WEAPONS[index].max_ammo,int(expected.ammo[index])+int(spec.amount))
		elif spec.kind == "health": expected.health = mini(100,int(expected.health)+int(spec.amount))
		elif spec.kind == "armor": expected.armor = mini(200,int(expected.armor)+int(spec.amount))
		else: nc_ok = false
		super.collect_pickup(id)
		var granted: bool = expected != before
		nc_pickups.append([id,Engine.get_physics_frames(),before,expected.duplicate(true),granted])
		nc_ledger = expected
		if granted:
			nc_consumed[id] = 1
			nc_removed.append(id)
		nc_ok = nc_ok and budget() == expected and state.removed.count(id) == (1 if granted else 0) and (not level.markers.has(id) if granted else level.markers.get(id) == marker)
	func activate_encounter(id: String) -> void:
		if not nc_enabled or "encounter:"+id in state.removed:
			super.activate_encounter(id)
			return
		var rows: Array = level.layout.data.encounters.filter(func(spec): return spec.id == id)
		if rows.size() != 1:
			nc_ok = false
			return
		var spec: Dictionary = rows[0]
		var cell: Vector2 = Vector2(player.position.x,player.position.z)/4.0
		var region: Array = spec.region
		nc_ok = nc_ok and nc_current() and id in ["nursery_first_commit","nursery_first_return"] and not nc_activated.has(id) and h_stack("/main.gd","_process") and not h_stack("/enemy.gd","take_damage") and cell.is_equal_approx(cell.clamp(Vector2(region[0],region[1]),Vector2(region[2],region[3]))) and spec.requires.all(func(key): return key in nc_keys)
		super.activate_encounter(id)
		nc_activated[id] = [Engine.get_physics_frames(),cell,state.keys.duplicate()]
		nc_removed.append("encounter:"+id)
		for actor in enemies:
			if actor.id in spec.enemy_ids: nc_ok = nc_ok and nc_actor(actor) and actor.hp == actor.max_hp and actor.active and actor.alerted
		for light in spec.cue.light_ids:
			nc_ok = nc_ok and level.machine_lights.has(light) and level.machine_lights[light].light_color == (Color(1.0,0.76,0.44) if id == "nursery_first_commit" and "blood" in nc_keys else Color(1.0,0.28,0.1))
	func enemy_event(actor, event: String) -> void:
		if nc_enabled:
			nc_ok = nc_ok and nc_current() and nc_actor(actor) and actor.active and Engine.is_in_physics_frame() and h_stack("/enemy.gd","_event")
			nc_events.append([actor.id,event,Engine.get_physics_frames(),actor.hp,actor._committed_variant,actor.phase])
			if event == "attack" and actor.kind == "worker":
				var origin: Vector3 = actor.global_position+Vector3.UP*1.4
				var end: Vector3 = origin+(actor._committed_aim-origin).normalized()*30.0
				var query = PhysicsRayQueryParameters3D.create(origin,end,1|2|4)
				query.exclude = [actor.get_rid()]
				query.hit_from_inside = true
				nc_worker = {"source":actor,"tick":Engine.get_physics_frames(),"hit":level.get_world_3d().direct_space_state.intersect_ray(query)}
			if event == "attack" and actor.kind == "summoner": nc_summon_attacks[actor.id] = [Engine.get_physics_frames(),actor._summoned_total]
			if event == "melee_contact":
				var intended = actor._committed_target
				var query = PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*0.6,intended.global_position+Vector3.UP*0.7,1|2|4)
				query.exclude = [actor.get_rid()]
				query.hit_from_inside = true
				nc_melee = {"source":actor,"tick":Engine.get_physics_frames(),"hit":level.get_world_3d().direct_space_state.intersect_ray(query)}
			if event == "death":
				var source = nc_projectile_pending.source if not nc_projectile_pending.is_empty() and nc_projectile_pending.hit.get("collider") == actor else actor.target
				var mode: String = "unproven"
				if source == player and h_stack("/player.gd","fire") and h_stack("/enemy.gd","take_damage") and not nc_shots.is_empty() and nc_shots[-1][0] == Engine.get_physics_frames() and Input.is_action_pressed("fire") and aim_observation.get("level") == level and aim_observation.get("player") == player and aim_observation.get("actor_id","") == actor.id and aim_observation.get("tick",-1) == Engine.get_physics_frames(): mode = "player"
				elif nc_native_contact(actor,source): mode = "infighting"
				nc_deaths[actor.id] = nc_deaths.get(actor.id,0)+1
				nc_finishes[actor.id] = mode
				nc_removed.append(actor.id)
				nc_ok = nc_ok and mode != "unproven" and actor.hp == 0 and actor.collision_layer == 0 and actor.collision_mask == 0 and nc_deaths[actor.id] == 1 and state.removed.count(actor.id) == 1
		super.enemy_event(actor,event)
	func nc_native_contact(victim, source) -> bool:
		if not nc_actor(source): return false
		var tick: int = Engine.get_physics_frames()
		if not nc_projectile_pending.is_empty():
			var pending: Dictionary = nc_projectile_pending
			if pending.source == source and pending.tick == tick and pending.hit.collider == victim and pending.hit.rid == victim.get_rid() and h_stack("/projectile.gd","_physics_process"):
				nc_projectile_pending.clear()
				return true
		if source.hp <= 0 or not source.active: return false
		for contact in [nc_worker,nc_melee]:
			if contact.get("source") == source and contact.get("tick",-1) == tick and contact.hit.get("collider") == victim and contact.hit.get("rid") == victim.get_rid() and h_stack("/enemy.gd","_attack") and h_stack("/enemy.gd","_release_attack" if source.kind == "worker" else "_try_melee"): return true
		return false
	func _debug_projectile_event(projectile: Node3D, event: String, data: Dictionary) -> void:
		if nc_enabled:
			var id: int = projectile.get_instance_id()
			var source = projectile.shooter
			nc_ok = nc_ok and nc_current() and OS.is_debug_build() and Engine.is_in_physics_frame() and nc_actor(source) and projectile.get_script() == preload("res://scripts/projectile.gd") and projectile.game == self and projectile._current_map() and projectile.get_parent() == level and projectile.is_physics_processing() and data.get("projectile") == projectile and data.get("source") == source and data.get("map") == level and data.get("player") == player and data.get("tick",-1) == Engine.get_physics_frames() and data.get("position") == projectile.global_position and data.get("velocity") == projectile.velocity and data.get("lifetime") == projectile.lifetime and projectile.blast_damage == 0 and projectile.velocity.is_finite() and is_equal_approx(projectile.velocity.length(),12.0) and projectile.lifetime > 0 and projectile.lifetime <= 4.0
			if event == "configured_birth":
				nc_ok = nc_ok and not nc_births.has(id) and source.hp > 0 and source.active and source.kind == "caster" and h_stack("/enemy.gd","_release_attack") and data.origin == projectile.global_position and data.origin.is_finite() and data.destination.is_finite() and projectile.velocity.is_equal_approx((data.destination-data.origin).normalized()*12.0) and projectile.lifetime == 4.0
				nc_births[id] = [weakref(projectile),source.get_instance_id(),Engine.get_physics_frames()]
			else:
				var hit: Dictionary = data.get("hit",{})
				var victim = hit.get("collider")
				nc_ok = nc_ok and event in ["queued_player_contact","queued_enemy_contact"] and nc_births.has(id) and not nc_contacts.has(id) and nc_births[id][0].get_ref() == projectile and nc_births[id][1] == source.get_instance_id() and Engine.get_physics_frames()-int(nc_births[id][2]) <= 241 and projectile.is_queued_for_deletion() and h_stack("/projectile.gd","_physics_process") and (victim == player if event == "queued_player_contact" else nc_actor(victim) and victim.hp > 0 and victim != source) and hit.get("rid") == victim.get_rid() and data.ray_start.is_finite() and data.ray_end.is_equal_approx(data.ray_start+projectile.velocity*minf(1.0/60.0,projectile.lifetime))
				var query = PhysicsRayQueryParameters3D.create(data.ray_start,data.ray_end,1|2|4)
				query.exclude = [source.get_rid()]
				query.hit_from_inside = true
				nc_ok = nc_ok and level.get_world_3d().direct_space_state.intersect_ray(query) == hit
				nc_contacts[id] = [event,source.id,victim.get_instance_id(),Engine.get_physics_frames(),hit.position]
				if victim == player or victim.hp <= 14:
					nc_ok = nc_ok and nc_projectile_pending.is_empty()
					nc_projectile_pending = {"id":id,"source":source,"tick":Engine.get_physics_frames(),"hit":hit,"projectile":projectile}
		super._debug_projectile_event(projectile,event,data)
	func hurt_player(amount: int) -> void:
		if nc_enabled:
			var source = null
			if not nc_projectile_pending.is_empty(): source = nc_projectile_pending.source
			else:
				for contact in [nc_worker,nc_melee]:
					if contact.get("tick",-1) == Engine.get_physics_frames() and contact.hit.get("collider") == player: source = contact.source

			var expected_amount: int = 14 if h_stack("/projectile.gd","_physics_process") else 10 if is_instance_valid(source) and source.kind == "worker" else 24 if is_instance_valid(source) and source.kind == "brute" else 12
			nc_ok = nc_ok and nc_current() and Engine.is_in_physics_frame() and budget() == nc_ledger and amount == expected_amount and state.difficulty == 1 and nc_native_contact(player,source)
			var absorbed: int = mini(int(nc_ledger.armor),int(amount/3))
			nc_ledger.armor -= absorbed
			nc_ledger.health = maxi(0,int(nc_ledger.health)-amount+absorbed)
			nc_hurts.append([Engine.get_physics_frames(),source.id if is_instance_valid(source) else "unproven",amount,absorbed])
		super.hurt_player(amount)
		if nc_enabled: nc_ok = nc_ok and budget() == nc_ledger
	func interact() -> void:
		if nc_enabled:
			var spec: Dictionary = nearest_interaction()
			nc_ok = nc_ok and nc_current() and Engine.is_in_physics_frame() and Input.is_action_pressed("interact") and h_stack("/player.gd","_physics_process") and spec.get("id","") == "nursery_blood"
			nc_inputs.append([spec.get("id",""),Engine.get_physics_frames(),player.position])
		super.interact()
	func collect_key(id: String) -> void:
		if nc_enabled:
			nc_ok = nc_ok and nc_current() and id == "nursery_blood" and nc_keys.is_empty() and nc_inputs.size() == 1 and h_stack("/main.gd","interact") and h_stack("/player.gd","_physics_process") and Input.is_action_pressed("interact") and level.markers.get(id) == nc_markers[id].get_ref()
		super.collect_key(id)
		if nc_enabled:
			nc_keys.append("blood")
			nc_removed.append(id)
			nc_ok = nc_ok and state.keys == nc_keys and state.removed.count(id) == 1 and not level.markers.has(id)
			for light in ["nursery_gestation_feed","nursery_gestation_core"]: nc_ok = nc_ok and level.machine_lights[light].light_color == Color(1.0,0.76,0.44)
	func _capture_actor_state() -> bool:
		if nc_enabled:
			nc_capture_calls += 1
			nc_ok = false # This bounded first-loop slice never reaches the pre-finale checkpoint.
		return super._capture_actor_state()
	func _capture_game_mouse() -> void:
		if nc_enabled: nc_mouse_attempts.append([Engine.get_physics_frames(),state.level_index,placement_pending,playing])
		super._capture_game_mouse()
	func _save() -> Error:
		if nc_enabled:
			nc_save_calls += 1
			nc_ok = false
		return super._save()

var nc_started: bool = false
var nc_epoch: int = 0
var nc_wall: int = 0
var nc_frozen_fields: Array = []
var nc_frozen: Dictionary = {}
var nc_saved_sha: String = ""
var nc_originals: Dictionary = {}

func run() -> void:
	if "--nursery-campaign-pin-rejection" in OS.get_cmdline_user_args():
		await nursery_campaign_pin_rejection()
		return
	var ok: bool = await walk_through_nursery(NurseryCampaignMain.new())
	if ok: print("PASS proposed source-native virtual-input earned Nursery GESTATION/BLOOD/RETURN segment only; seed loop, checkpoint, gate, Warden and descent remain open. Not native evidence until executed; not physical/render/audio/performance/packed/full-eight acceptance.")
	await finish(0 if ok else 1)

func walk_through_nursery(observer: NurseryCampaignMain, profile_prefix: String = "") -> bool:
	if not expect(NC_CORE_PINS.keys().all(func(path): return FileAccess.get_sha256(path) == NC_CORE_PINS[path]) and FileAccess.get_sha256("res://tests/test_nursery_earned_entry.gd") == NC_ENTRY_SHA and FileAccess.get_sha256("res://data/05_nursery.json") == N_MAP_SHA,"Pinned complete accepted Nursery entry and original fifth map BEFORE observer/profile adoption"):
		if is_instance_valid(observer) and observer != game and observer.get_parent() == null and not observer.is_inside_tree(): observer.free()
		return false
	if not await walk_into_nursery(observer,profile_prefix): return false
	# walk_into_nursery returns only after nursery_entry_result; freeze the entire accepted prefix now.
	var actual: Array = []
	for property in game.get_property_list():
		if str(property.name).begins_with("n_") and property.name != "n_enabled": actual.append(property.name)
	actual.sort()
	var declared: Array = NC_N_FIELDS.duplicate()
	declared.sort()
	if not expect(actual == declared and game.n_ok and game.n_enabled,"Complete accepted N observer field inventory before relevant adapter retirement"): return false
	nc_frozen_fields = n_fields+NC_N_FIELDS
	nc_frozen = observer_witness(nc_frozen_fields)
	nc_saved_sha = FileAccess.get_sha256(r_profile)
	game.nc_ledger = game.budget().duplicate(true)
	game.nc_start = game.state.level_start.duplicate(true)
	game.nc_explored = game.state.explored.duplicate(true)
	game.nc_last_cell = game.n_last_cell
	game.nc_bindings = game.n_bindings.duplicate(true)
	for actor in game.enemies: nc_originals[actor.id] = [actor.position,actor.rotation.y,actor.age,actor.max_hp,actor.kind,actor.encounter_id]
	for id in route_level.markers: game.nc_markers[id] = weakref(route_level.markers[id])
	release_actions()
	game.n_enabled = false
	nc_epoch = Engine.get_physics_frames()
	nc_wall = Time.get_ticks_usec()
	nc_started = true
	game.nc_enabled = true
	if not await nursery_route(NC_APPROACH.slice(0,9)) or not await nursery_select_pistol(): return false
	if not await nursery_route(NC_APPROACH.slice(9)) or not await nursery_fight("nursery_first_commit"): return false
	if not await nursery_route(NC_GESTATION) or not await nursery_blood_input(): return false
	if not await nursery_route(NC_RETURN) or not await nursery_fight("nursery_first_return") or not await nursery_route(NC_JUNCTION): return false
	return nursery_segment_result()

func nursery_campaign_pin_rejection() -> void:
	if not expect(FileAccess.get_sha256("res://tests/test_nursery_earned_entry.gd") != NC_ENTRY_SHA,"Pin control requires parent-owned deliberate accepted-entry mismatch"):
		await finish(1)
		return
	var fixture: String = "user://reliquary_catalogue_exit_nursery_campaign_pin_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	if not expect(["_campaign.json","_campaign.json.tmp","_preferences.json","_preferences.json.tmp"].all(func(suffix): return not FileAccess.file_exists(fixture+suffix)),"Fresh pin-control namespace only"):
		quit(1)
		return
	var observer = NurseryCampaignMain.new()
	var reference = weakref(observer)
	var result: bool = await walk_through_nursery(observer,fixture)
	var ok: bool = expect(not result and reference.get_ref() == null and game == null and root.get_child_count() == 0 and ["_campaign.json","_campaign.json.tmp","_preferences.json","_preferences.json.tmp"].all(func(suffix): return not FileAccess.file_exists(fixture+suffix)),"Wrong pin refuses/frees detached observer before adoption and leaves ONLY fresh namespace untouched")
	prefix = fixture
	await finish(0 if ok else 1)

func live_route() -> bool:
	if not nc_started: return super.live_route()
	if not expect(Engine.get_physics_frames()-nc_epoch <= NC_LIMIT and Time.get_ticks_usec()-nc_wall <= NC_SECONDS*1000000,"Nursery-only finite outer guard; ancestor limits unchanged"): return false
	if not expect(game.nc_ok and game.nc_current() and game.get_instance_id() == r_main_id and game.state.get_instance_id() == r_campaign_id and game.progress_path == r_profile and game.settings_path == game.r_settings_origin and game.level == route_level and game.player == route_player and game.is_processing() and game.is_physics_processing() and route_player.is_physics_processing() and route_player.position.is_finite() and game.state.health > 0,"Same earned native owner/profile/Player, live production AI/input and positive finite survival"): return false
	if not expect(observer_witness(nc_frozen_fields) == nc_frozen and not game.n_enabled and not game.e_enabled and observers_retired() and e_retired.all(func(ref): return ref.get_ref() == null) and e_markers.values().all(func(ref): return ref.get_ref() == null) and retired.all(func(ref): return ref.get_ref() == null) and x_marker_refs.values().all(func(ref): return ref.get_ref() == null),"All accepted prefix and N histories frozen separately; retired owners/markers drained"): return false
	game.nc_register_summons()
	game.nc_sync_selection()
	var children: Array = route_level.get_children().filter(func(node): return node.get_script() == game.Enemy).map(func(node): return node.get_instance_id())
	var bound: Array = game.nc_bindings.values().map(func(record): return record[0])
	children.sort()
	bound.sort()
	if not expect(children == bound and game.enemies.size() == bound.size() and game.enemies.size() == 29+game.nc_summons.size(),"Exact29 originals plus proven native budgeted summons; no fake/replaced actors"): return false
	for actor in game.enemies:
		var capsule: CollisionShape3D = actor.get_child(0)
		var binding: Array = game.nc_bindings[actor.id]
		if not expect(game.nc_actor(actor) and actor.is_physics_processing() and capsule.get_instance_id() == binding[1] and capsule.shape.get_instance_id() == binding[2] and not capsule.disabled and capsule.shape is CapsuleShape3D and absf(capsule.shape.radius-N_ROLES[actor.kind][1]) < 0.000001 and absf(capsule.shape.height-N_ROLES[actor.kind][2]) < 0.000001 and capsule.position == Vector3(0,capsule.shape.height/2,0) and actor.position.is_finite() and is_finite(actor.rotation.y) and actor.hp >= 0 and actor.hp <= actor.max_hp,"Live original native capsule/role/HP/processing provenance: "+actor.id): return false
		if nc_originals.has(actor.id):
			var original: Array = nc_originals[actor.id]
			if not expect(actor.max_hp == original[3] and actor.kind == original[4] and actor.encounter_id == original[5] and actor.age-original[2] >= float(Engine.get_physics_frames()-nc_epoch-2)/60.0,"Original actor group/HP ceiling/native age preserved: "+actor.id): return false
			if not game.nc_activated.has(actor.encounter_id) and not expect(actor.hp == actor.max_hp and actor.position == original[0] and actor.rotation.y == original[1] and not actor.active and not actor.alerted,"Unentered second loop/finale actors remain original inactive/fullHP: "+actor.id): return false
		if actor.hp > 0:
			if not expect(actor.collision_layer == 4 and actor.collision_mask == 7,"Living actors retain native collisions"): return false
			var floor_hit: Dictionary = route_level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(actor.position+Vector3.UP*0.5,actor.position-Vector3.UP*6,1))
			if not expect(not floor_hit.is_empty() and floor_hit.normal.y >= 0.7 and absf(actor.position.y-floor_hit.position.y-(1.0 if actor.kind == "caster" else 0.0)) <= (0.25 if actor.kind == "caster" else 0.15),"Living actor has actual authored native floor support: "+actor.id): return false
		elif not expect(game.nc_deaths.get(actor.id,0) == 1 and game.nc_finishes.get(actor.id,"unproven") != "unproven" and actor.collision_layer == 0 and actor.collision_mask == 0 and game.state.removed.count(actor.id) == 1,"Native once-only death and collision retirement: "+actor.id): return false
	for id in game.nc_markers:
		if id in game.nc_removed:
			if not expect(not route_level.markers.has(id),"Production removes only earned marker: "+id): return false
		elif not expect(route_level.markers.get(id) == game.nc_markers[id].get_ref() and is_instance_valid(game.nc_markers[id].get_ref()) and not game.nc_markers[id].get_ref().is_queued_for_deletion(),"Every unclaimed original marker remains: "+id): return false
	for node in route_level.get_children():
		if node.get_script() == preload("res://scripts/projectile.gd") and not node.is_queued_for_deletion():
			if not expect(game.nc_births.has(node.get_instance_id()) and game.nc_births[node.get_instance_id()][0].get_ref() == node and game.nc_actor(node.shooter) and node._current_map() and node.is_physics_processing() and node.lifetime > 0 and node.lifetime <= 4.0,"Every live native projectile retains original observed birth/shooter/lifetime"): return false
	return expect(game.nc_ok and game.budget() == game.nc_ledger and game.state.keys == game.nc_keys and game.nc_removed_matches() and game.state.explored == game.nc_explored and game.state.discoveries == [3] and game.state.checkpoint_id == "entry" and game.state.checkpoint == game.nc_start and game.state.level_start == game.nc_start and game.state.actors == game.nc_start.actors and FileAccess.get_sha256(r_profile) == nc_saved_sha and game.nc_save_calls == 0 and game.nc_capture_calls == 0 and game.nc_mouse_attempts.is_empty() and game.nc_projectile_pending.is_empty(),"Independent all-pickup/shot/damage/activation/summon/survey ledger; entry recovery/actor image and disk unchanged")

func route_tick() -> bool:
	if not nc_started: return await super.route_tick()
	if not live_route(): return false
	await physics_frame
	return live_route()

func clear_point(cell: Array):
	if not nc_started: return super.clear_point(cell)
	# Reuse the accepted unrestricted native floor/capsule check, not Exit's old-map rectangle.
	if not route_level.layout.is_walkable(Vector2i(floori(cell[0]),floori(cell[1]))): return null
	var point: Vector3 = route_level.layout.world_position(cell)
	var space = route_level.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*2,point-Vector3.UP*0.5,1))
	if hit.is_empty() or absf(hit.position.y-point.y) > 0.08 or hit.normal.y < 0.7: return null
	var collider: CollisionShape3D = route_player.get_child(0)
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.transform = Transform3D(Basis.IDENTITY,point+Vector3.UP*0.04+collider.position)
	query.collision_mask = route_player.collision_mask
	query.exclude = [route_player.get_rid()]
	return point+Vector3.UP*0.04 if space.intersect_shape(query,1).is_empty() else null

func nursery_select_pistol() -> bool:
	release_actions()
	game.nc_select = 1
	var event = InputEventAction.new()
	event.action = "weapon_2"
	event.pressed = true
	event.strength = 1.0
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	for frame in range(2):
		if not await route_tick(): return false
	Input.action_release("weapon_2")
	return expect(game.state.weapon == 1 and game.nc_ledger.weapon == 1,"Real Player weapon intent selects owned pistol; resources are never assigned")

func nursery_fire() -> bool:
	Input.action_release("fire")
	if game.state.weapon != 1 or game.state.ammo[1] <= 0 or game.nc_shots.size() >= NC_SHOTS: return false
	var selected = null
	var nearest: float = game.Player.WEAPONS[1].range
	for actor in game.enemies:
		if not game.nc_actor(actor) or actor.hp <= 0 or not actor.active: continue
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

func nursery_route(cells: Array) -> bool:
	for cell in cells:
		var target: Vector3 = route_level.layout.world_position(cell)+Vector3.UP*0.04
		var began: int = Engine.get_physics_frames()
		while true:
			if not live_route() or not expect(Engine.get_physics_frames()-began < NC_HOP,"Nursery-only clearance/movement cap at "+str(cell)): return false
			var clear: bool = clear_point(cell) != null
			var start: Vector3 = route_player.position
			var samples: int = ceili(start.distance_to(target)/0.5)
			for sample in range(samples+1):
				var point: Vector3 = start.lerp(target,float(sample)/maxi(1,samples))
				if clear_point([point.x/4,point.z/4]) == null: clear = false
			if clear: break
			release_actions()
			if not expect(nursery_fire(),"Blocked original route must have a finite visible active actor, never idle/retry navigation"): return false
			if not await route_tick(): return false
		while Vector2(route_player.position.x-target.x,route_player.position.z-target.z).length() > 0.12:
			if not live_route() or not expect(Engine.get_physics_frames()-began < NC_HOP,"Nursery-only movement deadline at "+str(cell)): return false
			release_actions()
			if not nursery_fire(): route_player.look_at(Vector3(target.x,route_player.position.y,target.z),Vector3.UP)
			var direction: Vector3 = target-route_player.position
			direction.y = 0
			var deadzone: float = 0.0
			for action in ["move_left","move_right","move_forward","move_back"]: deadzone += InputMap.action_get_deadzone(action)/4.0
			var axes: Vector3 = route_player.basis.inverse()*direction.normalized()*(deadzone+(1.0-deadzone)*minf(1.0,direction.length()*6.0/9.0))
			for action in [["move_right",axes.x],["move_left",-axes.x],["move_back",axes.z],["move_forward",-axes.z]]: Input.action_press(action[0],maxf(0,action[1]))
			if not await route_tick(): return false
		release_actions()
		for frame in range(12):
			if not expect(Engine.get_physics_frames()-began < NC_HOP,"Nursery settling shares leg deadline"): return false
			nursery_fire()
			if not await route_tick(): return false
		release_actions()
		await process_frame
		if not live_route() or not expect(route_player.position.distance_to(target) < 0.2 and clear_point(cell) != null,"Actual native settled Nursery waypoint: "+str(cell)): return false
		print("NURSERY_GESTATION_HOP cell=",cell," frame=",Engine.get_physics_frames()-nc_epoch," resources=",game.nc_ledger)
	return true

func nursery_fight(group_id: String) -> bool:
	if not expect(game.nc_activated.has(group_id),"Original group earned through its actual region: "+group_id): return false
	for frame in range(NC_FIGHT):
		if not live_route(): return false
		if game.enemies.all(func(actor): return actor.hp == 0 or actor.encounter_id != group_id and actor._summon_owner_id.is_empty()):
			release_actions()
			return true
		release_actions()
		if not expect(nursery_fire(),"Finite first-loop fight requires visible live native target, not idle waiting"): return false
		if not await route_tick(): return false
	release_actions()
	return expect(false,"Nursery-only1800-frame combat cap: "+group_id)

func nursery_blood_input() -> bool:
	aim_interaction([9.5,12.5])
	if not "--omit-nursery-blood" in OS.get_cmdline_user_args(): interaction_input(true)
	for frame in range(6):
		if not await route_tick(): return false
		if "blood" in game.state.keys: break
	interaction_input(false)
	release_actions()
	await process_frame
	return live_route() and expect(game.nc_keys == ["blood"] and game.nc_inputs.size() == 1 and game.nc_inputs[0][0] == "nursery_blood" and game.nc_markers["nursery_blood"].get_ref() == null,NC_BLOOD_GUARD)

func nursery_segment_result() -> bool:
	if not live_route(): return false
	var yaw: float = route_player.rotation.y
	if yaw < -PI or yaw >= PI: yaw = wrapf(yaw,-PI,PI)
	yaw = Vector3(0,clampf(yaw,-3.1415925,3.1415925),0).y
	if not expect(game.state.position == route_player.position and game.state.yaw == yaw and game.state.pitch == clampf(route_player.camera.rotation.x,-1.35,1.35),"Independent settled current Campaign position/yaw/pitch matches actual native Player facing"): return false
	var ids: Array = N_ACTORS.filter(func(spec): return spec[6] in [0,2]).map(func(spec): return spec[0])
	var expected: Array = ids+game.nc_summons.keys()
	if not expect(expected.all(func(id): return game.nc_deaths.get(id,0) == 1 and game.nc_finishes.get(id,"unproven") in ["player","infighting"]) and game.nc_deaths.size() == expected.size() and game.nc_activated.keys() == ["nursery_first_commit","nursery_first_return"] and game.state.keys == ["blood"] and game.state.owned_weapons == [0,1,2,3] and game.state.ammo[3] == 60 and game.state.ammo[2] == 32 and game.nc_inputs.size() == 1 and route_player.position.distance_to(route_level.layout.world_position([14.0,21.0])) < 0.2 and game.nc_shots.size() > 0 and game.nc_shots.size() <= NC_SHOTS,"Coherent nonquitting original gestation loop/Blood/return/junction; all11 original and any real summoned deaths, finite earned repeater, second loop/finale still dormant"): return false
	print("NURSERY_EARNED_SEGMENT frames=",Engine.get_physics_frames()-nc_epoch," wall_us=",Time.get_ticks_usec()-nc_wall," shots=",game.nc_shots," hurts=",game.nc_hurts," pickups=",game.nc_pickups," deaths=",game.nc_deaths," provenance=",game.nc_finishes," births=",game.nc_births.size()," contacts=",game.nc_contacts.size()," summons=",game.nc_summons.size()," resources=",game.nc_ledger," saved_sha=",nc_saved_sha)
	return true

func finish(status: int) -> void:
	# Refused detached observers have never adopted a profile; do not run inherited file cleanup.
	if game == null:
		release_actions()
		quit(status)
		return
	await super.finish(status)
