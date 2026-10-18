extends "res://tests/test_nursery_seed_loop.gd"

# Provisional seed dependency: parent rebinds ONLY this pin after accepted seed review.
const NF_SEED_SHA = "b2efd4ecf6f306c38ac276480b2e2fe8cb96fb967241e0c5b2303d0f86b4e2ab"
const NF_OSSUARY_SHA = "781a86ab846db76d7189f108281f009b300812a5c2136faa754b9a74000bc74c"
const NF_ANCESTOR_SAVE_SHA = "1da02250064a304d13212f4f8fe1c4ab2dda32e20ce152b2246d4e05d3e348d0"
const NF_RESULT_SAVE_SHA = "15353b6ea7d39856fcd975c2195d391bfdd7cc2f17d567022945bd749f4558ce"
const NF_RESULT_RESOURCES = {"health":93,"armor":197,"ammo":[0,99,32,120,0,0],"owned_weapons":[0,1,2,3],"weapon":1}
const NF_CARRY = {"health":78,"armor":194,"ammo":[0,163,32,60,0,0],"owned_weapons":[0,1,2,3],"weapon":1}
# New phase only: finite route plus81 ideal pistol hits for1660 original finale HP.
const NF_LIMIT = 9000
const NF_SECONDS = 300
const NF_HOP = 900
const NF_FIGHT = 3600
const NF_SHOTS = 110
const NF_INPUT = 6
const NF_GATE_WAIT = 60
const NF_DRAIN = 246
const NF_ENTRY_LIMIT = 30
const NF_ENTRY_SECONDS = 10
const NF_STORY_ROUTE = [[20.0,21.0],[23.25,21.0],[23.25,23.75]]
const NF_SUPPLIES = [[23.25,21.0],[25.5,21.5],[25.5,20.5],[24.5,20.5],[24.5,19.5],[25.5,19.5],[26.5,19.5],[25.5,19.5],[25.5,17.6]]
# Original controlled active-boss fixture's route and entry, now reached by earned movement.
const NF_APPROACH = [[25.5,16.4],[25.5,14.5]]
const NF_BATTLE = [[25.5,4.75],[35.5,4.75],[35.5,14.0],[25.5,14.0]]
const NF_CLOSE = [[35.5,14.0],[35.5,5.5]]
const NF_GATE_GUARD = "NATIVE RED Nursery finale requires queued E, both earned keys and original growthgate collision retirement"
const NF_EXIT_GUARD = "NATIVE RED Nursery finale requires queued E after seven proven original deaths and real saved Ossuary intermission"
const NF_STORY = {"id":"nursery_story","kind":"story","cell":[23.25,23.75],"text":"The growth chart labels your repairs as release trials. Every successful recovery has widened the restraints."}
const NF_DOOR = {"id":"nursery_growth_gate","cell":[25.5,16.7],"size":[12.2,5.0,0.6],"requires":["blood","ivory"],"yaw":0.0}
const NF_CHECKPOINT = {"id":"nursery_checkpoint","kind":"checkpoint","cell":[25.5,19.5],"requires":["blood","ivory"],"text":"RECOVERY IMAGE STORED"}
const NF_DESCENT = {"id":"nursery_descent","kind":"exit","cell":[35.5,5.5],"requires":["blood","ivory"],"text":"GROWTH FEEDS STABLE / DESCEND","requires_defeated":["nursery_warden"]}
const NF_IDS = ["nursery_enemy_22","nursery_enemy_23","nursery_enemy_24","nursery_enemy_25","nursery_enemy_26","nursery_enemy_27","nursery_warden"]
const NF_NS_FIELDS = ["ns_ok","ns_ticks","ns_ledger","ns_removed","ns_keys","ns_pickups","ns_consumed","ns_shots","ns_last_time","ns_last_tick","ns_slot","ns_activated","ns_events","ns_deaths","ns_finishes","ns_hurts","ns_births","ns_contacts","ns_projectile_pending","ns_worker","ns_melee","ns_summons","ns_summon_attacks","ns_explored","ns_last_cell","ns_inputs","ns_capture_calls","ns_mouse_attempts","ns_save_calls","ns_start","ns_bindings","ns_markers","ns_select","ns_selections","ns_actor_image","ns_checkpoint","ns_saved_sha","ns_hp","ns_damage_events"]
const NF_O_ACTORS = [["ossuary_enemy_00","brute",4.5,21.5,1.5,225,"ossuary_first_commit"],["ossuary_enemy_01","crawler",8.5,21.5,1.5,135,"ossuary_first_commit"],["ossuary_enemy_02","worker",4.5,17.5,1.5,243,"ossuary_first_commit"],["ossuary_enemy_03","crawler",8.5,18.5,1.5,90,"ossuary_first_commit"],["ossuary_enemy_04","worker",9.5,16.5,1.5,124,"ossuary_first_commit"],["ossuary_enemy_05","caster",9.5,12.5,1.5,153,"ossuary_first_commit"],["ossuary_enemy_06","crawler",5.5,14.5,1.5,194,"ossuary_first_commit"],["ossuary_enemy_07","worker",3.5,12.5,1.5,207,"ossuary_first_commit"],["ossuary_enemy_08","guardian",26.5,15.5,-1.5,207,"ossuary_second_commit"],["ossuary_enemy_09","crawler",31.5,15.5,-1.5,117,"ossuary_second_commit"],["ossuary_enemy_10","worker",33.5,11.5,-1.5,149,"ossuary_second_commit"],["ossuary_enemy_11","crawler",27.5,9.5,-1.5,180,"ossuary_second_commit"],["ossuary_enemy_12","worker",32.5,8.5,-1.5,149,"ossuary_second_commit"],["ossuary_enemy_13","caster",29.5,7.5,-1.5,180,"ossuary_second_commit"],["ossuary_enemy_14","crawler",24.5,12.5,-1.5,217,"ossuary_second_commit"],["ossuary_enemy_15","worker",25.5,8.5,-1.5,202,"ossuary_second_commit"],["ossuary_enemy_16","summoner",18.5,13.5,0.0,90,"ossuary_first_return"],["ossuary_enemy_17","crawler",19.5,16.5,0.0,0,"ossuary_first_return"],["ossuary_enemy_18","worker",18.5,20.5,0.0,346,"ossuary_first_return"],["ossuary_enemy_19","crawler",19.5,10.5,0.0,243,"ossuary_second_return"],["ossuary_enemy_20","worker",20.5,11.5,-0.1875,270,"ossuary_second_return"],["ossuary_enemy_21","crawler",20.5,22.5,0.0,14,"ossuary_second_return"],["ossuary_enemy_22","worker",19.5,32.5,0.0,288,"ossuary_finale"],["ossuary_enemy_23","crawler",25.5,33.5,0.0,56,"ossuary_finale"],["ossuary_enemy_24","caster",26.5,36.5,0.0,53,"ossuary_finale"],["ossuary_enemy_25","worker",18.5,37.5,0.0,315,"ossuary_finale"],["ossuary_enemy_26","crawler",23.5,36.5,0.0,18,"ossuary_finale"]]

