extends "res://tests/test_reliquary_earned_entry.gd"

const H_ENTRY_SHA = "74bbbce7a6a35693350da63e8b1008af10963bae952a5828c2c5120f338cbe0c"
const H_ENTRY_FIELDS = ["r_ok","r_main_origin","r_campaign_origin","r_profile_origin","r_settings_origin","r_captures","r_capture_attempts","r_bindings","r_level_id","r_player_id","r_start","r_ticks","r_explored","r_last_cell"]
const H_FLAGS = ["foundry_enabled","entry_enabled","organ_enabled","palanquin_enabled","exit_enabled"]
const H_APPROACH = [[18.5,38.5],[18.5,37.5],[18.5,38.5],[19.5,38.5],[20.5,38.5],[20.5,37.5],[20.5,38.5],[19.5,38.5],[19.5,35.5],[19.5,32.5],[19.5,28.5],[15.5,28.5],[12.5,28.5],[10.5,28.5],[10.5,25.5],[9.5,25.5],[10.5,25.5],[9.5,22.1]]
const H_IDS = ["reliquary_enemy_00","reliquary_enemy_01","reliquary_enemy_02","reliquary_enemy_03","reliquary_enemy_04","reliquary_enemy_05","reliquary_enemy_06","reliquary_enemy_07"]
# 32 perfect pistol hits need 31*12.6=390.6 inter-shot ticks; 360 cannot certify this group.
const H_FIGHT_LIMIT = 480
const H_LIMIT = 4830
const H_SECONDS = 90
const H_PICKUPS = {
	"reliquary_entry_rivets":{"id":"reliquary_entry_rivets","kind":"ammo","cell":[18.5,38.5],"amount":60.0,"weapon":1.0},
	"reliquary_entry_scattergun":{"id":"reliquary_entry_scattergun","kind":"weapon","cell":[19.5,32.5],"amount":16.0,"weapon":2.0},
	"reliquary_entry_health":{"id":"reliquary_entry_health","kind":"health","cell":[18.5,37.5],"amount":30.0},
	"reliquary_entry_armor":{"id":"reliquary_entry_armor","kind":"armor","cell":[20.5,37.5],"amount":40.0},
	"reliquary_halo_approach_rivets":{"id":"reliquary_halo_approach_rivets","kind":"ammo","cell":[9.5,25.5],"amount":45.0,"weapon":1.0},
	"reliquary_halo_approach_shells":{"id":"reliquary_halo_approach_shells","kind":"ammo","cell":[10.5,25.5],"amount":8.0,"weapon":2.0}}

