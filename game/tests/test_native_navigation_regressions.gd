extends SceneTree

# Behavioral port of retained route boundaries/goals; native execution belongs to the parent.
const Owner = preload("res://scripts/navigation_routes.gd")

class NativeGame extends "res://scripts/main.gd":
	func _ready() -> void: set_process(false)

class Step extends Node:
	var actor
	var pending := false
	var destination := Vector3.ZERO
	var traverse := false
	var steps := 0
	var grounded := 0
	var path := PackedVector3Array()
	var path_index := 0
	func _physics_process(delta: float) -> void:
		if pending:
			pending = false
			actor._physics_process(delta)
		if not traverse: return
		var heading: Vector3 = destination-actor.global_position
		heading.y = 0
		if heading.length() < .08 or steps >= 180:
			traverse = false
			return
		if not path.is_empty():
			while path_index < path.size()-1 and Vector2(actor.global_position.x-path[path_index].x,actor.global_position.z-path[path_index].z).length() <= .15: path_index += 1
			if path_index < path.size()-1:
				heading = path[path_index]-actor.global_position
				heading.y = 0
		var speed := minf(3,heading.length()/delta) if not path.is_empty() and delta > 0 else 3.0
		actor.velocity.x = heading.normalized().x*speed
		actor.velocity.z = heading.normalized().z*speed
		actor.velocity.y -= 24*delta
		actor.move_and_slide()
		steps += 1
		if actor.is_on_floor(): grounded += 1

var game
var routes
var failures := 0
var profile_id := ""

func _initialize() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"),true)
	profile_id = "native_navigation_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	call_deferred("run")

func expect(value: bool, detail: String) -> void:
	print("NATIVE_REGRESSION ",detail," result=",value)
	if value: return
	failures += 1
	push_error(detail)

func setup(index: int, native_terrain: bool = false) -> void:
	game = NativeGame.new()
	# No Main startup/settings read and no save operation; unique paths also guard accidental writes.
	game.progress_path = "user://"+profile_id+"_campaign.json"
	game.settings_path = "user://"+profile_id+"_preferences.json"
	root.add_child(game)
	game.state.new_campaign(1)
	game.state.level_index = index
	game.level = game.Level.new()
	game.add_child(game.level)
	game.level.game = game
	expect(game.level.layout.load_level(index),"SETUP actual layout loads "+str(index))
	if native_terrain: game.level._build_geometry()
	else: game.level._box(Vector3(40,.2,48),Vector3(58,-.1,94),null,true)
	game.player = game.Player.new()
	game.level.add_child(game.player)
	game.player.configure(game)
	game.player.set_physics_process(false)
	game.player.position = Vector3(58,.03,114)
	game.playing = true
	routes = null

func actor_at(role: String, point: Vector3):
	var actor = game.Enemy.new()
	game.level.add_child(actor)
	actor.configure(game,{"id":"native_regression_"+role+"_"+str(game.enemies.size()),"kind":role,"cell":[point.x/4,point.z/4],"yaw":0})
	actor.position = point
	actor.set_physics_process(false)
	actor.alerted = true
	actor.target = game.player
	actor.attack_time = 1000
	game.enemies.append(actor)
	var shape: CapsuleShape3D = actor.get_child(0).shape
	expect(is_equal_approx(shape.radius,game.Enemy.capsule_radius(role)) and is_equal_approx(shape.height,game.Enemy.capsule_height(role)) and actor.collision_mask == (1|2|4),"SETUP unchanged production "+role+" capsule/mask")
	return actor

func publish(role: String) -> bool:
	if routes == null:
		routes = Owner.new()
		routes.name = "NavigationRoutes"
		game.level.add_child(routes)
		var profiles := {}
		profiles[role] = {"radius":game.Enemy.capsule_radius(role),"height":game.Enemy.capsule_height(role),"hover":1.16 if role in ["caster","choir_avatar"] else 0.0}
		expect(routes.configure(game.level,profiles),"SETUP native owner accepts real role "+role)
	else:
		routes.invalidate_doors()
	# Wait for the actual bake first, then allow two real seconds for publication.
	var deadline := Time.get_ticks_usec()+2000000
	while routes._roles.has(role) and (routes._dirty or not routes._pending.is_empty() or routes._roles[role].mesh == null) and Time.get_ticks_usec() < deadline:
		OS.delay_msec(2)
		await process_frame
		await physics_frame
	deadline = Time.get_ticks_usec()+2000000
	while not routes.is_ready(role) and Time.get_ticks_usec() < deadline:
		OS.delay_msec(2)
		await process_frame
		await physics_frame
	expect(routes.is_ready(role),"Native role publishes within two real seconds after bake: "+role)
	return routes.is_ready(role)

