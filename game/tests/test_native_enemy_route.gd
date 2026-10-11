extends SceneTree

# Synthetic flat Intake arena; real crawler capsule, AI, native collisions and door opening.
# No navigation repair, combat retuning, active-body repositioning or prop collision removal.
class NativeGame extends "res://scripts/main.gd":
	func _ready() -> void: set_process(false)

class Driver extends Node:
	var actor
	var base
	var remaining := 0
	var steps := 0
	var blocked := 0
	var eligible := 0
	var visible := 0
	var attack_holds := 0
	var grounded := 0
	var hover_supported := 0
	var reached := false
	var tail_travel := 0.0
	var initial_range := 0.0
	var far_edge := 0.0
	func _physics_process(delta: float) -> void:
		if remaining <= 0: return
		var destination: Vector3 = actor.game.player.global_position
		var sight := PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP,destination+Vector3.UP,1)
		var clear: bool = actor.get_world_3d().direct_space_state.intersect_ray(sight).is_empty()
		if clear: visible += 1
		if Engine.is_in_physics_frame() and actor._current_map() and actor.active and actor.alerted and actor.hp > 0 and actor._valid_target(actor.target): eligible += 1
		var before: Vector3 = actor.global_position
		actor._physics_process(delta)
		if actor.is_on_floor(): grounded += 1
		if actor.kind in ["caster","choir_avatar"]:
			var floor_ray := PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*.5,actor.global_position-Vector3.UP*6,1)
			var floor_hit: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(floor_ray)
			if not floor_hit.is_empty() and actor.global_position.y-floor_hit.position.y > .5 and actor.global_position.y-floor_hit.position.y < 1.5: hover_supported += 1
		var normals: Array = []
		var base_contact := false
		for index in actor.get_slide_collision_count():
			var contact: KinematicCollision3D = actor.get_slide_collision(index)
			normals.append({"body":str(contact.get_collider().name),"normal":str(contact.get_normal())})
			if contact.get_collider() == base and absf(contact.get_normal().y) < .25: base_contact = true
		if base_contact: blocked += 1
		if steps >= 180: tail_travel += actor.global_position.distance_to(before)
		var distance: float = actor.global_position.distance_to(destination)
		reached = actor.global_position.z > far_edge and distance < initial_range-4.0
		if not reached and (actor.telegraph_time > 0 or actor.recovery_time > 0 or actor.stagger_time > 0 or actor._rush_time > 0): attack_holds += 1
		if steps%10 == 0 or reached:
			print("ROUTE_TRACE tick=",steps," position=",actor.global_position," target=",destination," waypoint=",actor.waypoint," current_source_intent=",actor.waypoint if actor._routing else destination," los_clear=",clear," range=",distance," displacement=",actor.global_position-before," contacts=",normals)
		steps += 1
		remaining = 0 if reached else remaining-1

var game
var failures := 0
var role := "crawler"

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func expect(condition: bool, detail: String) -> void:
	if condition: return
	failures += 1
	push_error(detail)

