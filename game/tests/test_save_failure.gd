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
	game.set_process(false)
	game.player.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)
	game.state.ammo[1] = 17
	for spec in game.level.layout.data.interactions:
		if spec.kind != "checkpoint": continue
		game.state.keys = spec.get("requires",[]).duplicate()
		game.player.position = game.level.layout.world_position(spec.cell)
		game._process(0)
		if game.state.checkpoint_id != spec.id or not game.message.begins_with("RECOVERY MEMORY ONLY: SAVE FAILED"):
			push_error("Actual automatic checkpoint disk failure must never display stored-success feedback")
			quit(1)
			return
		break
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
	game.progress_path = "user://dead_continue_"+str(Time.get_ticks_usec())+".json"
	var dead_startups = [0]
	var observe_start = func(_tempo):
		if game.state.health <= 0 and (game.playing or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED): dead_startups[0] += 1
	game.music.player.changed_tempo.connect(observe_start)
	for usable_recovery in [true,false]:
		game.state.health = 0
		game.state.checkpoint.health = 100 if usable_recovery else 0
		game.state.level_start.health = 100 if usable_recovery else 0
		if game._save() != OK:
			push_error("Owned dead-Continue fixture must save successfully")
			quit(1)
			return
		game.show_title()
		game.continue_campaign()
		if dead_startups[0] != 0:
			push_error("Dead Continue must never activate or capture gameplay during synchronous music initialization")
			quit(1)
			return
		if game.playing or not paused or Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
			push_error("Zero-health Continue must display recovery rather than trap controls in dead gameplay")
			quit(1)
			return
		var actions: Array = []
		for node in game.menu.get_children():
			if node is Button: actions.append(node.text)
		if ("Restore checkpoint" in actions) != usable_recovery or ("Restart level" in actions) != usable_recovery or not "Return to title" in actions:
			push_error("Recovery offers only healthy snapshots, with an exit when none exist")
			quit(1)
			return
		if usable_recovery:
			for node in game.menu.get_children():
				if node is Button and node.text == "Restore checkpoint":
					node.pressed.emit()
					break
			if not game.playing or game.state.health != 100:
				push_error("Real recovery menu callback restores a healthy playable checkpoint")
				quit(1)
				return
			game._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
			if game.playing or not paused or not game.music.player.playback_paused:
				push_error("Native focus-loss notification pauses live combat and MIDI")
				quit(1)
				return
			game._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
			if game.playing:
				push_error("Focus return must never resume combat automatically")
				quit(1)
				return
			game.state.health = 0
			game.show_recovery()
			for node in game.menu.get_children():
				if node is Button and node.text == "Restart level":
					node.pressed.emit()
					break
			if not game.playing or game.state.health != 100 or game.state.checkpoint_id != "entry":
				push_error("Real recovery Restart-level button restores healthy entry resources")
				quit(1)
				return
		else:
			game.resume_game()
			if game.playing:
				push_error("No recovery path may resume dead gameplay")
				quit(1)
				return
	DirAccess.remove_absolute(game.progress_path)
	game.music.player.changed_tempo.disconnect(observe_start)
	game.show_title()
	game.queue_free()
	paused = false
	print("PASS actual checkpoint failure feedback, failed save/close, dead Continue, healthy recovery and focus-loss pause")
	quit()
