extends RefCounted

# Test-only, one segment. All callbacks observe; only production changes gameplay.
const LIMIT = 12000
const SECONDS = 600
const LEG = 900
const FIGHT = 1800
const SHOTS = 100
const OWNER = "ossuary_enemy_16"
const GROUPS = ["ossuary_first_commit","ossuary_first_return"]
const BLOOD = {"id":"ossuary_blood","kind":"key","key":"blood","cell":[9.5,14.5],"text":"RIB CARRIER BLOOD SEAL RECOVERED"}
const CARRY = {"health":93,"armor":197,"ammo":[0,99,32,120,0,0],"owned_weapons":[0,1,2,3],"weapon":1}
const SAVE_SHA = "15353b6ea7d39856fcd975c2195d391bfdd7cc2f17d567022945bd749f4558ce"
const ROLES = {"crawler":[50,0.42,1.1],"worker":[90,0.34,2.7],"caster":[90,0.34,2.7],"brute":[210,0.62,3.3],"guardian":[260,0.65,3.7],"summoner":[150,0.45,4.2]}
const SUPPLIES = ["ossuary_entry_rivets","ossuary_entry_shells","ossuary_entry_health","ossuary_entry_armor","ossuary_scattergun","ossuary_first_approach_rivets","ossuary_first_approach_shells","ossuary_first_return_rivets","ossuary_first_return_health"]
var game
var scene
var player
var main_id: int = 0
var campaign_id: int = 0
var level_id: int = 0
var player_id: int = 0
var profile: String = ""
var settings: String = ""
var epoch: int = 0
var wall: int = 0
var ok: bool = true
var failures: Array = []
var ticks: int = 0
var ledger: Dictionary = {}
var keys: Array = []
var removed: Array = []
var explored: Array = []
var last_cell: Vector2i = Vector2i(-1,-1)
var checkpoint: Dictionary = {}
var start: Dictionary = {}
var actor_image: Array = []
var saved_sha: String = ""
var map_image: Dictionary = {}
var originals: Dictionary = {}
var bindings: Dictionary = {}
var hp: Dictionary = {}
var markers: Dictionary = {}
var marker_values: Dictionary = {}
var activated: Dictionary = {}
var pickups: Array = []
var pickup_attempts: Dictionary = {}
var consumed: Dictionary = {}
var shots: Array = []
var last_time: float = -INF
var last_tick: int = -1
var slot: float = -1.0
var events: Array = []
var deaths: Dictionary = {}
var finishes: Dictionary = {}
var damage: Array = []
var lethal: Dictionary = {}
var hurts: Array = []
var births: Dictionary = {}
var contacts: Dictionary = {}
var used_contacts: Dictionary = {}
var pending_player: Dictionary = {}
var summons: Dictionary = {}
var rituals: Dictionary = {}
var inputs: Array = []
var intent: String = ""
var saves: int = 0
var captures: int = 0
var mouse_attempts: int = 0
var starts: int = 0
var restarts: int = 0
var waypoints: Array = []

func require(value: bool, label: String) -> bool:
	if not value:
		ok = false
		if failures.size() < 16 and not label in failures:
			failures.append(label)
			push_error("OSSUARY_WITNESS "+label)
	return value

# Values, not aliases: prior ledgers and this witness can be frozen independently.
static func value_image(value):
	if typeof(value) == TYPE_OBJECT and not is_instance_valid(value): return {"object_id":0}
	if value is Array:
		var result: Array = []
		for item in value: result.append(value_image(item))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value: result[key] = value_image(value[key])
		return result
	if value is WeakRef:
		var ref = value.get_ref()
		return {"weak_id":ref.get_instance_id() if is_instance_valid(ref) else 0}
	if typeof(value) == TYPE_OBJECT:
		return {"object_id":value.get_instance_id() if is_instance_valid(value) else 0}
	return value

func snapshot() -> Dictionary:
	var result: Dictionary = {}
	for property in get_property_list():
		var name: String = str(property.name)
		if (int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE) == 0: continue
		result[name] = value_image(get(name))
	return result

