extends Node3D

const Layout = preload("res://scripts/level_data.gd")
var layout = Layout.new()
var game: Node
var doors: Dictionary = {}
var markers: Dictionary = {}

func build(owner_game: Node, index: int) -> void:
	game = owner_game
	if not layout.load_level(index):
		push_error("Level source unavailable: " + str(index))
		return
	_build_geometry()
	_build_environment()
	for hero in layout.data.heroes:
		var path = "res://assets/art/world/" + hero.id + ".glb"
		if ResourceLoader.exists(path):
			var model = load(path).instantiate()
			add_child(model)
			model.position = layout.world_position(hero.cell)
			model.rotation.y = deg_to_rad(hero.yaw)
	for spec in layout.data.doors:
		if spec.id in game.state.removed:
			continue
		var door = _box(Vector3(spec.size[0],spec.size[1],spec.size[2]), layout.world_position(spec.cell) + Vector3(0,spec.size[1]/2,0), _material(Color(0.14,0.08,0.09)), true)
		door.rotation.y = deg_to_rad(spec.yaw)
		doors[spec.id] = door
	for spec in layout.data.pickups + layout.data.interactions:
		if spec.id in game.state.removed:
			continue
		var color = Color(0.85,0.59,0.22)
		if spec.kind == "health": color = Color(0.4,0.7,0.65)
		if spec.kind == "armor": color = Color(0.34,0.5,0.86)
		if spec.kind == "key" and spec.key == "blood": color = Color(0.7,0.12,0.11)
		var marker = _box(Vector3(0.55,0.7,0.55), layout.world_position(spec.cell) + Vector3(0,0.65,0), _material(color, 0.7), false)
		markers[spec.id] = marker

func _material(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.83
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if emission > 0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material

func _box(size: Vector3, location: Vector3, material: Material, solid: bool) -> Node3D:
	var root = StaticBody3D.new() if solid else Node3D.new()
	add_child(root)
	root.position = location
	var mesh = MeshInstance3D.new()
	var shape = BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material
	root.add_child(mesh)
	if solid:
		root.collision_layer = 1
		var collider = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = size
		collider.shape = box
		root.add_child(collider)
	return root

func _build_geometry() -> void:
	var floor_material = _material(Color(0.22,0.2,0.19))
	var wall_material = _material(Color(0.32,0.22,0.23))
	for entry in [[floor_material,"floor"],[wall_material,"wall"]]:
		var texture_path = "res://assets/art/textures/" + entry[1] + ".png"
		if ResourceLoader.exists(texture_path): entry[0].albedo_texture = load(texture_path)
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var size = float(layout.data.cell_size)
	for cell in layout.tiles:
		var corners: Array[Vector3] = []
		for offset in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]:
			var point = Vector2(cell) + offset
			corners.append(Vector3(point.x*size,layout.height_at(point),point.y*size))
		for i in [0,2,1,0,3,2]:
			surface.set_normal(Vector3.UP)
			surface.set_uv(Vector2(corners[i].x/size,corners[i].z/size))
			surface.add_vertex(corners[i])
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if not layout.is_walkable(cell + direction):
				var point = Vector2(cell) + Vector2(0.5,0.5) + Vector2(direction)*0.5
				var h = layout.height_at(point)
				var tall = 10.0 if cell.x < 10 and cell.y < 19 and cell.y > 11 else 6.0
				var dimensions = Vector3(0.28,tall,size+0.28) if direction.x else Vector3(size+0.28,tall,0.28)
				_box(dimensions, Vector3(point.x*size,h+tall/2,point.y*size),wall_material,true)
	var floor_mesh = MeshInstance3D.new()
	floor_mesh.mesh = surface.commit()
	floor_mesh.material_override = floor_material
	add_child(floor_mesh)
	floor_mesh.create_trimesh_collision()
	var shape = floor_mesh.get_child(0).get_child(0).shape as ConcavePolygonShape3D
	shape.backface_collision = true
	# Repeated structure is supporting kit; the loop hero pieces remain bespoke.
	var arch_path = "res://assets/art/world/arch.glb"
	if ResourceLoader.exists(arch_path):
		for cell in [[14,25],[14,19],[5.5,19],[23,19]]:
			var arch = load(arch_path).instantiate()
			add_child(arch)
			arch.position = layout.world_position(cell)

func _build_environment() -> void:
	var world = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.008,0.006,0.01)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.42,0.35,0.4)
	environment.ambient_light_energy = 0.52
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.environment = environment
	add_child(world)
	for cell in [[14,28],[14,23],[6,23],[6,16],[6,8],[14,13],[23,23],[23,14],[23,8],[14,2]]:
		var light = OmniLight3D.new()
		light.position = layout.world_position(cell) + Vector3(0,3.5,0)
		light.light_color = Color(1.0,0.57,0.29) if cell[0] < 20 else Color(0.56,0.77,0.7)
		light.omni_range = 19
		light.light_energy = 2.0
		add_child(light)
		_box(Vector3(0.65,0.1,0.65),light.position,_material(light.light_color,2.0),false)

func remove_marker(id: String) -> void:
	if markers.has(id):
		markers[id].queue_free()
		markers.erase(id)

func open_door(id: String) -> void:
	if not doors.has(id): return
	var door = doors[id]
	door.collision_layer = 0
	var tween = create_tween()
	tween.tween_property(door,"position:y",door.position.y+6.0,0.65)
	doors.erase(id)