class FourthMain:
	extends "res://tests/test_reliquary_earned_entry.gd".ReliquaryMain
	var h_enabled: bool = false
	var h_ok: bool = true
	var h_level: int = 0
	var h_player: int = 0
	var h_bindings: Dictionary = {}
	var h_ticks: int = 0
	var h_shots: Array = []
	var h_last: int = -1
	var h_slot: float = -1.0
	var h_last_time: float = -INF
	var h_shot_start_age: float = INF
	var h_shot_start_time: float = 0.0
	var h_rivets: int = 0
	var h_health_gain: int = 0
	var h_armor_gain: int = 0
	var h_health_loss: int = 0
	var h_absorbed: int = 0
	var h_consumed: Dictionary = {}
	var h_rejected: Dictionary = {}
	var h_removed: Array = []
	var h_activation: int = 0
	var h_activated: Dictionary = {}
	var h_attacks: Dictionary = {}
	var h_roles: Dictionary = {}
	var h_damage_attacks: Dictionary = {}
	var h_hurts: Array = []
	var h_deaths: Dictionary = {}
	var h_finishes: Dictionary = {}
	var h_births: Dictionary = {}
	var h_contacts: Dictionary = {}
	var h_projectile_used: Dictionary = {}
	var h_pending: Dictionary = {}
	var h_release: Dictionary = {}
	var h_melee_pending: Dictionary = {}
	var h_enemy_contacts: Dictionary = {}
	var h_enemy_pending: Dictionary = {}
	var h_enemy_used: Dictionary = {}
	func h_current() -> bool:
		return fourth_scene() and playing and not get_tree().paused and not placement_pending and level.get_instance_id() == h_level and player.get_instance_id() == h_player and prefix_bookkeeping_retired
	func h_resources() -> Dictionary:
		return {"health":100+h_health_gain-h_health_loss,"armor":200+h_armor_gain-h_absorbed,"ammo":[0,125+h_rivets-h_shots.size(),32,0,0,0],"owned_weapons":[0,1,2],"weapon":1}
	func h_original(actor) -> bool:
		return is_instance_valid(actor) and actor.get_script() == Enemy and actor.id in H_IDS and h_bindings.get(actor.id,-1) == actor.get_instance_id() and actor._current_map() and actor.get_parent() == level and not actor.is_queued_for_deletion()
	func h_stack(source: String, method: String) -> bool:
		return get_stack().any(func(frame): return str(frame.get("source","")).ends_with(source) and frame.get("function","") == method)
	func h_worker_contact(victim, repeat_ray: bool) -> bool:
		var source = h_release.get("source")
		if not h_original(source) or source.kind != "worker" or source.hp <= 0 or not source.active or h_release.get("tick",-1) != Engine.get_physics_frames() or not h_stack("/enemy.gd","_attack") or not h_stack("/enemy.gd","_release_attack"): return false
		var key: String = source.id+":"+str(h_release.tick)
		var hit: Dictionary = h_release.hit
		if h_damage_attacks.has(key) or hit.get("collider") != victim or hit.get("rid") != victim.get_rid() or victim.get_parent() != level: return false
		var origin: Vector3 = source.global_position+Vector3.UP*1.4
		var end: Vector3 = origin+(source._committed_aim-origin).normalized()*30.0
		if origin != h_release.origin or end != h_release.end: return false
		if repeat_ray:
			var query = PhysicsRayQueryParameters3D.create(origin,end,1|2|4)
			query.exclude = [source.get_rid()]
			query.hit_from_inside = true
			if level.get_world_3d().direct_space_state.intersect_ray(query) != hit: return false
		return true
	func h_crawler_contact(victim, repeat_ray: bool) -> bool:
		if h_melee_pending.is_empty(): return false
		var source = h_melee_pending.source
		var tick: int = h_melee_pending.release_tick
		var age: int = Engine.get_physics_frames()-tick
		if not h_original(source) or source.kind != "crawler" or source.hp <= 0 or not source.active or h_melee_pending.tick != Engine.get_physics_frames() or h_melee_pending.map != level or h_melee_pending.player != player or h_attacks.get(source.id,-1) != tick or age < 0 or age > 12 or h_damage_attacks.has(source.id+":"+str(tick)) or not h_stack("/enemy.gd","_try_melee") or not h_stack("/enemy.gd","_attack"): return false
		var hit: Dictionary = h_melee_pending.hit
		if hit.get("collider") != victim or hit.get("rid") != victim.get_rid() or victim.get_parent() != level: return false
		var intended = h_melee_pending.intended
		if not is_instance_valid(intended) or source._committed_target != intended or source.global_position.distance_to(intended.global_position) >= 1.9: return false
		var origin: Vector3 = source.global_position+Vector3.UP*0.6
		var end: Vector3 = intended.global_position+Vector3.UP*0.7
		if origin != h_melee_pending.origin or end != h_melee_pending.end: return false
		if repeat_ray:
			var query = PhysicsRayQueryParameters3D.create(origin,end,1|2|4)
			query.exclude = [source.get_rid()]
			query.hit_from_inside = true
			if level.get_world_3d().direct_space_state.intersect_ray(query) != hit: return false
		else:
			if h_melee_pending.victim_hp <= 0 or h_melee_pending.victim_hp > 12: return false
		return true
	func h_projectile_death(victim) -> bool:
		if h_enemy_pending.is_empty(): return false
		var id: int = h_enemy_pending.id
		var data: Dictionary = h_enemy_pending.data
		var projectile = data.projectile
		if not h_births.has(id) or not h_enemy_contacts.has(id) or h_enemy_used.has(id) or not is_instance_valid(projectile): return false
		var birth: Dictionary = h_births[id]
		return data.tick == Engine.get_physics_frames() and data.hit.collider == victim and data.hit.rid == victim.get_rid() and data.victim_id == victim.get_instance_id() and data.victim_hp > 0 and data.victim_hp <= 14 and data.map == level and data.player == player and birth.source == data.source and birth.reference.get_ref() == projectile and h_original(data.source) and projectile.shooter == data.source and projectile.is_queued_for_deletion() and projectile._current_map() and h_stack("/projectile.gd","_physics_process") and h_stack("/enemy.gd","take_damage")
	func _physics_process(delta: float) -> void:
		super._physics_process(delta)
		if not h_enabled: return
		h_ok = h_ok and h_enemy_pending.is_empty() and h_melee_pending.is_empty() and h_current() and absf(delta-1.0/60.0) < 0.000001
		h_ticks += 1
		if not Input.is_action_pressed("fire"): h_slot = -1.0
	func shot(weapon: int) -> void:
		if h_enabled:
			var tick: int = Engine.get_physics_frames()
			h_slot = entry_slot(tick,h_last,h_slot,weapon)
			var elapsed: float = player.active_play_time-h_shot_start_time
			h_ok = h_ok and h_current() and Engine.is_in_physics_frame() and weapon == 1 and state.weapon == 1 and Input.is_action_pressed("fire") and h_slot >= 0.0 and player.shot_age(1) == 0.0 and h_stack("/player.gd","fire") and player.active_play_time > h_last_time and (h_shots.size() > 0 or h_shot_start_age+elapsed+0.000001 >= 0.21)
			h_shots.append([tick,player.active_play_time,h_slot,player.cooldown,weapon])
			h_last = tick
			h_last_time = player.active_play_time
			h_ok = h_ok and budget() == h_resources() and state.ammo[1] >= 0 and state.ammo[1] <= 180 and player.cooldown > 0 and player.cooldown <= 0.21+0.000001
		super.shot(weapon)
	func collect_pickup(id: String) -> void:
		if not h_enabled:
			super.collect_pickup(id)
			return
		if not H_PICKUPS.has(id):
			h_ok = false
			super.collect_pickup(id)
			return
		var spec: Dictionary = H_PICKUPS[id]
		var before: Dictionary = h_resources()
		var marker = level.markers.get(id)
		var ammo: bool = spec.kind in ["ammo","weapon"]
		var slot: int = int(spec.get("weapon",0))
		var cap: int = (180 if slot == 1 else 32) if ammo else (100 if spec.kind == "health" else 200)
		var old: int = int(before.ammo[slot] if ammo else before[spec.kind])
		var gain: int = mini(cap,old+int(spec.amount))-old
		h_ok = h_ok and h_current() and Engine.is_in_physics_frame() and budget() == before and not id in state.removed and is_instance_valid(marker) and marker.get_parent() == level and not marker.is_queued_for_deletion() and level.layout.data.pickups.filter(func(item): return item.id == id) == [spec] and player.position.distance_to(level.layout.world_position(spec.cell)) < 1.4 and h_stack("/main.gd","update_passive_triggers")
		super.collect_pickup(id)
		if gain > 0:
			if ammo:
				h_ok = h_ok and slot == 1
				h_rivets += gain
			elif spec.kind == "health": h_health_gain += gain
			else: h_armor_gain += gain
			h_consumed[id] = h_consumed.get(id,0)+1
			h_removed.append(id)
			h_ok = h_ok and h_consumed[id] == 1 and not level.markers.has(id) and state.removed.count(id) == 1
		else:
			h_rejected[id] = h_rejected.get(id,0)+1
			h_ok = h_ok and is_instance_valid(marker) and level.markers.get(id) == marker and not marker.is_queued_for_deletion() and not id in state.removed
		h_ok = h_ok and budget() == h_resources() and state.removed == h_removed
	func activate_encounter(id: String) -> void:
		if not h_enabled:
			super.activate_encounter(id)
			return
		var prior: bool = "encounter:"+id in state.removed
		h_ok = h_ok and h_current() and id == "reliquary_halo_commit"
		if not prior:
			var cell: Vector2 = Vector2(player.position.x,player.position.z)/4.0
			h_ok = h_ok and cell.x >= 2.0 and cell.x <= 13.9 and cell.y >= 10.0 and cell.y <= 22.5 and Engine.is_in_physics_frame() and h_stack("/main.gd","update_encounter_triggers") and h_stack("/player.gd","_physics_process") and state.keys.is_empty()
		super.activate_encounter(id)
		if not prior:
			h_activation += 1
			h_removed.append("encounter:"+id)
			for actor in enemies:
				if actor.id in H_IDS:
					h_ok = h_ok and h_original(actor) and actor.active and actor.alerted and actor.hp == actor.max_hp
					h_activated[actor.id] = [actor.get_instance_id(),Engine.get_physics_frames()]
			h_ok = h_ok and h_activation == 1 and h_activated.size() == 8 and state.removed == h_removed
	func enemy_event(actor, event: String) -> void:
		if h_enabled:
			h_ok = h_ok and h_current() and Engine.is_in_physics_frame() and h_original(actor) and actor.active and h_activated.has(actor.id) and h_stack("/enemy.gd","_event")
			if event == "attack":
				h_attacks[actor.id] = Engine.get_physics_frames()
				h_roles[actor.kind] = h_roles.get(actor.kind,0)+1
				h_release = {"source":actor,"tick":Engine.get_physics_frames()}
				if actor.kind == "worker":
					var origin: Vector3 = actor.global_position+Vector3.UP*1.4
					var end: Vector3 = origin+(actor._committed_aim-origin).normalized()*30.0
					var query = PhysicsRayQueryParameters3D.create(origin,end,1|2|4)
					query.exclude = [actor.get_rid()]
					query.hit_from_inside = true
					h_release.merge({"origin":origin,"end":end,"hit":level.get_world_3d().direct_space_state.intersect_ray(query)})
			if event == "melee_contact":
				var intended = actor._committed_target
				var tick: int = int(h_attacks.get(actor.id,-1000))
				var age: int = Engine.get_physics_frames()-tick
				if not OS.is_debug_build() or actor.kind != "crawler" or actor.hp <= 0 or not h_melee_pending.is_empty() or not actor._valid_target(intended) or intended.get_parent() != level or actor.global_position.distance_to(intended.global_position) >= 1.9 or age < 0 or age > 12 or h_damage_attacks.has(actor.id+":"+str(tick)) or not h_stack("/enemy.gd","_try_melee") or not h_stack("/enemy.gd","_physics_process"):
					h_ok = false
					return
				var origin: Vector3 = actor.global_position+Vector3.UP*0.6
				var end: Vector3 = intended.global_position+Vector3.UP*0.7
				var query = PhysicsRayQueryParameters3D.create(origin,end,1|2|4)
				query.exclude = [actor.get_rid()]
				query.hit_from_inside = true
				var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(query)
				var victim = hit.get("collider")
				if not origin.is_finite() or not end.is_finite() or not (victim == player or h_original(victim) and victim.hp > 0) or hit.get("rid") != victim.get_rid():
					h_ok = false
					return
				if victim == player or victim.hp <= 12:
					h_melee_pending = {"source":actor,"release_tick":tick,"tick":Engine.get_physics_frames(),"map":level,"player":player,"intended":intended,"origin":origin,"end":end,"hit":hit,"victim_hp":0 if victim == player else victim.hp}
			if event == "death":
				h_deaths[actor.id] = h_deaths.get(actor.id,0)+1
				var player_fire: bool = actor.target == player and h_last == Engine.get_physics_frames() and player.shot_age(1) == 0.0 and Input.is_action_pressed("fire") and h_stack("/player.gd","fire") and aim_observation.get("actor_id","") == actor.id and aim_observation.get("tick",-1) == Engine.get_physics_frames() and aim_observation.get("level") == level and aim_observation.get("player") == player and aim_observation.get("weapon",-1) == 1
				var worker: bool = h_worker_contact(actor,false)
				var caster: bool = h_projectile_death(actor)
				var crawler: bool = h_crawler_contact(actor,false)
				var infighting: bool = worker or caster or crawler
				if crawler:
					h_damage_attacks[h_melee_pending.source.id+":"+str(h_melee_pending.release_tick)] = true
					h_melee_pending.clear()
				if worker: h_damage_attacks[h_release.source.id+":"+str(h_release.tick)] = true
				if caster:
					h_enemy_used[h_enemy_pending.id] = true
					h_enemy_pending.clear()
				h_finishes[actor.id] = "player" if player_fire else "infighting" if infighting else "unproven"
				h_removed.append(actor.id)
				h_ok = h_ok and actor.hp == 0 and actor.collision_layer == 0 and actor.collision_mask == 0 and state.removed.count(actor.id) == 1 and h_deaths[actor.id] == 1 and (player_fire or infighting) and state.removed == h_removed
		super.enemy_event(actor,event)
	func _debug_projectile_event(projectile: Node3D, event: String, data: Dictionary) -> void:
		if not h_enabled:
			# New enemy-contact observation does not rewrite historical prefix witnesses.
			if event == "queued_enemy_contact": return
			super._debug_projectile_event(projectile,event,data)
			return
		var source = projectile.shooter
		var id: int = projectile.get_instance_id()
		h_ok = h_ok and h_current() and OS.is_debug_build() and Engine.is_in_physics_frame() and projectile.get_script() == preload("res://scripts/projectile.gd") and projectile.game == self and projectile._current_map() and projectile.is_physics_processing() and h_original(source) and source.id == "reliquary_enemy_07" and source.kind == "caster" and data.get("projectile") == projectile and data.get("source") == source and data.get("map") == level and data.get("player") == player and data.get("tick",-1) == Engine.get_physics_frames() and data.get("position") == projectile.global_position and data.get("velocity") == projectile.velocity and data.get("lifetime") == projectile.lifetime and projectile.blast_damage == 0 and data.get("blast_damage") == 0 and projectile.velocity.is_finite() and is_equal_approx(projectile.velocity.length(),12.0) and projectile.lifetime > 0 and projectile.lifetime <= 4.0
		if event == "configured_birth":
			h_ok = h_ok and not h_births.has(id) and source.hp > 0 and source.active and h_attacks.get(source.id,-1) == Engine.get_physics_frames() and projectile.lifetime == 4.0 and not projectile.is_queued_for_deletion() and data.get("origin") is Vector3 and data.get("destination") is Vector3 and h_stack("/enemy.gd","_release_attack")
			if data.get("origin") is Vector3 and data.get("destination") is Vector3:
				h_ok = h_ok and data.origin.is_finite() and data.destination.is_finite() and data.origin == projectile.global_position and projectile.velocity.is_equal_approx((data.destination-data.origin).normalized()*12.0)
			h_births[id] = {"source":source,"tick":Engine.get_physics_frames(),"reference":weakref(projectile),"map":level,"player":player}
			return
		if not event in ["queued_player_contact","queued_enemy_contact"] or not h_births.has(id) or h_contacts.has(id) or h_enemy_contacts.has(id) or not h_pending.is_empty() or not h_enemy_pending.is_empty() or not (data.get("hit") is Dictionary and data.get("ray_start") is Vector3 and data.get("ray_end") is Vector3):
			h_ok = false
			return
		var birth: Dictionary = h_births[id]
		var hit: Dictionary = data.hit
		var victim = hit.get("collider")
		var victim_ok: bool = victim == player if event == "queued_player_contact" else h_original(victim) and victim != source and victim.hp > 0
		if not victim_ok:
			h_ok = false
			return
		h_ok = h_ok and source == birth.source and birth.reference.get_ref() == projectile and birth.map == level and birth.player == player and projectile.is_queued_for_deletion() and data.tick >= birth.tick and data.tick-birth.tick <= 241 and hit.get("rid") == victim.get_rid() and hit.get("position") == projectile.global_position and data.ray_start.is_finite() and data.ray_end.is_finite() and data.ray_end.is_equal_approx(data.ray_start+projectile.velocity*minf(1.0/60.0,projectile.lifetime)) and h_stack("/projectile.gd","_physics_process")
		var query = PhysicsRayQueryParameters3D.create(data.ray_start,data.ray_end,1|2|4)
		query.exclude = [source.get_rid()]
		query.hit_from_inside = true
		h_ok = h_ok and level.get_world_3d().direct_space_state.intersect_ray(query) == hit
		if event == "queued_player_contact":
			h_contacts[id] = data.duplicate(true)
			h_pending = {"id":id,"data":data.duplicate(true)}
		else:
			var contact: Dictionary = data.duplicate(true)
			contact.merge({"victim_id":victim.get_instance_id(),"victim_hp":victim.hp})
			h_enemy_contacts[id] = contact
			if victim.hp <= 14: h_enemy_pending = {"id":id,"data":contact}
	func hurt_player(amount: int) -> void:
		if not h_enabled:
			super.hurt_player(amount)
			return
		var attributed: bool = false
		var source_id: String = ""
		if amount == 14 and not h_pending.is_empty():
			var id: int = h_pending.id
			var data: Dictionary = h_pending.data
			attributed = h_births.has(id) and h_contacts.has(id) and not h_projectile_used.has(id) and data.tick == Engine.get_physics_frames() and is_instance_valid(data.projectile) and data.projectile.is_queued_for_deletion() and data.projectile._current_map() and h_original(data.source) and data.map == level and data.player == player and data.hit.collider == player and h_stack("/projectile.gd","_physics_process")
			if attributed:
				h_projectile_used[id] = true
				source_id = data.source.id
				h_pending.clear()
		elif h_pending.is_empty() and amount == 10:
			attributed = h_worker_contact(player,true)
			if attributed:
				source_id = h_release.source.id
				h_damage_attacks[source_id+":"+str(h_release.tick)] = true
		elif h_pending.is_empty() and amount == 12:
			attributed = h_crawler_contact(player,true)
			if attributed:
				source_id = h_melee_pending.source.id
				h_damage_attacks[source_id+":"+str(h_melee_pending.release_tick)] = true
				h_melee_pending.clear()
		h_ok = h_ok and h_current() and Engine.is_in_physics_frame() and attributed and state.difficulty == 1 and budget() == h_resources()
		var absorbed: int = mini(200+h_armor_gain-h_absorbed,int(amount/3))
		h_absorbed += absorbed
		h_health_loss += amount-absorbed
		h_hurts.append([Engine.get_physics_frames(),source_id,amount,absorbed])
		super.hurt_player(amount)
		h_ok = h_ok and budget() == h_resources()

