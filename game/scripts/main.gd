extends Node3D

const Campaign = preload("res://scripts/campaign.gd")
const Level = preload("res://scripts/level.gd")
const Player = preload("res://scripts/player.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Hud = preload("res://scripts/hud.gd")
const Music = preload("res://audio/music.gd")
const ExportAudio = preload("res://audio/export_audio_check.gd")
const Effects = preload("res://audio/effects.gd")
const Preferences = preload("res://scripts/preferences.gd")
const AmmoVisuals = preload("res://scripts/ammo_visuals.gd")
var state = Campaign.new()
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
	Input.joy_connection_changed.connect(_interaction_device_changed)

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
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	if "--verify-export" in OS.get_cmdline_user_args(): AudioServer.set_bus_mute(0,true)
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
	show_title()
	if "--verify-export" in OS.get_cmdline_user_args(): call_deferred("_verify_export")

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
	if is_instance_valid(player): player.cancel_actions()
	# Reuse the atomic Campaign boundary for all three selected resource envelopes.
	var candidate = Campaign.new()
	if not candidate.from_dict(state.to_dict()):
		if not candidate.level_load_error.is_empty():
			_level_load_failed(candidate.level_load_error)
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
	message = level.layout.data.mission
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
			notify("NO SAFE RECOVERY POSITION",8)
			return
	menu_scroll.hide()
	player.cancel_actions()
	playing = true
	_capture_game_mouse()
	if music != null:
		music.set_paused(false)
		music.set_pressure(0)
		music.play_level(state.level_index)

func _capture_game_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

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
		if not space.intersect_shape(query,1).is_empty(): return false
		var cell = Vector2(actor.position.x,actor.position.z)/float(layout.data.cell_size)
		var floor_point: Vector3 = layout.world_position([cell.x,cell.y])
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
	var snapshot: Dictionary = {"removed":state.removed.duplicate(),"actors":[]}
	for actor in enemies:
		if is_instance_valid(actor) and actor._current_map() and actor.hp > 0:
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
		notify("RECOVERY POSITION REPAIRED: HEALTHY SNAPSHOT",8)
		return true
	var entry: Vector3 = level.layout.world_position(level.layout.data.spawn)
	if not _valid_saved_position(entry): return false
	state.position = entry
	player.position = entry+Vector3.UP*0.04
	notify("RECOVERY POSITION REPAIRED: LEVEL ENTRY",8)
	return true

func _process(delta: float) -> void:
	message_time = maxf(0,message_time-delta)
	damage_flash = maxf(0,damage_flash-delta)
	hit_flash = maxf(0,hit_flash-delta)
	if playing and player != null:
		var cell = Vector2(player.position.x,player.position.z)/float(level.layout.data.cell_size)
		for group in level.layout.data.get("encounters",[]):
			var r = group.region
			# World positions are float32; preserve inclusive authored edges after cell conversion.
			if cell.is_equal_approx(cell.clamp(Vector2(r[0],r[1]),Vector2(r[2],r[3]))) and _has_keys(group.get("requires",[])):
				activate_encounter(group.id)
		if music != null: music.set_pressure(_combat_pressure())
	hud.queue_redraw()

func _passive_scan_current(observer: CharacterBody3D, scene: Node3D) -> bool:
	if not Engine.is_in_physics_frame() or not is_inside_tree() or not playing or get_tree().paused or placement_pending or state.health <= 0 or _scene_level_index != state.level_index: return false
	if not is_instance_valid(scene) or level != scene or scene.is_queued_for_deletion() or scene.get_parent() != self or not scene.is_inside_tree(): return false
	return is_instance_valid(observer) and player == observer and observer._current_map() and observer.global_position.is_finite()

func update_passive_triggers(observer: CharacterBody3D) -> void:
	var scene = level
	if not _passive_scan_current(observer,scene) or _passive_scan_tick == Engine.get_physics_frames(): return
	# Latch before mutations: callbacks may reenter or retire this player/map.
	_passive_scan_tick = Engine.get_physics_frames()
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

func collect_key(id: String) -> void:
	if id in state.removed: return
	for spec in level.layout.data.interactions:
		if spec.id == id and spec.kind == "key":
			if not spec.key in state.keys: state.keys.append(spec.key)
			state.removed.append(id)
			level.remove_marker(id)
			level.refresh_machine_lights()
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
			for id in spec.get("requires_defeated",[]):
				if not id in state.removed:
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

func resume_game() -> void:
	if is_instance_valid(player): player.cancel_actions()
	if placement_pending or state.health <= 0 or not is_instance_valid(level) or level.is_queued_for_deletion(): return
	get_tree().paused = false
	playing = true
	menu_scroll.hide()
	_capture_game_mouse()
	if music != null: music.set_paused(false)
	if effects != null: effects.set_paused(false)

func _save() -> Error:
	if not _capture_actor_state():
		notify("SAVE FAILED: INVALID ACTOR IMAGE",8)
		return ERR_INVALID_DATA
	var result = state.save_progress(progress_path)
	if result != OK: notify("SAVE FAILED: "+error_string(result),8)
	return result

func save_and_title() -> void:
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
		music.stop()
	if effects != null: effects.stop()
	_show_menu("NULL CHOIR",[["New campaign",show_difficulty],["Continue",continue_campaign],["Settings",show_settings],["Quit",quit_game]])

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
	var revelation = "YOUR VOICE ISSUED THE FIRST ORDER\nTHE RESTRAINT WAS BUILT AROUND YOU" if state.discoveries.size() == 8 else "THE RESTRAINT IS OPEN\nTHE VOICE NOW USES YOUR NAME"
	_show_menu(revelation,[["New campaign",show_difficulty],["Return to title",show_title]])

func show_difficulty() -> void:
	_show_menu("RECOVERY PROTOCOL",[["Merciful",func(): start_campaign(0)],["Relentless",func(): start_campaign(1)],["Terminal",func(): start_campaign(2)],["Back",show_title]])

func show_settings() -> void:
	_show_menu("SETTINGS",[])
	for option in [["head_bob","Head bob"],["camera_shake","Camera shake"],["reduced_damage_flashes","Reduced damage flashes"],["invert_y","Invert Y"],["auto_aim","Classic auto-aim"]]:
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
	if placement_pending: show_title()
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
	message = text
	message_time = duration

func shot(weapon: int) -> void:
	if effects != null: effects.play(["tool","rivet","scatter","rivet","scatter","caster_charge"][clampi(weapon,0,5)])
	if weapon in [1,2,3]:
		var visuals = ammo_visuals()
		if visuals != null and is_instance_valid(player): visuals.casing(player)
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
	var query := PhysicsRayQueryParameters3D.create(origin,origin+direction*max_range,1|4)
	query.exclude = [player.get_rid()]
	var manual := space.intersect_ray(query)
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
		var shape_node: CollisionShape3D
		for child in actor.get_children():
			if child is CollisionShape3D and child.shape is CapsuleShape3D:
				shape_node = child
				break
		if shape_node == null: continue
		var capsule: CapsuleShape3D = shape_node.shape
		var center := shape_node.global_position
		var half_line := maxf(0,capsule.height*.5-capsule.radius)
		var toward_camera := shape_node.global_basis.inverse()*(origin-center)
		var points: Array[Vector3] = []
		for height in [clampf(toward_camera.y,-half_line,half_line),0.0,half_line]:
			points.append(shape_node.to_global(Vector3(0,height,0)))
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
			query.to = origin+resolved*max_range
			var hit := space.intersect_ray(query)
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

func _export_art_checks() -> Dictionary:
	var expected_art = {"ribbed_wall":1,"conduit":1}
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
			if visual_only and not meshes.is_empty() and meshes.all(func(part): return part.is_visible_in_tree() and part.mesh is ArrayMesh and part.mesh.get_surface_count() > 0):
				marker_models[node.get_instance_id()] = art
	var checks = {}
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
			valid = valid and marker.is_visible_in_tree() and marker.position.is_equal_approx(level.layout.world_position(spec.cell)+Vector3.UP*0.06) and marker.scale.is_equal_approx(Vector3.ONE) and is_equal_approx(marker.rotation.y,deg_to_rad(180))
			marker_ids.append(marker.get_instance_id())
		checks["marker_"+spec.id] = valid
	checks["marker_count"] = level.markers.size() == remaining
	for art in expected_art:
		checks["art_"+art] = models.get(art,0) == expected_art[art] if art.begins_with("marker_") else models.get(art,0) >= expected_art[art]
	return checks

func _verify_export() -> void:
	var validation_home = OS.get_environment("HOME")
	if validation_home.get_file() != "validation-home" or not OS.get_user_data_dir().begins_with(validation_home+"/"):
		push_error("Export validation requires isolated HOME/userdata")
		get_tree().quit(1)
		return
	progress_path = "user://export_validation.json"
	var checks = {
		"native_metal_caches": _has_metal_shader_cache("res://.godot/shader_cache"),
		"notices": FileAccess.get_file_as_string("res://licenses/Godot-Third-Party.txt").contains(Engine.get_license_text()),
		"midi_sources": ExportAudio.retained_sources_present()}
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
			checks[id+"_actor_"+actor.id] = actor._current_map() and actor.hp > 0 and actor.sprite.texture is Texture2D and actor.sprite.texture.get_width() == cell*8 and actor.sprite.texture.get_height() == cell*5
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
	player.position = level.layout.world_position([20.5,25.5])
	await _verify_passive_tick()
	_process(0)
	checks["scattergun"] = state.owned_weapons == [0,1,2] and state.weapon == 2 and state.ammo[2] == 16 and ResourceLoader.exists("res://assets/art/weapons/scattergun.png")
	checks["scattergun_fire"] = await _verify_fire_tick() and state.ammo[2] == 15
	player.position = level.layout.world_position([16.5,16.5])
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
	# Continue the actual campaign inventory; acquire late weapons at their authored pickup cells.
	set_process(false)
	for _index in range(3,8):
		state.complete_level()
		start_level()
		await verify_level.call()
		await get_tree().physics_frame
		await get_tree().physics_frame
		for spec in level.layout.data.pickups:
			if spec.kind != "weapon" or int(spec.weapon) < 3 or int(spec.weapon) in state.owned_weapons: continue
			var weapon = int(spec.weapon)
			var profile = Player.WEAPONS[weapon]
			var before = state.ammo[weapon]
			player.position = level.layout.world_position(spec.cell)
			await _verify_passive_tick()
			_process(0)
			checks[profile.asset+"_pickup"] = weapon in state.owned_weapons and state.weapon == weapon and spec.id in state.removed and state.ammo[weapon] == mini(profile.max_ammo,before+int(spec.amount))
			before = state.ammo[weapon]
			player.camera.rotation.x = 0.6
			checks[profile.asset+"_fire"] = await _verify_fire_tick() and state.ammo[weapon] == before-1 and player.cooldown > 0 and player.shot_flash > 0
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
		checks["weapon_art_"+weapon.asset] = texture is Texture2D and texture.get_width() == 960 and texture.get_height() == 200
	show_title()
	get_tree().paused = false
	# Existing native fixture grace: stopped effects release on the next audio mix.
	await get_tree().create_timer(0.1).timeout
	await get_tree().process_frame
	await get_tree().process_frame
	for check in checks:
		if not checks[check]:
			push_error("Export workflow failed: "+check)
			get_tree().quit(1)
			return
	print("PASS packaged title, start, fire, pause, checkpoint restoration, Foundry and Processional scene/art/recorded PCM, scattergun/caster flight, retained MIDI sources and notices")
	print("PASS packaged full8 scenes/art/recorded PCM: intake,foundry,processional,reliquary,nursery,ossuary,inversion,heart")
	print("PASS packaged retained MIDI sources: intake,foundry,processional,reliquary,nursery,ossuary,inversion,heart")
	print("PASS packaged late weapon pickups/fire/ammo: sawtooth_repeater,marrow_launcher,choir_disruptor; actor/boss imports: brute,guardian,summoner,nursery_warden,choir_avatar")
	print("PASS packaged native Metal shader caches")
	print("PASS packaged isolated userdata")
	get_tree().quit()
