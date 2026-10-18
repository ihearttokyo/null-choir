extends "res://tests/test_intake_combat.gd"

const WeaponPlayer = preload("res://scripts/player.gd")
const WEST_LIMIT = 900
const HOP_LIMIT = 240
const WEST_ROUTE = [[7.5,23.5],[6.5,23.5],[6.5,20.5],[5.5,20.5],[6.5,20.5],[6.5,18.5],[6.0,17.5],[6.0,13.5],[4.0,13.5]]
class WestMain:
	extends "res://scripts/main.gd"
	var prefix_bookkeeping_retired: bool = false
	var ticks: int = 0
	var rate_ok: bool = true
	var shots: int = 0
	var hits: int = 0
	var impacts: int = 0
	var attacks: int = 0
	var deaths: int = 0
	var last_shot: int = -1
	var shot_slot: float = -1.0
	var shot_ok: bool = true
	var feedback_ok: bool = true
	var player_finish: bool = false
	var victim
	var west_firing_id: String = ""
	var west_deaths: Dictionary = {}
	var west_finishes: Dictionary = {}
	static func earned_shot_slot(tick: int, last_tick: int, slot: float, interval_ticks: float, count: int, ammo: int, earned: int, weapon: int, held: bool) -> float:
		if earned not in [0,45] or ammo < 0 or ammo > Player.WEAPONS[1].max_ammo: return -1.0
		# 125+45 <= 180 means the earned pickup cannot be truncated by the source cap.
		# shortcut: 240+900 firing ticks cannot exhaust 125 rounds; widen the oracle only for a longer fixture.
		return preload("res://tests/test_intake_combat.gd").CombatMain.accepted_shot_slot(tick,last_tick,slot,interval_ticks,count,ammo-earned,weapon,held)
	func _physics_process(delta: float) -> void:
		if not prefix_bookkeeping_retired and playing and not get_tree().paused:
			ticks += 1
			rate_ok = rate_ok and absf(delta-1.0/60.0) < 0.000001
			if not Input.is_action_pressed("fire"): shot_slot = -1.0
	func shot(weapon: int) -> void:
		if not prefix_bookkeeping_retired:
			shots += 1
			var earned: int = 45 if state.removed.count("upper_ammo") == 1 else 0
			shot_slot = earned_shot_slot(ticks,last_shot,shot_slot,Player.WEAPONS[1].interval*60.0,shots,state.ammo[1],earned,weapon,Input.is_action_pressed("fire"))
			shot_ok = shot_ok and Engine.is_in_physics_frame() and playing and is_instance_valid(player) and player._current_map() and state.weapon == weapon and state.owned_weapons == [0,1] and state.removed.count("upper_ammo") <= 1 and shot_slot >= 0.0
			last_shot = ticks
		super.shot(weapon)
		if not prefix_bookkeeping_retired:
			var visuals = level.get_node_or_null("AmmoVisuals")
			feedback_ok = feedback_ok and visuals != null and visuals.slots.any(func(slot): return slot.row == 1 and slot.sprite.visible)
	func hit_feedback() -> void:
		if not prefix_bookkeeping_retired:
			hits += 1
		super.hit_feedback()
		if not prefix_bookkeeping_retired:
			feedback_ok = feedback_ok and hit_flash > 0
	func impact(point: Vector3) -> void:
		if not prefix_bookkeeping_retired:
			impacts += 1
		super.impact(point)
		if not prefix_bookkeeping_retired:
			var visuals = level.get_node_or_null("AmmoVisuals")
			feedback_ok = feedback_ok and visuals != null and visuals.slots.any(func(slot): return slot.row == 3 and slot.sprite.visible)
	func enemy_event(actor, event: String) -> void:
		if not prefix_bookkeeping_retired and actor == victim and playing and actor._current_map() and actor.active:
			if event == "attack" and actor._committed_target == player: attacks += 1
			if event == "death":
				deaths += 1
				player_finish = Input.is_action_pressed("fire") and last_shot == ticks and actor.target == player
		if not prefix_bookkeeping_retired and event == "death" and actor != victim and playing and actor._current_map() and actor.active:
			west_deaths[actor.id] = west_deaths.get(actor.id,0)+1
			west_finishes[actor.id] = actor.id == west_firing_id and Input.is_action_pressed("fire") and last_shot == ticks and actor.target == player and aim_observation.get("actor_id","") == actor.id and aim_observation.get("tick",-1) == Engine.get_physics_frames() and aim_observation.get("level") == level and aim_observation.get("player") == player
		super.enemy_event(actor,event)


