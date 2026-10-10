extends SceneTree
var game
func _initialize()->void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")
func run()->void:
	if DisplayServer.get_name()=="headless":
		push_error("Native rendering contract requires actual GPU");quit(1);return
	if RenderingServer.get_current_rendering_method()!="mobile" or RenderingServer.get_current_rendering_driver_name()!="metal":
		push_error("Apple Silicon renderer must actually select Mobile/native Metal");quit(1);return
	game=load("res://scripts/main.gd").new()
	var prefix="user://rendering_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	game.settings_path=prefix+"_preferences.json"
	game.progress_path=prefix+"_campaign.json"
	root.add_child(game)
	game.state.new_campaign(1)
	await game.start_level()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	game.set_process(false)
	game.player.set_physics_process(false)
	game.hud.survey.set_physics_process(false)
	for actor in game.enemies:actor.set_physics_process(false)
	await physics_frame
	await physics_frame
	await RenderingServer.frame_post_draw
	var active=game.playing and not game.placement_pending and not paused and not game.menu_scroll.visible
	if not active:push_error("Active gameplay—not a paused menu—is required before readback")
	var layout_ok=root.content_scale_size==Vector2i(640,360) and root.content_scale_mode==Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var okay=active and layout_ok
	if not layout_ok:push_error("Keep640x360 HUD coordinates while rendering3D at window resolution")
	var pixels=root.get_texture().get_image()
	# Integer stretching letterboxes fractional window multiples.
	var ratios=Vector2(root.size)/Vector2(root.content_scale_size)
	var extent=root.content_scale_size*maxi(1,floori(minf(ratios.x,ratios.y)))
	okay=okay and pixels.get_size()==extent
	if pixels.get_size()!=extent:push_error("Active3D target must match integer-scaled content extent")
	print("ACTUAL GAME target=",pixels.get_size()," window=",DisplayServer.window_get_size()," logicalHUD=",root.content_scale_size," screen_scale=",DisplayServer.screen_get_scale(root.current_screen))
	game.show_title()
	paused=false
	await create_timer(.1).timeout
	game.free()
	await process_frame
	await process_frame
	if okay:print("PASS native active Mobile/Metal game:640x360 HUD coordinates and integer-scaled3D")
	quit(0 if okay else 1)
