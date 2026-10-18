extends SceneTree

# Native mesh storage quantizes normals; allow the measured decode tolerance.
const NORMAL_EPS := .0001

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var snapshots: Dictionary = {}
	var valid := true
	var sloped := 0
	for index in range(8):
		var level = preload("res://scripts/level.gd").new()
		root.add_child(level)
		if not level.layout.load_level(index):
			push_error("Missing authored map "+str(index))
			level.free()
			quit(1)
			return
		level._build_geometry()
		var meshes: Dictionary = {}
		var bad := 0
		for node in level.get_children():
			if not node is MeshInstance3D or not node.mesh is ArrayMesh: continue
			var arrays: Array = node.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var collision := PackedVector3Array()
			if node.name.begins_with("Floor"): collision = node.get_child(0).get_child(0).shape.get_faces()
			meshes[str(node.name)] = var_to_bytes([vertices,arrays[Mesh.ARRAY_TEX_UV],arrays[Mesh.ARRAY_INDEX],collision,node.mesh.get_aabb()]).hex_encode().sha256_text()
			for i in range(0,vertices.size(),3):
				var a := vertices[i+1]-vertices[i]
				var b := vertices[i+2]-vertices[i]
				if absf(a.y)+absf(b.y) > .0001: sloped += 1
				for vertex in range(i,i+3):
					var normal := normals[vertex]
					if not normal.is_finite() or absf(normal.length()-1) > NORMAL_EPS or absf(normal.dot(a.normalized())) > NORMAL_EPS or absf(normal.dot(b.normalized())) > NORMAL_EPS or a.cross(b).dot(normal) >= 0:
						bad += 1
			snapshots[str(index)] = meshes
		if bad > 0:
			valid = false
			push_error("Authored surface normals must be unit/perpendicular/front-facing: level="+str(index)+" bad_vertices="+str(bad))
		level.free()
		await physics_frame
	if sloped == 0:
		valid = false
		push_error("Fixture must exercise actual authored ramps")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			var file := FileAccess.open(arg.trim_prefix("--capture="),FileAccess.WRITE)
			if file == null:
				push_error("Cannot retain geometry witness")
				quit(1)
				return
			file.store_string(JSON.stringify(snapshots))
			file.flush()
			var capture_error := file.get_error()
			file.close()
			if capture_error != OK:
				push_error("Geometry witness write failed: "+error_string(capture_error))
				quit(1)
				return
	await process_frame
	if valid: print("PASS actual eight-map surface normals: finite/unit/perpendicular/clockwise and ",sloped," authored sloped triangles; non-normal/collision fingerprints computed")
	quit(0 if valid else 1)