func tick(driver: Step) -> void:
	driver.pending = true
	while driver.pending: await physics_frame

func floor_anchor(point: Vector3) -> Vector3:
	var size: float = game.level.layout.data.cell_size
	return game.level.layout.world_position([point.x/size,point.z/size])+Vector3.UP*.03

func capsule_query(actor, start: Vector3, end: Vector3) -> PhysicsShapeQueryParameters3D:
	var collider: CollisionShape3D = actor.get_child(0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.transform = Transform3D(Basis.IDENTITY,start+collider.position)
	query.motion = end-start
	query.margin = actor.safe_margin
	query.collision_mask = 1|2|4
	query.exclude = [actor.get_rid(),game.player.get_rid()]
	return query

func capsule_clear(actor, start: Vector3, end: Vector3) -> bool:
	var query := capsule_query(actor,start,end)
	var space = actor.get_world_3d().direct_space_state
	if not space.intersect_shape(query,1).is_empty(): return false
	var fraction: PackedFloat32Array = space.cast_motion(query)
	return fraction.size() == 2 and fraction[0] >= .9999

func check_flat_path(actor, path: PackedVector3Array, detail: String) -> void:
	expect(path.size() >= 2,detail+" reaches a native endpoint")
	var lift := Vector3.UP if actor.kind in ["caster","choir_avatar"] else Vector3.ZERO
	for index in range(1,path.size()):
		expect(capsule_clear(actor,path[index-1]+lift,path[index]+lift),detail+" admits actual capsule segment "+str(index))

func path_length(path: PackedVector3Array) -> float:
	var result := 0.0
	for index in range(1,path.size()): result += path[index-1].distance_to(path[index])
	return result

func close() -> void:
	game.playing = false
	game.free()
	game = null
	routes = null
	OS.delay_msec(100)
	await process_frame
	await process_frame

func goals() -> void:
	setup(0)
	var base = game.level._box(Vector3(6.6,.55,6.6),Vector3(58,.275,88),null,true)
	game.player.position = Vector3(58,.03,84.15)
	var actor = actor_at("crawler",Vector3(58,.03,98))
	if await publish("crawler"):
		await physics_frame
		expect(not capsule_clear(actor,Vector3(58,.03,86),Vector3(58,.03,86)),"SETUP actual target-cell center is inside retained prop")
		var path: PackedVector3Array = routes.route(floor_anchor(actor.global_position),floor_anchor(game.player.global_position),actor.kind)
		check_flat_path(actor,path,"Actual target outside prop does not require occupied cell center")
		var point: Vector3 = actor._next_step(game.player.global_position)
		expect(point != actor.global_position and capsule_clear(actor,actor.global_position,point),"Enemy selects capsule-clear native detour to actual target")
	base.free()
	actor.position = Vector3(56.5,.03,85)
	game.player.position = Vector3(59.5,.03,87)
	game.level._box(Vector3(.6,.55,.6),Vector3(58,.275,86),null,true)
	if await publish("crawler"):
		await physics_frame
		expect(not capsule_clear(actor,actor.global_position,game.player.global_position),"SETUP same-cell target has blocked direct capsule travel")
		var point: Vector3 = actor._next_step(game.player.global_position)
		expect(point != actor.global_position and point != Vector3(58,0,86) and capsule_clear(actor,actor.global_position,point),"Blocked same-cell target selects a checked detour, not occupied center")
	await close()

	setup(0)
	game.level._box(Vector3(6.6,.55,6.6),Vector3(58,.275,88),null,true)
	game.player.position = Vector3(58,.03,94)
	actor = actor_at("worker",Vector3(58,.03,82))
	if await publish("worker"):
		var driver := Step.new()
		driver.actor = actor
		root.add_child(driver)
		await tick(driver)
		var sight := PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP,game.player.global_position+Vector3.UP,1)
		expect(actor.get_world_3d().direct_space_state.intersect_ray(sight).is_empty(),"SETUP ranged strafe has clear actual LOS above retained low base")
		var intended: Vector3 = actor.waypoint-actor.global_position
		intended.y = 0
		expect(actor._routing and Vector2(actor.velocity.x,actor.velocity.z).dot(Vector2(intended.x,intended.z)) > 0,"Ranged strafe does not override actual capsule-clear native detour")
		driver.free()
	await close()

