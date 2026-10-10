extends "res://tests/test_active_boss_fights.gd"

const WALK_LIMIT = 600
const WAYPOINTS = [[11.7,28.5],[11.7,27.0],[11.7,28.5],[14.5,28.5]]
var walk_ticks: int = 0
var travelled: float = 0.0
var peak: float = 0.0
var origin: Vector3
var previous: Vector3
var route_level
var route_player
var actors: Dictionary = {}

func run() -> void:
	prefix = "user://intake_walk_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	release_actions()
	if not expect(Engine.physics_ticks_per_second == 60,"SETUP: requires native 60-Hz physics"):
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
	if not await walk_route():
		await finish(1)
		return
	print("PASS source-native Intake entry-ammo round trip; virtual movement, automatic CharacterBody3D physics and all 23 authored actors; no firing or staging. Not full Intake/campaign traversal, ammo balance, human/physical input, GPU or packed-app acceptance.")
	await finish(0)

func press_menu(label: String) -> bool:
	for node in game.menu.get_children():
		if node is Button and not node.is_queued_for_deletion() and node.text == label:
			node.pressed.emit()
			return true
	return expect(false,"Actual menu callback missing: "+label)

func wait_entry() -> bool:
	for frame in range(120):
		if game.playing and not game.placement_pending and is_instance_valid(game.player): break
		await physics_frame
	if not expect(game.playing and not game.placement_pending and is_instance_valid(game.level) and is_instance_valid(game.player) and not paused,"Actual menu startup must finish within 120 physics frames"): return false
	await physics_frame
	await physics_frame
	route_level = game.level
	route_player = game.player
	var data: Dictionary = route_level.layout.data
	if not expect(data.id == "intake" and data.spawn == [14.5,28.5] and data.cell_size == 4 and game.state.level_index == 0 and game.state.difficulty == 1,"Fixture pins actual Intake/Relentless entry geometry"): return false
	if not expect(game.state.health == 100 and game.state.armor == 0 and game.state.ammo == [0,90,0,0,0,0] and game.state.owned_weapons == [0,1] and game.state.weapon == 1 and game.state.removed.is_empty(),"Fresh entry has unmodified default resources"): return false
	var actual: Array = game.enemies.map(func(actor): return actor.id)
	var authored: Array = data.enemies.map(func(spec): return spec.id)
	actual.sort()
	authored.sort()
	if not expect(actual == authored and actual.size() == 23,"All 23 authored Intake actors start"): return false
	for actor in game.enemies: actors[actor.id] = [actor.get_instance_id(),actor.age]
	origin = route_player.position
	previous = origin
	return expect(origin.distance_to(route_level.layout.world_position(data.spawn)) < 0.1 and clear_point(data.spawn) != null,"Entry must be actual spawn with native floor/capsule clearance")