func current() -> bool:
	return is_instance_valid(game) and game.get_instance_id() == main_id and is_instance_valid(scene) and is_instance_valid(player) and game.level == scene and game.player == player and scene.get_instance_id() == level_id and player.get_instance_id() == player_id and not scene.is_queued_for_deletion() and not player.is_queued_for_deletion() and scene.get_parent() == game and player.get_parent() == scene and game.state.get_instance_id() == campaign_id and game.progress_path == profile and game.settings_path == settings and game.playing and not game.get_tree().paused and not game.placement_pending and not game.loaded_positions and game.state.level_index == 5 and game._scene_level_index == 5 and player._current_map()

func actor(node) -> bool:
	return current() and is_instance_valid(node) and node.get_script() == game.Enemy and bindings.has(node.id) and bindings[node.id][0] == node.get_instance_id() and node.get_parent() == scene and not node.is_queued_for_deletion() and node._current_map()

func stack(source: String, method: String) -> bool:
	return game.h_stack(source,method)

func adopt(host) -> bool:
	game = host
	scene = host.level
	player = host.player
	main_id = host.get_instance_id()
	campaign_id = host.state.get_instance_id()
	level_id = scene.get_instance_id()
	player_id = player.get_instance_id()
	profile = host.progress_path
	settings = host.settings_path
	epoch = Engine.get_physics_frames()
	wall = Time.get_ticks_usec()
	if not require(current() and host.budget() == CARRY and host.state.keys.is_empty() and host.state.removed.is_empty() and host.state.discoveries == [3,4] and host.enemies.size() == 27,"verified fresh earned Ossuary boundary"): return false
	map_image = scene.layout.data.duplicate(true)
	ledger = CARRY.duplicate(true)
	explored = host.oss_explored.duplicate(true)
	last_cell = host.oss_last_cell
	checkpoint = host.state.checkpoint.duplicate(true)
	start = host.state.level_start.duplicate(true)
	actor_image = host.state.actors.duplicate(true)
	saved_sha = SAVE_SHA
	# Compare the known saved expectation; never learn a replacement from disk.
	require(host.nf_saved_sha == SAVE_SHA and FileAccess.get_sha256(profile) == SAVE_SHA and host.state.explored == explored,"immutable independently pinned disk/entry Survey")
	for node in host.enemies:
		var capsule: CollisionShape3D = node.get_child(0)
		bindings[node.id] = [node.get_instance_id(),capsule.get_instance_id(),capsule.shape.get_instance_id()]
		originals[node.id] = [node.position,node.rotation.y,node.age,node.max_hp,node.kind,node.encounter_id]
		hp[node.id] = node.max_hp
		require(node.hp == node.max_hp and not node.active and not node.alerted and node._summon_owner_id.is_empty(),"full original actor at adoption: "+node.id)
	for id in scene.markers:
		var marker = scene.markers[id]
		markers[id] = weakref(marker)
		marker_values[id] = [marker.get_instance_id(),marker.transform]
	return validate()

func physics(delta: float) -> void:
	require(current() and Engine.is_in_physics_frame() and absf(delta-1.0/60.0) < 0.000001,"native current-map60Hz observer")
	if not current(): return
	ticks += 1
	if not Input.is_action_pressed("fire"): slot = -1.0
	register_summons()
	survey()

func survey() -> void:
	var cell: Vector2i = Vector2i((Vector2(player.position.x,player.position.z)/4.0).floor())
	if cell == last_cell or not scene.layout.is_walkable(cell): return
	last_cell = cell
	for x in range(cell.x-2,cell.x+3):
		for z in range(cell.y-2,cell.y+3):
			var point: Vector2i = Vector2i(x,z)
			var saved: Array = [x,z]
			if not scene.layout.is_walkable(point) or saved in explored: continue
			var end: Vector3 = scene.layout.world_position([x+0.5,z+0.5])+Vector3.UP*1.55
			if point == cell or scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(player.camera.global_position,end,1)).is_empty(): explored.append(saved)

