extends SceneTree

const Music = preload("res://audio/music.gd")
const SoundTest = preload("res://ui/resonance/sound_test.gd")

var music
var screen
var bus: int = -1
var old_mute: bool = false
var recording_refs: Array[WeakRef] = []
var failures: int = 0

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func require(ok: bool, message: String = "Existing procedural-art invariant") -> bool:
	if not ok:
		failures += 1
		push_error(message)
	return ok

func run() -> void:
	music = Music.new()
	root.add_child(music)
	bus = AudioServer.get_bus_index("Music")
	old_mute = AudioServer.is_bus_mute(bus)
	AudioServer.set_bus_mute(bus, true) # Fixture never claims audible listening.
	screen = SoundTest.new()
	screen.bind_music(music)
	root.add_child(screen)
	screen.set_process(false)
	var player: AudioStreamPlayer = music.player
	var bus_count := AudioServer.get_bus_count()
	if not require(player.stream == null): await finish(); return
	if not require(screen._style.item_count == 3 and screen._style.focus_mode == Control.FOCUS_ALL): await finish(); return
	var seeds: Array = []
	for index in screen._tracks.size():
		if not require(screen.play_track(index)): await finish(); return
		recording_refs.append(weakref(player.stream))
		var seed: float = screen._art_material.get_shader_parameter("seed")
		if not require(not seeds.has(seed)): await finish(); return
		seeds.append(seed)
		if not require(screen._visual_style == index % 3): await finish(); return
		if not require(music.player == player and AudioServer.get_bus_count() == bus_count): await finish(); return
	if not require(seeds.size() == 9): await finish(); return # Nine selections, not a claim of nine unique recordings.
	screen.set_visual_style(2)
	if not require(screen._art_material.get_shader_parameter("visual_style") == 2): await finish(); return
	if not require(screen._style.selected == 2): await finish(); return
	screen._update_art(0.1)
	if not require(absf(screen._phase - player.get_playback_position() * 0.45) < 0.1): await finish(); return # Native mixer may advance between reads.
	if not require(screen._art_energy == 0.0, "Muted bus must not invent visible audio amplitude"): await finish(); return
	screen.toggle_playback()
	if not require(player.stream_paused): await finish(); return
	var held_phase: float = screen._phase
	var held_energy: float = screen._art_energy
	screen._update_art(10.0)
	if not require(screen._phase == held_phase and screen._art_energy == held_energy): await finish(); return
	screen.toggle_playback()
	screen.set_reduced_motion(true)
	screen._update_art(10.0)
	if not require(screen._phase == 0.0 and screen._art_energy == 0.0): await finish(); return
	if not require(screen._art_material.get_shader_parameter("phase") == 0.0): await finish(); return
	if not require(screen._art_material.get_shader_parameter("energy") == 0.0): await finish(); return
	screen.hide()
	if not require(not screen.is_processing() and not screen.is_processing_unhandled_input()): await finish(); return
	if not require(not player.playing and player.stream == null): await finish(); return
	screen.show()
	if not require(screen.is_processing()): await finish(); return
	await finish()

func finish() -> void:
	if is_instance_valid(screen): screen.close(); screen.free()
	screen = null
	if is_instance_valid(music): music.stop(); music.free()
	music = null
	var deadline: int = Time.get_ticks_usec()+2000000
	while not _recordings_released(recording_refs) and Time.get_ticks_usec()<deadline:
		OS.delay_msec(2)
		await process_frame
	require(_recordings_released(recording_refs),"Native mixer must release every tested MP3 recording")
	if bus>=0: AudioServer.set_bus_mute(bus,old_mute)
	call_deferred("terminal")

func terminal() -> void:
	await process_frame
	await process_frame
	if failures==0: print("PASS arranged procedural art: per-selection seeds, styles, real transport time, muted peak, paused/reduced freeze, hidden processing, same player; no listening/render acceptance")
	quit(0 if failures==0 else 1)

func _recordings_released(recordings: Array[WeakRef]) -> bool:
	for recording in recordings:
		if recording.get_ref() != null:
			return false
	return true
