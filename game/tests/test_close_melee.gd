extends SceneTree

var game

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func run() -> void:
	game = preload("res://scripts/main.gd").new()
	var prefix := "user://close_melee_"+str(OS.get_process_id())
	game.progress_path = prefix+"_campaign.json"
	game.settings_path = prefix+"_preferences.json"
	root.add_child(game)
	game.start_campaign(1)
	game.set_process(false)
	game.player.set_physics_process(false)
	game.settings.auto_aim = true
	game.settings.head_bob = false
	game.settings.camera_shake = false
	for actor in game.enemies:
		actor.set_physics_process(false)
		actor.collision_layer = 0
	var target = game.enemies.filter(func(actor): return actor.kind == "crawler")[0]
	target.collision_layer = 4
	target.active = true
	var origin: Vector3 = game.player.position
	game.player.rotation.y = 0
	game.player.camera.rotation.x = 0
	game.player.camera.position = Vector3(0,1.55,0)
	game.state.weapon = 0
	target.position = origin+Vector3(0,0,-3.4)
	await physics_frame
	await physics_frame
	var hp_before: int = target.hp
	game.player.cooldown = 0
	if not game.player.fire() or target.hp != hp_before:
		push_error("Impact tool must not damage beyond its finite reach")
		await finish(1)
		return
	target.position = origin+Vector3(0,0,-1.8)
	game.settings.auto_aim = false
	await physics_frame
	game.player.cooldown = 0
	hp_before = target.hp
	if not game.player.fire() or target.hp != hp_before:
		push_error("Horizontal assistance-off miss must not secretly redirect")
		await finish(1)
		return
	game.player.camera.look_at(target.global_position+Vector3.UP*.85,Vector3.UP)
	await physics_frame
	await physics_frame
	game.player.cooldown = 0
	hp_before = target.hp
	if not game.player.fire() or target.hp != hp_before-28:
		push_error("Manual downward impact-tool hit must remain valid with assistance disabled")
		await finish(1)
		return
	target.hp = hp_before
	game.player.camera.rotation.x = 0
	game.settings.auto_aim = true
	for distance in [1.0,1.8,2.4]:
		target.position = origin+Vector3(0,0,-distance)
		await physics_frame
		await physics_frame
		game.player.cooldown = 0
		var hp: int = target.hp
		var solution: Dictionary = game.resolve_aim(game.player.camera.global_position,-game.player.camera.global_basis.z,game.player.WEAPONS[0].range,true)
		var contact: Vector3 = solution.contact.get("position",Vector3.INF)
		if not Engine.is_in_physics_frame() or solution.contact.get("collider") != target or solution.actor_id != target.id or not contact.is_finite() or solution.origin.distance_to(contact) > 2.70001:
			push_error("Assisted low-crawler selection must match a finite native first contact within tool reach")
			await finish(1)
			return
		var accepted: bool = game.player.fire()
		print("MEASURE close crawler distance=",distance," camera_y=",game.player.camera.global_position.y," target_y=",target.global_position.y," accepted=",accepted," damage=",hp-target.hp)
		if not accepted or target.hp != hp-28:
			push_error("Horizontal assisted impact tool must hit the actual reachable low crawler at "+str(distance))
			await finish(1)
			return
		target.hp = hp
	target.position = origin+Vector3(0,0,-2.4)
	var wall = game.level._box(Vector3(3,4,.1),origin+Vector3(0,2,-1),null,true)
	await physics_frame
	await physics_frame
	game.player.cooldown = 0
	hp_before = target.hp
	if not game.player.fire() or target.hp != hp_before:
		push_error("Thin world wall must block classic low-crawler correction")
		await finish(1)
		return
	wall.collision_layer = 0
	var blocker = game.enemies.filter(func(actor): return actor.kind == "worker")[0]
	blocker.position = origin+Vector3(0,0,-1.2)
	blocker.collision_layer = 4
	blocker.active = false
	await physics_frame
	await physics_frame
	game.player.cooldown = 0
	var blocker_hp: int = blocker.hp
	hp_before = target.hp
	if not game.player.fire() or target.hp != hp_before or blocker.hp != blocker_hp-28:
		push_error("Manual intervening actor must win over assisted rear crawler, including dormant activation")
		await finish(1)
		return
	blocker.collision_layer = 0
	target.active = false
	await physics_frame
	game.player.cooldown = 0
	hp_before = target.hp
	if not game.player.fire() or target.hp != hp_before:
		push_error("Dormant low crawler must not receive automatic redirection")
		await finish(1)
		return
	game.player.camera.look_at(target.global_position+Vector3.UP*.85,Vector3.UP)
	await physics_frame
	game.player.cooldown = 0
	if not game.player.fire() or target.hp != hp_before-28 or not target.active:
		push_error("Intentional manual dormant hit must retain activation")
		await finish(1)
		return
	print("PASS native close crawler horizontal assisted melee at three finite distances; not physical/GPU/whole aim contract")
	await finish(0)

func finish(code: int) -> void:
	game.show_title()
	paused = false
	await create_timer(.1,true).timeout
	game.free()
	await process_frame
	await process_frame
	quit(code)
