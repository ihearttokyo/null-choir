extends Node

signal playback_started

@export var level_tracks: PackedStringArray = ["res://audio/suno/intake.mp3", "res://audio/suno/foundry.mp3", "res://audio/suno/processional.mp3", "res://audio/suno/reliquary.mp3", "res://audio/suno/nursery.mp3", "res://audio/suno/ossuary.mp3", "res://audio/suno/inversion.mp3", "res://audio/suno/heart.mp3"]
@export var title_track := "res://audio/title/the-restraint-turns.ogg"
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
	playback_started.emit()

func play_title() -> void:
	pressure = 0.0
	pressure_target = 0.0
	player.volume_db = -3.0
	if (player.playing or player.stream_paused) and player.stream is AudioStreamOggVorbis and player.stream.resource_path == title_track:
		player.stream_paused = false
		# A same-stream request transfers preview ownership without restarting.
		playback_started.emit()
		return
	stop()
	if not ResourceLoader.exists(title_track):
		push_error("Title recording is unavailable: " + title_track)
		return
	var recording := load(title_track) as AudioStreamOggVorbis
	if recording == null or recording.packet_sequence == null or not is_finite(recording.get_length()) or recording.get_length() <= 0:
		push_error("Title recording failed to load: " + title_track)
		return
	# Audible loop approval is pending; play the title cue once.
	recording.loop = false
	recording.loop_offset = 0.0
	player.stream = recording
	player.play()
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
	player.stop()
	player.stream = null
	player.stream_paused = false
	pressure = 0.0
	pressure_target = 0.0
	player.volume_db = -3.0
