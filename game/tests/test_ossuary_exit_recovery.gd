extends SceneTree

const Exit = preload("res://tests/ossuary_finale_exit_witness.gd")
const Main = preload("res://scripts/main.gd")

class MenuProbe:
	extends "res://tests/ossuary_finale_exit_witness.gd"
	# Controlled menu/file predicate only; earned identity is checked by the route.
	func cx_identity() -> bool: return true

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func check(value: bool, label: String) -> bool:
	if not value: push_error(label)
	return value

func run() -> void:
	var ok: bool = true
	var game = Main.new()
	game.progress_path = "user://CONTROLLED_c_documents_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())+".json"
	game.settings_path = game.progress_path+"_preferences"
	game.state.new_campaign(1)
	game.state.actors = []
	game.level = game.Level.new()
	game.add_child(game.level)
	ok = check(game.level.layout.load_level(0),"SETUP real Intake metadata for capture rejection") and ok
	game.player = game.Player.new()
	game.level.add_child(game.player)
	game.player.camera = Camera3D.new()
	game.player.add_child(game.player.camera)
	game._scene_level_index = 0
	game.state.yaw = -0.7
	game.state.pitch = -0.2
	game.player.rotation.y = 0.8
	game.player.camera.rotation.x = 0.4
	var before: Dictionary = game.state.to_dict().duplicate(true)
	var captured: Dictionary = before.duplicate(true)
	captured.yaw = game.Enemy.canonical_yaw(game.player.rotation.y)
	captured.pitch = clampf(game.player.camera.rotation.x,-1.35,1.35)
	# Known-complete empty actors cannot capture an actual map's missing live roster.
	ok = check(not game._capture_actor_state() and game.state.to_dict() == before,"Production capture refusal preserves distinct valid cached angles") and ok
	var predicted: Dictionary = Exit.before_capture_document(captured,before.actors,before.yaw,before.pitch)
	ok = check(predicted == before and captured.yaw != before.yaw and captured.pitch != before.pitch,"NATIVE RED failed first capture predicts cached, not live, angles") and ok
	predicted.actors.append({"controlled":true})
	ok = check(before.actors.is_empty() and captured.actors.is_empty(),"Before-capture prediction owns actor arrays without aliasing snapshots") and ok
	game.level.free()
	game.level = null
	game.player = null
	game._scene_level_index = -1
	root.add_child(game)
	await process_frame
	ok = check(game.state.from_dict(Exit.entry_document(game.state._resources())),"SETUP actual canonical Inversion entry document") and ok
	ok = check(game.state.save_progress(game.progress_path) == OK,"SETUP isolated real atomic entry save") and ok
	game.show_title()
	game._show_menu("THE OSSUARY RESTORED",[["Descend to The Inversion",game.start_level],["Return to title",game.show_title]])
	var probe = MenuProbe.new()
	probe.game = game
	probe.profile = game.progress_path
	probe.cx_expected = game.state.to_dict().duplicate(true)
	probe.cx_expected_bytes = FileAccess.get_file_as_bytes(game.progress_path)
	probe.cx_expected_sha = FileAccess.get_sha256(game.progress_path)
	ok = check(probe.cx_menu(false),"SETUP actual complete menu and persisted entry are accepted") and ok
	var title_button = game.menu.get_children().filter(func(node): return node is Button and node.text == "Return to title")[0]
	title_button.pressed.disconnect(Callable(game,"show_title"))
	ok = check(not probe.cx_menu(false),"NATIVE RED disconnected Return to title cannot pass exact intermission") and ok
	title_button.pressed.connect(Callable(game,"show_title"))
	game.menu.remove_child(title_button)
	ok = check(not probe.cx_menu(false),"NATIVE RED missing Return to title cannot pass exact intermission") and ok
	game.menu.add_child(title_button)
	var extra = Button.new()
	extra.text = "CONTROLLED unexpected action"
	game.menu.add_child(extra)
	ok = check(not probe.cx_menu(false),"NATIVE RED unexpected extra action cannot pass exact intermission") and ok
	game.menu.remove_child(extra)
	extra.free()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		ok = check(not probe.cx_menu(false),"NATIVE RED captured mouse cannot pass exact intermission") and ok
	else:
		print("NOT RUN captured-mode rejection: native headless backend does not retain mouse capture")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ok = check(probe.cx_menu(false),"Restored complete native menu stays accepted") and ok
	game.queue_free()
	await process_frame
	await process_frame
	paused = false
	ok = check(root.get_child_count() == 0 and not is_instance_valid(game),"Controlled real nodes drain; isolated saves retained") and ok
	if ok: print("PASS CONTROLLED C failed-capture document and exact menu/file/button predicates; no earned C/app/GUI acceptance")
	quit(0 if ok else 1)
