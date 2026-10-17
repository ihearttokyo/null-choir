extends SceneTree

# Native fixture only; no Main startup, saves, gameplay capture or performance claim.
const Owner = preload("res://scripts/navigation_routes.gd")
const Level = preload("res://scripts/level.gd")
const Enemy = preload("res://scripts/enemy.gd")
const START := Vector3(4,.03,4)
const GOAL := Vector3(4,.03,20)
const WAIT_US := 2000000

class Host extends Node:
	var level

var failures := 0
var host: Node
var level
var routes
var actor: CharacterBody3D
var notices: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool, detail: String) -> void:
	print("NAV_ASYNC ",detail," result=",condition)
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

func pause_owner() -> void:
	routes.set_process(false)
	routes.set_physics_process(false)

func record_notice(role: String, generation: int, ready: bool) -> void:
	notices.append({"role":role,"revision":generation,"ready":ready})

func ready_roles(generation: int) -> Array[String]:
	var result: Array[String] = []
	for notice in notices:
		if notice.revision == generation and notice.ready: result.append(notice.role)
	return result

func wait_native(reference: WeakRef, detail: String) -> bool:
	var deadline := Time.get_ticks_usec()+WAIT_US
	while Time.get_ticks_usec() < deadline:
		var mesh: NavigationMesh = reference.get_ref()
		var busy := mesh != null and NavigationServer3D.is_baking_navigation_mesh(mesh)
		mesh = null
		if not busy: return true
		OS.delay_msec(2)
		await process_frame
		await physics_frame
	expect(false,detail+" completes within the native test bound")
	return false

func wait_ready(role: String) -> bool:
	var deadline := Time.get_ticks_usec()+WAIT_US
	while not routes.is_ready(role) and Time.get_ticks_usec() < deadline:
		OS.delay_msec(2)
		await process_frame
		await physics_frame
	var ready: bool = routes.is_ready(role)
	expect(ready,"Native witness eventually publishes "+role)
	return ready

func wait_released(references: Array[WeakRef], maps: Array[RID], detail: String) -> void:
	var deadline := Time.get_ticks_usec()+WAIT_US
	var released := false
	while Time.get_ticks_usec() < deadline:
		released = true
		for reference in references:
			if reference.get_ref() != null: released = false
		var live_maps := NavigationServer3D.get_maps()
		for map in maps:
			if live_maps.has(map): released = false
		if released: break
		OS.delay_msec(2)
		await process_frame
		await physics_frame
	expect(released,detail)

func check_witness(role: String) -> void:
	var entry: Dictionary = routes._roles[role]
	var version: int = NavigationServer3D.map_get_iteration_id(entry.map)
	expect(entry.ready and not entry.sync and version != entry.version and version > 0 and NavigationServer3D.map_get_regions(entry.map).has(entry.region) and NavigationServer3D.map_get_closest_point_owner(entry.map,entry.witness) == entry.region and NavigationServer3D.map_get_closest_point(entry.map,entry.witness).distance_to(entry.witness) < .01 and not NavigationServer3D.map_get_path(entry.map,entry.witness,entry.witness,true,1).is_empty(),"Ready "+role+" retains the complete native publication witness")

func path_length(path: PackedVector3Array) -> float:
	var total := 0.0
	for index in range(1,path.size()): total += path[index-1].distance_to(path[index])
	return total

