extends SceneTree

# Real input/physics and Main callbacks; synthetic floor/inventory, no startup or saves.
class QuietHud extends Node2D:
	var survey := Control.new()
	func _ready() -> void: add_child(survey)

class NativeGame extends "res://scripts/main.gd":
	var driver
	var shots: Array = []
	var dry_events: Array = []
	var fire_events := 0
	var interactions := 0
	func interact() -> void: interactions += 1
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		set_process(false)
	func _input(event: InputEvent) -> void:
		if event.is_action("fire"): fire_events += 1
		super._input(event)
	func shot(index: int) -> void:
		super.shot(index)
		shots.append({"weapon":index,"tick":driver.ticks+1,"physics":driver.in_step})
	func dry_fire(index: int) -> void:
		super.dry_fire(index)
		dry_events.append({"weapon":index,"physics":driver.in_step})

class Driver extends Node:
	var game
	var remaining := 0
	var ticks := 0
	var in_step := false
	var last_delta := 0.0
	var bad_delta := false
	var injected_delta := 0.0
	func _physics_process(delta: float) -> void:
		if remaining <= 0: return
		if injected_delta > 0:
			delta = injected_delta # A single simulated hitch, still inside native physics.
			injected_delta = 0
		elif absf(delta-1.0/60.0) > .000001: bad_delta = true
		last_delta = delta
		var before: int = game.shots.size()
		in_step = true
		game.player._physics_process(delta)
		in_step = false
		if game.shots.size() > before:
			game.shots.back()["post_frame"] = game.player.weapon_frame()
			game.shots.back()["post_age"] = game.player.shot_age() if game.player.has_method("shot_age") else -1.0
		ticks += 1
		remaining -= 1

var game
var driver
var master_muted := false
var mouse_mode: int

func _initialize() -> void:
	master_muted = AudioServer.is_bus_mute(0)
	mouse_mode = Input.mouse_mode
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func run() -> void:
	var passed: bool = await check_fire_intent()
	paused = false
	if is_instance_valid(game): game.playing = false
	for action in preload("res://scripts/preferences.gd").ACTIONS:
		if InputMap.has_action(action): Input.action_release(action)
	var game_ref = weakref(game) if is_instance_valid(game) else null
	var driver_ref = weakref(driver) if is_instance_valid(driver) else null
	if is_instance_valid(driver): driver.queue_free()
	if is_instance_valid(game): game.queue_free()
	await process_frame
	await process_frame
	passed = expect((game_ref == null or game_ref.get_ref() == null) and (driver_ref == null or driver_ref.get_ref() == null),"Teardown releases the fixture, level and driver") and passed
	Input.mouse_mode = mouse_mode
	AudioServer.set_bus_mute(0,master_muted)
	if passed: print("PASS synthetic native NC02 intent: real mouse/key/axis events, short taps, handled menu, held Resume gate, 10s cadence, recovery, dry fallback and six first-post-shot poses/ages")
	quit(0 if passed else 1)

