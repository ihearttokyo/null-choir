extends Control

signal back_requested
signal music_volume_changed(linear_gain: float)
signal reduced_motion_changed(enabled: bool)

const Resonance = preload("resonance.gdshader")
const BONE := Color("eedfc0")
const BRASS := Color("a88551")
var _music_ref: WeakRef
var _preview_player_ref: WeakRef
var _preview_stream: AudioStream
var _tracks := PackedStringArray()
var _selected := 0
var _starting_preview := false
var _start_confirmed := false
var _reduced_motion := false
var _phase := 0.0
var _art_energy := 0.0
var _audio_bands := Vector3.ZERO
var _analyzer: AudioEffectSpectrumAnalyzer
var _visual_style := 0
var _style: OptionButton
var _art_caption: Label
var _status_clock := 0.0
var _content: VBoxContainer
var _body: BoxContainer
var _panel: PanelContainer
var _track_list: VBoxContainer
var _track_buttons: Array[Button] = []
var _art: ColorRect
var _art_material: ShaderMaterial
var _play: Button
var _previous: Button
var _next: Button
var _back: Button
var _motion: CheckButton
var _volume: HSlider
var _volume_label: Label
var _current: Label
var _status: Label
var _message: Label
var _progress: ProgressBar

func bind_music(music: Node) -> void:
	_detach_music()
	_tracks.clear()
	_selected = 0
	if is_instance_valid(music):
		var properties := PackedStringArray()
		for property in music.get_property_list():
			properties.append(property.name)
		if "player" in properties and "level_tracks" in properties and "title_track" in properties and music.has_method("play_title") and music.has_signal("playback_started") and music.has_method("play_level") and music.has_method("set_paused") and music.has_method("stop"):
			var catalog: Variant = music.get("level_tracks")
			if catalog is PackedStringArray:
				_music_ref = weakref(music)
				_tracks = catalog.duplicate()
				_tracks.append(music.get("title_track"))
				music.connect("playback_started", _on_playback_started)
	if is_node_ready():
		_rebuild_tracks()
		_sync_transport()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	set_reduced_motion(_reduced_motion) # Pre-ready preference initialization is silent.
	resized.connect(_layout)
	visibility_changed.connect(_on_visibility_changed)
	_rebuild_tracks()
	_layout()
	_sync_transport()
	_on_visibility_changed()
	_back.grab_focus()
	if not _track_buttons.is_empty() and not _track_buttons[0].disabled:
		_track_buttons[0].grab_focus()

func _owner() -> Node:
	return _music_ref.get_ref() as Node if _music_ref != null else null

func _player() -> AudioStreamPlayer:
	var music := _owner()
	if not is_instance_valid(music):
		return null
	var player: Variant = music.get("player")
	return player as AudioStreamPlayer if is_instance_valid(player) else null

func _owns_preview() -> bool:
	var player := _player()
	return is_instance_valid(player) and _preview_stream != null and _preview_player_ref != null and _preview_player_ref.get_ref() == player and player.stream == _preview_stream

func play_track(index: int) -> bool:
	var music := _owner()
	var player := _player()
	if not is_instance_valid(player) or not is_instance_valid(music) or index < 0 or index >= _tracks.size():
		_feedback("Track unavailable. Return to the title and reopen Sound test.")
		return false
	if not ResourceLoader.exists(_tracks[index]):
		_feedback("Recording unavailable: " + _track_name(index))
		return false
	_start_confirmed = false
	_starting_preview = true
	if index == _tracks.size() - 1:
		music.call("play_title")
	else:
		music.call("play_level", index)
	_starting_preview = false
	if not _start_confirmed or player.stream == null or player.stream.resource_path != _tracks[index]:
		_feedback("Recording could not start: " + _track_name(index))
		if is_node_ready():
			_sync_transport()
		return false
	_selected = index
	if _art_material != null:
		_art_material.set_shader_parameter("seed", float(index + 1))
		set_visual_style(index % 3)
	_preview_stream = player.stream
	_preview_player_ref = weakref(player)
	# Retire buffered samples only after a confirmed successful selection.
	_remove_analyzer()
	_zero_audio_signal()
	_ensure_analyzer()
	_feedback("")
	if is_node_ready():
		_sync_transport()
	return true

