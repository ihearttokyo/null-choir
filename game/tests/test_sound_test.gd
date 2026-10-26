extends SceneTree

const Music = preload("res://audio/music.gd")
const SoundTest = preload("res://ui/resonance/sound_test.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var music = Music.new()
	root.add_child(music)
	var bus := AudioServer.get_bus_index("Music")
	var old_mute := AudioServer.is_bus_mute(bus)
	var old_gain := AudioServer.get_bus_volume_db(bus)
	AudioServer.set_bus_mute(bus, true)
	AudioServer.set_bus_volume_db(bus, -12.0)
	var player: AudioStreamPlayer = music.player
	var bus_count := AudioServer.get_bus_count()
	var initial_effects := AudioServer.get_bus_effect_count(bus)
	var screen = SoundTest.new()
	screen.bind_music(music)
	root.add_child(screen)
	screen.set_process(false)
	assert(player.stream == null, "Opening must not start or replace music")
	assert(screen._analyzer == null and AudioServer.get_bus_effect_count(bus) == initial_effects)
	assert(music.level_tracks.size() == 8)
	assert(screen._tracks.size() == 9)
	for i in 8:
		assert(screen._track_buttons[i].text == "%d  %s" % [i + 1, music.level_tracks[i].get_file().get_basename().capitalize()])
		assert(screen._track_buttons[i].focus_mode == Control.FOCUS_ALL)
		assert(screen._track_buttons[i].get_node(screen._track_buttons[i].focus_next) != null)
		var old_analyzer: AudioEffectSpectrumAnalyzer = screen._analyzer
		assert(screen.play_track(i))
		assert(screen._analyzer != null and screen._analyzer != old_analyzer, "Successful selection retires buffered spectrum")
		assert(screen._audio_bands == Vector3.ZERO and screen._art_energy == 0.0)
		assert(AudioServer.get_bus_effect_count(bus) == initial_effects + 1)
		assert(player.stream.resource_path == music.level_tracks[i])
		assert(player.playing and player.stream is AudioStreamMP3)
		assert((player.stream as AudioStreamMP3).loop)
		assert(music.player == player and AudioServer.get_bus_count() == bus_count)
		assert(AudioServer.get_bus_volume_db(bus) == -12.0 and AudioServer.is_bus_mute(bus))
	screen.toggle_playback()
	assert(player.stream_paused)
	screen._sync_transport()
	assert(screen._status.text.begins_with("Paused"))
	screen.toggle_playback()
	assert(not player.stream_paused)
	screen.step_track(1)
	assert(screen._selected == 8)
	assert(screen._track_buttons[8].text == "9  Title — Processional")
	assert(player.stream is AudioStreamMP3 and player.stream.resource_path == music.title_track)
	assert(player.playing and not player.stream.loop and player.stream.loop_offset == 0.0)
	assert(music.player == player and AudioServer.get_bus_count() == bus_count)
	assert(AudioServer.get_bus_volume_db(bus) == -12.0 and AudioServer.is_bus_mute(bus))
	var title_stream: AudioStream = player.stream
	assert(screen.play_track(8) and player.stream == title_stream, "Already-playing title must confirm preview ownership")
	screen.toggle_playback()
	assert(player.stream_paused)
	assert(screen.play_track(8) and player.stream == title_stream and not player.stream_paused)
	screen.step_track(1)
	assert(screen._selected == 0)
	screen.step_track(-1)
	assert(screen._selected == 8)
	title_stream = null
	var stream: AudioStream = player.stream
	assert(not screen.play_track(-1) and player.stream == stream)
	var real_track: String = screen._tracks[0]
	screen._tracks[0] = "res://missing-sound-test-recording.mp3"
	assert(not screen.play_track(0) and player.stream == stream)
	screen._tracks[0] = real_track
	var selected_before: int = screen._selected
	var analyzer_before: AudioEffectSpectrumAnalyzer = screen._analyzer
	var bands_before: Vector3 = screen._audio_bands
	var energy_before: float = screen._art_energy
	var incompatible := "res://audio/effects/death.wav"
	assert(ResourceLoader.exists(incompatible), "Wrong-type resource must exist to reach Music's real loader")
	screen._tracks[0] = incompatible
	music.level_tracks[0] = incompatible
	print("EXPECTED_NEGATIVE: Music rejects one existing non-MP3 recording")
	assert(not screen.play_track(0))
	assert(player.stream == stream and player.playing and screen._selected == selected_before)
	assert(screen._analyzer == analyzer_before and screen._audio_bands == bands_before and screen._art_energy == energy_before, "Failed replacement preserves the active preview signal")
	assert(screen._message.text.contains("could not start"))
	screen._tracks[0] = real_track
	music.level_tracks[0] = real_track
	var real_title: String = music.title_track
	screen._tracks[8] = "res://missing-sound-test-title.ogg"
	assert(not screen.play_track(8) and player.stream == stream)
	screen._tracks[8] = incompatible
	music.title_track = incompatible
	print("EXPECTED_NEGATIVE: Music rejects one existing non-MP3 title")
	assert(not screen.play_track(8))
	assert(player.stream == null and not player.playing and screen._selected == selected_before)
	assert(screen._message.text.contains("could not start") and screen._preview_stream == null)
	screen._tracks[8] = real_title
	music.title_track = real_title
	assert(screen.play_track(8))
	stream = null
	screen.set_reduced_motion(true)
	screen._process(1.0)
	assert(screen._phase == 0.0)
	assert(screen._art_material.get_shader_parameter("phase") == 0.0)
	screen._change_volume(0.25)
	assert(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(bus)), 0.25))
	assert(AudioServer.is_bus_mute(bus))
	screen.hide()
	assert(player.stream == null and not player.playing)
	assert(not screen._art.is_visible_in_tree() and screen._analyzer == null)
	assert(screen._audio_bands == Vector3.ZERO and screen._art_energy == 0.0)
	screen.show()
	assert(screen.play_track(0))
	music.stop()
	screen._sync_transport()
	assert(screen._preview_stream == null, "External stop releases the retained preview resource")
	assert(screen._analyzer == null and screen._audio_bands == Vector3.ZERO and screen._art_energy == 0.0)
	assert(screen.play_track(0))
	music.play_level(0)
	screen.close()
	assert(player.stream != null and player.playing, "External same-track start relinquishes preview ownership")
	assert(screen._music_ref == null and screen._preview_stream == null)
	assert(screen._analyzer == null and AudioServer.get_bus_effect_count(bus) == initial_effects)
	screen.bind_music(music)
	assert(screen.play_track(8))
	music.play_title()
	screen.close()
	assert(player.stream is AudioStreamMP3 and player.playing, "External same-title request relinquishes preview ownership")
	screen.close()
	screen.free()
	music.stop()
	var unavailable = SoundTest.new()
	root.add_child(unavailable)
	assert(not unavailable.play_track(0))
	assert(unavailable._play.disabled)
	var not_ready = Music.new()
	unavailable.bind_music(not_ready)
	assert(not unavailable.play_track(0), "Existing owner without a ready player is unavailable")
	not_ready.free()
	unavailable.bind_music(music)
	assert(unavailable.play_track(8))
	var returns: Array[int] = [0]
	unavailable.back_requested.connect(func(): returns[0] += 1)
	unavailable.request_back()
	assert(returns[0] == 1 and player.stream == null)
	unavailable.bind_music(music)
	assert(unavailable.play_track(8))
	unavailable.free()
	assert(player.stream == null, "Freeing a preview screen stops its owned recording")
	unavailable = SoundTest.new()
	unavailable.bind_music(music)
	root.add_child(unavailable)
	assert(unavailable.play_track(0))
	var released_recording: WeakRef = weakref(player.stream)
	music.player.free()
	unavailable._sync_transport()
	assert(unavailable._play.disabled and unavailable._previous.disabled and unavailable._next.disabled)
	assert(unavailable._analyzer == null and unavailable._audio_bands == Vector3.ZERO and unavailable._art_energy == 0.0)
	assert(not unavailable.play_track(0), "Freed player with live Music owner is unavailable")
	music.free()
	assert(not unavailable.play_track(0))
	unavailable.free()
	var deadline: int = Time.get_ticks_usec()+2000000
	while released_recording.get_ref() != null and Time.get_ticks_usec() < deadline:
		OS.delay_msec(2)
		await process_frame
	assert(released_recording.get_ref() == null, "Native mixer must release the last recording")
	AudioServer.set_bus_volume_db(bus, old_gain)
	AudioServer.set_bus_mute(bus, old_mute)
	print("PASS native sound-test assertions; listening and visual acceptance remain separate")
	quit()
