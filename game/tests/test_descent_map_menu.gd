extends SceneTree

const Main = preload("res://scripts/main.gd")
const Narrative = preload("res://scripts/narrative.gd")
var game

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func button(text: String):
	for node in game.menu.get_children():
		if node is Button and node.text == text: return node
	return null

func run() -> void:
	var prefix: String = "user://descent_menu_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	game = Main.new()
	game.settings_path = prefix+"_preferences.json"
	game.progress_path = prefix+"_campaign.json"
	root.add_child(game)
	game.set_process(false)
	game.state.new_campaign(1)
	await game.start_level()
	assert(game.playing and not game.placement_pending)
	game.pause_game()
	var before: Dictionary = game.state.to_dict().duplicate(true)
	assert(button("Descent map") != null)
	button("Descent map").pressed.emit()
	assert(game.menu.get_child(0).text == "DESCENT MAP" and paused and not game.playing)
	assert(game.menu.get_child_count() == 5) # Existing accessible text plus illustrated chart.
	var map_body: RichTextLabel = game.menu.get_child(3)
	var chart = game.menu.get_child(4)
	var animation: CheckButton = chart.get_child(0)
	var illustration = chart.get_child(1)
	assert(illustration.rows.size() == 8 and illustration.textures.keys() == [0])
	assert(not animation.button_pressed and not illustration.is_processing())
	animation.button_pressed = true
	await process_frame
	await process_frame
	assert(illustration.is_processing() and illustration.phase > 0.0)
	animation.button_pressed = false
	assert(not illustration.is_processing() and illustration.phase == 0.0)
	illustration.rows[0].name = "Detached presentation mutation"
	assert(game.state.to_dict() == before)
	assert("01  The Intake" in map_body.text and "08  Uncharted descent" in map_body.text and not "The Heart" in map_body.text)
	map_body.grab_focus()
	await process_frame
	await process_frame
	assert(map_body.size.x <= game.menu_scroll.size.x)
	var scroll = map_body.get_v_scroll_bar()
	for step in range(16):
		var key = InputEventKey.new()
		key.keycode = KEY_PAGEDOWN
		key.pressed = true
		root.push_input(key)
		key = key.duplicate()
		key.pressed = false
		root.push_input(key)
		await process_frame
	assert(scroll.value > 0 and scroll.value >= scroll.max_value-scroll.page-.01)
	for node in game.menu.get_children():
		assert(not (node is Button and node.text.begins_with("Read: ")))
	game.show_descent_record(0,game.pause_game)
	assert(game.menu.get_child(0).text == "DESCENT MAP")
	assert(game.state.to_dict() == before)
	button("Back").pressed.emit()
	assert(game.menu.get_child(0).text == "PAUSED")
	button("Resume").pressed.emit()
	assert(game.playing and not paused and not game.menu_scroll.visible)
	game.show_descent_map(game.pause_game)
	assert(game.playing and not game.menu_scroll.visible)
	game.pause_game()
	var retired_button = button("Descent map")
	var navigation = game.level.get_node_or_null("NavigationRoutes")
	var pending_navigation: Array[WeakRef] = []
	if navigation != null and navigation._baking.has("mesh"):
		pending_navigation.append(weakref(navigation._baking.mesh))
		pending_navigation.append(weakref(navigation._baking.source))
	game.show_title()
	retired_button.pressed.emit()
	assert(game.menu.get_child(0).text == "NULL CHOIR")
	# Arranged completion/discovery tests presentation, not earned traversal.
	for index in range(8): game.state.complete_level()
	game.state.discover(0)
	game.show_ending()
	before = game.state.to_dict().duplicate(true)
	button("Descent map").pressed.emit()
	var completed_chart = game.menu.get_child(4).get_child(1)
	assert(completed_chart.textures.size() == 8 and completed_chart.rows.all(func(row): return row.status == "CLEARED"))
	assert(not completed_chart.is_processing())
	var read = button("Read: "+Narrative.RECORDS[0].title)
	assert(read != null)
	read.pressed.emit()
	assert(game.menu.get_child(0).text == Narrative.RECORDS[0].title)
	var bodies = game.menu.get_children().filter(func(node): return node is RichTextLabel)
	assert(bodies.size() == 1 and bodies[0].text == Narrative.RECORDS[0].body)
	button("Back to descent map").pressed.emit()
	assert(game.menu.get_child(0).text == "DESCENT MAP" and game.state.to_dict() == before)
	game.state.discoveries.clear() # Negative stale-unlock case.
	game.show_descent_map(game.show_ending)
	game.show_descent_record(0,game.show_ending)
	game.show_descent_record(-1,game.show_ending)
	game.show_descent_record(8,game.show_ending)
	assert(game.menu.get_child(0).text == "DESCENT MAP")
	game.music.stop()
	game.effects.stop()
	paused = false
	game.queue_free()
	await process_frame
	await process_frame
	# Scene retirement may leave the native async bake owning its input resources.
	# Wait for that actual owned operation, rather than assuming a timer drains it.
	var deadline: int = Time.get_ticks_usec()+2000000
	while pending_navigation.any(func(reference): return reference.get_ref() != null):
		assert(Time.get_ticks_usec() < deadline)
		await process_frame
		await physics_frame
	await create_timer(0.12).timeout
	print("PASS native illustrated descent-map menus: earned-only texture reveals, detached presentation, opt-in animation/static reset,  actual Intake startup, pause/back/resume, no state writes or unearned records, retired caller rejection and controlled ending/record navigation; not physical-input or campaign completion")
	# Let this resumed signal callback release its coroutine/locals before shutdown.
	call_deferred("quit",0)