class NurseryFinaleMain:
	extends "res://tests/test_nursery_seed_loop.gd".NurserySeedMain
	var nf_enabled: bool = false
	var nf_ok: bool = true
	var nf_ticks: int = 0
	var nf_ledger: Dictionary = {}
	var nf_removed: Array = []
	var nf_keys: Array = []
	var nf_pickups: Array = []
	var nf_consumed: Dictionary = {}
	var nf_shots: Array = []
	var nf_last_time: Array = [-INF,-INF,-INF,-INF,-INF,-INF]
	var nf_last_tick: int = -1
	var nf_slot: float = -1.0
	var nf_activated: Dictionary = {}
	var nf_events: Array = []
	var nf_deaths: Dictionary = {}
	var nf_finishes: Dictionary = {}
	var nf_hurts: Array = []
	var nf_births: Dictionary = {}
	var nf_contacts: Dictionary = {}
	var nf_projectile_pending: Dictionary = {}
	var nf_worker: Dictionary = {}
	var nf_melee: Dictionary = {}
	var nf_explored: Array = []
	var nf_last_cell: Vector2i = Vector2i(-1,-1)
	var nf_inputs: Array = []
	var nf_capture_calls: int = 0
	var nf_mouse_attempts: Array = []
	var nf_save_calls: int = 0
	var nf_start: Dictionary = {}
	var nf_bindings: Dictionary = {}
	var nf_markers: Dictionary = {}
	func nf_current() -> bool:
		return nf_enabled and playing and not get_tree().paused and not placement_pending and not loaded_positions and state.level_index == 4 and _scene_level_index == 4 and is_instance_valid(level) and not level.is_queued_for_deletion() and level.get_instance_id() == n_level_id and is_instance_valid(player) and not player.is_queued_for_deletion() and player.get_parent() == level and player.get_instance_id() == n_player_id
	func nf_actor(actor) -> bool:
		return is_instance_valid(actor) and actor.get_script() == Enemy and nf_bindings.has(actor.id) and nf_bindings[actor.id][0] == actor.get_instance_id() and actor._current_map() and actor.get_parent() == level and not actor.is_queued_for_deletion()
	func nf_survey() -> void:
		var cell: Vector2i = Vector2i((Vector2(player.position.x,player.position.z)/4.0).floor())
		if cell == nf_last_cell or not level.layout.is_walkable(cell): return
		nf_last_cell = cell
		for x in range(cell.x-2,cell.x+3):
			for z in range(cell.y-2,cell.y+3):
				var point: Vector2i = Vector2i(x,z)
				var saved: Array = [x,z]
				if not level.layout.is_walkable(point) or saved in nf_explored: continue
				var end: Vector3 = level.layout.world_position([x+0.5,z+0.5])+Vector3.UP*1.55
				if point == cell or level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(player.camera.global_position,end,1)).is_empty(): nf_explored.append(saved)
	func nf_register_summons() -> void:
		nf_ok = nf_ok and enemies.size() == 29 and enemies.all(func(actor): return nf_bindings.has(actor.id) and actor._summon_owner_id.is_empty())
	func _physics_process(delta: float) -> void:
		super._physics_process(delta)
		if oss_enabled and playing:
			oss_ticks += 1
			oss_ok = oss_ok and oss_current() and absf(delta-1.0/60.0) < 0.000001
			if oss_current(): oss_survey()
		if not nf_enabled or nf_completed: return
		nf_ok = nf_ok and nf_current() and absf(delta-1.0/60.0) < 0.000001
		if not nf_current(): return
		nf_ticks += 1
		if not Input.is_action_pressed("fire"): nf_slot = -1.0
		nf_register_summons()
		nf_survey()
		nf_sync_selection()
	func nf_sync_selection() -> void:
		nf_ok = nf_ok and state.weapon == 1 and nf_ledger.weapon == 1 and state.owned_weapons == [0,1,2,3]
	func nf_removed_matches() -> bool:
		var actual: Array = state.removed.duplicate()
		var expected: Array = nf_removed.duplicate()
		actual.sort()
		expected.sort()
		return actual == expected and expected.all(func(id): return expected.count(id) == 1)
	func shot(weapon: int) -> void:
		if nf_enabled:
			var tick: int = Engine.get_physics_frames()
			nf_slot = entry_slot(tick,nf_last_tick,nf_slot,weapon)
			nf_sync_selection()
			nf_ok = nf_ok and nf_current() and Engine.is_in_physics_frame() and h_stack("/player.gd","fire") and h_stack("/player.gd","_physics_process") and Input.is_action_pressed("fire") and weapon == 1 and weapon == state.weapon and not player._fire_release_required and player.shot_age(weapon) == 0.0 and nf_slot >= 0.0 and player.active_play_time > nf_last_time[weapon] and nf_shots.size() < NF_SHOTS
			nf_ledger.ammo[weapon] -= 1
			nf_shots.append([tick,player.active_play_time,weapon,player.cooldown])
			nf_last_time[weapon] = player.active_play_time
			nf_last_tick = tick
			nf_ok = nf_ok and nf_ledger.ammo[weapon] >= 0 and budget() == nf_ledger and player.cooldown > 0 and player.cooldown <= 0.21+0.000001
		super.shot(weapon)
	func collect_pickup(id: String) -> void:
		if not nf_enabled:
			super.collect_pickup(id)
			return
		var rows: Array = level.layout.data.pickups.filter(func(spec): return spec.id == id)
		if rows.size() != 1:
			nf_ok = false
			super.collect_pickup(id)
			return
		var spec: Dictionary = rows[0]
		var before: Dictionary = nf_ledger.duplicate(true)
		var expected: Dictionary = before.duplicate(true)
		var marker = level.markers.get(id)
		nf_ok = nf_ok and nf_current() and Engine.is_in_physics_frame() and budget() == before and h_stack("/main.gd","update_passive_triggers") and h_stack("/player.gd","_physics_process") and not nf_consumed.has(id) and is_instance_valid(marker) and marker == nf_markers[id].get_ref() and marker.get_parent() == level and not marker.is_queued_for_deletion() and player.position.distance_to(level.layout.world_position(spec.cell)) < 1.4 and _passive_trigger_visible(spec)
		if spec.kind in ["weapon","ammo"]:
			var index: int = int(spec.weapon)
			if spec.kind == "weapon" and not index in expected.owned_weapons:
				expected.owned_weapons.append(index)
				expected.weapon = index
			expected.ammo[index] = mini([0,180,32,240,24,120][index],int(expected.ammo[index])+int(spec.amount))
		elif spec.kind == "health": expected.health = mini(100,int(expected.health)+int(spec.amount))
		elif spec.kind == "armor": expected.armor = mini(200,int(expected.armor)+int(spec.amount))
		else: nf_ok = false
		super.collect_pickup(id)
		var granted: bool = expected != before
		nf_pickups.append([id,Engine.get_physics_frames(),before,expected.duplicate(true),granted])
		nf_ledger = expected
		if granted:
			nf_consumed[id] = 1
			nf_removed.append(id)
		nf_ok = nf_ok and budget() == expected and state.removed.count(id) == (1 if granted else 0) and (not level.markers.has(id) if granted else level.markers.get(id) == marker)
	func activate_encounter(id: String) -> void:
		if not nf_enabled or "encounter:"+id in state.removed:
			super.activate_encounter(id)
			return
		var rows: Array = level.layout.data.encounters.filter(func(spec): return spec.id == id)
		if rows.size() != 1:
			nf_ok = false
			return
		var spec: Dictionary = rows[0]
		var cell: Vector2 = Vector2(player.position.x,player.position.z)/4.0
		var region: Array = spec.region
		nf_ok = nf_ok and nf_current() and id == "nursery_finale" and not nf_activated.has(id) and h_stack("/main.gd","_process") and not h_stack("/enemy.gd","take_damage") and cell.is_equal_approx(cell.clamp(Vector2(region[0],region[1]),Vector2(region[2],region[3]))) and spec.requires.all(func(key): return key in nf_keys)
		super.activate_encounter(id)
		nf_activated[id] = [Engine.get_physics_frames(),cell,state.keys.duplicate()]
		nf_removed.append("encounter:"+id)
		for actor in enemies:
			if actor.id in spec.enemy_ids: nf_ok = nf_ok and nf_actor(actor) and actor.hp == actor.max_hp and actor.active and actor.alerted
		for light in spec.cue.light_ids:
			nf_ok = nf_ok and level.machine_lights.has(light) and level.machine_lights[light].light_color == Color(1.0,0.28,0.1)
	func enemy_event(actor, event: String) -> void:
		if nf_enabled:
			nf_ok = nf_ok and nf_current() and nf_actor(actor) and actor.active and Engine.is_in_physics_frame() and h_stack("/enemy.gd","_event")
			nf_events.append([actor.id,event,Engine.get_physics_frames(),actor.hp,actor._committed_variant,actor.phase])
			if event == "attack" and actor.kind == "nursery_warden":
				nf_ok = nf_ok and actor._committed_variant in [0,1] and actor.phase == (1 if actor.hp < actor.max_hp/2.0 else 0) and actor._committed_aim.is_finite() and h_stack("/enemy.gd","_release_attack")
				nf_boss_attacks.append([Engine.get_physics_frames(),actor._committed_variant,actor.phase,actor._committed_target.get_instance_id(),actor._committed_aim])
			if event == "attack" and actor.kind == "worker":
				var origin: Vector3 = actor.global_position+Vector3.UP*1.4
				var end: Vector3 = origin+(actor._committed_aim-origin).normalized()*30.0
				var query = PhysicsRayQueryParameters3D.create(origin,end,1|2|4)
				query.exclude = [actor.get_rid()]
				query.hit_from_inside = true
				nf_worker = {"source":actor,"tick":Engine.get_physics_frames(),"hit":level.get_world_3d().direct_space_state.intersect_ray(query)}
				var victim = nf_worker.hit.get("collider")
				if nf_actor(victim) and victim.hp > 0: nf_damage(victim,actor,10,(end-origin).normalized(),nf_worker.hit)
			if event == "melee_contact":
				nf_ok = nf_ok and actor._rush_hit and h_stack("/enemy.gd","_try_melee")
				if not nf_ok: return
				var intended = actor._committed_target
				var query = PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*0.6,intended.global_position+Vector3.UP*0.7,1|2|4)
				query.exclude = [actor.get_rid()]
				query.hit_from_inside = true
				nf_melee = {"source":actor,"tick":Engine.get_physics_frames(),"hit":level.get_world_3d().direct_space_state.intersect_ray(query)}
				var victim = nf_melee.hit.get("collider")
				if actor.kind == "nursery_warden": nf_charge_contacts.append([Engine.get_physics_frames(),actor.id,victim.get_instance_id() if is_instance_valid(victim) else 0,32,query.from,query.to,nf_melee.hit])
				if nf_actor(victim) and victim.hp > 0: nf_damage(victim,actor,32 if actor.kind == "nursery_warden" else 24 if actor.kind == "brute" else 12,(query.to-query.from).normalized(),nf_melee.hit)
			if event == "death":
				var source = nf_projectile_pending.source if not nf_projectile_pending.is_empty() and nf_projectile_pending.hit.get("collider") == actor else actor.target
				var mode: String = "unproven"
				if source == player and h_stack("/player.gd","fire") and h_stack("/enemy.gd","take_damage") and not nf_shots.is_empty() and nf_shots[-1][0] == Engine.get_physics_frames() and Input.is_action_pressed("fire") and aim_observation.get("level") == level and aim_observation.get("player") == player and aim_observation.get("actor_id","") == actor.id and aim_observation.get("tick",-1) == Engine.get_physics_frames(): mode = "player"
				elif nf_native_contact(actor,source): mode = "infighting"
				nf_deaths[actor.id] = nf_deaths.get(actor.id,0)+1
				nf_finishes[actor.id] = mode
				nf_removed.append(actor.id)
				nf_ok = nf_ok and mode != "unproven" and actor.hp == 0 and actor.collision_layer == 0 and actor.collision_mask == 0 and nf_deaths[actor.id] == 1 and state.removed.count(actor.id) == 1
		super.enemy_event(actor,event)
	func nf_native_contact(victim, source) -> bool:
		if not nf_actor(source): return false
		var tick: int = Engine.get_physics_frames()
		if not nf_projectile_pending.is_empty():
			var pending: Dictionary = nf_projectile_pending
			if pending.source == source and pending.tick == tick and pending.hit.collider == victim and pending.hit.rid == victim.get_rid() and h_stack("/projectile.gd","_physics_process"):
				nf_projectile_pending.clear()
				return true
		if source.hp <= 0 or not source.active: return false
		for field in ["nf_worker","nf_melee"]:
			var contact: Dictionary = get(field)
			if contact.get("source") == source and contact.get("tick",-1) == tick and contact.hit.get("collider") == victim and contact.hit.get("rid") == victim.get_rid() and h_stack("/enemy.gd","_attack") and h_stack("/enemy.gd","_release_attack" if source.kind == "worker" else "_try_melee"):
				set(field,{})
				return true
		return false
	func _debug_projectile_event(projectile: Node3D, event: String, data: Dictionary) -> void:
		if nf_enabled:
			var id: int = projectile.get_instance_id()
			var source = projectile.shooter
			nf_ok = nf_ok and nf_current() and OS.is_debug_build() and Engine.is_in_physics_frame() and nf_actor(source) and projectile.get_script() == preload("res://scripts/projectile.gd") and projectile.game == self and projectile._current_map() and projectile.get_parent() == level and projectile.is_physics_processing() and data.get("projectile") == projectile and data.get("source") == source and data.get("map") == level and data.get("player") == player and data.get("tick",-1) == Engine.get_physics_frames() and data.get("position") == projectile.global_position and data.get("velocity") == projectile.velocity and data.get("lifetime") == projectile.lifetime and projectile.blast_damage == 0 and projectile.velocity.is_finite() and is_equal_approx(projectile.velocity.length(),12.0) and projectile.lifetime > 0 and projectile.lifetime <= 4.0
			if event == "configured_birth":
				nf_ok = nf_ok and not nf_births.has(id) and source.hp > 0 and source.active and source.kind in ["caster","nursery_warden"] and h_stack("/enemy.gd","_release_attack") and (h_stack("/enemy.gd","_fire_pattern") if source.kind == "nursery_warden" else true) and h_stack("/projectile.gd","configure") and data.origin == source.global_position+Vector3.UP*(2.8 if source.kind == "nursery_warden" else 1.4) and data.origin == projectile.global_position and data.origin.is_finite() and data.destination.is_finite() and projectile.velocity.is_equal_approx((data.destination-data.origin).normalized()*12.0) and projectile.lifetime == 4.0
				nf_ok = nf_ok and nf_births.size() < 160
				if source.kind == "nursery_warden":
					var attack: Array = nf_boss_attacks[-1] if not nf_boss_attacks.is_empty() else []
					var count: int = 5 if source.phase > 0 else 3
					var index: int = nf_patterns.get(Engine.get_physics_frames(),0)
					var angle: float = (index-(count-1)/2.0)*0.13
					var aim: Vector3 = (source._committed_aim-data.origin).normalized()
					nf_ok = nf_ok and attack.size() == 5 and attack[0] == Engine.get_physics_frames() and attack[1] == 1 and index < count and data.destination.is_equal_approx(data.origin+aim.rotated(Vector3.UP,angle)*30)
					nf_patterns[Engine.get_physics_frames()] = index+1
				nf_births[id] = [weakref(projectile),source.get_instance_id(),Engine.get_physics_frames()]
			else:
				var hit: Dictionary = data.get("hit",{})
				var victim = hit.get("collider")
				nf_ok = nf_ok and event in ["queued_player_contact","queued_enemy_contact"] and nf_births.has(id) and not nf_contacts.has(id) and nf_births[id][0].get_ref() == projectile and nf_births[id][1] == source.get_instance_id() and Engine.get_physics_frames()-int(nf_births[id][2]) <= 241 and projectile.is_queued_for_deletion() and h_stack("/projectile.gd","_physics_process") and (victim == player if event == "queued_player_contact" else nf_actor(victim) and victim.hp > 0 and victim != source) and hit.get("rid") == victim.get_rid() and data.ray_start.is_finite() and data.ray_end.is_equal_approx(data.ray_start+projectile.velocity*minf(1.0/60.0,projectile.lifetime))
				var query = PhysicsRayQueryParameters3D.create(data.ray_start,data.ray_end,1|2|4)
				query.exclude = [source.get_rid()]
				query.hit_from_inside = true
				nf_ok = nf_ok and level.get_world_3d().direct_space_state.intersect_ray(query) == hit
				nf_contacts[id] = [event,source.id,victim.get_instance_id(),Engine.get_physics_frames(),hit.position]
				if victim != player: nf_damage(victim,source,14,projectile.velocity.normalized(),hit)
				if victim == player or nf_hp.get(victim.id,1) == 0:
					nf_ok = nf_ok and nf_projectile_pending.is_empty()
					nf_projectile_pending = {"id":id,"source":source,"tick":Engine.get_physics_frames(),"hit":hit,"projectile":projectile}
		super._debug_projectile_event(projectile,event,data)
	func hurt_player(amount: int) -> void:
		if nf_enabled:
			var source = null
			if not nf_projectile_pending.is_empty(): source = nf_projectile_pending.source
			else:
				for contact in [nf_worker,nf_melee]:
					if contact.get("tick",-1) == Engine.get_physics_frames() and contact.hit.get("collider") == player: source = contact.source

			var expected_amount: int = 14 if h_stack("/projectile.gd","_physics_process") else 32 if is_instance_valid(source) and source.kind == "nursery_warden" else 10 if is_instance_valid(source) and source.kind == "worker" else 24 if is_instance_valid(source) and source.kind == "brute" else 12
			nf_ok = nf_ok and nf_current() and Engine.is_in_physics_frame() and budget() == nf_ledger and amount == expected_amount and state.difficulty == 1 and nf_native_contact(player,source)
			var absorbed: int = mini(int(nf_ledger.armor),int(amount/3))
			nf_ledger.armor -= absorbed
			nf_ledger.health = maxi(0,int(nf_ledger.health)-amount+absorbed)
			nf_hurts.append([Engine.get_physics_frames(),source.id if is_instance_valid(source) else "unproven",amount,absorbed])
		super.hurt_player(amount)
		if nf_enabled: nf_ok = nf_ok and budget() == nf_ledger
	func interact() -> void:
		if not nf_enabled:
			super.interact()
			return
		var spec: Dictionary = nearest_interaction()
		nf_ok = nf_ok and nf_current() and Engine.is_in_physics_frame() and Input.is_action_pressed("interact") and h_stack("/player.gd","_physics_process") and spec.get("id","") == nf_intent and spec in [NF_STORY,NF_DOOR,NF_DESCENT]
		nf_inputs.append([spec.get("id",""),Engine.get_physics_frames(),player.position,player.rotation.y,player.camera.rotation.x])
		if spec == NF_DESCENT: nf_ok = nf_ok and nf_all_dead() and nf_exit_expected == nf_handoff()
		super.interact()
		if spec == NF_STORY:
			nf_removed.append(NF_STORY.id)
			nf_ok = nf_ok and state.discoveries == [3,4] and state.removed.count(NF_STORY.id) == 1 and not level.markers.has(NF_STORY.id) and budget() == nf_ledger
		if spec == NF_DESCENT: nf_completed = state.level_index == 5 and not playing and level == null and player == null and nf_exit_saves == 1
	func collect_key(id: String) -> void:
		if nf_enabled: nf_ok = false
		super.collect_key(id)
	var nf_actor_image: Array = []
	var nf_checkpoint: Dictionary = {}
	var nf_saved_sha: String = ""
	var nf_save_docs: Array = []
	func nf_records() -> Array:
		var records: Array = []
		for actor in enemies:
			if actor.hp <= 0: continue
			var yaw: float = actor.rotation.y
			if yaw < -PI or yaw >= PI: yaw = wrapf(yaw,-PI,PI)
			yaw = Vector3(0,clampf(yaw,-3.1415925,3.1415925),0).y
			records.append({"id":actor.id,"hp":actor.hp,"position":[actor.position.x,actor.position.y,actor.position.z],"yaw":yaw,"alerted":actor.alerted})
		return records
	func _capture_actor_state() -> bool:
		if oss_enabled: return oss_capture()
		if not nf_enabled: return super._capture_actor_state()
		nf_capture_calls += 1
		if state.level_index == 5:
			nf_ok = nf_ok and nf_intent == NF_DESCENT.id and h_stack("/main.gd","interact") and state.to_dict() == nf_exit_expected and _scene_level_index == 4
			var result: bool = super._capture_actor_state()
			nf_ok = nf_ok and result and state.to_dict() == nf_exit_expected
			return result
		var passive: bool = h_stack("/main.gd","update_passive_triggers")
		nf_ok = nf_ok and nf_current() and Engine.is_in_physics_frame() and h_stack("/player.gd","_physics_process") and (passive or nf_intent == NF_DESCENT.id and nf_all_dead())
		if passive and not NF_CHECKPOINT.id in nf_removed:
			nf_ok = nf_ok and nf_checkpoint_saves == 0 and state.removed.count(NF_CHECKPOINT.id) == 1 and player.position.distance_to(level.layout.world_position(NF_CHECKPOINT.cell)) < 3.2 and _passive_trigger_visible(NF_CHECKPOINT)
			nf_removed.append(NF_CHECKPOINT.id)
		var expected: Array = nf_records()
		var result: bool = super._capture_actor_state()
		nf_actor_image = expected
		nf_ok = nf_ok and result and state.actors == expected and state.yaw == Enemy.canonical_yaw(player.rotation.y) and state.pitch == clampf(player.camera.rotation.x,-1.35,1.35)
		return result
	func _capture_game_mouse() -> void:
		if oss_enabled:
			oss_mouse_attempts.append([Engine.get_physics_frames(),state.level_index,placement_pending,playing])
			oss_ok = oss_ok and oss_current() and h_stack("/main.gd","start_level")
		if nf_enabled: nf_mouse_attempts.append([Engine.get_physics_frames(),state.level_index,placement_pending,playing])
		super._capture_game_mouse()
	func _save() -> Error:
		if not nf_enabled: return super._save()
		nf_save_calls += 1
		var checkpoint_save: bool = state.level_index == 4
		var expected: Dictionary
		if checkpoint_save:
			nf_ok = nf_ok and nf_current() and nf_checkpoint_saves == 0 and h_stack("/main.gd","update_passive_triggers") and state.checkpoint_id == NF_CHECKPOINT.id
			nf_checkpoint = nf_ledger.duplicate(true)
			nf_checkpoint.merge({"keys":nf_keys.duplicate(),"removed":nf_removed.duplicate(),"checkpoint_id":NF_CHECKPOINT.id,"position":[player.position.x,player.position.y,player.position.z],"actors":nf_records(),"yaw":state.yaw,"pitch":state.pitch},true)
			expected = nf_checkpoint.duplicate(true)
			expected.merge({"version":1,"difficulty":1,"level_index":4,"discoveries":[3,4],"explored":nf_explored.duplicate(true),"checkpoint":nf_checkpoint.duplicate(true),"level_start":nf_start.duplicate(true)},true)
		else:
			nf_ok = nf_ok and state.level_index == 5 and nf_exit_saves == 0 and nf_intent == NF_DESCENT.id and Engine.is_in_physics_frame() and Input.is_action_pressed("interact") and h_stack("/main.gd","interact")
			expected = nf_handoff()
			nf_ok = nf_ok and nf_exit_expected == expected
		var result: Error = super._save()
		var saved = Campaign.new()
		nf_ok = nf_ok and result == OK and saved.load_progress(progress_path) and saved.to_dict() == expected and state.to_dict() == expected
		nf_saved_sha = FileAccess.get_sha256(progress_path)
		nf_save_docs.append(expected.duplicate(true))
		if checkpoint_save: nf_checkpoint_saves += 1
		else: nf_exit_saves += 1
		return result
	var nf_hp: Dictionary = {}
	var nf_damage_events: Array = []
	func nf_damage(victim, source, amount: int, direction: Vector3, hit: Dictionary) -> void:
		nf_ok = nf_ok and nf_current() and nf_actor(victim) and victim.hp > 0 and nf_hp.get(victim.id,-1) == victim.hp and Engine.is_in_physics_frame() and hit.get("collider") == victim and hit.get("rid") == victim.get_rid() and direction.is_finite() and is_equal_approx(direction.length(),1.0)
		var applied: int = amount
		nf_damage_events.append([Engine.get_physics_frames(),victim.id,source.get_instance_id(),amount,applied,victim.hp,hit.position,hit.rid])
		nf_hp[victim.id] = maxi(0,victim.hp-applied)
	func resolve_aim(origin: Vector3, direction: Vector3, max_range: float, melee: bool = false) -> Dictionary:
		var result: Dictionary = super.resolve_aim(origin,direction,max_range,melee)
		if not nf_enabled or not h_stack("/player.gd","fire"): return result
		nf_ok = nf_ok and nf_current() and h_stack("/player.gd","fire") and h_stack("/player.gd","_physics_process") and Input.is_action_pressed("fire") and state.weapon == 1 and not melee and max_range == 140.0 and not nf_shots.is_empty() and nf_shots[-1][0] == Engine.get_physics_frames()
		var query = PhysicsRayQueryParameters3D.create(origin,origin+result.direction*max_range,1|4)
		query.exclude = [player.get_rid()]
		var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(query)
		nf_ok = nf_ok and result.contact == hit
		var victim = hit.get("collider")
		if nf_actor(victim) and victim.hp > 0: nf_damage(victim,player,22,result.direction,hit)
		return result

	var nf_intent: String = ""
	var nf_gate_calls: int = 0
	var nf_checkpoint_saves: int = 0
	var nf_exit_saves: int = 0
	var nf_exit_expected: Dictionary = {}
	var nf_completed: bool = false
	var nf_boss_attacks: Array = []
	var nf_charge_contacts: Array = []
	var nf_patterns: Dictionary = {}
	var nf_flights: Dictionary = {}
	var nf_flight_steps: int = 0
	func nf_all_dead() -> bool:
		return enemies.size() == 29 and enemies.all(func(actor): return nf_actor(actor) and actor.hp == 0 and actor.collision_layer == 0 and actor.collision_mask == 0 and state.removed.count(actor.id) == 1) and NF_IDS.all(func(id): return nf_deaths.get(id,0) == 1 and nf_finishes.get(id,"") in ["player","infighting"]) and nf_deaths.size() == 7 and nf_activated.keys() == ["nursery_finale"]
	func nf_handoff() -> Dictionary:
		var resources: Dictionary = nf_ledger.duplicate(true)
		resources.merge({"keys":[],"removed":[],"checkpoint_id":"entry","position":[0.0,0.0,0.0]},true)
		var document: Dictionary = resources.duplicate(true)
		document.merge({"version":1,"difficulty":1,"level_index":5,"discoveries":[3,4],"explored":[],"checkpoint":resources.duplicate(true),"level_start":resources.duplicate(true)},true)
		return document
	func unlock_door(id: String) -> bool:
		if not nf_enabled: return super.unlock_door(id)
		nf_ok = nf_ok and nf_current() and id == NF_DOOR.id and nf_intent == id and nf_gate_calls == 0 and nf_checkpoint_saves == 1 and nf_keys == ["blood","ivory"] and Engine.is_in_physics_frame() and Input.is_action_pressed("interact") and h_stack("/player.gd","_physics_process") and h_stack("/main.gd","interact") and level.layout.data.doors == [NF_DOOR]
		var result: bool = super.unlock_door(id)
		nf_gate_calls += 1
		nf_removed.append(id)
		nf_ok = nf_ok and result and not level.doors.has(id) and nf_removed_matches() and budget() == nf_ledger
		return result

	var oss_enabled: bool = false
	var oss_ok: bool = true
	var oss_start_calls: int = 0
	var oss_captures: int = 0
	var oss_mouse_attempts: Array = []
	var oss_bindings: Dictionary = {}
	var oss_level_id: int = 0
	var oss_player_id: int = 0
	var oss_ticks: int = 0
	var oss_explored: Array = []
	var oss_last_cell: Vector2i = Vector2i(-1,-1)
	func oss_current() -> bool:
		return oss_enabled and playing and not get_tree().paused and not placement_pending and not loaded_positions and state.level_index == 5 and _scene_level_index == 5 and is_instance_valid(level) and not level.is_queued_for_deletion() and level.get_instance_id() == oss_level_id and is_instance_valid(player) and not player.is_queued_for_deletion() and player.get_parent() == level and player.get_instance_id() == oss_player_id
	func oss_originals() -> Array:
		var records: Array = []
		for spec in NF_O_ACTORS:
			var point: Vector3 = Vector3(spec[2]*4.0,spec[4],spec[3]*4.0)+Vector3.UP*0.03
			if spec[1] == "caster": point.y += 1.0
			records.append({"id":spec[0],"hp":N_ROLES[spec[1]][0],"position":[point.x,point.y,point.z],"yaw":e_yaw(Vector3(0,deg_to_rad(spec[5]),0).y),"alerted":false})
		return records
	func oss_start() -> Dictionary:
		var resources: Dictionary = nf_ledger.duplicate(true)
		resources.merge({"keys":[],"removed":[],"checkpoint_id":"entry","position":[142.0,0.0,98.0],"actors":oss_originals(),"yaw":Vector3(0,deg_to_rad(90),0).y,"pitch":0.0},true)
		return resources
	func oss_document() -> Dictionary:
		var document: Dictionary = oss_start()
		document.merge({"version":1,"difficulty":1,"level_index":5,"discoveries":[3,4],"explored":[],"checkpoint":oss_start(),"level_start":oss_start()},true)
		return document
	func start_level() -> void:
		if not oss_enabled:
			await super.start_level()
			return
		oss_start_calls += 1
		oss_ok = oss_ok and oss_start_calls == 1 and state.to_dict() == nf_exit_expected and not playing and not placement_pending and not loaded_positions and level == null and player == null and get_tree().paused
		await super.start_level()
		oss_ok = oss_ok and oss_current() and state.to_dict() == oss_document()
	func oss_capture() -> bool:
		oss_captures += 1
		oss_ok = oss_ok and oss_captures == 1 and not nf_enabled and not playing and not placement_pending and not loaded_positions and h_stack("/main.gd","start_level") and level.get_script() == Level and player.get_script() == Player and player.position == Vector3(142,0.04,98) and player.rotation.y == Vector3(0,deg_to_rad(90),0).y and player.camera.rotation.x == 0.0 and enemies.size() == NF_O_ACTORS.size()
		oss_level_id = level.get_instance_id()
		oss_player_id = player.get_instance_id()
		var expected: Array = oss_originals()
		for index in range(enemies.size()):
			if index >= NF_O_ACTORS.size():
				oss_ok = false
				continue
			var actor = enemies[index]
			var spec: Array = NF_O_ACTORS[index]
			var record: Dictionary = expected[index]
			var capsule: CollisionShape3D = actor.get_child(0)
			oss_ok = oss_ok and actor.get_script() == Enemy and actor.id == spec[0] and actor.kind == spec[1] and actor.hp == record.hp and actor.max_hp == record.hp and actor.position == Vector3(record.position[0],record.position[1],record.position[2]) and actor.rotation.y == Vector3(0,deg_to_rad(spec[5]),0).y and actor.age == 0.0 and actor.encounter_id == spec[6] and not actor.active and not actor.alerted and actor._current_map() and actor.get_parent() == level and actor.collision_layer == 4 and actor.collision_mask == 7 and not actor.get_instance_id() in nf_bindings.values().map(func(binding): return binding[0]) and not capsule.disabled and capsule.shape is CapsuleShape3D and absf(capsule.shape.radius-N_ROLES[spec[1]][1]) < 0.000001 and absf(capsule.shape.height-N_ROLES[spec[1]][2]) < 0.000001 and capsule.position == Vector3(0,capsule.shape.height/2,0)
			oss_bindings[actor.id] = [actor.get_instance_id(),capsule.get_instance_id(),capsule.shape.get_instance_id()]
		var result: bool = super._capture_actor_state()
		oss_ok = oss_ok and result and state.actors == expected
		return result
	func oss_survey() -> void:
		var cell: Vector2i = Vector2i((Vector2(player.position.x,player.position.z)/4.0).floor())
		if cell == oss_last_cell: return
		oss_last_cell = cell
		for x in range(cell.x-2,cell.x+3):
			for z in range(cell.y-2,cell.y+3):
				var point: Vector2i = Vector2i(x,z)
				if not level.layout.is_walkable(point): continue
				var end: Vector3 = level.layout.world_position([x+0.5,z+0.5])+Vector3.UP*1.55
				if point == cell or level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(player.camera.global_position,end,1)).is_empty(): oss_explored.append([x,z])

