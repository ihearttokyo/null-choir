extends SceneTree

const WallClock = preload("res://tests/wall_clock_wait.gd")
const PassivePhysicsStep = preload("res://tests/passive_physics_step.gd")

func _initialize():
	call_deferred("run")

func run():
	var game = load("res://scripts/main.gd").new()
	game.progress_path = "user://campaign_scene_contract.json"
	root.add_child(game)
	await process_frame
	game.start_campaign(1)
	if not expect(game.playing): return
	if not expect(game.player != null and game.level != null): return
	# Hold automatic callbacks during this controlled passive check.
	game.set_process(false)
	game.player.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)
	if not expect(game.level.doors.has("containment_gate")): return
	if not expect(not game.unlock_door("containment_gate")): return
	game.player.position = game.level.layout.world_position([13.5,10.5])
	if not expect(await PassivePhysicsStep.scan(game)): return
	game._process(0)
	if not expect(game.state.checkpoint_id == "entry"): return
	game.set_process(true)
	game.player.set_physics_process(true)
	for actor in game.enemies: actor.set_physics_process(true)
	game.collect_key("blood_key")
	game.collect_key("ivory_key")
	if not expect(game.state.keys == ["blood","ivory"]): return
	if not expect(game.unlock_door("containment_gate")): return
	if not expect(not game.level.doors.has("containment_gate")): return
	var ammo_before = game.state.ammo[1]
	game.collect_pickup("entry_ammo")
	if not expect(game.state.ammo[1] == ammo_before+35): return
	game.collect_pickup("entry_ammo")
	if not expect(game.state.ammo[1] == ammo_before+35): return
	game.state.mark_checkpoint("scene_contract", game.player.position)
	game.hurt_player(300)
	if not expect(not game.playing and game.state.health == 0): return
	await game.restore_checkpoint()
	if not expect(game.playing and game.state.health > 0 and game.state.ammo[1] == ammo_before+35): return
	await game.restart_level()
	if not expect(game.state.ammo[1] == ammo_before and game.state.keys.is_empty()): return
	game.pause_game()
	if not expect(not game.playing and paused): return
	game.resume_game()
	if not expect(game.playing and not paused): return
	game.state.save_progress(game.progress_path)
	game.show_title()
	if not expect(game.level == null and not game.playing): return
	await game.continue_campaign()
	await game.restart_level()
	if not expect(game.state.ammo[1] == ammo_before): return
	game.pause_game()
	if FileAccess.file_exists(game.progress_path): DirAccess.remove_absolute(game.progress_path)
	paused = false
	game.queue_free()
	await process_frame
	await process_frame
	await WallClock.seconds(self, 0.15)
	if not expect(not is_instance_valid(game)): return
	print("PASS native first-level scene: campaign entry, key gate, one-shot pickup, death restoration and pause/resume")
	quit()

func expect(condition: bool) -> bool:
	if not condition:
		push_error("Gameplay contract assertion failed")
		quit(1)
	return condition
