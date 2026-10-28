extends SceneTree

class TestGame extends Node3D:
	var state = preload("res://scripts/campaign.gd").new()
	var settings = {"auto_aim":false,"sensitivity":1.0,"invert_y":false,"head_bob":false,"camera_shake":false}
	var playing = true
	var level: Node3D
	var player

class Driver extends Node:
	var player
	var ticks := 0
	var touched_x := false
	var touched_z := false
	var invalid := false
	var corner_limit := false
	func _physics_process(delta: float) -> void:
		player._physics_process(delta)
		ticks += 1
		if player.position.x > 1.59 or (corner_limit and player.position.z < -3.59): invalid = true
		for index in player.get_slide_collision_count():
			var normal: Vector3 = player.get_slide_collision(index).get_normal()
			touched_x = touched_x or normal.x < -.9
			touched_z = touched_z or normal.z > .9

func _initialize() -> void: call_deferred("run")

func run() -> void:
	preload("res://scripts/preferences.gd").new().apply_bindings()
	for action in ["move_left","move_right","move_forward","move_back","run","fire","interact"]: Input.action_release(action)
	var game := TestGame.new()
	root.add_child(game)
	game.state.new_campaign(1)
	game.level = Node3D.new()
	game.add_child(game.level)
	add_box(game.level,Vector3(0,-.1,0),Vector3(200,.2,200))
	add_box(game.level,Vector3(2,2,0),Vector3(.2,4,200))
	game.player = preload("res://scripts/player.gd").new()
	game.level.add_child(game.player)
	game.player.configure(game)
	game.player.set_physics_process(false)
	var driver := Driver.new()
	driver.player = game.player
	driver.set_physics_process(false)
	root.add_child(driver)
	await physics_frame
	await physics_frame
	Input.action_press("run") # Original fast-slide velocity bound requires run, not slower walk.
	Input.action_press("move_right")
	Input.action_press("move_forward")
	driver.set_physics_process(true)
	while driver.ticks < 60: await physics_frame
	driver.set_physics_process(false)
	var slide: bool = not driver.invalid and driver.touched_x and game.player.is_on_floor() and game.player.position.x > 1.5 and game.player.position.z < -5.0 and game.player.velocity.z < -6.0
	if not slide:
		push_error("Real capsule must slide along the wall without penetration: "+str(game.player.position))
		await finish(game,driver,1)
		return
	# Add the crossing wall and rebuild a fresh start for corner contact.
	add_box(game.level,Vector3(0,2,-4),Vector3(200,4,.2))
	game.player.position = Vector3.ZERO
	game.player.cancel_actions() # Fresh collision case also resets canonical movement phase.
	driver.ticks = 0
	driver.corner_limit = true
	driver.touched_x = false
	driver.touched_z = false
	driver.invalid = false
	await physics_frame
	await physics_frame
	driver.set_physics_process(true)
	while driver.ticks < 90: await physics_frame
	driver.set_physics_process(false)
	var corner: bool = not driver.invalid and driver.touched_x and driver.touched_z and game.player.is_on_floor() and game.player.position.x > 1.5 and game.player.position.z < -3.5 and Vector2(game.player.velocity.x,game.player.velocity.z).length() < .01
	if not corner: push_error("Real corner must stop both planar components without penetration: "+str(game.player.position)+" velocity="+str(game.player.velocity))
	if corner: print("PASS native wall slide and corner: unchanged capsule, actual collision normals, floor contact, bounded position and stopped corner velocity")
	await finish(game,driver,0 if corner else 1)

func add_box(level: Node3D, point: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.position = point
	body.add_child(shape)
	level.add_child(body)

func finish(game: Node, driver: Node, code: int) -> void:
	for action in ["move_left","move_right","move_forward","move_back","run"]: Input.action_release(action)
	game.free()
	driver.free()
	await process_frame
	quit(code)
