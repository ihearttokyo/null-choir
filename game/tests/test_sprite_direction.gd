extends SceneTree

const RecordedAudioRelease = preload("res://tests/recorded_audio_release.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scripts/main.gd").new()
	root.add_child(game)
	game.start_campaign(1)
	game.set_process(false)
	game.player.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)
	var actor = game.enemies[0]
	actor.hp = 0
	for facing in range(8):
		actor.rotation.y = facing*TAU/8
		for view in [[Vector3.FORWARD,0],[Vector3.RIGHT,2],[Vector3.BACK,4],[Vector3.LEFT,6]]:
			game.player.position = actor.global_position+actor.global_basis*view[0]*5
			actor._physics_process(0)
			if actor.sprite.frame%8 != view[1]:
				push_error("Wrong atlas direction: yaw "+str(facing)+" expected "+str(view[1])+" got "+str(actor.sprite.frame%8))
				quit(1)
				return
	if not await RecordedAudioRelease.stop(game):
		push_error("Direction fixture must release its native recorded-audio playback before exit")
		quit(1)
		return
	# stop() above returned to title; release that new playback as well.
	game.music.stop()
	game.effects.stop()
	var drain_until: int = Time.get_ticks_usec()+100000
	while Time.get_ticks_usec() < drain_until:
		OS.delay_msec(2)
		await process_frame
	game.queue_free()
	paused = false
	await process_frame
	await process_frame
	print("PASS all 32 actor-rotation/front/right/back/left atlas selections")
	quit()
