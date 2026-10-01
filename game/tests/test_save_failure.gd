extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var blocker = "user://save_contract_parent_"+str(Time.get_ticks_usec())
	var file = FileAccess.open(blocker,FileAccess.WRITE)
	file.store_string("Owned save failure fixture")
	file.close()
	var game = load("res://scripts/main.gd").new()
	game.progress_path = blocker+"/campaign.json"
	root.add_child(game)
	game.start_campaign(1)
	game.state.ammo[1] = 17
	game.pause_game()
	var current = game.level
	game.save_and_title()
	if game.level != current or game.state.ammo[1] != 17 or not game.message.begins_with("SAVE FAILED"):
		push_error("Save failure must preserve paused scene/resources and report failure")
		quit(1)
		return
	if game.quit_game() or game.level != current or not paused:
		push_error("Failed close save must preserve paused scene")
		quit(1)
		return
	DirAccess.remove_absolute(blocker)
	game.show_title()
	game.queue_free()
	paused = false
	print("PASS failed save-and-title/close retain session and show error")
	quit()