func check_fire_intent() -> bool:
	if not expect(Engine.physics_ticks_per_second == 60 and not paused,"SETUP: unpaused native 60-Hz physics required"): return false
	game = NativeGame.new()
	root.add_child(game)
	game.preferences.apply_bindings()
	for action in game.Preferences.ACTIONS: Input.action_release(action)
	game.state.new_campaign(1)
	game.settings.auto_aim = false
	game.settings.head_bob = false
	game.settings.camera_shake = false
	game.canvas = CanvasLayer.new()
	game.canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game.canvas)
	game.hud = QuietHud.new()
	game.canvas.add_child(game.hud)
	game.menu = VBoxContainer.new()
	game.menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game.menu_scroll = ScrollContainer.new()
	game.menu_scroll.position = Vector2(150,45)
	game.menu_scroll.size = Vector2(340,275)
	game.menu_scroll.add_child(game.menu)
	game.canvas.add_child(game.menu_scroll)
	game.menu_scroll.hide()
	game.level = game.Level.new()
	game.level.process_mode = Node.PROCESS_MODE_PAUSABLE
	game.add_child(game.level)
	if not expect(game.level.layout.load_level(0),"SETUP native observation needs actual authored interaction metadata"): return false
	game.level._box(Vector3(40,1,40),Vector3(0,-.5,0),null,true)
	driver = Driver.new()
	driver.process_mode = Node.PROCESS_MODE_PAUSABLE
	driver.game = game
	game.driver = driver
	root.add_child(driver)
	await physics_frame
	await physics_frame
	if not await fresh_player(1): return false
	var events: int = game.fire_events
	mouse(true)
	mouse(false)
	print("MEASURE NC02 between-tick real mouse tap: events=",game.fire_events-events," immediate_shots=",game.shots.size()," held=",Input.is_action_pressed("fire"))
	if not expect(game.fire_events-events == 2 and not Input.is_action_pressed("fire"),"SETUP: native dispatch delivered both mouse edges and release state"): return false
	# This semantic assertion precedes every proposed-interface assertion.
	if not expect(game.shots.is_empty() and game.state.ammo[1] == 90,"NC02 RED: input callbacks must not discharge a between-tick tap"): return false
	if not await step(1): return false
	if not expect(game.shots.size() == 1 and game.shots[0].physics and game.state.ammo[1] == 89,"Released eligible tap produces exactly one physics-owned shot"): return false
	mouse(true)
	mouse(false)
	if not await step(18): return false
	if not expect(game.shots.size() == 1,"Unavailable tap is consumed, not replayed after recovery"): return false
	mouse(true)
	mouse(false)
	mouse(true)
	mouse(false)
	if not await step(1): return false
	if not expect(game.shots.size() == 2,"Two queued press edges occupy one attempt slot"): return false
	if not await check_pause_and_menu(): return false
	if not await check_repeat_and_recovery(): return false
	if not await check_interact_and_hitch(): return false
	if not await fresh_player(3): return false
	game.state.ammo[3] = 0
	game.state.owned_weapons = [0,1,3] # Pin pistol as the supplied owned fallback.
	mouse(true)
	mouse(false)
	if not await step(1): return false
	if not expect(game.shots.is_empty() and game.dry_events.size() == 1 and game.dry_events[0].physics and game.state.weapon == 1 and game.state.ammo[1] == 90,"Dry attempt selects supplied fallback without discharging it"): return false
	if not await step(18): return false
	if not expect(game.shots.is_empty(),"Released dry attempt never queues a fallback shot"): return false
	mouse(true)
	mouse(false)
	if not await step(1): return false
	if not expect(game.shots.size() == 1 and game.shots[0].weapon == 1 and game.state.ammo[1] == 89,"New fallback tap spends exactly one supplied round"): return false
	for weapon in range(6):
		if not await fresh_player(weapon): return false
		if weapon == 3:
			trigger(1.0)
			trigger(0.0)
		else:
			mouse(true)
			mouse(false)
		if not expect(game.shots.is_empty(),"Every weapon/trigger waits for a physics attempt"): return false
		var ammo_before: Array = game.state.ammo.duplicate()
		if not await step(1): return false
		if not expect(game.shots.size() == 1 and game.shots[0].weapon == weapon and game.shots[0].physics and game.shots[0].post_frame == 1,"Every accepted weapon starts in its actual first-post-shot firing pose"): return false
		ammo_before[weapon] -= 1 if weapon > 0 else 0
		if not expect(game.state.ammo == ammo_before,"Accepted-shot ammo agrees for all six weapons, including the free tool"): return false
		if not expect(game.player.has_method("shot_age"),"Presentation contract: selected-weapon shot_age() reads the authoritative accepted-shot clock"): return false
		if not expect(is_zero_approx(game.shots[0].post_age),"First post-shot age is zero, not interval minus residual readiness"): return false
		if not await step(1): return false
		if not expect(absf(game.player.shot_age()-driver.last_delta) < .000001,"Shot age advances by one active tick, independently of readiness"): return false
	return true

func check_pause_and_menu() -> bool:
	if not await fresh_player(1): return false
	mouse(true)
	if not await step(1): return false
	if not expect(game.shots.size() == 1,"SETUP: held shot before pause"): return false
	game.pause_game()
	if not expect(paused and not game.playing and not driver.can_process(),"Production pause suspends the physics driver"): return false
	var paused_age: float = game.player.shot_age() if game.player.has_method("shot_age") else -1.0
	for tick in range(16): await physics_frame
	if not expect(game.shots.size() == 1 and (paused_age < 0 or is_equal_approx(game.player.shot_age(),paused_age)),"Actual pause freezes accepted shots and the exposed shot-age clock"): return false
	game.resume_game()
	if not await step(20): return false
	if not expect(game.shots.size() == 1,"Still-held fire after production Resume requires release"): return false
	mouse(false)
	if not await step(1): return false
	mouse(true)
	mouse(false)
	if not await step(1): return false
	if not expect(game.shots.size() == 2,"Release followed by a fresh tap re-arms Resume fire"): return false
	if not await fresh_player(1): return false
	game.pause_game()
	await process_frame
	await process_frame
	var resume_button: Button = game.menu.get_child(1)
	mouse(true,resume_button.get_global_rect().get_center())
	if not expect(root.is_input_handled() and Input.is_action_pressed("fire") and game.shots.is_empty() and not game.playing,"Native menu consumes a fire-bound mouse press without combat"): return false
	game.resume_game()
	if not await step(20): return false
	if not expect(game.shots.is_empty(),"Menu-consumed still-held click cannot leak into resumed combat"): return false
	mouse(false)
	if not await step(1): return false
	return true