const WEST_IDS = ["intake_enemy_02","intake_enemy_03","intake_enemy_04","intake_enemy_05","intake_enemy_06"]
var west_actors: Dictionary = {}
var west_hp: Dictionary = {}
var west_damage: Dictionary = {}
var prefix_hits: int = 0
var prefix_impacts: int = 0
var west_started: bool = false
var west_ticks: int = 0
var prefix_shots: int = 0
var prior_mute: bool = false
var last_health: int = 0
var health_collected: bool = false

func _initialize() -> void:
	prior_mute = AudioServer.is_bus_mute(0)
	for sample in [[5,120,0,1,true,true],[5,165,45,1,true,true],[5,165,0,1,true,false],[5,120,45,1,true,false],[5,165,90,1,true,false],[5,181,45,1,true,false],[6,165,45,1,true,false],[5,165,45,0,true,false],[5,165,45,1,false,false]]:
		var slot: float = WestMain.earned_shot_slot(800,780,792.6,12.6,sample[0],sample[1],sample[2],sample[3],sample[4])
		if not expect((slot >= 0.0) == sample[5],"Finite earned-supply oracle boundary: "+str(sample)):
			quit(1)
			return
	if not expect(WestMain.earned_shot_slot(792,780,792.6,12.6,5,165,45,1,true) < 0.0 and WestMain.earned_shot_slot(780,780,792.6,12.6,5,165,45,1,true) < 0.0,"Earned ammo cannot bypass cadence or same-tick rejection"):
		quit(1)
		return
	super._initialize()

func run() -> void:
	prefix = "user://intake_west_seal_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	if not await walk_to_west_seal(WestMain.new(),prefix):
		await finish(1)
		return
	print("PASS source-native candidate earned Intake west blood seal only; inherited virtual movement/camera aim/Input fire, production interaction input and automatic original actors. Not human/OS input, east seal, exit, full Intake/campaign, GPU/audio or packed-app acceptance.")
	await finish(0)

func walk_to_west_seal(observer, profile_prefix: String) -> bool:
	prefix = profile_prefix
	release_actions()
	if not expect(Engine.physics_ticks_per_second == 60,"SETUP: requires native 60-Hz physics"):
		return false
	seed(1304)
	game = observer
	game.settings_path = prefix+"_preferences.json"
	game.progress_path = prefix+"_campaign.json"
	root.add_child(game)
	if not press_menu("New campaign") or not press_menu("Relentless") or not await wait_entry() or not await walk_route():
		return false
	game.victim = game.enemies.filter(func(actor): return actor.id == "intake_enemy_00")[0]
	var spec: Dictionary = route_level.layout.data.enemies.filter(func(actor): return actor.id == game.victim.id)[0]
	if not expect(spec.kind == "worker" and Vector2(spec.cell[0],spec.cell[1]) == Vector2(8.5,23.5) and game.victim.encounter_id.is_empty() and game.victim.active and game.victim.hp == 90 and game.shots == 0,"Original full-health early worker follows the earned entry pickup"):
		return false
	if not await approach() or not await combat():
		return false
	prefix_shots = game.shots
	prefix_hits = game.hits
	prefix_impacts = game.impacts
	for id in WEST_IDS:
		var matches: Array = game.enemies.filter(func(actor): return actor.id == id)
		if not expect(matches.size() == 1,"Retain the named original west actor: "+id):
			return false
		west_actors[id] = matches[0]
		west_hp[id] = matches[0].hp
		west_damage[id] = 0
	var blocker: Dictionary = route_level.layout.data.enemies.filter(func(spec): return spec.id == "intake_enemy_03")[0]
	if not expect(blocker.kind == "worker" and blocker.cell == [6.5,13.75] and west_actors[blocker.id].hp == 90 and WeaponPlayer.WEAPONS[1].max_ammo == 180 and 125+45 <= WeaponPlayer.WEAPONS[1].max_ammo and WeaponPlayer.WEAPONS[1].interval == 0.21,"Pin original worker03 and uncapped finite supply/cadence"):
		return false
	if not expect(game.state.keys.is_empty() and not "blood_key" in game.state.removed and route_level.markers.has("blood_key"),"Coverage RED baseline: earned prefix has not collected the west blood seal"):
		return false
	last_health = game.state.health
	west_started = true
	if not await west_route() or not await west_seal():
		return false
	return true

