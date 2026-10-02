extends SceneTree

func _initialize(): call_deferred("run")

func run():
	var game = load("res://scripts/main.gd").new()
	root.add_child(game)
	await process_frame
	game.start_campaign(1)
	game.player.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)
	await physics_frame
	var worker = game.enemies[0]
	if not expect(worker.sprite.shaded): return
	var crawler = game.enemies[1]
	var before = crawler.hp
	crawler.take_damage(13,worker)
	if not expect(crawler.hp == before-13 and crawler.target == worker): return
	before = worker.hp
	crawler._attack(worker,12)
	if not expect(worker.hp == before-12 and worker.target == crawler): return
	crawler._physics_process(0)
	if not expect(int(crawler.sprite.frame/8) == 3): return
	crawler.take_damage(1000,game.player)
	if not expect(crawler.hp == 0 and crawler.collision_layer == 0 and crawler.id in game.state.removed): return
	var removed_before = game.state.removed.size()
	crawler.take_damage(2,worker)
	if not expect(game.state.removed.size() == removed_before): return
	crawler._physics_process(0)
	if not expect(int(crawler.sprite.frame/8) == 4): return
	game.playing = false
	print("PASS native enemy damage, infighting, attack/death pose and one-shot corpse removal")
	game.queue_free()
	quit()

func expect(condition: bool) -> bool:
	if not condition:
		push_error("Enemy contract assertion failed")
		quit(1)
	return condition
