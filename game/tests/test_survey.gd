extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var game = load("res://scripts/main.gd").new()
	game.settings_path = "user://survey_unused_"+str(Time.get_ticks_usec())+".json"
	root.add_child(game)
	game.start_campaign(1)
	game.set_process(false)
	game.set_process_unhandled_input(false)
	game.player.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)
	await physics_frame
	await physics_frame
	if not expect(game.hud.get("survey") != null,"Image-derived native survey must be integrated in the actual HUD"): return
	var survey = game.hud.survey
	survey.reveal()
	if not expect(not survey.visible and game.state.explored.size() > 0 and game.state.explored.size() <= 25,"Survey begins closed; local discovery is bounded"): return
	var known = game.state.explored.duplicate(true)
	survey.reveal()
	if not expect(game.state.explored == known,"Standing still does not repeat discovery work or duplicate cells"): return
	for point in known:
		var cell = Vector2i(point[0],point[1])
		if not expect(game.level.layout.is_walkable(cell),"Only authored walkable cells may be mapped"): return
		var to = game.level.layout.world_position([point[0]+0.5,point[1]+0.5])+Vector3.UP*1.55
		var query = PhysicsRayQueryParameters3D.create(game.player.camera.global_position,to,1)
		if cell != Vector2i(Vector2(game.player.position.x,game.player.position.z)/game.level.layout.data.cell_size) and not expect(game.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"Walls and closed gates cannot reveal cells behind them"): return
	survey.toggle()
	if not expect(survey.visible and game.playing and not paused,"Survey leaves real combat live"): return
	var data: Dictionary = survey.draw_state()
	if not expect(data.cells.size() == known.size() and not data.has("enemies"),"Presentation uses actual discovery and does not expose enemies"): return
	for icon in data.icons:
		if not expect([icon.cell.x,icon.cell.y] in known,"Only discovered locations receive icons"): return
	var before = game.state.to_dict().duplicate(true)
	survey.draw_state()
	if not expect(game.state.to_dict() == before,"Survey presentation is read-only"): return
	var restored = game.Campaign.new()
	if not expect(restored.from_dict(JSON.parse_string(JSON.stringify(before))) and restored.explored == known,"Exploration survives the real campaign JSON boundary"): return
	var legacy = before.duplicate(true)
	legacy.erase("explored")
	if not expect(restored.from_dict(legacy) and restored.explored.is_empty(),"Legacy v1 saves still load"): return
	for cells in [[[0.5,1]],[[NAN,1]],[[1,1],[1,1]],[[256,1]],["fake"]]:
		var invalid = before.duplicate(true)
		invalid.explored = cells
		var frozen = restored.to_dict().duplicate(true)
		if not expect(not restored.from_dict(invalid) and restored.to_dict() == frozen,"Malformed survey data cannot mutate live state"): return
	game.state.restore_checkpoint()
	if not expect(game.state.explored == known,"Checkpoint resource rewind keeps route knowledge"): return
	game.pause_game()
	if not expect(not survey.visible,"Pause closes survey before displaying menu"): return
	game.resume_game()
	var key = InputEventKey.new()
	key.physical_keycode = KEY_M
	key.pressed = true
	if not expect(InputMap.event_is_action(key,"survey"),"Default desktop survey control"): return
	var pad = InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_BACK
	pad.pressed = true
	if not expect(InputMap.event_is_action(pad,"survey"),"Default controller survey control"): return
	for event in [key,pad]:
		await dispatch(game,event)
		if not expect(survey.visible and game.playing and not paused,"Mapped keyboard/controller input opens live survey"): return
		event.pressed = false
		await dispatch(game,event)
		event.pressed = true
		await dispatch(game,event)
		if not expect(not survey.visible,"A second physical press closes survey"): return
		event.pressed = false
		await dispatch(game,event)
	var rebound = InputEventKey.new()
	rebound.physical_keycode = KEY_N
	rebound.pressed = true
	game.preferences.bind_event("survey",rebound)
	key.pressed = true
	await dispatch(game,key)
	if not expect(not survey.visible,"Old mapping cannot open rebound survey"): return
	key.pressed = false
	await dispatch(game,key)
	await dispatch(game,rebound)
	if not expect(survey.visible,"Rebound action reaches actual survey handler"): return
	rebound.pressed = false
	await dispatch(game,rebound)
	var prefs = game.Preferences.new()
	var old_prefs = prefs.to_dict()
	old_prefs.version = 1
	old_prefs.values.erase("reduced_damage_flashes")
	old_prefs.bindings.erase("survey")
	if not expect(prefs.from_dict(old_prefs) and prefs.binding_text("survey").contains("M"),"Legacy preferences acquire only the new default action"): return
	game.state.complete_level()
	if not expect(game.state.explored.is_empty(),"Next level has independent unexplored routes"): return
	game.show_title()
	game.free()
	paused = false
	await process_frame
	print("PASS native live survey, real local occlusion, no spoilers, bounded discovery, legacy saves/controls, pause and campaign progression")
	quit()

func dispatch(game: Node, event: InputEvent) -> void:
	await process_frame
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	game._unhandled_input(event)

func expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
