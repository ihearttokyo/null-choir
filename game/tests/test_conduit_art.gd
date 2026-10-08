extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var scene = load("res://assets/art/world/conduit.glb")
	if not expect(scene is PackedScene, "Actual GLB imports as PackedScene"): return
	var model = scene.instantiate()
	root.add_child(model)
	var meshes = model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D: meshes.push_front(model)
	if not expect(meshes.size() == 1, "One flattened mesh node"): return
	var mesh = meshes[0].mesh
	if not expect(mesh.get_surface_count() == 2, "Two retained material surfaces"): return
	if OS.get_cmdline_user_args().has("--drop-emission"):
		for surface in mesh.get_surface_count():
			var lost = mesh.surface_get_material(surface)
			lost.emission_enabled = false
			lost.emission_texture = null
			lost.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var triangles = 0
	var emitters = 0
	for surface in mesh.get_surface_count():
		var arrays = mesh.surface_get_arrays(surface)
		if not expect(arrays[Mesh.ARRAY_TEX_UV].size() == arrays[Mesh.ARRAY_VERTEX].size(), "UVs preserved for every imported vertex"): return
		triangles += arrays[Mesh.ARRAY_INDEX].size()/3
		var material = mesh.surface_get_material(surface)
		if not expect(material is BaseMaterial3D, "Native standard imported PBR material"): return
		if material.emission_enabled:
			emitters += 1
			if not expect(surface == 0 and material.emission_texture != null, "Iron surface must retain an actual emission texture"): return
		var names = material.get_property_list().map(func(p): return p.name)
		var textures = []
		for key in ["albedo_texture", "orm_texture", "roughness_texture", "metallic_texture", "emission_texture"]:
			if not key in names: continue
			var texture = material.get(key)
			if texture == null: continue
			if not expect(texture is Texture2D and texture.get_width() <= 256 and texture.get_height() <= 256, "Imported bounded Texture2D " + key): return
			if not expect(not texture.resource_path.ends_with(".png"), "Embedded texture must not become a duplicate external PNG"): return
			textures.append(key + "=" + str(texture.get_size()) + "/" + texture.resource_path)
		if not expect(textures.size() >= 2, "Imported albedo plus PBR data texture"): return
		print("SURFACE ", surface, " CLASS ", material.get_class(), " FILTER ", material.texture_filter, " EMISSION ", material.emission_enabled, " TEXTURES ", textures)
		if not material.emission_enabled and not expect(material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "Non-emissive material preserves mip filtering"): return
		if material.emission_enabled and not expect(material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_LINEAR, "Actual Godot emission-bearing material must use non-mip linear sampling"): return
	if not expect(emitters == 1, "Exactly one actual emission-bearing material must remain"): return
	if not expect(triangles == 2912, "Actual imported indexed geometry 2912 triangles"): return
	var bounds = mesh.get_aabb()
	if not expect(bounds.position.is_equal_approx(Vector3(-.49,0,-2.022)) and bounds.end.is_equal_approx(Vector3(.49,.585,2.006)), "Exact imported ground and bounds"): return
	model.free()
	print("PASS actual headless Godot import: two standard surfaces, bounded textures, UVs and fixed geometry; no rendered/game/performance acceptance")
	quit(0)
func expect(value: bool, message: String) -> bool:
	if not value:
		push_error(message)
		quit(1)
	return value
