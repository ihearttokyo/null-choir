extends SceneTree

# Synthetic inventory/ground; production Player, Main callbacks and native scheduling.
class QuietHud extends Node2D:
	var survey := Control.new()
	func _ready() -> void: add_child(survey)

class NativeGame extends "res://scripts/main.gd":
	var shots: Array = []
	var dry_events: Array = []
	func _ready() -> void:
		set_process(false)
	func shot(index: int) -> void:
		super.shot(index)
		shots.append({"weapon":index,"selected":state.weapon,"ammo":state.ammo.duplicate(),"tick":Engine.get_physics_frames(),"cooldowns":player.weapon_cooldowns.duplicate()})
	func dry_fire(index: int) -> void:
		super.dry_fire(index)
		dry_events.append({"weapon":index,"tick":Engine.get_physics_frames()})

var game
var master_muted: bool

func _initialize() -> void:
	master_muted = AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func run() -> void:
	var passed: bool = await check_input()
	Input.action_release("fire")
	Input.action_release("weapon_4")
	paused = false
	if is_instance_valid(game):
		game.playing = false
		game.queue_free()
	await process_frame
	await process_frame
	passed = expect(not is_instance_valid(game),"Teardown frees both current and retired levels") and passed
	AudioServer.set_bus_mute(0,master_muted)
	if passed: print("PASS synthetic native held ammo input: cooldown, one-round fallback, pause and retired player")
	quit(0 if passed else 1)

