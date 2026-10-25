extends SceneTree
const Layout = preload("res://scripts/level_data.gd")
const Landmarks = preload("res://scripts/level_landmarks.gd")

func _initialize() -> void:
	var seen: Dictionary = {}
	for index in range(Layout.FILES.size()):
		var layout = Layout.new()
		assert(layout.load_level(index),layout.load_error)
		var before = JSON.stringify(layout.data)
		var frames = Landmarks.plan(layout)
		assert(frames.size() >= 4,"Architecture must frame both authored loops: "+str(index))
		assert(frames.size() <= Landmarks.MAX_FRAMES)
		var signature = str(Landmarks.PROFILES[layout.data.id])
		assert(not seen.has(signature),"Depth profiles must differ")
		seen[signature] = true
		for frame in frames:
			assert(frame.width >= 3.0 and frame.width <= 28.0)
			assert(frame.center.y-Landmarks.THICKNESS*0.5 >= frame.floor_top+Landmarks.CLEARANCE)
			assert(frame.center.y+frame.rise+Landmarks.THICKNESS*0.5 < frame.roof_bottom)
		var level = Node3D.new()
		root.add_child(level)
		Landmarks.build(level,layout)
		assert(level.get_child_count() == 1,"Exactly one draw surface owner per map")
		var mesh = level.get_child(0) as MeshInstance3D
		assert(mesh != null and mesh.mesh.get_surface_count() == 1)
		assert(mesh.get_child_count() == 0,"No gameplay collider or light may be introduced")
		assert(mesh.mesh.surface_get_array_len(0) <= Landmarks.MAX_FRAMES*7*36)
		assert(JSON.stringify(layout.data) == before,"Runtime planning must not mutate authored map")
		level.free()
	print("PASS: all eight map-driven architecture plans and native static mesh budgets")
	quit()
