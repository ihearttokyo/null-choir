extends SceneTree

var game

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func run() -> void:
	game = load("res://scripts/main.gd").new()
	var prefix = "user://weapon_pose_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	game.progress_path = prefix+"_campaign.json"
	game.settings_path = prefix+"_preferences.json"
	root.add_child(game)
	game.start_campaign(1)
	game.set_process(false)
	game.player.set_physics_process(false)
	game.player.set_process_unhandled_input(false)
	for actor in game.enemies: actor.set_physics_process(false)
	await physics_frame
	await physics_frame
	await process_frame
	game.set_process(false)
	var player = game.player
	player.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)
	if not expect(player.has_method("weapon_frame"),"A single selected-weapon pose method must serve the actual HUD draw path"): return
	if not expect(FileAccess.get_file_as_string("res://scripts/hud.gd").contains("var frame = player.weapon_frame()"),"Actual HUD draw consumes the tested selected-weapon pose path"): return
	var campaign_before: Dictionary = game.state.to_dict().duplicate(true)
	for index in player.WEAPONS.size():
		game.state.weapon = index
		var interval: float = player.WEAPONS[index].interval
		player.weapon_cooldowns.fill(0.06)
		player.cooldown = 0
		player.shot_flash = 0.12
		if not expect(pure_pose(player)==0,"Unfired selected weapon remains idle despite another weapon's camera flash"): return
		player.cooldown = interval
		player.shot_flash = 0
		if not expect(pure_pose(player)==1,"Every real weapon interval starts with its own firing pose"): return
		player.cooldown = interval*0.25
		if not expect(pure_pose(player)==2,"Every weapon, including the 85ms repeater, reaches recovery before idle"): return
		var clocks_before: Array[float] = player.weapon_cooldowns.duplicate()
		player.weapon_frame()
		player.weapon_frame()
		if not expect(player.weapon_cooldowns == clocks_before,"Reading presentation never advances or resets combat cooldowns"): return
		player.cooldown = 0
	game.state.weapon = campaign_before.weapon
	if not expect(game.state.to_dict() == campaign_before,"Pose derivation never changes ammo, health or campaign state"): return
	game.show_title()
	await create_timer(0.1).timeout
	game.free()
	game = null
	paused = false
	await process_frame
	print("PASS native pose-method boundary checks; real held-fire timing and rendered atlas regions require separate acceptance")
	quit()

func pure_pose(player) -> int:
	var clocks: Array[float] = player.weapon_cooldowns.duplicate()
	var before: Dictionary = game.state.to_dict().duplicate(true)
	var pose: int = player.weapon_frame()
	if not expect(player.weapon_cooldowns==clocks and game.state.to_dict()==before,"Every pose read preserves selected and nonselected clocks and campaign"): return -1
	return pose

func expect(condition: bool, detail: String) -> bool:
	if not condition:
		push_error(detail)
		if is_instance_valid(game):
			game.show_title()
			game.free()
		paused = false
		quit(1)
	return condition
