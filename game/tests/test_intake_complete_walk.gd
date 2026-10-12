extends "res://tests/test_intake_west_seal.gd"

const EAST_LIMIT = 3600
const BELL_RETURN = [[6.0,13.5],[6.0,10.5],[6.0,8.5],[9.0,8.5],[11.5,8.5],[14.0,8.5],[14.0,6.75]]
const SOUTH_CROSS = [[14.0,8.5],[13.5,10.5],[13.5,13.5],[13.5,15.5],[12.0,15.5],[12.0,16.0],[12.0,15.5],[13.5,15.5],[13.5,19.0],[13.5,22.5],[16.5,22.5],[19.5,22.5],[22.5,22.5]]
const SIPHON_ASCENT = [[22.5,20.5],[22.5,18.5],[22.5,15.5],[22.5,12.5],[24.5,12.5]]
const NORTH_RETURN = [[23.5,12.5],[23.5,10.5],[23.5,8.5],[20.5,8.5],[17.5,8.5],[17.5,10.5],[14.0,10.5],[14.0,8.5],[14.0,6.5]]
const EXIT_APPROACH = [[14.0,4.5],[14.5,2.0]]

class CompleteMain:
	extends "res://tests/test_intake_west_seal.gd".WestMain
	var shot_clock_ok: bool = true
	var nave_calls: int = 0
	var nave_reward_ok: bool = true
	func collect_pickup(id: String) -> void:
		var before: int = state.health
		super.collect_pickup(id)
		if id == "nave_health":
			nave_calls += 1
			nave_reward_ok = nave_reward_ok and before < 100 and state.health == mini(100,before+30) and state.removed.count(id) == 1
	func shot(weapon: int) -> void:
		shot_clock_ok = shot_clock_ok and is_instance_valid(player) and player._current_map() and is_zero_approx(player.shot_age(weapon)) and player.active_play_time > 0.0
		super.shot(weapon)

var east_started: bool = false
var east_ticks: int = 0
var east_origin_frame: int = 0
var east_start_shots: int = 0
var nave_collected: bool = false
var east_last_health: int = 0
var east_damage: Dictionary = {}
var east_hp: Dictionary = {}
var markers_before: Dictionary = {}

func run() -> void:
	prefix = "user://intake_complete_walk_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	# Parent owns the unchanged prefix extraction; never copy it or call its quitting run().
	if not expect(has_method("walk_to_west_seal"),"DEPENDENCY NOT READY: parent must extract west walk_to_west_seal(observer, profile_prefix) -> bool without changing its assertions"):
		await finish(1)
		return
	if not await call("walk_to_west_seal",CompleteMain.new(),prefix):
		await finish(1)
		return
	if not super.live_route() or not pin_east():
		await finish(1)
		return
	east_start_shots = game.shots
	east_last_health = game.state.health
	east_origin_frame = Engine.get_physics_frames()
	for actor in game.enemies:
		east_hp[actor.id] = actor.hp
		east_damage[actor.id] = 0
	east_started = true
	if not await select_pistol() or not await east_route(BELL_RETURN) or not await gate_input(false) or not await east_route(SOUTH_CROSS):
		await finish(1)
		return
	if not expect(game.nave_calls == 1 and game.nave_reward_ok,"Exact once-only capped nave healing must occur at the actual production pickup callback"):
		await finish(1)
		return
	if not expect(game.state.removed.count("nave_health") == 1 and not route_level.markers.has("nave_health") and markers_before.nave_health.get_ref() == null,"Earn nave healing through actual once-only proximity and marker drain, not a resource grant") or not await east_route(SIPHON_ASCENT):
		await finish(1)
		return
	if not await eastern_fight() or not await ivory_input() or not await east_route(NORTH_RETURN) or not await gate_input(true) or not await east_route(EXIT_APPROACH) or not await exit_input():
		await finish(1)
		return
	print("PASS source-native earned Intake candidate through original west prefix, east fight/ramp, ivory, authored gate and actual exit; virtual Input/scripted aim only. Not human/OS input, Foundry/campaign, GPU/audio/performance or packed-app acceptance.")
	await finish(0)