var nf_started: bool = false
var nf_epoch: int = 0
var nf_wall: int = 0
var nf_fields: Array = []
var nf_frozen: Dictionary = {}
var nf_originals: Dictionary = {}
var nf_waypoints: Array = []
var nf_gate_ref
var nf_retired: Array = []
var nf_marker_refs: Dictionary = {}
var nf_entry_fields: Array = []
var nf_entry_frozen: Dictionary = {}
var nf_entry_epoch: int = 0
var nf_entry_wall: int = 0
var nf_egress: Array = []
var nf_battle_corner: int = -1

func run() -> void:
	if "--nursery-finale-pin-rejection" in OS.get_cmdline_user_args():
		await nursery_finale_pin_rejection()
		return
	var ok: bool = await walk_through_nursery_finale(NurseryFinaleMain.new())
	if ok: print("PASS SAME earned Nursery finale and nonquitting Ossuary handoff; synthetic native input only when executed, not app/campaign/performance/listening acceptance.")
	await finish(0 if ok else 1)

static func finale_outcome_matches(attacks: Array, shot_count: int, resources: Dictionary, actual_save_sha: String) -> bool:
	return [[0,0],[1,0],[0,1],[1,1]].all(func(pair): return attacks.any(func(attack): return attack[1] == pair[0] and attack[2] == pair[1])) and shot_count == 81 and resources == NF_RESULT_RESOURCES and actual_save_sha == NF_RESULT_SAVE_SHA