func check_input() -> bool:
	if not expect(Engine.physics_ticks_per_second == 60 and not paused,"SETUP: unpaused native 60-Hz physics required"): return false
	game = NativeGame.new()
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
	Input.action_release("fire")
	Input.action_release("weapon_4")
	game.state.new_campaign(1)
	game.state.owned_weapons = [0,1,3]
	game.state.ammo = [0,90,0,1,0,0]
	game.state.weapon = 1
	game.level = arena()
	game.player = player_in(game.level,Vector3(0,0.04,0))
	game.playing = true
	for tick in range(12): await physics_frame
	if not expect(game.player.is_on_floor() and game.state.ammo == [0,90,0,1,0,0] and game.shots.is_empty(),"SETUP: real capsule settles on native ground without firing"): return false
	Input.action_press("fire")
	if not await wait_shots(1,4): return false
	if not expect(game.shots[0].weapon == 1 and game.shots[0].selected == 1 and game.shots[0].ammo == [0,89,0,1,0,0],"Held fire first spends exactly one pistol round"): return false
	Input.action_press("weapon_4")
	if not await wait_shots(2,4): return false
	Input.action_release("weapon_4")
	var repeater: Dictionary = game.shots[1]
	if not expect(repeater.weapon == 3 and repeater.selected == 3 and repeater.ammo == [0,89,0,0,0,0] and repeater.cooldowns[1] > 0,"Mapped selection fires one repeater round while pistol is still cooling"): return false
	for tick in range(3):
		await physics_frame
		if game.state.weapon == 1: break
	if not expect(game.state.weapon == 1 and game.shots.size() == 2 and game.dry_events.size() == 1 and game.dry_events[0].weapon == 3 and game.dry_events[0].tick > repeater.tick,"Dry fallback selects pistol without a shot in the refused tick"): return false
	if not await wait_shots(5,45): return false
	var pistol_ticks: Array = []
	for shot in game.shots:
		if shot.weapon == 1: pistol_ticks.append(shot.tick)
	if not expect(game.shots.size() == 5 and pistol_ticks.size() == 4 and game.state.ammo == [0,86,0,0,0,0],"Continuous held fire spends four pistol rounds and only one repeater round"): return false
	var interval_ticks: int = int(ceil(game.Player.WEAPONS[1].interval*60.0))
	for index in range(1,pistol_ticks.size()):
		var elapsed: int = pistol_ticks[index]-pistol_ticks[index-1]
		if not expect(elapsed in [floori(game.Player.WEAPONS[1].interval*60.0),interval_ticks],"Held pistol preserves its nominal phase with only adjacent quantized gaps"): return false
	var frozen_ammo: Array = game.state.ammo.duplicate()
	var pre_pause_cooldowns: Array = game.player.weapon_cooldowns.duplicate()
	var pause_tick: int = Engine.get_physics_frames()
	game.pause_game()
	var frozen_cooldowns: Array = game.player.weapon_cooldowns.duplicate()
	for index in range(frozen_cooldowns.size()):
		if not expect(frozen_cooldowns[index] >= pre_pause_cooldowns[index],"Ending held repeat for pause never shortens recovery"): return false
	if not expect(not game.player.can_process() and frozen_cooldowns[1] > 0,"Actual SceneTree pause suspends the cooling production Player"): return false
	for tick in range(24): await physics_frame
	if not expect(game.shots.size() == 5 and game.state.ammo == frozen_ammo and game.player.weapon_cooldowns == frozen_cooldowns,"Held fire cannot spend ammo or advance any cooldown while paused"): return false
	var paused_ticks: int = Engine.get_physics_frames()-pause_tick
	game.resume_game()
	if not expect(game.player.weapon_cooldowns == frozen_cooldowns,"Resume preserves every retained recovery deadline"): return false
	for tick in range(20): await physics_frame
	if not expect(game.shots.size() == 5 and game.state.ammo == frozen_ammo,"Production Resume rejects still-held fire without spending ammunition"): return false
	Input.action_release("fire")
	await physics_frame
	Input.action_press("fire")
	if not await wait_shots(6,4): return false
	var active_gap: int = game.shots[5].tick-game.shots[4].tick-paused_ticks
	if not expect(game.shots.size() == 6 and game.shots[5].weapon == 1 and active_gap >= interval_ticks and game.state.ammo == [0,85,0,0,0,0],"Release/re-arm after Resume respects retained recovery and spends exactly one pistol round"): return false
	Input.action_release("fire")
	for tick in range(interval_ticks+2): await physics_frame
	var retired = game.player
	var retired_level = game.level
	var retired_cooldowns: Array = retired.weapon_cooldowns.duplicate()
	if not expect(is_zero_approx(retired_cooldowns[1]),"SETUP: retired pistol recovers naturally before replacement"): return false
	game.level = arena()
	game.player = player_in(game.level,Vector3(5,0.04,0))
	for tick in range(12): await physics_frame
	if not expect(retired.is_inside_tree() and retired.is_physics_processing() and game.player.is_physics_processing() and retired.get_parent() == retired_level and game.player.is_on_floor(),"SETUP: old and new Players stay automatically scheduled in separate tree-owned levels"): return false
	var stale_event = InputEventAction.new()
	stale_event.action = "fire"
	stale_event.pressed = true
	retired._unhandled_input(stale_event)
	if not expect(game.shots.size() == 6 and game.state.ammo == [0,85,0,0,0,0] and retired.weapon_cooldowns == retired_cooldowns,"Retired player's real input entry rejects a ready stale fire event"): return false
	Input.action_press("fire")
	for tick in range(20): await physics_frame
	Input.action_release("fire")
	if not expect(game.shots.size() == 8 and game.state.ammo == [0,83,0,0,0,0] and retired.weapon_cooldowns == retired_cooldowns,"Only current Player spends two rounds; scheduled retired Player cannot fire or spend"): return false
	print("MEASURE synthetic native ammo shots=",game.shots," dry=",game.dry_events," paused_ticks=",paused_ticks)
	return true

func arena():
	var level = game.Level.new()
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	game.add_child(level)
	level._box(Vector3(40,1,40),Vector3(0,-0.5,0),null,true)
	return level

func player_in(level, location: Vector3):
	var player = game.Player.new()
	level.add_child(player)
	player.configure(game)
	player.position = location
	return player

func wait_shots(count: int, limit: int) -> bool:
	for tick in range(limit):
		await physics_frame
		if game.shots.size() >= count: return true
	return expect(false,"Native held-input shot deadline exceeded: "+str(count))

func expect(condition: bool, message: String) -> bool:
	if not condition: push_error(message)
	return condition