var h_started: bool = false
var h_epoch: int = 0
var h_wall: int = 0
var h_fields: Array = []
var h_frozen: Dictionary = {}
var h_ages: Dictionary = {}
var h_marker_refs: Dictionary = {}

func run() -> void:
	if not await walk_through_halo(FourthMain.new()):
		await finish(1)
		return
	print("PASS source-native virtual-input earned fourth HALO feasibility only: original mixed8 natural deaths, native role attacks/caster birth/player sweep contact, finite ammo and damage, frozen prefix witnesses; not physical controls, visual/audio/performance, packed-app, fourth seals/checkpoint/exit or full-eight acceptance")
	await finish(0)

func walk_through_halo(observer: FourthMain, profile_prefix: String = "") -> bool:
	if not expect(H_LIMIT == H_APPROACH.size()*240+H_FIGHT_LIMIT+30,"Declared4830 bound matches actual18 hops and480 fight ticks"):
		if is_instance_valid(observer) and observer != game and not observer.is_inside_tree(): observer.free()
		return false
	prefix = profile_prefix if not profile_prefix.is_empty() else "user://reliquary_halo_feasibility_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	if not expect(FileAccess.get_sha256("res://tests/test_reliquary_earned_entry.gd") == H_ENTRY_SHA,"Reviewed candidate entry helper pin; parent must reconcile dependency drift before integration"):
		if is_instance_valid(observer) and observer != game and not observer.is_inside_tree(): observer.free()
		return false
	if not await walk_to_reliquary_entry(observer,prefix) or not start_halo():
		return false
	# Same acceptance guard in both fixture modes; RED omits only fourth approach/activation.
	if not "--halo-no-approach" in OS.get_cmdline_user_args():
		for cell in H_APPROACH:
			var began: int = east_elapsed()
			if not await east_route([cell]) or not expect(east_elapsed()-began <= 240,"Bounded native halo hop including settling/process: "+str(cell)):
				return false
			print("RELIQUARY_HALO_HOP cell=",cell," frames=",east_elapsed()," position=",route_player.position," resources=",game.h_resources()," shots=",game.h_shots.size()," activated=",game.h_activated.size())
	if not expect(game.h_activation == 1 and game.h_activated.size() == 8 and H_IDS.all(func(id): return game.h_activated.has(id)),"NATIVE RED first-fourth feasibility requires legitimate native approach and automatic original mixed-role halo activation after accepted entry"):
		return false
	for frame in range(H_FIGHT_LIMIT):
		if game.h_deaths.size() == 8 and not game.h_contacts.is_empty() and game.h_pending.is_empty(): break
		release_actions()
		east_fire()
		if not await route_tick():
			return false
	release_actions()
	await process_frame
	if not halo_result():
		return false
	return true

