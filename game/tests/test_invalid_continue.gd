extends SceneTree

# This fixture writes only the explicitly supplied disposable source root.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var isolated := OS.get_environment("NULL_CHOIR_ISOLATED_SOURCE_ROOT")
	if isolated.is_empty() or ProjectSettings.globalize_path("res://").trim_suffix("/") != isolated.trim_suffix("/"):
		push_error("SETUP requires exact disposable project root")
		quit(2)
		return
	AudioServer.set_bus_mute(0,true)
	var game = preload("res://scripts/main.gd").new()
	game.settings_path = "user://invalid_continue_preferences.json"
	game.progress_path = "user://invalid_continue_campaign.json"
	root.add_child(game)
	game.set_process(false)
	game.hud.survey.set_physics_process(false)
	game.state.new_campaign(1)
	await game.start_level()
	game.player.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)
	if game._save() != OK:
		push_error("SETUP real actor-bearing save required")
		game.free()
		quit(2)
		return
	game.show_title()
	var prior_state: Dictionary = game.state.to_dict().duplicate(true)
	var prior_save := FileAccess.get_file_as_string(game.progress_path)
	var source := "res://data/01_intake.json"
	var original := FileAccess.get_file_as_string(source)
	var invalid: Dictionary = JSON.parse_string(original)
	invalid.enemies[0].kind = "unsupported_role"
	var file := FileAccess.open(source,FileAccess.WRITE)
	file.store_string(JSON.stringify(invalid))
	file.close()
	await game.continue_campaign()
	var safe: bool = not game.playing and paused and not game.placement_pending and game.level == null and game.player == null and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and game.menu.get_child(0).text == "NULL CHOIR"
	var unchanged: bool = game.state.to_dict() == prior_state and FileAccess.get_file_as_string(game.progress_path) == prior_save
	var actionable: bool = game.message.begins_with("LEVEL LOAD FAILED:") and "01_intake.json" in game.message and "enemies[0].kind" in game.message and "retry" in game.message.to_lower()
	file = FileAccess.open(source,FileAccess.WRITE)
	file.store_string(original)
	file.close()
	# A subsequent unrelated invalid save must not retain the old source diagnostic.
	file = FileAccess.open(game.progress_path,FileAccess.WRITE)
	file.store_string("{}")
	file.close()
	await game.continue_campaign()
	var cleared: bool = game.message == "NO VALID RECOVERY IMAGE"
	game.show_title()
	game.free()
	paused = false
	OS.delay_msec(100)
	await process_frame
	await process_frame
	if not safe or not unchanged or not actionable or not cleared:
		push_error("Continue must retain source diagnostic, safe title, unchanged saved/live state, and clear stale errors")
		quit(1)
		return
	print("PASS real actor-bearing Continue rejects isolated source with actionable diagnostic, atomic state/save and cleared stale error")
	quit(0)
