extends SceneTree

const Music = preload("res://audio/music.gd")
const WallClock = preload("res://tests/wall_clock_wait.gd")
var music

func _initialize() -> void: call_deferred("run")

func run() -> void:
	music = Music.new()
	root.add_child(music)
	music.set_process(false)
	if not expect(music.has_method("play_title"), "INTENDED RED: Music must expose actual title playback"): return
	var player = music.player
	var bus = AudioServer.get_bus_index("Music")
	var count = AudioServer.get_bus_count()
	AudioServer.set_bus_volume_db(bus, -12.0)
	AudioServer.set_bus_mute(bus, true)
	var started = {"count": 0}
	music.playback_started.connect(func(): started.count += 1)
	paused = true
	music.play_title()
	var title = player.stream
	if not expect(title is AudioStreamOggVorbis and title.resource_path == music.title_track and title.loop and title.loop_offset == 0.0 and absf(title.get_length() - 78.669333) < 0.01, "Actual title Ogg decoder must expose its full length and zero-offset loop"): return
	if not expect(player.process_mode == Node.PROCESS_MODE_INHERIT and music.process_mode == Node.PROCESS_MODE_ALWAYS and player.can_process(), "Title transport must retain frame ownership in paused menus"): return
	await WallClock.seconds(self, 0.15)
	if not expect(player.playing and player.has_stream_playback() and player.get_playback_position() > 0, "Native Dummy title transport advances while the menu tree is paused"): return
	music.set_paused(true)
	await WallClock.seconds(self, 0.15)
	var position = player.get_playback_position()
	await WallClock.seconds(self, 0.12)
	if not expect(player.stream_paused and is_equal_approx(player.get_playback_position(), position), "Explicit title pause freezes native transport"): return
	music.play_title()
	if not expect(player.stream == title and not player.stream_paused and started.count == 2 and player.get_playback_position() >= position, "Repeated title resumes the same player/stream without restarting and signals the new owner"): return
	await WallClock.seconds(self, 0.12)
	if not expect(player.get_playback_position() > position, "Repeated title resumes actual transport"): return
	player.seek(title.get_length() - 0.08)
	await WallClock.seconds(self, 0.25)
	if not expect(player.playing and player.get_playback_position() < 1, "Actual title Vorbis playback wraps at its end"): return
	for index in [0, 7]:
		music.play_level(index)
		if not expect(player.stream is AudioStreamMP3 and player.stream.resource_path == music.level_tracks[index] and player.playing and not player.stream_paused, "Title must never suppress first/last campaign MP3 playback"): return
		music.set_pressure(1.0)
		music._process(1.0)
		music.set_paused(true)
		music.play_title()
		if not expect(player.stream == title and player.playing and not player.stream_paused and music.pressure == 0 and music.pressure_target == 0 and player.volume_db == -3, "Return/recovery/ending audio request replaces paused campaign and clears combat gain"): return
	if not expect(AudioServer.get_bus_volume_db(bus) == -12 and AudioServer.is_bus_mute(bus), "Title/campaign transitions preserve initial user bus settings"): return
	AudioServer.set_bus_volume_db(bus, -6.0)
	AudioServer.set_bus_mute(bus, false)
	await WallClock.seconds(self, 0.12)
	position = player.get_playback_position()
	var before_repeat = started.count
	music.play_title()
	if not expect(started.count == before_repeat + 1 and player.get_playback_position() >= position, "Unpaused settings/back title request signals ownership without restarting"): return
	var stream = player.stream
	var signals = started.count
	for index in [-1, 8]:
		music.play_level(index)
		if not expect(player.stream == stream and started.count == signals, "Existing invalid campaign indices must not replace title"): return
	var tracks = music.level_tracks.duplicate()
	music.level_tracks[0] = "res://audio/missing.mp3"
	music.play_level(0)
	if not expect(player.stream == stream and started.count == signals, "Missing campaign track must retain current stream without success signal"): return
	music.level_tracks = tracks
	var path = music.title_track
	for bad_path in ["res://audio/title/missing.ogg", music.level_tracks[0], "res://tests/fixtures/empty_title.tres"]:
		music.play_level(0)
		music.set_paused(true)
		music.title_track = bad_path
		music.play_title()
		if not expect(not player.playing and player.stream == null and not player.stream_paused and music.pressure == 0 and music.pressure_target == 0, "Missing/wrong/empty title must fail closed, not leak campaign transport"): return
	music.title_track = path
	music.play_title()
	if not expect(player.stream == title and player.playing, "Valid title must recover after bad inputs"): return
	music.set_pressure(1.0)
	music.set_paused(true)
	music.stop()
	music._process(2)
	if not expect(not player.playing and player.stream == null and not player.stream_paused and music.pressure == 0 and music.pressure_target == 0 and player.volume_db == -3, "STOP clears transport, stream, pause and combat gain without restarting"): return
	if not expect(music.player == player and music.get_child_count() == 1 and player.bus == &"Music" and AudioServer.get_bus_count() == count and AudioServer.get_bus_volume_db(bus) == -6 and not AudioServer.is_bus_mute(bus), "All paths preserve one player/bus and user volume/mute"): return
	music.free()
	music = null
	title = null
	stream = null
	player = null
	paused = false
	await WallClock.seconds(self, 0.15)
	print("PASS TITLE_AUDIO native Dummy Ogg length/loop/paused-tree/transport/repeat/switch/recovery/stop/settings; expected 6 invalid-input errors; NOT listening or Main scene")
	quit()

func expect(ok: bool, detail: String) -> bool:
	if not ok:
		push_error(detail)
		music.free()
		music = null
		paused = false
		quit(1)
	return ok