func start_halo() -> bool:
	if not expect(game is FourthMain and not game.prefix_bookkeeping_retired and not game.h_enabled and observers_retired() and game.r_ok and game.rate_ok and observer_witness(R_INHERITED_FIELDS) == r_inherited and game.feedback_ok and game.shot_clock_ok and game.budget() == R_CARRY,"Accepted alive entry preserves the exact inherited boundary safeguards before retirement; no resets"): return false
	h_fields = R_THIRD_FIELDS+R_INHERITED_FIELDS+H_ENTRY_FIELDS+H_FLAGS+["ticks","shot_slot"]
	h_frozen = observer_witness(h_fields)
	for actor in game.enemies:
		h_ages[actor.id] = actor.age
		game.h_bindings[actor.id] = actor.get_instance_id()
	for id in route_level.markers: h_marker_refs[id] = weakref(route_level.markers[id])
	for id in H_PICKUPS:
		if not expect(route_level.layout.data.pickups.filter(func(spec): return spec.id == id) == [H_PICKUPS[id]] and route_level.markers.has(id),"Independent finite authored halo/entry supply: "+id): return false
	if not expect(game.Player.WEAPONS[1].damage == 22 and game.Player.WEAPONS[1].interval == 0.21 and game.Player.WEAPONS[1].max_ammo == 180 and game.Player.WEAPONS[2].damage == 15 and game.Player.WEAPONS[2].pellets == 7 and game.Player.WEAPONS[2].interval == 0.7 and game.Player.WEAPONS[2].max_ammo == 32,"Independent real pistol and scattergun constants; no perfect-hit budget guarantee"): return false
	release_actions()
	game.h_level = route_level.get_instance_id()
	game.h_player = route_player.get_instance_id()
	game.h_shot_start_age = route_player.shot_age(1)
	game.h_shot_start_time = route_player.active_play_time
	h_epoch = Engine.get_physics_frames()
	h_wall = Time.get_ticks_usec()
	game.prefix_bookkeeping_retired = true
	game.h_enabled = true
	h_started = true
	return live_route()