func toggle_playback() -> void:
	var player := _player()
	if _owns_preview() and (player.playing or player.stream_paused):
		_owner().call("set_paused", not player.stream_paused)
		_sync_transport()
	else:
		play_track(_selected)

func step_track(direction: int) -> void:
	if not _tracks.is_empty():
		play_track(posmod(_selected + direction, _tracks.size()))

func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	_phase = 0.0
	_zero_audio_signal()
	if _art_material != null:
		_art_material.set_shader_parameter("phase", _phase)
	if is_instance_valid(_art_caption):
		_art_caption.text = "Still pixel art · Audio response off" if enabled else "Live pixel art · Playback-time animation · Measured Music low/mid/high bands"
	if is_instance_valid(_motion):
		_motion.set_pressed_no_signal(enabled)

func _on_motion_toggled(enabled: bool) -> void:
	if enabled == _reduced_motion:
		return
	set_reduced_motion(enabled)
	reduced_motion_changed.emit(enabled)

func _stop_preview() -> void:
	_remove_analyzer()
	_zero_audio_signal()
	if _owns_preview():
		_owner().call("stop")
		_owner().call("set_paused", false)
	_preview_stream = null
	_preview_player_ref = null

func _on_playback_started() -> void:
	if _starting_preview:
		_start_confirmed = true
	else:
		# Another screen can start the same cached stream; identity alone cannot prove ownership.
		_preview_stream = null
		_preview_player_ref = null
		_remove_analyzer()
		_zero_audio_signal()

func _detach_music() -> void:
	_stop_preview()
	var music := _owner()
	if is_instance_valid(music) and music.is_connected("playback_started", _on_playback_started):
		music.disconnect("playback_started", _on_playback_started)
	_music_ref = null

func close() -> void:
	_detach_music()
	_tracks.clear()
	set_process(false)
	set_process_unhandled_input(false)
	if is_node_ready():
		hide()

func request_back() -> void:
	close()
	back_requested.emit()

func _exit_tree() -> void:
	_detach_music()
	_tracks.clear()
	if is_instance_valid(_art):
		_art.material = null
	_art_material = null

func _on_visibility_changed() -> void:
	var visible_now := is_visible_in_tree()
	set_process(visible_now)
	set_process_unhandled_input(visible_now)
	if not visible_now:
		_stop_preview()

func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		request_back()

func set_visual_style(index: int) -> void:
	_visual_style = clampi(index, 0, 2)
	if _art_material != null:
		_art_material.set_shader_parameter("visual_style", _visual_style)
	if is_instance_valid(_style):
		_style.select(_visual_style)

func _analyzer_location() -> Vector2i:
	if _analyzer == null:
		return Vector2i(-1, -1)
	for bus in range(AudioServer.get_bus_count()):
		for effect in range(AudioServer.get_bus_effect_count(bus)):
			if AudioServer.get_bus_effect(bus, effect) == _analyzer:
				return Vector2i(bus, effect)
	return Vector2i(-1, -1)

func _remove_analyzer() -> void:
	if _analyzer == null:
		return
	# Resolve by exact resource identity on every removal, never a stale index.
	for bus in range(AudioServer.get_bus_count()):
		for effect in range(AudioServer.get_bus_effect_count(bus) - 1, -1, -1):
			if AudioServer.get_bus_effect(bus, effect) == _analyzer:
				AudioServer.remove_bus_effect(bus, effect)
	_analyzer = null

func _ensure_analyzer() -> void:
	if not is_inside_tree() or not is_visible_in_tree() or not _owns_preview():
		return
	var bus := AudioServer.get_bus_index("Music")
	if bus < 0:
		return
	var location := _analyzer_location()
	if location.x == bus:
		return
	_remove_analyzer()
	_analyzer = AudioEffectSpectrumAnalyzer.new()
	_analyzer.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_1024
	_analyzer.buffer_length = 0.1
	AudioServer.add_bus_effect(bus, _analyzer)

func _zero_bands() -> void:
	_audio_bands = Vector3.ZERO
	if _art_material != null:
		_art_material.set_shader_parameter("audio_bands", _audio_bands)

