extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var game = load("res://scripts/main.gd").new()
	game.settings_path = "user://overhaul_ui_unused.json"
	root.add_child(game)
	game._show_menu("CONTAINMENT RECOVERY / AN EXTENDED TRANSMISSION",[["Return to title",game.show_title]])
	await process_frame
	await process_frame
	var heading = game.menu.get_child(0)
	if not expect(heading.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART,"Long menu headings wrap instead of widening the scroll client"): return
	var button = game.menu.get_child(1)
	if not expect(button.clip_text and button.has_focus(),"Menu actions remain bounded and initially keyboard-focusable"): return
	var focus = button.get_theme_stylebox("focus")
	if not expect(focus is StyleBoxFlat and focus.border_width_left >= 2,"Focused actions have a visible authored outline"): return
	game.show_settings()
	await process_frame
	await process_frame
	var edge = game.menu_scroll.global_position.x+game.menu_scroll.size.x-game.menu_scroll.get_v_scroll_bar().size.x
	for child in game.menu.get_children():
		if child is Control and not expect(child.global_position.x+child.size.x <= edge+1,"Settings stay within the menu client"): return
	game.show_controls()
	await process_frame
	var control = game.menu.get_child(2)
	if not expect(control.clip_text and control.has_focus(),"Rebind rows retain focus and bounded text"): return
	game.free()
	paused = false
	print("PASS native authored menu focus, heading wrapping, settings width and rebind row feedback")
	quit()

func expect(condition: bool, text: String) -> bool:
	if not condition:
		push_error(text)
		quit(1)
	return condition
