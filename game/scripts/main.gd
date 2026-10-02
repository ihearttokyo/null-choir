extends Node3D

const Campaign = preload("res://scripts/campaign.gd")
const Level = preload("res://scripts/level.gd")
const Player = preload("res://scripts/player.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Hud = preload("res://scripts/hud.gd")
const Music = preload("res://audio/music.gd")
const Preferences = preload("res://scripts/preferences.gd")
var state = Campaign.new()
var playing: bool = false
var preferences = Preferences.new()
var settings: Dictionary = preferences.values
var progress_path: String = Campaign.SAVE_PATH
var settings_path: String = "user://preferences.json"
var level: Node3D
var player: CharacterBody3D
var music: Node
var enemies: Array = []
var menu: VBoxContainer
var menu_scroll: ScrollContainer
var pending_action: String = ""
var pending_button: Button
var hud: Node2D
var canvas: CanvasLayer
var message: String = ""
var message_time: float = 0
var damage_flash: float = 0
var hit_flash: float = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	if "--verify-export" in OS.get_cmdline_user_args(): AudioServer.set_bus_mute(0,true)
	if FileAccess.file_exists(settings_path) and not preferences.load_file(settings_path): notify("INVALID SETTINGS: USING DEFAULTS",8)
	settings = preferences.values
	music = Music.new()
	add_child(music)
	_apply_volumes()
	preferences.apply_bindings()
	canvas = CanvasLayer.new()
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)
	hud = Hud.new()
	hud.game = self
	canvas.add_child(hud)
	menu = VBoxContainer.new()
	menu.custom_minimum_size.x = 340
	menu_scroll = ScrollContainer.new()
	menu_scroll.position = Vector2(150,45)
	menu_scroll.size = Vector2(340,275)
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_scroll.follow_focus = true
	menu.add_theme_constant_override("separation",9)
	menu_scroll.add_child(menu)
	canvas.add_child(menu_scroll)
	show_title()
	if "--verify-export" in OS.get_cmdline_user_args(): call_deferred("_verify_export")

func _apply_volumes() -> void:
	for bus in ["Music","Effects"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.get_bus_count()-1,bus)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus),linear_to_db(settings[bus.to_lower()+"_volume"]))

func _save_settings() -> void:
	var error = preferences.save(settings_path)
	if error != OK: notify("SETTINGS SAVE FAILED: "+error_string(error),8)

func _input(event: InputEvent) -> void:
	if pending_action.is_empty(): return
	if event is InputEventKey and (event.physical_keycode if event.physical_keycode else event.keycode) in [KEY_SHIFT,KEY_CTRL,KEY_ALT,KEY_META]:
		if event.pressed:
			get_viewport().set_input_as_handled()
			return
		event = event.duplicate()
		event.pressed = true
	if event is InputEventKey and event.pressed and (event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE):
		pending_button.text = _control_text(pending_action)
		pending_action = ""
	elif preferences.bind_event(pending_action,event):
		pending_button.text = _control_text(pending_action)
		pending_action = ""
		_save_settings()
	get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed_by_event("pause",event) and level != null:
		if playing: pause_game()
		elif state.health > 0: resume_game()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: quit_game()

func start_campaign(mode: int) -> void:
	state.new_campaign(mode)
	start_level()

func start_level() -> void:
	get_tree().paused = false
	playing = false
	if level != null: level.queue_free()
	enemies.clear()
	level = Level.new()
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	level.build(self,state.level_index)
	player = Player.new()
	level.add_child(player)
	player.configure(self)
	if state.position == Vector3.ZERO:
		state.mark_checkpoint("entry",level.layout.world_position(level.layout.data.spawn))
	player.position = state.position + Vector3(0,0.04,0)
	player.rotation.y = deg_to_rad(level.layout.data.spawn_yaw)
	for spec in level.layout.data.enemies:
		if spec.id in state.removed: continue
		var actor = Enemy.new()
		level.add_child(actor)
		actor.configure(self,spec)
		enemies.append(actor)
	message = level.layout.data.mission
	message_time = 7
	menu_scroll.hide()
	playing = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if music != null:
		music.set_paused(false)
		music.play_level(state.level_index)

