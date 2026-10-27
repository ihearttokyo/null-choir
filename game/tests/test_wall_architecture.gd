extends SceneTree
## PREPARED ONLY until a separately granted native run. No input/audio/render claims.
const Walls = preload("res://scripts/wall_architecture.gd")
const Level = preload("res://scripts/level.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not check_face_orientation(): return
	var sloped_samples: int = 0
	for index in range(8):
		var level = Level.new()
		root.add_child(level)
		if not check(level.layout.load_level(index),"load chapter"): return
		level._build_geometry()
		for wall: Node in level.get_children():
			if not str(wall.name).begins_with("WallArchitecture_"): continue
			for mesh: Node in wall.get_children():
				if mesh is MeshInstance3D and mesh.material_override is BaseMaterial3D:
					if not check(mesh.material_override.cull_mode==BaseMaterial3D.CULL_BACK,"default backface culling retained"): return
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

# Actual production SurfaceTool arrays, independent clockwise-front test.
func outward_triangle(a: Vector3, b: Vector3, c: Vector3, normal: Vector3, center: Vector3) -> bool:
	var front: Vector3 = (c-a).cross(b-a).normalized()
	var away: Vector3 = (a+b+c)/3.0-center
	return front.dot(away)>0.00001 and normal.dot(away)>0.00001 and normal.dot(front)>0.9999

func check_face_orientation() -> bool:
	var checked: int = 0
	for chapter: String in Walls.FAMILIES:
		for variant: int in [0,1]:
			for direction: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				for part: Array in Walls.profile(chapter,4.0,6.0,variant):
					var points: PackedVector3Array = Walls._vertices(part,Vector3.ZERO,Vector3(-direction.y,0,direction.x),Vector3(direction.x,0,direction.y))
					var center: Vector3 = Vector3.ZERO
					for point: Vector3 in points: center += point/8.0
					var tool := SurfaceTool.new(); tool.begin(Mesh.PRIMITIVE_TRIANGLES)
					var collision: PackedVector3Array = Walls._append(tool,points,PackedVector3Array())
					var arrays: Array = tool.commit_to_arrays()
					var draw: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
					if not check(draw==collision and draw.size()==36 and normals.size()==36,"actual rendered/collider triangles and normals"): return false
					for i: int in range(0,draw.size(),3):
						var a: Vector3 = draw[i]; var b: Vector3 = draw[i+1]; var c: Vector3 = draw[i+2]
						for normal: Vector3 in [normals[i],normals[i+1],normals[i+2]]:
							if not check(outward_triangle(a,b,c,normal,center),"outward clockwise front and explicit normal"): return false
						if not check(not outward_triangle(a,c,b,normals[i],center),"inverted winding negative control"): return false
						if not check(not outward_triangle(a,b,c,-normals[i],center),"inverted normal negative control"): return false
						if not check(not outward_triangle(a,c,b,-normals[i],center),"original inside-out pair negative control"): return false
						checked += 1
	print("WALL_OUTWARD_FACE_RESULT triangles=",checked," orientations=4 families=8 default_backface_cull=true")
	return check(checked>0,"actual orientation coverage")
