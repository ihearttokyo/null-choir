extends SceneTree

const RecordedAudioRelease = preload("res://tests/recorded_audio_release.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var game = load("res://scripts/main.gd").new()
	game.settings_path = "user://axis_pause_contract_"+str(Time.get_ticks_usec())+".json"
	root.add_child(game)
	game.start_campaign(1)
	game.set_process(false)
	# Dispatch the real handler once per simulated event, after native input state advances.
	game.set_process_unhandled_input(false)
	game.player.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)
	var axis = InputEventJoypadMotion.new()
	axis.axis = JOY_AXIS_LEFT_X
	axis.axis_value = 0.8
	game.preferences.bind_event("pause",axis)
	await process_frame
	Input.parse_input_event(axis)
	Input.flush_buffered_events()
	game._unhandled_input(axis)
	if not expect(not game.playing and paused,"Initial axis press pauses"): return
	axis = axis.duplicate()
	axis.axis_value = 0.95
	await process_frame
	Input.parse_input_event(axis)
	Input.flush_buffered_events()
	game._unhandled_input(axis)
	if not expect(not game.playing and paused,"Held stick motion must not repeatedly toggle pause"): return
	axis = axis.duplicate()
	axis.axis_value = 0
	await process_frame
	Input.parse_input_event(axis)
	Input.flush_buffered_events()
	game._unhandled_input(axis)
	axis = axis.duplicate()
	axis.axis_value = 0.8
	await process_frame
	Input.parse_input_event(axis)
	Input.flush_buffered_events()
	game._unhandled_input(axis)
	if not expect(game.playing and not paused,"Release then press resumes once"): return
	if not expect(await RecordedAudioRelease.stop(game),"Controls fixture must release its native recorded-audio playback before exit"): return
	game.free()
	paused = false
	print("PASS native mapped stick axis pauses once per press, not once per motion event")
	quit()

func expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
