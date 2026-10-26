extends SceneTree
## Actual Control signals in an isolated tree; not physical input or listening.
const Music = preload("res://audio/music.gd")
const SoundTest = preload("res://ui/resonance/sound_test.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var music = Music.new()
	root.add_child(music)
	var bus := AudioServer.get_bus_index("Music")
	var old_mute := AudioServer.is_bus_mute(bus)
	AudioServer.set_bus_mute(bus, true)
	var initial_effects := AudioServer.get_bus_effect_count(bus)
	var screen = SoundTest.new()
	var preference_edits: Array[bool] = []
	screen.reduced_motion_changed.connect(func(enabled: bool): preference_edits.append(enabled))
	screen.set_reduced_motion(true) # Main initializes the preference before ready.
	screen.bind_music(music)
	root.add_child(screen)
	screen.set_process(false)
	assert(screen._motion.button_pressed and preference_edits.is_empty())
	assert(screen._phase == 0.0 and screen._art_energy == 0.0 and screen._audio_bands == Vector3.ZERO)
	assert(screen._art_material.get_shader_parameter("audio_bands") == Vector3.ZERO)
	assert(music.player.stream == null and AudioServer.get_bus_effect_count(bus) == initial_effects)
	assert(screen._progress is ProgressBar, "Shipping progress remains display-only; no seek redesign")
	for control in [screen._previous, screen._play, screen._next, screen._volume, screen._style, screen._motion, screen._back]:
		assert(control.focus_mode == Control.FOCUS_ALL)
		assert(control.get_node(control.focus_next) != null and control.get_node(control.focus_previous) != null)
	screen._next.grab_focus()
	screen._motion.button_pressed = false # Real CheckButton property emits toggled.
	assert(preference_edits == [false] and not screen._reduced_motion)
	assert(screen._next.has_focus(), "Preference edits do not steal keyboard focus")
	screen.set_reduced_motion(true)
	assert(preference_edits == [false] and screen._motion.button_pressed)
	screen._motion.toggled.emit(true) # Duplicate state notification is not an edit.
	assert(preference_edits == [false])
	screen.hide()
	assert(not screen._art.is_visible_in_tree() and not screen.is_processing())
	assert(screen._analyzer == null and AudioServer.get_bus_effect_count(bus) == initial_effects)
	screen.close()
	screen.free()
	music.stop()
	music.free()
	AudioServer.set_bus_mute(bus, old_mute)
	print("PASS actual Control preference signal: silent pre-ready/programmatic init, user-only edits, shipping focus/progress and hidden cleanup; not physical input/listening")
	quit(0)
