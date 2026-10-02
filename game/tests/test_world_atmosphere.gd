extends SceneTree

const ASSETS = ["nursery_growth_vault", "ossuary_sorting_vault", "inversion_cosmic_membrane", "heart_arterial_vault"]
var game

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var layout = load("res://scripts/level_data.gd").new()
	for index in range(4,8):
		if not expect(layout.load_level(index),"Actual late map must load"): return
		var id = ASSETS[index-4]
		var mounts = layout.data.scenery.filter(func(spec): return spec.art == id)
		if not expect(mounts.size() == 8,"Eight image-derived overhead mounts, four in each loop chamber: "+id+" (intended RED)"): return
		for spec in mounts:
			if not expect(not spec.has("solid") and spec.height >= 5.5 and spec.get("scale",[1,1,1]) == [1,1,1],"Overhead art must not add route collision or enlarge its accepted geometry"): return
		game = load("res://scripts/main.gd").new()
		game.settings_path = "user://atmosphere_preferences.json"
		game.progress_path = "user://atmosphere_progress.json"
		root.add_child(game)
		game.state.new_campaign(0)
		game.state.level_index = index
		game.start_level()
		game.pause_game()
		var models = game.level.get_children().filter(func(node): return node.scene_file_path.get_file() == id+".glb")
		if not expect(models.size() == 8,"Actual PackedScenes must be mounted, not just JSON metadata"): return
		for model in models:
			for mesh in model.find_children("*","MeshInstance3D",true,false):
				for surface in mesh.mesh.get_surface_count():
					var material = mesh.mesh.surface_get_material(surface)
					if material is BaseMaterial3D and material.albedo_texture != null:
						if not expect(not material.albedo_texture.resource_path.ends_with(".png"),"Actual module texture must remain embedded, not extracted duplicate PNG: "+material.albedo_texture.resource_path): return
			var bounds = model_bounds(model)
			if not expect(bounds.size.y > 3.6 and bounds.size.y < 4.2,"Real imported module bounds"): return
			for hero in layout.data.heroes:
				var node = game.level.get_children().filter(func(n): return n.scene_file_path.get_file() == hero.id+".glb")[0]
				if not expect(not bounds.intersects(model_bounds(node)),"Overhead apparatus clips protected unique hero: "+hero.id): return
			for x in range(floori(bounds.position.x/4),floori(bounds.end.x/4)+1):
				for z in range(floori(bounds.position.z/4),floori(bounds.end.z/4)+1):
					var cell = Vector2i(x,z)
					if not expect(layout.is_walkable(cell),"Overhead apparatus intersects a solid boundary wall: "+str(cell)): return
					for point in [Vector2(cell),Vector2(cell)+Vector2.RIGHT,Vector2(cell)+Vector2.ONE,Vector2(cell)+Vector2.DOWN]:
						var floor_y = layout.height_at(point)
						if not expect(bounds.position.y >= floor_y+5.5 and bounds.end.y <= floor_y+layout.roof_height(cell)-.25,"Real module must clear tallest regular sprite and every solid roof triangle: "+id+" "+str(cell)): return
			if index in [4,7]:
				var reserved = AABB(Vector3(24*4,-10,4*4),Vector3(13*4,40,11*4)) if index==4 else AABB(Vector3(26*4,-10,3*4),Vector3(16*4,40,14*4))
				if not expect(not bounds.intersects(reserved),"No atmosphere changes inside reserved boss arena"): return
		var lamps = layout.data.lights.filter(func(spec): return spec.get("id","").begins_with("atmosphere_"))
		if not expect(lamps.size() == 4 and lamps.all(func(spec): return not spec.get("shadow",false) and spec.range <= 24),"Four bounded native supporting lights; no new shadows"): return
		if not expect(game.level.get_children().filter(func(n): return n is Light3D and n.shadow_enabled).size()==4,"Protect four original shadowed landmark spots"): return
		print("STAGED ",layout.data.id," eight real overhead modules; hero/boundary/roof/actor clearance, reserved arenas and native light budget")
		game.show_title()
		paused = false
		await create_timer(.1).timeout
		game.free()
		game = null
		await process_frame
		await process_frame
	print("PASS native image-derived atmosphere staging in all four late maps")
	quit()

func model_bounds(model: Node3D) -> AABB:
	var result = AABB()
	var first = true
	for child in model.find_children("*","MeshInstance3D",true,false):
		var box = child.global_transform*child.mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result

func expect(condition: bool, detail: String) -> bool:
	if not condition:
		push_error(detail)
		if is_instance_valid(game): game.free()
		paused = false
		quit(1)
	return condition
