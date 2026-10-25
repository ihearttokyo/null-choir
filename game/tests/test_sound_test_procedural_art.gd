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
	AudioServer.set_bus_mute(bus, true) # Fixture never claims audible listening.
	var screen = SoundTest.new()
	screen.bind_music(music)
	root.add_child(screen)
	screen.set_process(false)
	var player: AudioStreamPlayer = music.player
	var bus_count := AudioServer.get_bus_count()
	assert(player.stream == null)
	assert(screen._style.item_count == 3 and screen._style.focus_mode == Control.FOCUS_ALL)
	var seeds: Array = []
	var recording_refs: Array[WeakRef] = []
	for index in screen._tracks.size():
		assert(screen.play_track(index))
		recording_refs.append(weakref(player.stream))
		var seed: float = screen._art_material.get_shader_parameter("seed")
		assert(not seeds.has(seed))
		seeds.append(seed)
		assert(screen._visual_style == index % 3)
		assert(music.player == player and AudioServer.get_bus_count() == bus_count)
	assert(seeds.size() == 9) # Nine selections, not a claim of nine unique recordings.
	screen.set_visual_style(2)
	assert(screen._art_material.get_shader_parameter("visual_style") == 2)
	assert(screen._style.selected == 2)
	screen._update_art(0.1)
	assert(absf(screen._phase - player.get_playback_position() * 0.45) < 0.1) # Native mixer may advance between reads.
	assert(screen._art_energy == 0.0, "Muted bus must not invent visible audio amplitude")
	screen.toggle_playback()
	assert(player.stream_paused)
	var held_phase: float = screen._phase
	var held_energy: float = screen._art_energy
	screen._update_art(10.0)
	assert(screen._phase == held_phase and screen._art_energy == held_energy)
	screen.toggle_playback()
	screen.set_reduced_motion(true)
	screen._update_art(10.0)
	assert(screen._phase == 0.0 and screen._art_energy == 0.0)
	assert(screen._art_material.get_shader_parameter("phase") == 0.0)
	assert(screen._art_material.get_shader_parameter("energy") == 0.0)
	screen.hide()
	assert(not screen.is_processing() and not screen.is_processing_unhandled_input())
	assert(not player.playing and player.stream == null)
	screen.show()
	assert(screen.is_processing())
	screen.close()
	screen.free()
	music.stop()
	music.free()
	# CoreAudio can retain the last native MP3 playback after stop/free. Wait
	# for actual weakref release, bounded by the existing two-second guard;
	# do not hide a leak with a fixed delay or an unconditional pass.
	var deadline: int = Time.get_ticks_usec() + 2000000
	while not _recordings_released(recording_refs) and Time.get_ticks_usec() < deadline:
		OS.delay_msec(2)
		await process_frame
	assert(_recordings_released(recording_refs), "Native mixer must release every tested MP3 recording")
	AudioServer.set_bus_mute(bus, old_mute)
	print("PASS arranged procedural art: per-selection seeds, styles, real transport time, muted peak, paused/reduced freeze, hidden processing, same player; no listening/render acceptance")
	quit(0)

func _recordings_released(recordings: Array[WeakRef]) -> bool:
	for recording in recordings:
		if recording.get_ref() != null:
			return false
	return true
