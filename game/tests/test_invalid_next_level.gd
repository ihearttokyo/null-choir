extends SceneTree

# Run only against a disposable project with a rejected Foundry source.
class ExitGame extends "res://scripts/main.gd":
	func nearest_interaction() -> Dictionary:
		return {"id":"fixture_exit","kind":"exit","requires":[]}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var next = preload("res://scripts/level_data.gd").new()
	if next.load_level(1):
		push_error("SETUP requires isolated rejected Foundry source; authored data must not be modified")
		quit(2)
		return
	var game = ExitGame.new()
	game.settings_path = "user://invalid_next_preferences.json"
	game.progress_path = "user://invalid_next_campaign.json"
	root.add_child(game)
	game.set_process(false)
	game.hud.survey.set_physics_process(false)
	game.state.new_campaign(1)
	await game.start_level()
	game.player.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)
	game.interact()
	var safe: bool = not game.playing and paused and not game.placement_pending and game.level == null and game.player == null and game.enemies.is_empty() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
	var title: bool = game.menu_scroll.visible and game.menu.get_child(0).text == "NULL CHOIR"
	var actionable: bool = game.message.begins_with("LEVEL LOAD FAILED:") and "02_foundry.json" in game.message
	game.show_title()
	game.free()
	paused = false
	OS.delay_msec(100)
	await process_frame
	await process_frame
	if not safe or not title or not actionable:
		push_error("Rejected next source must leave actionable safe title, not completed-level menu")
		quit(1)
		return
	print("PASS actual exit dispatch with rejected next source retains safe actionable title")
	quit(0)
