extends RefCounted

const SAVE_PATH = "user://preferences.json"
const DEFAULTS = {"sensitivity":1.0,"invert_y":false,"head_bob":true,"camera_shake":true,"reduced_damage_flashes":false,"auto_aim":false,"music_volume":0.65,"effects_volume":0.8,"sound_test_reduced_motion":false}
const ACTIONS = ["move_forward","move_back","move_left","move_right","interact","pause","fire","weapon_previous","weapon_next","look_left","look_right","look_up","look_down","weapon_1","weapon_2","weapon_3","weapon_4","weapon_5","weapon_6","survey","run","use_asset"]
const V4_ADDITIONS = ["run","use_asset"] # One joint v4 transition.
var values: Dictionary = DEFAULTS.duplicate()
var bindings: Dictionary = default_bindings()

static func default_bindings() -> Dictionary:
	var result: Dictionary = {}
	for action in ACTIONS: result[action] = []
	var keys = [KEY_W,KEY_S,KEY_A,KEY_D,KEY_E,KEY_ESCAPE]
	for i in keys.size(): result[ACTIONS[i]].append(_key(keys[i]))
	result.weapon_previous.append(_key(KEY_Q))
	result.weapon_next.append(_key(KEY_TAB))
	result.survey.append(_key(KEY_M))
	result.run.append(_key(KEY_SHIFT))
	result.run.append({"kind":"joy","code":JOY_BUTTON_LEFT_STICK})
	result.use_asset.append(_key(KEY_SPACE))
	result.use_asset.append({"kind":"joy","code":JOY_BUTTON_X})
	for i in 6: result["weapon_"+str(i+1)].append(_key(KEY_1+i))
	result.fire.append({"kind":"mouse","code":MOUSE_BUTTON_LEFT})
	for bind in [["move_left",0,-1],["move_right",0,1],["move_forward",1,-1],["move_back",1,1],["look_left",2,-1],["look_right",2,1],["look_up",3,-1],["look_down",3,1],["fire",5,1]]:
		result[bind[0]].append({"kind":"axis","code":bind[1],"sign":bind[2]})
	for bind in [["interact",JOY_BUTTON_A],["pause",JOY_BUTTON_START],["weapon_previous",JOY_BUTTON_LEFT_SHOULDER],["weapon_next",JOY_BUTTON_RIGHT_SHOULDER],["survey",JOY_BUTTON_BACK]]:
		result[bind[0]].append({"kind":"joy","code":bind[1]})
	return result

static func _key(code: int) -> Dictionary:
	return {"kind":"key","code":code,"shift":false,"alt":false,"ctrl":false,"meta":false}

func reset() -> void:
	values = DEFAULTS.duplicate()
	bindings = default_bindings()
	apply_bindings()

func apply_bindings() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action): InputMap.add_action(action,0.2)
		InputMap.action_erase_events(action)
		for binding in bindings[action]: InputMap.action_add_event(action,_event(binding))

func bind_event(action: String, event: InputEvent) -> bool:
	if not action in ACTIONS: return false
	var binding: Dictionary = {}
	if event is InputEventKey and event.pressed and not event.echo:
		binding = _key(event.physical_keycode if event.physical_keycode else event.keycode)
		for modifier in ["shift","alt","ctrl","meta"]: binding[modifier] = event.get(modifier+"_pressed")
	elif event is InputEventMouseButton and event.pressed:
		binding = {"kind":"mouse","code":event.button_index}
	elif event is InputEventJoypadButton and event.pressed:
		binding = {"kind":"joy","code":event.button_index}
	elif event is InputEventJoypadMotion and absf(event.axis_value) >= 0.65:
		binding = {"kind":"axis","code":event.axis,"sign":1 if event.axis_value > 0 else -1}
	if not _valid_binding(binding): return false
	var desktop = binding.kind in ["key","mouse"]
	bindings[action] = bindings[action].filter(func(old): return (old.kind in ["key","mouse"]) != desktop)
	bindings[action].append(binding)
	apply_bindings()
	return true

func binding_text(action: String) -> String:
	var labels: PackedStringArray = []
	for binding in bindings[action]:
		match binding.kind:
			"key": labels.append(_event(binding).as_text().replace(" (Physical)",""))
			"mouse": labels.append("Mouse "+str(binding.code))
			"joy": labels.append("Pad "+str(binding.code))
			"axis": labels.append("Axis %d%s" % [binding.code,"+" if binding.sign > 0 else "−"])
	return " / ".join(labels)