func west_route() -> bool:
	var supplies: Array = route_level.layout.data.pickups.filter(func(spec): return spec.id == "upper_ammo")
	if not expect(supplies.size() == 1 and supplies[0].kind == "ammo" and supplies[0].weapon == 1 and supplies[0].amount == 45 and supplies[0].cell == [5.5,20.5],"Pin the only added pistol supply to actual authored west ammo"): return false
	var health_supply: Array = route_level.layout.data.pickups.filter(func(spec): return spec.id == "west_health")
	if not expect(health_supply.size() == 1 and health_supply[0].kind == "health" and health_supply[0].amount == 25 and health_supply[0].cell == [7.5,23.5],"Pin finite west healing to the actual authored pickup"): return false
	# Keep the same route and full native clearance; combat may earn a blocked leg.
	for cell in WEST_ROUTE:
		var target: Vector3 = route_level.layout.world_position(cell)+Vector3.UP*0.04
		var hop_start: int = west_ticks
		while true:
			if not live_route(): return false
			var clear: bool = clear_point(cell) != null
			var start: Vector3 = route_player.position
			var samples: int = ceili(start.distance_to(target)/0.5)
			for sample in range(samples+1):
				var point: Vector3 = start.lerp(target,float(sample)/maxi(1,samples))
				if clear_point([point.x/4.0,point.z/4.0]) == null: clear = false
			if clear: break
			release_actions()
			if not expect(west_ticks-hop_start < HOP_LIMIT and west_fire(),"NATIVE RED blocked west leg without bounded visible combat: "+str(cell)+" position="+str(route_player.position)): return false
			if not await route_tick(): return false
		while Vector2(route_player.position.x-target.x,route_player.position.z-target.z).length() > 0.12:
			if not live_route() or not expect(west_ticks-hop_start < HOP_LIMIT,"NATIVE RED west hop deadline "+str(cell)+" position="+str(route_player.position)): return false
			release_actions()
			if not west_fire():
				route_player.look_at(Vector3(target.x,route_player.position.y,target.z),Vector3.UP)
			var direction: Vector3 = target-route_player.position
			direction.y = 0
			var distance: float = direction.length()
			var deadzone: float = 0.0
			for action in ["move_left","move_right","move_forward","move_back"]: deadzone += InputMap.action_get_deadzone(action)/4.0
			# Strafe toward the waypoint while native pistol aim faces the actual enemy.
			var axes: Vector3 = route_player.basis.inverse()*direction.normalized()*(deadzone+(1.0-deadzone)*minf(1.0,distance*6.0/9.0))
			Input.action_press("move_right",maxf(0,axes.x))
			Input.action_press("move_left",maxf(0,-axes.x))
			Input.action_press("move_back",maxf(0,axes.z))
			Input.action_press("move_forward",maxf(0,-axes.z))
			if not await route_tick(): return false
		release_actions()
		for settling in range(12):
			west_fire()
			if not await route_tick(): return false
		release_actions()
		await process_frame
		if not live_route() or not expect(route_player.position.distance_to(target) < 0.2 and clear_point(cell) != null,"NATIVE RED west hop must settle with current native clearance: "+str(cell)): return false
		print("INTAKE_WEST_HOP cell=",cell," west_ticks=",west_ticks," total_ticks=",walk_ticks," position=",route_player.position," hp=",game.state.health," ammo=",game.state.ammo," shots=",game.shots)
	for id in WEST_IDS:
		if not game.west_deaths.has(id): continue
		var actor = west_actors[id]
		if not expect(game.west_deaths[id] == 1 and actor.hp == 0 and game.state.removed.count(id) == 1 and actor.collision_layer == 0 and actor.collision_mask == 0,"Each observed original west death/removal is once-only: "+id): return false
	var blocker = west_actors["intake_enemy_03"]
	if not expect(blocker.hp == 0 and game.west_deaths.get(blocker.id,0) == 1 and game.west_finishes.get(blocker.id,false) and west_damage[blocker.id] > 0 and game.state.removed.count(blocker.id) == 1 and blocker.collision_layer == 0 and blocker.collision_mask == 0 and game.shots > prefix_shots and game.hits > prefix_hits and game.impacts > prefix_impacts and game.feedback_ok,"Actual worker03 must take damage and finish once through Player fire/LOS and production feedback, never staging or infighting-only acceptance"): return false
	return expect(game.state.removed.count("upper_ammo") == 1 and not route_level.markers.has("upper_ammo"),"West ammo must be earned by automatic proximity once")

