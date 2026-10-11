extends SceneTree

class TestGame extends Node3D:
	var state = preload("res://scripts/campaign.gd").new()
	var settings = {"auto_aim":false,"sensitivity":1.0,"invert_y":false,"head_bob":false,"camera_shake":false}
	var playing = true
	var level: Node3D
	var player

class Driver extends Node:
	var player
	var expected := Vector2.ZERO
	var target := Vector2.ZERO
	var ticks := 0
	var failed := false
	var label := ""
	var travelled := 0.0
	func _physics_process(delta: float) -> void:
		# Test the production callback inside the actual native physics domain.
		var remaining := target-expected
		var step := minf(remaining.length(),50.0*delta)
		if remaining.length() > 0: expected += remaining.normalized()*step
		var before: Vector3 = player.position
		player._physics_process(delta)
		var displacement := Vector2(player.position.x-before.x,player.position.z-before.z)
		travelled += displacement.length()
		if displacement.distance_to(expected*delta) > .00005:
			failed = true
			push_error("Native movement displacement "+label+" expected="+str(expected*delta)+" actual="+str(displacement))
		var actual := Vector2(player.velocity.x,player.velocity.z)
		if not actual.is_equal_approx(expected):
			failed = true
			push_error("Movement vector budget "+label+" tick="+str(ticks)+" expected="+str(expected)+" actual="+str(actual))
		ticks += 1

func _initialize() -> void: call_deferred("run")

func run() -> void:
	preload("res://scripts/preferences.gd").new().apply_bindings()
	for action in ["move_left","move_right","move_forward","move_back","fire","interact"]: Input.action_release(action)
	var game = TestGame.new()
	root.add_child(game)
	game.state.new_campaign(1)
	game.level = Node3D.new()
	game.add_child(game.level)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(200,.2,200)
	floor_shape.shape = floor_box
	floor_body.position.y = -.1
	floor_body.add_child(floor_shape)
	game.level.add_child(floor_body)
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
	var cases := 0
	for yaw in [0.0,22.5,45.0,90.0,135.0]:
		for strength in [.25,.5,1.0]:
			for pattern in ["forward","strafe","diagonal"]:
				game.player.position = Vector3.ZERO
				game.player.velocity = Vector3.ZERO
				game.player.rotation.y = deg_to_rad(yaw)
				driver.expected = Vector2.ZERO
				driver.failed = false
				if pattern != "strafe": Input.action_press("move_forward",strength)
				if pattern != "forward": Input.action_press("move_right",strength)
				for phase in ["start","reverse","stop"]:
					if phase == "stop":
						Input.action_release("move_back")
						Input.action_release("move_left")
					if phase == "reverse":
						Input.action_release("move_forward")
						Input.action_release("move_right")
						if pattern != "strafe": Input.action_press("move_back",strength)
						if pattern != "forward": Input.action_press("move_left",strength)
					var axes := Input.get_vector("move_left","move_right","move_forward","move_back")
					var world: Vector3 = game.player.basis * Vector3(axes.x,0,axes.y)*9.0
					driver.target = Vector2(world.x,world.z)
					driver.label = "yaw="+str(yaw)+" strength="+str(strength)+" pattern="+pattern+" "+phase
					if phase == "reverse" and not driver.expected.dot(driver.target) < 0:
						push_error("Reverse must start at nonzero opposing velocity")
						game.free()
						driver.free()
						quit(1)
						return
					driver.travelled = 0.0
					driver.ticks = 0
					driver.set_physics_process(true)
					while driver.ticks < 24 and not driver.failed: await physics_frame
					driver.set_physics_process(false)
					if driver.failed:
						game.free()
						driver.free()
						quit(1)
						return
					if not Vector2(game.player.velocity.x,game.player.velocity.z).is_equal_approx(driver.target):
						push_error("Movement failed to reach target: "+driver.label)
						game.free()
						driver.free()
						quit(1)
						return
					if not game.player.is_on_floor() or (phase != "stop" and driver.travelled <= 0):
						push_error("Real floor contact and active-phase travel required: "+driver.label)
						game.free()
						driver.free()
						quit(1)
						return
					cases += 1
				for action in ["move_left","move_right","move_forward","move_back"]: Input.action_release(action)
	game.free()
	driver.free()
	await process_frame
	print("PASS native movement: ",cases," rotated analog forward/strafe/diagonal start-full-reverse-stop cases with displacement/floor witnesses; real capsule/physics callback")
	quit()
