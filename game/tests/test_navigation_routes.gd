extends SceneTree

# Geometry-owner witness only; no Enemy AI adoption or app/performance claim.
const Owner = preload("res://scripts/navigation_routes.gd")
const Level = preload("res://scripts/level.gd")
const Enemy = preload("res://scripts/enemy.gd")
const START := Vector3(4,.03,4)
const GOAL := Vector3(4,.03,20)
var failures := 0
var host: Node
var level
var routes
var actor: CharacterBody3D
var callback_mode := ""
var callback_seen: Array[String] = []

func reconfigure_from_notification(role: String, _revision: int, _ready: bool) -> void:
	callback_seen.append(role)
	if callback_mode == "": return
	var mode := callback_mode
	callback_mode = ""
	if mode == "teardown":
		routes.teardown()
	else:
		routes.configure(level,{"brute":{"radius":.6,"height":2.0,"hover":0.0}})

class Follow extends Node:
	var body: CharacterBody3D
	var path: PackedVector3Array
	var base: Node3D
	var index := 0
	var steps := 0
	var grounded := 0
	var contacts := 0
	var done := false
	var reached := false
	func _physics_process(delta: float) -> void:
		if done: return
		if Vector2(body.position.x-path[-1].x,body.position.z-path[-1].z).length() < .2 or steps >= 360:
			reached = steps < 360
			done = true
			return
		while index < path.size()-1 and Vector2(body.position.x-path[index].x,body.position.z-path[index].z).length() < .15: index += 1
		var heading: Vector3 = path[index]-body.position
		heading.y = 0
		var speed := minf(5.4,heading.length()/delta) if delta > 0 else 0.0
		body.velocity.x = heading.normalized().x*speed
		body.velocity.z = heading.normalized().z*speed
		body.velocity.y -= 24*delta
		body.move_and_slide()
		steps += 1
		if body.is_on_floor(): grounded += 1
		for number in body.get_slide_collision_count():
			var contact := body.get_slide_collision(number)
			if contact.get_collider() == base and absf(contact.get_normal().y) < .25: contacts += 1

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool, detail: String) -> void:
	if condition: return
	failures += 1
	push_error(detail)

func make_level():
	var result = Level.new()
	host.add_child(result)
	result.game = host
	result.layout.data = {"cell_size":4.0,"elevations":[],"ceilings":[]}
	for x in range(6):
		for z in range(7): result.layout.tiles[Vector2i(x,z)] = true
	result._box(Vector3(24,.2,28),Vector3(12,-.1,14),null,true)
	return result

func wait_ready(role: String) -> bool:
	for frame in range(90):
		await process_frame
		await physics_frame
		if routes.is_ready(role): return true
	expect(false,"Owned map must synchronize with a real closest-point witness: "+role)
	return false

func path_length(path: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1,path.size()): total += path[i-1].distance_to(path[i])
	return total