func pin_east() -> bool:
	var data: Dictionary = route_level.layout.data
	var ivory: Array = data.interactions.filter(func(spec): return spec.id == "ivory_key")
	var gates: Array = data.doors.filter(func(spec): return spec.id == "containment_gate")
	var exits: Array = data.interactions.filter(func(spec): return spec.id == "exit")
	var healing: Array = data.pickups.filter(func(spec): return spec.id == "nave_health")
	var worker: Array = data.enemies.filter(func(spec): return spec.id == "intake_enemy_15")
	if not expect(ivory.size() == 1 and ivory[0].kind == "key" and ivory[0].key == "ivory" and ivory[0].cell == [25.0,12.5] and gates.size() == 1 and gates[0].cell == [14.0,5.75] and gates[0].size == [8.2,5.0,0.6] and gates[0].requires == ["blood","ivory"] and gates[0].yaw == 0 and exits.size() == 1 and exits[0].kind == "exit" and exits[0].cell == [14.5,1.5] and exits[0].requires == ["blood","ivory"],"Pin actual ivory, physical containment gate and Intake exit"): return false
	if not expect(healing.size() == 1 and healing[0].kind == "health" and healing[0].amount == 30 and healing[0].cell == [12.0,16.0] and worker.size() == 1 and worker[0].kind == "worker" and worker[0].cell == [25.0,11.75],"Pin finite nave supply and original east worker15"): return false
	for id in ["ivory_key","nave_health","exit"]:
		if not expect(route_level.markers.has(id) and is_instance_valid(route_level.markers[id]) and route_level.markers[id].get_parent() == route_level and not id in game.state.removed,"Retain tangible original marker before east traversal: "+id): return false
		markers_before[id] = weakref(route_level.markers[id])
	return expect(game.state.keys == ["blood"] and game.state.discoveries.is_empty() and route_level.doors.has("containment_gate") and route_level.layout.world_position([22.5,12.5]).y == 2.0 and game.enemies.size() == 23,"Earned west prefix precedes uncollected upper ivory and closed physical gate")

func select_pistol() -> bool:
	var before: Dictionary = resource_snapshot()
	for pressed in [true,false]:
		action_input("weapon_2",pressed)
		if not await route_tick(): return false
	return expect(game.state.weapon == 1 and game.state.owned_weapons == [0,1] and game.state.ammo == before.ammo,"Production weapon_2 Input selects the earned pistol without granting inventory")

func action_input(action: String, pressed: bool) -> void:
	var event = InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func east_fire() -> bool:
	Input.action_release("fire")
	game.west_firing_id = ""
	var selected = null
	var nearest: float = WeaponPlayer.WEAPONS[1].range
	for actor in game.enemies:
		if not is_instance_valid(actor) or not actor._current_map() or not actor.active or actor.hp <= 0: continue
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

func east_route(cells: Array) -> bool:
	for cell in cells:
		var target: Vector3 = route_level.layout.world_position(cell)+Vector3.UP*0.04
		var hop_start: int = east_elapsed()
		while true:
			if not live_route() or not expect(east_elapsed()-hop_start < HOP_LIMIT,"NATIVE RED east clearance deadline cell="+str(cell)+" position="+str(route_player.position)): return false
			var clear: bool = clear_point(cell) != null
			var start: Vector3 = route_player.position
			var samples: int = ceili(start.distance_to(target)/0.5)
			for sample in range(samples+1):
				var point: Vector3 = start.lerp(target,float(sample)/maxi(1,samples))
				if clear_point([point.x/4.0,point.z/4.0]) == null: clear = false
			if clear: break
			release_actions()
			if not expect(east_fire(),"NATIVE RED blocked east leg lacks visible original combat target: "+str(cell)): return false
			if not await route_tick(): return false
		while Vector2(route_player.position.x-target.x,route_player.position.z-target.z).length() > 0.12:
			if not live_route() or not expect(east_elapsed()-hop_start < HOP_LIMIT,"NATIVE RED east movement deadline cell="+str(cell)+" position="+str(route_player.position)): return false
			release_actions()
			if not east_fire(): route_player.look_at(Vector3(target.x,route_player.position.y,target.z),Vector3.UP)
			var direction: Vector3 = target-route_player.position
			direction.y = 0
			var deadzone: float = 0.0
			for action in ["move_left","move_right","move_forward","move_back"]: deadzone += InputMap.action_get_deadzone(action)/4.0
			var axes: Vector3 = route_player.basis.inverse()*direction.normalized()*(deadzone+(1.0-deadzone)*minf(1.0,direction.length()*6.0/9.0))
			Input.action_press("move_right",maxf(0,axes.x))
			Input.action_press("move_left",maxf(0,-axes.x))
			Input.action_press("move_back",maxf(0,axes.z))
			Input.action_press("move_forward",maxf(0,-axes.z))
			if not await route_tick(): return false
		release_actions()
		for settling in range(12):
			if not expect(east_elapsed()-hop_start < HOP_LIMIT,"East settling shares the same 240-frame leg deadline"): return false
			east_fire()
			if not await route_tick(): return false
		release_actions()
		await process_frame
		if not live_route() or not expect(route_player.position.distance_to(target) < 0.2 and clear_point(cell) != null,"NATIVE RED east endpoint must settle on actual floor with native capsule clearance: "+str(cell)): return false
		print("INTAKE_EAST_HOP cell=",cell," east_ticks=",east_ticks," total_ticks=",walk_ticks," position=",route_player.position," hp=",game.state.health," ammo=",game.state.ammo," shots=",game.shots)
	return true