func _process(delta: float) -> void:
	message_time = maxf(0,message_time-delta)
	damage_flash = maxf(0,damage_flash-delta)
	hit_flash = maxf(0,hit_flash-delta)
	if playing and player != null:
		for spec in level.layout.data.pickups:
			if not spec.id in state.removed and player.position.distance_to(level.layout.world_position(spec.cell)) < 1.4:
				collect_pickup(spec.id)
		for spec in level.layout.data.interactions:
			if spec.kind == "checkpoint" and not spec.id in state.removed and player.position.distance_to(level.layout.world_position(spec.cell)) < 3.2 and _has_keys(spec.get("requires",[])):
				state.removed.append(spec.id)
				state.mark_checkpoint(spec.id,player.position)
				_save()
				notify(spec.text)
	hud.queue_redraw()

func _has_keys(required: Array) -> bool:
	for key in required:
		if not key in state.keys: return false
	return true

func collect_key(id: String) -> void:
	if id in state.removed: return
	for spec in level.layout.data.interactions:
		if spec.id == id and spec.kind == "key":
			if not spec.key in state.keys: state.keys.append(spec.key)
			state.removed.append(id)
			level.remove_marker(id)
			notify(spec.text)
			return

func collect_pickup(id: String) -> void:
	if id in state.removed: return
	for spec in level.layout.data.pickups:
		if spec.id != id: continue
		match spec.kind:
			"ammo": state.ammo[spec.weapon] = mini(9999,state.ammo[spec.weapon]+spec.amount)
			"health":
				if state.health >= 100: return
				state.health = mini(100,state.health+spec.amount)
			"armor":
				if state.armor >= 200: return
				state.armor = mini(200,state.armor+spec.amount)
		state.removed.append(id)
		level.remove_marker(id)
		notify("RECOVERED "+spec.kind.to_upper())
		return

func unlock_door(id: String) -> bool:
	for spec in level.layout.data.doors:
		if spec.id == id:
			if not _has_keys(spec.requires):
				notify("BLOOD AND IVORY SEALS REQUIRED")
				return false
			if not id in state.removed: state.removed.append(id)
			level.open_door(id)
			return true
	return false

func nearest_interaction() -> Dictionary:
	if player == null: return {}
	var nearest: Dictionary = {}
	var distance = 4.5
	for spec in level.layout.data.interactions + level.layout.data.doors:
		if spec.id in state.removed or spec.get("kind") == "checkpoint": continue
		var location = level.layout.world_position(spec.cell)
		var d = player.position.distance_to(location)
		if d >= distance: continue
		var aim = location+Vector3(0,spec.size[1]/2 if spec.has("size") else 0.7,0)
		if (-player.camera.global_basis.z).dot((aim-player.camera.global_position).normalized()) < 0.4: continue
		var ray = PhysicsRayQueryParameters3D.create(player.camera.global_position,aim,1)
		var hit = get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.collider != level.doors.get(spec.id): continue
		nearest = spec
		distance = d
	return nearest

func interact() -> void:
	var spec = nearest_interaction()
	if spec.is_empty(): return
	if spec.has("size"):
		unlock_door(spec.id)
		return
	match spec.kind:
		"key": collect_key(spec.id)
		"story":
			state.discover(state.level_index)
			state.removed.append(spec.id)
			level.remove_marker(spec.id)
			notify(spec.text,12)
		"exit":
			if not _has_keys(spec.get("requires",[])): return
			var prior = state.to_dict()
			state.complete_level()
			if _save() != OK:
				state.from_dict(prior)
				return
			show_title()
			_show_menu("INTAKE RESTORED",[["Return to title",show_title]])