func before_shot(weapon: int) -> void:
	# Births can precede this callback in the same physics tick.
	if current() and ok: register_summons()
	var tick: int = Engine.get_physics_frames()
	slot = game.entry_slot(tick,last_tick,slot,weapon)
	require(current() and Engine.is_in_physics_frame() and stack("/player.gd","fire") and stack("/player.gd","_physics_process") and Input.is_action_pressed("fire") and weapon == 1 and game.state.weapon == 1 and not player._fire_release_required and player.shot_age(1) == 0.0 and slot >= 0 and player.active_play_time > last_time and shots.size() < SHOTS,"committed finite native pistol cadence")
	ledger.ammo[1] -= 1
	shots.append([tick,player.active_play_time,weapon,player.cooldown])
	last_tick = tick
	last_time = player.active_play_time
	require(ledger.ammo[1] >= 0 and game.budget() == ledger and player.cooldown > 0 and player.cooldown <= 0.210001,"independent actual pistol debit")

func before_pickup(id: String) -> Dictionary:
	var rows: Array = scene.layout.data.pickups.filter(func(spec): return spec.id == id)
	if not require(rows.size() == 1 and id in SUPPLIES,"only authored first-loop supplies"): return {}
	var spec: Dictionary = rows[0]
	var marker = scene.markers.get(id)
	require(current() and Engine.is_in_physics_frame() and game.budget() == ledger and stack("/main.gd","update_passive_triggers") and stack("/player.gd","_physics_process") and not consumed.has(id) and markers.has(id) and marker == markers[id].get_ref() and is_instance_valid(marker) and not marker.is_queued_for_deletion() and player.position.distance_to(scene.layout.world_position(spec.cell)) < 1.4 and game._passive_trigger_visible(spec),"actual visible once-only passive pickup: "+id)
	var expected: Dictionary = ledger.duplicate(true)
	if spec.kind in ["weapon","ammo"]:
		var index: int = int(spec.weapon)
		require(index in [1,2] and index in expected.owned_weapons,"no new ownership or launcher in transport")
		expected.ammo[index] = mini([0,180,32,240,24,120][index],int(expected.ammo[index])+int(spec.amount))
	elif spec.kind == "health": expected.health = mini(100,int(expected.health)+int(spec.amount))
	elif spec.kind == "armor": expected.armor = mini(200,int(expected.armor)+int(spec.amount))
	else: require(false,"unknown pickup")
	return {"id":id,"before":ledger.duplicate(true),"after":expected,"marker":marker}

func after_pickup(record: Dictionary) -> void:
	if record.is_empty(): return
	var granted: bool = record.before != record.after
	pickup_attempts[record.id] = pickup_attempts.get(record.id,0)+1
	# Repeated full-capacity passive scans retain a count, not identical nested ledgers.
	if not pickups.any(func(item): return item[0] == record.id and item[2] == record.before and item[3] == record.after):
		require(pickups.size() < 512,"bounded distinct pickup observation history")
		pickups.append([record.id,Engine.get_physics_frames(),record.before,record.after.duplicate(true),granted])
	ledger = record.after
	if granted:
		consumed[record.id] = 1
		removed.append(record.id)
	require(game.budget() == ledger and game.state.removed.count(record.id) == (1 if granted else 0) and (not scene.markers.has(record.id) if granted else scene.markers.get(record.id) == record.marker),"clamped/uncollected supply and actual retirement: "+record.id)

func before_encounter(id: String) -> Dictionary:
	if "encounter:"+id in game.state.removed: return {}
	var rows: Array = scene.layout.data.encounters.filter(func(spec): return spec.id == id)
	if not require(rows.size() == 1,"authored encounter identity"): return {}
	var spec: Dictionary = rows[0]
	var cell: Vector2 = Vector2(player.position.x,player.position.z)/4.0
	var region: Array = spec.region
	require(current() and id in GROUPS and not activated.has(id) and stack("/main.gd","_process") and not stack("/enemy.gd","take_damage") and cell.is_equal_approx(cell.clamp(Vector2(region[0],region[1]),Vector2(region[2],region[3]))) and spec.requires.all(func(key): return key in keys),"actual inclusive region/key encounter: "+id)
	return spec

func after_encounter(spec: Dictionary) -> void:
	if spec.is_empty(): return
	activated[spec.id] = [Engine.get_physics_frames(),player.position,keys.duplicate()]
	removed.append("encounter:"+spec.id)
	for node in game.enemies:
		if node.id in spec.enemy_ids: require(actor(node) and node.hp == node.max_hp and node.active and node.alerted,"original region activation: "+node.id)
	for id in spec.cue.light_ids: require(scene.machine_lights.has(id) and scene.machine_lights[id].light_color == Color(1.0,0.28,0.1),"actual encounter cue light")

