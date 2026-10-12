extends "res://tests/test_foundry_earned_walk.gd"

const P_LIMIT = 1800
const P_SECONDS = 40
const P_FIGHT_LIMIT = 360
const P_MAP_SHA = "6fb899edee2cecd05bce408fdaf6976819ed19246e59de56b2f00fa318b234c4"
const P_ENTRY = [[22.5,30.5],[21.5,29.5],[21.0,27.0],[20.5,25.5],[18.5,24.5],[16.5,24.5],[15.5,24.5],[16.5,24.5]]
const P_SUPPLIES = ["processional_entry_rivets","processional_scattergun","processional_nave_health"]

class EntryMain:
	extends "res://tests/test_foundry_earned_walk.gd".FoundryMain
	var entry_enabled: bool = false
	var p_ok: bool = true
	var p_ticks: int = 0
	var p_shots: Array = [0,0,0,0,0,0]
	var p_last: Array = [-1,-1,-1,-1,-1,-1]
	var p_slots: Array = [-1.0,-1.0,-1.0,-1.0,-1.0,-1.0]
	var p_selected: int = -1
	var p_ledger: Dictionary = {}
	var p_originals: Dictionary = {}
	var p_consumed: Dictionary = {}
	var p_pickups: Dictionary = {}
	var p_deaths: Dictionary = {}
	var p_finishes: Dictionary = {}
	var p_attacks: Dictionary = {}
	var p_damage_attacks: Dictionary = {}
	static func entry_slot(tick: int, last: int, nominal: float, weapon: int) -> float:
		if weapon not in [1,2]: return -1.0
		var interval: float = Player.WEAPONS[weapon].interval*60.0
		if last >= 0 and (tick <= last or float(tick)+0.000001 < (nominal if nominal >= 0.0 else float(last)+interval)): return -1.0
		var result: float = float(tick)+interval if nominal < 0.0 else nominal+interval
		if result <= float(tick)+0.000001: result += (floorf((float(tick)+0.000001-result)/interval)+1.0)*interval
		return result
	func _physics_process(delta: float) -> void:
		super._physics_process(delta)
		if entry_enabled and playing and state.level_index == 2 and not get_tree().paused:
			p_ticks += 1
			p_ok = p_ok and absf(delta-1.0/60.0) < 0.000001
			if not Input.is_action_pressed("fire") or p_selected != state.weapon:
				p_slots.fill(-1.0)
			p_selected = state.weapon
	func shot(weapon: int) -> void:
		if entry_enabled:
			if weapon not in [1,2]:
				p_ok = false
				super.shot(weapon)
				return
			var tick: int = Engine.get_physics_frames()
			p_slots[weapon] = entry_slot(tick,p_last[weapon],p_slots[weapon],weapon)
			var expected: Dictionary = p_ledger.duplicate(true)
			expected.ammo[weapon] -= 1
			p_ok = p_ok and Engine.is_in_physics_frame() and playing and state.level_index == 2 and is_instance_valid(player) and player._current_map() and state.weapon == weapon and weapon in state.owned_weapons and Input.is_action_pressed("fire") and not player._fire_release_required and p_slots[weapon] >= 0.0 and player.shot_age(weapon) == 0.0 and player._last_shots[weapon] == player.active_play_time and budget() == expected and expected.ammo[weapon] >= 0 and p_consumed.get("processional_scattergun",0) == 1 and weapon == 2
			p_ledger = expected
			p_shots[weapon] += 1
			p_last[weapon] = tick
		# Legacy pistol-only shot_ok is not an entry oracle; Main noise/effects still dispatch.
		super.shot(weapon)
	func collect_pickup(id: String) -> void:
		if not entry_enabled:
			super.collect_pickup(id)
			return
		var matches: Array = level.layout.data.pickups.filter(func(spec): return spec.id == id)
		p_ok = p_ok and Engine.is_in_physics_frame() and playing and state.level_index == 2 and player._current_map() and matches.size() == 1 and id in ["processional_entry_rivets","processional_scattergun","processional_nave_health"] and budget() == p_ledger
		if matches.size() != 1:
			super.collect_pickup(id)
			return
		var spec: Dictionary = matches[0]
		var before: Dictionary = p_ledger.duplicate(true)
		var expected: Dictionary = before.duplicate(true)
		var weapon: int = int(spec.get("weapon",1))
		var ammunition: bool = spec.kind in ["weapon","ammo"]
		var old: int = int(expected.ammo[weapon]) if ammunition else int(expected[spec.kind])
		var cap: int = Player.WEAPONS[weapon].max_ammo if ammunition else 100 if spec.kind == "health" else 200
		var acquired: bool = spec.kind == "weapon" and not weapon in expected.owned_weapons
		var consumed: bool = not id in state.removed and (acquired or old < cap)
		var rejected: bool = not id in state.removed and not consumed
		var original_marker = level.markers.get(id)
		if consumed:
			p_ok = p_ok and is_instance_valid(original_marker) and original_marker.get_parent() == level and not original_marker.is_queued_for_deletion()
			if acquired:
				expected.owned_weapons.append(weapon)
				expected.weapon = weapon
			if ammunition: expected.ammo[weapon] = mini(cap,old+int(spec.amount))
			else: expected[spec.kind] = mini(cap,old+int(spec.amount))
		super.collect_pickup(id)
		p_ok = p_ok and spec.kind in ["weapon","ammo","health","armor"] and budget() == expected and state.removed.count(id) == (1 if consumed or p_consumed.has(id) else 0)
		if consumed:
			p_consumed[id] = p_consumed.get(id,0)+1
			p_pickups[id] = {"before":before,"after":expected.duplicate(true)}
			p_ok = p_ok and p_consumed[id] == 1 and not level.markers.has(id)
		if rejected:
			p_ok = p_ok and is_instance_valid(original_marker) and level.markers.get(id) == original_marker and original_marker.get_parent() == level and not original_marker.is_queued_for_deletion()
		p_ledger = expected
	func enemy_event(actor, event: String) -> void:
		if entry_enabled:
			p_ok = p_ok and Engine.is_in_physics_frame() and playing and actor._current_map() and actor.active and p_originals.has(actor.id) and actor.get_instance_id() == p_originals.get(actor.id,{}).get("instance",-1) and actor.kind in ["worker","crawler"]
			if event == "attack" and actor._committed_target == player: p_attacks[actor.id] = Engine.get_physics_frames()
			if event == "death":
				p_deaths[actor.id] = p_deaths.get(actor.id,0)+1
				p_ok = p_ok and actor.hp == 0 and actor.collision_layer == 0 and actor.collision_mask == 0 and state.removed.count(actor.id) == 1 and p_deaths[actor.id] == 1
				p_finishes[actor.id] = state.weapon == 2 and Input.is_action_pressed("fire") and p_last[2] == Engine.get_physics_frames() and player.shot_age(2) == 0.0 and actor.target == player and aim_observation.get("actor_id","") == actor.id and aim_observation.get("tick",-1) == Engine.get_physics_frames() and aim_observation.get("level") == level and aim_observation.get("player") == player and aim_observation.get("weapon",-1) == 2 and get_stack().any(func(frame): return str(frame.get("source","")).ends_with("/player.gd") and frame.get("function","") == "fire")
		super.enemy_event(actor,event)
	func hurt_player(amount: int) -> void:
		if not entry_enabled:
			super.hurt_player(amount)
			return
		var attack_key: String = ""
		for actor in enemies:
			var attack_tick: int = int(p_attacks.get(actor.id,-1000))
			var age: int = Engine.get_physics_frames()-attack_tick
			var key: String = actor.id+":"+str(attack_tick)
			if p_originals.has(actor.id) and actor.get_instance_id() == p_originals[actor.id].instance and actor._current_map() and actor.active and actor.hp > 0 and actor._committed_target == player and not p_damage_attacks.has(key) and age >= 0 and ((actor.kind == "worker" and amount == 10 and age == 0) or (actor.kind == "crawler" and amount == 12 and age <= 12)):
				attack_key = key
				break
		# shortcut: source-debug stack attribution only; packed-app attribution is separate.
		var stack_attack: bool = get_stack().any(func(frame): return str(frame.get("source","")).ends_with("/enemy.gd") and frame.get("function","") == "_attack")
		p_ok = p_ok and Engine.is_in_physics_frame() and not attack_key.is_empty() and stack_attack and state.difficulty == 1 and budget() == p_ledger
		if not attack_key.is_empty(): p_damage_attacks[attack_key] = true
		var expected: Dictionary = p_ledger.duplicate(true)
		var absorbed: int = mini(int(expected.armor),int(amount/3))
		expected.armor -= absorbed
		expected.health = maxi(0,int(expected.health)-(amount-absorbed))
		super.hurt_player(amount)
		p_ok = p_ok and budget() == expected
		p_ledger = expected