func east_elapsed() -> int:
	return Engine.get_physics_frames()-h_epoch if h_started else super.east_elapsed()

func route_tick() -> bool:
	if not h_started: return await super.route_tick()
	if not live_route(): return false
	await physics_frame
	return live_route()

func east_fire() -> bool:
	if not h_started: return super.east_fire()
	Input.action_release("fire")
	if game.state.weapon != 1: return false
	var selected = null
	var nearest: float = 140.0
	for actor in game.enemies:
		if not game.h_original(actor) or not actor.active or actor.hp <= 0: continue
		# Keep the original caster alive until a real birth; no forced attacks or actors.
		if actor.kind == "caster" and game.h_births.is_empty(): continue
		if game.h_roles.get(actor.kind,0) == 0 and game.enemies.filter(func(other): return game.h_original(other) and other.kind == actor.kind and other.hp > 0).size() == 1: continue
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
	Input.action_press("fire")
	return true

func clear_point(cell: Array):
	if not h_started: return super.clear_point(cell)
	var point = super.clear_point(cell)
	if point == null: return null
	# Historical approach maths belongs to revision zero; super checks current native floor/capsule.
	var floor_y: float = (float(cell[1])-26.0)*0.5 if cell[0] >= 8.0 and cell[0] <= 11.0 and cell[1] >= 22.0 and cell[1] <= 26.0 else 0.0
	return point if absf(route_level.layout.original_floor(3).world_position(cell).y-floor_y) <= 0.08 else null