# A small testable consume-once primitive. Native caller/map checks surround its use.
static func claim(used: Dictionary, token: Dictionary, source_id: int, victim_id: int, rid: RID, tick: int, map_id: int, caller: String) -> bool:
	if token.is_empty() or str(token.get("key","")).is_empty() or token.get("source_id",0) != source_id or token.get("victim_id",0) != victim_id or token.get("rid") != rid or token.get("tick",-1) != tick or token.get("map_id",0) != map_id or token.get("caller","") != caller or used.has(token.get("key","")): return false
	used[token.key] = true
	return true

func contact_token(source, victim, hit: Dictionary, key: String, caller: String, amount: int) -> Dictionary:
	return {"source":source,"source_id":source.get_instance_id(),"victim_id":victim.get_instance_id(),"rid":hit.get("rid"),"tick":Engine.get_physics_frames(),"map_id":level_id,"caller":caller,"key":key,"amount":amount,"hit":hit}

func observe_damage(victim, source, amount: int, hit: Dictionary, mode: String, caller: String) -> void:
	if not require(actor(victim) and victim.hp > 0 and hp.get(victim.id,-1) == victim.hp and Engine.is_in_physics_frame() and hit.get("collider") == victim and hit.get("rid") == victim.get_rid() and is_instance_valid(source),"native pre-damage identity/HP/RID"): return
	require(victim.active and activated.has(victim.encounter_id) if originals.has(victim.id) else summons.has(victim.id),"only earned original/summoned targets")
	var after: int = maxi(0,victim.hp-amount)
	var record: Dictionary = {"victim_id":victim.get_instance_id(),"source_id":source.get_instance_id(),"tick":Engine.get_physics_frames(),"rid":hit.rid,"amount":amount,"before":victim.hp,"after":after,"mode":mode,"caller":caller,"position":hit.position}
	damage.append([victim.id,record.duplicate(true)])
	hp[victim.id] = after
	if after == 0:
		require(not lethal.has(victim.id),"one pending native lethal transaction")
		lethal[victim.id] = record

func observe_contact(source, hit: Dictionary, amount: int, caller: String, key: String) -> void:
	var victim = hit.get("collider")
	if not is_instance_valid(victim) or victim != player and not actor(victim): return
	var token: Dictionary = contact_token(source,victim,hit,key,caller,amount)
	if victim == player:
		require(pending_player.is_empty(),"single synchronous player contact")
		pending_player = token
	else:
		require(claim(used_contacts,token,source.get_instance_id(),victim.get_instance_id(),victim.get_rid(),Engine.get_physics_frames(),level_id,caller),"once-only enemy native contact")
		observe_damage(victim,source,amount,hit,"infighting",caller)