func _normalized_band(stereo: Vector2) -> float:
	var magnitude := maxf(stereo.x, stereo.y)
	if not is_finite(magnitude) or magnitude <= 0.0:
		return 0.0
	# Fixed measured-magnitude dB normalization, not RMS or beat inference.
	var normalized := clampf((linear_to_db(maxf(magnitude, 0.000001)) + 60.0) / 60.0, 0.0, 1.0)
	return 0.0 if normalized <= 0.04 else (normalized - 0.04) / 0.96

func _effective_music_gain(bus: int) -> float:
	if bus < 0:
		return 0.0
	var gain := db_to_linear(AudioServer.get_bus_volume_db(bus)) * db_to_linear(AudioServer.get_bus_volume_db(0))
	return gain if is_finite(gain) and gain > 0.000001 else 0.0

func _zero_audio_signal() -> void:
	_art_energy = 0.0
	_zero_bands()
	if _art_material != null:
		_art_material.set_shader_parameter("energy", 0.0)

func _analyzer_instance(location: Vector2i) -> AudioEffectSpectrumAnalyzerInstance:
	return AudioServer.get_bus_effect_instance(location.x, location.y) as AudioEffectSpectrumAnalyzerInstance

func _update_art(delta: float) -> void:
	var player := _player()
	if not _owns_preview() or not is_instance_valid(player):
		_remove_analyzer()
		_zero_audio_signal()
		return
	_ensure_analyzer()
	var bus := AudioServer.get_bus_index("Music")
	var effective_gain := _effective_music_gain(bus)
	var muted: bool = effective_gain == 0.0 or AudioServer.is_bus_mute(0) or (bus >= 0 and AudioServer.is_bus_mute(bus))
	# Reduced neutral state overrides pause. Mute/gain-zero clears signal even
	# while paused, but never advances that paused transport's decorative phase.
	if _reduced_motion:
		_phase = 0.0
		if _art_material != null:
			_art_material.set_shader_parameter("phase", _phase)
		_zero_audio_signal()
		return
	if muted:
		_zero_audio_signal()
	if player.stream_paused:
		return # Normal unmuted pause holds exact phase AND measured signal.
	if not player.playing:
		_zero_audio_signal()
		return
	_phase = maxf(0.0, player.get_playback_position()) * 0.45
	if _art_material != null:
		_art_material.set_shader_parameter("phase", _phase)
	if muted:
		return # Muted PLAYING may animate; it never invents audio response.
	var location := _analyzer_location()
	if location.x < 0 or not AudioServer.is_bus_effect_enabled(location.x, location.y):
		_zero_audio_signal()
		return
	var instance := _analyzer_instance(location)
	if instance == null:
		_zero_audio_signal()
		return
	# The peak meter is already post-fader: never multiply its gain again.
	var peak := maxf(AudioServer.get_bus_peak_volume_left_db(bus, 0), AudioServer.get_bus_peak_volume_right_db(bus, 0))
	var target := clampf(db_to_linear(peak), 0.0, 1.0) if is_finite(peak) else 0.0
	_art_energy = lerpf(_art_energy, target, 1.0 - exp(-maxf(delta, 0.0) * 8.0))
	# Passive FFT samples before bus faders; apply Music+Master gain once.
	var measured := Vector3(
		_normalized_band(instance.get_magnitude_for_frequency_range(40, 250, AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_MAX) * effective_gain),
		_normalized_band(instance.get_magnitude_for_frequency_range(250, 2000, AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_MAX) * effective_gain),
		_normalized_band(instance.get_magnitude_for_frequency_range(2000, 12000, AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_MAX) * effective_gain))
	_audio_bands = _audio_bands.lerp(measured, 1.0 - exp(-maxf(delta, 0.0) * 9.0))
	if _art_material != null:
		_art_material.set_shader_parameter("energy", _art_energy)
		_art_material.set_shader_parameter("audio_bands", _audio_bands)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_update_art(delta)
	_status_clock += maxf(delta, 0.0)
	if _status_clock >= 0.2:
		_status_clock = 0.0
		_sync_transport()

func _change_volume(value: float) -> void:
	var bus := AudioServer.get_bus_index("Music")
	if bus < 0 or not is_finite(value):
		return
	var gain := clampf(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(gain))
	music_volume_changed.emit(gain)
	_sync_transport()