func check_capsule(path: PackedVector3Array) -> void:
	expect(Engine.is_in_physics_frame(),"Capsule sweeps require a native physics frame")
	var collider: CollisionShape3D = actor.get_child(0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.margin = actor.safe_margin
	query.collision_mask = 1
	query.exclude = [actor.get_rid()]
	for i in range(1,path.size()):
		query.transform = Transform3D(Basis.IDENTITY,path[i-1]+collider.position)
		query.motion = path[i]-path[i-1]
		expect(actor.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(),"Native route starts clear of retained static solids")
		var fraction := actor.get_world_3d().direct_space_state.cast_motion(query)
		expect(fraction.size() == 2 and fraction[0] >= .9999,"Native route admits the original crawler capsule")

func run() -> void:
	host = Host.new()
	# The fixture host exposes the same authoritative current-level field as Main.
	root.add_child(host)
	level = make_level()
	host.level = level
	var base = level._box(Vector3(6.6,.55,6.6),Vector3(12,.275,12),null,true)
	var door = level._box(Vector3(16,5,.6),Vector3(8,2.5,12),null,true)
	level.doors["fixture"] = door
	actor = CharacterBody3D.new()
	level.add_child(actor)
	actor.position = START
	actor.collision_layer = 4
	actor.collision_mask = 1|2|4
	actor.floor_snap_length = .5
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = Enemy.capsule_radius("crawler")
	capsule.height = Enemy.capsule_height("crawler")
	collider.shape = capsule
	collider.position.y = capsule.height/2
	actor.add_child(collider)
	routes = Owner.new()
	level.add_child(routes)
	var profile := {"radius":capsule.radius,"height":capsule.height,"hover":0.0}
	expect(routes.configure(level,{"crawler":profile}),"Owner config accepts actual crawler dimensions")
	expect(not routes.is_ready("crawler") and routes.route(START,GOAL,"crawler").is_empty(),"Construction frame cannot publish routes")
	if not await wait_ready("crawler"): await finish(); return
	expect(not NavigationServer3D.region_get_use_async_iterations(routes._roles.crawler.region),"Owned region updates are synchronous to prevent dropped mesh publication")
	expect(NavigationServer3D.map_get_use_async_iterations(routes._roles.crawler.map),"Native map updates remain asynchronous")
	var closed: PackedVector3Array = routes.route(START,GOAL,"crawler")
	expect(closed.size() > 2 and path_length(closed) > 23,"Closed real door forces a detour")
	check_capsule(closed)
	var old_revision: int = routes.revision
	level.open_door("fixture")
	routes.invalidate_doors()
	routes.invalidate_doors()
	expect(routes.revision == old_revision+1 and not routes.is_ready("crawler"),"Repeated dirty requests coalesce and immediately reject old routes")
	expect(routes.route(START,GOAL,"crawler").is_empty(),"A previous-map path cannot escape while rebuilding")
	if not await wait_ready("crawler"): await finish(); return
	var opened: PackedVector3Array = routes.route(START,GOAL,"crawler")
	print("OWNER_PATHS closed=",closed," closed_length=",path_length(closed)," open=",opened," open_length=",path_length(opened)," revision=",routes.revision," source_bounds=",routes._source.get_bounds())
	expect(opened.size() >= 2 and path_length(opened) < path_length(closed)-2,"Door collision-layer removal shortens rebuilt native path")
	check_capsule(opened)
	var base_path: PackedVector3Array = routes.route(Vector3(12,.03,4),Vector3(12,.03,20),"crawler")
	print("OWNER_BASE_PATH ",base_path," ready=",routes.is_ready("crawler")," queries=",routes._queries," tick=",routes._query_tick)
	var native_map: RID = routes._roles.crawler.map
	print("OWNER_RAW_PATH ",NavigationServer3D.map_get_path(native_map,START,GOAL,true,1)," closest_start=",NavigationServer3D.map_get_closest_point(native_map,START)," closest_goal=",NavigationServer3D.map_get_closest_point(native_map,GOAL))
	print("OWNER_ENABLED ",NavigationServer3D.region_get_enabled(routes._roles.crawler.region)," layers=",NavigationServer3D.region_get_navigation_layers(routes._roles.crawler.region)," iteration=",NavigationServer3D.map_get_iteration_id(native_map))
	print("OWNER_SELF_PATH ",NavigationServer3D.map_get_path(native_map,routes._roles.crawler.witness,routes._roles.crawler.witness,true,1))
	expect(base_path.size() > 2,"Retained base cannot become a direct shortcut")
	check_capsule(base_path)
	if base_path.size() > 2:
		actor.position = Vector3(12,.03,4)
		var driver := Follow.new()
		driver.body = actor
		driver.path = base_path
		driver.base = base
		root.add_child(driver)
		while not driver.done: await physics_frame
		expect(driver.reached and driver.grounded >= driver.steps-3 and driver.contacts == 0,"Native move_and_slide follows owner path around the unchanged base; not Enemy AI")
		driver.free()
	level._box(Vector3(24,5,.6),Vector3(12,2.5,24),null,true)
	routes.invalidate_doors()
	if not await wait_ready("crawler"): await finish(); return
	expect(routes.route(START,Vector3(4,.03,26),"crawler").is_empty(),"Disconnected legitimate goal rejects partial native paths")
	expect(routes.route(START,Vector3(4,.03,26),"crawler",2).is_empty(),"Pursuit approach tolerance cannot accept a disconnected partial path")
	expect(routes.route(START,GOAL,"crawler",NAN).is_empty() and routes.route(START,GOAL,"crawler",7).is_empty(),"Nonfinite or excessive approach tolerance fails closed")
	expect(routes.route(Vector3(NAN,0,0),GOAL,"crawler").is_empty(),"Nonfinite route input fails closed")
	expect(routes.route(START,GOAL,"missing").is_empty(),"Unknown profiles fail closed")
	await physics_frame
	print("OWNER_BUDGET_START ready=",routes.is_ready("crawler")," queries=",routes._queries," tick=",routes._query_tick," current_tick=",Engine.get_physics_frames()," closest_start=",NavigationServer3D.map_get_closest_point(routes._roles.crawler.map,START)," closest_goal=",NavigationServer3D.map_get_closest_point(routes._roles.crawler.map,GOAL))
	for i in range(Owner.MAX_QUERIES_PER_TICK):
		expect(not routes.route(START,GOAL,"crawler").is_empty(),"Forty native queries fit the per-tick budget")
	expect(routes.route(START,GOAL,"crawler").is_empty(),"Per-tick query cap rejects excess work without fallback")
	await physics_frame
	expect(not routes.route(START,GOAL,"crawler").is_empty(),"A new physics tick restores the query budget")
	# Ceilings are authored visual triangles, not colliders; the owner must add them.
	level.layout.data.ceilings = [{"rect":[0,0,5,6],"height":2.0}]
	expect(routes.configure(level,{"crawler":profile,"worker":{"radius":Enemy.capsule_radius("worker"),"height":Enemy.capsule_height("worker"),"hover":0.0},"hover":{"radius":capsule.radius,"height":capsule.height,"hover":1.16}}),"Role-aware rebuild config accepts grounded and hovering envelopes")
	if not await wait_ready("crawler"): await finish(); return
	for frame in range(90):
		await process_frame
		await physics_frame
		if routes._pending.is_empty(): break
	expect(not routes.route(START,GOAL,"crawler").is_empty(),"Crawler retains access below two-meter visual roof")
	expect(not routes.is_ready("worker") and not routes.is_ready("hover"),"Tall and hovering envelopes cannot navigate beneath low roof")
	expect(routes._roles.worker.mesh.get_polygon_count() == 0 and routes._roles.hover.mesh.get_polygon_count() == 0,"Baked polygons prove low-roof exclusion rather than pending synchronization")
	# Parsing and manual roof faces must share the Level-local transform.
	level.position = Vector3(100,3,-50)
	level.rotation.y = .6
	expect(routes.configure(level,{"crawler":profile,"worker":{"radius":Enemy.capsule_radius("worker"),"height":Enemy.capsule_height("worker"),"hover":0.0}}),"Transformed low-roof owner accepts roles")
	if not await wait_ready("crawler"): await finish(); return
	for frame in range(90):
		await process_frame
		await physics_frame
		if routes._pending.is_empty(): break
	expect(not routes.route(level.to_global(START),level.to_global(GOAL),"crawler").is_empty(),"Translated/yaw-rotated roof preserves crawler path")
	expect(routes._roles.worker.mesh.get_polygon_count() == 0,"Translated/yaw-rotated roof excludes tall actor in native bake")
	level.position = Vector3.ZERO
	level.rotation.y = 0
	level.layout.data.ceilings = []
	routes.readiness_changed.connect(reconfigure_from_notification)
	callback_mode = "replace"
	callback_seen.clear()
	expect(not routes.configure(level,{"crawler":profile,"worker":{"radius":.42,"height":2.1,"hover":0.0}}),"Reentrant configure cannot certify its retired generation")
	expect(callback_seen == ["crawler","brute"] and routes._roles.keys() == ["brute"],"Notification cannot continue retired profiles under a new revision")
	callback_mode = "teardown"
	callback_seen.clear()
	expect(not routes.configure(level,{"crawler":profile}),"Synchronous teardown cancels configure success")
	expect(routes._roles.is_empty() and not routes.is_processing() and not routes.is_physics_processing(),"Cancelled configure leaves no resource or enabled process")
	callback_mode = ""
	routes.readiness_changed.disconnect(reconfigure_from_notification)
	expect(routes.configure(level,{"crawler":profile}),"Owner remains reusable after callback cancellation")
	if not await wait_ready("crawler"): await finish(); return
	routes.readiness_changed.connect(reconfigure_from_notification)
	callback_seen.clear()
	callback_mode = "replace"
	# Already-ready first profile emits from _physics_process, not configure().
	routes._roles.crawler.ready = false
	routes._roles.crawler.sync = true
	routes._roles.crawler.version = 0
	await physics_frame
	await physics_frame
	expect(callback_seen == ["crawler","brute"] and routes._roles.keys() == ["brute"],"Ready callbacks cannot resume iteration into replacement profiles")
	routes.readiness_changed.disconnect(reconfigure_from_notification)
	expect(routes.configure(level,{"crawler":profile}),"Owner recovers after ready callback replacement")
	if not await wait_ready("crawler"): await finish(); return
	var old_routes = routes
	var old_map: RID = routes._roles.crawler.map
	var mesh_ref: WeakRef = weakref(routes._roles.crawler.mesh)
	var source_ref: WeakRef = weakref(routes._source)
	var replacement = make_level()
	host.level = replacement
	old_routes.invalidate_doors()
	expect(not old_routes.is_ready("crawler") and old_routes.route(START,GOAL,"crawler").is_empty(),"Replaced live owner cannot publish paths before queue_free")
	var old_level = level
	# An old scene still exists when replacement parses: source groups must not mix.
	level = replacement
	routes = Owner.new()
	level.add_child(routes)
	expect(routes.configure(level,{"crawler":profile}),"Replacement owns a fresh map")
	if await wait_ready("crawler"):
		var clean: PackedVector3Array = routes.route(START,GOAL,"crawler")
		expect(clean.size() >= 2 and path_length(clean) < 16.5,"Replacement excludes old door/base/roof geometry")
		old_level.queue_free()
		for frame in range(4): await physics_frame
		expect(not NavigationServer3D.get_maps().has(old_map),"Retired level releases its owned map RID")
		expect(mesh_ref.get_ref() == null and source_ref.get_ref() == null,"Retired level releases native geometry and mesh resources")
		var map: RID = routes._roles.crawler.map
		routes.teardown()
		routes.teardown()
		expect(routes.route(START,GOAL,"crawler").is_empty(),"Explicit teardown is idempotent and rejects queries")
		await physics_frame
		expect(not NavigationServer3D.get_maps().has(map),"Explicit teardown frees map RID")
	var queued = make_level()
	host.level = queued
	var queued_routes = Owner.new()
	queued.add_child(queued_routes)
	expect(queued_routes.configure(queued,{"crawler":profile}),"Queued-owner fixture config accepts crawler")
	queued.queue_free()
	expect(not queued_routes.is_ready("crawler") and queued_routes.route(START,GOAL,"crawler").is_empty(),"Queued owner cannot publish before its first parse/bake")
	await finish()

class Host extends Node:
	var level

func finish() -> void:
	host.free()
	if failures == 0: print("PASS level-owned native navigation geometry witness; no AI adoption or packed-app claim")
	quit(0 if failures == 0 else 1)
