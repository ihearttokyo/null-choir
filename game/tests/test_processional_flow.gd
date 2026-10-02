extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var game = load("res://scripts/main.gd").new()
	game.settings_path = "user://processional_flow_preferences.json"
	game.progress_path = "user://processional_flow_campaign.json"
	root.add_child(game)
	AudioServer.set_bus_mute(0,true)
	game.state.new_campaign(0)
	game.state.level_index = 1
	game.start_level()
	game.set_process(false)
	game.player.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)
	game.state.discover(1)
	game.state.ammo[1] = 111
	game.collect_key("foundry_blood")
	game.collect_key("foundry_ivory")
	game.unlock_door("foundry_gate")
	game.player.position = game.level.layout.world_position([12.5,2.2])
	game.player.rotation.y = 0
	await physics_frame
	await physics_frame
	Input.action_press("interact")
	game.player.set_physics_process(true)
	await physics_frame
	await process_frame
	Input.action_release("interact")
	if not expect(game.state.level_index == 2 and not game.playing and game.level == null and game.state.position == Vector3.ZERO,"Actual Foundry exit tick must advance once and preserve next spawn"): return
	var descend: Button
	for node in game.menu.get_children():
		if node is Button and node.text == "Descend to The Processional": descend = node
	if not expect(descend != null,"Foundry intermission must offer Processional"): return
	descend.pressed.emit()
	if not expect(game.playing and game.level.layout.data.id == "processional" and game.state.position == game.level.layout.world_position(game.level.layout.data.spawn),"Descend must enter the real third map at its own checkpoint"): return
	game.player.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)
	if not expect(game.state.ammo[1] == 111 and game.state.discoveries == [1],"Campaign resources and discoveries persist"): return
	game.player.position = game.level.layout.world_position([20.5,25.5])
	game._process(0)
	if not expect(game.state.owned_weapons == [0,1,2] and game.state.weapon == 2 and game.state.ammo[2] == 16,"Actual entry pickup must introduce and select the scattergun"): return
	game._process(0)
	if not expect(game.state.ammo[2] == 16,"Entry pickup cannot grant duplicate shells"): return
	game.player.position = game.level.layout.world_position([1.2,13.5])
	game.player.rotation.y = PI/2
	await physics_frame
	await physics_frame
	game.interact()
	if not expect(game.state.discoveries == [1,2],"Third clue must be reachable through actual native interaction"): return
	game.collect_key("processional_blood")
	game.collect_key("processional_ivory")
	if not expect(game.unlock_door("processional_gate"),"Both earned seals open the actual exit gate"): return
	game.player.position = game.level.layout.world_position([16.5,8.5])
	game._process(0)
	if not expect(game.state.checkpoint_id == "processional_checkpoint","Automatic checkpoint requires the earned seals"): return
	game.player.cooldown = 0
	if not expect(game.player.fire() and game.state.ammo[2] == 15,"Real scattergun firing consumes one shell"): return
	game.hurt_player(300)
	game.restore_checkpoint()
	if not expect(game.playing and game.state.health == 100 and game.state.ammo[2] == 16 and game.state.weapon == 2,"Death restores third-map checkpoint weapon/resources"): return
	game.save_and_title()
	game.continue_campaign()
	if not expect(game.playing and game.state.discoveries == [1,2] and game.state.owned_weapons == [0,1,2],"Save Continue retains Processional and earned inventory"): return
	game.restart_level()
	if not expect(game.state.checkpoint_id == "entry" and game.state.owned_weapons == [0,1] and game.state.ammo[1] == 111,"Restart restores third-map entry resources before scattergun acquisition"): return
	var progress = game.progress_path
	game.show_title()
	game.queue_free()
	paused = false
	await process_frame
	await process_frame
	if FileAccess.file_exists(progress): DirAccess.remove_absolute(progress)
	print("PASS actual Foundry exit input, third-map descent/entry, one-shot scattergun, optional clue, seals, checkpoint/death/save Continue/restart")
	quit()

func expect(condition: bool, detail: String) -> bool:
	if not condition:
		push_error(detail)
		quit(1)
	return condition
