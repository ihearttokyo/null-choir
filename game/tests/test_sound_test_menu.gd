extends SceneTree

var game
var prefix := "user://sound_test_menu_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())

func _initialize() -> void: call_deferred("run")

func run() -> void:
	AudioServer.set_bus_mute(0,true)
	game = load("res://scripts/main.gd").new()
	game.settings_path = prefix+"_preferences.json"
	game.progress_path = prefix+"_campaign.json"
	root.add_child(game)
	var entry: Button
	for child in game.menu.get_children():
		if child is Button and child.text == "Sound test": entry = child
	if not check(entry != null,"Title must expose the real Sound test entry"): return
	var before: Dictionary = game.state.to_dict().duplicate(true)
	var title_player: AudioStreamPlayer = game.music.player
	var title_stream: AudioStream = title_player.stream
	var title_position: float = title_player.get_playback_position()
	if not check(title_stream is AudioStreamMP3 and title_stream.resource_path == game.music.title_track and title_player.playing,"Title owns the intended Suno MP3 before Sound test opens"): return
	entry.pressed.emit()
	var screen = game.sound_test
	if not check(is_instance_valid(screen) and not game.menu_scroll.visible and not game.playing and game.level == null and paused,"Title opens the native screen without starting gameplay"): return
	if not check(game.music.player == title_player and title_player.stream == title_stream and title_player.get_playback_position() >= title_position and screen._preview_stream == null,"Opening must not autoplay, replace, restart or claim existing title music"): return
	title_stream = null
	if not check(screen.play_track(0) and game.music.level_tracks.size() == 8 and screen._tracks.size() == 9 and game.music.player.stream is AudioStreamMP3,"Screen preserves eight level tracks and appends the title on the same Music player"): return
	var recording: WeakRef = weakref(game.music.player.stream)
	if not check(screen.play_track(8) and game.music.player == title_player and title_player.stream is AudioStreamMP3 and title_player.stream.resource_path == game.music.title_track,"Explicit ninth entry previews the title on the same owner"): return
	screen._change_volume(0.37)
	var preferences = load("res://scripts/preferences.gd").new()
	if not check(preferences.load_file(game.settings_path) and is_equal_approx(preferences.values.music_volume,0.37) and is_equal_approx(game.settings.music_volume,0.37),"Explicit slider edit persists through the existing preferences path"): return
	var valid_settings: String = game.settings_path
	var saved_settings: String = FileAccess.get_file_as_string(valid_settings)
	game.settings_path = prefix+"_missing/preferences.json"
	screen._change_volume(0.41)
	if not check(screen._message.text.begins_with("SETTINGS SAVE FAILED") and FileAccess.get_file_as_string(valid_settings) == saved_settings,"Failed volume persistence must remain visible above the full-screen panel and preserve saved options"): return
	game.settings_path = valid_settings
	screen.request_back()
	if not check(game.sound_test == null and game.menu_scroll.visible and game.music.player.playing and not game.music.player.stream_paused and game.music.player.stream is AudioStreamMP3 and game.music.player.stream.resource_path == game.music.title_track and game.state.to_dict() == before,"Back retires preview, restores title audio and preserves the complete campaign state"): return
	await process_frame
	if not check(not is_instance_valid(screen),"Returned screen is actually freed"): return
	game.show_sound_test()
	if not check(game.sound_test.play_track(8),"Title preview starts before another-menu retirement"): return
	game.show_settings()
	if not check(game.sound_test == null and game.menu_scroll.visible and title_player.stream == null and not title_player.playing,"Another menu retires the preview screen and its owned audio"): return
	game.show_title()
	game.show_sound_test()
	if not check(game.sound_test.play_track(8),"Title preview starts before campaign retirement"): return
	game.start_campaign(1)
	await physics_frame
	await physics_frame
	if not check(game.playing and game.sound_test == null and game.music.player == title_player and title_player.stream is AudioStreamMP3 and title_player.stream.resource_path == game.music.level_tracks[0],"Starting a real campaign retires any title preview before gameplay"): return
	game.show_sound_test()
	if not check(game.playing and game.sound_test == null,"Gameplay cannot be covered by a sound-test overlay"): return
	await load("res://tests/recorded_audio_release.gd").stop(game)
	var retired_title: WeakRef = weakref(game.music.player.stream)
	game.music.stop()
	await load("res://tests/wall_clock_wait.gd").seconds(self,0.15)
	if not check(retired_title.get_ref() == null,"Stopped native title releases before Main retirement"): return
	game.free()
	paused = false
	await process_frame
	var deadline := Time.get_ticks_usec()+2000000
	while recording.get_ref() != null and Time.get_ticks_usec() < deadline:
		OS.delay_msec(2)
		await process_frame
	if not check(recording.get_ref() == null,"Native preview recording releases after retirement"): return
	for suffix in ["_preferences.json","_preferences.json.tmp","_campaign.json","_campaign.json.tmp"]:
		if FileAccess.file_exists(prefix+suffix): DirAccess.remove_absolute(prefix+suffix)
	print("PASS actual title sound-test entry, single music owner, volume persistence, back/settings/campaign retirement and gameplay guard")
	quit()

func check(okay: bool, message: String) -> bool:
	if not okay:
		push_error(message)
		quit(1)
	return okay
