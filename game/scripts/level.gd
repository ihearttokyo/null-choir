extends Node3D

const Layout = preload("res://scripts/level_data.gd")
const Routes = preload("res://scripts/navigation_routes.gd")
const PURPOSE_ART = {
	"ammo":"marker_ammo", "health":"marker_health", "armor":"marker_armor",
	"key":"marker_key", "weapon":"marker_weapon", "story":"marker_story",
	"checkpoint":"marker_checkpoint", "exit":"marker_exit"
}
var layout = Layout.new()
var game: Node
var doors: Dictionary = {}
var markers: Dictionary = {}
var machine_lights: Dictionary = {}
# Instances retain meshes, not their PackedScene; keep one owner per art ID.
var _model_scenes: Dictionary = {}

func build(owner_game: Node, index: int) -> bool:
	if not layout.load_level(index):
		return false
	game = owner_game
	_build_geometry()
	_build_environment()
	_build_scenery()
	for hero in layout.data.heroes:
		_place_model(hero.id,layout.world_position(hero.cell),hero.yaw)
		if not hero.has("base"): continue
		var base = _box(Vector3(hero.base[0],hero.base[1],hero.base[2]),layout.world_position(hero.cell)+Vector3.UP*(hero.base[1]/2),null,true)
		if hero.get("round",false):
			var cylinder = CylinderShape3D.new()
			cylinder.radius = hero.base[0]/2
			cylinder.height = hero.base[1]
			base.get_child(0).shape = cylinder
		base.name = "LandmarkBase_"+hero.id
		base.rotation.y = deg_to_rad(hero.yaw)
	for spec in layout.data.doors:
		if spec.id in game.state.removed:
			continue
		var door = _box(Vector3(spec.size[0],spec.size[1],spec.size[2]), layout.world_position(spec.cell) + Vector3(0,spec.size[1]/2,0), _material(Color(0.14,0.08,0.09)), true)
		door.rotation.y = deg_to_rad(spec.yaw)
		doors[spec.id] = door
	for spec in layout.data.pickups + layout.data.interactions:
		if spec.id in game.state.removed:
			continue
		markers[spec.id] = _place_model(PURPOSE_ART[spec.kind],layout.world_position(spec.cell)+Vector3.UP*0.06,180)
	refresh_machine_lights()
	_build_navigation()
	return true

func _build_navigation() -> void:
	var actor = preload("res://scripts/enemy.gd")
	var profiles := {}
	for spec in layout.data.enemies:
		if actor.LATE.get(spec.kind,{}).get("speed",1.0) == 0: continue
		profiles[spec.kind] = {"radius":actor.capsule_radius(spec.kind),"height":actor.capsule_height(spec.kind),"hover":1.16 if spec.kind in ["caster","choir_avatar"] else 0.0}
	var routes = Routes.new()
	routes.name = "NavigationRoutes"
	add_child(routes)
	if not routes.configure(self,profiles): routes.queue_free()

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
	if material != null:
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

func _roof_height(cell: Vector2i) -> float:
	return layout.roof_height(cell)

func _build_geometry() -> void:
	var floor_material = _material(Color.WHITE)
	var wall_material = _material(Color.WHITE)
	var roof_material = _material(Color(0.8,0.85,0.85))
	for entry in [[floor_material,"floor"],[wall_material,"wall"],[roof_material,"grate"]]:
		entry[0].albedo_texture = load("res://assets/art/textures/"+entry[1]+".png")
	var chunks = {}
	var size = float(layout.data.cell_size)
	for cell in layout.tiles:
		# Compatibility selects at most eight local lights per mesh. Keep geometry local.
		var chunk = Vector2i(floori(cell.x/4.0),floori(cell.y/4.0))
		if not chunks.has(chunk):
			chunks[chunk] = [SurfaceTool.new(),SurfaceTool.new()]
			for tool in chunks[chunk]:
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				tool.set_smooth_group(-1)
		var corners: Array[Vector3] = []
		for offset in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]:
			var point = Vector2(cell)+offset
			corners.append(Vector3(point.x*size,layout.height_at(point),point.y*size))
		for i in [0,1,2,0,2,3]:
			chunks[chunk][0].set_uv(Vector2(corners[i].x/size,corners[i].z/size))
			chunks[chunk][0].add_vertex(corners[i])
		for i in [0,2,1,0,3,2]:
			chunks[chunk][1].set_uv(Vector2(corners[i].x/size,corners[i].z/size))
			chunks[chunk][1].add_vertex(corners[i]+Vector3.UP*_roof_height(cell))
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var point = Vector2(cell)+Vector2(0.5,0.5)+Vector2(direction)*0.5
			var h = layout.height_at(point)
			var tall = _roof_height(cell)
			if not layout.is_walkable(cell+direction):
				var dimensions = Vector3(0.28,tall,size+0.28) if direction.x else Vector3(size+0.28,tall,0.28)
				var wall = _box(dimensions,Vector3(point.x*size,h+tall/2,point.y*size),wall_material,true)
				var occluder = OccluderInstance3D.new()
				occluder.occluder = BoxOccluder3D.new()
				# Only opaque static walls occlude. Insets keep openings and scenery edges visible.
				occluder.occluder.size = dimensions-Vector3.ONE*0.04
				wall.add_child(occluder)
			elif tall > _roof_height(cell+direction):
				var drop = tall-_roof_height(cell+direction)
				var dimensions = Vector3(0.28,drop,size) if direction.x else Vector3(size,drop,0.28)
				_box(dimensions,Vector3(point.x*size,h+tall-drop/2,point.y*size),wall_material,false)
	for chunk in chunks:
		for i in range(2):
			var mesh = MeshInstance3D.new()
			mesh.name = ("Floor" if i == 0 else "Ceiling")+str(chunk.x)+"_"+str(chunk.y)
			chunks[chunk][i].generate_normals()
			mesh.mesh = chunks[chunk][i].commit()
			mesh.material_override = floor_material if i == 0 else roof_material
			add_child(mesh)
			if i == 0:
				mesh.create_trimesh_collision()
				mesh.get_child(0).get_child(0).shape.backface_collision = true

