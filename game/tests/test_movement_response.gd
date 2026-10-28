extends SceneTree

class TestGame extends Node3D:
	var state = preload("res://scripts/campaign.gd").new()
	var settings = {"auto_aim":false,"sensitivity":1.0,"invert_y":false,"head_bob":false,"camera_shake":false}
	var playing = true
	var level: Node3D
	var player

class Driver extends Node:
	var player
	var axes := Vector2.ZERO
	var running := false
	var retained := Vector2.ZERO
	var reference := Vector2.ZERO
	var clock := 0.0
	var boundary := 0.0
	var commanded := false
	var ticks := 0
	var failed := false
	var label := ""
	var travelled := 0.0
	func reset() -> void:
		retained = Vector2.ZERO
		reference = Vector2.ZERO
		clock = 0.0
		boundary = 0.0
		commanded = false
		failed = false
	func _physics_process(delta: float) -> void:
		# Absolute-time overlap oracle; independent of production phase/helper state.
		var end := clock+delta
		var wanted := Vector2.ZERO
		var grounded: bool = player.is_on_floor()
		while clock < end-1.0e-12:
			if clock >= boundary-1.0e-12:
				var right := Vector2(player.basis.x.x,player.basis.x.z)
				var ahead := Vector2(-player.basis.z.x,-player.basis.z.z)
				reference = retained
				commanded = axes != Vector2.ZERO
				if grounded: reference += (right*axes.x*(40.0 if running else 24.0)+ahead*axes.y*(50.0 if running else 25.0))/32.0
				reference = Vector2(clampf(reference.x,-30.0,30.0),clampf(reference.y,-30.0,30.0))
				boundary += 1.0/35.0
			var until := minf(end,boundary)
			wanted += reference*((until-clock)*0.7)
			clock = until
			if clock >= boundary-1.0e-12:
				retained = reference
				if grounded:
					if not commanded and absf(retained.x) < 0.0625 and absf(retained.y) < 0.0625: retained = Vector2.ZERO
					else: retained *= 0.90625
		var before: Vector3 = player.position
		player._physics_process(delta)
		var actual := Vector2(player.position.x-before.x,player.position.z-before.z)
		travelled += actual.length()
		if actual.distance_to(wanted) > .00005 or Vector2(player.velocity.x,player.velocity.z).distance_to(wanted/delta) > .00005:
			failed = true
			push_error("Native Doom movement "+label+" callback="+str(ticks)+" expected displacement="+str(wanted)+" actual="+str(actual))
		ticks += 1

func _initialize() -> void: call_deferred("run")

func run() -> void:
	preload("res://scripts/preferences.gd").new().apply_bindings()
	for action in ["move_left","move_right","move_forward","move_back","run","fire","interact"]: Input.action_release(action)
	# Ninety independent cases; use --movement-case=0..89 for bounded native shards.
	var selected := -1
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--movement-case="):
			var value := argument.trim_prefix("--movement-case=")
			if selected != -1 or not value.is_valid_int() or int(value) < 0 or int(value) >= 90:
				push_error("Invalid movement case selector")
				quit(1)
				return
			selected = int(value)
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
	var ordinal := 0
	for yaw in [0.0,22.5,45.0,90.0,135.0]:
		for strength in [.25,.5,1.0]:
			for pattern in ["forward","strafe","diagonal"]:
				for running in [false,true]:
					var current := ordinal
					ordinal += 1
					if selected >= 0 and current != selected: continue
					game.player.position = Vector3.ZERO
					game.player.cancel_actions()
					game.player.rotation.y = deg_to_rad(yaw)
					driver.reset()
					driver.running = running
					if running: Input.action_press("run")
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
						driver.axes = Vector2(Input.get_axis("move_left","move_right"),Input.get_axis("move_back","move_forward"))
						driver.label = "case="+str(current)+" "+phase
						if phase == "reverse":
							var desired: Vector3 = game.player.basis*Vector3(driver.axes.x,0,-driver.axes.y)
							if not driver.retained.dot(Vector2(desired.x,desired.z)) < 0:
								push_error("Reverse must start against nonzero momentum")
								await finish(game,driver,1)
								return
						driver.travelled = 0.0
						driver.ticks = 0
						driver.set_physics_process(true)
						var count := 120 if phase == "stop" else 24
						while driver.ticks < count and not driver.failed: await physics_frame
						driver.set_physics_process(false)
						if driver.failed or not game.player.is_on_floor() or (phase != "stop" and driver.travelled <= 0):
							push_error("Floor contact/active travel/reference required: "+driver.label)
							await finish(game,driver,1)
							return
						if phase == "stop" and (driver.retained != Vector2.ZERO or Vector2(game.player.velocity.x,game.player.velocity.z).length() > .00005):
							push_error("Released movement must finish at zero after its friction tail")
							await finish(game,driver,1)
							return
						cases += 1
					for action in ["move_left","move_right","move_forward","move_back","run"]: Input.action_release(action)
	if cases != (3 if selected >= 0 else 270):
		push_error("Missing movement cases")
		await finish(game,driver,1)
		return
	print("PASS native movement: ",cases," rotated analog/digital walk/run forward/strafe/diagonal start/reverse/coast-stop cases; real displacement/floor witnesses")
	await finish(game,driver,0)

func finish(game: Node, driver: Node, code: int) -> void:
	for action in ["move_left","move_right","move_forward","move_back","run","fire","interact"]: Input.action_release(action)
	game.free()
	driver.free()
	await process_frame
	quit(code)
