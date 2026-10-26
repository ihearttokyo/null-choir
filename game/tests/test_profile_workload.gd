extends "res://tests/test_intake_walk.gd"

const WallClock = preload("res://tests/wall_clock_wait.gd")
const PROFILE_TICKS = 1440
const HOP_TICKS = 240
var samples: Array = []
var route_leg: int = 0
var hop_ticks: int = 0
var completed_laps: int = 0

func run() -> void:
	prefix = "user://profile_workload_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	release_actions()
	if not expect(Engine.physics_ticks_per_second == 60 and Engine.time_scale == 1.0,"Profile requires unmodified 60-Hz physics and time scale"):
		await finish(1)
		return
	seed(1304)
	game = ObservedMain.new()
	game.settings_path = prefix+"_preferences.json"
	game.progress_path = prefix+"_campaign.json"
	root.add_child(game)
	if not press_menu("New campaign") or not press_menu("Relentless") or not await wait_entry():
		await finish(1)
		return
	var started: int = Time.get_ticks_usec()
	for tick in range(PROFILE_TICKS):
		if not live_route():
			await finish(1)
			return
		var target = clear_point(WAYPOINTS[route_leg])
		if not expect(target != null,"Profile waypoint retains native floor/capsule clearance"):
			await finish(1)
			return
		var offset: Vector3 = target-route_player.position
		var distance: float = Vector2(offset.x,offset.z).length()
		if distance < 0.12:
			release_actions()
			route_leg = (route_leg+1)%WAYPOINTS.size()
			if route_leg == 0: completed_laps += 1
			hop_ticks = 0
		else:
			hop_ticks += 1
			if not expect(hop_ticks <= HOP_TICKS,"Profile cannot silently remain blocked at a waypoint"):
				await finish(1)
				return
			var desired: float = atan2(-offset.x,-offset.z)
			route_player.look(Vector2(wrapf(route_player.rotation.y-desired,-PI,PI),0))
			var deadzone: float = 0.0
			for action in ["move_left","move_right","move_forward","move_back"]: deadzone += InputMap.action_get_deadzone(action)/4.0
			Input.action_press("move_forward",deadzone+(1.0-deadzone)*minf(1.0,distance*6.0/9.0))
		await physics_frame
		walk_ticks += 1
		var point: Vector3 = route_player.position
		travelled += Vector2(point.x-previous.x,point.z-previous.z).length()
		peak = maxf(peak,Vector2(point.x-origin.x,point.z-origin.z).length())
		previous = point
		if tick%120 == 0:
			samples.append({"tick":tick,"elapsed_us":Time.get_ticks_usec()-started,"health":game.state.health,"ammo":game.state.ammo[1],"x":point.x,"z":point.z,"objects":int(Performance.get_monitor(Performance.OBJECT_COUNT)),"resources":int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),"collision_pairs":int(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS))})
	release_actions()
	await process_frame
	var ok: bool = live_route()
	ok = expect(completed_laps >= 3 and travelled >= 100 and peak >= 10,"Profile completes real repeated movement, not a stationary wait") and ok
	ok = expect(game.state.health > 0 and game.state.armor == 0 and game.state.ammo == [0,125,0,0,0,0] and game.state.removed == ["entry_ammo"] and not route_level.markers.has("entry_ammo"),"Only the finite authored entry pickup changes resources; no firing, refund, removal or recovery") and ok
	ok = expect(game.state.owned_weapons == [0,1] and game.state.weapon == 1 and game.rate_ok and game.ticks >= PROFILE_TICKS,"Native Main physics and original inventory remain active for all 1440 ticks") and ok
	for actor in game.enemies:
		ok = expect(actor.hp > 0 and actor.age-actors[actor.id][1] >= float(PROFILE_TICKS-2)/60.0,"Every original live actor advances automatically throughout the profile: "+actor.id) and ok
	print("PROFILE_WORKLOAD ",JSON.stringify({"ticks":walk_ticks,"elapsed_us":Time.get_ticks_usec()-started,"laps":completed_laps,"metres":travelled,"health":game.state.health,"ammo":game.state.ammo,"samples":samples,"scope":"source-native synthetic movement and live actors; callback spacing/counters, not GPU, CPU duration, physical input, display pacing or campaign acceptance"}))
	if ok: print("PASS surviving 1440-tick Intake profiling workload; all 23 actors automatic, one earned pickup, unchanged finite resources and native movement")
	await finish(0 if ok else 1)

func finish(status: int) -> void:
	release_actions()
	if is_instance_valid(game):
		retire_level()
		for node in [game,game.music,game.effects]: retired.append(weakref(node))
		game.music.stop()
	paused = false
	await WallClock.seconds(self,0.15)
	if is_instance_valid(game): game.free()
	await process_frame
	await process_frame
	if not expect(retired.all(func(reference): return reference.get_ref() == null),"Profile native owners must drain"): status = 1
	for suffix in ["_campaign.json","_campaign.json.tmp","_preferences.json","_preferences.json.tmp"]:
		var path: String = prefix+suffix
		if FileAccess.file_exists(path) and not expect(DirAccess.remove_absolute(path) == OK,"Remove only the unique profiling fixture profile"): status = 1
	quit(status)