# Blender -Y fronts export as Godot +Z; these are Godot-space yaw angles.
func _place_model(id: String, position_world: Vector3, yaw: float = 0.0, scale_model: Array = [1,1,1]) -> Node3D:
	if not _model_scenes.has(id):
		_model_scenes[id] = load("res://assets/art/world/"+id+".glb")
	var model = _model_scenes[id].instantiate()
	add_child(model)
	model.position = position_world
	model.rotation.y = deg_to_rad(yaw)
	model.scale = Vector3(scale_model[0],scale_model[1],scale_model[2])
	return model

func _build_scenery() -> void:
	var size = float(layout.data.cell_size)
	for cell in layout.tiles:
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if layout.is_walkable(cell+direction): continue
			var point = Vector2(cell)+Vector2(0.5,0.5)+Vector2(direction)*0.5
			var wall = Vector3(point.x*size,layout.height_at(point),point.y*size)-Vector3(direction.x,0,direction.y)*0.18
			_place_model("ribbed_wall",wall+Vector3.UP*0.3,rad_to_deg(atan2(direction.x,direction.y))+180)
			_place_model("conduit",wall+Vector3.UP*4.4,0 if direction.x else 90)
	for spec in layout.data.scenery:
		var position_world = layout.world_position(spec.cell)+Vector3.UP*spec.get("height",0.0)
		_place_model(spec.art,position_world,spec.get("yaw",0),spec.get("scale",[1,1,1]))
		for support in spec.get("supports",[]):
			var scale_model = spec.get("scale",[1,1,1])
			var factor = Vector3(scale_model[0],scale_model[1],scale_model[2])
			var dimensions = Vector3(support.size[0],support.size[1],support.size[2])*factor
			var offset = Vector3(support.offset[0],support.offset[1],support.offset[2])*factor
			var base = _box(dimensions,position_world+offset.rotated(Vector3.UP,deg_to_rad(spec.get("yaw",0)))+Vector3.UP*dimensions.y/2,null,true)
			base.name = "ScenerySupport_"+spec.art
			base.rotation.y = deg_to_rad(spec.get("yaw",0))
		if spec.has("solid"):
			var dimensions = Vector3(spec.solid[0],spec.solid[1],spec.solid[2])
			var base = _box(dimensions,position_world+Vector3.UP*dimensions.y/2,null,true)
			# Invisible envelope prevents walking through peripheral machinery.
			base.rotation.y = deg_to_rad(spec.get("yaw",0))

func _build_environment() -> void:
	var world = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.025,0.04,0.045)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.42,0.48,0.52)
	environment.ambient_light_energy = 0.4
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = Color(0.045,0.07,0.085)
	environment.fog_depth_begin = 16
	environment.fog_depth_end = 68
	environment.fog_density = 0.72
	environment.glow_enabled = true
	environment.glow_intensity = 0.16
	world.environment = environment
	add_child(world)
	for spec in layout.data.lights:
		var light = SpotLight3D.new() if spec.has("target") else OmniLight3D.new()
		light.position = layout.world_position(spec.cell)+Vector3.UP*spec.height
		light.light_color = Color(spec.color[0],spec.color[1],spec.color[2])
		light.light_energy = spec.energy
		light.shadow_enabled = spec.get("shadow",false)
		add_child(light)
		if spec.has("id"): machine_lights[spec.id] = light
		if light is SpotLight3D:
			light.spot_range = spec.range
			light.spot_angle = 48
			light.look_at(layout.world_position(spec.target)+Vector3.UP*2.5)
		else:
			light.omni_range = spec.range
		if spec.has("fixture_yaw"):
			_place_model("lumen_sconce",layout.world_position(spec.cell)+Vector3.UP*(spec.height-1.0),spec.fixture_yaw)

func apply_encounter_cue(spec: Dictionary, _restoring: bool) -> void:
	# Steady feed light: no flicker, motion, audio or text to replay on restoration.
	for id in spec.cue.light_ids:
		if machine_lights.has(id): machine_lights[id].light_color = Color(1.0,0.28,0.1)
	refresh_machine_lights()

func refresh_machine_lights() -> void:
	# Earned seals override a live feed, including version-1 saves without encounter flags.
	for hero in layout.data.heroes:
		if not hero.get("seal","") in game.state.keys: continue
		for id in hero.get("light_ids",[]):
			if machine_lights.has(id): machine_lights[id].light_color = Color(1.0,0.76,0.44)

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
	tween.finished.connect(door.queue_free)
	doors.erase(id)
	var routes = get_node_or_null("NavigationRoutes")
	if routes != null: routes.invalidate_doors()