var entry_started: bool = false
var p_epoch: int = 0
var p_wall_us: int = 0
var p_start_shots: int = 0
var p_start_hits: int = 0
var p_markers: Dictionary = {}
var p_recovery: Dictionary = {}
var p_start: Dictionary = {}
var p_main_id: int = 0
var p_profile: String = ""

func _initialize() -> void:
	for weapon in [1,2]:
		var interval: float = WeaponPlayer.WEAPONS[weapon].interval*60.0
		var nominal: float = EntryMain.entry_slot(100,-1,-1.0,weapon)
		if not expect(nominal == 100.0+interval and EntryMain.entry_slot(100,100,nominal,weapon) < 0.0 and EntryMain.entry_slot(ceili(nominal)-1,100,nominal,weapon) < 0.0 and EntryMain.entry_slot(ceili(nominal),100,nominal,weapon) > nominal and EntryMain.entry_slot(ceili(nominal)-1,100,-1.0,weapon) < 0.0,"Per-weapon cadence rejects early/same-tick shots and release/switch cooldown refunds"):
			quit(1)
			return
	if not expect(EntryMain.entry_slot(100,-1,-1.0,0) < 0.0 and EntryMain.entry_slot(100,-1,-1.0,3) < 0.0,"Entry rejects unearned weapons"):
		quit(1)
		return
	super._initialize()

