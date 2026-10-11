extends SceneTree

const PassivePhysicsStep = preload("res://tests/passive_physics_step.gd")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var game = load("res://scripts/main.gd").new()
	game.settings_path = "user://transition_preferences.json"
	game.progress_path = "user://transition_campaign.json"
	root.add_child(game)
	AudioServer.set_bus_mute(0,true)
	game.start_campaign(0)
	game.set_process(false)
	game.player.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)
	game.state.discover(0)
	game.state.ammo[1] = 123
	game.collect_key("blood_key")
	game.collect_key("ivory_key")
	game.unlock_door("containment_gate")
	game.player.position = game.level.layout.world_position([14.5,2.2])
	await physics_frame
	await physics_frame
	Input.action_press("interact")
	game.player.set_physics_process(true)
	await physics_frame
	await process_frame
	Input.action_release("interact")
	if not expect(game.state.level_index == 1 and not game.playing and game.level == null,"Native player exit input must advance exactly once"): return
	if not expect(game.state.position == Vector3.ZERO,"Completed player tick must not overwrite the next entry spawn"): return
	var descend: Button
	for node in game.menu.get_children():
		if node is Button and node.text == "Descend to The Foundry": descend = node
	if not expect(descend != null,"Completed Intake must offer the actual next level"): return
	descend.pressed.emit()
	if not expect(game.playing and game.level.layout.data.id == "foundry","Descend must load Foundry"): return
	if not expect(game.state.discoveries == [0] and game.state.ammo[1] == 123,"Resources and story persist across transition"): return
	if not expect(game.state.keys.is_empty() and game.state.removed.is_empty(),"Per-level pickups and keys must reset"): return
	if not expect(game.state.checkpoint_id == "entry" and game.state.position == game.level.layout.world_position(game.level.layout.data.spawn),"New entry checkpoint belongs to Foundry"): return
	game.player.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)
	game.player.position = game.level.layout.world_position([2.2,13.5])
	game.player.rotation.y = PI/2
	await physics_frame
	await physics_frame
	game.interact()
	if not expect(game.state.discoveries == [0,1],"Foundry clue must be reachable through native interaction"): return
	game.collect_key("foundry_blood")
	game.collect_key("foundry_ivory")
	if not expect(game.unlock_door("foundry_gate"),"Both Foundry keys open its actual gate"): return
	game.player.position = game.level.layout.world_position([16.5,8.5])
	if not expect(await PassivePhysicsStep.scan(game),"Actual passive physics step completes with the staged player/map"): return
	game._process(0)
	if not expect(game.state.checkpoint_id == "foundry_checkpoint","Authored automatic checkpoint must trigger"): return
	game.hurt_player(300)
	await game.restore_checkpoint()
	if not expect(game.playing and game.state.health == 100 and game.level.layout.data.id == "foundry","Death restores current map checkpoint"): return
	game.save_and_title()
	await game.continue_campaign()
	if not expect(game.playing and game.level.layout.data.id == "foundry" and game.state.discoveries == [0,1],"Saved Continue must retain Foundry"): return
	await game.restart_level()
	if not expect(game.state.checkpoint_id == "entry" and game.state.ammo[1] == 123,"Restart keeps Foundry entry resources"): return
	var test_path = game.progress_path
	game.show_title()
	game.queue_free()
	paused = false
	await process_frame
	await process_frame
	if FileAccess.file_exists(test_path): DirAccess.remove_absolute(test_path)
	print("PASS native Intake-to-Foundry intermission, resources/story persistence, checkpoint death, save Continue and level restart")
	quit()

func expect(condition: bool, detail: String) -> bool:
	if not condition:
		push_error(detail)
		quit(1)
	return condition