func west_fire() -> bool:
	Input.action_release("fire")
	game.west_firing_id = ""
	var selected = null
	var nearest: float = INF
	for id in WEST_IDS:
		var actor = west_actors[id]
		if not is_instance_valid(actor) or not actor._current_map() or not actor.active or actor.hp <= 0: continue
		var point: Vector3 = actor.global_position+actor.get_child(0).position
		var distance: float = route_player.camera.global_position.distance_to(point)
		if distance >= nearest or distance > WeaponPlayer.WEAPONS[1].range: continue
		var query = PhysicsRayQueryParameters3D.create(route_player.camera.global_position,point,1|4)
		query.exclude = [route_player.get_rid()]
		var hit = route_level.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider == actor:
			selected = actor
			nearest = distance
	if selected == null: return false
	var aim: Vector3 = selected.global_position+selected.get_child(0).position
	var heading: Vector3 = aim-route_player.camera.global_position
	# shortcut: inherited fixture camera aim is virtual, not physical/OS look acceptance.
	route_player.rotation.y = atan2(-heading.x,-heading.z)
	route_player.camera.look_at(aim,Vector3.UP)
	game.west_firing_id = selected.id
	Input.action_press("fire")
	return true

func west_seal() -> bool:
	var keys: Array = route_level.layout.data.interactions.filter(func(spec): return spec.id == "blood_key")
	if not expect(keys.size() == 1 and keys[0].kind == "key" and keys[0].key == "blood" and keys[0].cell == [3.5,13.5] and route_level.markers.has("blood_key") and game.state.keys.is_empty(),"Actual uncollected west Key and empty seal inventory precede input"): return false
	var marker = weakref(route_level.markers["blood_key"])
	var before: Dictionary = resource_snapshot()
	var aim: Vector3 = route_level.layout.world_position(keys[0].cell)+Vector3.UP*0.7
	var heading: Vector3 = aim-route_player.camera.global_position
	route_player.rotation.y = atan2(-heading.x,-heading.z)
	route_player.camera.look_at(aim,Vector3.UP)
	for pulse in range(2):
		interaction_input(true)
		if not await route_tick(): return false
		interaction_input(false)
		if not await route_tick(): return false
		await process_frame
		if not live_route() or not expect(game.state.keys == ["blood"] and game.state.removed.count("blood_key") == 1 and not route_level.markers.has("blood_key"),"NATIVE RED production interact must earn blood exactly once, with marker absent; pulse="+str(pulse)): return false
		if not expect(game.state.ammo == before.ammo and game.state.owned_weapons == before.owned_weapons and game.state.weapon == before.weapon and game.state.armor == before.armor and game.state.health <= before.health,"Key/repeated interact must grant no ammo, weapon, armor or health"): return false
	if not expect(marker.get_ref() == null,"Collected actual Key marker must drain, not merely leave the marker dictionary"): return false
	for actor in game.enemies:
		if not expect(actor.age-actors[actor.id][1] >= float(walk_ticks-2)/60.0,"Every original actor retains automatic native age through west seal: "+actor.id): return false
	if not expect(game.rate_ok and game.ticks >= walk_ticks-2 and game.state.checkpoint_id == "entry" and game.state.discoveries.is_empty(),"Automatic native Main cadence; no checkpoint/story/exit/state advance"): return false
	print("INTAKE_WEST_SEAL total_ticks=",walk_ticks," west_ticks=",west_ticks," prefix_shots=",prefix_shots," total_shots=",game.shots," west_damage=",west_damage," west_deaths=",game.west_deaths," position=",route_player.position," resources=",resource_snapshot()," removed=",game.state.removed)
	return true