func live_route() -> bool:
	if not h_started: return super.live_route()
	if not expect(east_elapsed() <= H_LIMIT and Time.get_ticks_usec()-h_wall <= H_SECONDS*1000000,"Fresh fourth frame/wall epoch bounded independently of old exit_started"): return false
	if not expect(game.h_ok and game.h_current() and not paused and game.get_instance_id() == r_main_id and game.state.get_instance_id() == r_campaign_id and game.progress_path == r_profile and game.level == route_level and game.player == route_player and not game.loaded_positions and game.is_processing() and game.is_physics_processing() and route_player.is_physics_processing() and route_player._current_map() and route_player.position.is_finite() and game.enemies.size() == 31 and game.scene_roster_matches() and game.h_enemy_pending.is_empty() and game.h_melee_pending.is_empty(),"Same automatic fourth scene/Main/Campaign/profile/player and original31; no recovery; h_ok="+str(game.h_ok)+" position="+str(route_player.position)+" shots="+str(game.h_shots.size())+" resources="+str(game.h_resources())+" deaths="+str(game.h_deaths)+" roles="+str(game.h_roles)): return false
	if not expect(observer_witness(h_fields) == h_frozen and observers_retired() and retired.all(func(reference): return reference.get_ref() == null) and x_marker_refs.values().all(func(reference): return reference.get_ref() == null),"All accepted prefix/entry flags, counters, clocks, bindings, capture history and Survey witnesses stay deep-frozen"): return false
	for index in range(R_ACTORS.size()):
		var spec: Array = R_ACTORS[index]
		var actor = game.enemies[index]
		if not expect(is_instance_valid(actor) and actor.id == spec[0] and game.h_bindings.get(actor.id,-1) == actor.get_instance_id() and actor.get_script() == game.Enemy and actor.kind == spec[1] and actor.max_hp == spec[2] and actor.hp >= 0 and actor.hp <= spec[2] and actor._current_map() and actor.is_physics_processing() and actor.age-h_ages[actor.id] >= float(east_elapsed()-2)/60.0,"Fresh original fourth role/HP/identity and native age: "+spec[0]): return false
		if not actor.id in H_IDS:
			var record: Dictionary = h_frozen.r_start.actors[index]
			if not expect(actor.hp == spec[2] and not actor.active and not actor.alerted and actor.position == Vector3(record.position[0],record.position[1],record.position[2]) and actor.rotation.y == Vector3(0,deg_to_rad(spec[6]),0).y and actor.collision_layer == 4 and actor.collision_mask == 7 and not (actor.get_child(0) as CollisionShape3D).disabled,"Other original23 untouched; unexpected real activation/damage is failure: "+actor.id): return false
		elif actor.hp == 0:
			if not expect(game.h_deaths.get(actor.id,0) == 1 and game.h_finishes.get(actor.id,"unproven") != "unproven" and actor.collision_layer == 0 and actor.collision_mask == 0 and game.state.removed.count(actor.id) == 1,"Each natural halo death/removal/collider change once"): return false
		elif not expect(actor.collision_layer == 4 and actor.collision_mask == 7 and not (actor.get_child(0) as CollisionShape3D).disabled,"Live original halo capsule stays enabled"): return false
	return expect(game.budget() == game.h_resources() and game.state.health > 0 and game.state.health <= 100 and game.state.armor >= 0 and game.state.armor <= 200 and game.state.ammo[1] >= 0 and game.state.ammo[1] <= 180 and game.state.removed == game.h_removed and game.state.keys.is_empty() and game.state.discoveries.is_empty() and game.state.checkpoint_id == "entry" and game.state.checkpoint == h_frozen.r_start and game.state.level_start == h_frozen.r_start and FileAccess.get_sha256(r_profile) == r_saved_sha and game.h_ticks >= east_elapsed()-2 and absf(route_player.active_play_time-game.h_shot_start_time-float(east_elapsed())/60.0) <= 2.0/60.0,"Independent carry plus finite accepted pickup/shot/hurt ledger; unchanged entry recovery/disk envelopes, no fourth seals or manufactured progress")