func doors() -> void:
	setup(0)
	var actor = actor_at("crawler",Vector3(58,.03,82))
	var door = game.level._box(Vector3(16,3,.6),Vector3(58,1.5,98),null,true)
	game.level.doors["native_fixture"] = door
	if await publish("crawler"):
		await physics_frame
		var start: Vector3 = actor.global_position
		var goal: Vector3 = game.player.global_position
		expect(not capsule_clear(actor,start,goal),"SETUP actual closed door blocks direct capsule travel")
		var closed: PackedVector3Array = routes.route(start,goal,actor.kind)
		check_flat_path(actor,closed,"Closed door detour")
		game.level.open_door("native_fixture")
		expect(not routes.is_ready(actor.kind) and routes.route(start,goal,actor.kind).is_empty(),"Normal door opening immediately rejects stale geometry")
		if await publish("crawler"):
			await physics_frame
			var opened: PackedVector3Array = routes.route(start,goal,actor.kind)
			check_flat_path(actor,opened,"Opened door route")
			expect(capsule_clear(actor,start,goal) and path_length(opened) < path_length(closed)-2,"Normal native opening produces shorter physically clear route")
		game.level._box(Vector3(40,3,.6),Vector3(58,1.5,98),null,true)
		if await publish("crawler"):
			await physics_frame
			expect(routes.route(start,goal,actor.kind).is_empty(),"Unreachable target rejects native partial route")
			expect(actor._next_step(goal) == actor.global_position,"Enemy holds rather than inventing unreachable progress")
	await close()

func arrival_and_sight() -> void:
	setup(0)
	var actor = actor_at("crawler",Vector3(58,.03,82))
	var driver := Step.new()
	driver.actor = actor
	root.add_child(driver)
	if await publish("crawler"):
		await tick(driver)
		expect(actor.path_time > .9,"SETUP clear native route acquired before timer expires")
		expect(not actor._routing,"Unobstructed native path retains direct steering")
		var cached_waypoint: Vector3 = actor.waypoint
		game.level._box(Vector3(4,3,.5),Vector3(58,1.5,98),null,true)
		if await publish("crawler"):
			for frame in range(65): await tick(driver)
			var sight := PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP,game.player.global_position+Vector3.UP,1)
			expect(not actor.get_world_3d().direct_space_state.intersect_ray(sight).is_empty(),"SETUP newly acquired wall blocks actual LOS")
			# The route API uses floor anchors; an inflated cast from settled feet overlaps supporting floor.
			expect(actor._routing and actor.waypoint != cached_waypoint and Vector2(actor.waypoint.x-actor.global_position.x,actor.waypoint.z-actor.global_position.z).length() > .01 and actor.is_on_floor() and capsule_clear(actor,floor_anchor(actor.global_position),actor.waypoint),"Acquired blocked LOS replaces cached direct steering through normal AI throttle with capsule-clear progressing detour")
			var before_detour: Vector3 = actor.global_position
			for frame in range(20): await tick(driver)
			expect(actor.is_on_floor() and Vector2(actor.global_position.x-before_detour.x,actor.global_position.z-before_detour.z).length() > 1,"Actual native capsule progresses on the replacement route with floor support")
	actor.position = Vector3(54,.03,89.97)
	actor.waypoint = Vector3(54,0,90)
	actor.path_time = 1
	actor._routing = true
	actor.recovery_time = .5
	await tick(driver)
	expect(actor.path_time > .9 and absf(actor.global_position.z-89.97) < .002,"Held recovery does not reset route throttle before actual arrival")
	actor.recovery_time = 0
	actor.position = Vector3(54,.03,89.15)
	actor.waypoint = Vector3(54,0,89.18)
	actor.path_time = 1
	var crowd = actor_at("crawler",Vector3(54,.03,90))
	await physics_frame
	await physics_frame
	await tick(driver)
	var crowd_contact := false
	for index in actor.get_slide_collision_count():
		if actor.get_slide_collision(index).get_collider() == crowd: crowd_contact = true
	expect(crowd_contact and actor.path_time > .9 and absf(actor.global_position.z-89.18) > .005,"Actual crowd capsule contact cannot reset route throttle before physical progress")
	crowd.free()
	actor.position = Vector3(54,.03,89.97)
	actor.waypoint = Vector3(54,0,90)
	actor.path_time = 1
	await tick(driver)
	expect(absf(actor.global_position.z-90) < .002,"Routed arrival clamps movement to remaining waypoint distance")
	await tick(driver)
	expect(actor.global_position.z >= 89.998,"Arrival refreshes native waypoint without cached backtracking")
	driver.free()
	await close()