func run() -> void:
	prefix = "user://processional_earned_entry_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	if not await walk_to_processional_entry(EntryMain.new(),prefix):
		await finish(1)
		return
	print("PASS source-native earned Processional ENTRY only: actual Descend, capped rivets, acquired scattergun, capped healing and input-fired original worker00 finish. Virtual Input/scripted aim; not physical input, third-level exit/campaign, rendered quality, audio/performance or packed-app acceptance.")
	await finish(0)

func walk_to_processional_entry(observer, profile_prefix: String) -> bool:
	prefix = profile_prefix
	if not await walk_to_foundry_exit(observer,prefix) or not await descend_processional():
		return false
	for cell in P_ENTRY:
		var started: int = east_elapsed()
		if not await east_route([cell]) or not expect(east_elapsed()-started <= HOP_LIMIT,"Processional hop includes its final process wait within 240 frames"):
			return false
	if not await entry_fight() or not await entry_result():
		return false
	return true

func descend_processional() -> bool:
	var carried: Dictionary = resource_snapshot()
	if not expect(carried == {"health":93,"armor":89,"ammo":[0,164,0,0,0,0],"owned_weapons":[0,1],"weapon":1,"keys":[]} and game.f_ok and game.f_deaths.size() == 23 and retired.all(func(reference): return reference.get_ref() == null),"Exact verified two-map earned exit precedes observer handoff"): return false
	p_main_id = game.get_instance_id()
	p_profile = game.progress_path
	release_actions()
	# Only the completed Foundry observer is disabled; production super dispatch is retained.
	if not press_menu("Descend to The Processional"): return false
	for frame in range(118):
		if game.playing and not game.placement_pending and is_instance_valid(game.player): break
		await physics_frame
	await physics_frame
	await physics_frame
	if not expect(game.playing and not paused and not game.placement_pending and game.state.level_index == 2 and game.get_instance_id() == p_main_id and game.progress_path == p_profile and resource_snapshot() == carried,"Actual Descend preserves Main/profile/earned resources and completes native placement within 120 frames"): return false
	game.foundry_enabled = false
	route_level = game.level
	route_player = game.player
	var data: Dictionary = route_level.layout.data
	if not expect(FileAccess.get_sha256("res://data/03_processional.json") == P_MAP_SHA and data.id == "processional" and data.spawn == [21.5,29.5] and data.cell_size == 4 and data.enemies.size() == 26 and WeaponPlayer.WEAPONS[2].name == "SCATTERGUN" and WeaponPlayer.WEAPONS[2].max_ammo == 32 and WeaponPlayer.WEAPONS[2].interval == 0.7 and WeaponPlayer.WEAPONS[2].useful_range == 8.0,"Pin authored Processional and actual first scattergun profile"): return false
	actors.clear()
	for actor in game.enemies:
		var specs: Array = data.enemies.filter(func(spec): return spec.id == actor.id and spec.kind == actor.kind)
		if not expect(specs.size() == 1 and not actors.has(actor.id) and actor.hp == (50 if actor.kind == "crawler" else 90) and actor.max_hp == actor.hp,"All 26 original actors retain authored role and full starting health"): return false
		actors[actor.id] = [actor.get_instance_id(),actor.age]
		game.p_originals[actor.id] = {"instance":actor.get_instance_id(),"age":actor.age,"kind":actor.kind,"max_hp":actor.max_hp}
	for id in route_level.markers: p_markers[id] = weakref(route_level.markers[id])
	if not expect(actors.size() == 26 and game.p_originals.size() == 26 and route_player.position.distance_to(route_level.layout.world_position(data.spawn)+Vector3.UP*0.04) < 0.1 and clear_point(data.spawn) != null and game.state.removed.is_empty() and game.state.keys.is_empty() and game.state.checkpoint_id == "entry","Native original spawn, clear capsule and unearned third-map triggers"): return false
	for id in P_SUPPLIES:
		if not expect(route_level.markers.has(id) and is_instance_valid(route_level.markers[id]),"Original entry supply marker exists: "+id): return false
	for recovery in [game.state.checkpoint,game.state.level_start]:
		for field in carried:
			if not expect(recovery.get(field) == carried[field],"Independent earned Processional entry recovery field: "+field): return false
	p_recovery = game.state.checkpoint.duplicate(true)
	p_start = game.state.level_start.duplicate(true)
	game.p_ledger = game.budget()
	p_start_shots = game.shots
	p_start_hits = game.hits
	p_epoch = Engine.get_physics_frames()
	p_wall_us = Time.get_ticks_usec()
	game.entry_enabled = true
	entry_started = true
	return live_route()

