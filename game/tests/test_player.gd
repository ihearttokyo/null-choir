extends SceneTree

class TestGame extends Node3D:
	var state = preload("res://scripts/campaign.gd").new()
	var settings = {"auto_aim":false,"sensitivity":1.0,"invert_y":false,"head_bob":false,"camera_shake":false}
	var playing = false
	var shots = 0
	func shot(_weapon): shots += 1

func _initialize():
	call_deferred("run")

func run():
	var game = TestGame.new()
	root.add_child(game)
	game.state.new_campaign(1)
	var player = load("res://scripts/player.gd").new()
	game.add_child(player)
	player.configure(game)
	player.set_physics_process(false)
	await physics_frame
	game.playing = true
	if not expect(player.fire()): return
	if not expect(game.state.ammo[1] == 89 and game.shots == 1): return
	if not expect(not player.fire() and game.state.ammo[1] == 89): return
	player.cooldown = 0
	game.state.ammo[1] = 0
	if not expect(not player.fire() and game.shots == 1): return
	game.state.weapon = 0
	if not expect(player.fire() and game.state.ammo[0] == 0): return
	player.cycle_weapon(1)
	if not expect(game.state.weapon == 1): return
	player.cooldown = 0
	game.state.health = 0
	if not expect(not player.fire()): return
	game.playing = false
	game.state.health = 100
	game.state.ammo[1] = 10
	if not expect(not player.fire() and game.state.ammo[1] == 10): return
	game.playing = true
	preload("res://scripts/preferences.gd").new().apply_bindings()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var motion = InputEventMouseMotion.new()
	motion.relative = Vector2(5,0)
	motion.screen_relative = Vector2(10,0)
	player._unhandled_input(motion)
	if not expect(is_equal_approx(player.rotation.y,-0.02)): return
	var tap = InputMap.action_get_events("fire")[0].duplicate()
	tap.pressed = true
	player._unhandled_input(tap)
	tap.pressed = false
	player._unhandled_input(tap)
	if not expect(game.state.ammo[1] == 9 and game.shots == 3): return
	print("PASS native player fire: ammo, cooldown, empty weapon, melee, inventory cycle and death gate")
	game.queue_free()
	quit()

func expect(condition: bool) -> bool:
	if not condition:
		push_error("Player firing contract assertion failed")
		quit(1)
	return condition