func crests() -> void:
	for entry in [[0,Vector2(22.5,8.5),Vector2(23.5,8.5),"crawler"],[1,Vector2(20,7),Vector2(21,7),"crawler"],[4,Vector2(24.75,22.25),Vector2(24.3,22.6),"nursery_warden"]]:
		setup(entry[0],true)
		expect(game.level.layout.is_walkable(Vector2i(entry[1].floor())) and game.level.layout.is_walkable(Vector2i(entry[2].floor())),"SETUP actual authored crest endpoints are walkable "+str(entry[0]))
		var a: Vector3 = game.level.layout.world_position([entry[1].x,entry[1].y])+Vector3.UP*.03
		var b: Vector3 = game.level.layout.world_position([entry[2].x,entry[2].y])+Vector3.UP*.03
		var actor = actor_at(entry[3],a)
		var driver := Step.new()
		driver.actor = actor
		root.add_child(driver)
		await physics_frame
		await physics_frame
		# Preserve the independent physical control even when a conservative bake rejects the crest.
		for destination in [b,a]:
			driver.destination = destination
			driver.steps = 0
			driver.grounded = 0
			driver.traverse = true
			while driver.traverse: await physics_frame
			var gap := Vector2(actor.global_position.x-destination.x,actor.global_position.z-destination.z).length()
			print("CREST_CONTROL role=",entry[3]," map=",entry[0]," destination=",destination," actual=",actor.global_position," gap=",gap," steps=",driver.steps," grounded=",driver.grounded)
			expect(driver.steps > 0 and gap < .08 and driver.grounded >= driver.steps-3,"Actual unchanged "+entry[3]+" capsule physically traverses crest with native floor contact "+str(entry[0]))
			var ray := PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*3,actor.global_position-Vector3.UP*3,1)
			var support: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(ray)
			expect(not support.is_empty() and support.normal.y > .5,"Actual crest traversal retains native supporting floor")
		if await publish(entry[3]):
			await physics_frame
			for pair in [[a,b],[b,a]]:
				var path: PackedVector3Array = routes.route(pair[0],pair[1],entry[3])
				expect(path.size() >= 2 and path[-1].distance_to(pair[1]) < Owner.ENDPOINT_TOLERANCE+.04,"Native owner must admit physically proven crest direction "+str(entry[0])+"/"+entry[3])
				print("CREST_NATIVE map=",entry[0]," role=",entry[3]," start=",pair[0]," goal=",pair[1]," path=",path)
				if path.size() < 2: continue
				driver.path = path
				driver.path_index = 0
				driver.destination = pair[1]
				driver.steps = 0
				driver.grounded = 0
				driver.traverse = true
				while driver.traverse: await physics_frame
				var gap := Vector2(actor.global_position.x-pair[1].x,actor.global_position.z-pair[1].z).length()
				expect(driver.steps > 0 and gap < .08 and driver.grounded >= driver.steps-3,"Native crest path physically carries unchanged capsule with floor contact "+str(entry[0])+"/"+entry[3])
				print("CREST_NATIVE_TRAVERSAL map=",entry[0]," role=",entry[3]," actual=",actor.global_position," gap=",gap," steps=",driver.steps," grounded=",driver.grounded)
		driver.free()
		await close()

