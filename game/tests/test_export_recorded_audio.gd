extends SceneTree

const ExportAudio = preload("res://audio/export_audio_check.gd")
const WallClock = preload("res://tests/wall_clock_wait.gd")

func _initialize():
	AudioServer.set_bus_mute(0, true)
	call_deferred("run")

func run():
	var prefix = "user://export_audio_" + str(OS.get_process_id()) + "_" + str(Time.get_ticks_usec())
	if not OS.get_cmdline_user_args().has("--only-silence-red"):
		assert(DirAccess.make_dir_recursive_absolute(prefix) == OK)
		var files = ExportAudio.LEGACY_FILES.duplicate()
		for level in ExportAudio.LEVELS: files.append(level + ".mid")
		for file in files:
			assert(DirAccess.copy_absolute("res://audio/" + file, prefix.path_join(file)) == OK)
		if not require(ExportAudio.retained_sources_present(prefix), "Owned copies of every retained source must pass"): return
		for level in ExportAudio.LEVELS:
			var path = prefix.path_join(level + ".mid")
			assert(DirAccess.rename_absolute(path, path + ".hidden") == OK)
			var wrongly_accepted = ExportAudio.retained_sources_present(prefix)
			assert(DirAccess.rename_absolute(path + ".hidden", path) == OK)
			if not require(not wrongly_accepted, "INTENDED RED: missing retained MIDI must fail: " + level): return
	if AudioServer.get_bus_index("Music") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.get_bus_count()-1, "Music")
	var player = AudioStreamPlayer.new()
	player.bus = &"Music"
	root.add_child(player)
	var silent = load("res://tests/fixtures/silent_recording.mp3") as AudioStreamMP3
	silent.loop = true
	player.stream = silent
	player.play()
	await WallClock.seconds(self, 0.1)
	if not require(not await ExportAudio.decoded_pcm(self, player), "INTENDED RED: an active silent MP3 must fail decoded-audio validation"): return
	player.stop()
	player.stream = null
	if OS.get_cmdline_user_args().has("--only-silence-red"):
		player.free()
		await WallClock.seconds(self, 0.15)
		print("PASS silent MP3 is rejected by real decoded-audio validation")
		quit()
		return
	var pack = PCKPacker.new()
	assert(pack.pck_start(prefix + ".pck") == OK)
	var packed = "res://export_audio_pack_" + str(OS.get_process_id()) + "/"
	for file in ExportAudio.LEGACY_FILES:
		assert(pack.add_file(packed + "midi/" + file, "res://audio/" + file) == OK)
	for level in ExportAudio.LEVELS:
		assert(pack.add_file(packed + "midi/" + level + ".mid", "res://audio/" + level + ".mid") == OK)
		var config = ConfigFile.new()
		assert(config.load("res://audio/suno/" + level + ".mp3.import") == OK)
		var remap = FileAccess.open(prefix.path_join(level + ".remap"), FileAccess.WRITE)
		remap.store_string('[remap]\npath="' + packed + level + '.mp3str"\n')
		remap.close()
		assert(pack.add_file(packed + level + ".mp3.remap", prefix.path_join(level + ".remap")) == OK)
		assert(pack.add_file(packed + level + ".mp3str", config.get_value("remap", "path")) == OK)
	assert(pack.flush() == OK)
	assert(ProjectSettings.load_resource_pack(prefix + ".pck"))
	if not require(ExportAudio.retained_sources_present(packed + "midi"), "All eight retained MIDI sources must be readable from the actual PCK"): return
	var bus = AudioServer.get_bus_index("Music")
	var count = AudioServer.get_bus_effect_count(bus)
	var gain = AudioServer.get_bus_volume_db(bus)
	var mute = AudioServer.is_bus_mute(bus)
	for level in ExportAudio.LEVELS:
		var path = packed + level + ".mp3"
		if not require(not FileAccess.file_exists(path) and not ResourceLoader.has_cached(path), "Packed-only recording must not fall back to source or cache"): return
		var stream = load(path) as AudioStreamMP3
		stream.loop = true
		player.stream = stream
		player.play()
		if not require(await ExportAudio.decoded_pcm(self, player), "Actual packed recording must produce decoded PCM: " + level): return
		if not require(AudioServer.get_bus_effect_count(bus) == count and AudioServer.get_bus_volume_db(bus) == gain and AudioServer.is_bus_mute(bus) == mute and AudioServer.is_bus_mute(0), "Decoded validation must restore effects and user audio settings"): return
		player.stop()
		player.stream = null
		print("PACKED_EXPORT_PCM ", level)
	player.free()
	pack = null
	silent = null
	await WallClock.seconds(self, 0.15)
	print("PASS native packed eight-recording decoded PCM, silent-media rejection, all eight missing-MIDI controls and unchanged bus settings; not a full Mac app check")
	quit()

func require(ok: bool, detail: String) -> bool:
	if not ok:
		push_error(detail)
		quit(1)
	return ok
