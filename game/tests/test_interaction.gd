extends SceneTree

func _initialize(): call_deferred("run")

func run():
	var game = load("res://scripts/main.gd").new()
	root.add_child(game)
	await process_frame
	game.start_campaign(1)
	game.player.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)
	var key = game.level.layout.world_position([3.5,13.5])
	game.player.position = key+Vector3(0,0.04,3)
	game.player.rotation = Vector3.ZERO
	var wall = game.level._box(Vector3(2,3,0.5),key+Vector3(0,1.5,1.5),StandardMaterial3D.new(),true)
	await physics_frame
	if not expect(game.nearest_interaction().is_empty()): return
	wall.queue_free()
	await physics_frame
	await physics_frame
	if not expect(game.nearest_interaction().get("id") == "blood_key"): return
	game.interact()
	if not expect("blood" in game.state.keys and "blood_key" in game.state.removed): return
	game.playing = false
	print("PASS native interaction ray: blocked by world wall, then visible key can be recovered")
	game.queue_free()
	quit()

func expect(condition: bool) -> bool:
	if not condition:
		push_error("Interaction occlusion contract failed")
		quit(1)
	return condition
