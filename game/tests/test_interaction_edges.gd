extends "res://tests/test_ammo_input.gd"

# Controlled ground/inventory; queued events and actual native Player scheduling.
class InteractionGame:
	extends "res://tests/test_ammo_input.gd".NativeGame
	var interactions: Array = []
	var virtual_repress: bool = false
	func interact() -> void:
		interactions.append(Engine.get_physics_frames())
		if virtual_repress:
			virtual_repress = false
			Input.action_release("interact")
			Input.action_press("interact")

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
	var ok: bool = expect(game.player.is_on_floor(),"Setup: production capsule settled on native ground")
	# Deliver at the native frame boundary where the earned Nursery run found duplication.
	await physics_frame
	var start: int = game.interactions.size()
	edge(true)
	for tick in range(6): await physics_frame
	ok = expect(game.interactions.size()-start == 1,"One queued held interaction is consumed exactly once; ticks="+str(game.interactions)) and ok
	edge(false)
	for tick in range(6): await physics_frame
	start = game.interactions.size()
	edge(true)
	edge(false)
	for tick in range(6): await physics_frame
	ok = expect(game.interactions.size()-start == 1,"Short press/release before physics survives exactly once") and ok
	start = game.interactions.size()
	Input.action_press("interact")
	for tick in range(6): await physics_frame
	ok = expect(game.interactions.size()-start == 1,"Virtual-action fallback stays compatible and consumes once") and ok
	game.player.cancel_actions()
	for tick in range(6): await physics_frame
	ok = expect(game.interactions.size()-start == 1,"Held interaction cannot leak after production action cancellation") and ok
	Input.action_release("interact")
	for tick in range(6): await physics_frame
	start = game.interactions.size()
	edge(true)
	for tick in range(6): await physics_frame
	ok = expect(game.interactions.size()-start == 1,"Release/repress rearms exactly one eligible interaction") and ok
	edge(false)
	for tick in range(6): await physics_frame
	start = game.interactions.size()
	for tap in range(2):
		edge(true)
		edge(false)
		await physics_frame
	for tick in range(6): await physics_frame
	ok = expect(game.interactions.size()-start == 2,"Two fresh queued taps on adjacent native ticks each remain eligible") and ok
	start = game.interactions.size()
	edge(true)
	edge(false)
	game.player.cancel_actions()
	for tick in range(6): await physics_frame
	ok = expect(game.interactions.size() == start,"Canceled queued short tap cannot reappear through polling") and ok
	for tick in range(6): await physics_frame
	start = game.interactions.size()
	edge(true)
	edge(false)
	game.pause_game()
	for tick in range(6): await physics_frame
	ok = expect(paused and not game.playing and game.interactions.size() == start,"Actual pause cancels pending native edge while its poll expires") and ok
	game.resume_game()
	for tick in range(6): await physics_frame
	Input.action_press("interact")
	for tick in range(6): await physics_frame
	ok = expect(not paused and game.playing and game.interactions.size()-start == 1,"Fresh virtual press after pending-edge pause/Resume remains eligible") and ok
	Input.action_release("interact")
	for tick in range(6): await physics_frame
	start = game.interactions.size()
	Input.action_press("interact")
	for tick in range(6): await physics_frame
	ok = expect(game.interactions.size()-start == 1,"Virtual held edge is consumed once before immediate release/repress") and ok
	Input.action_release("interact")
	Input.action_press("interact")
	for tick in range(6): await physics_frame
	ok = expect(game.interactions.size()-start == 2,"Fresh virtual release/repress before the next Player tick is accepted") and ok
	var canceled_start: int = game.interactions.size()
	game.player.cancel_actions()
	Input.action_release("interact")
	Input.action_press("interact")
	Input.action_release("interact")
	for tick in range(6): await physics_frame
	ok = expect(game.interactions.size()-canceled_start == 1,"Fresh released virtual tap after held cancellation remains eligible") and ok
	for tick in range(6): await physics_frame
	start = game.interactions.size()
	edge(true)
	edge(false)
	game.player.cancel_actions()
	Input.action_press("interact")
	for tick in range(6): await physics_frame
	ok = expect(game.interactions.size()-start == 1,"Immediate fresh virtual press after canceled native edge is accepted exactly once") and ok
	Input.action_release("interact")
	for tick in range(6): await physics_frame
	start = game.interactions.size()
	game.virtual_repress = true
	edge(true)
	for tick in range(6): await physics_frame
	ok = expect(game.interactions.size()-start == 2,"Native interaction callback can issue one distinct virtual release/repress for next tick") and ok
	edge(false)
	for wait_ticks in [6,0]:
		for tick in range(6): await physics_frame
		edge(true)
		for tick in range(6): await physics_frame
		Input.action_release("interact")
		for tick in range(wait_ticks): await physics_frame
		start = game.interactions.size()
		edge(true)
		edge(false)
		game.player.cancel_actions()
		for tick in range(6): await physics_frame
		ok = expect(game.interactions.size() == start,"Native hold then virtual release cannot leak canceled new tap; gap="+str(wait_ticks)) and ok
	print("INTERACTION_EDGE_TICKS ",game.interactions)
	game.playing = false
	game.queue_free()
	await process_frame
	await process_frame
	ok = expect(not is_instance_valid(game),"Controlled native fixture drains") and ok
	AudioServer.set_bus_mute(0,master_muted)
	if ok: print("PASS queued held/tapped interaction, virtual action, cancellation and rearm through actual native Player ticks")
	quit(0 if ok else 1)

func edge(pressed: bool) -> void:
	var event = InputEventAction.new()
	event.action = "interact"
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)
	Input.flush_buffered_events()
