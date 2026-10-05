extends SceneTree

var game
var prefix = "user://reliquary_flow_"+str(OS.get_process_id())

func _initialize() -> void: call_deferred("run")

func run() -> void:
	game = load("res://scripts/main.gd").new()
	game.settings_path = prefix+"_preferences.json"
	game.progress_path = prefix+"_progress.json"
	root.add_child(game)
	AudioServer.set_bus_mute(0,true)
	game.state.new_campaign(0)
	game.state.level_index = 2
	game.state.owned_weapons = [0,1,2]
	game.state.ammo[1] = 111
	game.state.ammo[2] = 3
	game.start_level()
	freeze()
	game.state.discover(2)
	game.collect_key("processional_blood")
	game.collect_key("processional_ivory")
	game.unlock_door("processional_gate")
	game.player.position = game.level.layout.world_position([15.5,2.2])
	game.player.rotation.y = 0
	await physics_frame
	await physics_frame
	Input.action_press("interact")
	game.player.set_physics_process(true)
	await physics_frame
	await process_frame
	Input.action_release("interact")
	if not expect(game.state.level_index == 3 and not game.playing and game.level == null and game.state.position == Vector3.ZERO,"Actual third-map exit input advances once without overwriting fourth entry"): return
	var descend: Button
	for node in game.menu.get_children():
		if node is Button and node.text == "Descend to The Reliquary": descend = node
	if not expect(descend != null,"Native intermission offers the actual fourth map"): return
	descend.pressed.emit()
	freeze()
	if not expect(game.playing and game.level.layout.data.id == "reliquary" and game.state.position == game.level.layout.world_position([19.5,38.5]),"Descent loads Reliquary at its own safe entry checkpoint"): return
	if not expect(game.music.player.file == "res://audio/reliquary.mid" and game.state.ammo[1] == 111 and game.state.discoveries == [2],"Fourth live MIDI and carried campaign resources/story persist"): return
	game.player.cycle_weapon(1)
	game.player.position = game.level.layout.world_position([19.5,32.5])
	game._process(0)
	if not expect(game.state.owned_weapons == [0,1,2] and game.state.weapon == 2 and game.state.ammo[2] == 19,"Actual fourth-map pickup retains selected existing scattergun and adds sixteen shells"): return
	game._process(0)
	if not expect(game.state.ammo[2] == 19,"Collected entry weapon cannot duplicate ammunition"): return
	game.player.position = game.level.layout.world_position([1.35,16.5])
	game.player.rotation.y = PI/2
	await physics_frame
	await physics_frame
	game.interact()
	if not expect(game.state.discoveries == [2,3] and "reliquary_story" in game.state.removed,"Actual optional command-channel clue is interactable and persists once"): return
	game.player.position = game.level.layout.world_position([19.5,10.5])
	game._process(0)
	if not expect(game.state.checkpoint_id == "entry" and not game.unlock_door("reliquary_index_gate"),"Neither checkpoint nor exit gate bypasses earned seals"): return
	game.collect_key("reliquary_blood")
	game._process(0)
	if not expect(game.state.checkpoint_id == "entry" and not game.unlock_door("reliquary_index_gate"),"One seal cannot release the gate or commit recovery"): return
	game.collect_key("reliquary_ivory")
	game._process(0)
	if not expect(game.state.checkpoint_id == "reliquary_checkpoint" and not "encounter:reliquary_catalogue" in game.state.removed and game.unlock_door("reliquary_index_gate"),"Both seals store checkpoint before catalogue commitment and release actual gate"): return
	game.player.position = game.level.layout.world_position([19.5,9.25])
	game._process(0)
	if not expect("encounter:reliquary_catalogue" in game.state.removed,"Crossing the final threshold activates authored catalogue encounter"): return
	game.player.cooldown = 0
	if not expect(game.player.fire() and game.state.ammo[2] == 18,"Actual fourth-map firing consumes one shell"): return
	game.hurt_player(300)
	await game.restore_checkpoint()
	freeze()
	if not expect(game.playing and game.state.health == 100 and game.state.ammo[2] == 19 and game.state.weapon == 2 and not "encounter:reliquary_catalogue" in game.state.removed,"Death restores exact pre-catalogue resources and rewinds encounter activation"): return
	game.save_and_title()
	await game.continue_campaign()
	freeze()
	if not expect(game.playing and game.level.layout.data.id == "reliquary" and game.state.discoveries == [2,3] and game.state.ammo[2] == 19,"Saved Continue restores the actual fourth map and earned inventory/discoveries"): return
	await game.restart_level()
	freeze()
	if not expect(game.state.checkpoint_id == "entry" and game.state.ammo[1] == 111 and game.state.ammo[2] == 3 and game.state.weapon == 1 and game.state.discoveries == [2,3],"Restart restores fourth entry inventory and retains permanent discoveries"): return
	cleanup()
	print("PASS actual Processional exit, Reliquary descent/live MIDI, pickup/clue/seals, pre-catalogue checkpoint, firing/death/Continue/restart")
	quit()

func freeze() -> void:
	game.set_process(false)
	game.player.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)

func cleanup() -> void:
	Input.action_release("interact")
	if is_instance_valid(game):
		game.show_title()
		game.free()
	paused = false
	for suffix in ["_progress.json","_progress.json.tmp"]:
		if FileAccess.file_exists(prefix+suffix): DirAccess.remove_absolute(prefix+suffix)

func expect(condition: bool, detail: String) -> bool:
	if not condition:
		push_error(detail)
		cleanup()
		quit(1)
	return condition
