extends SceneTree

const WallClock = preload("res://tests/wall_clock_wait.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scripts/main.gd").new()
	game.progress_path = "user://completion_contract.json"
	root.add_child(game)
	game.start_campaign(1)
	game.set_process(false)
	game.player.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)
	game.collect_key("blood_key")
	game.collect_key("ivory_key")
	game.unlock_door("containment_gate")
	game.player.position = game.level.layout.world_position([14.5,2.2])
	await physics_frame
	await physics_frame
	game.interact()
	if not expect(game.state.level_index == 1 and not game.playing,"Exit must advance once"): return
	var event = InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	game._unhandled_input(event)
	if not expect(not game.playing and game.level == null,"Escape must not resume completed map"): return
	if FileAccess.file_exists(game.progress_path): DirAccess.remove_absolute(game.progress_path)
	game.music.stop()
	await WallClock.seconds(self,0.15)
	game.queue_free()
	paused = false
	await process_frame
	print("PASS completed Intake releases old map and cannot resume via Escape")
	quit()

func expect(condition: bool, detail: String) -> bool:
	if not condition:
		push_error(detail)
		quit(1)
	return condition