func finale_pins_match() -> bool:
	return FileAccess.get_sha256("res://tests/test_nursery_seed_loop.gd") == NF_SEED_SHA and FileAccess.get_sha256("res://tests/test_nursery_earned_campaign.gd") == NS_CAMPAIGN_SHA and FileAccess.get_sha256("res://tests/test_nursery_earned_entry.gd") == NC_ENTRY_SHA and FileAccess.get_sha256("res://data/05_nursery.json") == N_MAP_SHA and FileAccess.get_sha256("res://data/06_ossuary.json") == NF_OSSUARY_SHA and NC_CORE_PINS.keys().all(func(path): return FileAccess.get_sha256(path) == NC_CORE_PINS[path])

func walk_through_nursery_finale(observer: NurseryFinaleMain, profile_prefix: String = "") -> bool:
	if not expect(finale_pins_match(),"Exact provisional seed, accepted ancestor/current core and original fifth/sixth maps BEFORE observer/profile adoption"):
		if is_instance_valid(observer) and observer != game and observer.get_parent() == null and not observer.is_inside_tree(): observer.free()
		return false
	var fixture: String = profile_prefix if not profile_prefix.is_empty() else "user://reliquary_catalogue_exit_nursery_finale_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	if not await walk_through_nursery_seeds(observer,fixture): return false
	if not expect(finale_pins_match() and game.ns_ok and game.ns_enabled and game.budget() == NF_CARRY and game.nc_deaths.size() == 11 and game.ns_deaths.size() == 11 and game.ns_summons.is_empty() and game.nc_summons.is_empty() and game.ns_saved_sha == NF_ANCESTOR_SAVE_SHA and FileAccess.get_sha256(r_profile) == NF_ANCESTOR_SAVE_SHA,"Actual pinned same four-map/two-loop seed boundary; exact earned78/194/163/32/60 and22 original deaths"): return false
	var actual: Array = game.get_property_list().filter(func(property): return str(property.name).begins_with("ns_") and property.name != "ns_enabled").map(func(property): return property.name)
	actual.sort()
	var declared: Array = NF_NS_FIELDS.duplicate()
	declared.sort()
	if not expect(actual == declared,"Freeze EVERY declared/reflected seed field, including HP/damage/recovery/save observers"): return false
	nf_fields = ns_frozen_fields+NF_NS_FIELDS
	nf_frozen = observer_witness(nf_fields)
	for name in ["ledger","keys","removed","consumed","bindings","explored","last_cell","start","checkpoint","actor_image","saved_sha","births","contacts","hp","last_time","last_tick"]:
		var value = game.get("ns_"+name)
		game.set("nf_"+name,value.duplicate(true) if value is Array or value is Dictionary else value)
	for actor in game.enemies: nf_originals[actor.id] = [actor.position,actor.rotation.y,actor.age,actor.max_hp,actor.kind,actor.encounter_id,actor.hp]
	for id in route_level.markers: game.nf_markers[id] = weakref(route_level.markers[id])
	nf_gate_ref = weakref(route_level.doors[NF_DOOR.id])
	nf_marker_refs = game.nf_markers.duplicate()
	release_actions()
	game.ns_enabled = false
	nf_epoch = Engine.get_physics_frames()
	nf_wall = Time.get_ticks_usec()
	nf_started = true
	game.nf_enabled = true
	if not expect(route_level.layout.data.interactions.filter(func(spec): return spec.id in [NF_STORY.id,NF_CHECKPOINT.id,NF_DESCENT.id]) == [NF_CHECKPOINT,NF_STORY,NF_DESCENT] and route_level.layout.data.doors == [NF_DOOR] and InputMap.action_get_events("interact").any(func(event): return event is InputEventKey and event.physical_keycode == KEY_E),"Exact optional story/checkpoint/two-key boss exit schema and actual physical E binding"): return false
	if not await nursery_finale_route(NF_STORY_ROUTE) or not await nursery_finale_input(NF_STORY,"--omit-nursery-finale-story"): return false
	if not await nursery_finale_route(NF_SUPPLIES) or not await nursery_finale_gate(): return false
	if not await nursery_finale_route(NF_APPROACH) or not await nursery_finale_battle() or not await nursery_finale_egress(): return false
	for frame in range(NF_DRAIN):
		if not await route_tick(): return false
		await process_frame
	if not await nursery_finale_route(NF_CLOSE) or not nursery_finale_earned(): return false
	if not await nursery_finale_completion(): return false
	return await nursery_finale_ossuary()