func aim_interaction(cell: Array, height: float = 0.7) -> void:
	release_actions()
	var aim: Vector3 = route_level.layout.world_position(cell)+Vector3.UP*height
	var heading: Vector3 = aim-route_player.camera.global_position
	route_player.rotation.y = atan2(-heading.x,-heading.z)
	route_player.camera.look_at(aim,Vector3.UP)

func eastern_fight() -> bool:
	var worker = game.enemies.filter(func(actor): return actor.id == "intake_enemy_15")[0]
	for frame in range(240):
		if not live_route(): return false
		if worker.hp <= 0: break
		release_actions()
		if not expect(east_fire(),"NATIVE RED bounded eastern fight lacks real LOS; never move or damage worker15 directly"): return false
		if not await route_tick(): return false
	release_actions()
	return expect(worker.hp == 0,"NATIVE RED original eastern worker15 must die within the predeclared 240-frame fight")

func ivory_input() -> bool:
	var worker = game.enemies.filter(func(actor): return actor.id == "intake_enemy_15")[0]
	if not expect(worker.hp == 0 and game.west_deaths.get(worker.id,0) == 1 and game.west_finishes.get(worker.id,false) and east_damage[worker.id] > 0 and game.state.removed.count(worker.id) == 1 and worker.collision_layer == 0 and worker.collision_mask == 0 and game.shots > east_start_shots and game.feedback_ok,"NATIVE RED worker15 must naturally die once through observed Player fire/aim/LOS and collision retirement"): return false
	var before: Dictionary = resource_snapshot()
	aim_interaction([25.0,12.5])
	for pulse in range(2):
		interaction_input(true)
		if not await route_tick(): return false
		interaction_input(false)
		if not await route_tick(): return false
		await process_frame
		if not live_route() or not expect(game.state.keys == ["blood","ivory"] and game.state.removed.count("ivory_key") == 1 and not route_level.markers.has("ivory_key") and game.state.ammo == before.ammo and game.state.health <= before.health and game.state.armor == before.armor and game.state.owned_weapons == before.owned_weapons,"Input earns ivory once; repeated input cannot grant resources"): return false
	return expect(markers_before.ivory_key.get_ref() == null and "encounter:intake_siphon_draw" in game.state.removed,"Original upper ivory node drains after actual east encounter")

func gate_input(unlocked: bool) -> bool:
	if not expect(route_level.doors.has("containment_gate"),"Original physical gate still exists before interaction"): return false
	var gate = route_level.doors["containment_gate"]
	var reference = weakref(gate)
	var revision: int = route_level.get_node("NavigationRoutes").revision
	var before: Dictionary = resource_snapshot()
	aim_interaction([14.0,5.75],2.5)
	interaction_input(true)
	if not await route_tick(): return false
	interaction_input(false)
	if not await route_tick(): return false
	if not expect(game.state.ammo == before.ammo and game.state.health <= before.health and game.state.keys == before.keys,"Gate input preserves actual earned seals and finite resources"): return false
	if not unlocked:
		return expect(game.state.keys == ["blood"] and not "containment_gate" in game.state.removed and route_level.doors.has("containment_gate") and gate.collision_layer == 1 and gate.position == route_level.layout.world_position([14.0,5.75])+Vector3.UP*2.5 and route_level.get_node("NavigationRoutes").revision == revision,"Blood alone cannot remove or move the physical gate or invalidate native navigation")
	if not expect(game.state.keys == ["blood","ivory"] and game.state.removed.count("containment_gate") == 1 and not route_level.doors.has("containment_gate") and gate.collision_layer == 0 and route_level.get_node("NavigationRoutes").revision > revision,"Both input-earned seals retire physical gate collision and invalidate native navigation once"): return false
	for frame in range(60):
		east_fire()
		if not await route_tick(): return false
		await process_frame
	release_actions()
	return expect(reference.get_ref() == null,"Authored gate tween must drain its actual node within 60 frames")

