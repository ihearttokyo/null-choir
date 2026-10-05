extends SceneTree

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func run() -> void:
	var game = preload("res://scripts/main.gd").new()
	root.add_child(game)
	game.set_process(false)
	var effects = game.get_node_or_null("Effects")
	if not expect(effects != null,"Actual game must own its independent offline Effects player"): return
	game.start_campaign(1)
	game.player.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)
	game.shot(1)
	if not expect(effects.players.rivet.playing,"Actual weapon shot must route to native PCM"): return
	effects.stop()
	game.hit_feedback()
	if not expect(effects.players.flesh.playing,"Actual hit feedback must route to native PCM"): return
	effects.stop()
	game.impact(Vector3.ZERO)
	if not expect(effects.players.impact.playing,"Actual world impact must route to native PCM"): return
	game.pause_game()
	if not expect(effects.paused and effects.players.impact.stream_paused,"Actual game pause must freeze effect voices"): return
	game.resume_game()
	if not expect(not effects.paused,"Actual game resume must release effect pause"): return
	game.show_title()
	if not expect(effects.players.values().all(func(p): return not p.playing),"Actual title transition must stop effect voices"): return
	await create_timer(0.1).timeout
	game.free()
	await create_timer(0.1).timeout
	await process_frame
	print("PASS actual shot/hit/world feedback and pause/title offline PCM lifecycle")
	quit()

func expect(condition: bool, text: String) -> bool:
	if not condition:
		push_error(text)
		quit(1)
	return condition