func nursery_finale_pin_rejection() -> void:
	if not expect(not finale_pins_match(),"Control requires deliberate parent-owned single dependency pin mismatch"):
		await finish(1)
		return
	var fixture: String = "user://reliquary_catalogue_exit_nursery_finale_pin_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	var suffixes: Array = ["_campaign.json","_campaign.json.tmp","_preferences.json","_preferences.json.tmp"]
	if not expect(suffixes.all(func(suffix): return not FileAccess.file_exists(fixture+suffix)),"Fresh unique wrong-pin control namespace"):
		quit(1)
		return
	var observer = NurseryFinaleMain.new()
	var reference = weakref(observer)
	var result: bool = await walk_through_nursery_finale(observer,fixture)
	var ok: bool = expect(not result and reference.get_ref() == null and game == null and root.get_child_count() == 0 and suffixes.all(func(suffix): return not FileAccess.file_exists(fixture+suffix)),"Wrong pin frees only detached observer before any Main/profile adoption")
	prefix = fixture
	await finish(0 if ok else 1)

func nursery_finale_key(pressed: bool) -> void:
	var event = InputEventKey.new()
	event.physical_keycode = KEY_E
	event.keycode = KEY_E
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func nursery_finale_input(spec: Dictionary, omit: String) -> bool:
	if not live_route(): return false
	aim_interaction(spec.cell,NF_DOOR.size[1]/2.0 if spec == NF_DOOR else 0.7)
	game.nf_intent = spec.id
	var count: int = game.nf_inputs.size()
	if not omit in OS.get_cmdline_user_args(): nursery_finale_key(true)
	for frame in range(NF_INPUT):
		if not await route_tick(): return false
		if game.nf_inputs.size() > count: break
	nursery_finale_key(false)
	release_actions()
	game.nf_intent = ""
	await process_frame
	return live_route() and expect(game.nf_inputs.size() == count+1 and game.nf_inputs[-1][0] == spec.id,"NATIVE RED one queued physical E is consumed by original production Player: "+spec.id)