func before_enemy(node, event: String) -> void:
	# Births can precede this callback in the same physics tick.
	if current() and ok: register_summons()
	require(current() and actor(node) and node.active and Engine.is_in_physics_frame() and stack("/enemy.gd","_event"),"production synchronous original/born enemy event")
	if not ok: return
	events.append([node.id,event,Engine.get_physics_frames(),node.hp])
	require(events.size() <= 4096,"bounded event evidence")
	if event == "attack":
		if not require(stack("/enemy.gd","_release_attack") and node._released and node._committed_aim.is_finite(),"committed native attack release"): return
		if node.kind == "worker":
			var origin: Vector3 = node.global_position+Vector3.UP*1.4
			var end: Vector3 = origin+(node._committed_aim-origin).normalized()*30.0
			var query = PhysicsRayQueryParameters3D.create(origin,end,1|2|4)
			query.exclude = [node.get_rid()]
			query.hit_from_inside = true
			observe_contact(node,scene.get_world_3d().direct_space_state.intersect_ray(query),10,"worker",node.id+":worker:"+str(Engine.get_physics_frames()))
		if node.kind == "summoner":
			require(node.id == OWNER and node._summon_budget() > 0,"production ritual has real budget")
			rituals[node.id] = [Engine.get_physics_frames(),node._summoned_total,node._summon_budget(),node._committed_target.get_instance_id()]
	if event == "melee_contact":
		if not require(node.kind in ["crawler","brute"] and node._rush_hit and stack("/enemy.gd","_try_melee") and is_instance_valid(node._committed_target),"committed native rush contact"): return
		var query = PhysicsRayQueryParameters3D.create(node.global_position+Vector3.UP*0.6,node._committed_target.global_position+Vector3.UP*0.7,1|2|4)
		query.exclude = [node.get_rid()]
		query.hit_from_inside = true
		observe_contact(node,scene.get_world_3d().direct_space_state.intersect_ray(query),24 if node.kind == "brute" else 12,"melee",node.id+":melee:"+str(Engine.get_physics_frames()))
	if event == "death":
		var record: Dictionary = lethal.get(node.id,{})
		require(not record.is_empty() and record.get("victim_id",0) == node.get_instance_id() and record.get("tick",-1) == Engine.get_physics_frames() and record.get("rid") == node.get_rid() and record.get("after",-1) == 0 and stack("/enemy.gd","take_damage") and node.hp == 0 and node.collision_layer == 0 and node.collision_mask == 0 and game.state.removed.count(node.id) == 1,"once-only observed native lethal result")
		var caller: String = record.get("caller","")
		require(stack("/player.gd","fire") if caller == "player" else stack("/projectile.gd","_physics_process") if caller == "projectile" else stack("/enemy.gd","_attack") and stack("/enemy.gd","_release_attack" if caller == "worker" else "_try_melee"),"lethal transaction caller still on production stack")
		deaths[node.id] = deaths.get(node.id,0)+1
		finishes[node.id] = record.get("mode","unproven")
		removed.append(node.id)
		lethal.erase(node.id)
		require(deaths[node.id] == 1 and finishes[node.id] in ["player","infighting"],"genuine unique death provenance")

func after_aim(origin: Vector3, max_range: float, melee: bool, result: Dictionary) -> void:
	if not stack("/player.gd","fire"): return
	require(current() and stack("/player.gd","_physics_process") and Input.is_action_pressed("fire") and game.state.weapon == 1 and not melee and max_range == 140.0 and not shots.is_empty() and shots[-1][0] == Engine.get_physics_frames(),"committed native pistol aim")
	var query = PhysicsRayQueryParameters3D.create(origin,origin+result.direction*max_range,1|4)
	query.exclude = [player.get_rid()]
	var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(query)
	require(result.contact == hit,"same native actual resolved shot ray")
	var victim = hit.get("collider")
	if actor(victim) and victim.hp > 0: observe_damage(victim,player,22,hit,"player","player")

func before_projectile(projectile: Node3D, event: String, data: Dictionary) -> void:
	# Births can precede this callback in the same physics tick.
	if current() and ok: register_summons()
	var id: int = projectile.get_instance_id()
	var source = projectile.shooter
	require(current() and OS.is_debug_build() and Engine.is_in_physics_frame() and actor(source) and projectile.get_script() == preload("res://scripts/projectile.gd") and projectile.game == game and projectile._current_map() and projectile.get_parent() == scene and projectile.is_physics_processing() and data.get("projectile") == projectile and data.get("source") == source and data.get("map") == scene and data.get("player") == player and data.get("tick",-1) == Engine.get_physics_frames() and data.get("position") == projectile.global_position and data.get("velocity") == projectile.velocity and data.get("lifetime") == projectile.lifetime and data.get("blast_damage",-1) == 0 and projectile.blast_damage == 0 and projectile.velocity.is_finite() and is_equal_approx(projectile.velocity.length(),12.0) and projectile.lifetime > 0 and projectile.lifetime <= 4.0,"actual current-map finite native projectile callback")
	if not ok: return
	if event == "configured_birth":
		require(not births.has(id) and source.hp > 0 and source.active and source.kind == "caster" and stack("/enemy.gd","_release_attack") and stack("/projectile.gd","configure") and data.origin == source.global_position+Vector3.UP*1.4 and data.origin == projectile.global_position and data.destination == source._committed_aim and data.origin.is_finite() and data.destination.is_finite() and projectile.velocity.is_equal_approx((data.destination-data.origin).normalized()*12.0) and projectile.lifetime == 4.0 and births.size() < 160,"production caster projectile birth")
		births[id] = [weakref(projectile),source.get_instance_id(),Engine.get_physics_frames()]
	else:
		var hit: Dictionary = data.get("hit",{})
		var victim = hit.get("collider")
		require(event in ["queued_player_contact","queued_enemy_contact"] and births.has(id) and not contacts.has(id) and births[id][0].get_ref() == projectile and births[id][1] == source.get_instance_id() and Engine.get_physics_frames()-int(births[id][2]) <= 241 and projectile.is_queued_for_deletion() and stack("/projectile.gd","_physics_process") and (victim == player if event == "queued_player_contact" else actor(victim) and victim.hp > 0 and victim != source) and hit.get("rid") == victim.get_rid() and data.ray_start.is_finite() and data.ray_end.is_equal_approx(data.ray_start+projectile.velocity*minf(1.0/60.0,projectile.lifetime)),"once-only native queued projectile contact")
		if not ok: return
		var query = PhysicsRayQueryParameters3D.create(data.ray_start,data.ray_end,1|2|4)
		query.exclude = [source.get_rid()]
		query.hit_from_inside = true
		require(scene.get_world_3d().direct_space_state.intersect_ray(query) == hit,"repeated actual swept projectile ray/RID")
		contacts[id] = [event,source.id,victim.get_instance_id(),Engine.get_physics_frames(),hit.position,hit.rid]
		observe_contact(source,hit,14,"projectile","projectile:"+str(id))

