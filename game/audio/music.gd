extends Node

# Gate fixture only; parent replaces this list with the eight authored level files.
@export var level_tracks: PackedStringArray = ["res://audio/gate.mid"]
const BANK_PATH := "res://audio/GeneralUser-GS.sf2"
# Load only the representative palette once. Add programs when final compositions use them.
const PROGRAMS := [0, 19, 30, 34, 81, 128 << 7]
var player: MidiPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index("Music") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, "Music")
	player = MidiPlayer.new()
	player.bus = &"Music"
	player.loop = true
	add_child(player)
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

func set_paused(paused: bool) -> void:
	player.set_paused(paused)

func stop() -> void:
	player.stop()
