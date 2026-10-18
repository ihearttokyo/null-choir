extends SceneTree

class ObservedMain extends "res://scripts/main.gd":
	var shots := 0
	var interactions := 0
	func shot(index: int) -> void:
		shots += 1
		super.shot(index)
	func interact() -> void: interactions += 1

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func run() -> void:
	var game := ObservedMain.new()
	var prefix := "user://trigger_replacement_"+str(OS.get_process_id())
	game.progress_path = prefix+"_campaign.json"
	game.settings_path = prefix+"_preferences.json"
	root.add_child(game)
	game.start_campaign(1)
	for tick in range(12): await physics_frame
	var old_player = game.player
	Input.action_press("fire")
	Input.action_press("interact")
	await game.restart_level()
	var before_shots: int = game.shots
	var before_interactions: int = game.interactions
	var distinct: bool = game.player != old_player
	for tick in range(20): await physics_frame
	var good: bool = distinct and game.playing and game.shots == before_shots and game.interactions == before_interactions
	if not good: push_error("Held fire/interact must not leak across actual restart replacement: shots="+str(game.shots-before_shots)+" interactions="+str(game.interactions-before_interactions))
	Input.action_release("fire")
	Input.action_release("interact")
	game.show_title()
	paused = false
	await create_timer(.1,true).timeout
	game.free()
	await process_frame
	await process_frame
	if good: print("PASS actual Main restart replacement cancels held fire/interact; real new Player and native input/physics, not physical controls")
	quit(0 if good else 1)