func before_hurt(amount: int) -> void:
	var token: Dictionary = pending_player
	var source = token.get("source")
	var caller: String = token.get("caller","")
	require(current() and Engine.is_in_physics_frame() and game.budget() == ledger and actor(source) and amount == token.get("amount",-1) and game.state.difficulty == 1 and (stack("/projectile.gd","_physics_process") if caller == "projectile" else stack("/enemy.gd","_attack") and stack("/enemy.gd","_release_attack" if caller == "worker" else "_try_melee")),"native committed damage source/caller/amount")
	if not ok: return
	require(claim(used_contacts,token,source.get_instance_id(),player_id,player.get_rid(),Engine.get_physics_frames(),level_id,caller),"consume player native contact exactly once")
	pending_player = {}
	var absorbed: int = mini(int(ledger.armor),int(amount/3))
	ledger.armor -= absorbed
	ledger.health = maxi(0,int(ledger.health)-amount+absorbed)
	hurts.append([Engine.get_physics_frames(),source.id,amount,absorbed,token.hit.position,token.rid,caller])

func after_hurt() -> void:
	require(game.budget() == ledger and ledger.health > 0,"independent armor/HP debit and survival")

func before_interact() -> void:
	var spec: Dictionary = game.nearest_interaction()
	require(current() and Engine.is_in_physics_frame() and Input.is_action_pressed("interact") and stack("/player.gd","_physics_process") and spec == BLOOD and intent == BLOOD.id and inputs.is_empty(),"only queued physical rebound E Blood interaction")
	inputs.append([spec.get("id",""),Engine.get_physics_frames(),player.position,player.rotation.y,player.camera.rotation.x])

func before_key(id: String) -> void:
	require(current() and id == BLOOD.id and keys.is_empty() and intent == id and stack("/main.gd","interact") and stack("/player.gd","_physics_process") and Engine.is_in_physics_frame() and Input.is_action_pressed("interact") and game.nearest_interaction() == BLOOD,"real original Blood key through native interaction")

func after_key(id: String) -> void:
	keys.append("blood")
	removed.append(id)
	require(game.state.keys == keys and game.state.removed.count(id) == 1 and not scene.markers.has(id) and game.budget() == ledger,"real Blood marker/key retirement without resource grant")
	for light in ["ossuary_bridge_feed","ossuary_bridge_core"]: require(scene.machine_lights[light].light_color == Color(1.0,0.76,0.44),"earned warmed rib-bridge light")

func forbidden(kind: String) -> void:
	match kind:
		"save": saves += 1
		"capture": captures += 1
		"mouse": mouse_attempts += 1
		"start": starts += 1
		"restart": restarts += 1
	require(false,"forbidden transport side effect: "+kind)