func hurt_player(amount: int) -> void:
	if state.health <= 0: return
	state.damage(amount)
	damage_flash = 0.35
	if state.health == 0:
		pause_game()
		_show_menu("RECOVERY FAILED",[["Restore checkpoint",restore_checkpoint],["Restart level",restart_level],["Return to title",show_title]])

func restore_checkpoint() -> void:
	state.restore_checkpoint()
	start_level()

func restart_level() -> void:
	state.restore_level_start()
	start_level()

func pause_game() -> void:
	playing = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if music != null: music.set_paused(true)
	_show_menu("PAUSED",[["Resume",resume_game],["Settings",show_settings],["Restart level",restart_level],["Save and return to title",save_and_title]])

func resume_game() -> void:
	get_tree().paused = false
	playing = true
	menu_scroll.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if music != null: music.set_paused(false)

func _save() -> Error:
	var result = state.save_progress(progress_path)
	if result != OK: notify("SAVE FAILED: "+error_string(result),8)
	return result

func save_and_title() -> void:
	if state.health > 0 and _save() != OK:
		_show_menu("SAVE FAILED",[["Retry save",save_and_title],["Return without saving",show_title],["Back",pause_game]])
		return
	show_title()

func show_title() -> void:
	playing = false
	if level != null:
		level.queue_free()
		level = null
		player = null
		enemies.clear()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if music != null: music.stop()
	_show_menu("NULL CHOIR",[["New campaign",show_difficulty],["Continue",continue_campaign],["Settings",show_settings],["Quit",quit_game]])

func continue_campaign() -> void:
	if not state.load_progress(progress_path):
		notify("NO VALID RECOVERY IMAGE",5)
		return
	if state.level_index >= Level.Layout.FILES.size():
		notify("CAMPAIGN DEVELOPMENT IN PROGRESS",5)
		return
	start_level()

func show_difficulty() -> void:
	_show_menu("RECOVERY PROTOCOL",[["Merciful",func(): start_campaign(0)],["Relentless",func(): start_campaign(1)],["Terminal",func(): start_campaign(2)],["Back",show_title]])

func show_settings() -> void:
	_show_menu("SETTINGS",[])
	for option in [["head_bob","Head bob"],["camera_shake","Camera shake"],["invert_y","Invert Y"],["auto_aim","Classic auto-aim"]]:
		var button = CheckButton.new()
		button.text = option[1]
		button.button_pressed = settings[option[0]]
		button.toggled.connect(func(value):
			settings[option[0]] = value
			_save_settings())
		menu.add_child(button)
	for option in [["sensitivity","Look sensitivity",0.1,4.0,0.05],["music_volume","Music volume",0.0,1.0,0.01],["effects_volume","Effects volume",0.0,1.0,0.01]]:
		var label = Label.new()
		label.text = "%s: %.2f" % [option[1],settings[option[0]]]
		menu.add_child(label)
		var slider = HSlider.new()
		slider.min_value = option[2]
		slider.max_value = option[3]
		slider.step = option[4]
		slider.value = settings[option[0]]
		slider.value_changed.connect(func(value):
			settings[option[0]] = value
			label.text = "%s: %.2f" % [option[1],value]
			_apply_volumes()
			_save_settings())
		menu.add_child(slider)
	_button("Controls",show_controls)
	_button("Restore all defaults",func():
		preferences.reset()
		settings = preferences.values
		_apply_volumes()
		_save_settings()
		show_settings())
	_button("Back",func(): pause_game() if level != null else show_title())
	menu.get_child(1).grab_focus()

func _control_text(action: String) -> String:
	return action.replace("_"," ").capitalize()+": "+preferences.binding_text(action)

