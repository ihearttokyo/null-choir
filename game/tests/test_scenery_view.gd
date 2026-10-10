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
	game.state.new_campaign(0)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="): game.state.level_index = int(arg.trim_prefix("--level="))
	game.start_level()
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
	var views = [{"id":"entrance","cell":[14.5,28.5],"target":[14.5,20],"height":1.65},{"id":"bell","cell":[7.8,17.4],"target":[4.5,15.2],"height":3.6},{"id":"siphon","cell":[22.4,17.2],"target":[25.5,14.5],"height":2.3},{"id":"combat","cell":[14.5,28.5],"target":[14.5,20],"height":1.65}]
	if game.state.level_index == 1:
		views = [{"id":"entrance","cell":[14.5,30.5],"target":[17,27],"height":1.65},{"id":"furnace","cell":[9.6,17.8],"target":[7.5,14.5],"height":4.4},{"id":"crucible","cell":[27.3,14.2],"target":[24.5,12.5],"height":2.8},{"id":"combat","cell":[14,20.5],"target":[11,20],"height":1.65}]
	elif game.state.level_index == 2:
		views = [{"id":"entrance","cell":[21.5,29.5],"target":[20.5,25.5],"height":1.65},{"id":"organ","cell":[8.1,16.5],"target":[7.5,14.5],"height":3.7},{"id":"palanquin","cell":[27.1,14.8],"target":[27.5,12.5],"height":2.7},{"id":"combat","cell":[16.5,21.5],"target":[16.5,15.5],"height":1.65}]
	elif game.state.level_index == 3:
		views = [{"id":"entrance","cell":[19.5,35.0],"target":[19.5,26.5],"height":1.65},{"id":"halo","cell":[9.8,20.5],"target":[7.5,16.5],"height":4.5},{"id":"wheel","cell":[29.3,19.5],"target":[31.5,15.5],"height":3.3},{"id":"combat","cell":[11.5,19.5],"target":[11.5,17.5],"height":1.65}]
	for view in views:
		game.player.position = layout.world_position(view.cell)
		game.player.camera.look_at(layout.world_position(view.target)+Vector3.UP*view.height)
		if view.id == "combat":
			if game.state.level_index in [2,3]:
				game.state.owned_weapons.append(2)
				game.state.ammo[2] = 90
				game.state.weapon = 2
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
		if not game.playing or game.menu_scroll.visible:
			push_error("Controlled scenery capture requires active gameplay, not a paused menu overlay")
			await game._finish_quit()
			quit(1)
			return
		var pixels = root.get_texture().get_image()
		if pixels.is_empty() or pixels.save_png(output+"/"+view.id+".png") != OK:
			push_error("Rendered scenery capture failed: "+view.id)
			quit(1)
			return
		print("RENDERED ",view.id," fps=",1000.0*frames/(Time.get_ticks_msec()-before)," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)," pixels=",pixels.get_size())
	Input.action_release("fire")
	Input.action_release("move_forward")
	print("PASS native GPU scenery pixels captured at three controlled camera positions and native combat sample; visual acceptance remains manual")
	game._finish_quit()
