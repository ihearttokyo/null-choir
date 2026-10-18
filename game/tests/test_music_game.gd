extends SceneTree

const WallClock = preload("res://tests/wall_clock_wait.gd")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	AudioServer.set_bus_mute(0, true)
	var game = load("res://scripts/main.gd").new()
	var prefix = "user://recorded_music_" + str(Time.get_ticks_usec())
	game.progress_path = prefix + "_campaign.json"
	game.settings_path = prefix + "_preferences.json"
	root.add_child(game)
	if not expect(game.music != null and game.music.player is AudioStreamPlayer and game.music.player.stream == null, "Game must own one persistent lazy recorded-music node"): return
	var music = game.music
	game.start_campaign(1)
	game.set_process(false)
	game.player.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)
	var first = music.player.stream
	await WallClock.seconds(self, 0.2)
	if not expect(first is AudioStreamMP3 and first.resource_path == music.level_tracks[0] and music.player.get_playback_position() > 0, "Campaign must play the actual Intake Suno recording"): return
	game.pause_game()
	await WallClock.seconds(self, 0.05)
	var position = music.player.get_playback_position()
	await WallClock.seconds(self, 0.15)
	if not expect(music.player.get_playback_position() == position and music.player.stream_paused, "Game pause must freeze recorded transport"): return
	game.resume_game()
	await WallClock.seconds(self, 0.15)
	if not expect(music.player.get_playback_position() > position, "Game resume must continue recorded transport"): return
	await game.restart_level()
	if not expect(game.music == music and music.player.stream == first and music.player.get_playback_position() < 0.15, "Level restart must reuse the music node and restart the recording"): return
	game.show_title()
	if not expect(not music.player.playing and music.player.stream == null, "Title must stop and release the recording"): return
	game.free()
	first = null
	paused = false
	await WallClock.seconds(self, 0.2)
	print("PASS persistent Suno gameplay start/pause/resume/restart/title integration")
	quit()

func expect(ok: bool, detail: String) -> bool:
	if not ok:
		push_error(detail)
		quit(1)
	return ok