func resource_snapshot() -> Dictionary:
	return {"health":game.state.health,"armor":game.state.armor,"ammo":game.state.ammo.duplicate(),"owned_weapons":game.state.owned_weapons.duplicate(),"weapon":game.state.weapon,"keys":game.state.keys.duplicate()}

func interaction_input(pressed: bool) -> void:
	var event = InputEventAction.new()
	event.action = "interact"
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func route_tick() -> bool:
	if not west_started: return await super.route_tick()
	if not expect(west_ticks < WEST_LIMIT,"NATIVE RED west extension exceeds 900 ticks; inherited prefix limits remain unchanged"): return false
	await physics_frame
	west_ticks += 1
	walk_ticks += 1
	for id in WEST_IDS:
		var actor = west_actors[id]
		if not expect(is_instance_valid(actor) and actor._current_map(),"Original west actor remains current: "+id): return false
		if actor.hp < west_hp[id]: west_damage[id] += 1
		west_hp[id] = actor.hp
	if not live_route(): return false
	var point: Vector3 = route_player.position
	travelled += Vector2(point.x-previous.x,point.z-previous.z).length()
	peak = maxf(peak,Vector2(point.x-origin.x,point.z-origin.z).length())
	previous = point
	return true

func live_route() -> bool:
	if not super.live_route(): return false
	if not west_started: return true
	var health_now: bool = "west_health" in game.state.removed
	var healing: int = 25 if health_now and not health_collected else 0
	if not expect(game.state.health <= mini(100,last_health+healing),"Health can increase only through the once-only authored west health pickup"): return false
	last_health = game.state.health
	health_collected = health_now
	var earned: int = 45 if "upper_ammo" in game.state.removed else 0
	if not expect(game.shots >= prefix_shots and game.shot_ok and game.state.ammo == [0,125-game.shots+earned,0,0,0,0] and game.state.ammo[1] >= 0 and game.state.ammo[1] <= WeaponPlayer.WEAPONS[1].max_ammo and game.state.armor == 0 and game.state.weapon == 1 and game.state.owned_weapons == [0,1],"West resources are actual finite entry/earned supply minus all accepted native shots; no grants/ownership changes"): return false
	for supply in route_level.layout.data.pickups:
		if supply.id in game.state.removed and not expect(game.state.removed.count(supply.id) == 1 and supply.id in ["entry_ammo","upper_ammo","west_health"],"West must not earn an unrelated supply: "+supply.id): return false
	return true

func release_actions() -> void:
	for action in preload("res://scripts/preferences.gd").ACTIONS:
		if InputMap.has_action(action): Input.action_release(action)

func finish(status: int) -> void:
	await super.finish(status)
	AudioServer.set_bus_mute(0,prior_mute)
