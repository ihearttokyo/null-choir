extends "res://tests/test_profile_workload.gd"

const ENTRY = preload("res://tests/test_encounter_physics_clock.gd").ENTRY_ROUTE
const RETREAT = [[6.5,20.5],[6.5,23.15],[10.5,23.15],[11.7,24.5],[11.7,28.5],[14.5,28.5]]
const COMMAND_SHA256 = "3a37aaab7d80048ec77f5616475043fec1b14551d1a10c41393aa94a80325109"
var commands: Array = []
var forward_ticks: int = 0
var back_ticks: int = 0
var turn_radians: float = 0.0
var pressure_ticks: int = 0
var post_bell_pressure_ticks: int = 0

class PressureMain:
	extends "res://tests/test_profile_cadence.gd".CadenceMain
	var tracing: bool = false
	var costs: Dictionary = {"render":[],"aim":[],"passive":[]}
	var attacks_at_player: Array = []
	var damage: Array = []
	func _process(delta: float) -> void:
		var started: int = Time.get_ticks_usec()
		super._process(delta)
		if tracing: costs.render.append(Time.get_ticks_usec()-started)
	func resolve_aim(origin: Vector3, direction: Vector3, reach: float, melee: bool = false) -> Dictionary:
		var started: int = Time.get_ticks_usec()
		var result: Dictionary = super.resolve_aim(origin,direction,reach,melee)
		if tracing: costs.aim.append(Time.get_ticks_usec()-started)
		return result
	func update_passive_triggers(observer: CharacterBody3D) -> void:
		var started: int = Time.get_ticks_usec()
		super.update_passive_triggers(observer)
		if tracing: costs.passive.append(Time.get_ticks_usec()-started)
	func enemy_event(actor, event: String) -> void:
		if tracing and event == "attack" and actor._committed_target == player:
			attacks_at_player.append([ticks-start_tick,actor.id,Engine.is_in_physics_frame()])
		super.enemy_event(actor,event)
	func hurt_player(amount: int) -> void:
		var before: int = state.health
		super.hurt_player(amount)
		if tracing and state.health < before: damage.append([ticks-start_tick,before,state.health,amount])

func make_main():
	return PressureMain.new()