func show_controls() -> void:
	_show_menu("CONTROLS",[])
	var label = Label.new()
	label.text = "Select a row, then press a key, mouse button,\nor pad input. Esc cancels. Other device stays bound."
	label.add_theme_font_size_override("font_size",12)
	menu.add_child(label)
	for action in Preferences.ACTIONS:
		var button = Button.new()
		button.text = _control_text(action)
		button.custom_minimum_size.y = 34
		button.add_theme_font_size_override("font_size",14)
		button.pressed.connect(func():
			if not pending_action.is_empty(): pending_button.text = _control_text(pending_action)
			pending_action = action
			pending_button = button
			button.text = action.replace("_"," ").capitalize()+": press input (Esc cancels)")
		menu.add_child(button)
	_button("Back",show_settings)
	menu.get_child(2).grab_focus()

func _show_menu(title: String, actions: Array) -> void:
	pending_action = ""
	pending_button = null
	menu_scroll.scroll_vertical = 0
	menu_scroll.show()
	for child in menu.get_children():
		menu.remove_child(child)
		child.queue_free()
	menu.show()
	var label = Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",32)
	menu.add_child(label)
	for action in actions: _button(action[0],action[1])

func _button(text: String, action: Callable) -> void:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 34
	button.pressed.connect(action)
	menu.add_child(button)
	if menu.get_child_count() == 2: button.grab_focus()

func notify(text: String, duration: float = 3) -> void:
	message = text
	message_time = duration

func shot(_weapon: int) -> void:
	for actor in enemies:
		if is_instance_valid(actor) and actor.hp > 0 and actor.position.distance_to(player.position) < 34:
			actor.alerted = true

func hit_feedback() -> void:
	hit_flash = 0.12

func impact(_point: Vector3) -> void:
	pass

func autoaim_target(origin: Vector3, direction: Vector3, max_range: float) -> Node3D:
	var best: Node3D
	var distance = max_range
	for actor in enemies:
		if not is_instance_valid(actor) or actor.hp <= 0: continue
		var offset = actor.global_position+Vector3(0,0.85,0)-origin
		var range_to_target = offset.length()
		if range_to_target < distance and direction.dot(offset.normalized()) > 0.975:
			var sight = PhysicsRayQueryParameters3D.create(origin,origin+offset,1)
			if not get_world_3d().direct_space_state.intersect_ray(sight).is_empty(): continue
			best = actor
			distance = range_to_target
	return best

func quit_game() -> bool:
	if level != null and state.health > 0 and _save() != OK:
		pause_game()
		_show_menu("SAVE FAILED",[["Retry save and quit",quit_game],["Quit without saving",func(): get_tree().quit()],["Resume",resume_game]])
		return false
	get_tree().quit()
	return true

# Fixed headless workflow for the release binary, which cannot execute external scripts.
func _verify_export() -> void:
	progress_path = "user://export_validation.json"
	var checks = {
		"notices": FileAccess.get_file_as_string("res://licenses/Godot-Third-Party.txt").contains(Engine.get_license_text()),
		"midi_sources": FileAccess.file_exists("res://audio/gate.mid") and FileAccess.file_exists("res://audio/GeneralUser-GS.sf2")}
	start_campaign(1)
	checks["start"] = playing and enemies.size() == 23 and music.player.bank != null
	checks["campaign_midis"] = music.level_tracks.size() == 8
	for track in music.level_tracks: checks["campaign_midis"] = checks["campaign_midis"] and FileAccess.file_exists(track)
	music.player._process(0.2)
	checks["live_midi"] = music.player.position > 0 and music.player.get_now_playing_polyphony() > 0
	player.set_physics_process(false)
	for actor in enemies: actor.set_physics_process(false)
	checks["fire"] = player.fire() and state.ammo[1] == 89
	pause_game()
	checks["pause"] = get_tree().paused and not playing
	restore_checkpoint()
	checks["checkpoint"] = playing and state.ammo[1] == 90
	show_title()
	for check in checks:
		if not checks[check]:
			push_error("Export workflow failed: "+check)
			get_tree().quit(1)
			return
	print("PASS packaged title, start, fire, pause, checkpoint restoration, MIDI source and notices")
	get_tree().quit()