func route_tick() -> bool:
	if not east_started: return await super.route_tick()
	if not expect(east_elapsed() < EAST_LIMIT,"NATIVE RED complete east extension shares a predeclared 3600-frame budget including process waits"): return false
	await physics_frame
	east_ticks += 1
	walk_ticks += 1
	for actor in game.enemies:
		if not expect(is_instance_valid(actor) and east_hp.has(actor.id),"Retain original east observer identities"): return false
		if actor.hp < east_hp[actor.id]: east_damage[actor.id] += 1
		east_hp[actor.id] = actor.hp
	if not live_route(): return false
	var point: Vector3 = route_player.position
	travelled += Vector2(point.x-previous.x,point.z-previous.z).length()
	peak = maxf(peak,Vector2(point.x-origin.x,point.z-origin.z).length())
	previous = point
	return true

func east_elapsed() -> int:
	return Engine.get_physics_frames()-east_origin_frame

func live_route() -> bool:
	if not east_started: return super.live_route()
	if not expect(east_elapsed() <= EAST_LIMIT,"All native east frames, including process waits, share the frozen budget"): return false
	if not expect(not paused and game.playing and not game.placement_pending and game.state.level_index == 0 and is_instance_valid(route_level) and is_instance_valid(route_player) and game.level == route_level and game.player == route_player and not route_level.is_queued_for_deletion() and route_player._current_map() and game.is_processing() and game.is_physics_processing() and route_player.is_physics_processing() and game.state.health > 0 and game.state.health <= 100,"East retains the live original automatic Main/Player/map; no recovery or replacement"): return false
	if not expect(game.enemies.size() == 23 and actors.size() == 23,"East retains all 23 original Intake actors"): return false
	var seen: Dictionary = {}
	for actor in game.enemies:
		if not expect(is_instance_valid(actor) and actors.has(actor.id) and actor.get_instance_id() == actors[actor.id][0] and actor._current_map() and actor.is_physics_processing() and actor.age-actors[actor.id][1] >= float(walk_ticks-2)/60.0,"Every original east actor retains identity and automatic age: "+actor.id): return false
		seen[actor.id] = true
		if actor.hp == 0 and not expect(game.state.removed.count(actor.id) == 1 and actor.collision_layer == 0 and actor.collision_mask == 0,"Natural original death retires collision/removal exactly once: "+actor.id): return false
	var healing_now: bool = "nave_health" in game.state.removed
	var healing: int = 30 if healing_now and not nave_collected else 0
	if not expect(game.state.health <= mini(100,east_last_health+healing),"East health can increase only from once-only authored nave healing"): return false
	east_last_health = game.state.health
	nave_collected = healing_now
	for supply in route_level.layout.data.pickups:
		if supply.id in game.state.removed and not expect(supply.id in ["entry_ammo","upper_ammo","west_health","nave_health"] and game.state.removed.count(supply.id) == 1,"No extra supplies may bypass the shared 170-round pistol budget: "+supply.id): return false
	return expect(seen.size() == 23 and game.rate_ok and game.ticks >= walk_ticks-2 and game.shot_ok and game.shot_clock_ok and game.state.ammo == [0,170-game.shots,0,0,0,0] and game.state.ammo[1] >= 0 and game.state.ammo[1] <= WeaponPlayer.WEAPONS[1].max_ammo and game.state.weapon == 1 and game.state.owned_weapons == [0,1] and game.state.armor == 0 and game.state.discoveries.is_empty(),"Original shared native cadence, shot-age, finite earned ammo and unchanged pistol-only ownership remain mandatory")