func halo_result() -> bool:
	print("RELIQUARY_HALO_LIMIT frames=",east_elapsed()," wall_us=",Time.get_ticks_usec()-h_wall," position=",route_player.position," shots=",game.h_shots," resources=",game.h_resources()," consumed=",game.h_consumed," rejected=",game.h_rejected," roles=",game.h_roles," births=",game.h_births.size()," contacts=",game.h_contacts.size()," hurts=",game.h_hurts," deaths=",game.h_deaths," provenance=",game.h_finishes)
	if not live_route(): return false
	if not expect(game.h_deaths.size() == 8 and H_IDS.all(func(id): return game.h_deaths.get(id,0) == 1 and game.h_finishes.get(id,"unproven") in ["player","infighting"]) and ["crawler","worker","caster"].all(func(role): return game.h_roles.get(role,0) > 0),"NATIVE RED bounded480-frame mixed fight requires all original8 natural provenanced deaths and real attack events for every role"): return false
	if not expect(not game.h_births.is_empty() and not game.h_contacts.is_empty() and game.h_projectile_used.size() == game.h_contacts.size() and game.h_pending.is_empty(),"NATIVE RED original caster configured birth and independently repeated native swept player contact/hurt; no direct attack calls"): return false
	if not expect(game.h_consumed == {"reliquary_entry_rivets":1} and game.h_rivets == 55 and game.h_shots.size() > 0 and game.h_shots.size() <= 180,"Finite carry125 plus authored60 capped180 gives only55 accepted rounds; actual Player pistol spending, no refunds"): return false
	for id in ["reliquary_entry_scattergun","reliquary_entry_health","reliquary_entry_armor","reliquary_halo_approach_rivets","reliquary_halo_approach_shells"]:
		if not expect(game.h_rejected.get(id,0) > 0 and route_level.markers.has(id) and h_marker_refs[id].get_ref() == route_level.markers[id] and not id in game.state.removed,"Original full-cap rejection keeps marker/resources/ownership: "+id): return false
	return true