func register_summons() -> void:
	for node in game.enemies:
		if bindings.has(node.id): continue
		var owner_rows: Array = game.enemies.filter(func(candidate): return candidate.id == OWNER)
		if not require(owner_rows.size() == 1 and rituals.has(OWNER),"birth requires witnessed original summoner release"): return
		var owner = owner_rows[0]
		var ritual: Array = rituals[OWNER]
		var number: int = int(node.id.trim_prefix(OWNER+"_add_"))
		var tick: int = Engine.get_physics_frames()
		require(actor(owner) and owner.kind == "summoner" and node.id == OWNER+"_add_"+str(number) and node._summon_owner_id == OWNER and node.kind == "crawler" and node.get_script() == game.Enemy and number == summons.size()+1 and number > int(ritual[1]) and number <= owner._summoned_total and number-int(ritual[1]) <= int(ritual[2]) and number <= 6 and tick-int(ritual[0]) in [0,1] and node.hp == 50 and node.max_hp == 50 and node.active and node.alerted and node.encounter_id.is_empty() and node.target.get_instance_id() == ritual[3] and node.get_parent() == scene and node._current_map() and node.age <= 1.0/60.0+0.000001 and node.position.distance_to(owner.position) <= 2.5 and game.state.removed.count("summon:"+OWNER+":"+str(number)) == 1,"production budgeted sequential finite ritual birth")
		if not ok: return
		var capsule: CollisionShape3D = node.get_child(0)
		bindings[node.id] = [node.get_instance_id(),capsule.get_instance_id(),capsule.shape.get_instance_id()]
		hp[node.id] = 50
		summons[node.id] = [OWNER,number,tick,weakref(node),node.position,ritual.duplicate()]
		removed.append("summon:"+OWNER+":"+str(number))
	var living: Array = game.enemies.filter(func(node): return node.hp > 0 and not node._summon_owner_id.is_empty())
	require(living.size() <= 4 and living.filter(func(node): return node._summon_owner_id == OWNER).size() <= 2 and summons.size() <= 6,"production global4/owner2/lifetime6 summon limits")
	for node in game.enemies:
		if node.id == OWNER: require(node._summoned_total == summons.size(),"all actual summoner births independently reconciled")

func all_dead(group: String) -> bool:
	return activated.has(group) and game.enemies.filter(func(node): return node.encounter_id == group or group == GROUPS[1] and node._summon_owner_id == OWNER).all(func(node): return actor(node) and node.hp == 0 and deaths.get(node.id,0) == 1 and finishes.get(node.id,"") in ["player","infighting"])

