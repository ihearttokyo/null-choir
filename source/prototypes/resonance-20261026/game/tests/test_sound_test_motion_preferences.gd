extends SceneTree
const Preferences = preload("res://scripts/preferences.gd")

func _initialize() -> void:
	var prefs = Preferences.new()
	if not expect(prefs.to_dict().version == 3 and prefs.values.size() == 9, "Motion preferences invariant: line 6"): return
	if not expect(prefs.values.sound_test_reduced_motion == false, "Motion preferences invariant: line 7"): return
	var v1 = {"version":1,"values":{"sensitivity":1.7,"invert_y":true,"head_bob":false,"camera_shake":false,"auto_aim":true,"music_volume":0.25,"effects_volume":0.75},"bindings":Preferences.default_bindings()}
	v1.bindings.erase("survey")
	var v2: Dictionary = v1.duplicate(true)
	v2.version = 2
	v2.values.reduced_damage_flashes = true
	v2.bindings.survey = Preferences.default_bindings().survey
	var path = "user://motion_preferences_"+str(Time.get_ticks_usec())+".json"
	for historical in [v1,v2]:
		var raw = JSON.stringify(historical)
		var file = FileAccess.open(path,FileAccess.WRITE)
		file.store_string(raw);file.close()
		if not expect(prefs.load_file(path), "Motion preferences invariant: line 19"): return
		if not expect(FileAccess.get_file_as_string(path) == raw and not FileAccess.file_exists(path+".tmp"),"Migration must not write historical file or temp"): return
		if not expect(prefs.values.sound_test_reduced_motion == false and prefs.values.sensitivity == 1.7, "Motion preferences invariant: line 21"): return
		if not expect(JSON.parse_string(JSON.stringify(prefs.bindings.survey)) == JSON.parse_string(JSON.stringify(Preferences.default_bindings().survey)), "Motion preferences invariant: line 22"): return
		var frozen: Dictionary = prefs.to_dict()
		for field in ["sound_test_reduced_motion","reduced_damage_flashes"]:
			if historical.version == 2 and field == "reduced_damage_flashes": continue
			var invalid: Dictionary = historical.duplicate(true)
			invalid.values[field] = false
			if not expect(not prefs.from_dict(invalid) and prefs.to_dict() == frozen,"Historical schemas must reject future options"): return
	prefs.values.sound_test_reduced_motion = true
	if not expect(prefs.save(path) == OK, "Motion preferences invariant: line 30"): return
	var serialized: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not expect(serialized.version == 3 and serialized.values.size() == 9 and serialized.values.sound_test_reduced_motion == true, "Motion preferences invariant: line 32"): return
	var restored = Preferences.new()
	if not expect(restored.load_file(path) and restored.values.sound_test_reduced_motion == true, "Motion preferences invariant: line 34"): return
	var frozen: Dictionary = restored.to_dict()
	for bad in [0,1,"true",null,[],{}]:
		var invalid: Dictionary = serialized.duplicate(true)
		invalid.values.sound_test_reduced_motion = bad
		if not expect(not restored.from_dict(invalid) and restored.to_dict() == frozen, "Motion preferences invariant: line 39"): return
	var missing: Dictionary = serialized.duplicate(true)
	missing.values.erase("sound_test_reduced_motion")
	if not expect(not restored.from_dict(missing) and restored.to_dict() == frozen, "Motion preferences invariant: line 42"): return
	DirAccess.remove_absolute(path)
	print("PASS strict preferences v3: genuine v1/v2 memory-only migration, bool validation, exact nine-option roundtrip; no Main/UI claim")
	quit(0)

func expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
