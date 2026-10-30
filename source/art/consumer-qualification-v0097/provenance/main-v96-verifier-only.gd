extends Node3D

const BuildInfo = preload("res://scripts/build_info.gd")
const SealGuardians = preload("res://scripts/seal_guardians.gd")
const EarnedRuntime = preload("res://scripts/earned_supply_runtime.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Narrative = preload("res://scripts/narrative.gd")
const Level = preload("res://scripts/level.gd")
const Player = preload("res://scripts/player.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Hud = preload("res://scripts/hud.gd")
const Music = preload("res://audio/music.gd")
const ExportAudio = preload("res://audio/export_audio_check.gd")
const Effects = preload("res://audio/effects.gd")
const Preferences = preload("res://scripts/preferences.gd")
const AmmoVisuals = preload("res://scripts/ammo_visuals.gd")
const SpriteHitQuery = preload("res://scripts/sprite_hit_query.gd")
var state = Campaign.new()
var earned_runtime = EarnedRuntime.new()
var earned_recovery_only: bool = false
var playing: bool = false
var loaded_positions: bool = false
var placement_pending: bool = false
var preferences = Preferences.new()
var settings: Dictionary = preferences.values
var progress_path: String = Campaign.SAVE_PATH
var settings_path: String = "user://preferences.json"
var level: Node3D
var player: CharacterBody3D
var music: Node
var effects: Node
var enemies: Array = []
var sound_test: Control
var menu: VBoxContainer
var intermission_route: Control
var menu_scroll: ScrollContainer
var pending_action: String = ""
var pending_button: Button
var hud: Node2D
var canvas: CanvasLayer
var message: String = ""
var message_time: float = 0
var damage_flash: float = 0
var hit_flash: float = 0
var quitting: bool = false
var _scene_level_index: int = -1
var aim_observation: Dictionary = {}
var interaction_observation: Dictionary = {}
var _passive_scan_tick: int = -1
var _interaction_edges: Array = []
var _interaction_incoming_eligible: bool = false
var _interaction_pending_player: int = 0
var _interaction_axis_held: Dictionary = {}

func _enter_tree() -> void:
	get_window().window_input.connect(_record_interaction_input)
	get_window().window_input.connect(_record_supply_input)
	Input.joy_connection_changed.connect(_interaction_device_changed)

func fail_earned_transaction(detail: String) -> void:
	# Lethal preparation failed. This scene is POISONED, not a resumable pause.
	# Keep the last good save/checkpoint envelopes; never publish partial defeat.
	earned_recovery_only=true
	playing=false
	placement_pending=false
	_scene_level_index=-1
	if is_instance_valid(player):
		player.cancel_actions()
		player.set_physics_process(false)
		player.collision_layer=0
		player.collision_mask=0
	for actor in enemies:
		if not is_instance_valid(actor): continue
		actor.set_physics_process(false)
		actor.collision_layer=0
		actor.collision_mask=0
	get_tree().paused=true
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if music != null: music.set_paused(true)
	if effects != null: effects.set_paused(true)
	_show_earned_recovery()
	notify(detail,10)

func _show_earned_recovery() -> void:
	var choices: Array = []
	if state.checkpoint.get("health",0)>0: choices.append(["Restore checkpoint",restore_checkpoint])
	if state.level_start.get("health",0)>0: choices.append(["Restart level",restart_level])
	choices.append(["Return without saving",show_title])
	choices.append(["Quit without saving",_finish_quit])
	_show_menu("SUPPLY TRANSACTION FAILED / RECOVERY REQUIRED",choices)

func _record_supply_input(event: InputEvent) -> void:
	if InputMap.has_action("use_asset"): earned_runtime.record_input(self,event)

func queue_use_asset_input(observer: CharacterBody3D, event: InputEvent) -> bool:
	return earned_runtime.queue_use(self,observer,event)

func cancel_supply_input() -> void:
	if InputMap.has_action("use_asset"): earned_runtime.cancel(self)

func reset_supply_sweep() -> void:
	if InputMap.has_action("use_asset"): earned_runtime.reset(self)

func supply_display() -> Dictionary:
	return earned_runtime.display(self)

func earned_defeated(actor) -> bool:
	return earned_runtime.commit_defeat(self,actor)

func _record_interaction_input(event: InputEvent) -> void:
	_interaction_incoming_eligible = false
	if event is InputEventJoypadMotion:
		var held_key := Vector2i(event.device,event.axis)
		if _interaction_axis_held.has(held_key) and (int(signf(event.axis_value)) != _interaction_axis_held[held_key] or absf(event.axis_value) < InputMap.action_get_deadzone("interact")):
			_interaction_axis_held.erase(held_key)
	if event is InputEventJoypadMotion and event.is_action("interact"):
		var key := Vector2i(event.device,event.axis)
		if event.is_action_pressed("interact"):
			var direction: int = int(signf(event.axis_value))
			_interaction_incoming_eligible = _interaction_axis_held.get(key,0) != direction
			_interaction_axis_held[key] = direction
		else: _interaction_axis_held.erase(key)
	else:
		_interaction_incoming_eligible = event.is_action_pressed("interact") and not event.is_echo()
	if not event.is_action_pressed("interact") or event.is_echo(): return
	var tick: int = Engine.get_physics_frames()
	_interaction_edges = _interaction_edges.filter(func(row): return row[1] >= tick)
	# Raw identity survives localization, pause and Player replacement; polls expire next tick.
	_interaction_edges.append([event,tick+1])

func _interaction_device_changed(device: int, connected: bool) -> void:
	earned_runtime.device_changed()
	if connected: return
	for key in _interaction_axis_held.keys():
		if key.x == device: _interaction_axis_held.erase(key)

func _queue_interaction_input(observer: CharacterBody3D) -> void:
	if observer == player and observer._current_map() and playing and _interaction_incoming_eligible:
		_interaction_pending_player = observer.get_instance_id()

func _consume_interaction_input(observer: CharacterBody3D, allow_virtual: bool) -> bool:
	if not Engine.is_in_physics_frame() or observer != player or not observer._current_map() or not playing: return false
	var eligible: bool = _interaction_pending_player == observer.get_instance_id()
	_interaction_pending_player = 0
	var tick: int = Engine.get_physics_frames()
	_interaction_edges = _interaction_edges.filter(func(row): return row[1] >= tick)
	var native_poll: bool = _interaction_edges.any(func(row): return Input.is_action_just_pressed_by_event("interact",row[0]))
	return eligible or (allow_virtual and not native_poll and Input.is_action_just_pressed("interact"))

func _cancel_interaction_input(observer: CharacterBody3D) -> void:
	if _interaction_pending_player == observer.get_instance_id(): _interaction_pending_player = 0

func _ready() -> void:
	get_window().title = BuildInfo.DISPLAY_NAME
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	var sprite_export_probe: bool = "--verify-sprite-hit-export" in OS.get_cmdline_user_args()
	if "--verify-export" in OS.get_cmdline_user_args() or sprite_export_probe: AudioServer.set_bus_mute(0,true)
	if sprite_export_probe:
		# Fail before preferences or other user files can be read.
		var home: String = OS.get_environment("HOME")
		if home.get_file() != "validation-home" or not OS.get_user_data_dir().begins_with(home+"/"):
			push_error("Sprite export validation requires isolated HOME/userdata")
			get_tree().quit(1)
			return
		settings_path = "user://sprite_hit_export_preferences.json"
		progress_path = "user://sprite_hit_export_campaign.json"
	if FileAccess.file_exists(settings_path) and not preferences.load_file(settings_path): notify("INVALID SETTINGS: USING DEFAULTS",8)
	settings = preferences.values
	music = Music.new()
	add_child(music)
	effects = Effects.new()
	effects.name = "Effects"
	add_child(effects)
	_apply_volumes()
	preferences.apply_bindings()
	canvas = CanvasLayer.new()
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)
	hud = Hud.new()
	hud.game = self
	canvas.add_child(hud)
	menu = VBoxContainer.new()
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_scroll = ScrollContainer.new()
	menu_scroll.theme = _menu_theme()
	menu_scroll.position = Vector2(150,45)
	menu_scroll.size = Vector2(340,275)
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_scroll.follow_focus = true
	menu.add_theme_constant_override("separation",9)
	menu_scroll.add_child(menu)
	canvas.add_child(menu_scroll)
	var build_label = Label.new()
	build_label.name = "BuildVersion"
	build_label.text = BuildInfo.DISPLAY_NAME
	build_label.position = Vector2(8,306)
	build_label.add_theme_font_size_override("font_size",8)
	build_label.modulate = Color(.82,.77,.67,.8)
	build_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(build_label)
	show_title()
	if sprite_export_probe: call_deferred("_verify_sprite_hit_export")
	elif "--verify-export" in OS.get_cmdline_user_args(): call_deferred("_verify_export")

func _menu_theme() -> Theme:
	var theme = Theme.new()
	theme.default_font_size = 14
	var ivory = Color(0.87,0.79,0.65)
	var copper = Color(0.45,0.26,0.19)
	for type in ["Button","CheckButton","Label"]:
		theme.set_color("font_color",type,ivory)
		theme.set_color("font_focus_color",type,Color(1.0,0.9,0.72))
		theme.set_color("font_hover_color",type,Color(1.0,0.9,0.72))
		theme.set_color("font_pressed_color",type,ivory)
		theme.set_color("font_disabled_color",type,Color(0.45,0.4,0.34))
	for state_name in ["normal","hover","pressed","disabled","focus"]:
		var box = StyleBoxFlat.new()
		box.bg_color = Color(0.055,0.035,0.045) if state_name == "normal" else Color(0.13,0.065,0.075)
		box.border_color = ivory if state_name == "focus" else copper
		box.set_border_width_all(2 if state_name == "focus" else 1)
		box.content_margin_left = 12
		box.content_margin_right = 12
		box.content_margin_top = 6
		box.content_margin_bottom = 6
		if state_name == "focus": box.draw_center = false
		if state_name == "disabled": box.bg_color = Color(0.035,0.025,0.03)
		theme.set_stylebox(state_name,"Button",box)
	return theme

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
	if pending_button != null: pending_button.tooltip_text = pending_button.text
	get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if playing and Input.is_action_just_pressed_by_event("survey",event):
		hud.survey.toggle()
		get_viewport().set_input_as_handled()
	if Input.is_action_just_pressed_by_event("pause",event) and level != null:
		if playing or placement_pending: pause_game()
		elif state.health > 0: resume_game()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: quit_game()
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and (playing or placement_pending): pause_game()

func start_campaign(mode: int) -> void:
	loaded_positions = false
	state.new_campaign(mode)
	start_level()

func start_level() -> void:
	_close_sound_test()
	if is_instance_valid(player): player.cancel_actions()
	# Reuse the atomic Campaign boundary for all three selected resource envelopes.
	if not state.from_dict(state.to_dict()):
		if not state.level_load_error.is_empty():
			_level_load_failed(state.level_load_error)
			return
		show_title()
		notify("NO VALID RECOVERY IMAGE",8)
		return
	if hud != null: hud.survey.hide()
	get_tree().paused = false
	playing = false
	placement_pending = false
	if loaded_positions and music != null: music.set_paused(true)
	if effects != null:
		effects.stop()
		effects.set_paused(false)
	if level != null: level.queue_free()
	enemies.clear()
	level = Level.new()
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	if not level.build(self,state.level_index):
		_level_load_failed(level.layout.load_error)
		return
	_scene_level_index = state.level_index
	player = Player.new()
	level.add_child(player)
	player.configure(self)
	var fresh_entry: bool = state.position == Vector3.ZERO and not loaded_positions
	if fresh_entry: state.position = level.layout.world_position(level.layout.data.spawn)
	player.position = state.position + Vector3(0,0.04,0)
	player.rotation.y = state.yaw if state.yaw != null and not fresh_entry else deg_to_rad(level.layout.data.spawn_yaw)
	player.camera.rotation.x = state.pitch if state.pitch != null and not fresh_entry else 0.0
	state.yaw = Enemy.canonical_yaw(player.rotation.y)
	state.pitch = clampf(player.camera.rotation.x,-1.35,1.35)
	var specs: Dictionary = Campaign.actor_specs(level.layout)
	var records: Array = state.actors if state.actors != null else level.layout.data.enemies
	for record in records:
		if record.id in state.removed: continue
		var actor = Enemy.new()
		level.add_child(actor)
		actor.configure(self,specs[record.id])
		if state.actors != null: actor.restore_snapshot(record)
		enemies.append(actor)
	SealGuardians.refresh_markers(self,true)
	reset_supply_sweep()
	earned_runtime.refresh(self)
	if fresh_entry:
		if not _capture_actor_state():
			show_title()
			notify("NO VALID ENTRY ACTOR IMAGE",8)
			return
		state.mark_checkpoint("entry",state.position)
	for group in level.layout.data.get("encounters",[]):
		if "encounter:"+group.id in state.removed: level.apply_encounter_cue(group,true)
	damage_flash = 0
	hit_flash = 0
	message = ("ELLIS MARR / RECOVERY TECHNICIAN\n" if state.level_index == 0 else "")+level.layout.data.mission
	message_time = 7
	if state.health <= 0:
		show_recovery()
		return
	if loaded_positions or (state.actors != null and not fresh_entry):
		placement_pending = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if music != null: music.set_paused(true)
		var pending_level = level
		var pending_player = player
		# New native bodies are not queryable reliably in their construction frame.
		await get_tree().physics_frame
		await get_tree().physics_frame
		if not placement_pending or level != pending_level or player != pending_player or not is_instance_valid(pending_level) or pending_level.is_queued_for_deletion() or not is_instance_valid(pending_player) or pending_player.is_queued_for_deletion() or _scene_level_index != state.level_index: return
		placement_pending = false
		if state.health <= 0:
			show_recovery()
			return
		if not _valid_restored_actors() or not _repair_loaded_position():
			show_title()
			# Invalid current poses remain rejected. Recovery is an explicit player choice,
			# using original healthy envelopes, never a silent repaired save/refund.
			show_recovery()
			notify("NO SAFE RECOVERY POSITION",8)
			return
	menu_scroll.hide()
	player.cancel_actions()
	earned_recovery_only=false # Clear ONLY after a validated replacement scene.
	playing = true
	_capture_game_mouse()
	if music != null:
		music.set_paused(false)
		music.set_pressure(0)
		music.play_level(state.level_index)

func _capture_game_mouse() -> void:
	if _verify_stall_requested(OS.get_cmdline_user_args()): return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

static func _verify_stall_requested(args: PackedStringArray) -> bool:
	return "--verify-export" in args and "--verify-stall" in args

func _level_load_failed(detail: String) -> void:
	show_title()
	notify("LEVEL LOAD FAILED: "+detail+"\nRestore the level file and retry.",8)

func _valid_restored_actors() -> bool:
	var layout = level.layout
	var space = level.get_world_3d().direct_space_state
	for actor in enemies:
		if not is_instance_valid(actor) or not actor._current_map() or actor.hp <= 0: return false
		var collider: CollisionShape3D = actor.get_child(0)
		var query = PhysicsShapeQueryParameters3D.new()
		query.shape = collider.shape
		query.transform = collider.global_transform
		# Player clearance is repaired against these survivors below, not vice versa.
		query.collision_mask = 1|4
		query.exclude = [actor.get_rid()]
		var contacts = space.intersect_shape(query,1)
		if not contacts.is_empty():
			# Native movement may retain submillimetre floor contact, never other overlap.
			var allowance: float = minf(actor.safe_margin,0.001)
			var floor_y: float = layout.capsule_floor_support_at_y(Vector2(actor.position.x,actor.position.z),collider.shape.radius,actor.position.y,.08)
			if not is_finite(floor_y) or actor.position.y < floor_y-allowance: return false
			while not contacts.is_empty():
				var body = contacts[0].collider
				if not body is StaticBody3D or not body in level.floor_bodies or body.get_parent().get_parent() != level: return false
				query.exclude = query.exclude+[contacts[0].rid]
				contacts = space.intersect_shape(query,1)
			# This query alone cannot waive walls/actors: the unchanged pose was checked above.
			query.exclude = [actor.get_rid()]
			query.transform.origin.y += allowance
			if not space.intersect_shape(query,1).is_empty(): return false
		var cell = Vector2(actor.position.x,actor.position.z)/float(layout.data.cell_size)
		var floor_point: Vector3 = layout.surface_position_at_y([cell.x,cell.y],actor.position.y)
		var support = PhysicsRayQueryParameters3D.create(floor_point+Vector3.UP*0.5,floor_point-Vector3.UP,1)
		var hit = space.intersect_ray(support)
		if hit.is_empty() or hit.normal.y < 0.5 or absf(hit.position.y-floor_point.y) > 0.08: return false
	return true

func _capture_actor_state() -> bool:
	# Paused scenes are valid; missing, pending and retired scenes are not captures.
	if placement_pending or not is_instance_valid(level) or level.is_queued_for_deletion() or not is_instance_valid(player) or player.is_queued_for_deletion() or player.get_parent() != level or _scene_level_index != state.level_index: return true
	var captured_yaw: float = Enemy.canonical_yaw(player.rotation.y)
	var raw_pitch: float = player.camera.rotation.x
	if not is_finite(raw_pitch) or absf(raw_pitch) > Vector3(1.35,0,0).x: return false
	var captured_pitch: float = clampf(raw_pitch,-1.35,1.35)
	if not is_finite(captured_yaw) or not is_finite(captured_pitch): return false
	var snapshot: Dictionary = {"removed":state.removed.duplicate(),"keys":state.keys.duplicate(),"seal_drops":state.seal_drops.duplicate(true),"legacy_exit_wardens":state.legacy_exit_wardens.duplicate(),"actors":[]}
	if not state._valid_seal_resources(snapshot,level.layout): return false
	for actor in enemies:
		if is_instance_valid(actor) and actor._current_map() and actor.hp > 0:
			# A failed LIVE native floor settlement must never become a new saved image.
			if actor._floor_settle_failed: return false
			snapshot.actors.append(actor.snapshot())
	if not state._valid_actor_resources(snapshot,level.layout,state.difficulty):
		# Legacy Continue may have lost born-not-dead nodes before this feature existed.
		# Keep that envelope unknown; never invent deaths, HP or replacement births.
		if not (state.actors == null and state._valid_actor_resources(snapshot,level.layout,state.difficulty,true)): return false
	else:
		state.actors = snapshot.actors
	state.yaw = captured_yaw
	state.pitch = captured_pitch
	return true

func _valid_saved_position(point: Vector3) -> bool:
	var size: float = level.layout.data.cell_size
	if not level.layout.is_walkable(Vector2i(floor(point.x/size),floor(point.z/size))): return false
	var space = level.get_world_3d().direct_space_state
	var support = PhysicsRayQueryParameters3D.create(point+Vector3.UP*0.2,point-Vector3.UP*0.6,1)
	var floor_hit = space.intersect_ray(support)
	if floor_hit.is_empty() or floor_hit.normal.y < 0.5: return false
	var collider: CollisionShape3D = player.get_child(0)
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	var pose = player.global_transform
	pose.origin = point+Vector3.UP*0.04
	query.transform = pose*collider.transform
	query.collision_mask = 1|4
	query.exclude = [player.get_rid()]
	return space.intersect_shape(query,1).is_empty()

func _repair_loaded_position() -> bool:
	if _valid_saved_position(state.position): return true
	for snapshot in [state.checkpoint,state.level_start]:
		if snapshot.get("health",0) <= 0: continue
		var values = snapshot.position
		var point = Vector3(values[0],values[1],values[2])
		if not _valid_saved_position(point): continue
		state.position = point
		player.position = point+Vector3.UP*0.04
		reset_supply_sweep()
		notify("RECOVERY POSITION REPAIRED: HEALTHY SNAPSHOT",8)
		return true
	var entry: Vector3 = level.layout.world_position(level.layout.data.spawn)
	if not _valid_saved_position(entry): return false
	state.position = entry
	player.position = entry+Vector3.UP*0.04
	reset_supply_sweep()
	notify("RECOVERY POSITION REPAIRED: LEVEL ENTRY",8)
	return true

func _process(delta: float) -> void:
	message_time = maxf(0,message_time-delta)
	damage_flash = maxf(0,damage_flash-delta)
	hit_flash = maxf(0,hit_flash-delta)
	if playing and player != null:
		_update_encounters()
		if music != null: music.set_pressure(_combat_pressure())
	hud.queue_redraw()

func _update_encounters() -> void:
	var cell = Vector2(player.position.x,player.position.z)/float(level.layout.data.cell_size)
	for group in level.layout.data.get("encounters",[]):
		var r = group.region
		# World positions are float32; preserve inclusive authored edges after cell conversion.
		if cell.is_equal_approx(cell.clamp(Vector2(r[0],r[1]),Vector2(r[2],r[3]))) and _has_keys(group.get("requires",[])):
			activate_encounter(group.id)

func update_encounter_triggers(observer: CharacterBody3D) -> void:
	# Native movement/collection must publish encounter activation before rendering.
	if _passive_scan_current(observer,level): _update_encounters()

func _passive_scan_current(observer: CharacterBody3D, scene: Node3D) -> bool:
	if not Engine.is_in_physics_frame() or not is_inside_tree() or not playing or get_tree().paused or placement_pending or state.health <= 0 or _scene_level_index != state.level_index: return false
	if not is_instance_valid(scene) or level != scene or scene.is_queued_for_deletion() or scene.get_parent() != self or not scene.is_inside_tree(): return false
	return is_instance_valid(observer) and player == observer and observer._current_map() and observer.global_position.is_finite()

func update_passive_triggers(observer: CharacterBody3D) -> void:
	var scene = level
	if not _passive_scan_current(observer,scene) or _passive_scan_tick == Engine.get_physics_frames(): return
	# Latch before mutations: callbacks may reenter or retire this player/map.
	_passive_scan_tick = Engine.get_physics_frames()
	earned_runtime.tick(self,observer)
	if not _passive_scan_current(observer,scene): return
	for spec in scene.layout.data.pickups:
		if not _passive_scan_current(observer,scene): return
		if not spec.id in state.removed and observer.position.distance_to(scene.layout.world_position(spec.cell)) < 1.4 and _passive_trigger_visible(spec):
			if not _passive_scan_current(observer,scene): return
			collect_pickup(spec.id)
	if not _passive_scan_current(observer,scene): return
	for spec in scene.layout.data.interactions:
		if not _passive_scan_current(observer,scene): return
		if spec.kind == "checkpoint" and not spec.id in state.removed and observer.position.distance_to(scene.layout.world_position(spec.cell)) < 3.2 and _has_keys(spec.get("requires",[])) and _passive_trigger_visible(spec):
			if not _passive_scan_current(observer,scene): return
			state.removed.append(spec.id)
			var captured: bool = _capture_actor_state()
			if not _passive_scan_current(observer,scene): return
			if not captured:
				state.removed.erase(spec.id)
				notify("RECOVERY ACTOR CAPTURE FAILED",8)
				continue
			state.mark_checkpoint(spec.id,observer.position)
			var saved: Error = _save()
			if not _passive_scan_current(observer,scene): return
			if saved == OK: notify(spec.text)
			else: notify("RECOVERY MEMORY ONLY: "+message,8)

func _passive_trigger_visible(spec: Dictionary) -> bool:
	if not Engine.is_in_physics_frame() or not _passive_scan_current(player,level): return false
	var marker = level.markers.get(spec.id)
	if not is_instance_valid(marker) or marker.is_queued_for_deletion() or marker.get_parent() != level: return false
	var collider: CollisionShape3D = player.get_child(0)
	if collider == null or not collider.shape is CapsuleShape3D: return false
	var capsule: CapsuleShape3D = collider.shape
	var usable: float = capsule.height/2-capsule.radius
	var bounds = AABB()
	var first = true
	for child in marker.find_children("*","MeshInstance3D",true,false):
		var box: AABB = marker.global_transform.affine_inverse()*child.global_transform*child.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	if first or not bounds.position.is_finite() or not bounds.size.is_finite() or bounds.size.x <= 0 or bounds.size.z <= 0: return false
	# Use the actual compact marker envelope, not the trigger radius or its decorative center.
	var near: Vector3 = marker.to_local(player.global_position)
	near.x = clampf(near.x,bounds.position.x,bounds.end.x)
	near.z = clampf(near.z,bounds.position.z,bounds.end.z)
	near.y = 0
	var endpoint: Vector3 = marker.to_global(near)
	var floor_point: Vector3 = level.to_global(level.layout.world_position(spec.cell))
	if not endpoint.is_finite() or not floor_point.is_finite(): return false
	var space = level.get_world_3d().direct_space_state
	# shortcut: two floor-body heights within a tight XZ envelope, add mesh samples if authored cases require them.
	for origin in [collider.to_global(Vector3.DOWN*usable),collider.to_global(Vector3.UP*usable)]:
		if not origin.is_finite(): return false
		for height in [0.08,0.35]:
			endpoint.y = floor_point.y+height
			var ray = PhysicsRayQueryParameters3D.create(origin,endpoint,1)
			ray.hit_from_inside = true
			if space.intersect_ray(ray).is_empty(): return true
	return false

func _combat_pressure() -> float:
	var threats = 0
	for actor in enemies:
		if not is_instance_valid(actor) or not actor._current_map(): continue
		if actor.hp > 0 and actor.active and actor.alerted and (actor.target == null or actor.target == player) and actor.position.distance_to(player.position) < 30:
			threats += 1
	return maxf(minf(1.0,threats*0.25),clampf(damage_flash/0.35,0,1)*0.75)

func activate_encounter(id: String) -> void:
	if not playing or not is_instance_valid(level) or level.is_queued_for_deletion() or "encounter:"+id in state.removed: return
	for group in level.layout.data.get("encounters",[]):
		if group.id != id: continue
		state.removed.append("encounter:"+id)
		for actor in enemies:
			if is_instance_valid(actor) and actor._current_map() and actor.hp > 0 and actor.encounter_id == id:
				actor.active = true
				actor.alerted = true
		level.apply_encounter_cue(group,false)
		# Physics checkpoint failures must survive a later render encounter cue.
		if message_time <= 0 or not message.begins_with("RECOVERY MEMORY ONLY: SAVE FAILED"):
			notify(group.cue.text,5)
		if effects != null: effects.play(group.cue.sound,-6)
		return

func enemy_event(actor, event: String) -> void:
	if not playing or not is_instance_valid(actor) or not actor._current_map() or not actor.active: return
	var cue = ""
	match event:
		"windup":
			var family = {"brute":"crawler","guardian":"worker","summoner":"caster","nursery_warden":"crawler","choir_avatar":"caster"}.get(actor.kind,actor.kind)
			cue = family+"_charge"
		"attack": cue = "tool" if actor.kind == "crawler" else "rivet" if actor.kind == "worker" else "impact"
		"stagger": cue = "stagger"
		"death": cue = "death"
	if not cue.is_empty() and effects != null:
		effects.play(cue,-6-clampf(actor.position.distance_to(player.position)/2,0,18))

func _has_keys(required: Array) -> bool:
	for key in required:
		if not key in state.keys: return false
	return true

func guardian_defeated(actor) -> void:
	if not playing or not is_instance_valid(actor) or not actor._current_map(): return
	SealGuardians.defeated(self,actor)

func collect_key(id: String) -> void:
	if id in state.removed: return
	for spec in level.layout.data.interactions:
		if spec.id == id and spec.kind == "key":
			if not SealGuardians.available(state,spec): return
			for guardian in spec.get("requires_defeated",[]):
				if not guardian in state.removed: return
			if not spec.key in state.keys: state.keys.append(spec.key)
			state.removed.append(id)
			if spec.has("seal_bearer"):
				state.seal_drops = state.seal_drops.filter(func(drop): return drop.guardian != spec.seal_bearer)
			level.remove_marker(id)
			level.refresh_machine_lights()
			level.refresh_gate_presentations()
			if effects != null: effects.play("seal_release",-6)
			notify(spec.text)
			return

func collect_pickup(id: String) -> void:
	if id in state.removed: return
	for spec in level.layout.data.pickups:
		if spec.id != id: continue
		match spec.kind:
			"weapon", "ammo":
				var weapon = int(spec.weapon)
				var capacity = Player.WEAPONS[weapon].max_ammo
				var acquired = spec.kind == "weapon" and not weapon in state.owned_weapons
				if not acquired and state.ammo[weapon] >= capacity: return
				if acquired:
					state.owned_weapons.append(weapon)
					state.weapon = weapon
				if state.ammo[weapon] < capacity:
					state.ammo[weapon] = mini(capacity,state.ammo[weapon]+spec.amount)
			"health":
				if state.health >= 100: return
				state.health = mini(100,state.health+spec.amount)
			"armor":
				if state.armor >= 200: return
				state.armor = mini(200,state.armor+spec.amount)
		state.removed.append(id)
		level.remove_marker(id)
		notify("RECOVERED "+(Player.WEAPONS[int(spec.weapon)].name if spec.kind == "weapon" else spec.kind.to_upper()))
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
	if not Engine.is_in_physics_frame() or not playing or not is_instance_valid(player) or not player._current_map(): return {}
	var nearest: Dictionary = {}
	var distance = 4.5
	for spec in level.layout.data.interactions + level.layout.data.doors:
		if spec.id in state.removed or spec.get("kind") == "checkpoint": continue
		if not SealGuardians.available(state,spec): continue
		var location = SealGuardians.interaction_position(self,spec)
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
			for id in spec.get("requires_defeated",[]):
				if SealGuardians.exit_warden_required(state,id):
					notify("THE MANIFESTATION HOLDS THE RESTRAINT")
					return
			if not _capture_actor_state():
				notify("RECOVERY ACTOR CAPTURE FAILED",8)
				return
			var prior = state.to_dict()
			state.complete_level()
			if _save() != OK:
				state.from_dict(prior)
				return
			loaded_positions = false
			var completed_title = level.layout.data.title+" RESTORED"
			if state.level_index == 8:
				show_ending()
				return
			show_title()
			var next_layout = Level.Layout.new()
			var actions = [["Return to title",show_title]]
			if next_layout.load_level(state.level_index):
				actions.push_front(["Descend to "+next_layout.data.title.capitalize(),start_level])
			else:
				_level_load_failed(next_layout.load_error)
				return
			_show_menu(completed_title,actions)
			_show_descent_intermission()

func hurt_player(amount: int) -> void:
	if state.health <= 0 or amount <= 0: return
	state.damage(amount)
	damage_flash = 0.35
	if effects != null: effects.play("impact",-6)
	if state.health == 0:
		show_recovery()

func show_recovery() -> void:
	pause_game()
	var choices: Array = []
	if state.checkpoint.get("health",0) > 0: choices.append(["Restore checkpoint",restore_checkpoint])
	if state.level_start.get("health",0) > 0: choices.append(["Restart level",restart_level])
	choices.append(["Return to title",show_title])
	_show_menu("RECOVERY FAILED",choices)

func restore_checkpoint() -> void:
	state.restore_checkpoint()
	await start_level()

func restart_level() -> void:
	state.restore_level_start()
	await start_level()

func pause_game() -> void:
	if earned_recovery_only:
		_show_earned_recovery()
		return
	if is_instance_valid(player): player.cancel_actions()
	if placement_pending:
		show_title()
		notify("RECOVERY HELD: SELECT CONTINUE WHEN READY",5)
		return
	hud.survey.hide()
	playing = false
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if music != null: music.set_paused(true)
	if effects != null: effects.set_paused(true)
	_show_menu("PAUSED",[["Resume",resume_game],["Settings",show_settings],["Restart level",restart_level],["Save and return to title",save_and_title]])
	_button("Recovered records",func(): show_records(pause_game))
	_button("Descent map",func(): show_descent_map(pause_game))

func resume_game() -> void:
	if earned_recovery_only: return
	if is_instance_valid(player): player.cancel_actions()
	if placement_pending or state.health <= 0 or not is_instance_valid(level) or level.is_queued_for_deletion(): return
	get_tree().paused = false
	playing = true
	menu_scroll.hide()
	_capture_game_mouse()
	if music != null: music.set_paused(false)
	if effects != null: effects.set_paused(false)

func _save() -> Error:
	if earned_recovery_only: return ERR_INVALID_DATA
	if not _capture_actor_state():
		notify("SAVE FAILED: INVALID ACTOR IMAGE",8)
		return ERR_INVALID_DATA
	var result = state.save_progress(progress_path)
	if result != OK: notify("SAVE FAILED: "+error_string(result),8)
	return result

func save_and_title() -> void:
	if earned_recovery_only:
		_show_earned_recovery()
		return
	if state.health > 0 and _save() != OK:
		_show_menu("SAVE FAILED",[["Retry save",save_and_title],["Return without saving",show_title],["Back",pause_game]])
		return
	show_title()

func show_title() -> void:
	if is_instance_valid(player): player.cancel_actions()
	if hud != null: hud.survey.hide()
	playing = false
	placement_pending = false
	_scene_level_index = -1
	if level != null:
		level.queue_free()
		level = null
		player = null
		enemies.clear()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if music != null:
		music.set_pressure(0)
		if quitting: music.stop()
		else: music.play_title()
	if effects != null: effects.stop()
	_show_menu(BuildInfo.DISPLAY_NAME,[["New campaign",show_difficulty],["Continue",continue_campaign],["Settings",show_settings],["Sound test",show_sound_test],["Quit",quit_game]])
	# The title illustration reserves its quiet left third for these controls.
	# Other screens retain _show_menu's centered layout and default type size.
	menu_scroll.position = Vector2(18, 45)
	menu_scroll.size = Vector2(220, 275)
	menu.get_child(0).add_theme_font_size_override("font_size", 28)
	menu.get_child(0).autowrap_mode = TextServer.AUTOWRAP_OFF

func show_sound_test() -> void:
	if playing or placement_pending or is_instance_valid(level): return
	_close_sound_test()
	menu_scroll.hide()
	sound_test = load("res://ui/resonance/sound_test.gd").new()
	sound_test.set_reduced_motion(settings.get("sound_test_reduced_motion",false))
	sound_test.bind_music(music)
	sound_test.back_requested.connect(show_title)
	sound_test.music_volume_changed.connect(_sound_test_volume_changed)
	# Released SoundTest lacks the prototype-only persistence signal. Keep that API optional.
	var motion_callback := Callable(self,"_sound_test_motion_changed")
	if sound_test.has_signal("reduced_motion_changed") and motion_callback.is_valid() and not sound_test.is_connected("reduced_motion_changed",motion_callback):
		sound_test.connect("reduced_motion_changed",motion_callback)
	canvas.add_child(sound_test)

func _close_sound_test() -> void:
	if is_instance_valid(sound_test):
		sound_test.close()
		sound_test.queue_free()
	sound_test = null

func _sound_test_volume_changed(value: float) -> void:
	settings.music_volume = value
	_apply_volumes()
	_save_settings()

func _sound_test_motion_changed(enabled: bool) -> void:
	settings.sound_test_reduced_motion = enabled
	_save_settings()

func continue_campaign() -> void:
	if not state.load_progress(progress_path):
		if not state.level_load_error.is_empty():
			_level_load_failed(state.level_load_error)
			return
		notify("NO VALID RECOVERY IMAGE",5)
		return
	if state.level_index == 8:
		show_ending()
		return
	loaded_positions = true
	await start_level()

func show_ending() -> void:
	show_title()
	music.play_interlude()
	var revelation = "YOUR VOICE ISSUED THE FIRST ORDER\nTHE RESTRAINT WAS BUILT AROUND YOU" if state.discoveries.size() == 8 else "THE RESTRAINT IS OPEN\nTHE VOICE NOW USES YOUR NAME"
	_show_menu(revelation,[["New campaign",show_difficulty],["Return to title",show_title]])
	_button("Recovered records",func(): show_records(show_ending))
	_button("Descent map",func(): show_descent_map(show_ending))
	_record_body(Narrative.ENDINGS["complete" if state.discoveries.size() == 8 else "normal"].body)
	# Keep the earned mouth illustration readable beside a compact ending rail.
	# The existing scroll/focus behavior retains the complete ending body.
	menu_scroll.position = Vector2(422, 32)
	menu_scroll.size = Vector2(202, 290)
	var ending_heading: Label = menu.get_child(0)
	ending_heading.add_theme_font_size_override("font_size", 16)
	ending_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var ending_ink := StyleBoxFlat.new()
	ending_ink.bg_color = Color(0.025, 0.022, 0.029, 0.94)
	ending_ink.set_content_margin_all(8)
	ending_heading.add_theme_stylebox_override("normal", ending_ink)
	# Heart's illustration is earned only after the final depth is completed.
	# An incomplete ending invocation must not reveal the CURRENT final chapter.
	if state.level_index == 8:
		var completed: Dictionary = preload("res://scripts/descent_map.gd").overview(state)
		if completed.rows.size() == 8 and completed.rows[7].status == "CLEARED" and ResourceLoader.exists(preload("res://scripts/descent_chart.gd").art_path(7)):
			menu.set_meta("chapter_intro", 7)
			hud.queue_redraw()

func _descent_available() -> bool:
	if not is_inside_tree(): return false
	return not playing and not placement_pending and get_tree().paused and (state.level_index == 8 or (is_instance_valid(level) and not level.is_queued_for_deletion()))

func show_descent_map(back: Callable) -> void:
	if not _descent_available() or not back.is_valid(): return
	var view: Dictionary = preload("res://scripts/descent_map.gd").overview(state)
	_show_menu("DESCENT MAP",[["Back",back]])
	var summary = Label.new()
	summary.text = "%d / 8 descents cleared · %d / 8 records recovered\n\n%s\n\nIllustrated chapter descent below; not a navigational floor plan." % [view.cleared, view.records, view.objective]
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_font_size_override("font_size",14)
	menu.add_child(summary)
	var entries: PackedStringArray = []
	for row in view.rows:
		entries.append("%02d  %s — %s\n%s" % [row.index+1, row.name, row.status, "Record recovered" if row.record_found else "Record not recovered"])
	# Reuse the keyboard-scrollable, focus-outlined archive panel, not inert labels.
	_record_body("\n\n".join(entries))
	var chart = preload("res://scripts/descent_chart.gd").new()
	chart.configure(view)
	menu.add_child(chart)
	for row in view.rows:
		if row.record_found:
			var index: int = row.index
			_button("Read: "+Narrative.RECORDS[index].title,func(): show_descent_record(index,back))

func show_descent_record(index: int, back: Callable) -> void:
	if not _descent_available() or not back.is_valid() or index < 0 or index >= Narrative.RECORDS.size() or not index in state.discoveries: return
	_show_menu(Narrative.RECORDS[index].title,[["Back to descent map",func(): show_descent_map(back)]])
	menu.get_child(0).add_theme_font_size_override("font_size",24)
	_record_body(Narrative.RECORDS[index].body)

func show_records(back: Callable) -> void:
	if playing or placement_pending: return
	_show_menu("Recovered records",[["Back",back]])
	for index in state.discoveries:
		_button(Narrative.RECORDS[index].title,func(): show_record(index,back))
	if state.discoveries.is_empty():
		_record_body("No records recovered. Examine optional discoveries in the cathedral to preserve their accounts here.")

func show_record(index: int, back: Callable) -> void:
	if playing or placement_pending or not index in state.discoveries: return
	_show_menu(Narrative.RECORDS[index].title,[["Back to records",func(): show_records(back)]])
	menu.get_child(0).add_theme_font_size_override("font_size",24)
	_record_body(Narrative.RECORDS[index].body)

func _record_body(text: String) -> void:
	var body = RichTextLabel.new()
	body.text = text
	body.bbcode_enabled = false
	body.custom_minimum_size.y = 180
	body.focus_mode = Control.FOCUS_ALL
	body.add_theme_font_size_override("normal_font_size",14)
	body.add_theme_stylebox_override("normal",menu_scroll.theme.get_stylebox("normal","Button"))
	body.add_theme_stylebox_override("focus",menu_scroll.theme.get_stylebox("focus","Button"))
	body.add_theme_color_override("default_color",menu_scroll.theme.get_color("font_color","Label"))
	menu.add_child(body)

func show_difficulty() -> void:
	_show_menu("RECOVERY PROTOCOL",[["Merciful",func(): start_campaign(0)],["Relentless",func(): start_campaign(1)],["Terminal",func(): start_campaign(2)],["Back",show_title]])
	_show_chapter_intro(0)

func _show_descent_intermission() -> void:
	# Only the just-saved actual completion path calls this presentation boundary.
	if playing or is_instance_valid(level) or state.level_index < 1 or state.level_index > 7: return
	if menu.get_child_count() == 0 or not menu.get_child(0).text.ends_with(" RESTORED"): return
	menu.set_meta("descent_intermission", true)
	music.play_interlude()
	menu_scroll.position = Vector2(430, 45)
	menu_scroll.size = Vector2(198, 275)
	menu.get_child(0).add_theme_font_size_override("font_size", 22)
	# Keep the existing first Descend button and its callback/focus untouched.
	menu.get_child(1).clip_text = false
	menu.get_child(1).add_theme_font_size_override("font_size", 12)
	intermission_route = preload("res://scripts/descent_chart.gd").IntermissionRoute.new()
	intermission_route.position = Vector2.ZERO
	intermission_route.size = Vector2(640, 360)
	intermission_route.configure(preload("res://scripts/descent_map.gd").overview(state))
	menu_scroll.get_parent().add_child(intermission_route)
	menu_scroll.get_parent().move_child(intermission_route, menu_scroll.get_index())
	var cleared_index: int = state.level_index - 1
	if intermission_route.textures.get(cleared_index) is Texture2D:
		var illustration_toggle := Button.new()
		illustration_toggle.text = "Chapter illustration"
		illustration_toggle.accessibility_name = "Show completed chapter illustration"
		illustration_toggle.tooltip_text = "View the chapter you just completed. Unreached chapter art stays sealed."
		illustration_toggle.custom_minimum_size.y = 34
		illustration_toggle.add_theme_font_size_override("font_size", 12)
		illustration_toggle.pressed.connect(_toggle_restored_illustration.bind(illustration_toggle, cleared_index))
		menu.add_child(illustration_toggle)
	_record_body("Depth %02d restored.\nFollow the gold route.\nYOU ARE HERE marks your next descent.\n\nWorld illustration, not a floor plan." % state.level_index)
	menu.get_child(menu.get_child_count()-1).custom_minimum_size.y = 96

func _toggle_restored_illustration(button: Button, cleared_index: int) -> void:
	# The next level is CURRENT, not earned: only the last CLEARED row may open.
	if not is_instance_valid(intermission_route) or not menu.get_meta("descent_intermission", false): return
	if cleared_index != state.level_index - 1 or cleared_index < 0 or cleared_index >= intermission_route.rows.size(): return
	if intermission_route.rows[cleared_index].status != "CLEARED" or not intermission_route.textures.get(cleared_index) is Texture2D: return
	var show_art: bool = menu.get_meta("chapter_intro", -1) != cleared_index
	if show_art:
		menu.set_meta("chapter_intro", cleared_index)
	else:
		menu.remove_meta("chapter_intro")
	intermission_route.visible = not show_art
	# Full chapter paintings share one unobtrusive bottom rail: retain the same
	# Descend and toggle nodes/callbacks, rather than covering each hero at right.
	menu_scroll.position = Vector2(8, 245) if show_art else Vector2(430, 45)
	menu_scroll.size = Vector2(624, 82) if show_art else Vector2(198, 275)
	for index in [0, 2, menu.get_child_count() - 1]:
		menu.get_child(index).visible = not show_art
	menu_scroll.scroll_vertical = 0
	button.text = "Descent chart" if show_art else "Chapter illustration"
	button.accessibility_name = "Show connected descent chart" if show_art else "Show completed chapter illustration"
	hud.queue_redraw()


func _show_chapter_intro(index: int) -> void:
	if not is_inside_tree() or playing or placement_pending or is_instance_valid(level) or not get_tree().paused or not menu_scroll.visible: return
	if index < 0 or index >= 8 or menu.get_child_count() == 0: return
	var heading: String = menu.get_child(0).text
	var new_campaign_choice: bool = index == 0 and heading == "RECOVERY PROTOCOL"
	var earned_transition: bool = index > 0 and index == state.level_index and heading.ends_with(" RESTORED")
	if not new_campaign_choice and not earned_transition: return
	if menu.get_meta("chapter_intro",-1) == index: return
	menu.set_meta("chapter_intro",index)
	_record_body("%02d / 08 — %s\nFind both seals, then the exit. Explore for optional records.\nChapter illustration, not a floor plan." % [index+1,preload("res://scripts/descent_map.gd").LEVEL_NAMES[index]])
	menu.get_child(menu.get_child_count()-1).custom_minimum_size.y = 96
	hud.queue_redraw()

func show_settings() -> void:
	_show_menu("SETTINGS",[])
	for option in [["head_bob","Head bob"],["camera_shake","Camera shake"],["reduced_damage_flashes","Reduced damage flashes"],["sound_test_reduced_motion","Sound test: reduced motion"],["invert_y","Invert Y"],["auto_aim","Classic auto-aim"]]:
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
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",12)
	menu.add_child(label)
	for action in Preferences.ACTIONS:
		var button = Button.new()
		button.text = _control_text(action)
		button.clip_text = true
		button.tooltip_text = button.text
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
	_close_sound_test()
	if placement_pending: show_title()
	pending_action = ""
	pending_button = null
	if is_instance_valid(intermission_route):
		intermission_route.get_parent().remove_child(intermission_route)
		intermission_route.queue_free()
	intermission_route = null
	menu_scroll.position = Vector2(150,45)
	menu_scroll.size = Vector2(340,275)
	menu.set_meta("descent_intermission", false)
	menu.set_meta("chapter_intro",-1)
	menu_scroll.scroll_vertical = 0
	menu_scroll.show()
	for child in menu.get_children():
		menu.remove_child(child)
		child.queue_free()
	menu.show()
	var label = Label.new()
	label.text = title
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",32)
	menu.add_child(label)
	for action in actions: _button(action[0],action[1])

func _button(text: String, action: Callable) -> void:
	var button = Button.new()
	button.text = text
	button.clip_text = true
	button.custom_minimum_size.y = 34
	button.pressed.connect(action)
	menu.add_child(button)
	if menu.get_child_count() == 2: button.grab_focus()

func notify(text: String, duration: float = 3) -> void:
	if is_instance_valid(sound_test): sound_test._feedback(text)
	message = text
	message_time = duration

func shot(weapon: int) -> void:
	if effects != null: effects.play(["tool","rivet","scatter","rivet","scatter","caster_charge"][clampi(weapon,0,5)])
	if weapon in [1,2,3]:
		var visuals = ammo_visuals()
		if visuals != null and is_instance_valid(player): visuals.casing(player,weapon,player.last_shot_sequence(weapon))
	for actor in enemies:
		if is_instance_valid(actor) and actor._current_map() and actor.hp > 0 and actor.active and actor.position.distance_to(player.position) < 34:
			actor.alerted = true

func hit_feedback() -> void:
	if effects != null and hit_flash <= 0: effects.play("flesh")
	hit_flash = 0.12

func ammo_visuals() -> Node3D:
	if not playing or not is_instance_valid(level) or level.is_queued_for_deletion(): return null
	var visuals = level.get_node_or_null("AmmoVisuals")
	if visuals == null:
		visuals = AmmoVisuals.new()
		visuals.name = "AmmoVisuals"
		visuals.game = self
		level.add_child(visuals)
	return visuals

func weapon_impact(point: Vector3, weapon: int, sequence: int, surface: String) -> void:
	var scene = level
	if not playing or not is_instance_valid(scene) or scene.is_queued_for_deletion(): return
	if effects != null: effects.play("impact",-12)
	if not playing or level != scene or not is_instance_valid(scene) or scene.is_queued_for_deletion(): return
	var visuals = ammo_visuals()
	if visuals != null: visuals.impact(point,weapon,sequence,surface)

func impact(point: Vector3) -> void:
	if effects != null: effects.play("impact",-12)
	var visuals = ammo_visuals()
	if visuals != null: visuals.impact(point)

func dry_fire(_weapon: int) -> void:
	if effects != null: effects.play("dry")

func resolve_aim(origin: Vector3, direction: Vector3, max_range: float, melee: bool = false) -> Dictionary:
	var result := {"level":level,"player":player,"tick":Engine.get_physics_frames(),"weapon":state.weapon,"origin":origin,"manual_direction":direction,"direction":direction,"range":max_range,"contact":{},"actor_id":"","assisted":false}
	if not Engine.is_in_physics_frame() or not playing or not is_instance_valid(player) or not player._current_map() or state.health <= 0 or not origin.is_finite() or not direction.is_finite() or not is_finite(max_range) or max_range <= 0 or not is_equal_approx(direction.length_squared(),1.0): return result
	var space := level.get_world_3d().direct_space_state
	# Aim feedback and actual shots share the rendered-frame silhouette query.
	# Movement capsules are deliberately not an anatomical hit approximation.
	var exclusions: Array[RID] = [player.get_rid()]
	var manual: Dictionary = SpriteHitQuery.cast(space,origin,origin+direction*max_range,player.camera,enemies,exclusions,1|4)
	result.contact = manual
	if not manual.is_empty() and manual.collider.has_method("take_damage"):
		if manual.collider.has_method("_current_map") and manual.collider._current_map() and manual.collider.hp > 0:
			result.actor_id = str(manual.collider.id)
		return result
	if not settings.auto_aim: return result
	var best_angle := -1.0
	var best_distance := INF
	var best_id := ""
	var manual_flat := Vector2(direction.x,direction.z).normalized()
	for actor in enemies:
		if not is_instance_valid(actor) or not actor._current_map() or actor.hp <= 0 or not actor.active: continue
		var points: Array[Vector3] = SpriteHitQuery.candidate_points(actor,player.camera,origin)
		for point in points:
			var offset := point-origin
			if offset.length_squared() < .000001: continue
			var resolved := offset.normalized()
			var angular := direction.dot(resolved)
			if melee:
				angular = manual_flat.dot(Vector2(offset.x,offset.z).normalized())
				# Classic correction is bounded; the final native contact still uses finite 3D reach.
				if absf(direction.y-resolved.y) > .8: continue
			if angular <= .975: continue
			var hit: Dictionary = SpriteHitQuery.cast(space,origin,origin+resolved*max_range,player.camera,enemies,exclusions,1|4)
			if hit.is_empty() or hit.collider != actor: continue
			var distance := origin.distance_to(hit.position)
			if distance > max_range+.00001: continue
			var better: bool = angular > best_angle or (angular == best_angle and (distance < best_distance or (distance == best_distance and str(actor.id) < best_id)))
			if not better: continue
			best_angle = angular
			best_distance = distance
			best_id = str(actor.id)
			result.direction = resolved
			result.contact = hit
			result.actor_id = best_id
			result.assisted = true
	return result

func clear_observations() -> void:
	aim_observation = {}
	interaction_observation = {}

func observe_player() -> void:
	clear_observations()
	if not Engine.is_in_physics_frame() or not playing or not is_instance_valid(player) or not player._current_map() or state.health <= 0: return
	var profile: Dictionary = Player.WEAPONS[state.weapon]
	aim_observation = resolve_aim(player.camera.global_position,-player.camera.global_basis.z,profile.range,state.weapon == 0)
	observe_interaction()

func observe_interaction() -> void:
	interaction_observation = {}
	if not Engine.is_in_physics_frame() or not playing or not is_instance_valid(player) or not player._current_map() or state.health <= 0: return
	interaction_observation = {"level":level,"player":player,"tick":Engine.get_physics_frames(),"origin":player.camera.global_position,"direction":-player.camera.global_basis.z,"spec":nearest_interaction()}

func _observation_current(observation: Dictionary) -> bool:
	return not observation.is_empty() and playing and state.health > 0 and is_instance_valid(player) and player._current_map() and observation.level == level and observation.player == player and Engine.get_physics_frames()-int(observation.tick) <= 1 and observation.origin == player.camera.global_position and observation.get("manual_direction",observation.get("direction")) == -player.camera.global_basis.z

func aim_display() -> Dictionary:
	if not _observation_current(aim_observation) or aim_observation.weapon != state.weapon: return {}
	if not aim_observation.actor_id.is_empty():
		var actor = aim_observation.contact.get("collider")
		if not is_instance_valid(actor) or not actor._current_map() or actor.hp <= 0 or str(actor.id) != aim_observation.actor_id: return {}
	return aim_observation

func interaction_display() -> Dictionary:
	if not _observation_current(interaction_observation): return {}
	var spec: Dictionary = interaction_observation.spec
	return {} if spec.get("id","") in state.removed else spec

func autoaim_target(origin: Vector3, direction: Vector3, max_range: float) -> Node3D:
	var solution := resolve_aim(origin,direction,max_range,max_range <= Player.WEAPONS[0].range)
	return solution.contact.get("collider") if not solution.actor_id.is_empty() else null

func quit_game() -> bool:
	if earned_recovery_only:
		_show_earned_recovery()
		return false
	if quitting: return true
	if level != null and state.health > 0 and _save() != OK:
		pause_game()
		_show_menu("SAVE FAILED",[["Retry save and quit",quit_game],["Quit without saving",_finish_quit],["Resume",resume_game]])
		return false
	_finish_quit()
	return true

func _finish_quit() -> void:
	if quitting: return
	quitting = true
	show_title()
	menu_scroll.hide()
	# Mixer release uses wall time, not the caller's accumulated frame delta.
	var drain_until: int = Time.get_ticks_usec()+100000
	while Time.get_ticks_usec() < drain_until:
		await get_tree().process_frame
	get_tree().quit()

func _has_metal_shader_cache(root: String) -> bool:
	return _contains_metal_cache(root.path_join("SceneForwardMobileShaderRD")) and _contains_metal_cache(root.path_join("CanvasShaderRD"))

func _contains_metal_cache(root: String) -> bool:
	if not DirAccess.dir_exists_absolute(root): return false
	var directories = [root]
	while not directories.is_empty():
		var path = directories.pop_back()
		if Array(DirAccess.get_files_at(path)).any(func(file): return file.ends_with(".metal.cache")): return true
		for child in DirAccess.get_directories_at(path): directories.append(path.path_join(child))
	return false

# Fixed headless workflow for the release binary, which cannot execute external scripts.
# Controlled packed-resource workflow; not played difficulty, art/audio quality or FPS acceptance.
class ExportPassiveTick:
	extends Node
	var game
	var observer
	var completed: bool = false
	func _physics_process(_delta: float) -> void:
		if is_instance_valid(game) and is_instance_valid(observer): game.update_passive_triggers(observer)
		completed = true
		set_physics_process(false)

func _verify_passive_tick() -> void:
	var driver = ExportPassiveTick.new()
	driver.game = self
	driver.observer = player
	driver.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(driver)
	while not driver.completed: await get_tree().physics_frame
	driver.free()

class ExportFireTick:
	extends Node
	var game
	var observer
	var completed: bool = false
	var fired: bool = false
	func _physics_process(_delta: float) -> void:
		if is_instance_valid(game) and is_instance_valid(observer) and observer == game.player:
			fired = observer.fire()
		completed = true
		set_physics_process(false)

func _verify_fire_tick() -> bool:
	var driver = ExportFireTick.new()
	driver.game = self
	driver.observer = player
	driver.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(driver)
	while not driver.completed: await get_tree().physics_frame
	var fired: bool = driver.fired
	driver.free()
	return fired

# Registered ownership replaces only obsolete FLOOR supply assumptions.
# These are arranged packed-resource transactions, NOT played route/balance proof.
func _export_earned_checks() -> Dictionary:
	var supply = Campaign.EarnedSupplies
	var content: Dictionary = supply.chapter(level.layout)
	var checks := {"earned_registry":not content.is_empty(),"no_floor_supplies":level.layout.data.pickups.is_empty()}
	if content.is_empty(): return checks
	checks["earned_typed_state"]=supply.valid(state.earned_supply,state._resources(),level.layout,state.difficulty)
	checks["retired_floor_markers_absent"]=content.legacy_pickups.all(func(row): return not level.markers.has(row.id))
	var expected: Dictionary = {}
	for station in content.stations:
		var remaining: int = int(state.earned_supply.healing_remaining[station.id])
		expected[station.id]={"parent":level,"point":level.healing_machinery.root_point(station.id),
			"text":"","reservoir":true,"available":remaining>0,"station_id":station.id,"chapter":level.layout.data.id,"stock":remaining,"capacity":int(station.capacity)}
	var grants: Dictionary = supply.grant_map(content)
	for drop in state.earned_supply.loot_drops:
		var grant: Dictionary = grants[drop.grant_id]
		var label: String = "ARMOR" if grant.kind=="armor" else Player.WEAPONS[int(grant.weapon)].name
		expected[drop.grant_id]={"parent":level,"point":Vector3(drop.position[0],drop.position[1],drop.position[2]),
			"text":label+(" UNLOCK" if grant.kind=="unlock" else " x"+str(drop.remaining)),"reservoir":false,"available":true}
	for grant in grants.values():
		if grant.id in state.earned_supply.loot_claimed or expected.has("carrier:"+grant.carrier): continue
		for actor in enemies:
			if not is_instance_valid(actor) or actor.id!=grant.carrier or actor.hp<=0 or not actor._current_map(): continue
			var label: String = "CARRIED RESONATOR" if actor.kind=="caster" else "RITUAL CACHE" if actor.kind=="summoner" else "CARRIED EQUIPMENT"
			expected["carrier:"+actor.id]={"parent":actor,"point":Vector3(.4,1.0,.15),"text":label,"reservoir":false,"available":true}
	var actual: Dictionary = earned_runtime._markers
	checks["earned_marker_count"]=actual.size()==expected.size() and actual.keys().all(func(id): return expected.has(id)) and expected.keys().all(func(id): return actual.has(id))
	var seen: Array = []
	var owned: bool = bool(checks.earned_marker_count)
	for id in expected:
		var row: Dictionary = expected[id]
		var marker = actual.get(id)
		if not is_instance_valid(marker) or not marker is Node3D or marker.is_queued_for_deletion(): owned=false;continue
		if marker.get_instance_id() in seen or marker.get_parent()!=row.parent or not marker.position.is_equal_approx(row.point): owned=false
		seen.append(marker.get_instance_id())
		if not marker.visible or marker is CollisionObject3D: owned=false
		if row.reservoir:
			if level.healing_stations.get(id,{}).get("root")!=marker or not level.healing_machinery.validate_station(id,true): owned=false
			if earned_runtime.station_use_target(self,{"id":id,"capacity":row.capacity})==null: owned=false
			continue
		if not marker.find_children("*","CollisionShape3D",true,false).is_empty(): owned=false
		var meshes: Array = marker.get_children().filter(func(child): return child is MeshInstance3D)
		var labels: Array = marker.get_children().filter(func(child): return child is Label3D)
		var lights: Array = marker.get_children().filter(func(child): return child is Light3D)
		if marker.find_children("*","Light3D",true,false).size()!=lights.size(): owned=false
		if not row.reservoir:
			var drop_practical: bool=row.parent==level
			if meshes.size()!=1 or labels.size()!=1 or lights.size()!=(1 if drop_practical else 0): owned=false;continue
			if drop_practical:
				var practical: Light3D=lights[0]
				if earned_runtime._drop_practicals.get(marker.get_instance_id())!=practical: owned=false
				if not practical is OmniLight3D or practical.name!="EarnedDropPractical" or not practical.visible or not practical.position.is_equal_approx(Vector3(0,.32,0)) or not is_equal_approx(practical.omni_range,2.0) or not is_equal_approx(practical.light_energy,1.0) or not practical.shadow_enabled or not practical.light_color.is_equal_approx(Color(.95,.8,.6)) or practical.get_meta("practical_source","")!="earned_drop_case" or practical.get_meta("source_role","")!="earned_equipment_drop": owned=false
			var drop_mesh: MeshInstance3D=meshes[0]
			if not drop_mesh.mesh is BoxMesh or not drop_mesh.mesh.size.is_equal_approx(Vector3(.34,.12,.22)) or not drop_mesh.material_override is StandardMaterial3D: owned=false
			else:
				var case_material := drop_mesh.material_override as StandardMaterial3D
				if not case_material.emission_enabled or not case_material.emission.is_equal_approx(Color(.56,.36,.18)) or not is_equal_approx(case_material.emission_energy_multiplier,.18): owned=false
			if labels[0].text!=row.text or labels[0].billboard!=BaseMaterial3D.BILLBOARD_ENABLED: owned=false
			continue
	if earned_runtime._drop_practicals.size()!=state.earned_supply.loot_drops.size(): owned=false
	checks["earned_fixed_machine_geometry"]=level.healing_machinery.validate_book(state.earned_supply,true)
	checks["earned_marker_ownership"]=owned and checks.earned_fixed_machine_geometry
	return checks

func _export_earned_negative_controls() -> bool:
	# No state/file writes and no await while the visible marker book is overlaid.
	# Missing/foreign/duplicate-node controls must fail, then restore exact objects.
	var original: Dictionary = earned_runtime._markers
	if original.size()<2: return false
	var keys: Array = original.keys()
	var missing: Dictionary = original.duplicate()
	missing.erase(keys[0]);earned_runtime._markers=missing
	var missing_rejected: bool = not _export_earned_checks().get("earned_marker_count",true)
	var foreign: Dictionary = original.duplicate()
	foreign["foreign:unregistered"]=original[keys[0]];earned_runtime._markers=foreign
	var foreign_rejected: bool = not _export_earned_checks().get("earned_marker_count",true)
	var duplicate: Dictionary = original.duplicate()
	duplicate[keys[1]]=duplicate[keys[0]];earned_runtime._markers=duplicate
	var duplicate_rejected: bool = not _export_earned_checks().get("earned_marker_ownership",true)
	earned_runtime._markers=original
	var restored: Dictionary = _export_earned_checks()
	return missing_rejected and foreign_rejected and duplicate_rejected and restored.get("earned_marker_count",false) and restored.get("earned_marker_ownership",false) and _export_earned_machine_negative_controls() and _export_earned_drop_practical_negative_controls()

func _export_earned_drop_practical_negative_controls() -> bool:
	# Only existing actual drops; no grant/death/save construction for this probe.
	for marker in earned_runtime._markers.values():
		if not earned_runtime._drop_practicals.has(marker.get_instance_id()): continue
		var practical: OmniLight3D=earned_runtime._drop_practicals[marker.get_instance_id()]
		practical.hide()
		var hidden: bool=not _export_earned_checks().get("earned_marker_ownership",true)
		practical.show()
		var replacement: Node=practical.duplicate()
		marker.remove_child(practical);marker.add_child(replacement)
		var substituted: bool=not _export_earned_checks().get("earned_marker_ownership",true)
		marker.remove_child(replacement);replacement.free();marker.add_child(practical)
		var foreign := OmniLight3D.new();marker.add_child(foreign)
		var foreign_rejected: bool=not _export_earned_checks().get("earned_marker_ownership",true)
		foreign.free()
		var holder := Node3D.new();marker.add_child(holder)
		marker.remove_child(practical);holder.add_child(practical)
		var nested: bool=not _export_earned_checks().get("earned_marker_ownership",true)
		holder.remove_child(practical);marker.add_child(practical);holder.free()
		return hidden and substituted and foreign_rejected and nested and _export_earned_checks().get("earned_marker_ownership",false)
	return true # No uncollected drop exists in this current primitive state.

func _export_earned_machine_negative_controls() -> bool:
	# No await, supply mutation or file writes while geometry is temporarily invalid.
	var ids: Array=level.healing_stations.keys()
	if ids.is_empty(): return false
	var row: Dictionary=level.healing_stations[ids[0]]
	var control: MeshInstance3D=row.nodes.DialFace
	var needle: MeshInstance3D=row.nodes.StockNeedle
	var fluid: MeshInstance3D=row.nodes.StockVolume
	var machine: Node3D=row.root
	var anchor: Node3D=row.nodes.UseTarget
	control.hide()
	var hidden: bool=not _export_earned_checks().get("earned_marker_ownership",true)
	control.show()
	var original: Transform3D=machine.transform
	machine.position.x+=.01
	var moved: bool=not _export_earned_checks().get("earned_marker_ownership",true)
	machine.transform=original
	var control_mesh: Mesh=control.mesh
	control.mesh=SphereMesh.new()
	var substituted: bool=not _export_earned_checks().get("earned_marker_ownership",true)
	control.mesh=control_mesh
	var fake := StandardMaterial3D.new()
	fake.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;fake.albedo_color.a=.1
	control.material_override=fake
	var transparent: bool=not _export_earned_checks().get("earned_marker_ownership",true)
	control.material_override=null
	var anchor_transform: Transform3D=anchor.transform
	anchor.position.z+=.01
	var anchor_lie: bool=not _export_earned_checks().get("earned_marker_ownership",true)
	anchor.transform=anchor_transform
	var needle_transform: Transform3D=needle.transform
	needle.rotation.z+=.1
	var gauge_lie: bool=not _export_earned_checks().get("earned_marker_ownership",true)
	needle.transform=needle_transform
	var stock_transform: Transform3D=fluid.transform
	fluid.scale.y=0.0
	var stock_lie: bool=not _export_earned_checks().get("earned_marker_ownership",true)
	fluid.transform=stock_transform
	var original_id: String=row.id
	row.id="foreign"
	var foreign: bool=not _export_earned_checks().get("earned_marker_ownership",true)
	row.id=original_id
	return hidden and moved and substituted and transparent and anchor_lie and gauge_lie and stock_lie and foreign and _export_earned_checks().get("earned_marker_ownership",false)

class ExportEarnedDeathTick:
	extends Node
	var game
	var observer
	var carrier
	var completed: bool = false
	var defeated: bool = false
	func _physics_process(_delta: float) -> void:
		if is_instance_valid(observer) and observer==game.player and is_instance_valid(carrier) and carrier._current_map() and carrier.hp>0:
			# Controlled production damage/death hook, not an ammo/balance claim.
			# Guardian front armor is still applied by take_damage itself.
			carrier.take_damage(carrier.hp*4,observer,{"attack_kind":"export_fixture","origin":observer.global_position})
			defeated=carrier.hp==0 and carrier.id in game.state.removed and not game.earned_recovery_only
		completed=true
		set_physics_process(false)

func _verify_registered_weapon(weapon: int, checks: Dictionary, key: String) -> bool:
	var supply = Campaign.EarnedSupplies
	var content: Dictionary = supply.chapter(level.layout)
	var unlock: Dictionary = {}
	for row in content.get("grants",[]):
		if row.kind=="unlock" and int(row.weapon)==weapon:
			unlock=row;break
	checks[key+"_registered_unlock"]=not unlock.is_empty()
	if unlock.is_empty(): return false
	var carrier
	for actor in enemies:
		if is_instance_valid(actor) and actor.id==unlock.carrier: carrier=actor;break
	checks[key+"_living_registered_carrier"]=is_instance_valid(carrier) and carrier.hp>0 and not carrier.id in state.removed
	if not checks[key+"_living_registered_carrier"]: return false
	var old_inventory: Array = state.owned_weapons.duplicate()
	var old_ammo: Array = state.ammo.duplicate()
	var old_weapon: int = state.weapon
	var quantity: int = 0
	for row in content.grants:
		if row.carrier==carrier.id and row.kind=="ammo" and int(row.weapon)==weapon: quantity+=supply.amount(row,state.difficulty)
	var driver = ExportEarnedDeathTick.new()
	driver.game=self;driver.observer=player;driver.carrier=carrier
	driver.process_mode=Node.PROCESS_MODE_ALWAYS
	add_child(driver)
	while not driver.completed: await get_tree().physics_frame
	var defeated: bool = driver.defeated
	driver.free()
	checks[key+"_carrier_death"]=defeated
	checks[key+"_death_did_not_grant_inventory"]=state.ammo==old_ammo and state.owned_weapons==old_inventory and state.weapon==old_weapon
	if not defeated: return false
	var drop: Dictionary = {}
	for row in state.earned_supply.loot_drops:
		if row.grant_id==unlock.id: drop=row;break
	checks[key+"_finite_unlock_drop"]=not drop.is_empty() and int(drop.get("remaining",0))==1
	if drop.is_empty(): return false
	# Arrangement chooses the ACTUAL recorded corpse/recovery drop, never its
	# retired floor cell. Reset prevents teleport segments collecting other loot.
	player.position=Vector3(drop.position[0],drop.position[1]-.16,drop.position[2])
	reset_supply_sweep()
	await _verify_passive_tick()
	_process(0)
	var expected_ammo: int = mini(Player.WEAPONS[weapon].max_ammo,int(old_ammo[weapon])+quantity)
	var remainder: int = 0
	var grants: Dictionary = supply.grant_map(content)
	for row in state.earned_supply.loot_drops:
		var grant: Dictionary = grants[row.grant_id]
		if grant.carrier==carrier.id and grant.kind=="ammo" and int(grant.weapon)==weapon: remainder+=int(row.remaining)
	checks[key+"_pickup"]=weapon in state.owned_weapons and state.weapon==weapon and unlock.id in state.earned_supply.loot_claimed and state.ammo[weapon]==expected_ammo
	checks[key+"_finite_ammo_conservation"]=int(state.ammo[weapon])-int(old_ammo[weapon])+remainder==quantity
	checks[key+"_retired_floor_not_claimed"]=not unlock.legacy_alias in state.removed
	checks[key+"_typed_snapshot"]=_capture_actor_state() and Campaign.new().from_dict(state.to_dict())
	var owned_checks: Dictionary = _export_earned_checks()
	for name in owned_checks: checks[key+"_"+name]=owned_checks[name]
	return checks[key+"_pickup"] and checks[key+"_finite_ammo_conservation"] and checks[key+"_typed_snapshot"] and ResourceLoader.exists("res://assets/art/weapons/"+Player.WEAPONS[weapon].asset+".png")

func _export_wall_architecture_checks() -> Dictionary:
	# Source-profile presence/ownership check, not a new wall-art or physics grade.
	# Existing wall-native contracts own detailed winding/contact qualification.
	var checks := {"wall_family":false,"wall_chunks":false,"wall_draw_geometry":false,"wall_collision":false}
	var walls = Level.WallArchitecture
	var layout = level.layout
	var chapter: String = layout.data.id
	if not walls.FAMILIES.has(chapter): return checks
	checks.wall_family = true
	var size: float = layout.data.cell_size
	var closure_top: float = walls._highest_support(layout)+3.0
	var expected: Dictionary = {}
	for cell in layout.tiles:
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if layout.is_walkable(cell+direction): continue
			var point := Vector2(cell)+Vector2(0.5,0.5)+Vector2(direction)*0.5
			var edge := Vector2(-direction.y,direction.x)*0.5
			var a: float = layout.height_at(point-edge)
			var b: float = layout.height_at(point+edge)
			var bottom: float = minf(a,b)
			var height: float = maxf(layout.roof_height(cell)+absf(a-b),closure_top-bottom)
			var key := Vector2i(floori(cell.x/float(walls.CHUNK_CELLS)),floori(cell.y/float(walls.CHUNK_CELLS)))
			var name: String = "WallArchitecture_"+str(key.x)+"_"+str(key.y)
			if not expected.has(name): expected[name] = {"counts":[0,0,0],"bounds":[null,null,null]}
			var chunk: Dictionary = expected[name]
			for part in walls.profile(chapter,size,height,absi(cell.x*17+cell.y*31+direction.x+direction.y)):
				var material: int = int(part[6])
				chunk.counts[material] += 36
				var vertices: PackedVector3Array = walls._vertices(part,Vector3(point.x*size,bottom,point.y*size),Vector3(-direction.y,0,direction.x),Vector3(direction.x,0,direction.y))
				for vertex in vertices:
					chunk.bounds[material] = AABB(vertex,Vector3.ZERO) if chunk.bounds[material] == null else chunk.bounds[material].expand(vertex)
	var actual: Dictionary = {}
	for node in level.get_children():
		if str(node.name).begins_with("WallArchitecture_"): actual[str(node.name)] = node
	checks.wall_chunks = not expected.is_empty() and actual.size()==expected.size() and expected.keys().all(func(name): return actual.has(name))
	if not checks.wall_chunks: return checks
	var draw_valid: bool = true
	var collision_valid: bool = true
	for name in expected:
		var root = actual[name]
		var chunk: Dictionary = expected[name]
		if not root is StaticBody3D or root.get_parent()!=level or root.transform!=Transform3D.IDENTITY:
			draw_valid=false;collision_valid=false;continue
		var meshes: Array = root.get_children().filter(func(node): return node is MeshInstance3D)
		var colliders: Array = root.get_children().filter(func(node): return node is CollisionShape3D)
		if not root.is_visible_in_tree() or meshes.size()!=3 or root.get_child_count()!=4: draw_valid=false
		if meshes.size()==3:
			for index in range(3):
				var mesh: MeshInstance3D = meshes[index]
				if not mesh.is_visible_in_tree() or mesh.transform!=Transform3D.IDENTITY or not mesh.mesh is ArrayMesh or mesh.mesh.get_surface_count()!=1 or not mesh.material_override is StandardMaterial3D:
					draw_valid=false;continue
				var arrays: Array = mesh.mesh.surface_get_arrays(0)
				var bounds: AABB = mesh.mesh.get_aabb()
				var wanted: AABB = chunk.bounds[index]
				if arrays[Mesh.ARRAY_VERTEX].size()!=chunk.counts[index] or arrays[Mesh.ARRAY_NORMAL].size()!=chunk.counts[index] or arrays[Mesh.ARRAY_TEX_UV].size()!=chunk.counts[index] or not bounds.position.is_equal_approx(wanted.position) or not bounds.size.is_equal_approx(wanted.size) or mesh.material_override.cull_mode!=BaseMaterial3D.CULL_BACK or mesh.material_override.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED: draw_valid=false
		var expected_faces: int = int(chunk.counts[0])+int(chunk.counts[1])+int(chunk.counts[2])
		if root.collision_layer!=1 or colliders.size()!=1:
			collision_valid=false
		else:
			var collider: CollisionShape3D = colliders[0]
			if collider.disabled or collider.transform!=Transform3D.IDENTITY or not collider.shape is ConcavePolygonShape3D or not collider.shape.backface_collision or collider.shape.get_faces().size()!=expected_faces: collision_valid=false
	checks.wall_draw_geometry=draw_valid
	checks.wall_collision=collision_valid
	return checks

func _export_art_checks() -> Dictionary:
	var expected_art = {}
	for art in Level.PURPOSE_ART.values()+Level.AMMO_ART+["marker_ivorykey"]: expected_art[art] = 0
	for spec in level.layout.data.heroes: expected_art[spec.id] = expected_art.get(spec.id,0)+1
	for spec in level.layout.data.scenery: expected_art[spec.art] = expected_art.get(spec.art,0)+1
	var models = {}
	var marker_models = {}
	for node in level.get_children():
		if node.scene_file_path.get_extension() != "glb": continue
		var art = node.scene_file_path.get_file().get_basename()
		var parts = [node]+node.find_children("*","MeshInstance3D",true,false)
		var meshes = parts.filter(func(part): return part is MeshInstance3D)
		if meshes.any(func(part): return part.mesh != null and part.mesh.get_surface_count() > 0):
			models[art] = models.get(art,0)+1
		if art.begins_with("marker_"):
			var nodes = [node]+node.find_children("*","",true,false)
			var visual_only = not nodes.any(func(part): return part is CollisionObject3D or part is CollisionShape3D or part is CollisionPolygon3D)
			if visual_only and not meshes.is_empty() and meshes.all(func(part): return part.mesh is ArrayMesh and part.mesh.get_surface_count() > 0):
				marker_models[node.get_instance_id()] = art
	var checks = _export_wall_architecture_checks()
	# Retired boundary kit remains a real loadable asset, not a required world placement.
	for legacy in ["ribbed_wall","conduit"]:
		var resource = load("res://assets/art/world/"+legacy+".glb")
		var valid: bool = resource is PackedScene
		if valid:
			var instance = resource.instantiate()
			var legacy_meshes: Array = ([instance]+instance.find_children("*","MeshInstance3D",true,false)).filter(func(node): return node is MeshInstance3D)
			valid = not legacy_meshes.is_empty() and legacy_meshes.any(func(node): return node.mesh != null and node.mesh.get_surface_count()>0)
			instance.free()
		checks["retained_asset_"+legacy] = valid
	var marker_ids = []
	var remaining = 0
	for spec in level.layout.data.pickups+level.layout.data.interactions:
		if spec.id in state.removed: continue
		remaining += 1
		var art: String = Level.PURPOSE_ART[spec.kind]
		if spec.kind == "key" and spec.key == "ivory": art = "marker_ivorykey"
		elif spec.kind == "ammo": art = Level.AMMO_ART[int(spec.weapon)]
		expected_art[art] = expected_art.get(art,0)+1
		var marker = level.markers.get(spec.id)
		var valid = is_instance_valid(marker) and marker is Node3D
		if valid:
			valid = marker.get_parent() == level and marker.scene_file_path == "res://assets/art/world/"+art+".glb" and marker_models.get(marker.get_instance_id(),"") == art and not marker.get_instance_id() in marker_ids
			var dropped_seal: bool = spec.get("kind") == "key" and spec.has("seal_bearer")
			var expected_visible: bool = SealGuardians.available(state,spec)
			var expected_position: Vector3 = SealGuardians.interaction_position(self,spec) if dropped_seal and expected_visible else level.layout.world_position(spec.cell)+Vector3.UP*.06
			valid = valid and marker.is_visible_in_tree() == expected_visible and marker.position.is_equal_approx(expected_position) and marker.scale.is_equal_approx(Vector3.ONE) and is_equal_approx(marker.rotation.y,deg_to_rad(180))
			if expected_visible:
				var marker_meshes = ([marker]+marker.find_children("*","MeshInstance3D",true,false)).filter(func(part): return part is MeshInstance3D)
				valid = valid and marker_meshes.all(func(part): return part.is_visible_in_tree())
			marker_ids.append(marker.get_instance_id())
		checks["marker_"+spec.id] = valid
	# Keep exact GLB interaction-marker ownership AND the separate finite book.
	var earned: Dictionary = _export_earned_checks()
	checks.merge(earned)
	checks["marker_count"] = level.markers.size() == remaining and earned.get("earned_marker_count",false) and earned.get("earned_marker_ownership",false)
	checks["earned_marker_negative_controls"] = _export_earned_negative_controls()
	for art in expected_art:
		checks["art_"+art] = models.get(art,0) == expected_art[art] if art.begins_with("marker_") else models.get(art,0) >= expected_art[art]
	return checks

func _export_title_audio_checks() -> Dictionary:
	var checks = {
		"title_recording": music.playback_context == "title" and ResourceLoader.exists(music.title_track) and music.player.stream is AudioStreamMP3 and music.player.stream.resource_path == music.title_track and music.player.stream.get_length() > 0,
		"title_transport": music.player.playing and music.player.has_stream_playback() and not music.player.stream_paused}
	checks["title_decoded_pcm"] = await ExportAudio.decoded_pcm(get_tree(), music.player)
	return checks

func _verify_export() -> void:
	var validation_home = OS.get_environment("HOME")
	if validation_home.get_file() != "validation-home" or not OS.get_user_data_dir().begins_with(validation_home+"/"):
		push_error("Export validation requires isolated HOME/userdata")
		get_tree().quit(1)
		return
	progress_path = "user://export_validation.json"
	if _verify_stall_requested(OS.get_cmdline_user_args()):
		var trace = load("res://scripts/app_frame_trace.gd").new()
		await trace.run(self)
		return
	var checks = {
		"native_metal_caches": _has_metal_shader_cache("res://.godot/shader_cache"),
		"notices": FileAccess.get_file_as_string("res://licenses/Godot-Third-Party.txt").contains(Engine.get_license_text()),
		"midi_sources": ExportAudio.retained_sources_present()}
	checks.merge(await _export_title_audio_checks())
	start_campaign(1)
	checks["start"] = playing and enemies.size() == 23 and music.player.stream is AudioStreamMP3
	checks["campaign_recordings"] = music.level_tracks.size() == 8
	for track in music.level_tracks: checks["campaign_recordings"] = checks["campaign_recordings"] and ResourceLoader.exists(track)
	checks["recorded_transport"] = music.player.playing and music.player.has_stream_playback()
	player.set_physics_process(false)
	for actor in enemies: actor.set_physics_process(false)
	checks["fire"] = await _verify_fire_tick() and state.ammo[1] == 89
	pause_game()
	checks["pause"] = get_tree().paused and not playing
	await restore_checkpoint()
	checks["checkpoint"] = playing and state.ammo[1] == 90
	var retained_music_player = music.player
	var map_ids = ["intake","foundry","processional","reliquary","nursery","ossuary","inversion","heart"]
	var verified_maps = []
	var loaded_roles = []
	var acquired_late_weapons = []
	var verify_level = func() -> void:
		var id: String = map_ids[state.level_index]
		checks[id+"_scene"] = playing and level.layout.data.id == id and state.position == level.layout.world_position(level.layout.data.spawn) and enemies.size() == level.layout.data.enemies.size()
		verified_maps.append(level.layout.data.id)
		checks[id+"_track"] = music.player.stream.resource_path == "res://audio/suno/"+id+".mp3" and music.player == retained_music_player
		checks[id+"_playback"] = music.player.playing and music.player.has_stream_playback()
		var art_checks = _export_art_checks()
		for check in art_checks: checks[id+"_"+check] = art_checks[check]
		player.set_physics_process(false)
		for actor in enemies:
			actor.set_physics_process(false)
			var cell = 256 if actor.kind in ["nursery_warden","choir_avatar"] else 128
			# Fixed qualified body contract: Worker has six physiology rows; other roles retain five.
			var expected_rows = 6 if actor.kind == "worker" else 5
			checks[id+"_actor_"+actor.id] = actor._current_map() and actor.hp > 0 and actor.sprite.texture is Texture2D and actor.sprite.texture.get_width() == cell*8 and actor.sprite.texture.get_height() == cell*expected_rows
			if not actor.kind in loaded_roles: loaded_roles.append(actor.kind)
		checks[id+"_decoded_pcm"] = await ExportAudio.decoded_pcm(get_tree(), music.player)
	await verify_level.call()
	state.complete_level()
	start_level()
	checks["foundry"] = playing and level.layout.data.id == "foundry" and state.position == level.layout.world_position(level.layout.data.spawn)
	checks["foundry_recording"] = music.player.stream.resource_path == "res://audio/suno/foundry.mp3" and music.player == retained_music_player
	var foundry_heroes = []
	for node in level.get_children():
		if node.scene_file_path.get_file().get_basename() in ["vertebral_furnace","marrow_crucible"]: foundry_heroes.append(node.scene_file_path)
	checks["foundry_art"] = foundry_heroes.size() == 2
	await verify_level.call()
	state.complete_level()
	start_level()
	checks["processional"] = playing and level.layout.data.id == "processional" and state.position == level.layout.world_position(level.layout.data.spawn)
	checks["processional_recording"] = music.player.stream.resource_path == "res://audio/suno/processional.mp3" and music.player == retained_music_player
	checks["processional_playback"] = music.player.playing and music.player.has_stream_playback()
	var processional_heroes = []
	for node in level.get_children():
		if node.scene_file_path.get_file().get_basename() in ["walking_bone_organ","ossified_palanquin"]: processional_heroes.append(node.scene_file_path)
	checks["processional_art"] = processional_heroes.size() == 2
	await verify_level.call()
	player.set_physics_process(false)
	var caster
	var caster_count = 0
	for actor in enemies:
		actor.set_physics_process(false)
		if actor.kind == "caster":
			caster_count += 1
			if actor.id == "processional_enemy_11": caster = actor
	checks["caster_art"] = caster_count == 4
	# Registered Worker13 now owns the original Scatter unlock/bundle; no floor gun.
	checks["scattergun"] = await _verify_registered_weapon(2,checks,"scattergun")
	if not checks["scattergun"]:
		push_error("Export workflow failed: registered Scatter carrier transaction")
		get_tree().quit(1)
		return
	checks["scattergun"] = checks["scattergun"] and state.owned_weapons==[0,1,2] and state.weapon==2 and state.ammo[2]==16
	checks["scattergun_fire"] = await _verify_fire_tick() and state.ammo[2] == 15
	player.position = level.layout.world_position([16.5,16.5])
	reset_supply_sweep()
	await get_tree().physics_frame
	await get_tree().physics_frame
	if caster != null:
		activate_encounter(caster.encounter_id)
		checks["caster_encounter"] = caster.active and "encounter:"+caster.encounter_id in state.removed
		caster._physics_process(0.05)
		caster._physics_process(0.70)
		checks["caster_art"] = checks["caster_art"] and caster.sprite.texture != null and caster.motion_mode == CharacterBody3D.MOTION_MODE_FLOATING
	var projectiles = 0
	for node in level.get_children():
		if node.get_script() == Enemy.Projectile: projectiles += 1
	checks["caster_flight"] = projectiles == 1
	# Continue actual inventory; the first registered new capability is earned
	# by production carrier death then real passive finite collection.
	set_process(false)
	for _index in range(3,8):
		state.complete_level()
		start_level()
		await verify_level.call()
		await get_tree().physics_frame
		await get_tree().physics_frame
		for weapon in [3,4,5]:
			if weapon in state.owned_weapons: continue
			var content: Dictionary = Campaign.EarnedSupplies.chapter(level.layout)
			if not content.grants.any(func(row): return row.kind=="unlock" and int(row.weapon)==weapon): continue
			var profile: Dictionary = Player.WEAPONS[weapon]
			var asset_id: String = String(profile.asset).get_file()
			checks[asset_id+"_pickup"] = await _verify_registered_weapon(weapon,checks,asset_id)
			if not checks[asset_id+"_pickup"]:
				push_error("Export workflow failed: registered carrier "+asset_id)
				get_tree().quit(1)
				return
			var before: int = int(state.ammo[weapon])
			player.camera.rotation.x = 0.6
			checks[asset_id+"_fire"] = await _verify_fire_tick() and state.ammo[weapon] == before-1 and player.cooldown > 0 and player.shot_flash > 0
			if weapon == 4:
				checks["marrow_launcher_projectile"] = level.get_children().filter(func(node): return node.get_script() == Player.Projectile).size() == 1
			acquired_late_weapons.append(weapon)

	checks["full8"] = verified_maps == map_ids
	checks["late_weapons"] = acquired_late_weapons == [3,4,5] and state.owned_weapons == [0,1,2,3,4,5]
	for kind in ["crawler","worker","caster","brute","guardian","summoner","nursery_warden","choir_avatar"]:
		checks["role_"+kind] = kind in loaded_roles
	for art in ["floor","wall","grate"]:
		var texture = load("res://assets/art/textures/"+art+".png")
		checks["texture_"+art] = texture is Texture2D and texture.get_width() > 0 and texture.get_height() > 0
	for weapon in Player.WEAPONS:
		var texture = load("res://assets/art/weapons/"+weapon.asset+".png")
		var asset_id: String = String(weapon.asset).get_file()
		checks["weapon_art_"+asset_id] = texture is Texture2D and texture.get_width() == 960 and texture.get_height() == 200
	show_title()
	music.stop()
	get_tree().paused = false
	# Existing native fixture grace: stopped effects release on the next audio mix.
	await get_tree().create_timer(0.1).timeout
	await get_tree().process_frame
	await get_tree().process_frame
	var export_failed: bool = false
	for check in checks:
		if not checks[check]:
			export_failed = true
			push_error("Export workflow failed: "+check)
	if export_failed:
		get_tree().quit(1)
		return
	print("PASS packaged title Ogg resource/transport/decoded PCM; audible-loop approval pending")
	print("PASS packaged title, start, fire, pause, checkpoint restoration, Foundry and Processional scene/art/recorded PCM, scattergun/caster flight, retained MIDI sources and notices")
	print("PASS packaged full8 scenes/art/recorded PCM: intake,foundry,processional,reliquary,nursery,ossuary,inversion,heart")
	print("PASS packaged retained MIDI sources: intake,foundry,processional,reliquary,nursery,ossuary,inversion,heart")
	print("PASS packaged late weapon pickups/fire/ammo: sawtooth_repeater,marrow_launcher,choir_disruptor; actor/boss imports: brute,guardian,summoner,nursery_warden,choir_avatar")
	print("PASS packaged finite carrier death/unlock/ammo conservation, no floor supplies and exact reservoir/corpse ownership")
	print("PASS packaged native Metal shader caches")
	print("PASS packaged isolated userdata")
	get_tree().quit()

# Opt-in shipped-PCK contract only. No external scripts, normal game path unchanged.
func _sprite_export_check(checks: Dictionary, key: String, passed: bool) -> void:
	checks[key] = passed
	if not passed: push_error("Packed sprite-hit contract failed: "+key)

func _sprite_export_actor(id: String, location: Vector3):
	var actor = Enemy.new()
	level.add_child(actor)
	actor.configure(self,{"id":id,"kind":"worker","cell":[.5,.5],"yaw":0})
	actor.position = location
	actor.set_physics_process(false) # Explicit arranged hit-geometry arena, NOT combat.
	actor.active = true
	enemies.append(actor)
	return actor

func _sprite_export_fire(checks: Dictionary, key: String, actor, damage: int) -> void:
	var hp: int = actor.hp
	var ammo: int = state.ammo[1]
	player.cooldown = 0 # Independent arranged discharge cases, not rate acceptance.
	var fired: bool = await _verify_fire_tick()
	_sprite_export_check(checks,key,fired and actor.hp==hp-damage and state.ammo[1]==ammo-1)

func _verify_sprite_hit_export() -> void:
	var checks: Dictionary = {}
	_sprite_export_check(checks,"clock",Engine.physics_ticks_per_second==60 and Engine.time_scale==1.0)
	_sprite_export_check(checks,"shipped_shared_module",ResourceLoader.exists("res://scripts/sprite_hit_query.gd") and load("res://scripts/sprite_hit_query.gd")==SpriteHitQuery)
	_sprite_export_check(checks,"no_shipped_tests",not DirAccess.dir_exists_absolute("res://tests") and not ResourceLoader.exists("res://tests/test_aim_resolution.gd") and not FileAccess.file_exists("res://tests/test_autoaim.gd"))
	var recording: WeakRef = weakref(music.player.stream) if music.player.stream != null else null
	music.stop()
	effects.set_paused(true)
	set_process(false)
	menu_scroll.hide()
	hud.hide()
	get_tree().paused = false
	state.new_campaign(1)
	level = Level.new()
	add_child(level)
	if not level.layout.load_level(0):
		_sprite_export_check(checks,"layout",false)
		await _sprite_export_finish(checks,recording)
		return
	_scene_level_index = 0
	player = Player.new()
	level.add_child(player)
	player.configure(self)
	player.set_physics_process(false)
	player.position = Vector3(0,.04,0)
	playing = true
	settings.auto_aim = false
	var actor = _sprite_export_actor("packed_analytic",Vector3(0,.04,-8))
	var image = Image.create(6,3,false,Image.FORMAT_RGBA8)
	image.fill(Color(0,0,0,0))
	image.set_pixel(1,1,Color.WHITE)
	image.set_pixel(2,1,Color.WHITE) # Visible right pixel lies outside movement capsule.
	actor.sprite.texture = ImageTexture.create_from_image(image)
	actor.sprite.hframes = 2
	actor.sprite.vframes = 1
	actor.sprite.frame = 0
	actor.sprite.pixel_size = 1.0
	actor.sprite.position = Vector3(0,1.55,0)
	actor.sprite.modulate = Color.WHITE
	actor.sprite.alpha_scissor_threshold = .5
	await get_tree().physics_frame
	await get_tree().physics_frame
	var origin: Vector3 = player.camera.global_position
	var hit: Dictionary = resolve_aim(origin,Vector3.FORWARD,40.0)
	_sprite_export_check(checks,"opaque_shared_contact",hit.actor_id==actor.id and hit.contact.get("coverage")=="visible_sprite" and hit.contact.get("frame_pixel")==Vector2i(1,1))
	await _sprite_export_fire(checks,"opaque_real_rivet",actor,22)
	player.camera.look_at(Vector3(-1,origin.y,-8),Vector3.UP)
	hit = resolve_aim(origin,-player.camera.global_basis.z,40.0)
	_sprite_export_check(checks,"transparent_hole",hit.actor_id.is_empty())
	await _sprite_export_fire(checks,"hole_real_rivet_no_damage",actor,0)
	player.camera.rotation = Vector3.ZERO
	actor.sprite.frame = 1
	hit = resolve_aim(origin,Vector3.FORWARD,40.0)
	_sprite_export_check(checks,"transparent_frame",hit.actor_id.is_empty())
	await _sprite_export_fire(checks,"frame_switch_real_rivet_no_damage",actor,0)
	actor.sprite.frame = 0
	player.camera.look_at(Vector3(1,origin.y,-8),Vector3.UP)
	var query = PhysicsRayQueryParameters3D.create(origin,origin-player.camera.global_basis.z*40,4)
	query.exclude = [player.get_rid()]
	_sprite_export_check(checks,"outside_capsule_setup",get_world_3d().direct_space_state.intersect_ray(query).is_empty())
	hit = resolve_aim(origin,-player.camera.global_basis.z,40.0)
	_sprite_export_check(checks,"outside_capsule_opaque",hit.actor_id==actor.id and hit.contact.get("frame_pixel")==Vector2i(2,1))
	await _sprite_export_fire(checks,"outside_capsule_real_rivet",actor,22)
	player.camera.rotation = Vector3.ZERO
	var wall = level._box(Vector3(4,4,.2),Vector3(0,2,-4),null,true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	hit = resolve_aim(origin,Vector3.FORWARD,40.0)
	_sprite_export_check(checks,"solid_wall",hit.actor_id.is_empty() and hit.contact.get("collider")==wall)
	await _sprite_export_fire(checks,"wall_real_rivet_no_damage",actor,0)
	wall.collision_layer = 0
	actor.collision_layer = 0
	var actual = _sprite_export_actor("packed_actual_worker",Vector3(0,.04,-8))
	var sprite: Sprite3D = actual.sprite
	var atlas: Image = sprite.texture.get_image()
	var valid: bool = atlas != null and not atlas.is_empty()
	if valid and atlas.is_compressed(): valid = atlas.decompress()==OK
	# Pin the approved production body URI independently of Enemy selection; legacy is not a fallback.
	_sprite_export_check(checks,"original_worker_atlas",valid and sprite.texture.resource_path=="res://assets/art/sprites/bodies-v1/worker.png")
	if valid:
		atlas.convert(Image.FORMAT_RGBA8)
		var size = Vector2i(atlas.get_width()/sprite.hframes,atlas.get_height()/sprite.vframes)
		var offset = Vector2i(sprite.frame%sprite.hframes,sprite.frame/sprite.hframes)*size
		var chosen = Vector2i(-1,-1)
		for y in range(size.y):
			for x in range(size.x):
				if atlas.get_pixelv(offset+Vector2i(x,y)).a>=sprite.alpha_scissor_threshold: chosen = Vector2i(x,y)
		_sprite_export_check(checks,"actual_frame_has_opaque_texel",chosen.x>=0)
		if chosen.x>=0:
			var local = Vector2(chosen)+Vector2(.5,.5)-Vector2(size)*.5
			var point: Vector3 = sprite.global_position+player.camera.global_basis.x*local.x*sprite.pixel_size-player.camera.global_basis.y*local.y*sprite.pixel_size
			var exclusions: Array[RID] = [player.get_rid()]
			var contact: Dictionary = SpriteHitQuery.cast(get_world_3d().direct_space_state,origin,origin+(point-origin).normalized()*40,player.camera,enemies,exclusions,5)
			_sprite_export_check(checks,"actual_independent_alpha_texel",contact.get("collider")==actual and contact.get("sprite_pixel")==offset+chosen)
		settings.auto_aim = true
		await _sprite_export_fire(checks,"actual_worker_real_rivet",actual,22)
	_sprite_export_check(checks,"six_finite_shots",state.ammo[1]==84)
	await _sprite_export_finish(checks,recording)

func _sprite_export_finish(checks: Dictionary, recording: WeakRef) -> void:
	playing = false
	music.stop()
	effects.stop()
	if is_instance_valid(level): level.queue_free()
	level = null
	player = null
	enemies.clear()
	get_tree().paused = false
	await get_tree().process_frame
	var deadline: int = Time.get_ticks_usec()+2000000
	while recording != null and recording.get_ref()!=null and Time.get_ticks_usec()<deadline:
		OS.delay_msec(2)
		await get_tree().process_frame
	_sprite_export_check(checks,"owned_menu_audio_released",recording==null or recording.get_ref()==null)
	await get_tree().process_frame
	call_deferred("_sprite_export_terminal",checks)

func _sprite_export_terminal(checks: Dictionary) -> void:
	# Let the probe coroutine release its Image/texture locals before shutdown.
	await get_tree().process_frame
	await get_tree().process_frame
	var passed: bool = checks.values().all(func(value): return value==true)
	print("PACKED_SPRITE_HIT_CONTRACT ",JSON.stringify(checks))
	if passed: print("PASS packed shared SpriteHitQuery/Player.fire opaque/hole/frame/outside-capsule/wall/actual-worker alpha and six finite shots; arranged unit, not campaign/render/input/listening")
	get_tree().quit(0 if passed else 1)