func hover_and_contacts() -> void:
	setup(0)
	game.level._box(Vector3(6.6,.55,6.6),Vector3(58,.275,98),null,true)
	var actor = actor_at("caster",Vector3(58,1.03,82))
	if await publish("caster"):
		await physics_frame
		expect(capsule_clear(actor,actor.global_position,game.player.global_position+Vector3.UP),"Actual hover-height capsule clears retained low base despite grounded target")
		var path: PackedVector3Array = routes.route(floor_anchor(actor.global_position),floor_anchor(game.player.global_position),actor.kind)
		check_flat_path(actor,path,"Hover role floor-anchor navigation")
		var driver := Step.new()
		driver.actor = actor
		root.add_child(driver)
		await tick(driver)
		var ray := PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*.5,actor.global_position-Vector3.UP*6,1)
		var support: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(ray)
		expect(not support.is_empty() and actor.global_position.y-support.position.y > .5 and actor.global_position.y-support.position.y < 1.5,"Actual native caster tick preserves hovering floor offset")
		driver.free()
	await close()

	setup(4,true)
	var start: Vector3 = game.level.layout.world_position([24.3,22.6])
	var goal: Vector3 = game.level.layout.world_position([24.75,22.25])
	actor = actor_at("choir_avatar",start+Vector3.UP)
	game.level._box(Vector3(.6,.98,.6),goal+Vector3.UP*.49,null,true)
	await physics_frame
	await physics_frame
	var query := capsule_query(actor,goal+Vector3.UP,goal+Vector3.UP+Vector3(.1,0,0))
	expect(actor.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(),"SETUP unchanged 1m hovering capsule clears .98m obstruction on actual Nursery floor")
	if await publish("choir_avatar"):
		await physics_frame
		var point: Vector3 = actor._next_step(goal)
		expect(point != actor.global_position,"Floating slope-to-flat native pursuit preserves a physically valid hover goal")
		game.player.position = goal
		var driver := Step.new()
		driver.actor = actor
		root.add_child(driver)
		await tick(driver)
		var ray := PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*.5,actor.global_position-Vector3.UP*6,1)
		var support: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(ray)
		expect(not support.is_empty() and actor.global_position.y-support.position.y > .5 and actor.global_position.y-support.position.y < 1.5,"Actual floating crest tick uses native floor offset, not prior slope support")
		driver.free()
	await close()

	setup(0)
	actor = actor_at("crawler",Vector3(58,.03,82))
	game.level._box(Vector3(2,2,2),Vector3(58,1,82),null,true)
	if await publish("crawler"):
		await physics_frame
		expect(not capsule_clear(actor,actor.global_position,Vector3(58,.03,90)),"Actual blocked start overlaps native capsule")
		expect(routes.route(actor.global_position,Vector3(58,.03,90),actor.kind).is_empty(),"Blocked starting overlap is not accepted as native route")
	await close()

	setup(0)
	actor = actor_at("crawler",Vector3(58,.03,82))
	game.level._box(Vector3(4,.2,4),Vector3(58,.9,90),null,true)
	if await publish("crawler"):
		await physics_frame
		expect(not capsule_clear(actor,actor.global_position,Vector3(58,.03,94)),"Actual low ceiling obstructs unchanged capsule's direct travel")
		check_flat_path(actor,routes.route(actor.global_position,Vector3(58,.03,94),actor.kind),"Native low-ceiling detour")
	await close()

func run() -> void:
	preload("res://scripts/preferences.gd").new().apply_bindings()
	expect(Engine.physics_ticks_per_second == 60,"SETUP native sixty-Hz physics required")
	await goals()
	await doors()
	await arrival_and_sight()
	await crests()
	await hover_and_contacts()
	print("PASS native navigation behavioral regressions; not campaign/FPS/app acceptance" if failures == 0 else "FAIL native navigation behavioral regressions: "+str(failures))
	quit(0 if failures == 0 else 1)
