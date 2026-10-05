extends Node

@export var level_tracks: PackedStringArray = ["res://audio/intake.mid","res://audio/foundry.mid","res://audio/processional.mid","res://audio/reliquary.mid","res://audio/nursery.mid","res://audio/ossuary.mid","res://audio/inversion.mid","res://audio/heart.mid"]
const BANK_PATH := "res://audio/GeneralUser-GS.sf2"
# Load the authored campaign palette once; bank survives level changes.
const PROGRAMS := [0, 19, 30, 34, 81, 128 << 7]
# Expression attenuates the authored mix; the organ remains the constant anchor.
const QUIET_EXPRESSION := {0: 0.35, 1: 0.8, 3: 0.6, 9: 0.55}
var player: MidiPlayer
var pressure := 0.0
var pressure_target := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index("Music") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, "Music")
	player = MidiPlayer.new()
	player.bus = &"Music"
	player.loop = true
	add_child(player)
	player.looped.connect(_apply_pressure)
	if not FileAccess.file_exists(BANK_PATH):
		push_error("Packaged soundbank is missing")
		return
	var parsed := SoundFont.new().read_file(BANK_PATH)
	if parsed.error != OK or parsed.data == null:
		push_error("Packaged soundbank failed to load")
		return
	player.bank = Bank.new()
	player.bank.read_soundfont(parsed.data, PROGRAMS)

func play_level(index: int) -> void:
	if player.bank == null or index < 0 or index >= level_tracks.size() or not FileAccess.file_exists(level_tracks[index]):
		push_error("Music level is unavailable: %d" % index)
		return
	player.file = level_tracks[index]
	player.play()
	_apply_pressure()

func set_pressure(value: float) -> void:
	pressure_target = clampf(value, 0.0, 1.0) if is_finite(value) else 0.0

func _process(delta: float) -> void:
	if player == null or player.playback_paused or pressure == pressure_target:
		return
	var rate := 4.0 if pressure_target > pressure else 1.0
	pressure = move_toward(pressure, pressure_target, maxf(0.0, delta) * rate)
	_apply_pressure()

func _apply_pressure() -> void:
	for number in QUIET_EXPRESSION:
		var channel := player.channel_status[number]
		channel.expression = lerpf(QUIET_EXPRESSION[number], 1.0, pressure)
		player._apply_channel_volume(channel)

func set_paused(paused: bool) -> void:
	player.set_paused(paused)

func stop() -> void:
	player.stop()
