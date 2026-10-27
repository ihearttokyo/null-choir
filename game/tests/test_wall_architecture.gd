extends SceneTree
## PREPARED ONLY until a separately granted native run. No input/audio/render claims.
const Walls = preload("res://scripts/wall_architecture.gd")
const Level = preload("res://scripts/level.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sloped_samples: int = 0
	for index in range(8):
		var level = Level.new()
		root.add_child(level)
		if not check(level.layout.load_level(index),"load chapter"): return
		level._build_geometry()
		await physics_frame
		await physics_frame
		var shape := CapsuleShape3D.new()
		shape.radius = 0.32
		shape.height = 1.65
		var chosen: Dictionary = {}
		var sloped: Dictionary = {}
		for cell in level.layout.tiles:
			for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				if level.layout.is_walkable(cell+direction): continue
				var point := Vector2(cell)+Vector2(0.5,0.5)+Vector2(direction)*0.5
				var tangent := Vector2(-direction.y,direction.x)*0.5
				var a: float = level.layout.height_at(point-tangent)
				var b: float = level.layout.height_at(point+tangent)
				if absf(a-b) > 0.01 and sloped.is_empty():
					sloped = {"point":Vector3(point.x*4.0,minf(a,b),point.y*4.0),"outward":Vector3(direction.x,0,direction.y),"tangent":Vector3(-direction.y,0,direction.x)}
				if absf(a-b) < 0.001 and chosen.is_empty():
					chosen = {"point":Vector3(point.x*4.0,a,point.y*4.0),"outward":Vector3(direction.x,0,direction.y),"tangent":Vector3(-direction.y,0,direction.x)}
		if not check(not chosen.is_empty(),"flat boundary fixture"): return
		var space = level.get_world_3d().direct_space_state
		var origin: Vector3 = chosen.point
		var outward: Vector3 = chosen.outward
		var along: Vector3 = chosen.tangent
		# Old valid standing capsule has more clearance, not less: no save migration.
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.collision_mask = 1
		query.transform = Transform3D(Basis.IDENTITY,origin+along*0.5-outward*0.48+Vector3.UP*0.95)
		if not check(space.intersect_shape(query).is_empty(),"legacy near-wall standing pose"): return
		# Every height through an upper-deck fall is physically barred by visible ribs.
		var ceiling: float = Walls._highest_support(level.layout)+1.8
		for y in [origin.y+1.0,origin.y+2.5,ceiling]:
			query.transform.origin = Vector3(origin.x,y,origin.z)+along*0.5
			if not check(not space.intersect_shape(query).is_empty(),"capsule-sized exterior aperture"): return
		var actor := CharacterBody3D.new()
		actor.collision_layer = 2
		actor.collision_mask = 1
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position.y = 0.85
		actor.add_child(collision)
		root.add_child(actor)
		actor.position = Vector3(origin.x,Walls._highest_support(level.layout)+0.25,origin.z)+along*0.5-outward*0.65
		await physics_frame
		for _step in range(8):
			actor.move_and_collide(outward*0.24-Vector3.UP*0.35)
			if not check((actor.position-origin).dot(outward) < 0.0,"high-to-low fall cannot enter unsupported niche"): return
		actor.free()
		if not sloped.is_empty():
			var old_pose: Vector3 = sloped.point+sloped.tangent*0.5-sloped.outward*0.48
			old_pose.y = level.layout.capsule_floor_support(Vector2(old_pose.x,old_pose.z),0.32)+0.95
			query.transform.origin = old_pose
			if not check(space.intersect_shape(query).is_empty(),"sloped legacy supported save pose"): return
			# Capsule bottom is above every authored support; only walls can satisfy this query.
			query.transform.origin = Vector3(sloped.point.x,Walls._highest_support(level.layout)+1.0,sloped.point.z)+sloped.tangent*0.5
			if not check(not space.intersect_shape(query).is_empty(),"sloped edge still bars unsupported bay entry"): return
			sloped_samples += 1
		if index == 0:
			# A thin ray CAN see deep into the recess; no hidden old front plane/occluder.
			var from: Vector3 = origin+along*0.5-outward+Vector3.UP*1.55
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from,from+outward*3.0,1))
			if not check(not hit.is_empty() and (hit.position-origin).dot(outward)>0.80,"actual deep visible/colliding Intake recess"): return
		level.free()
		await physics_frame
	if not check(sloped_samples > 0,"actual authored sloped boundary coverage"): return
	print("PASS eight physical wall families, deep recess, old standing capsule, upper-deck fall containment")
	quit()

func check(ok: bool, reason: String) -> bool:
	if not ok:
		push_error("Wall architecture: "+reason)
		quit(1)
	return ok
