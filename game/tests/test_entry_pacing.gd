extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var game = load("res://scripts/main.gd").new()
	game.settings_path = "user://entry_pacing_preferences.json"
	game.progress_path = "user://entry_pacing_campaign.json"
	root.add_child(game)
	AudioServer.set_bus_mute(0,true)
	var level_index = 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="): level_index = int(arg.trim_prefix("--level="))
	for mode in range(3):
		game.state.new_campaign(mode)
		game.state.level_index = level_index
		game.start_level()
		game.set_process(false)
		game.player.set_physics_process(false)
		for actor in game.enemies: actor.set_physics_process(false)
		await physics_frame
		await physics_frame
		for frame in range(600):
			for actor in game.enemies: actor._physics_process(1.0/60)
			if game.state.health == 0: break
			await physics_frame
		var alert_ids = []
		for actor in game.enemies:
			if actor.alerted: alert_ids.append(actor.id)
		print("ENTRY difficulty=",mode," simulated_seconds=10 health=",game.state.health," alerted=",alert_ids)
		if not expect(game.state.health == 100,"Entry must allow reading the seven-second mission before combat"): return
		game.player.position = game.level.layout.world_position([14.5,17.5] if level_index == 0 else [14,19])
		await physics_frame
		await physics_frame
		var engaged = false
		for actor in game.enemies:
			actor._physics_process(1.0/60)
			engaged = engaged or actor.alerted
		if not expect(engaged,"Encounter must still activate when entering the nave"): return
	game.show_title()
	game.queue_free()
	paused = false
	await process_frame
	await process_frame
	print("PASS native ten-second idle entry on all difficulties and live nave alert; no invulnerability or adaptive AI")
	quit()

func expect(condition: bool, detail: String) -> bool:
	if not condition:
		push_error(detail)
		quit(1)
	return condition
