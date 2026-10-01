extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var game = load("res://scripts/main.gd").new()
	root.add_child(game)
	if game.music == null:
		push_error("Game must own one persistent live-MIDI node")
		quit(1)
		return
	var music = game.music
	var bank = music.player.bank
	game.start_campaign(1)
	game.set_process(false)
	game.player.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)
	music.player.set_process(false)
	music.player._process(0.2)
	var position = music.player.position
	game.pause_game()
	music.player._process(1)
	if not expect(music.player.position == position and music.player.playback_paused,"Game pause must freeze MIDI clock"): return
	game.resume_game()
	music.player._process(0.1)
	if not expect(music.player.position > position,"Game resume must continue MIDI clock"): return
	game.restart_level()
	if not expect(game.music == music and music.player.bank == bank and music.player.position == 0,"Level restart must reuse bank and restart song"): return
	game.show_title()
	if not expect(music.player.get_now_playing_polyphony() == 0,"Title must stop all music voices"): return
	game.free()
	bank = null
	await create_timer(0.2,true).timeout
	print("PASS persistent live-MIDI gameplay start/pause/resume/restart/title integration")
	quit()

func expect(condition: bool, detail: String) -> bool:
	if not condition:
		push_error(detail)
		quit(1)
	return condition
