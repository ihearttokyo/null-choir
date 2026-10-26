extends SceneTree

const AudioRelease = preload("res://tests/recorded_audio_release.gd")
class QuietGame extends "res://scripts/main.gd":
	func _capture_game_mouse() -> void: pass
var game

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func run() -> void:
	game = QuietGame.new()
	game.progress_path = "user://narrative_campaign.json"
	game.settings_path = "user://narrative_preferences.json"
	root.add_child(game)
	if not game.has_method("show_records"):
		push_error("INTENDED RED: earned records need a persistent voluntary reader, not only a timed one-line message")
		await finish(1)
		return
	var narrative = load("res://scripts/narrative.gd")
	assert(narrative.RECORDS.size()==8)
	var ids = ["intake","foundry","processional","reliquary","nursery","ossuary","inversion","heart"]
	for i in range(8):
		var record = narrative.RECORDS[i]
		assert(record.level_id==ids[i] and record.title.length()>5 and record.body.split(" ",false).size()>=200 and record.body.count("\n\n")>=2)
		var layout = game.Level.Layout.new()
		assert(layout.load_level(i))
		var stories = layout.data.interactions.filter(func(spec):return spec.kind=="story")
		assert(stories.size()==1 and stories[0].id==ids[i]+"_story" and stories[0].text.begins_with(record.pickup))
	game.show_records(game.show_title)
	assert(game.menu.get_child(1).text=="Back" and game.menu.get_child(1).has_focus())
	assert(game.menu.get_children().filter(func(node):return node is Button).size()==1)
	assert(game.menu.get_child(2).text.begins_with("No records recovered"))
	game.menu.get_child(1).pressed.emit()
	game.state.new_campaign(0)
	await game.start_level()
	assert(game.playing)
	game.pause_game()
	var pause_buttons = game.menu.get_children().filter(func(node):return node is Button)
	assert(pause_buttons.map(func(node):return node.text)==["Resume","Settings","Restart level","Save and return to title","Recovered records","Descent map"])
	# Reader fixture arranges three discoveries; actual optional collection has its own eight-map test.
	for i in [0,3,7]: game.state.discover(i)
	assert(game._save()==OK)
	var saved_sha = FileAccess.get_sha256(game.progress_path)
	var before = game.state.to_dict().duplicate(true)
	pause_buttons[4].pressed.emit()
	for index in range(3):
		var expected = narrative.RECORDS[[0,3,7][index]]
		var buttons = game.menu.get_children().filter(func(node):return node is Button)
		assert(buttons.size()==4 and buttons[0].has_focus() and buttons[index+1].text==expected.title)
		buttons[index+1].pressed.emit()
		await process_frame
		await process_frame
		assert(not game.playing and paused and game.menu.get_child(0).text==expected.title)
		assert(game.menu.get_child(1).text=="Back to records" and game.menu.get_child(1).has_focus())
		await verify_body(expected.body)
		game.menu.get_child(1).pressed.emit()
		assert(game.state.to_dict()==before and FileAccess.get_sha256(game.progress_path)==saved_sha)
	var title = game.menu.get_child(0).text
	game.show_record(1,game.pause_game)
	assert(game.menu.get_child(0).text==title,"Unearned record must remain inaccessible")
	# Extend coverage after proving that the partial archive hides five records.
	for index in range(8): game.state.discover(index)
	var all_records = game.state.to_dict().duplicate(true)
	for index in range(8):
		game.show_record(index,game.pause_game)
		await process_frame
		await process_frame
		await verify_body(narrative.RECORDS[index].body)
		assert(game.state.to_dict()==all_records and FileAccess.get_sha256(game.progress_path)==saved_sha)
	game.show_records(game.pause_game)
	game.menu.get_child(1).pressed.emit()
	assert(game.menu.get_child(0).text=="PAUSED" and not game.playing and paused)
	game.resume_game()
	assert(game.playing and not paused and not game.menu_scroll.visible)
	assert(await AudioRelease.stop(game))
	for clues in [[],[0,1,2,3,4,5,6],[0,1,2,3,4,5,6,7]]:
		game.state.new_campaign(1)
		for index in range(8): game.state.complete_level()
		for index in clues: game.state.discover(index)
		assert(game._save()==OK)
		saved_sha = FileAccess.get_sha256(game.progress_path)
		before = game.state.to_dict().duplicate(true)
		await game.continue_campaign()
		var expected_title = "YOUR VOICE ISSUED THE FIRST ORDER\nTHE RESTRAINT WAS BUILT AROUND YOU" if clues.size()==8 else "THE RESTRAINT IS OPEN\nTHE VOICE NOW USES YOUR NAME"
		assert(game.menu.get_child(0).text==expected_title)
		assert(game.menu.get_child(4).text=="Descent map")
		assert(game.menu.get_child(5).text==narrative.ENDINGS["complete" if clues.size()==8 else "normal"].body)
		game.menu.get_child(4).pressed.emit()
		assert(game.menu.get_child(0).text=="DESCENT MAP" and game.state.to_dict()==before and FileAccess.get_sha256(game.progress_path)==saved_sha)
		game.menu.get_child(1).pressed.emit()
		assert(game.menu.get_child(0).text==expected_title)
		game.menu.get_child(3).pressed.emit()
		assert(game.menu.get_children().filter(func(node):return node is Button).size()==clues.size()+1)
		game.menu.get_child(1).pressed.emit()
		assert(game.menu.get_child(0).text==expected_title and game.state.to_dict()==before and FileAccess.get_sha256(game.progress_path)==saved_sha)
	print("PASS native earned-only recovered records, complete static lore, keyboard scroll/focus/back, immutable state/disk, pause/resume and0/7/8 saved ending readers; fixtures arrange discoveries, no physical playthrough claimed")
	await finish(0)

func verify_body(expected: String) -> void:
	var body: RichTextLabel = game.menu.get_child(2)
	assert(body.text==expected and body.get_parsed_text()==expected and not body.bbcode_enabled and body.size.x<=game.menu_scroll.size.x)
	assert(body.get_theme_stylebox("normal")==game.menu_scroll.theme.get_stylebox("normal","Button"))
	assert(body.get_theme_stylebox("focus")==game.menu_scroll.theme.get_stylebox("focus","Button") and body.get_theme_color("default_color")==game.menu_scroll.theme.get_color("font_color","Label"))
	body.grab_focus()
	await process_frame
	var bar = body.get_v_scroll_bar()
	var old_scroll = bar.value
	for step in range(16):
		var key = InputEventKey.new()
		key.keycode = KEY_PAGEDOWN
		key.pressed = true
		root.push_input(key)
		key = key.duplicate()
		key.pressed = false
		root.push_input(key)
		await process_frame
	assert(bar.value>old_scroll,"Native keyboard scrolling must reach the long record")
	assert(bar.value>=bar.max_value-bar.page-.01,"Every record's final native text line must be reachable")

func finish(status: int) -> void:
	if is_instance_valid(game): game.show_title()
	paused = false
	await create_timer(.15).timeout
	if is_instance_valid(game): game.free()
	await process_frame
	await process_frame
	quit(status)