func nursery_finale_gate() -> bool:
	var revision: int = route_level.get_node("NavigationRoutes").revision
	if not await nursery_finale_input(NF_DOOR,"--omit-nursery-finale-gate"): return false
	if not expect(game.nf_gate_calls == 1 and game.nf_checkpoint_saves == 1 and is_instance_valid(nf_gate_ref.get_ref()) and nf_gate_ref.get_ref().collision_layer == 0 and not route_level.doors.has(NF_DOOR.id) and route_level.get_node("NavigationRoutes").revision > revision,NF_GATE_GUARD): return false
	for frame in range(NF_GATE_WAIT):
		if not await route_tick(): return false
		await process_frame
	return expect(nf_gate_ref.get_ref() == null,"Original growthgate tween/body drained within60 real physics waits")

func nursery_finale_fire() -> bool:
	if game.nf_shots.size() >= NF_SHOTS: return false
	# Pure inherited aim/input helper reads frozen original actor bindings, never its retired ledger.
	return nursery_seed_fire()

func nursery_finale_move(target: Vector3) -> void:
	var direction: Vector3 = target-route_player.position
	direction.y = 0
	var deadzone: float = 0.0
	for action in ["move_left","move_right","move_forward","move_back"]: deadzone += InputMap.action_get_deadzone(action)/4.0
	var axes: Vector3 = route_player.basis.inverse()*direction.normalized()*(deadzone+(1.0-deadzone)*minf(1.0,direction.length()*6.0/9.0))
	for action in [["move_right",axes.x],["move_left",-axes.x],["move_back",axes.z],["move_forward",-axes.z]]: Input.action_press(action[0],maxf(0,action[1]))

func nursery_finale_route(cells: Array) -> bool:
	for cell in cells:
		var target: Vector3 = route_level.layout.world_position(cell)+Vector3.UP*0.04
		var began: int = Engine.get_physics_frames()
		var arrived: bool = false
		for frame in range(NF_HOP):
			if not live_route(): return false
			var start: Vector3 = route_player.position
			var clear: bool = clear_point(cell) != null
			var samples: int = ceili(start.distance_to(target)/0.5)
			for sample in range(samples+1):
				var point: Vector3 = start.lerp(target,float(sample)/maxi(1,samples))
				if clear_point([point.x/4,point.z/4]) == null: clear = false
				if sample > 0:
					var prior: Vector3 = start.lerp(target,float(sample-1)/maxi(1,samples))
					if not nursery_seed_sweep([prior.x/4,prior.z/4],[point.x/4,point.z/4]): clear = false
			release_actions()
			if not clear:
				if not expect(nursery_finale_fire(),"Blocked earned route needs a finite visible active original actor, never idle navigation"): return false
			else:
				if Vector2(start.x-target.x,start.z-target.z).length() <= 0.12:
					arrived = true
					break
				if not nursery_finale_fire(): route_player.look_at(Vector3(target.x,route_player.position.y,target.z),Vector3.UP)
				nursery_finale_move(target)
			if not await route_tick(): return false
		if not expect(arrived and Engine.get_physics_frames()-began+12 < NF_HOP,"Finite new-only route leg and settling cap: "+str(cell)): return false
		release_actions()
		for frame in range(12):
			nursery_finale_fire()
			if not await route_tick(): return false
		release_actions()
		await process_frame
		if not live_route() or not expect(route_player.position.distance_to(target) < 0.2 and clear_point(cell) != null,"Actual native settled finale waypoint: "+str(cell)): return false
		nf_waypoints.append(cell.duplicate())
		print("NURSERY_FINALE_HOP cell=",cell," frame=",Engine.get_physics_frames()-nf_epoch," resources=",game.nf_ledger)
	return true

func nursery_finale_battle() -> bool:
	if not expect(game.nf_activated.keys() == ["nursery_finale"] and game.enemies.filter(func(actor): return actor.encounter_id == "nursery_finale").map(func(actor): return actor.id) == NF_IDS,"Actual both-key growthgate region activates only seven original finale actors"): return false
	var corner: int = 0
	for frame in range(NF_FIGHT):
		if not live_route(): return false
		if game.nf_all_dead():
			release_actions()
			nf_battle_corner = corner
			return true
		release_actions()
		var visible: bool = nursery_finale_fire()
		var target: Vector3 = route_level.layout.world_position(NF_BATTLE[corner])
		if Vector2(route_player.position.x-target.x,route_player.position.z-target.z).length() < 1.0: corner = (corner+1)%NF_BATTLE.size()
		if not visible: route_player.look_at(Vector3(target.x,route_player.position.y,target.z),Vector3.UP)
		nursery_finale_move(target)
		if not expect(game.state.ammo[1] > 0 and game.nf_shots.size() < NF_SHOTS,"Finite owned pistol battle,110-shot ceiling without grant/refill/restart"): return false
		if not await route_tick(): return false
	release_actions()
	return expect(false,"New-only3600-frame native moving finale fight cap")

func finale_prior_frozen() -> bool:
	return observer_witness(nf_fields) == nf_frozen and not game.ns_enabled and not game.nc_enabled and not game.n_enabled and not game.e_enabled and observers_retired() and ns_waypoints == NS_APPROACH+NS_SEEDS+NS_RETURN+NS_JUNCTION and e_retired.all(func(ref): return ref.get_ref() == null) and e_markers.values().all(func(ref): return ref.get_ref() == null) and retired.all(func(ref): return ref.get_ref() == null) and x_marker_refs.values().all(func(ref): return ref.get_ref() == null)

