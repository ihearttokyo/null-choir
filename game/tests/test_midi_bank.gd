extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	const PATH := "res://audio/GeneralUser-GS.sf2"
	assert(FileAccess.get_sha256(PATH) == "9575028c7a1f589f5770fccc8cff2734566af40cd26ed836944e9a5152688cfe")
	var bank := Bank.new()
	bank.read_soundfont(SoundFont.new().read_file(PATH).data, [81])
	# The pinned SF2 declares two overlapping Saw Lead zones at C5, not nine.
	var actual: int = bank.get_preset(81).instruments[72].size()
	print("BANK_ZONE_LAYERS: actual=", actual, " declared=2")
	assert(actual == 2, "preset and instrument key ranges must intersect")
	bank = null
	print("PASS MIDI_BANK_GREEN: preset-zone intersection")
	quit()