func walk_route() -> bool:
	var supplies: Array = route_level.layout.data.pickups.filter(func(spec): return spec.id == "entry_ammo")
	if not expect(supplies.size() == 1,"Actual entry supply exists"): return false
	var supply: Dictionary = supplies[0]
	if not expect(supply.kind == "ammo" and supply.weapon == 1 and supply.amount == 35 and supply.cell == [12.0,27.0] and route_level.markers.has(supply.id),"Fixture pins finite authored pistol supply"): return false
	# Seven-lamps base covers the pickup center; approach its west edge, never teleport.
	for leg in range(WAYPOINTS.size()):
		var target = clear_point(WAYPOINTS[leg])
		if not expect(target != null,"BLOCKED native endpoint: "+str(WAYPOINTS[leg])+"; smaller fallback is spawn-to-west-aisle-and-back, without pickup acceptance"): return false
		var start: Vector3 = route_player.position
		var samples: int = ceili(start.distance_to(target)/0.5)
		for sample in range(samples+1):
			var point: Vector3 = start.lerp(target,float(sample)/maxi(1,samples))
			if not expect(clear_point([point.x/4.0,point.z/4.0]) != null,"BLOCKED native capsule along leg "+str(leg)+" at "+str(point)+"; no route acceptance"): return false
		while Vector2(route_player.position.x-target.x,route_player.position.z-target.z).length() > 0.12:
			if not live_route() or not expect(walk_ticks < WALK_LIMIT,"Route exceeded 600 physics ticks; inspect last waypoint/position instead of widening the bot"): return false
			var distance: float = Vector2(route_player.position.x-target.x,route_player.position.z-target.z).length()
			route_player.look_at(Vector3(target.x,route_player.position.y,target.z),Vector3.UP)
			var deadzone: float = 0.0
			for action in ["move_left","move_right","move_forward","move_back"]: deadzone += InputMap.action_get_deadzone(action)/4.0
			Input.action_press("move_forward",deadzone+(1.0-deadzone)*minf(1.0,distance*6.0/9.0))
			if not await route_tick(): return false
		release_actions()
		for settling in range(12):
			if not await route_tick(): return false
		await process_frame # Actual Main proximity collection, never a manual gameplay step.
		if not expect(route_player.position.distance_to(target) < 0.2,"Real locomotion must settle at waypoint "+str(leg)): return false
		print("INTAKE_WALK leg=",leg," tick=",walk_ticks," position=",route_player.position," metres=",travelled," peak=",peak," ammo=",game.state.ammo[1]," health=",game.state.health)
		if leg >= 1 and not expect(game.state.ammo == [0,125,0,0,0,0] and game.state.removed.count(supply.id) == 1 and not route_level.markers.has(supply.id),"Automatic real pickup adds exactly 35 pistol rounds once; no shots or refill"): return false
	if not live_route(): return false
	for actor in game.enemies:
		if not expect(actor.age-actors[actor.id][1] >= float(walk_ticks-2)/60.0,"Every retained actor advances automatic native age: "+actor.id): return false
	return expect(peak >= 10.0 and travelled >= 30.0 and route_player.position.distance_to(origin) < 0.2 and game.ticks >= walk_ticks-2 and game.rate_ok and game.state.armor == 0 and game.state.weapon == 1 and game.state.owned_weapons == [0,1],"Measured real out-and-back displacement, automatic Main/actors, live health and unchanged inventory ownership")

func route_tick() -> bool:
	if not expect(walk_ticks < WALK_LIMIT,"Route including settling is bounded to 600 ticks"): return false
	await physics_frame
	walk_ticks += 1
	if not live_route(): return false
	var point: Vector3 = route_player.position
	travelled += Vector2(point.x-previous.x,point.z-previous.z).length()
	peak = maxf(peak,Vector2(point.x-origin.x,point.z-origin.z).length())
	previous = point
	return true

func live_route() -> bool:
	if not expect(not paused and game.playing and not game.placement_pending and game.state.level_index == 0 and game.level == route_level and game.player == route_player and is_instance_valid(route_level) and is_instance_valid(route_player) and not route_level.is_queued_for_deletion() and route_player._current_map() and game.state.health > 0 and game.state.health <= 100 and game.is_processing() and game.is_physics_processing() and route_player.is_physics_processing(),"Route must retain live unpaused current-map automatic processing; no recovery/scene replacement"): return false
	if not expect(game.enemies.size() == actors.size(),"Route retains the complete actor count"): return false
	var seen: Dictionary = {}
	for actor in game.enemies:
		if not expect(is_instance_valid(actor) and actors.has(actor.id) and actor.get_instance_id() == actors[actor.id][0] and actor._current_map() and actor.is_physics_processing(),"Route retains each original automatically processing actor"): return false
		seen[actor.id] = true
	return expect(seen.size() == actors.size(),"All 23 original identities remain distinct")

func clear_point(cell: Array):
	var layout = route_level.layout
	if not layout.is_walkable(Vector2i(floori(cell[0]),floori(cell[1]))): return null
	var point: Vector3 = layout.world_position(cell)
	var space = route_level.get_world_3d().direct_space_state
	var hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*2,point-Vector3.UP*0.5,1))
	if hit.is_empty() or absf(hit.position.y-point.y) > 0.08 or hit.normal.y < 0.7: return null
	var collider: CollisionShape3D = route_player.get_child(0)
	var pose: Vector3 = point+Vector3.UP*0.04
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.transform = Transform3D(Basis.IDENTITY,pose+collider.position)
	query.collision_mask = route_player.collision_mask
	query.exclude = [route_player.get_rid()]
	return pose if space.intersect_shape(query,1).is_empty() else null