func check_capsule(path: PackedVector3Array) -> void:
	expect(Engine.is_in_physics_frame(),"Clearance checks run in a native physics frame")
	var collider: CollisionShape3D = actor.get_child(0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.margin = actor.safe_margin
	query.collision_mask = 1
	query.exclude = [actor.get_rid()]
	for index in range(1,path.size()):
		query.transform = Transform3D(Basis.IDENTITY,path[index-1]+collider.position)
		query.motion = path[index]-path[index-1]
		expect(actor.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(),"Async route starts clear of retained static solids")
		var fraction := actor.get_world_3d().direct_space_state.cast_motion(query)
		expect(fraction.size() == 2 and fraction[0] >= .9999,"Async route admits the unchanged crawler capsule")

func run() -> void:
	expect(ProjectSettings.get_setting("navigation/baking/thread_model/baking_use_multiple_threads",false),"Actual engine navigation baking is configured for worker threads")
	host = Host.new()
	root.add_child(host)
	level = make_level()
	host.level = level
	level._box(Vector3(6.6,.55,6.6),Vector3(12,.275,12),null,true)
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
	routes.name = "NavigationRoutes"
	level.add_child(routes)
	routes.readiness_changed.connect(record_notice)
	var profiles := {
		"crawler":{"radius":capsule.radius,"height":capsule.height,"hover":0.0},
		"worker":{"radius":Enemy.capsule_radius("worker"),"height":Enemy.capsule_height("worker"),"hover":0.0}
	}
	var accepted: bool = routes.configure(level,profiles)
	expect(accepted,"Fixture accepts the actual crawler and worker profiles")
	if not accepted:
		await finish()
		return
	pause_owner()
	expect(not routes.is_ready("crawler") and routes.route(START,GOAL,"crawler").is_empty(),"Construction cannot expose a route")

	# No await between the real parse, launch and behavioral RED assertion.
	routes._process(0.0)
	expect(not routes._dirty and routes._pending == ["crawler","worker"],"Real main-thread parsing preserves role order")
	if not routes._roles.has("crawler"):
		await finish()
		return
	routes._process(0.0)
	var deferred: bool = routes._roles.crawler.mesh == null
	expect(deferred,"RED_ASYNC_DEFERRED_PUBLICATION: launch returns with crawler.mesh null")
	if not deferred:
		await finish()
		return

	expect(routes._baking.role == "crawler" and routes._baking.revision == routes.revision and routes._pending == ["worker"],"Launch owns exactly the first role and its revision")
	expect(not routes.is_ready("crawler") and routes.route(START,GOAL,"crawler").is_empty() and routes._queries == 0,"Unpublished work cannot expose or spend a route query")
	var discarded_revision: int = routes.revision
	var discarded_mesh: WeakRef = weakref(routes._baking.mesh)
	var discarded_source: WeakRef = weakref(routes._baking.source)

	# This remains meaningful even if the native worker has already finished:
	# its result is still outstanding until the owner polls it.
	level.open_door("fixture")
	routes.invalidate_doors()
	routes.invalidate_doors()
	expect(routes.revision == discarded_revision+1 and routes._dirty and routes._pending.is_empty(),"Real door invalidation retires the outstanding generation and coalesces")
	expect(routes.route(START,GOAL,"crawler").is_empty(),"Door invalidation immediately rejects stale routes")
	if NavigationServer3D.is_baking_navigation_mesh(routes._baking.mesh):
		routes._process(0.0)
		expect(routes._source == discarded_source.get_ref() and routes._pending.is_empty() and routes._roles.crawler.mesh == null,"An outstanding job cannot trigger another parse or role launch")
	if not await wait_native(discarded_mesh,"Superseded native bake"):
		await finish()
		return
	if not routes._baking.is_empty(): routes._process(0.0)
	expect(routes._baking.is_empty() and routes._dirty and routes._pending.is_empty() and routes._roles.crawler.mesh == null and routes._roles.worker.mesh == null,"Completed stale work is discarded without publication or replacement parsing")
	expect(ready_roles(discarded_revision).is_empty(),"A retired revision never emits ready")

	routes._process(0.0)
	expect(not routes._dirty and routes._pending == ["crawler","worker"] and routes._source != discarded_source.get_ref(),"Only after draining stale work does the new generation parse")
	routes._process(0.0)
	var current_revision: int = routes.revision
	var crawler_mesh: WeakRef = weakref(routes._baking.mesh)
	var current_source: WeakRef = weakref(routes._baking.source)
	# Whether still busy or just completed, this poll must not launch worker.
	routes._process(0.0)
	expect(routes._pending == ["worker"] and routes._roles.worker.mesh == null and routes._source == current_source.get_ref(),"Polling the first job cannot consume the next role or replace its source")
	if not await wait_native(crawler_mesh,"Current crawler bake"):
		await finish()
		return
	if not routes._baking.is_empty(): routes._process(0.0)
	expect(routes._baking.is_empty() and routes._roles.crawler.mesh == crawler_mesh.get_ref() and routes._roles.crawler.sync and not routes.is_ready("crawler"),"Completed mesh publication still waits for the native map witness")
	expect(ready_roles(current_revision).is_empty() and routes.route(START,GOAL,"crawler").is_empty(),"Mesh assignment alone cannot emit ready or expose queries")

	routes.set_physics_process(true)
	if not await wait_ready("crawler"):
		await finish()
		return
	check_witness("crawler")
	expect(routes._roles.worker.mesh == null and routes._pending == ["worker"],"Later roles remain unstarted while only physics synchronization runs")
	routes._process(0.0)
	expect(routes._baking.role == "worker" and routes._pending.is_empty() and routes._baking.source == current_source.get_ref(),"The next role reuses the exact parsed source")
	var worker_mesh: WeakRef = weakref(routes._baking.mesh)
	if not await wait_native(worker_mesh,"Current worker bake"):
		await finish()
		return
	routes._process(0.0)
	if not await wait_ready("worker"):
		await finish()
		return
	check_witness("worker")
	expect(ready_roles(current_revision) == ["crawler","worker"],"Controlled role publication preserves notification order")
	expect(not NavigationServer3D.region_get_use_async_iterations(routes._roles.crawler.region) and NavigationServer3D.map_get_use_async_iterations(routes._roles.crawler.map),"Region publication and asynchronous map iteration settings remain unchanged")

	await physics_frame
	var opened: PackedVector3Array = routes.route(START,GOAL,"crawler")
	expect(opened.size() >= 2 and path_length(opened) < 16.5,"Fresh opened-door geometry replaces the discarded closed-door detour")
	check_capsule(opened)
	expect(routes.route(Vector3(NAN,0,0),GOAL,"crawler").is_empty() and routes.route(START,GOAL,"missing").is_empty() and routes.route(START,GOAL,"crawler",NAN).is_empty(),"Invalid endpoints, roles and tolerance remain fail-closed")
	await physics_frame
	for index in range(Owner.MAX_QUERIES_PER_TICK):
		expect(not routes.route(START,GOAL,"crawler").is_empty(),"An allowed native query remains available")
	expect(routes.route(START,GOAL,"crawler").is_empty(),"Async publication does not bypass the per-tick query cap")
	await physics_frame
	expect(not routes.route(START,GOAL,"crawler").is_empty(),"The next physics tick restores the query budget")
	await wait_released([discarded_mesh,discarded_source],[],"Superseded job releases its mesh and parsed source")

	var retired_resources: Array[WeakRef] = [
		weakref(routes._roles.crawler.mesh),
		weakref(routes._roles.worker.mesh),
		weakref(routes._source)
	]
	var retired_maps: Array[RID] = [routes._roles.crawler.map,routes._roles.worker.map]
	pause_owner()
	routes.invalidate_doors()
	routes._process(0.0)
	routes._process(0.0)
	var retired_revision: int = routes.revision
	retired_resources.append(weakref(routes._baking.mesh))
	retired_resources.append(weakref(routes._baking.source))
	expect(NavigationServer3D.is_baking_navigation_mesh(routes._baking.mesh),"Native worker is busy immediately before teardown and reconfigure")
	routes.teardown()
	routes.teardown()
	expect(routes._baking.is_empty() and routes._roles.is_empty() and routes._source == null and not routes.is_processing() and not routes.is_physics_processing(),"Repeated teardown drops local outstanding work and disables processing")
	expect(routes.route(START,GOAL,"crawler").is_empty(),"Teardown rejects all queries")

	expect(routes.configure(level,{"worker":profiles.worker}),"Immediate reconfigure accepts a fresh generation")
	pause_owner()
	routes._process(0.0)
	routes._process(0.0)
	expect(routes._baking.role == "worker" and routes._roles.worker.mesh == null,"Reconfigure launches a fresh resource rather than publishing retired work")
	routes.set_process(true)
	routes.set_physics_process(true)
	if not await wait_ready("worker"):
		await finish()
		return
	check_witness("worker")
	expect(ready_roles(retired_revision).is_empty(),"Retired teardown work cannot notify the replacement generation")
	await wait_released(retired_resources,retired_maps,"Teardown/reconfigure releases retired published resources, outstanding resources and map RIDs")

	pause_owner()
	routes.invalidate_doors()
	routes._process(0.0)
	routes._process(0.0)
	var queued_revision: int = routes.revision
	var queued_resources: Array[WeakRef] = [
		weakref(routes),
		weakref(routes._roles.worker.mesh),
		weakref(routes._baking.mesh),
		weakref(routes._baking.source)
	]
	var queued_maps: Array[RID] = [routes._roles.worker.map]
	expect(NavigationServer3D.is_baking_navigation_mesh(routes._baking.mesh),"Native worker is busy immediately before owner queue_free")
	routes.queue_free()
	expect(not routes.is_ready("worker") and routes.route(START,GOAL,"worker").is_empty(),"Queued owner rejects queries before outstanding work is reclaimed")
	routes = null
	await wait_released(queued_resources,queued_maps,"Freeing an owner with outstanding work releases the Node, resources and map RID")
	expect(ready_roles(queued_revision).is_empty(),"Freed outstanding work never emits ready")

	notices.clear()
	routes = Owner.new()
	routes.name = "NavigationRoutes"
	level.add_child(routes)
	routes.readiness_changed.connect(record_notice)
	expect(routes.configure(level,{"crawler":profiles.crawler}),"Stale-owner fixture configures")
	pause_owner()
	routes._process(0.0)
	routes._process(0.0)
	var abandoned_revision: int = routes.revision
	var abandoned_resources: Array[WeakRef] = [weakref(routes._baking.mesh),weakref(routes._baking.source)]
	var abandoned_maps: Array[RID] = [routes._roles.crawler.map]
	var old_level = level
	var replacement = make_level()
	expect(NavigationServer3D.is_baking_navigation_mesh(routes._baking.mesh),"Native worker is busy immediately before authoritative level replacement")
	host.level = replacement
	expect(not routes.is_ready("crawler") and routes.route(START,GOAL,"crawler").is_empty(),"Replacing the authoritative level immediately rejects outstanding old-owner routes")
	routes._process(0.0)
	expect(routes._baking.is_empty() and routes._roles.is_empty() and routes._source == null,"A stale owner tears down before polling or publishing native results")
	expect(ready_roles(abandoned_revision).is_empty(),"A stale owner cannot emit ready")
	old_level.queue_free()

	level = replacement
	routes = Owner.new()
	routes.name = "NavigationRoutes"
	level.add_child(routes)
	expect(routes.configure(level,{"crawler":profiles.crawler}),"Replacement level owns a fresh navigation generation")
	if not await wait_ready("crawler"):
		await finish()
		return
	check_witness("crawler")
	await physics_frame
	var clean: PackedVector3Array = routes.route(START,GOAL,"crawler")
	expect(clean.size() >= 2 and path_length(clean) < 16.5,"Replacement geometry excludes the still-retiring old level")
	await wait_released(abandoned_resources,abandoned_maps,"Stale-owner teardown releases outstanding resources and map RID")

	var final_resources: Array[WeakRef] = [weakref(routes._roles.crawler.mesh),weakref(routes._source)]
	var final_maps: Array[RID] = [routes._roles.crawler.map]
	routes.teardown()
	await wait_released(final_resources,final_maps,"Final teardown releases published geometry and map RID")
	await finish()

func finish() -> void:
	host.free()
	print("PASS native async navigation lifecycle; no app or performance claim" if failures == 0 else "FAIL native async navigation lifecycle: "+str(failures))
	quit(0 if failures == 0 else 1)
