extends "res://tests/test_interaction_edges.gd"

# Controlled native event dispatch, not attached keyboard/mouse/pad hardware.
class ConsumeInput extends Node:
	func _input(event: InputEvent) -> void:
		if event.is_action_pressed("interact"): get_viewport().set_input_as_handled()
func run() -> void:
	game = InteractionGame.new()
	root.add_child(game)
	game.preferences.apply_bindings()
	game.canvas = CanvasLayer.new()
	game.canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.canvas)
	game.hud = QuietHud.new()
	game.canvas.add_child(game.hud)
	game.menu = VBoxContainer.new()
	game.menu_scroll = ScrollContainer.new()
	game.menu_scroll.add_child(game.menu)
	game.canvas.add_child(game.menu_scroll)
	game.menu_scroll.hide()
	game.state.new_campaign(1)
	game.level = arena()
	game.player = player_in(game.level,Vector3(0,0.04,0))
	game.playing = true
	for tick in range(12): await physics_frame
	var ok: bool = expect(game.player.is_on_floor(),"Setup: actual capsule settled")
	var key = InputEventKey.new()
	key.physical_keycode = KEY_E
	key.pressed = true
	game.preferences.bind_event("interact",key)
	ok = await button_case(key,"mapped keyboard") and ok
	var mouse = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_MIDDLE
	mouse.position = Vector2(320,180)
	mouse.global_position = mouse.position
	mouse.pressed = true
	game.preferences.bind_event("interact",mouse)
	ok = await button_case(mouse,"mapped mouse") and ok
	var button = InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_X
	button.pressed = true
	game.preferences.bind_event("interact",button)
	ok = await button_case(button,"mapped pad button") and ok
	var axis = InputEventJoypadMotion.new()
	axis.axis = JOY_AXIS_RIGHT_X
	axis.axis_value = 0.8
	game.preferences.bind_event("interact",axis)
	var start: int = game.interactions.size()
	dispatch(axis)
	for tick in range(6): await physics_frame
	ok = expect(game.interactions.size()-start == 1,"Mapped pad axis consumes initial threshold edge once") and ok
	axis = axis.duplicate()
	axis.axis_value = 0.95
	dispatch(axis)
	for tick in range(6): await physics_frame
	ok = expect(game.interactions.size()-start == 1,"Held axis motion cannot manufacture another interaction") and ok
	axis = axis.duplicate()
	axis.axis_value = 0
	dispatch(axis)
	for tick in range(6): await physics_frame
	axis = axis.duplicate()
	axis.axis_value = 0.8
	dispatch(axis)
	for tick in range(6): await physics_frame
	ok = expect(game.interactions.size()-start == 2,"Release and recross the axis threshold rearms once") and ok
	axis = axis.duplicate()
	axis.axis_value = 0
	dispatch(axis)
	for tick in range(6): await physics_frame
	var multi_start: int = game.interactions.size()
	for device in [0,1]:
		var press = axis.duplicate()
		press.device = device
		press.axis_value = 0.8
		dispatch(press)
		for tick in range(6): await physics_frame
	ok = expect(game.interactions.size()-multi_start == 2,"Two distinct pad sources each provide one initial axis edge") and ok
	for device in [0,1,0,1]:
		var held = axis.duplicate()
		held.device = device
		held.axis_value = 0.95
		dispatch(held)
		for tick in range(6): await physics_frame
	ok = expect(game.interactions.size()-multi_start == 2,"Alternating held controllers cannot manufacture new axis interactions") and ok
	# Exercise the engine signal contract without claiming real hardware disconnect.
	Input.joy_connection_changed.emit(0,false)
	ok = expect(not game._interaction_axis_held.has(Vector2i(0,axis.axis)) and game._interaction_axis_held.has(Vector2i(1,axis.axis)),"Disconnect clears only its device's held-axis state") and ok
	var reconnect = axis.duplicate()
	reconnect.device = 0
	reconnect.axis_value = 0.8
	dispatch(reconnect)
	for tick in range(6): await physics_frame
	ok = expect(game.interactions.size()-multi_start == 3,"A reattached logical device rearms without disturbing the other held controller") and ok
	for device in [0,1]:
		var release = axis.duplicate()
		release.device = device
		release.axis_value = 0
		dispatch(release)
		for tick in range(6): await physics_frame
	var polarity_start: int = game.interactions.size()
	for value in [0.8,-0.8,0.8,0.0]:
		var polarity = axis.duplicate()
		polarity.device = 0
		polarity.axis_value = value
		dispatch(polarity)
		for tick in range(6): await physics_frame
	ok = expect(game.interactions.size()-polarity_start == 2,"Opposite-direction motion releases the bound positive axis before recross") and ok
	ok = expect(game._interaction_axis_held.is_empty(),"All released/disconnected physical axis entries retire") and ok
	# Exact-deadzone motion remains pressed in the observed native API.
	for unbound_release in [0.0,0.1,InputMap.action_get_deadzone("interact")]:
		var a0 = axis.duplicate()
		a0.device = 0
		a0.axis_value = 0.8
		game.preferences.bind_event("interact",a0)
		dispatch(a0)
		for tick in range(6): await physics_frame
		var rebind_start: int = game.interactions.size()
		game.pause_game()
		for tick in range(2): await physics_frame
		var b1 = a0.duplicate()
		b1.device = 1
		b1.axis = JOY_AXIS_RIGHT_Y
		game.preferences.bind_event("interact",b1)
		dispatch(b1)
		var release_a0 = a0.duplicate()
		release_a0.axis_value = unbound_release
		dispatch(release_a0)
		var a1 = a0.duplicate()
		a1.device = 1
		game.preferences.bind_event("interact",a1)
		dispatch(a1)
		var release_a1 = a1.duplicate()
		release_a1.axis_value = 0.0
		dispatch(release_a1)
		var release_b1 = b1.duplicate()
		release_b1.axis_value = 0.0
		dispatch(release_b1)
		for tick in range(6): await physics_frame
		ok = expect(paused and not game.playing and game.interactions.size() == rebind_start,"Rebinding during real pause cannot invoke gameplay interactions") and ok
		game.resume_game()
		for tick in range(6): await physics_frame
		dispatch(a0.duplicate())
		for tick in range(6): await physics_frame
		ok = expect(game.interactions.size()-rebind_start == (1 if unbound_release < InputMap.action_get_deadzone("interact") else 0),"Paused two-controller A-to-B-to-A rebind respects unbound release and exact native deadzone: "+str(unbound_release)) and ok
		var final_release = a0.duplicate()
		final_release.axis_value = 0.0
		dispatch(final_release)
		for tick in range(6): await physics_frame
	ok = expect(game._interaction_axis_held.is_empty(),"Released unbound axes retire without clearing held sources prematurely") and ok
	game.preferences.bind_event("interact",mouse)
	var consumer = ConsumeInput.new()
	root.add_child(consumer)
	start = game.interactions.size()
	dispatch(mouse.duplicate())
	for tick in range(6): await physics_frame
	ok = expect(game.interactions.size() == start,"Window input consumed before unhandled stage cannot replay through polling") and ok
	var up = mouse.duplicate()
	up.pressed = false
	dispatch(up)
	consumer.queue_free()
	print("INTERACTION_DEVICE_TICKS ",game.interactions)
	game.playing = false
	game.queue_free()
	await process_frame
	await process_frame
	ok = expect(not is_instance_valid(game),"Controlled native device fixture drains") and ok
	AudioServer.set_bus_mute(0,master_muted)
	if ok: print("PASS rebound keyboard/mouse/pad button/axis through queued native events; not physical hardware")
	quit(0 if ok else 1)

func button_case(event: InputEvent, label: String) -> bool:
	var start: int = game.interactions.size()
	dispatch(event)
	for tick in range(6): await physics_frame
	var ok: bool = expect(game.interactions.size()-start == 1,label+" queued press owns one interaction")
	if event is InputEventKey:
		var echo = event.duplicate()
		echo.echo = true
		dispatch(echo)
		for tick in range(6): await physics_frame
		ok = expect(game.interactions.size()-start == 1,"Held keyboard echo cannot manufacture another interaction") and ok

	var released = event.duplicate()
	released.pressed = false
	dispatch(released)
	for tick in range(6): await physics_frame
	var tap = event.duplicate()
	tap.pressed = true
	dispatch(tap)
	var tap_release = tap.duplicate()
	tap_release.pressed = false
	dispatch(tap_release)
	for tick in range(6): await physics_frame
	ok = expect(game.interactions.size()-start == 2,label+" released short tap survives exactly once") and ok
	return ok

func dispatch(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()