func exit_input() -> bool:
	var defeats: Array = []
	for actor in game.enemies:
		defeats.append({"id":actor.id,"hp":actor.hp,"removed":game.state.removed.count(actor.id),"layer":actor.collision_layer,"mask":actor.collision_mask})
	if not expect(all_original_defeated(defeats),"Every claimed original enemy must be naturally dead/removed before exit teardown"): return false
	var survivor: Array = defeats.duplicate(true)
	survivor[-1].hp = 1
	survivor[-1].removed = 0
	if not expect(not all_original_defeated(survivor),"Alive non-required actor must fail pre-exit defeat oracle"): return false
	if not live_route() or not expect(game.state.keys == ["blood","ivory"] and game.state.removed.count("containment_gate") == 1 and "encounter:intake_siphon_return" in game.state.removed and "encounter:intake_gate_release" in game.state.removed,"Actual earned gate and eastern return encounters precede Intake exit"): return false
	var before: Dictionary = resource_snapshot()
	var witness: Array = game.state.removed.duplicate()
	for node in [route_level,route_player]+game.enemies: retired.append(weakref(node))
	aim_interaction([14.5,1.5])
	if not expect(east_elapsed() < EAST_LIMIT,"Exit action shares the extension deadline"): return false
	interaction_input(true)
	await physics_frame
	east_ticks += 1
	interaction_input(false)
	release_actions()
	await process_frame
	await process_frame
	if not expect(game.state.level_index == 1 and not game.playing and not game.placement_pending and game.level == null and game.player == null and game.state.keys.is_empty() and game.state.removed.is_empty() and game.state.checkpoint_id == "entry" and game.state.ammo == before.ammo and game.state.owned_weapons == before.owned_weapons and game.state.weapon == before.weapon and game.state.armor == before.armor and game.state.health > 0 and game.state.health <= before.health,"Actual production exit advances only one level, preserves finite resources and retires Intake"): return false
	if not expect(east_elapsed() <= EAST_LIMIT and retired.all(func(reference): return reference.get_ref() == null) and markers_before.values().all(func(reference): return reference.get_ref() == null),"Actual exit must drain every original Intake level/player/actor and observed marker within the shared deadline"): return false
	var descend: bool = false
	for node in game.menu.get_children():
		if node is Button and not node.is_queued_for_deletion() and node.text == "Descend to The Foundry": descend = true
	if not expect(descend and FileAccess.file_exists(game.progress_path),"Actual completion must expose Foundry descent and persist isolated progress"): return false
	var saved = game.state.get_script().new()
	if not expect(saved.load_progress(game.progress_path) and saved_exit_matches(saved),"Read actual isolated exit save: next-map progress must preserve finite earned resources"): return false
	for mismatch in [{"armor":game.state.armor+1},{"weapon":0}]:
		var corrupt: Dictionary = saved.to_dict().duplicate(true)
		for key in mismatch: corrupt[key] = mismatch[key]
		var changed = game.state.get_script().new()
		if not expect(changed.from_dict(corrupt) and not saved_exit_matches(changed),"Valid-but-wrong persisted resource must fail exit oracle: "+str(mismatch)): return false
	for envelope in ["checkpoint","level_start"]:
		var corrupt: Dictionary = saved.to_dict().duplicate(true)
		corrupt[envelope].ammo[1] += 1
		var changed = game.state.get_script().new()
		if not expect(changed.from_dict(corrupt) and not saved_exit_matches(changed),"Valid-but-stale recovery snapshot must fail exit oracle: "+envelope): return false
	print("INTAKE_COMPLETE_EXIT east_ticks=",east_ticks," actual_east_frames=",east_elapsed()," prefix_and_route_ticks=",walk_ticks," shots=",game.shots," resources=",resource_snapshot()," earned_intake_witness=",witness," east_damage=",east_damage)
	return true

func saved_exit_matches(saved) -> bool:
	return saved.level_index == 1 and saved.ammo == game.state.ammo and saved.health == game.state.health and saved.armor == game.state.armor and saved.weapon == game.state.weapon and saved.owned_weapons == game.state.owned_weapons and saved.keys == [] and saved.removed == [] and saved.checkpoint == game.state.checkpoint and saved.level_start == game.state.level_start

func all_original_defeated(witnesses: Array) -> bool:
	if witnesses.size() != 23 or actors.size() != 23: return false
	var seen: Dictionary = {}
	for witness in witnesses:
		if not actors.has(witness.id) or seen.has(witness.id) or witness.hp != 0 or witness.removed != 1 or witness.layer != 0 or witness.mask != 0: return false
		seen[witness.id] = true
	return seen.size() == 23
