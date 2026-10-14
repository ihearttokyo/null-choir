extends SceneTree

func _initialize(): call_deferred("run")

func run():
	var prefix = "user://recorded_pack_" + str(Time.get_ticks_usec())
	var remap = FileAccess.open(prefix + ".remap", FileAccess.WRITE)
	remap.store_string('[remap]\npath="res://recorded_pack_fixture/intake.mp3str"\n')
	remap.close()
	var imported = ConfigFile.new()
	assert(imported.load("res://audio/suno/intake.mp3.import") == OK)
	var pack = PCKPacker.new()
	assert(pack.pck_start(prefix + ".pck") == OK)
	assert(pack.add_file("res://recorded_pack_fixture/intake.mp3.remap", prefix + ".remap") == OK)
	assert(pack.add_file("res://recorded_pack_fixture/intake.mp3str", imported.get_value("remap", "path")) == OK)
	assert(pack.flush() == OK)
	assert(ProjectSettings.load_resource_pack(prefix + ".pck"))
	var path = "res://recorded_pack_fixture/intake.mp3"
	assert(not FileAccess.file_exists(path), "The packed original MP3 source is absent")
	assert(ResourceLoader.exists(path), "Resource-aware export validation must find the remapped MP3")
	var stream = load(path)
	assert(stream is AudioStreamMP3 and stream.get_length() > 180)
	stream = null
	pack = null
	DirAccess.remove_absolute(prefix + ".remap")
	# The mounted pack stays open until process exit; retain it in isolated fixture data.
	print("PASS native resource-only PCK resolves the actual compressed MP3 without its original file")
	quit()
