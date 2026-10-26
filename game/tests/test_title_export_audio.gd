extends SceneTree

func _initialize() -> void: call_deferred("run")

func finish(game, code: int) -> void:
	game.music.stop()
	game.queue_free()
	var deadline := Time.get_ticks_usec() + 150000
	while Time.get_ticks_usec() < deadline: await process_frame
	quit(code)

func run() -> void:
	var game = load("res://scripts/main.gd").new()
	root.add_child(game)
	await process_frame
	if not game.has_method("_export_title_audio_checks"):
		print("INTENDED_RED: production export path lacks title-specific resource/transport/PCM checks")
		await finish(game, 1)
		return
	var checks: Dictionary = await game._export_title_audio_checks()
	assert(checks.size() == 3 and not false in checks.values(), "Actual title decoder/transport/PCM must pass")
	var title_path: String = game.music.title_track
	game.music.title_track = "res://audio/title/missing-export.ogg"
	checks = await game._export_title_audio_checks()
	assert(not checks.title_recording, "Absent exported title path must fail even with prior transport alive")
	game.music.title_track = title_path
	game.music.play_level(0)
	checks = await game._export_title_audio_checks()
	assert(not checks.title_recording, "A different campaign MP3 must not masquerade as the selected title recording")
	game.music.play_title()
	var muted := AudioServer.is_bus_mute(0)
	game.music.set_paused(true)
	checks = await game._export_title_audio_checks()
	assert(checks.title_recording and not checks.title_transport and not checks.title_decoded_pcm)
	assert(game.music.player.stream_paused and AudioServer.is_bus_mute(0) == muted)
	game.music.stop()
	checks = await game._export_title_audio_checks()
	assert(not true in checks.values(), "Stopped/missing title must not pass any title acceptance")
	game.music.play_title()
	checks = await game._export_title_audio_checks()
	assert(not false in checks.values(), "A recovered actual title stream must decode again")
	assert(AudioServer.is_bus_mute(0) == muted)
	print("PASS actual Main title export helper checks resource, transport and non-silent PCM; paused/stopped negatives; not human listening")
	await finish(game, 0)
