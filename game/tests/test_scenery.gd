extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scripts/main.gd").new()
	game.settings_path = "user://scenery_contract_preferences.json"
	game.progress_path = "user://scenery_contract_progress.json"
	root.add_child(game)
	game.start_campaign(0)
	game.pause_game()
	if not expect(root.use_occlusion_culling,"Native static-wall occlusion must be enabled"): return
	var occluders = 0
	var floors = 0
	var ceilings = 0
	var art = {}
	var shadows = 0
	var environment: Environment
	for node in game.level.get_children():
		if node is MeshInstance3D and node.mesh is ArrayMesh:
			if not expect(node.mesh.get_aabb().size.x <= 16.01 and node.mesh.get_aabb().size.z <= 16.01,"Floor/ceiling must be local meshes; a whole-level AABB loses local lights"): return
			if not expect(node.material_override.albedo_color.r >= 0.8,"Authored texture must not be multiplied by a near-black tint"): return
			var arrays = node.mesh.surface_get_arrays(0)
			var vertices = arrays[Mesh.ARRAY_VERTEX]
			var normals = arrays[Mesh.ARRAY_NORMAL]
			for i in range(0,vertices.size(),3):
				if not expect((vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i]).dot(normals[i]) < 0,"Godot front faces must wind clockwise; floor/ceiling is invisible from the playable side"): return
			if node.name.begins_with("Floor"):
				floors += 1
				if not expect(node.get_child(0) is StaticBody3D,"Every floor chunk requires native capsule collision"): return
			if node.name.begins_with("Ceiling"): ceilings += 1
		if not node.scene_file_path.is_empty():
			var id = node.scene_file_path.get_file().get_basename()
			art[id] = art.get(id,0)+1
			if id in ["ribbed_wall","witness_relief","lumen_sconce"]:
				var cell = Vector2i(floori(node.position.x/4),floori(node.position.z/4))
				var faces_inward = false
				for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					if not game.level.layout.is_walkable(cell+direction):
						faces_inward = faces_inward or (node.basis*Vector3.BACK).normalized().dot(-Vector3(direction.x,0,direction.y)) > 0.9
				if not expect(faces_inward,"Blender -Y exports as Godot +Z; detailed wall front faces outside: "+id+" "+str(node.position)): return
		for child in node.get_children():
			if child is OccluderInstance3D:
				occluders += 1
				if not expect(node is StaticBody3D and not node in game.level.doors.values() and node.get_child(0).visible and node.get_child(0).mesh is BoxMesh,"Only visible opaque static walls may occlude; never moving doors or hidden prop envelopes"): return
				var wall_size = node.get_child(0).mesh.size
				if not expect(child.occluder is BoxOccluder3D and child.position == Vector3.ZERO and child.occluder.size.x < wall_size.x and child.occluder.size.y < wall_size.y and child.occluder.size.z < wall_size.z,"Wall occluders must stay conservatively inside actual wall geometry"): return
		if node is Light3D:
			if node.shadow_enabled: shadows += 1
			var cell = Vector2(node.position.x,node.position.z)/game.level.layout.data.cell_size
			var roof = game.level.layout.height_at(cell)+game.level._roof_height(Vector2i(floori(cell.x),floori(cell.y)))
			if not expect(node.position.y < roof-0.15,"Light is above the solid ceiling: "+str(node.position)): return
		if node is WorldEnvironment: environment = node.environment
	if not expect(occluders == 214,"Every existing boundary wall has native conservative occlusion; no invented blocking geometry"): return
	for marker in game.level.markers.values():
		if not expect(marker.scene_file_path == "res://assets/art/world/containment_capsule.glb","Pickups/interaction markers must use Blender containment pods rather than conspicuous placeholder cubes"): return
		if not expect(marker.scale == Vector3(0.25,0.17,0.25),"Collectible pods must remain small enough to preserve level routes"): return
	if not expect(floors > 10 and ceilings == floors,"Local lit floor and ceiling coverage required"): return
	for id in ["ribbed_wall","conduit","vault_span","lumen_sconce","witness_relief","suspended_cadaver","containment_capsule","drain_altar"]:
		if not expect(art.get(id,0) >= 2,"Scenery missing from playable scene: "+id): return
	if not expect(art.get("skin_bell",0) == 1 and art.get("siphon_heart",0) == 1,"Each loop retains its unique landmark"): return
	if not expect(shadows >= 2 and shadows <= 6,"Bounded shadowed landmark lighting required"): return
	if not expect(environment != null and environment.fog_enabled and environment.fog_mode == Environment.FOG_MODE_DEPTH,"Native depth fog required"): return
	if not expect(environment.fog_depth_begin >= 12 and environment.fog_depth_end > 40,"Fog must retain combat sight lines"): return
	await physics_frame
	for lamp in game.level.layout.data.lights:
		if not lamp.has("fixture_yaw"): continue
		var p = game.level.layout.world_position(lamp.cell)+Vector3.UP*lamp.height
		var query = PhysicsRayQueryParameters3D.create(p,p+Vector3.FORWARD.rotated(Vector3.UP,deg_to_rad(lamp.fixture_yaw))*1.2,1)
		if not expect(not game.level.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"Wall lamp has no wall behind it: "+str(lamp.cell)): return
	for hero in game.level.layout.data.heroes:
		var p = game.level.layout.world_position(hero.cell)
		var query = PhysicsRayQueryParameters3D.create(p+Vector3.UP*1.2,p+Vector3.UP*0.05,1)
		await physics_frame
		if not expect(not game.level.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"Landmark base requires collision: "+hero.id): return
	game.queue_free()
	paused = false
	await process_frame
	await process_frame
	print("PASS Intake scene contains Blender scenery, local lit floors/ceilings, bounded shadow lighting and combat-readable depth fog")
	quit()

func expect(condition: bool, detail: String) -> bool:
	if not condition:
		push_error(detail)
		quit(1)
	return condition
