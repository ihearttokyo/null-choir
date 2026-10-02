extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Scenery pixels require the native GPU renderer, not --headless")
		quit(1)
		return
	var output = "user://scenery_review"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scenery-occlusion="): root.use_occlusion_culling = arg.ends_with("1")
		if arg.begins_with("--scenery-output="): output = arg.trim_prefix("--scenery-output=")
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Scenery evidence directory unavailable")
		quit(1)
		return
	root.title = "NULL CHOIR / scenery validation"
	AudioServer.set_bus_mute(0,true)
	var game = load("res://scripts/main.gd").new()
	game.settings_path = "user://scenery_view_preferences.json"
	game.progress_path = "user://scenery_view_progress.json"
	root.add_child(game)
	var start = Time.get_ticks_msec()
	game.start_campaign(0)
	print("LEVEL_BUILD_MS ",Time.get_ticks_msec()-start)
	game.set_process(false)
	game.player.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)
	game.settings.head_bob = false
	game.settings.camera_shake = false
	game.message = ""
	game.message_time = 0
	game.hud.queue_redraw()
	var layout = game.level.layout
	for view in [{"id":"entrance","cell":[14.5,28.5],"target":[14.5,20],"height":1.65},{"id":"bell","cell":[7.8,17.4],"target":[4.5,15.2],"height":3.6},{"id":"siphon","cell":[22.4,17.2],"target":[25.5,14.5],"height":2.3},{"id":"combat","cell":[14.5,28.5],"target":[14.5,20],"height":1.65}]:
		game.player.position = layout.world_position(view.cell)
		game.player.camera.look_at(layout.world_position(view.target)+Vector3.UP*view.height)
		if view.id == "combat":
			game.set_process(true)
			game.player.set_physics_process(true)
			for actor in game.enemies: actor.set_physics_process(true)
			Input.action_press("fire")
			Input.action_press("move_forward",0.25)
		# Separate cold shader/scene warm-up from sustained frame-rate sampling.
		await create_timer(1.0).timeout
		var frames = 0
		var before = Time.get_ticks_msec()
		while Time.get_ticks_msec()-before < 2500:
			if view.id == "combat": game.state.health = 100 # Controlled survival; native combat/physics still execute.
			await RenderingServer.frame_post_draw
			frames += 1
		var pixels = root.get_texture().get_image()
		if pixels.is_empty() or pixels.save_png(output+"/"+view.id+".png") != OK:
			push_error("Rendered scenery capture failed: "+view.id)
			quit(1)
			return
		print("RENDERED ",view.id," fps=",1000.0*frames/(Time.get_ticks_msec()-before)," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)," pixels=",pixels.get_size())
	Input.action_release("fire")
	Input.action_release("move_forward")
	game.music.stop()
	game.queue_free()
	await process_frame
	await process_frame
	print("PASS native GPU scenery pixels captured at three controlled camera positions and native combat sample; visual acceptance remains manual")
	quit()
