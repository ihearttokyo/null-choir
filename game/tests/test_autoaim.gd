extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scripts/main.gd").new()
	root.add_child(game)
	game.start_campaign(1)
	game.set_process(false)
	game.player.set_physics_process(false)
	game.settings.auto_aim = true
	for actor in game.enemies:
		actor.set_physics_process(false)
		actor.collision_layer = 0
	var target = game.enemies.filter(func(actor): return actor.kind == "crawler")[0]
	target.collision_layer = 4
	target.position = game.player.position+Vector3(0,0,-15)
	var wall = game.level._box(Vector3(4,4,0.2),game.player.position+Vector3(0,2,-20),game.level._material(Color.GRAY),true)
	await physics_frame
	await physics_frame
	var hp = target.hp
	game.player.fire()
	if not expect(target.hp == hp-22,"Classic auto-aim must hit a visible low enemy with a wall behind it"): return
	# A nearer world obstruction must still prevent the assisted shot.
	wall.position.z = game.player.position.z-8
	await physics_frame
	await physics_frame
	game.player.cooldown = 0
	hp = target.hp
	game.player.fire()
	if not expect(target.hp == hp,"Classic auto-aim cannot shoot through world geometry"): return
	wall.collision_layer = 0
	var hidden = game.enemies.filter(func(actor): return actor.kind == "crawler" and actor != target)[0]
	hidden.collision_layer = 4
	hidden.position = game.player.position+Vector3(-0.6,0,-10)
	target.position = game.player.position+Vector3(0.9,0,-15)
	game.level._box(Vector3(0.8,4,0.25),game.player.position+Vector3(-0.3,2,-5),game.level._material(Color.GRAY),true)
	await physics_frame
	await physics_frame
	game.player.cooldown = 0
	hp = target.hp
	var hidden_hp = hidden.hp
	game.player.fire()
	if not expect(target.hp == hp-22 and hidden.hp == hidden_hp,"Occluded nearer candidate must not suppress exposed crawler assistance"): return
	game.pause_game()
	paused = false
	print("PASS native classic auto-aim: visible low target with background wall; occlusion still blocks damage")
	game._finish_quit()

func expect(condition: bool, detail: String) -> bool:
	if not condition:
		push_error(detail)
		quit(1)
	return condition