func _event(binding: Dictionary) -> InputEvent:
	var event: InputEvent
	match binding.kind:
		"key":
			event = InputEventKey.new()
			event.physical_keycode = int(binding.code)
			for modifier in ["shift","alt","ctrl","meta"]: event.set(modifier+"_pressed",binding[modifier])
		"mouse":
			event = InputEventMouseButton.new()
			event.button_index = int(binding.code)
		"joy":
			event = InputEventJoypadButton.new()
			event.button_index = int(binding.code)
			event.device = -1
		"axis":
			event = InputEventJoypadMotion.new()
			event.axis = int(binding.code)
			event.axis_value = binding.sign
			event.device = -1
	return event

func to_dict() -> Dictionary:
	return {"version":4,"values":values.duplicate(),"bindings":bindings.duplicate(true)}

func from_dict(data: Dictionary) -> bool:
	if data.size() != 3 or not _integer(data.get("version"),1,4): return false
	var options = data.get("values")
	var controls = data.get("bindings")
	if not options is Dictionary: return false
	if data.version == 1:
		if options.size() != 7 or options.has("reduced_damage_flashes") or options.has("sound_test_reduced_motion"): return false
		options = options.duplicate()
		options.reduced_damage_flashes = DEFAULTS.reduced_damage_flashes
	if data.version <= 2:
		# Historical v2 is exactly eight options; never accept a v3 field in it.
		if options.size() != 8 or options.has("sound_test_reduced_motion"): return false
		options = options.duplicate()
		options.sound_test_reduced_motion = DEFAULTS.sound_test_reduced_motion
	# One shared v4 transition. V1 also predates survey; reject injected new
	# actions in old envelopes before adding defaults to a private copy.
	if data.version <= 3:
		if not controls is Dictionary: return false
		var old_count: int = ACTIONS.size()-V4_ADDITIONS.size()
		if data.version==1:
			# Historical v1 legitimately exists both before and after survey.
			if controls.size()!=old_count and (controls.size()!=old_count-1 or controls.has("survey")): return false
		elif controls.size()!=old_count: return false
		for action in V4_ADDITIONS:
			if controls.has(action): return false
		controls=controls.duplicate(true)
		for action in V4_ADDITIONS: controls[action]=default_bindings()[action]
	# One additive action; retain all existing v1 user bindings.
	if data.version == 1 and controls is Dictionary and controls.size() == ACTIONS.size()-1 and not controls.has("survey"):
		controls = controls.duplicate(true)
		controls.survey = default_bindings().survey
	if options.size() != DEFAULTS.size(): return false
	for key in DEFAULTS:
		var value = options.get(key)
		if DEFAULTS[key] is bool:
			if not value is bool: return false
		elif not (value is int or value is float) or not is_finite(float(value)) or value < (0.1 if key == "sensitivity" else 0.0) or value > (4.0 if key == "sensitivity" else 1.0): return false
	if not controls is Dictionary or controls.size() != ACTIONS.size(): return false
	for action in ACTIONS:
		var events = controls.get(action)
		if not events is Array or events.is_empty() or events.size() > 2: return false
		var families: Array = []
		for event in events:
			if not event is Dictionary or not _valid_binding(event): return false
			var desktop = event.kind in ["key","mouse"]
			if desktop in families: return false
			families.append(desktop)
	# Commit only after validating the complete primitive document; never deserialize objects.
	values = options.duplicate()
	bindings = controls.duplicate(true)
	return true

func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floor(value) and value >= low and value <= high

func _valid_binding(binding: Dictionary) -> bool:
	match binding.get("kind"):
		"key":
			if binding.size() != 6 or not _integer(binding.get("code"),1,0xFFFFFF): return false
			for modifier in ["shift","alt","ctrl","meta"]:
				if not binding.get(modifier) is bool: return false
			return true
		"mouse": return binding.size() == 2 and _integer(binding.get("code"),1,MOUSE_BUTTON_XBUTTON2)
		"joy": return binding.size() == 2 and _integer(binding.get("code"),0,JOY_BUTTON_MAX-1)
		"axis": return binding.size() == 3 and _integer(binding.get("code"),0,JOY_AXIS_MAX-1) and _integer(binding.get("sign"),-1,1) and binding.sign != 0
	return false

func save(path: String = SAVE_PATH) -> Error:
	var file = FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(to_dict()))
	file.flush()
	var error = file.get_error()
	file.close()
	if error != OK: return error
	return DirAccess.rename_absolute(path+".tmp",path)

func load_file(path: String = SAVE_PATH) -> bool:
	var file = FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > 1048576: return false
	var parser = JSON.new()
	return parser.parse(file.get_as_text()) == OK and parser.data is Dictionary and from_dict(parser.data)