func _sync_transport() -> void:
	if _preview_stream != null and not _owns_preview():
		_preview_stream = null
		_preview_player_ref = null
		_remove_analyzer()
		_zero_audio_signal()
	var player := _player()
	var available := is_instance_valid(player) and not _tracks.is_empty()
	_play.disabled = not available
	_previous.disabled = not available
	_next.disabled = not available
	for i in _track_buttons.size():
		_track_buttons[i].disabled = not available or not ResourceLoader.exists(_tracks[i])
		_track_buttons[i].set_pressed_no_signal(i == _selected)
	_play.text = "Resume" if _owns_preview() and player.stream_paused else "Pause" if _owns_preview() and player.playing else "Play"
	_current.text = _track_name(_selected) if not _tracks.is_empty() else "Sound test unavailable"
	_progress.value = 0.0
	_status.text = "Music player unavailable" if not is_instance_valid(player) else "Stopped"
	if is_instance_valid(player) and player.stream != null:
		var duration := maxf(0.0, player.stream.get_length())
		var elapsed := clampf(player.get_playback_position(), 0.0, duration)
		var state := "Paused" if player.stream_paused else "Playing" if player.playing else "Stopped"
		var scope := "" if _owns_preview() else " — Music owner: " + player.stream.resource_path.get_file().get_basename().capitalize()
		_status.text = "%s%s  %s / %s" % [state, scope, _clock(elapsed), _clock(duration)]
		_progress.value = elapsed / duration if duration > 0.0 else 0.0
	var bus := AudioServer.get_bus_index("Music")
	_volume.editable = bus >= 0
	if bus >= 0:
		var gain := db_to_linear(AudioServer.get_bus_volume_db(bus))
		_volume.set_value_no_signal(clampf(gain, 0.0, 1.0))
		_volume_label.text = "Music volume: %d%%%s" % [roundi(gain * 100.0), " (bus muted)" if AudioServer.is_bus_mute(bus) else ""]
	else:
		_volume_label.text = "Music bus unavailable"

func _clock(seconds: float) -> String:
	var whole := int(seconds)
	return "%d:%02d" % [whole / 60, whole % 60]

func _track_name(index: int) -> String:
	var recording_name := _tracks[index].get_file().get_basename().capitalize()
	if index == _tracks.size() - 1:
		# This menu-role resource contains the selected Processional recording,
		# not an additional composition named after its technical file path.
		if _tracks[index] == "res://audio/title/title-suno.mp3":
			recording_name = "Processional"
		return "Title — " + recording_name
	return recording_name

func _feedback(text: String) -> void:
	if is_instance_valid(_message):
		_message.text = text

func _rebuild_tracks() -> void:
	for button in _track_buttons:
		_track_list.remove_child(button)
		button.queue_free()
	_track_buttons.clear()
	var group := ButtonGroup.new()
	for i in _tracks.size():
		var button := _button("%d  %s" % [i + 1, _track_name(i)], _track_list, play_track.bind(i))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_group = group
		button.tooltip_text = _tracks[i]
		button.set_pressed_no_signal(i == _selected)
		_track_buttons.append(button)
	var controls: Array[Control] = []
	for button in _track_buttons:
		controls.append(button)
	controls.append_array([_previous, _play, _next, _volume, _style, _motion, _back])
	for i in controls.size():
		controls[i].focus_next = controls[i].get_path_to(controls[(i + 1) % controls.size()])
		controls[i].focus_previous = controls[i].get_path_to(controls[posmod(i - 1, controls.size())])