func live_route() -> bool:
	if not nf_started: return super.live_route()
	if not expect(Engine.get_physics_frames()-nf_epoch <= NF_LIMIT and Time.get_ticks_usec()-nf_wall <= NF_SECONDS*1000000,"New-only9000-frame/300s cap; all ancestor bounds unchanged"): return false
	if not expect(game.nf_ok and game.nf_current() and game.get_instance_id() == r_main_id and game.state.get_instance_id() == r_campaign_id and game.progress_path == r_profile and game.settings_path == game.r_settings_origin and game.level == route_level and game.player == route_player and game.is_processing() and game.is_physics_processing() and route_player.is_physics_processing() and route_player._current_map() and route_player.position.is_finite() and game.state.health > 0 and game.state.difficulty == 1,"Same earned Main/Campaign/profile/native Player; live current-map/processing/cancellation fences"): return false
	if not expect(finale_prior_frozen(),"Every retired prior observer value and original drained scene/marker identity remains frozen"): return false
	game.nf_register_summons()
	game.nf_sync_selection()
	var children: Array = route_level.get_children().filter(func(node): return node.get_script() == game.Enemy).map(func(node): return node.get_instance_id())
	var bound: Array = game.nf_bindings.values().map(func(record): return record[0])
	children.sort()
	bound.sort()
	if not expect(children == bound and bound.size() == 29 and game.enemies.size() == 29,"Exact29 original native actor instances; no replacement/born actors"): return false
	for actor in game.enemies:
		var capsule: CollisionShape3D = actor.get_child(0)
		var binding: Array = game.nf_bindings[actor.id]
		var original: Array = nf_originals[actor.id]
		if not expect(game.nf_actor(actor) and actor.is_physics_processing() and capsule.get_instance_id() == binding[1] and capsule.shape.get_instance_id() == binding[2] and not capsule.disabled and capsule.shape is CapsuleShape3D and absf(capsule.shape.radius-N_ROLES[actor.kind][1]) < 0.000001 and absf(capsule.shape.height-N_ROLES[actor.kind][2]) < 0.000001 and capsule.position == Vector3(0,capsule.shape.height/2,0) and actor.position.is_finite() and is_finite(actor.rotation.y) and actor.hp >= 0 and actor.hp == game.nf_hp.get(actor.id,-1) and actor.max_hp == original[3] and actor.kind == original[4] and actor.encounter_id == original[5] and actor.age-original[2] >= float(Engine.get_physics_frames()-nf_epoch-2)/60.0,"Original native actor/HP/capsule/processing/age: "+actor.id): return false
		if original[6] == 0:
			if not expect(actor.hp == 0 and actor.position == original[0] and actor.rotation.y == original[1] and (game.nc_deaths.get(actor.id,0) == 1 or game.ns_deaths.get(actor.id,0) == 1),"Accepted22 original corpses remain unchanged: "+actor.id): return false
		elif not game.nf_activated.has(actor.encounter_id):
			if not expect(actor.hp == actor.max_hp and actor.position == original[0] and actor.rotation.y == original[1] and not actor.active and not actor.alerted,"Original seven finale actors remain fullHP/dormant until actual region"): return false
		if actor.hp > 0:
			var floor_hit: Dictionary = route_level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(actor.position+Vector3.UP*0.5,actor.position-Vector3.UP*6,1))
			if not expect(actor.collision_layer == 4 and actor.collision_mask == 7 and not floor_hit.is_empty() and floor_hit.normal.y >= 0.7 and absf(actor.position.y-floor_hit.position.y-(1.0 if actor.kind == "caster" else 0.0)) <= (0.25 if actor.kind == "caster" else 0.15),"Native living capsule collision/floor: "+actor.id): return false
		else:
			if not expect(actor.collision_layer == 0 and actor.collision_mask == 0 and game.state.removed.count(actor.id) == 1 and (original[6] == 0 or game.nf_deaths.get(actor.id,0) == 1 and game.nf_finishes.get(actor.id,"") in ["player","infighting"]),"Once-only genuine native death and collision retirement: "+actor.id): return false
	for id in game.nf_markers:
		if id in game.nf_removed and id != NF_CHECKPOINT.id:
			if not expect(not route_level.markers.has(id),"Earned original marker retirement: "+id): return false
		elif not expect(route_level.markers.get(id) == game.nf_markers[id].get_ref() and is_instance_valid(game.nf_markers[id].get_ref()) and not game.nf_markers[id].get_ref().is_queued_for_deletion(),"Unclaimed/checkpoint original marker remains: "+id): return false
	for node in route_level.get_children():
		if node.get_script() != preload("res://scripts/projectile.gd") or node.is_queued_for_deletion(): continue
		var id: int = node.get_instance_id()
		if not expect(game.nf_births.has(id) and game.nf_births[id][0].get_ref() == node and game.nf_actor(node.shooter) and node._current_map() and node.is_physics_processing() and node.lifetime > 0 and node.lifetime <= 4.0,"Native finite projectile retains actual birth and current original shooter"): return false
		if node.shooter.kind == "nursery_warden":
			var prior: Array = game.nf_flights.get(id,[])
			if not prior.is_empty() and Engine.get_physics_frames() > prior[2] and node.global_position.distance_to(prior[0]) > 0.001 and node.lifetime < prior[1]: game.nf_flight_steps += 1
			game.nf_flights[id] = [node.global_position,node.lifetime,Engine.get_physics_frames()]
	var capsule: CollisionShape3D = route_player.get_child(0)
	var support: Dictionary = route_level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(route_player.position+Vector3.UP*0.5,route_player.position-Vector3.UP*0.5,1))
	if not expect(not capsule.disabled and capsule.shape is CapsuleShape3D and capsule.shape.radius == Vector3(0.32,0,0).x and capsule.shape.height == Vector3(1.65,0,0).x and capsule.position == Vector3(0,0.85,0) and route_player.collision_layer == 2 and route_player.collision_mask == 5 and not support.is_empty() and support.normal.y >= 0.7 and absf(route_player.position.y-support.position.y) <= 0.15,"Production Player capsule and actual native supporting floor"): return false
	return expect(game.nf_ok and game.budget() == game.nf_ledger and game.state.keys == game.nf_keys and game.nf_removed_matches() and game.state.explored == game.nf_explored and game.state.discoveries == ([3,4] if NF_STORY.id in game.nf_removed else [3]) and game.state.checkpoint_id == game.nf_checkpoint.checkpoint_id and game.state.checkpoint == game.nf_checkpoint and game.state.level_start == game.nf_start and game.state.actors == game.nf_actor_image and FileAccess.get_sha256(r_profile) == game.nf_saved_sha and game.nf_mouse_attempts.is_empty() and game.nf_projectile_pending.is_empty() and game.state.owned_weapons == [0,1,2,3] and game.state.ammo[2] == 32 and game.state.ammo[3] <= 120,"Independent finite pickup/shot/native damage/activation/Survey ledger; current resources versus recovery/disk envelopes")

func route_tick() -> bool:
	if not nf_started: return await super.route_tick()
	if not live_route(): return false
	await physics_frame
	return live_route()

func nursery_finale_earned() -> bool:
	if not live_route(): return false
	if not expect(game.state.position == route_player.position and game.state.yaw == game.Enemy.canonical_yaw(route_player.rotation.y) and game.state.pitch == clampf(route_player.camera.rotation.x,-1.35,1.35),"Final CURRENT pose independently equals settled production Player"): return false
	if not expect(game.nf_all_dead() and game.nf_boss_attacks.any(func(attack): return attack[2] == 0) and game.nf_boss_attacks.any(func(attack): return attack[2] == 1) and game.nf_flight_steps > 0 and not game.nf_patterns.is_empty() and game.nf_patterns.values().all(func(count): return count in [3,5]) and game.nf_shots.size() > 0 and game.nf_shots.size() <= NF_SHOTS and game.nf_inputs.map(func(item): return item[0]) == [NF_STORY.id,NF_DOOR.id] and game.nf_checkpoint_saves == 1 and game.nf_exit_saves == 0 and nf_waypoints == NF_STORY_ROUTE+NF_SUPPLIES+NF_APPROACH+nf_egress+NF_CLOSE,"Earned29 original corpses, seven new provenance records, natural boss phases/releases/flight, finite resources and complete exact native route"): return false
	for group in route_level.layout.data.encounters:
		if not expect(game.state.removed.count("encounter:"+group.id) == 1,"Every original Nursery encounter earned once: "+group.id): return false
	return true

func nursery_finale_completion() -> bool:
	game.nf_exit_expected = game.nf_handoff()
	for node in [route_level,route_player]+route_level.get_children(): nf_retired.append(weakref(node))
	var original_player = route_player
	aim_interaction(NF_DESCENT.cell)
	game.nf_intent = NF_DESCENT.id
	if not "--omit-nursery-finale-exit" in OS.get_cmdline_user_args(): nursery_finale_key(true)
	for frame in range(NF_INPUT):
		await physics_frame
		if game.nf_completed: break
		if not live_route(): return false
	nursery_finale_key(false)
	release_actions()
	if not expect(game.nf_completed,NF_EXIT_GUARD): return false
	# During the transition frame the actual retired Player must already reject stale queued input.
	if is_instance_valid(original_player):
		if not expect(not original_player._current_map() and game._interaction_pending_player == 0 and not game._consume_interaction_input(original_player,true) and original_player._weapon_intent == -1 and not original_player._fire_pressed,"Native exit cancels pending input; retired Player cannot consume the next frame"): return false
	for frame in range(12): await process_frame
	var offered: Array = game.menu.get_children().filter(func(node): return node is Button and not node.is_queued_for_deletion() and node.text == "Descend to The Ossuary")
	var labels: Array = game.menu.get_children().filter(func(node): return node is Label and not node.is_queued_for_deletion() and node.text == "THE NURSERY RESTORED")
	var saved = game.Campaign.new()
	if not expect(game.nf_ok and finale_prior_frozen() and game.state.to_dict() == game.nf_exit_expected and game.nf_exit_expected == game.nf_handoff() and saved.load_progress(r_profile) and saved.to_dict() == game.nf_exit_expected and FileAccess.get_sha256(r_profile) == game.nf_saved_sha and game.nf_exit_saves == 1 and game.nf_checkpoint_saves == 1 and game.nf_capture_calls == 4 and game.nf_inputs.map(func(item): return item[0]) == [NF_STORY.id,NF_DOOR.id,NF_DESCENT.id] and game.level == null and game.player == null and not game.playing and not game.placement_pending and not game.loaded_positions and paused and game.menu_scroll.visible and not game.quitting and offered.size() == 1 and labels.size() == 1 and labels[0].is_visible_in_tree() and offered[0].is_visible_in_tree() and not offered[0].disabled and nf_retired.all(func(ref): return ref.get_ref() == null) and nf_marker_refs.values().all(func(ref): return ref.get_ref() == null),"Same nonquitting earned owner; real Nursery RESTORED menu, loaded persisted fresh Ossuary handoff, drained original scene/actors/markers"): return false
	var connections: Array = offered[0].get_signal_connection_list("pressed")
	return expect(connections.size() == 1 and connections[0].callable == Callable(game,"start_level"),"Actual unique connected Ossuary Descend signal targets SAME Main.start_level")

