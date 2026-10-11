extends SceneTree

class TestGame extends Node3D:
	var state = preload("res://scripts/campaign.gd").new()
	var settings = {"auto_aim":false,"sensitivity":1.0,"invert_y":false,"head_bob":false,"camera_shake":false}
	var playing = false
	var shots = 0
	var level: Node3D
	var player
	var stop_on_shot = false
	var stop_on_feedback = false
	var stop_on_dry = false
	var feedback = 0
	var impacts = 0
	func shot(_weapon):
		shots += 1
		if stop_on_shot: playing = false
	func hit_feedback():
		feedback += 1
		if stop_on_feedback: playing = false
	func impact(_point): impacts += 1
	func dry_fire(_weapon):
		if stop_on_dry: playing = false

class Target extends StaticBody3D:
	var game
	var hits = 0
	var stop_on_damage = false
	func take_damage(_damage, _source):
		hits += 1
		if stop_on_damage: game.playing = false

func _initialize():
	call_deferred("run")

func run():
	preload("res://scripts/preferences.gd").new().apply_bindings()
	var game = TestGame.new()
	root.add_child(game)
	game.state.new_campaign(1)
	game.level = Node3D.new()
	game.add_child(game.level)
	var player = load("res://scripts/player.gd").new()
	game.player = player
	game.level.add_child(player)
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
	if not expect(game.state.ammo[1] == 10 and game.shots == 2): return
	player._physics_process(0) # This continuation is inside the awaited native physics frame.
	if not expect(game.state.ammo[1] == 9 and game.shots == 3): return
	game.state.owned_weapons = [0,1,2]
	game.state.ammo = [0,90,32,0,0,0]
	game.player = null
	for weapon in [0,1,2]:
		game.state.weapon = weapon
		player.cooldown = 0
		var ammo = game.state.ammo.duplicate()
		var shots = game.shots
		if not expect(not player.fire() and game.state.ammo == ammo and game.shots == shots): return
	game.player = player
	var target = Target.new()
	target.game = game
	target.collision_layer = 4
	target.collision_mask = 0
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(4,4,1)
	collision.shape = shape
	target.add_child(collision)
	game.level.add_child(target)
	target.position = Vector3(0,1,-2)
	player.camera.look_at(target.global_position)
	await physics_frame
	await physics_frame
	for boundary in ["shot","damage","feedback"]:
		game.stop_on_shot = boundary == "shot"
		target.stop_on_damage = boundary == "damage"
		game.stop_on_feedback = boundary == "feedback"
		for weapon in [0,1,2]:
			game.playing = true
			game.state.weapon = weapon
			player.cooldown = 0
			target.hits = 0
			game.feedback = 0
			game.impacts = 0
			var ammo = game.state.ammo[weapon]
			if not expect(player.fire() and game.state.ammo[weapon] == ammo-(0 if weapon == 0 else 1)): return
			if not expect(target.hits == (0 if boundary == "shot" else 1) and game.feedback == (1 if boundary == "feedback" else 0) and game.impacts == 0): return
	game.stop_on_dry = true
	game.state.ammo[1] = 0
	game.state.weapon = 1
	game.playing = true
	player.dry_fire_time = 0
	if not expect(not player.fire() and game.state.weapon == 1): return
	game.stop_on_shot = true
	game.stop_on_dry = false
	game.state.weapon = 1
	game.state.ammo[1] = 10
	game.state.position = Vector3(20,0,20)
	game.playing = true
	player.cooldown = 0
	Input.action_press("fire")
	player._physics_process(0)
	Input.action_release("fire")
	if not expect(game.state.position == Vector3(20,0,20)): return
	game.level.queue_free()
	game.playing = true
	for weapon in [0,1,2]:
		game.state.weapon = weapon
		player.cooldown = 0
		var ammo = game.state.ammo.duplicate()
		var shots = game.shots
		if not expect(not player.fire() and game.state.ammo == ammo and game.shots == shots): return
	print("PASS native player fire: ammo, cooldown, empty weapon, melee, inventory cycle, death and callback/map lifetime gates")
	game.queue_free()
	quit()

func expect(condition: bool) -> bool:
	if not condition:
		push_error("Player firing contract assertion failed")
		quit(1)
	return condition