func check_repeat_and_recovery() -> bool:
	if not await fresh_player(3): return false
	mouse(true)
	if not await step(600): return false
	var count: int = game.shots.size()
	var configured_count: float = 10.0/game.Player.WEAPONS[3].interval
	print("MEASURE NC02 ordinary 60Hz repeat seconds=10 shots=",count," configured=",configured_count," ammo=",game.state.ammo[3])
	if not expect(absf(count-configured_count) <= 1.0 and game.state.ammo[3] == 240-count,"Ten-second repeat matches configured average within one shot and exact finite ammo"): return false
	for index in range(count):
		var shot: Dictionary = game.shots[index]
		if not expect(shot.physics and shot.post_frame == 1,"Every sustained shot is physics-owned with a first-post-shot firing pose"): return false
		if not expect(shot.post_age >= 0 and absf(shot.post_age) < .000001,"Accepted repeat age starts at zero even when readiness retains residual lateness"): return false
		if index > 0:
			var gap: int = shot.tick-game.shots[index-1].tick
			if not expect(gap in [5,6],"Ordinary 85ms cadence uses only five/six tick gaps, never a burst"): return false
	var last_tick: int = game.shots.back().tick
	mouse(false)
	mouse(true)
	for waited in range(7):
		if not await step(1): return false
		if game.shots.size() > count: break
	if not expect(game.shots.size() == count+1 and float(game.shots.back().tick-last_tick)/60.0+.000001 >= game.Player.WEAPONS[3].interval,"Fresh repress normalizes full recovery instead of retaining a short repeat gap"): return false
	var shots_before: int = game.shots.size()
	key(KEY_2,true)
	if not await step(1): return false
	key(KEY_2,false)
	if not expect(game.state.weapon == 1 and game.shots.size() == shots_before+1 and game.shots.back().weapon == 1,"Physics selection precedes the held attempt for a fresh owned pistol"): return false
	key(KEY_4,true)
	if not await step(1): return false
	key(KEY_4,false)
	if not expect(game.state.weapon == 3 and game.shots.size() == shots_before+1,"Switching back respects the repeater recovery deadline"): return false
	mouse(false)
	return true

func check_interact_and_hitch() -> bool:
	if not await fresh_player(1): return false
	key(KEY_E,true)
	game.pause_game()
	game.resume_game()
	var before: int = game.interactions
	key(KEY_E,false)
	key(KEY_E,true)
	if not await step(1): return false
	key(KEY_E,false)
	if not expect(game.interactions == before+1,"Interaction release/repress between ticks must re-arm after Resume"): return false
	if not await fresh_player(3): return false
	mouse(true)
	if not await step(1): return false
	driver.injected_delta = game.Player.WEAPONS[3].interval*6.0
	if not await step(1): return false
	if not expect(game.shots.size() == 2 and is_equal_approx(game.player.cooldown,game.Player.WEAPONS[3].interval),"Exact-period simulated hitch skips missed shots to one full next interval"): return false
	if not await step(1): return false
	mouse(false)
	if not expect(game.shots.size() == 2,"No extra shot on the tick immediately after exact-period hitch"): return false
	if not await fresh_player(3): return false
	mouse(true)
	if not await step(47): return false
	var shots_before: int = game.shots.size()
	driver.injected_delta = game.player.cooldown+game.Player.WEAPONS[3].interval
	if not await step(1): return false
	if not expect(game.shots.size() == shots_before+1 and is_equal_approx(game.player.cooldown,game.Player.WEAPONS[3].interval),"Positive near-zero post-hitch recovery advances to a full next slot"): return false
	if not await step(1): return false
	mouse(false)
	return expect(game.shots.size() == shots_before+1,"Positive boundary hitch cannot add an immediate next-tick shot")

func fresh_player(weapon: int) -> bool:
	Input.action_release("fire")
	for action in ["weapon_2","weapon_4"]: Input.action_release(action)
	if is_instance_valid(game.player): game.player.free()
	game.state.owned_weapons = [0,1,2,3,4,5]
	game.state.ammo = [0,90,32,240,24,120]
	game.state.weapon = weapon
	game.player = game.Player.new()
	game.level.add_child(game.player)
	game.player.configure(game)
	game.player.position = Vector3(0,.04,0)
	game.player.set_physics_process(false)
	game.playing = true
	game.menu_scroll.hide()
	game.shots.clear()
	game.dry_events.clear()
	driver.ticks = 0
	if not await step(12): return false
	driver.ticks = 0
	return expect(game.player.is_on_floor() and game.shots.is_empty(),"SETUP: current real capsule settles without a shot")

func step(count: int) -> bool:
	driver.remaining = count
	for waited in range(count+3):
		await physics_frame
		if driver.remaining == 0:
			return expect(not driver.bad_delta,"Native fixture requires ordinary 1/60-second callbacks")
	return expect(false,"Native physics step deadline exceeded")

func mouse(pressed: bool, location: Vector2 = Vector2(20,20)) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = location
	event.global_position = location
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func trigger(value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_TRIGGER_RIGHT
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func expect(condition: bool, detail: String) -> bool:
	if not condition: push_error(detail)
	return condition
