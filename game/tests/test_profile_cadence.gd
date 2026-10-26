extends "res://tests/test_profile_workload.gd"

const CADENCE_TICKS = 480

class CadenceMain:
	extends "res://tests/test_active_boss_fights.gd".ObservedMain
	var start_tick: int = 0
	var shots: Array = []
	var pickups: Array = []
	func shot(index: int) -> void:
		shots.append([ticks-start_tick,index,Engine.is_in_physics_frame(),Input.is_action_pressed("fire")])
		super.shot(index)
	func collect_pickup(id: String) -> void:
		var before: bool = id in state.removed
		super.collect_pickup(id)
		if not before and id in state.removed: pickups.append([ticks-start_tick,id,Engine.is_in_physics_frame()])

func run() -> void:
	prefix = "user://profile_cadence_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	release_actions()
	if not expect(Engine.physics_ticks_per_second == 60 and Engine.time_scale == 1.0,"Cadence requires native60Hz physics/time scale"):
		await finish(1)
		return
	seed(1304)
	game = CadenceMain.new()
	game.settings_path = prefix+"_preferences.json"
	game.progress_path = prefix+"_campaign.json"
	root.add_child(game)
	if not press_menu("New campaign") or not press_menu("Relentless") or not await wait_entry():
		await finish(1)
		return
	game.start_tick = game.ticks
	for tick in range(CADENCE_TICKS):
		if not live_route():
			await finish(1)
			return
		var target = clear_point(WAYPOINTS[route_leg])
		if not expect(target != null,"Cadence waypoint has real floor/capsule clearance"):
			await finish(1)
			return
		var offset: Vector3 = target-route_player.position
		var distance: float = Vector2(offset.x,offset.z).length()
		for action in ACTIONS: Input.action_release(action)
		var reverse: bool = (tick/120)%2 == 1
		if distance < 0.12:
			route_leg = (route_leg+1)%WAYPOINTS.size()
			if route_leg == 0: completed_laps += 1
			hop_ticks = 0
		else:
			hop_ticks += 1
			if not expect(hop_ticks <= HOP_TICKS,"Cadence hop cannot stall silently"):
				await finish(1)
				return
			var desired: float = atan2(-offset.x,-offset.z)+(PI if reverse else 0.0)
			route_player.look(Vector2(wrapf(route_player.rotation.y-desired,-PI,PI),route_player.camera.rotation.x-1.0))
			var deadzone: float = 0.0
			for action in ACTIONS.slice(0,4): deadzone += InputMap.action_get_deadzone(action)/4.0
			Input.action_press("move_back" if reverse else "move_forward",deadzone+(1.0-deadzone)*minf(1.0,distance*6.0/9.0))
		if tick >= 60 and tick < 240: Input.action_press("fire")
		await physics_frame
		walk_ticks += 1
		var point: Vector3 = route_player.position
		travelled += Vector2(point.x-previous.x,point.z-previous.z).length()
		previous = point
		if tick%30 == 0:
			samples.append({"tick":tick,"x":point.x,"z":point.z,"health":game.state.health,"ammo":game.state.ammo[1],"back":Input.is_action_pressed("move_back"),"forward":Input.is_action_pressed("move_forward"),"fire":Input.is_action_pressed("fire")})
	release_actions()
	await process_frame
	var ok: bool = live_route()
	ok = expect(completed_laps >= 1 and travelled > 40,"Cadence contains real travel and turning/backpedal") and ok
	ok = expect(game.shots.size() == 15 and game.shots.all(func(row): return row[1] == 1 and row[2] and row[3]),"Exactly15 finite pistol shots are accepted in native physics while held") and ok
	ok = expect(game.pickups.size() == 1 and game.pickups[0][1] == "entry_ammo" and game.pickups[0][2] and game.state.removed == ["entry_ammo"] and not route_level.markers.has("entry_ammo"),"Exactly one earned production pickup occurs in native physics") and ok
	ok = expect(game.state.ammo == [0,110,0,0,0,0] and game.state.health > 0 and game.state.armor == 0 and game.state.owned_weapons == [0,1] and game.state.weapon == 1 and game.rate_ok,"Default90 plus earned35 minus15 shots; no grants/refunds/recovery") and ok
	for actor in game.enemies:
		ok = expect(actor.hp > 0 and actor.age-actors[actor.id][1] >= float(CADENCE_TICKS-2)/60.0,"All23 original actors remain alive and automatic: "+actor.id) and ok
	print("PROFILE_CADENCE ",JSON.stringify({"ticks":walk_ticks,"laps":completed_laps,"metres":travelled,"health":game.state.health,"ammo":game.state.ammo,"shots":game.shots,"pickups":game.pickups,"samples":samples,"scope":"real Main/native input and physics; upward fire/no enemy removal; not GPU/physical/display/400FPS acceptance"}))
	if ok: print("PASS turn/backpedal/native firing cadence with finite earned resources and all23 automatic original actors")
	await finish(0 if ok else 1)
