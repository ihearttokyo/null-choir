extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var game = load("res://scripts/main.gd").new()
	game.settings_path = "user://floor_placement_preferences.json"
	game.progress_path = "user://floor_placement_progress.json"
	root.add_child(game)
	game.state.new_campaign(0)
	game.state.level_index = 4
	game.start_level()
	game.pause_game()
	await physics_frame
	var good = true
	for cell in [[12.5,29.5],[12.2,29.8],[12.8,29.2]]:
		var point = game.level.layout.world_position(cell)
		var ray = PhysicsRayQueryParameters3D.create(point+Vector3.UP*3,point-Vector3.UP*3,1)
		var hit = game.level.get_world_3d().direct_space_state.intersect_ray(ray)
		print("FLOOR_PLACEMENT ",cell," declared=",point.y," native=",hit.get("position",Vector3.INF))
		if hit.is_empty() or absf(hit.position.y-point.y) > .003:
			push_error("Floor placement must match the actual triangulated ramp at fractional cells (intended RED)")
			good = false
			break
	game.show_title()
	paused = false
	await create_timer(.1).timeout
	game.free()
	await process_frame
	await process_frame
	if good: print("PASS fractional placement matches real native ramp triangles on both diagonal sides")
	quit(0 if good else 1)
