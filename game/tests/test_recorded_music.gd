extends SceneTree

const WallClock = preload("res://tests/wall_clock_wait.gd")

const Music = preload("res://audio/music.gd")
const LEVELS = ["intake", "foundry", "processional", "reliquary", "nursery", "ossuary", "inversion", "heart"]

func _initialize(): call_deferred("run")

func run():
	var music = Music.new()
	root.add_child(music)
	music.set_process(false)
	if not expect(music.player is AudioStreamPlayer, "INTENDED RED: campaign must use recorded audio rather than MIDI synthesis"): return
	if not expect(music.player.stream == null, "Music node startup stays lazy until title or campaign is requested"): return
	var bus = AudioServer.get_bus_index("Music")
	AudioServer.set_bus_mute(bus, true)
	AudioServer.set_bus_volume_db(bus, -12.0)
	var player = music.player
	var bus_count = AudioServer.get_bus_count()
	for i in LEVELS.size():
		if not expect(music.level_tracks[i] == "res://audio/suno/" + LEVELS[i] + ".mp3", "Eight selected Suno takes must match campaign order"): return
		music.play_level(i)
		var stream = player.stream
		if not expect(stream is AudioStreamMP3 and stream.loop and stream.get_length() > 180 and stream.get_length() < 310, "Actual compressed campaign recording must load with a finite full-length loop"): return
		await WallClock.seconds(self, 0.12)
		if not expect(player.playing and player.get_playback_position() > 0, "Native recorded transport must advance"): return
		music.set_paused(true)
		# The audio thread can finish its already mixed block before observing pause.
		await WallClock.seconds(self, 0.15)
		var position = player.get_playback_position()
		await WallClock.seconds(self, 0.12)
		if not expect(player.stream_paused and is_equal_approx(player.get_playback_position(), position), "Pause must freeze the actual recorded transport"): return
		music.set_paused(false)
		await WallClock.seconds(self, 0.12)
		if not expect(player.get_playback_position() > position, "Resume must continue the recording"): return
		music.play_level(i)
		if not expect(player.stream == stream and player.playing and not player.stream_paused and player.get_playback_position() < 0.1, "Restart must reuse the track and restart at zero"): return
		player.seek(stream.get_length() - 0.08)
		await WallClock.seconds(self, 0.25)
		if not expect(player.playing and player.get_playback_position() < 1.0, "Actual compressed recording must loop instead of ending"): return
		if not expect(music.player == player and AudioServer.get_bus_count() == bus_count and AudioServer.get_bus_volume_db(bus) == -12 and AudioServer.is_bus_mute(bus), "Track changes preserve one player and user bus settings"): return
	music.set_pressure(1.0)
	music._process(0.05)
	var attack = player.volume_db
	if not expect(attack > -3.0 and attack < 0.0, "Recorded pressure gain must ease without amplifying above the authored mix"): return
	music.set_paused(true)
	music._process(2.0)
	if not expect(player.volume_db == attack, "Pause must freeze gain smoothing"): return
	music.set_paused(false)
	for value in [NAN, INF, -INF, -1.0]:
		music.set_pressure(value)
		music._process(8.0)
		if not expect(is_equal_approx(player.volume_db, -3.0), "Non-finite or negative pressure must settle safely"): return
	music.stop()
	if not expect(not player.playing and player.stream == null, "Explicit stop must release the recording and playback"): return
	music.free()
	music = null
	player = null
	await WallClock.seconds(self, 0.15)
	print("PASS Suno eight-level recordings, native transport/repeat, pause/resume/restart/stop, one lazy player and independent Music bus")
	quit()

func expect(ok: bool, detail: String) -> bool:
	if not ok:
		push_error(detail)
		quit(1)
	return ok