func run() -> void:
	prefix = "user://profile_pressure_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	release_actions()
	if not expect(Engine.physics_ticks_per_second == 60 and Engine.time_scale == 1.0,"Pressure requires normal native60Hz/time scale"):
		await finish(1)
		return
	seed(1304)
	game = make_main()
	game.settings_path = prefix+"_preferences.json"
	game.progress_path = prefix+"_campaign.json"
	root.add_child(game)
	if not press_menu("New campaign") or not press_menu("Relentless") or not await wait_entry():
		await finish(1)
		return
	game.start_tick = game.ticks
	game.tracing = true
	var route: Array = ENTRY.duplicate(true)
	route.append_array(RETREAT)
	for tick in range(PROFILE_TICKS):
		if not live_route():
			await finish(1)
			return
		for actor in game.enemies:
			if not expect(actor.hp > 0,"Pressure preserves every original actor alive: "+actor.id):
				await finish(1)
				return
		var threatened: bool = game.enemies.any(func(actor): return actor.active and actor.alerted and actor.target == route_player and actor.position.distance_to(route_player.position) < 30.0)
		if threatened:
			pressure_ticks += 1
			if "encounter:intake_bell_release" in game.state.removed: post_bell_pressure_ticks += 1
		var target = clear_point(route[route_leg])
		if not expect(target != null,"Pressure waypoint retains actual floor/capsule clearance"):
			await finish(1)
			return
		var offset: Vector3 = target-route_player.position
		var distance: float = Vector2(offset.x,offset.z).length()
		for action in ACTIONS: Input.action_release(action)
		var reverse: bool = (tick/120)%2 == 1
		var yaw: float = 0.0
		var strength: float = 0.0
		if distance < 0.12:
			route_leg += 1
			if route_leg == route.size():
				route_leg = 0
				completed_laps += 1
				route = WAYPOINTS.duplicate(true)
			hop_ticks = 0
		else:
			hop_ticks += 1
			if not expect(hop_ticks <= HOP_TICKS,"Pressure movement cannot silently stall at leg "+str(route_leg)):
				await finish(1)
				return
			var desired: float = atan2(-offset.x,-offset.z)+(PI if reverse else 0.0)
			yaw = wrapf(route_player.rotation.y-desired,-PI,PI)
			strength = 0.2+0.8*minf(1.0,distance*6.0/9.0)
			route_player.look(Vector2(yaw,route_player.camera.rotation.x-1.0))
			Input.action_press("move_back" if reverse else "move_forward",strength)
			if reverse: back_ticks += 1
			else: forward_ticks += 1
			turn_radians += absf(yaw)
		var firing: bool = tick >= 960 and tick < 1140
		if firing: Input.action_press("fire")
		commands.append([tick,reverse,strength,yaw,firing])
		await physics_frame
		walk_ticks += 1
		var point: Vector3 = route_player.position
		travelled += Vector2(point.x-previous.x,point.z-previous.z).length()
		previous = point
		if tick%120 == 0:
			samples.append({"tick":tick,"x":point.x,"z":point.z,"health":game.state.health,"leg":route_leg,"attacks":game.attacks_at_player.size()})
	game.tracing = false
	release_actions()
	var ok: bool = live_route()
	ok = expect(JSON.stringify(commands).sha256_text() == COMMAND_SHA256,"Exact frozen1440tick native command ledger must match the source-bound pilot; navigation never waives input drift") and ok
	ok = expect(forward_ticks > 600 and back_ticks > 600 and turn_radians > 10*PI and post_bell_pressure_ticks >= 120,"Repeated forward/back/turn commands and at least120ticks of real post-bell player-target pressure") and ok
	ok = expect(travelled >= 100 and game.attacks_at_player.size() > 0 and not game.damage.is_empty(),"Pressure entails100m native movement and actual enemy attacks/damage") and ok
	ok = expect(game.shots.size() == 15 and game.shots.all(func(row): return row[1] == 1 and row[2] and row[3]),"Exactly15 finite native held pistol shots") and ok
	ok = expect(game.state.ammo == [0,155,0,0,0,0] and game.state.armor == 0 and game.state.owned_weapons == [0,1] and game.state.weapon == 1 and game.rate_ok,"Only90 default plus earned35/45 minus15; normal clock/inventory") and ok
	ok = expect(game.pickups.map(func(row): return row[1]) == ["entry_ammo","upper_ammo"] and game.pickups.all(func(row): return row[2]) and game.state.removed == ["entry_ammo","upper_ammo","encounter:intake_bell_release"] and game.state.keys.is_empty(),"Exactly earned physics entry/upper supplies and real bell activation, no keys or other removals") and ok
	for actor in game.enemies:
		ok = expect(actor.hp > 0 and actor.age-actors[actor.id][1] >= float(PROFILE_TICKS-2)/60.0,"All23 original actors remain alive and automatic for1440ticks") and ok
	ok = expect(game.costs.aim.size() == PROFILE_TICKS and game.costs.passive.size() == PROFILE_TICKS and not game.costs.render.is_empty(),"Every native aim/passive callback and a nonempty render trace must be measured") and ok
	var summaries: Dictionary = {}
	for label in game.costs:
		var values: Array = game.costs[label]
		values.sort()
		summaries[label] = {"n":values.size(),"sum_us":values.reduce(func(a,b): return a+b,0),"p95_us":values[int(values.size()*0.95)] if not values.is_empty() else 0,"max_us":values.back() if not values.is_empty() else 0}
	print("PROFILE_PRESSURE ",JSON.stringify({"ticks":walk_ticks,"metres":travelled,"health":game.state.health,"ammo":game.state.ammo,"shots":game.shots,"pickups":game.pickups,"attacks":game.attacks_at_player,"damage":game.damage,"samples":samples,"forward_ticks":forward_ticks,"back_ticks":back_ticks,"turn_radians":turn_radians,"pressure_ticks":pressure_ticks,"post_bell_pressure_ticks":post_bell_pressure_ticks,"callback_elapsed_us":summaries,"commands_sha256":JSON.stringify(commands).sha256_text(),"scope":"normal finite source-native pressure; Main render includes encounter/music pressure/redraw enqueue, aim includes native queries, passive includes scan/pickups (no checkpoint earned here); inclusive elapsed observations include host scheduling, not thread CPU time/full frame/GPU/display/physical/listening/FPS acceptance"}))
	if ok: print("PASS normal finite1440tick pressure/turn/backpedal/fire workload with all23 original automatic live actors")
	await finish(0 if ok else 1)