func _button(text: String, parent: Node, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size.y = 32
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _label(text: String, parent: Node, font_size: int = 16) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _build_ui() -> void:
	theme = _make_theme()
	var background := Panel.new()
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stone := StyleBoxFlat.new()
	stone.bg_color = Color("100d14")
	background.add_theme_stylebox_override("panel", stone)
	add_child(background)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)
	_body = BoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(_body)
	_panel = PanelContainer.new()
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.size_flags_stretch_ratio = 0.7
	_body.add_child(_panel)
	var tracks_scroll := ScrollContainer.new()
	tracks_scroll.follow_focus = true
	tracks_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(tracks_scroll)
	_track_list = VBoxContainer.new()
	_track_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tracks_scroll.add_child(_track_list)
	_label("Resonance\nChamber", _track_list, 26)
	_label("Sound test", _track_list)
	_art = ColorRect.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_art.size_flags_stretch_ratio = 1.3
	_art_material = ShaderMaterial.new()
	_art_material.shader = Resonance
	_art.material = _art_material
	_art.resized.connect(_update_art_aspect)
	_body.add_child(_art)
	var transport := PanelContainer.new()
	_content.add_child(transport)
	var footer := VBoxContainer.new()
	transport.add_child(footer)
	_current = _label("", footer, 20)
	_status = _label("Stopped", footer, 14)
	_progress = ProgressBar.new()
	_progress.max_value = 1.0
	_progress.show_percentage = false
	_progress.accessibility_name = "Track progress"
	_progress.custom_minimum_size.y = 4
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(_progress)
	var controls := HFlowContainer.new()
	footer.add_child(controls)
	_previous = _button("Previous", controls, step_track.bind(-1))
	_play = _button("Play", controls, toggle_playback)
	_next = _button("Next", controls, step_track.bind(1))
	_style = OptionButton.new()
	_style.add_item("Garden")
	_style.add_item("Star Parade")
	_style.add_item("Orbit Play")
	_style.accessibility_name = "Visual style"
	_style.tooltip_text = "Original pixel garden with seeded stars and orbit variants. Motion follows playback time; low/mid/high response uses measured Music bands."
	_style.focus_mode = Control.FOCUS_ALL
	_style.item_selected.connect(set_visual_style)
	controls.add_child(_style)
	_motion = CheckButton.new()
	_motion.text = "Reduced motion"
	_motion.focus_mode = Control.FOCUS_ALL
	_motion.button_pressed = _reduced_motion
	_motion.toggled.connect(_on_motion_toggled)
	controls.add_child(_motion)
	_back = _button("Back", controls, request_back)
	_volume_label = _label("Music volume", footer, 14)
	_volume = HSlider.new()
	_volume.max_value = 1.0
	_volume.step = 0.01
	_volume.custom_minimum_size.y = 28
	_volume.focus_mode = Control.FOCUS_ALL
	_volume.accessibility_name = "Music volume"
	_volume.tooltip_text = "Music volume. Left and right adjust the existing Music bus."
	_volume.value_changed.connect(_change_volume)
	footer.add_child(_volume)
	_art_caption = _label("Live pixel art · Playback-time animation · Measured Music low/mid/high bands", footer, 11)
	_message = _label("", footer, 14)
	_message.add_theme_color_override("font_color", BONE)

func _layout() -> void:
	if not is_instance_valid(_body):
		return
	var portrait := size.x < 620.0
	_body.vertical = portrait
	_panel.custom_minimum_size = Vector2(0.0 if portrait else 220.0, 220.0 if portrait else 160.0)
	_art.custom_minimum_size = Vector2(0.0, 220.0 if portrait else 160.0)
	_content.custom_minimum_size.y = size.y

func _update_art_aspect() -> void:
	_art_material.set_shader_parameter("aspect", _art.size.x / maxf(1.0, _art.size.y))

func _make_theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 16
	result.set_color("font_color", "Label", BONE)
	for type in ["Button", "CheckButton"]:
		result.set_color("font_color", type, BONE)
		result.set_color("font_hover_color", type, Color.WHITE)
		result.set_color("font_focus_color", type, Color.WHITE)
		result.set_color("font_disabled_color", type, Color("93877a"))
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var box := StyleBoxFlat.new()
			box.bg_color = Color("381a20") if state == "pressed" else Color("161219")
			box.border_color = BONE if state == "focus" else BRASS
			box.set_border_width_all(2 if state == "focus" else 1)
			box.content_margin_left = 10
			box.content_margin_right = 10
			box.content_margin_top = 5
			box.content_margin_bottom = 5
			if state == "focus":
				box.draw_center = false
			result.set_stylebox(state, type, box)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("100d14")
	panel.border_color = BRASS
	panel.set_border_width_all(1)
	panel.set_content_margin_all(10)
	result.set_stylebox("panel", "PanelContainer", panel)
	return result
