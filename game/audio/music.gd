extends Node

signal playback_started

@export var level_tracks: PackedStringArray = ["res://audio/suno/intake.mp3", "res://audio/suno/foundry.mp3", "res://audio/suno/processional.mp3", "res://audio/suno/reliquary.mp3", "res://audio/suno/nursery.mp3", "res://audio/suno/ossuary.mp3", "res://audio/suno/inversion.mp3", "res://audio/suno/heart.mp3"]
@export var title_track := "res://audio/title/title-suno.mp3"
@export var interlude_track := "res://audio/title/interlude-suno.mp3"
# Role copies retain exact selected source bytes, not additional compositions.
# Distinct resource paths keep campaign lifetime/loop state separate from menus.
var playback_context := ""
var player: AudioStreamPlayer
var pressure := 0.0
var pressure_target := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index("Music") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, "Music")
	player = AudioStreamPlayer.new()
	player.bus = &"Music"
	player.volume_db = -3.0
	add_child(player)

func play_level(index: int) -> void:
	if index < 0 or index >= level_tracks.size() or not ResourceLoader.exists(level_tracks[index]):
		push_error("Music level is unavailable: %d" % index)
		return
	var recording := load(level_tracks[index]) as AudioStreamMP3
	if recording == null or recording.get_length() <= 0:
		push_error("Campaign recording failed to load: %d" % index)
		return
	recording.loop = true
	player.stream = recording
	player.stream_paused = false
	player.play()
	playback_context = "campaign"
	playback_started.emit()

func play_title() -> void:
	_play_menu_recording(title_track, "title")

func play_interlude() -> void:
	_play_menu_recording(interlude_track, "interlude")

func _play_menu_recording(path: String, context: String) -> void:
	pressure = 0.0
	pressure_target = 0.0
	player.volume_db = -3.0
	if playback_context == context and (player.playing or player.stream_paused) and player.stream is AudioStreamMP3 and player.stream.resource_path == path:
		player.stream_paused = false
		# A same-role request transfers preview ownership without restarting.
		playback_started.emit()
		return
	stop()
	if not ResourceLoader.exists(path):
		push_error("Menu recording is unavailable: " + path)
		return
	var recording := load(path) as AudioStreamMP3
	if recording == null or not is_finite(recording.get_length()) or recording.get_length() <= 0:
		push_error("Menu recording failed to load: " + path)
		return
	# Reuse the selected offline Suno bytes. Menus play once, without an
	# unaudited infinite loop; play_level explicitly restores campaign looping.
	recording.loop = false
	recording.loop_offset = 0.0
	player.stream = recording
	player.play()
	playback_context = context
	playback_started.emit()

func set_pressure(value: float) -> void:
	pressure_target = clampf(value, 0.0, 1.0) if is_finite(value) else 0.0

func _process(delta: float) -> void:
	if player == null or player.stream_paused or pressure == pressure_target:
		return
	var rate := 4.0 if pressure_target > pressure else 1.0
	pressure = move_toward(pressure, pressure_target, maxf(0.0, delta) * rate)
	# A stereo recording cannot reveal separate stems; keep the lift below its authored peak.
	player.volume_db = lerpf(-3.0, 0.0, pressure)

func set_paused(paused: bool) -> void:
	player.stream_paused = paused

func stop() -> void:
	playback_context = ""
	player.stop()
	player.stream = null
	player.stream_paused = false
	pressure = 0.0
	pressure_target = 0.0
	player.volume_db = -3.0
