extends SceneTree

const WallClock = preload("res://tests/wall_clock_wait.gd")
const MIGRATION_DEFAULTS = {
	"run":[{"kind":"key","code":KEY_SHIFT,"shift":false,"alt":false,"ctrl":false,"meta":false},{"kind":"joy","code":JOY_BUTTON_LEFT_STICK}],
	"use_asset":[{"kind":"key","code":KEY_SPACE,"shift":false,"alt":false,"ctrl":false,"meta":false},{"kind":"joy","code":JOY_BUTTON_X}],
	"survey":[{"kind":"key","code":KEY_M,"shift":false,"alt":false,"ctrl":false,"meta":false},{"kind":"joy","code":JOY_BUTTON_BACK}]
}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var path = "user://preferences_contract_"+str(Time.get_ticks_usec())+".json"
	var game = load("res://scripts/main.gd").new()
	game.settings_path = path
	root.add_child(game)
	game.show_settings()
	for child in game.menu.get_children():
		if child is CheckButton and child.text == "Head bob":
			child.button_pressed = false
	game.music.stop()
	await WallClock.seconds(self,0.15)
	game.free()
	paused = false
	game = load("res://scripts/main.gd").new()
	game.settings_path = path
	root.add_child(game)
	if game.settings.head_bob != false:
		push_error("Changed settings must survive application restart")
		game.free()
		quit(1)
		return
	game.show_settings()
	await process_frame
	await process_frame
	var client_right = game.menu_scroll.global_position.x+game.menu_scroll.size.x-game.menu_scroll.get_v_scroll_bar().size.x
	for child in game.menu.get_children():
		if child is CheckButton or child is HSlider:
			if not expect(child.global_position.x+child.size.x <= client_right,"Controls fit the scroll client width without clipping"): return
	var sliders: Array = []
	for child in game.menu.get_children():
		if child is HSlider: sliders.append(child)
	if not expect(sliders.size() == 3,"Sensitivity and independent volume sliders"): return
	sliders[0].value = 2.0
	sliders[1].value = 0.25
	sliders[2].value = 0.7
	if not expect(game.settings.sensitivity == 2.0 and game.settings.music_volume == 0.25 and game.settings.effects_volume == 0.7,"Distinct slider closures"): return
	if not expect(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))),0.25) and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Effects"))),0.7),"Independent native bus gains"): return
	game.show_controls()
	var button = game.menu.get_child(2)
	button.pressed.emit()
	var key = InputEventKey.new()
	key.physical_keycode = KEY_Z
	key.pressed = true
	game._input(key)
	if not expect(game.pending_action.is_empty() and button.text.contains("Z") and InputMap.event_is_action(key,"move_forward"),"Control row captures real key and updates feedback"): return
	button.pressed.emit()
	key.physical_keycode = KEY_ESCAPE
	game._input(key)
	if not expect(game.pending_action.is_empty() and button.text.contains("Z"),"Escape cancels without rebinding"): return
	button.pressed.emit()
	key.physical_keycode = KEY_CTRL
	key.ctrl_pressed = true
	game._input(key)
	if not expect(game.pending_action == "move_forward","Modifier press waits for chord or release"): return
	key = key.duplicate()
	key.physical_keycode = KEY_F
	game._input(key)
	if not expect(game.pending_action.is_empty() and InputMap.event_is_action(key,"move_forward",true),"Ordered Ctrl then F captures chord"): return
	button.pressed.emit()
	key = key.duplicate()
	key.physical_keycode = KEY_CTRL
	game._input(key)
	key = key.duplicate()
	key.pressed = false
	key.ctrl_pressed = false
	game._input(key)
	if not expect(game.pending_action.is_empty() and button.text.contains("Ctrl"),"Bare modifier captures on release"): return
	key.physical_keycode = KEY_Z
	key.pressed = true
	button.pressed.emit()
	game._input(key)
	var Prefs = load("res://scripts/preferences.gd")
	var prefs = Prefs.new()
	if not expect(prefs.load_file(path) and prefs.values.sensitivity == 2.0 and prefs.values.music_volume == 0.25 and prefs.binding_text("move_forward").contains("Z"),"Options and controls survive JSON roundtrip"): return
	prefs.apply_bindings()
	key.physical_keycode = KEY_F
	key.ctrl_pressed = true
	if not expect(prefs.bind_event("fire",key),"Keyboard binding"): return
	var mouse = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	if not expect(not InputMap.event_is_action(mouse,"fire") and InputMap.event_is_action(key,"fire"),"Keyboard replaces mouse in desktop family"): return
	mouse.button_index = MOUSE_BUTTON_RIGHT
	if not expect(prefs.bind_event("interact",mouse) and InputMap.event_is_action(mouse,"interact"),"Mouse rebinding"): return
	var pad = InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.device = 3
	pad.pressed = true
	if not expect(InputMap.event_is_action(pad,"interact"),"Other device family and any gamepad preserved"): return
	pad.button_index = JOY_BUTTON_X
	if not expect(prefs.bind_event("interact",pad),"Gamepad button rebinding"): return
	var axis = InputEventJoypadMotion.new()
	axis.axis = JOY_AXIS_LEFT_X
	axis.axis_value = -0.9
	axis.device = 4
	if not expect(prefs.bind_event("interact",axis) and InputMap.event_is_action(axis,"interact") and not InputMap.event_is_action(pad,"interact") and InputMap.event_is_action(mouse,"interact"),"Axis replaces gamepad button, keeps mouse"): return
	axis.axis_value = 0.1
	if not expect(not prefs.bind_event("interact",axis),"Ignore neutral stick drift"): return
	prefs.apply_bindings()
	prefs.apply_bindings()
	if not expect(InputMap.action_get_events("interact").size() == 2,"Repeated apply adds no duplicates"): return
	var frozen = prefs.to_dict()
	if not expect(frozen.version == 4 and frozen.bindings.run.size() == 2,"Run action is remappable in both device families"): return
	for version in [1,2,3]:
		var legacy = frozen.duplicate(true)
		legacy.version = version
		for action in prefs.V4_ADDITIONS: legacy.bindings.erase(action)
		if version <= 2: legacy.values.erase("sound_test_reduced_motion")
		if version == 1: legacy.values.erase("reduced_damage_flashes")
		for missing_survey in ([false,true] if version == 1 else [false]):
			var historical = legacy.duplicate(true)
			if missing_survey: historical.bindings.erase("survey")
			# Missing historical actions gain native integer defaults, unlike the
			# FLOAT codes in the JSON-loaded snapshot. All existing values stay exact.
			var expected = frozen.duplicate(true)
			for action in prefs.V4_ADDITIONS: expected.bindings[action] = MIGRATION_DEFAULTS[action].duplicate(true)
			if missing_survey: expected.bindings.survey = MIGRATION_DEFAULTS.survey.duplicate(true)
			if not expect(prefs.from_dict(historical) and prefs.bindings.move_forward == frozen.bindings.move_forward and prefs.bindings.interact == frozen.bindings.interact,"Preserve old custom actions during run migration v"+str(version)): return
			if prefs.to_dict() != expected:
				print("PREF_MIGRATION_DIFF version=",version," missing_survey=",missing_survey," actual=",JSON.stringify(prefs.to_dict())," expected=",JSON.stringify(expected))
			if not expect(prefs.to_dict() == expected,"Migration adds only exact defaults and preserves current options"): return
		var before_invalid = prefs.to_dict()
		for action in prefs.V4_ADDITIONS:
			var injected = legacy.duplicate(true)
			injected.bindings[action] = frozen.bindings[action].duplicate(true)
			if not expect(not prefs.from_dict(injected) and prefs.to_dict() == before_invalid,"Reject forged modern action in old envelope "+action): return
	frozen = prefs.to_dict() # Freeze the actual committed image for atomic-refusal checks.
	for action in prefs.V4_ADDITIONS:
		var missing_action = frozen.duplicate(true)
		missing_action.bindings.erase(action)
		if not expect(not prefs.from_dict(missing_action) and prefs.to_dict() == frozen,"Modern envelope cannot silently migrate missing "+action): return
	for mutation in ["volume","nonfinite","version","fraction","object","unknown"]:
		var invalid = frozen.duplicate(true)
		match mutation:
			"volume": invalid.values.music_volume = 2
			"nonfinite": invalid.values.sensitivity = NAN
			"version": invalid.version = "1"
			"fraction": invalid.bindings.interact[0].code = 1.5
			"object": invalid.bindings.interact[0] = Node.new()
			"unknown": invalid.bindings.interact[0].injected = true
		if not expect(not prefs.from_dict(invalid) and prefs.to_dict() == frozen,"Reject complete invalid document without mutation: "+mutation): return
		if mutation == "object": invalid.bindings.interact[0].free()
	var broken = FileAccess.open(path,FileAccess.WRITE)
	broken.store_string("{broken")
	broken.close()
	if not expect(not prefs.load_file(path) and prefs.to_dict() == frozen,"Corrupt file leaves live state intact"): return
	var blocker = path+".parent"
	broken = FileAccess.open(blocker,FileAccess.WRITE)
	broken.store_string("Owned failed-write fixture")
	broken.close()
	if not expect(prefs.save(blocker+"/settings.json") != OK and prefs.to_dict() == frozen,"Failed save reports error and preserves live state"): return
	DirAccess.remove_absolute(blocker)
	prefs.reset()
	if not expect(prefs.values == Prefs.DEFAULTS and prefs.bindings == Prefs.default_bindings(),"Restore native defaults"): return
	game.music.stop()
	await WallClock.seconds(self,0.15)
	game.free()
	paused = false
	DirAccess.remove_absolute(path)
	print("PASS persistent settings, sliders/buses, native keyboard/mouse/gamepad rebinding, capture/cancel, strict JSON and failed-save preservation")
	quit()

func expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