func validate() -> bool:
	if not require(current(),"same Main/Campaign/profile/current native scene and Player"): return false
	register_summons()
	require(scene.layout.data == map_image,"exact pinned original map geometry/schema remains unchanged")
	require(Engine.get_physics_frames()-epoch <= LIMIT and Time.get_ticks_usec()-wall <= SECONDS*1000000,"new-only frozen12000-frame/600s bounds")
	require(game.is_processing() and game.is_physics_processing() and player.is_physics_processing() and player.position.is_finite() and game.state.health > 0 and game.state.difficulty == 1,"live processing, finite pose and survival")
	var child_ids: Array = scene.get_children().filter(func(node): return node.get_script() == game.Enemy).map(func(node): return node.get_instance_id())
	var bound_ids: Array = bindings.values().map(func(binding): return binding[0])
	var listed_ids: Array = game.enemies.map(func(node): return node.get_instance_id())
	listed_ids.sort()
	child_ids.sort()
	bound_ids.sort()
	require(child_ids == bound_ids and listed_ids == bound_ids and game.enemies.size() == 27+summons.size() and bindings.size() == game.enemies.size(),"exact27 original identities plus every actual legitimate birth")
	for node in game.enemies:
		if not require(actor(node),"bound native actor identity"): return false
		var capsule: CollisionShape3D = node.get_child(0)
		var role: Array = ROLES[node.kind]
		var binding: Array = bindings[node.id]
		require(node.is_physics_processing() and capsule.get_instance_id() == binding[1] and capsule.shape.get_instance_id() == binding[2] and not capsule.disabled and capsule.shape is CapsuleShape3D and absf(capsule.shape.radius-role[1]) < 0.000001 and absf(capsule.shape.height-role[2]) < 0.000001 and capsule.position == Vector3(0,capsule.shape.height/2,0) and node.position.is_finite() and is_finite(node.rotation.y) and node.hp == hp[node.id] and node.hp >= 0 and node.max_hp == role[0],"independent native HP/role/capsule/processing: "+node.id)
		if originals.has(node.id):
			var original: Array = originals[node.id]
			require(node.max_hp == original[3] and node.kind == original[4] and node.encounter_id == original[5] and node._summon_owner_id.is_empty() and node.age-original[2] >= float(Engine.get_physics_frames()-epoch-2)/60.0,"unchanged original identity/role/group/native age")
			if not activated.has(node.encounter_id): require(node.hp == node.max_hp and node.position == original[0] and node.rotation.y == original[1] and not node.active and not node.alerted,"unentered original dormant/fullHP/pose: "+node.id)
		if node.hp > 0:
			var floor_hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(node.position+Vector3.UP*0.5,node.position-Vector3.UP*6,1))
			require(node.collision_layer == 4 and node.collision_mask == 7 and not floor_hit.is_empty() and floor_hit.normal.y >= 0.7 and absf(node.position.y-floor_hit.position.y-(1.0 if node.kind == "caster" else 0.0)) <= (0.25 if node.kind == "caster" else 0.15),"actual native actor floor/collision support")
		else: require(deaths.get(node.id,0) == 1 and finishes.get(node.id,"") in ["player","infighting"] and node.collision_layer == 0 and node.collision_mask == 0 and game.state.removed.count(node.id) == 1,"all native once-only deaths retain provenance")
	for id in markers:
		var ref = markers[id].get_ref()
		if id in removed:
			require(not scene.markers.has(id) and (not is_instance_valid(ref) or ref.is_queued_for_deletion()),"claimed marker retired, awaiting actual drain: "+id)
		else: require(is_instance_valid(ref) and not ref.is_queued_for_deletion() and scene.markers.get(id) == ref and [ref.get_instance_id(),ref.transform] == marker_values[id],"uncollected marker identity/transform remains: "+id)
	for node in scene.get_children():
		if node.get_script() != preload("res://scripts/projectile.gd") or node.is_queued_for_deletion(): continue
		require(births.has(node.get_instance_id()) and births[node.get_instance_id()][0].get_ref() == node and actor(node.shooter) and node._current_map() and node.is_physics_processing() and node.lifetime > 0 and node.lifetime <= 4.0,"every live projectile has actual finite birth/shooter")
	var capsule: CollisionShape3D = player.get_child(0)
	var support: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(player.position+Vector3.UP*0.5,player.position-Vector3.UP*0.5,1))
	require(player.collision_layer == 2 and player.collision_mask == 5 and not capsule.disabled and capsule.shape is CapsuleShape3D and capsule.shape.radius == Vector3(0.32,0,0).x and capsule.shape.height == Vector3(1.65,0,0).x and capsule.position == Vector3(0,0.85,0) and not support.is_empty() and support.normal.y >= 0.7 and absf(player.position.y-support.position.y) <= 0.15,"original Player capsule and actual floor triangles")
	var actual_removed: Array = game.state.removed.duplicate()
	var expected_removed: Array = removed.duplicate()
	actual_removed.sort()
	expected_removed.sort()
	require(game.budget() == ledger and game.state.keys == keys and actual_removed == expected_removed and removed.all(func(id): return removed.count(id) == 1) and game.state.explored == explored and game.state.discoveries == [3,4] and game.state.owned_weapons == [0,1,2,3] and game.state.weapon == 1 and game.state.ammo[2] == 32 and game.state.ammo[3] == 120 and game.state.checkpoint_id == "entry" and game.state.checkpoint == checkpoint and game.state.level_start == start and game.state.actors == actor_image and FileAccess.get_sha256(profile) == saved_sha and saved_sha == SAVE_SHA and saves == 0 and captures == 0 and mouse_attempts == 0 and starts == 0 and restarts == 0 and pending_player.is_empty() and lethal.is_empty(),"independent resources/HP/Survey/removed and immutable recovery/disk envelopes")
	return ok
