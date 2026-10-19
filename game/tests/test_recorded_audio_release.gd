extends SceneTree

const RecordedAudioRelease = preload("res://tests/recorded_audio_release.gd")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var game = load("res://scripts/main.gd").new()
	var prefix = "user://audio_release_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	game.settings_path = prefix+"_preferences.json"
	game.progress_path = prefix+"_campaign.json"
	root.add_child(game)
	if not expect(not await RecordedAudioRelease.stop(game),"Title-only playback must not count as a retained campaign recording"): return
	game.state.new_campaign(1)
	await game.start_level()
	var held: AudioStreamMP3 = game.music.player.stream
	if not expect(held != null,"Real native recording required"): return
	var started: int = Time.get_ticks_usec()
	if not expect(not await RecordedAudioRelease.stop(game),"Retained recording must time out, not falsely pass"): return
	var elapsed: int = Time.get_ticks_usec()-started
	if not expect(elapsed >= 2000000 and elapsed < 3000000,"Native audio retention wait must be bounded"): return
	held = null
	await game.start_level()
	var recording: WeakRef = weakref(game.music.player.stream)
	if not expect(await RecordedAudioRelease.stop(game) and recording.get_ref() == null,"Unretained native recording must release"): return
	game.music.stop()
	await load("res://tests/wall_clock_wait.gd").seconds(self,0.15)
	game.free()
	paused = false
	await process_frame
	print("PASS native recorded-audio cleanup rejects missing/retained streams and releases actual playback within its deadline")
	quit()

func expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
