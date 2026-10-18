extends SceneTree

var game
var prefix = "user://ending_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())

func _initialize() -> void: call_deferred("run")

func run() -> void:
	game = load("res://scripts/main.gd").new()
	game.settings_path = prefix+"_preferences.json"
	game.progress_path = prefix+"_campaign.json"
	root.add_child(game)
	AudioServer.set_bus_mute(0,true)
	for clues in [[],[0,1,2,3,4,5,6],[0,1,2,3,4,5,6,7]]:
		game.state.new_campaign(1)
		for index in range(8): game.state.complete_level()
		game.state.discoveries = clues.duplicate()
		if not expect(game._save() == OK,"Actual completed campaign must save before Continue"): return
		await game.continue_campaign()
		var expected = "YOUR VOICE ISSUED THE FIRST ORDER\nTHE RESTRAINT WAS BUILT AROUND YOU" if clues.size() == 8 else "THE RESTRAINT IS OPEN\nTHE VOICE NOW USES YOUR NAME"
		if not expect(game.menu.get_child(0).text == expected,"INTENDED RED: completed saved Continue presents the actual clue-dependent ending"): return
		if not expect(not game.playing and game.level == null and game.state.level_index == 8 and game.state.discoveries == clues,"Ending never starts a ninth map or changes earned discoveries"): return
		await process_frame
		await process_frame
		var label: Label = game.menu.get_child(0)
		if not expect(label.get_visible_line_count() == label.get_line_count() and label.size.x <= game.menu_scroll.size.x,"Native ending title wraps fully within the existing readable menu"): return
		var buttons = game.menu.get_children().filter(func(node): return node is Button)
		if not expect(buttons.size() == 3 and buttons[2].text == "Recovered records" and buttons[0].text == "New campaign" and buttons[1].text == "Return to title" and buttons[0].has_focus(),"Ending retains native keyboard focus and restart/title actions"): return
		buttons[1].pressed.emit()
		if not expect(game.menu.get_child(0).text == "NULL CHOIR" and game.state.level_index == 8,"Return to title preserves the completed save"): return
		await game.continue_campaign()
		game.menu.get_child(1).pressed.emit()
		if not expect(game.menu.get_child(0).text == "RECOVERY PROTOCOL" and game.state.level_index == 8,"New campaign asks for existing difficulty before changing progress"): return
	await finish(0)
	print("PASS native completed Continue, zero/seven/eight-clue revelations, wrapped title, focus and non-destructive ending actions")
	quit()

func expect(condition: bool, detail: String) -> bool:
	if not condition:
		push_error(detail)
		finish.call_deferred(1)
	return condition

func finish(status: int) -> void:
	if is_instance_valid(game): game.show_title()
	paused = false
	await create_timer(.1).timeout
	if is_instance_valid(game): game.free()
	await process_frame
	await process_frame
	for suffix in ["_campaign.json","_campaign.json.tmp","_preferences.json","_preferences.json.tmp"]:
		if FileAccess.file_exists(prefix+suffix): DirAccess.remove_absolute(prefix+suffix)
	if status != 0: quit(status)
