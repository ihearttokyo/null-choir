extends SceneTree

const Preferences = preload("res://scripts/preferences.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var prefs = Preferences.new()
	if not expect(prefs.values.get("reduced_damage_flashes") == false,"Intended RED: reduced damage flashes have an independent false default"): return
	var legacy = {"version":1,"values":{"sensitivity":2.35,"invert_y":true,"head_bob":false,"camera_shake":false,"auto_aim":true,"music_volume":0.23,"effects_volume":0.71},"bindings":Preferences.default_bindings()}
	legacy.bindings.fire = [{"kind":"key","code":KEY_PRINT,"shift":true,"alt":true,"ctrl":true,"meta":true},{"kind":"axis","code":JOY_AXIS_TRIGGER_RIGHT,"sign":1}]
	legacy.bindings.interact = [{"kind":"mouse","code":MOUSE_BUTTON_RIGHT},{"kind":"joy","code":JOY_BUTTON_X}]
	var original: Dictionary = legacy.duplicate(true)
	if not expect(prefs.from_dict(legacy),"Complete v1 options and rebound desktop/gamepad bindings migrate"): return
	var expected: Dictionary = legacy.values.duplicate()
	expected.reduced_damage_flashes = false
	if not expect(prefs.values == expected and prefs.bindings == legacy.bindings,"Migration preserves every old value and chord; camera shake does not choose flash comfort"): return
	var current: Dictionary = prefs.to_dict()
	if not expect(current.version == 2 and current.values.size() == 8,"Only complete v2 documents are serialized"): return
	legacy.values.sensitivity = 4.0
	legacy.bindings.fire[0].ctrl = false
	if not expect(prefs.to_dict() == current,"Successful migration does not retain caller-owned dictionary aliases"): return
	var exported: Dictionary = prefs.to_dict()
	exported.values.head_bob = true
	exported.bindings.fire[0].alt = false
	if not expect(prefs.to_dict() == current,"Serialized dictionaries do not alias live options or nested bindings"): return
	# JSON decodes integer binding codes as floats; compare both primitive documents in that representation.
	var restored = Preferences.new()
	if not expect(restored.from_dict(JSON.parse_string(JSON.stringify(current))) and JSON.parse_string(JSON.stringify(restored.to_dict())) == JSON.parse_string(JSON.stringify(current)),"Migrated v2 survives a real JSON roundtrip"): return
	var no_survey: Dictionary = original.duplicate(true)
	no_survey.bindings.erase("survey")
	if not expect(restored.from_dict(no_survey),"Older v1 without the additive survey action remains supported"): return
	var expected_bindings: Dictionary = no_survey.bindings.duplicate(true)
	expected_bindings.survey = Preferences.default_bindings().survey
	if not expect(restored.values == expected and restored.bindings == expected_bindings and not no_survey.bindings.has("survey"),"Survey migration adds only its default, without mutating the legacy input"): return
	for version in [0,3,1.5,"1",true,NAN,INF]:
		var invalid: Dictionary = current.duplicate(true)
		invalid.version = version
		if not rejected(prefs,invalid,current,"unsupported version "+str(version)): return
	for version in [1,2]:
		var valid: Dictionary = original if version == 1 else current
		for mutation in ["root_extra","root_missing","options_type","options_extra","options_missing","options_unknown","nonfinite","range","controls_type","controls_extra","controls_missing","controls_unknown","controls_partial","duplicate_family","binding_bool","binding_extra"]:
			var invalid: Dictionary = valid.duplicate(true)
			match mutation:
				"root_extra": invalid.extra = true
				"root_missing": invalid.erase("bindings")
				"options_type": invalid.values = []
				"options_extra": invalid.values.extra = true
				"options_missing": invalid.values.erase("head_bob")
				"options_unknown":
					invalid.values.erase("head_bob")
					invalid.values.unknown = false
				"nonfinite": invalid.values.sensitivity = INF
				"range": invalid.values.effects_volume = -0.1
				"controls_type": invalid.bindings = []
				"controls_extra": invalid.bindings.extra = []
				"controls_missing": invalid.bindings.erase("fire")
				"controls_unknown":
					invalid.bindings.erase("fire")
					invalid.bindings.unknown = []
				"controls_partial": invalid.bindings.fire = []
				"duplicate_family": invalid.bindings.fire[1] = invalid.bindings.fire[0].duplicate()
				"binding_bool": invalid.bindings.fire[0].ctrl = 1
				"binding_extra": invalid.bindings.fire[0].extra = false
			if not rejected(prefs,invalid,current,"v%d %s" % [version,mutation]): return
		for option in valid.values:
			var invalid: Dictionary = valid.duplicate(true)
			invalid.values[option] = 0 if valid.values[option] is bool else NAN
			if not rejected(prefs,invalid,current,"v%d wrong type/nonfinite %s" % [version,option]): return
	var missing_new: Dictionary = current.duplicate(true)
	missing_new.values.erase("reduced_damage_flashes")
	if not rejected(prefs,missing_new,current,"v2 must not silently supply a missing new option"): return
	var extra_new: Dictionary = original.duplicate(true)
	extra_new.values.reduced_damage_flashes = false
	if not rejected(prefs,extra_new,current,"v1 must retain its exact seven-option schema"): return
	var missing_survey: Dictionary = current.duplicate(true)
	missing_survey.bindings.erase("survey")
	if not rejected(prefs,missing_survey,current,"v2 must not silently supply missing bindings"): return
	for option in ["sensitivity","music_volume","effects_volume"]:
		for value in [-INF,INF,-1.0,5.0]:
			var invalid: Dictionary = current.duplicate(true)
			invalid.values[option] = value
			if not rejected(prefs,invalid,current,"invalid range "+option): return
	for version in [1,2]:
		for upper in [false,true]:
			var boundary: Dictionary = (original if version == 1 else current).duplicate(true)
			boundary.values.sensitivity = 4.0 if upper else 0.1
			boundary.values.music_volume = 1.0 if upper else 0.0
			boundary.values.effects_volume = 1.0 if upper else 0.0
			if not expect(restored.from_dict(boundary),"Both versions accept the existing inclusive numeric boundaries"): return
	var path = "user://damage_flash_preferences_"+str(Time.get_ticks_usec())+".json"
	var raw = JSON.stringify(original)
	var file = FileAccess.open(path,FileAccess.WRITE)
	file.store_string(raw)
	file.close()
	if not expect(prefs.load_file(path) and JSON.parse_string(JSON.stringify(prefs.to_dict())) == JSON.parse_string(JSON.stringify(current)) and FileAccess.get_file_as_string(path) == raw,"Loading migrates in memory without rewriting a v1 save"): return
	var partial = JSON.stringify(missing_new)
	file = FileAccess.open(path,FileAccess.WRITE)
	file.store_string(partial)
	file.close()
	if not expect(not prefs.load_file(path) and JSON.parse_string(JSON.stringify(prefs.to_dict())) == JSON.parse_string(JSON.stringify(current)) and FileAccess.get_file_as_string(path) == partial,"A partial v2 file is rejected atomically and not rewritten"): return
	file = FileAccess.open(path,FileAccess.WRITE)
	file.store_string(raw)
	file.close()
	var game = load("res://scripts/main.gd").new()
	game.settings_path = path
	root.add_child(game)
	if not expect(JSON.parse_string(JSON.stringify(game.preferences.to_dict())) == JSON.parse_string(JSON.stringify(current)) and FileAccess.get_file_as_string(path) == raw,"Native startup loads old settings without a migration write"): return
	game.show_settings()
	var reduced: CheckButton
	var shake: CheckButton
	var checks = 0
	var sliders = 0
	for child in game.menu.get_children():
		if child is CheckButton:
			checks += 1
			if child.text == "Reduced damage flashes": reduced = child
			if child.text == "Camera shake": shake = child
		if child is HSlider: sliders += 1
	if not expect(reduced != null and shake != null and checks == 5 and sliders == 3,"One native comfort checkbox joins the existing family without another slider"): return
	if not expect(not reduced.button_pressed and not shake.button_pressed,"Legacy shake-off does not enable reduced flashes"): return
	reduced.button_pressed = true
	if not expect(restored.load_file(path) and restored.values.reduced_damage_flashes and not restored.values.camera_shake and restored.to_dict().version == 2,"Real checkbox signal persists only the independently chosen comfort setting as v2"): return
	shake.button_pressed = true
	if not expect(game.settings.reduced_damage_flashes and restored.load_file(path) and restored.values.reduced_damage_flashes and restored.values.camera_shake,"Camera shake toggle preserves independently reduced flashes"): return
	game.free()
	paused = false
	game = load("res://scripts/main.gd").new()
	game.settings_path = path
	root.add_child(game)
	if not expect(game.settings.reduced_damage_flashes and game.settings.camera_shake,"Native application restart preserves the checkbox choice"): return
	if not expect(game.hud.has_method("damage_flash_alpha"),"The actual HUD exposes the flash-alpha policy used by its draw path"): return
	for camera_shake in [false,true]:
		for reduced_flashes in [false,true]:
			game.settings.camera_shake = camera_shake
			game.settings.reduced_damage_flashes = reduced_flashes
			var frozen: Dictionary = game.preferences.to_dict()
			for duration in [0.0,0.1,0.35,1.0]:
				game.damage_flash = duration
				var alpha = minf(0.45,duration*1.3)*(0.6 if reduced_flashes else 1.0)
				if not expect(is_equal_approx(game.hud.call("damage_flash_alpha"),alpha),"Actual native HUD alpha follows reduced flashes, independently of camera shake and with the old cap"): return
			if not expect(game.preferences.to_dict() == frozen,"Reading HUD alpha never mutates preferences"): return
	game.free()
	paused = false
	DirAccess.remove_absolute(path)
	print("PASS strict lossless v1/v2 migration, atomic malformed rejection, no load rewrite, native checkbox persistence and independent HUD flash alpha")
	quit()

func rejected(prefs: RefCounted, invalid: Dictionary, frozen: Dictionary, reason: String) -> bool:
	var input_before: Dictionary = invalid.duplicate(true)
	var accepted: bool = prefs.from_dict(invalid)
	# JSON cannot distinguish rejected NaN/Inf from null; retain their exact primitive identity.
	var before_fields: Dictionary = {"version":input_before.version}
	var after_fields: Dictionary = {"version":invalid.get("version")}
	if input_before.values is Dictionary:
		for key in input_before.values:
			before_fields["option:"+key] = input_before.values[key]
			after_fields["option:"+key] = invalid.values.get(key) if invalid.get("values") is Dictionary else null
	for key in before_fields:
		var value = before_fields[key]
		if not value is float or is_finite(value): continue
		var after = after_fields[key]
		if not expect(after is float and (is_nan(after) if is_nan(value) else after == value),"Reject preserves nonfinite caller field: "+reason): return false
	return expect(not accepted and prefs.to_dict() == frozen and JSON.stringify(invalid) == JSON.stringify(input_before),"Reject without live or caller mutation: "+reason)

func expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