func east_elapsed() -> int:
	return Engine.get_physics_frames()-p_epoch if entry_started else super.east_elapsed()

func route_tick() -> bool:
	if not entry_started: return await super.route_tick()
	if not live_route(): return false
	await physics_frame
	return live_route()

func east_fire() -> bool:
	if not entry_started: return super.east_fire()
	Input.action_release("fire")
	game.west_firing_id = ""
	if game.p_consumed.get("processional_scattergun",0) != 1 or game.state.weapon != 2: return false
	var selected = null
	var nearest: float = WeaponPlayer.WEAPONS[2].useful_range+0.000001
	for actor in game.enemies:
		if not is_instance_valid(actor) or not actor._current_map() or not actor.active or actor.hp <= 0 or actor.kind not in ["worker","crawler"]: continue
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
	game.west_firing_id = selected.id
	Input.action_press("fire")
	return true

func live_route() -> bool:
	if not entry_started: return super.live_route()
	if not expect(east_elapsed() <= P_LIMIT and Time.get_ticks_usec()-p_wall_us <= P_SECONDS*1000000,"NATIVE RED frozen Processional entry 1800-native-frame/40-second budget includes process waits"): return false
	if not expect(not paused and game.playing and not game.placement_pending and game.state.level_index == 2 and game.get_instance_id() == p_main_id and game.progress_path == p_profile and is_instance_valid(route_level) and is_instance_valid(route_player) and game.level == route_level and game.player == route_player and route_player._current_map() and not route_level.is_queued_for_deletion() and game.is_processing() and game.is_physics_processing() and route_player.is_physics_processing() and game.enemies.size() == 26,"Entry retains automatic native original Main/Player/map; no replacement or recovery"): return false
	var seen: Dictionary = {}
	for actor in game.enemies:
		if not expect(is_instance_valid(actor) and game.p_originals.has(actor.id) and not seen.has(actor.id),"Retain each distinct original Processional actor"): return false
		var pin: Dictionary = game.p_originals[actor.id]
		if not expect(actor.get_instance_id() == pin.instance and actor.kind == pin.kind and actor.max_hp == pin.max_hp and actor.hp >= 0 and actor.hp <= pin.max_hp and actor._current_map() and actor.is_physics_processing() and actor.age-pin.age >= float(east_elapsed()-2)/60.0,"Original actor retains native identity/role/HP/automatic age: "+actor.id): return false
		seen[actor.id] = true
		if actor.hp == 0:
			if not expect(game.p_deaths.get(actor.id,0) == 1 and game.state.removed.count(actor.id) == 1 and actor.collision_layer == 0 and actor.collision_mask == 0,"Natural original death retires collision/removal once"): return false
		elif not expect(actor.collision_layer == 4 and actor.collision_mask == 7,"Living original actor retains collision"): return false
		if actor.kind == "caster" and not expect(not actor.active and actor.hp == pin.max_hp and not game.p_attacks.has(actor.id),"Entry never activates original branch/seal casters"): return false
	if not expect(not route_level.get_children().any(func(node): return node.get_script() == preload("res://scripts/projectile.gd")),"No new caster projectile is allowed in entry-only scope"): return false
	for id in game.state.removed:
		if not expect(game.p_consumed.has(id) or game.p_deaths.has(id),"No key/story/checkpoint/door/encounter grant in entry-only scope: "+id): return false
	var acquired: bool = game.p_consumed.get("processional_scattergun",0) == 1
	return expect(seen.size() == 26 and game.p_ok and game.rate_ok and game.feedback_ok and game.shot_clock_ok and game.p_ticks >= east_elapsed()-2 and game.shots-p_start_shots == game.p_shots[1]+game.p_shots[2] and game.budget() == game.p_ledger and game.state.health > 0 and game.state.health <= 100 and game.state.armor >= 0 and game.state.armor <= 200 and game.state.ammo[1] >= 0 and game.state.ammo[1] <= 180 and game.state.ammo[2] >= 0 and game.state.ammo[2] <= 32 and game.state.ammo.slice(3) == [0,0,0] and game.state.ammo[0] == 0 and game.state.owned_weapons == ([0,1,2] if acquired else [0,1]) and game.state.weapon == (2 if acquired else 1) and game.state.keys.is_empty() and game.state.discoveries.is_empty() and game.state.checkpoint_id == "entry" and game.state.checkpoint == p_recovery and game.state.level_start == p_start,"Independent entry cadence/capped callback ledger and untouched recovery envelopes remain exact")

