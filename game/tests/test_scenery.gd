extends SceneTree

const RecordedAudioRelease = preload("res://tests/recorded_audio_release.gd")

const PurposeContract = preload("res://tests/test_marker_purposes.gd")

var game
var master_muted := false
var mouse_mode: int

func _initialize() -> void:
	master_muted = AudioServer.is_bus_mute(0)
	mouse_mode = Input.mouse_mode
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func run() -> void:
	game = load("res://scripts/main.gd").new()
	var prefix = "user://scenery_contract_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	game.settings_path = prefix+"_preferences.json"
	game.progress_path = prefix+"_progress.json"
	root.add_child(game)
	game.state.new_campaign(0)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="): game.state.level_index = int(arg.trim_prefix("--level="))
	await game.start_level()
	if not expect(is_instance_valid(game.level) and game.playing,"Main must start the authored scenery level"): return
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
	var boundary_count = 0
	for cell in game.level.layout.tiles:
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if not game.level.layout.is_walkable(cell+direction): boundary_count += 1
	if not expect(occluders == boundary_count,"Every boundary wall has native conservative occlusion; no invented blocking geometry"): return
	if game.state.level_index == 0 and not expect(occluders == 214,"Preserve exact Intake boundary count"): return
	for spec in game.level.layout.data.pickups+game.level.layout.data.interactions:
		if spec.id in game.state.removed:
			if not expect(not game.level.markers.has(spec.id),"Consumed marker absent: "+spec.id): return
			continue
		if not PurposeContract.check_marker(game.level,spec,expect): return
	if not expect(floors > 10 and ceilings == floors,"Local lit floor and ceiling coverage required"): return
	for id in ["ribbed_wall","conduit","vault_span","lumen_sconce","witness_relief","suspended_cadaver","containment_capsule","drain_altar"]:
		if not expect(art.get(id,0) >= 2,"Scenery missing from playable scene: "+id): return
	for hero in game.level.layout.data.heroes:
		if not expect(art.get(hero.id,0) == 1,"Each loop retains its unique landmark: "+hero.id): return
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
		if hero.id == "ossuary_rib_bridge":
			if not expect(not hero.has("base") and game.level.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"Open bridge central passage must have no landmark-base collision"): return
			query.from = p+Vector3.UP*.05
			query.to = p-Vector3.UP*.25
			var floor_hit = game.level.get_world_3d().direct_space_state.intersect_ray(query)
			if not expect(not floor_hit.is_empty() and absf(floor_hit.position.y-p.y) < .003,"Open bridge retains the actual raised floor"): return
			continue
		if not expect(not game.level.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"Landmark base requires collision: "+hero.id): return
	var level_id = game.level.layout.data.id
	if not expect(await RecordedAudioRelease.stop(game),"Scenery fixture must release its native recorded-audio playback before exit"): return
	cleanup()
	await process_frame
	await process_frame
	Input.mouse_mode = mouse_mode
	AudioServer.set_bus_mute(0,master_muted)
	print("PASS ",level_id," scene contains Blender scenery, local lit floors/ceilings, bounded shadow lighting and combat-readable depth fog")
	quit()

func cleanup() -> void:
	paused = false
	if is_instance_valid(game):
		game.playing = false
		game.placement_pending = false
		if game.music != null: game.music.stop()
		if game.effects != null: game.effects.stop()
		for path in [game.settings_path,game.settings_path+".tmp",game.progress_path,game.progress_path+".tmp"]:
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
		game.queue_free()
	game = null

func expect(condition: bool, detail: String) -> bool:
	if not condition:
		cleanup()
		Input.mouse_mode = mouse_mode
		AudioServer.set_bus_mute(0,master_muted)
		push_error(detail)
		quit(1)
	return condition
