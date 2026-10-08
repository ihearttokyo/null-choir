extends SceneTree

func _initialize(): call_deferred("run")
func run():
	var game = load("res://scripts/main.gd").new()
	game.settings_path = "user://conduit_preferences.json"
	game.progress_path = "user://conduit_progress.json"
	root.add_child(game)
	var shared_mesh = null
	var shared_textures = {}
	var counts = []
	for index in range(8):
		game.state.new_campaign(0)
		game.state.level_index = index
		game.start_level()
		game.pause_game()
		var models = game.level.get_children().filter(func(n): return n.scene_file_path == "res://assets/art/world/conduit.glb")
		if not expect(models.size() > 100, "Boundary conduit must be integrated into every playable level"): return
		counts.append(models.size())
		for model in models:
			var meshes = model.find_children("*", "MeshInstance3D", true, false)
			if not expect(meshes.size() == 1 and meshes[0].mesh.get_surface_count() == 2, "One shared mesh/two material surfaces in actual scene"): return
			var mesh = meshes[0].mesh
			if shared_mesh == null: shared_mesh = mesh
			if not expect(mesh == shared_mesh, "All campaign instances reuse imported mesh resource"): return
			var emitters = 0
			for surface in mesh.get_surface_count():
				var material = mesh.surface_get_material(surface)
				if not expect(material is BaseMaterial3D, "Actual standard PBR material"): return
				if material.emission_enabled:
					emitters += 1
					if not expect(material.emission_texture != null and material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_LINEAR, "Actual emission remains non-mip"): return
				else:
					if not expect(material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "Organic material preserves mip filtering"): return
				for property in ["albedo_texture", "roughness_texture", "metallic_texture"]:
					var texture = material.get(property)
					if not expect(texture != null and not texture.resource_path.ends_with(".png"), "Textures stay shared and embedded"): return
					var key = str(surface) + "/" + property
					if not shared_textures.has(key): shared_textures[key] = texture
					if not expect(texture == shared_textures[key], "Instances reuse exact texture resources"): return
			if not expect(emitters == 1, "Exactly one emitter survives actual campaign staging"): return
			var bounds = model.global_transform * mesh.get_aabb()
			if not expect(bounds.position.y >= model.position.y - .001 and bounds.size.y <= .601, "Grounded boundary visual does not extend into lower actor route"): return
		game.show_title()
		paused = false
		await process_frame
		await process_frame
	game.free()
	print("PASS all eight actual campaign scenes: conduit counts ", counts, ", shared mesh/textures, two surfaces, preserved emission/organic filtering")
	quit(0)

func expect(value: bool, message: String) -> bool:
	if not value:
		push_error(message)
		quit(1)
	return value