func sweep(actor, start: Vector3, end: Vector3) -> PackedFloat32Array:
	var collider: CollisionShape3D = actor.get_child(0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.transform = Transform3D(Basis.IDENTITY,start+collider.position)
	query.motion = end-start
	query.margin = actor.safe_margin
	query.collision_mask = 1|2|4
	query.exclude = [actor.get_rid(),game.player.get_rid()]
	expect(game.level.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(),"SETUP swept capsule begins without overlap")
	return game.level.get_world_3d().direct_space_state.cast_motion(query)

func run() -> void:
	preload("res://scripts/preferences.gd").new().apply_bindings()
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): role = args[0]
	expect(Engine.physics_ticks_per_second == 60,"SETUP native sixty-Hz physics required")
	game = NativeGame.new()
	root.add_child(game)
	game.state.new_campaign(1)
	game.level = game.Level.new()
	game.add_child(game.level)
	expect(game.level.layout.load_level(0),"SETUP actual Intake layout loads")
	if role == "choir_avatar":
		# This controlled flat arena must fit the real 5.6m capsule plus 1.16m hover.
		game.level.layout.data.ceilings = [{"rect":[0,0,100,100],"height":8.0}]
	# This rectangle is flat and authored walkable; only geometry is controlled staging.
	game.level._box(Vector3(32,.2,80),Vector3(58,-.1,100),null,true)
	var base = game.level._box(Vector3(6.6,.55,6.6),Vector3(58,.275,88),null,true)
	base.name = "RouteLowHeroBase"
	var spec: Dictionary = game.level.layout.data.doors[0]
	var door = game.level._box(Vector3(spec.size[0],spec.size[1],spec.size[2]),Vector3(64,float(spec.size[1])/2,88),null,true)
	door.name = "RouteAuthoredDoor"
	game.level.doors[spec.id] = door
	game.player = game.Player.new()
	game.level.add_child(game.player)
	game.player.configure(game)
	game.player.set_physics_process(false)
	game.player.position = Vector3(58,.04,94 if role == "crawler" else 120)
	var actor = game.Enemy.new()
	game.level.add_child(actor)
	actor.configure(game,{"id":"route_"+role,"kind":role,"cell":[14.5,20.5],"yaw":0})
	actor.set_physics_process(false)
	actor.alerted = true
	if role != "crawler": actor.attack_time = 1000 # Isolate real pursuit from deliberately held firing.
	actor.target = game.player
	game.enemies = [actor]
	game.playing = true
	await physics_frame
	await physics_frame
	var shape: CapsuleShape3D = actor.get_child(0).shape
	expect(is_equal_approx(shape.radius,game.Enemy.capsule_radius(role)) and is_equal_approx(shape.height,game.Enemy.capsule_height(role)) and actor.collision_mask == (1|2|4),"SETUP unchanged production crawler collision")
	var route: Array[Vector3] = [Vector3(58,.04,82),Vector3(64,.04,82),Vector3(64,.04,94),Vector3(58,.04,94)]
	var closed: PackedFloat32Array = sweep(actor,route[1],route[2])
	expect(closed.size() == 2 and closed[0] < .99,"SETUP closed native door blocks alternative capsule segment")
	var door_ray := PhysicsRayQueryParameters3D.create(route[1]+Vector3.UP,route[2]+Vector3.UP,1)
	expect(game.level.get_world_3d().direct_space_state.intersect_ray(door_ray).get("collider") == door,"SETUP closed-route obstruction is the actual door")
	game.level.open_door(spec.id) # Normal production opening; the low base stays solid.
	await physics_frame
	await physics_frame
	for index in range(route.size()-1):
		var start: Vector3 = route[index]
		var end: Vector3 = route[index+1]
		for sample in range(int(ceil(start.distance_to(end)))+1):
			var point: Vector3 = start.lerp(end,float(sample)/ceil(start.distance_to(end)))
			var cell := Vector2(point.x,point.z)/float(game.level.layout.data.cell_size)
			expect(game.level.layout.is_walkable(Vector2i(cell.floor())) and absf(game.level.layout.world_position([cell.x,cell.y]).y) < .001,"SETUP alternate route stays on actual authored flat walkability")
		var floor_query := PhysicsRayQueryParameters3D.create(start+Vector3.UP,start-Vector3.UP,1)
		var support: Dictionary = game.level.get_world_3d().direct_space_state.intersect_ray(floor_query)
		expect(not support.is_empty() and absf(support.position.y) < .001 and support.normal.y > .99,"SETUP alternate anchor has actual floor support")
		var clear: PackedFloat32Array = sweep(actor,start,end)
		expect(clear.size() == 2 and clear[0] >= .9999,"SETUP alternate route admits the actual capsule after native door opening")
	var direct: PackedFloat32Array = sweep(actor,route[0],Vector3(58,.04,92))
	expect(direct.size() == 2 and direct[0] < .99,"SETUP direct capsule route is physically blocked by retained low base")
	var foot_ray := PhysicsRayQueryParameters3D.create(Vector3(58,.3,82),Vector3(58,.3,92),1)
	expect(game.level.get_world_3d().direct_space_state.intersect_ray(foot_ray).get("collider") == base,"SETUP low obstruction really is the retained hero base")
	var sight := PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP,game.player.global_position+Vector3.UP,1)
	expect(game.level.get_world_3d().direct_space_state.intersect_ray(sight).is_empty(),"SETUP world y1 LOS is clear independently of foot-level blockage")
	var navigation = preload("res://scripts/navigation_routes.gd").new()
	navigation.name = "NavigationRoutes"
	game.level.add_child(navigation)
	game.level.game = game
	expect(navigation.configure(game.level,{role:{"radius":shape.radius,"height":shape.height,"hover":1.16 if role in ["caster","choir_avatar"] else 0.0}}),"Native route owner config accepts real AI role")
	var deadline := Time.get_ticks_usec()+3000000
	while not navigation.is_ready(role) and Time.get_ticks_usec()<deadline:
		OS.delay_msec(2)
		await process_frame
		await physics_frame
	expect(navigation.is_ready(role),"Actual AI waits for native role path publication")
	print("ROUTE_SETUP role=",role," radius=",shape.radius," height=",shape.height," authored_search_waypoint=",actor._next_step(game.player.global_position)," alternative=",route)
	if failures > 0:
		await finish(1)
		return
	var driver := Driver.new()
	driver.actor = actor
	driver.base = base
	driver.initial_range = actor.global_position.distance_to(game.player.global_position)
	driver.far_edge = 88+3.3+shape.radius
	driver.remaining = 240 if role == "crawler" else 600
	root.add_child(driver)
	while driver.remaining > 0: await physics_frame
	expect(is_instance_valid(base) and base.collision_layer == 1 and actor.collision_mask == (1|2|4) and is_equal_approx(shape.radius,game.Enemy.capsule_radius(role)) and is_equal_approx(shape.height,game.Enemy.capsule_height(role)),"PARITY retained low base and capsule collision were not removed/enlarged")
	expect(actor.hp == actor.max_hp and game.state.health == 100 and game.enemies.size() == 1,"PARITY no combat, mortality or crowd confound")
	print("ROUTE_RESULT reached=",driver.reached," steps=",driver.steps," blocked=",driver.blocked," eligible=",driver.eligible," visible=",driver.visible," attack_holds=",driver.attack_holds," grounded=",driver.grounded," tail_travel=",driver.tail_travel," final=",actor.global_position)
	var status := 0
	if failures > 0: status = 1
	elif not driver.reached:
		if driver.blocked >= 120 and driver.eligible == driver.steps and driver.visible == driver.steps and driver.attack_holds == 0 and driver.grounded >= driver.steps-3 and driver.tail_travel < .06:
			push_error("NC05 RED: live eligible crawler repeatedly collides with low base despite independently reachable capsule-clear alternate route and clear sight")
			status = 1
		else:
			push_error("NC05 INCONCLUSIVE: progress failed without all collision/eligibility/LOS/attack-free stall witnesses")
			status = 2
	else:
		var supported: bool = driver.hover_supported >= driver.steps-3 if role in ["caster","choir_avatar"] else driver.grounded >= driver.steps-3
		expect(driver.eligible == driver.steps and driver.visible == driver.steps and driver.attack_holds == 0 and supported,"GREEN route retains eligibility/clear sight/attack-free grounded or actual hover-support progress")
		status = 1 if failures > 0 else 0
		if status == 0: print("PASS native "+role+" route progress around retained low base; synthetic arena, not campaign/navigation/GPU acceptance")
	driver.free()
	await finish(status)

func finish(status: int) -> void:
	game.playing = false
	game.free()
	await process_frame
	quit(status)
