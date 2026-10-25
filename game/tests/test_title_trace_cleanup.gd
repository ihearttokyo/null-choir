extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scripts/main.gd").new()
	root.add_child(game)
	await process_frame
	assert(game.music.player.playing and game.music.player.stream is AudioStreamMP3)
	var trace = load("res://scripts/app_frame_trace.gd").new()
	trace.game = game
	await trace.cleanup(self)
	var released: bool = not game.music.player.playing and game.music.player.stream == null
	# Clean the negative-control fixture too, without changing the observed result.
	game.music.stop()
	game.queue_free()
	var drain: int = Time.get_ticks_usec() + 150000
	while Time.get_ticks_usec() < drain: await process_frame
	if not released:
		print("INTENDED_RED: actual frame-trace cleanup restarts and retains title audio")
		quit(1)
		return
	print("PASS actual Main title + frame-trace cleanup stops/releases shared music before mixer drain")
	quit()