func nursery_finale_ossuary() -> bool:
	if not expect(finale_pins_match() and game.get_instance_id() == r_main_id and game.state.get_instance_id() == r_campaign_id and game.progress_path == r_profile,"Exact reviewed source pins and same earned owner before Ossuary adoption"): return false
	nf_entry_fields = game.get_property_list().filter(func(property): return str(property.name).begins_with("nf_") and property.name != "nf_enabled").map(func(property): return property.name)
	nf_entry_frozen = observer_witness(nf_entry_fields)
	game.nf_enabled = false
	game.oss_enabled = true
	nf_entry_epoch = Engine.get_physics_frames()
	nf_entry_wall = Time.get_ticks_usec()
	var offered: Array = game.menu.get_children().filter(func(node): return node is Button and not node.is_queued_for_deletion() and node.text == "Descend to The Ossuary")
	if not expect(offered.size() == 1,"Retain one real Ossuary button at handoff"): return false
	if not "--omit-nursery-finale-ossuary-menu" in OS.get_cmdline_user_args(): offered[0].pressed.emit()
	for frame in range(NF_ENTRY_LIMIT-2):
		if game.playing and not game.placement_pending and is_instance_valid(game.player): break
		if Time.get_ticks_usec()-nf_entry_wall > NF_ENTRY_SECONDS*1000000: break
		await physics_frame
	for frame in range(2): await physics_frame
	await process_frame
	return nursery_ossuary_result()

func nursery_ossuary_result() -> bool:
	if not expect(game.oss_ok and game.oss_current() and game.oss_start_calls == 1 and game.oss_captures == 1 and game.oss_mouse_attempts.size() == 1 and game.oss_ticks >= 1 and Engine.get_physics_frames()-nf_entry_epoch <= NF_ENTRY_LIMIT and Time.get_ticks_usec()-nf_entry_wall <= NF_ENTRY_SECONDS*1000000 and finale_prior_frozen() and not game.nf_enabled and observer_witness(nf_entry_fields) == nf_entry_frozen and game.get_instance_id() == r_main_id and game.state.get_instance_id() == r_campaign_id and game.progress_path == r_profile and game.settings_path == game.r_settings_origin,"Nonquitting same earned Main/Campaign/profile; every completed finale/prior observer frozen;30-frame/10s fresh entry cap"): return false
	if not expect(finale_outcome_matches(game.nf_boss_attacks,game.nf_shots.size(),game.budget(),FileAccess.get_sha256(r_profile)),"NATIVE RED exact retained finale variant/phase,81shots,93/197resources and finalsave identity"): return false
	var scene = game.level
	var player = game.player
	var data: Dictionary = scene.layout.data
	if not expect(scene.get_script() == game.Level and player.get_script() == game.Player and scene.get_instance_id() != game.n_level_id and player.get_instance_id() != game.n_player_id and scene.get_instance_id() == game.oss_level_id and player.get_instance_id() == game.oss_player_id and data.id == "ossuary" and data.spawn == [35.5,24.5] and data.spawn_yaw == 90 and data.enemies.size() == 27 and game.enemies.size() == 27 and game.oss_bindings.size() == 27 and scene.get_children().filter(func(node): return node.get_script() == game.Enemy).size() == 27 and game.is_processing() and game.is_physics_processing() and player.is_physics_processing() and player._current_map() and not game.menu_scroll.visible and not game.quitting,"Fresh original sixth Level/Player/27 native actors, live processing and exact original spawn"): return false
	var records: Array = game.oss_originals()
	for index in range(NF_O_ACTORS.size()):
		var spec: Array = NF_O_ACTORS[index]
		var record: Dictionary = records[index]
		var actor = game.enemies[index]
		var capsule: CollisionShape3D = actor.get_child(0)
		if not expect(data.enemies[index] == {"id":spec[0],"kind":spec[1],"cell":[spec[2],spec[3]],"yaw":float(spec[5])} and actor.get_script() == game.Enemy and game.oss_bindings.get(actor.id,[]) == [actor.get_instance_id(),capsule.get_instance_id(),capsule.shape.get_instance_id()] and actor.hp == record.hp and actor.max_hp == record.hp and actor.position == Vector3(record.position[0],record.position[1],record.position[2]) and actor.rotation.y == Vector3(0,deg_to_rad(spec[5]),0).y and actor.encounter_id == spec[6] and not actor.active and not actor.alerted and actor.age > 0 and actor.age <= float(Engine.get_physics_frames()-nf_entry_epoch+1)/60.0+0.000001 and actor._current_map() and actor.is_physics_processing() and actor.get_parent() == scene and not actor.is_queued_for_deletion() and actor.collision_layer == 4 and actor.collision_mask == 7 and not capsule.disabled and capsule.shape is CapsuleShape3D and absf(capsule.shape.radius-N_ROLES[spec[1]][1]) < 0.000001 and absf(capsule.shape.height-N_ROLES[spec[1]][2]) < 0.000001,"Independent original Ossuary actor pose/HP/capsule/group and live native age: "+spec[0]): return false
	var capsule: CollisionShape3D = player.get_child(0)
	var support: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(player.position+Vector3.UP*0.5,player.position-Vector3.UP*0.5,1))
	var expected: Dictionary = game.oss_document()
	expected.position = [player.position.x,player.position.y,player.position.z]
	expected.explored = game.oss_explored.duplicate(true)
	var saved = game.Campaign.new()
	if not expect(player.position.x == 142.0 and player.position.z == 98.0 and absf(player.position.y) <= 0.05 and not support.is_empty() and support.normal.y >= 0.7 and absf(player.position.y-support.position.y) <= 0.15 and player.rotation.y == Vector3(0,deg_to_rad(90),0).y and player.camera.rotation.x == 0.0 and game.state.position == player.position and game.state.yaw == game.Enemy.canonical_yaw(player.rotation.y) and game.state.pitch == clampf(player.camera.rotation.x,-1.35,1.35) and player.collision_layer == 2 and player.collision_mask == 5 and not capsule.disabled and capsule.shape is CapsuleShape3D and capsule.shape.radius == Vector3(0.32,0,0).x and capsule.shape.height == Vector3(1.65,0,0).x and capsule.position == Vector3(0,0.85,0) and player._weapon_intent == -1 and not player._fire_pressed and game._interaction_pending_player == 0 and game.state.to_dict() == expected and game.budget() == game.nf_ledger and saved.load_progress(r_profile) and saved.to_dict() == game.nf_exit_expected and FileAccess.get_sha256(r_profile) == game.nf_saved_sha and nf_retired.all(func(ref): return ref.get_ref() == null) and nf_marker_refs.values().all(func(ref): return ref.get_ref() == null),"Actual settled sixth Player/pose/capsule/Survey with unchanged earned resources/story; live fresh checkpoint versus persisted zero-position handoff, stale actors/input drained"): return false
	print("NURSERY_EARNED_FINALE frames=",Engine.get_physics_frames()-nf_epoch," shots=",game.nf_shots.size()," boss_attacks=",game.nf_boss_attacks," native_charge_contacts=",game.nf_charge_contacts," boss_flight_steps=",game.nf_flight_steps," deaths=",game.nf_deaths," provenance=",game.nf_finishes," resources=",game.nf_ledger," saved_sha=",game.nf_saved_sha," ossuary_entry_frames=",Engine.get_physics_frames()-nf_entry_epoch)
	return true

func nursery_finale_egress() -> bool:
	if not expect(nf_battle_corner in range(NF_BATTLE.size()),"Actual finite moving-fight corner retained for obstacle-safe egress"): return false
	for hop in range(NF_BATTLE.size()):
		var index: int = (nf_battle_corner+hop)%NF_BATTLE.size()
		nf_egress.append(NF_BATTLE[index].duplicate())
		if index == 2: break
	return await nursery_finale_route(nf_egress)