func entry_fight() -> bool:
	var worker = game.enemies.filter(func(actor): return actor.id == "processional_enemy_00")[0]
	if worker.hp > 0:
		var started: int = east_elapsed()
		if not await east_route([[18.0,24.5]]) or not expect(east_elapsed()-started <= HOP_LIMIT,"Entry approach remains within frozen 240-frame hop"): return false
	for frame in range(P_FIGHT_LIMIT):
		if not live_route(): return false
		if worker.hp == 0: break
		release_actions()
		east_fire() # No visible useful-range target means released fire, never fabricated damage.
		var approach: Vector3 = worker.global_position-route_player.global_position
		approach.y = 0
		if approach.length() > 5.0:
			# Original workers strafe/retreat inside their 8m standoff; pursue through real Input.
			var axes: Vector3 = route_player.basis.inverse()*approach.normalized()
			Input.action_press("move_left",maxf(0,-axes.x))
			Input.action_press("move_right",maxf(0,axes.x))
			Input.action_press("move_forward",maxf(0,-axes.z))
			Input.action_press("move_back",maxf(0,axes.z))
		if not await route_tick(): return false
	release_actions()
	return expect(worker.hp == 0 and game.p_deaths.get(worker.id,0) == 1 and game.p_finishes.get(worker.id,false),"Original worker00 naturally finishes once through same-physics scattergun input/aim/death within 360 fight frames")

func entry_result() -> bool:
	release_actions()
	await process_frame
	if not live_route(): return false
	for id in P_SUPPLIES:
		if not expect(game.p_consumed.get(id,0) == 1 and game.state.removed.count(id) == 1 and not route_level.markers.has(id) and p_markers[id].get_ref() == null,"Earned original entry supply drains once: "+id): return false
	var rivets: Dictionary = game.p_pickups.processional_entry_rivets
	var gun: Dictionary = game.p_pickups.processional_scattergun
	var healing: Dictionary = game.p_pickups.processional_nave_health
	if not expect(rivets.before.ammo[1] == 164 and rivets.after.ammo[1] == 180 and gun.before.ammo[2] == 0 and gun.after.ammo[2] == 16 and gun.before.owned_weapons == [0,1] and gun.after.owned_weapons == [0,1,2] and gun.after.weapon == 2 and healing.before.health < 100 and healing.after.health == 100 and healing.after.health == mini(100,int(healing.before.health)+30) and game.p_shots[1] == 0 and game.p_shots[2] > 0 and game.state.ammo[2] == 16-game.p_shots[2] and game.hits > p_start_hits,"Actual capped 35 rivets, earned 16-shell acquisition/autoselect, healing and consumed scattershot feedback"): return false
	print("PROCESSIONAL_EARNED_ENTRY native_frames=",east_elapsed()," shots=",game.p_shots," consumed=",game.p_consumed," deaths=",game.p_deaths," resources=",game.p_ledger)
	var view: Dictionary = game.hud.view
	return expect(view.get("weapon_name","") == "SCATTERGUN" and view.get("ammo","") == str(game.state.ammo[2]) and view.get("capacity","") == "CAP 32" and view.arsenal[2].owned and view.arsenal[2].selected,"Actual automatic HUD fields select earned scattergun and current shells; code-only, not rendered-quality evidence")
