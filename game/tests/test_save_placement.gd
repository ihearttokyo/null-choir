extends SceneTree

var game
var prefix = "user://placement_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
var forbidden = [Vector3.ZERO]
var unsafe_starts = [0]

func _initialize(): call_deferred("run")

func run():
	AudioServer.set_bus_mute(0,true)
	game = load("res://scripts/main.gd").new()
	game.progress_path = prefix+"_campaign.json"
	game.settings_path = prefix+"_preferences.json"
	root.add_child(game)
	game.set_process(false)
	game.hud.survey.set_physics_process(false)
	game.music.player.changed_tempo.connect(func(_tempo):
		if game.playing and game.state.position.is_equal_approx(forbidden[0]): unsafe_starts[0] += 1)
	for index in range(8):
		game.start_campaign(1)
		game.state.new_campaign(1)
		game.state.level_index = index
		await game.start_level()
		freeze()
		await physics_frame
		await physics_frame
		var entry: Vector3 = game.state.position
		game.state.health = 73
		game.state.armor = 21
		game.state.ammo[1] = 37
		game.state.discoveries = [0,3]
		game.state.explored = [[int(game.level.layout.data.spawn[0]),int(game.level.layout.data.spawn[1])]]
		var original: Dictionary = game.state.to_dict().duplicate(true)
		var door: Dictionary = game.level.layout.data.doors[0]
		var embedded: Vector3 = game.level.layout.world_position(door.cell)
		for point in [Vector3(99999,0,99999),embedded,entry-Vector3.UP*4,Vector3.ZERO]:
			var document = original.duplicate(true)
			document.position = [point.x,point.y,point.z]
			if not game.state.from_dict(document) or game._save() != OK:
				push_error("SETUP: strict real save boundary must admit structurally valid placement fixture")
				await finish(1)
				return
			forbidden[0] = point
			game.show_title()
			await game.continue_campaign()
			freeze()
			if unsafe_starts[0] != 0 or not game.playing or not game.state.position.is_equal_approx(entry):
				push_error("INTENDED RED G03: unsafe imported position must fall back before gameplay/capture/music startup, map="+str(index)+" point="+str(point))
				await finish(1)
				return
			if game.state.health != 73 or game.state.armor != 21 or game.state.ammo[1] != 37 or game.state.discoveries != [0,3] or game.state.explored != original.explored:
				push_error("Placement repair cannot refund resources or erase story/route knowledge")
				await finish(1)
				return
			if game.state.checkpoint != original.checkpoint or game.state.level_start != original.level_start:
				push_error("INTENDED RED: imported zero and placement repair must not overwrite recovery snapshots")
				await finish(1)
				return
			if not game.message.begins_with("RECOVERY POSITION REPAIRED"):
				push_error("Corrected placement must be visible to the player")
				await finish(1)
				return
		print("MEASURE native recovery placement map=",index," outside/closed-door/below-floor safe")
	# Both serialized recovery positions are also untrusted; authored entry is last.
	var invalid = game.state.to_dict().duplicate(true)
	var bad = [99999,0,99999]
	invalid.position = bad.duplicate()
	invalid.checkpoint.position = bad.duplicate()
	invalid.level_start.position = bad.duplicate()
	game.state.from_dict(invalid)
	game._save()
	var heart_entry: Vector3 = game.level.layout.world_position(game.level.layout.data.spawn)
	game.show_title()
	await game.continue_campaign()
	freeze()
	if not game.playing or not game.state.position.is_equal_approx(heart_entry) or game.state.health != 73 or game.state.ammo[1] != 37:
		push_error("Invalid current/checkpoint/start positions must use authored entry without resource refunds")
		await finish(1)
		return
	# This nonintegral position is on an actual recessed Nursery ramp triangle.
	game.start_campaign(1)
	game.state.new_campaign(1)
	game.state.level_index = 4
	await game.start_level()
	freeze()
	await physics_frame
	await physics_frame
	var fractional: Vector3 = game.level.layout.world_position([12.2,29.8])
	var ray = PhysicsRayQueryParameters3D.create(fractional+Vector3.UP*0.2,fractional-Vector3.UP*0.6,1)
	var floor_hit = game.level.get_world_3d().direct_space_state.intersect_ray(ray)
	if floor_hit.is_empty() or absf(floor_hit.position.y-fractional.y) > 0.003 or absf(fractional.y) < 0.001:
		push_error("SETUP: fractional fixture must stand on the real nonzero-height ramp, not an analytic-only floor")
		await finish(1)
		return
	game.state.position = fractional
	game._save()
	game.show_title()
	await game.continue_campaign()
	freeze()
	if not game.playing or not game.state.position.is_equal_approx(fractional):
		push_error("Legitimate fractional/elevated native floor restoration must not snap to entry")
		await finish(1)
		return
	game.state.health = 73
	game.state.armor = 21
	game.state.ammo[1] = 37
	var nursery: Dictionary = game.state.to_dict().duplicate(true)
	var nursery_entry: Vector3 = game.level.layout.world_position(game.level.layout.data.spawn)
	# Actual safe but distinct candidates prove priority and health eligibility.
	for candidate in ["checkpoint","dead_checkpoint","invalid_checkpoint","dead_both"]:
		var document = nursery.duplicate(true)
		document.position = bad.duplicate()
		document.checkpoint.position = [fractional.x,fractional.y,fractional.z]
		document.level_start.position = [nursery_entry.x,nursery_entry.y,nursery_entry.z]
		var expected = fractional
		if candidate == "dead_checkpoint" or candidate == "dead_both":
			document.checkpoint.health = 0
			expected = nursery_entry
		if candidate == "invalid_checkpoint":
			document.checkpoint.position = bad.duplicate()
			document.level_start.position = [fractional.x,fractional.y,fractional.z]
		if candidate == "dead_both": document.level_start.health = 0
		if not game.state.from_dict(document) or game._save() != OK:
			push_error("SETUP: distinct snapshot candidates must pass the real strict save boundary")
			await finish(1)
			return
		var saved_snapshots: Dictionary = game.state.to_dict().duplicate(true)
		game.show_title()
		await game.continue_campaign()
		freeze()
		if not game.playing or not game.state.position.is_equal_approx(expected) or game.state.health != 73 or game.state.armor != 21 or game.state.ammo[1] != 37 or game.state.checkpoint != saved_snapshots.checkpoint or game.state.level_start != saved_snapshots.level_start:
			push_error("Healthy native checkpoint/start priority must preserve current resources and snapshots: "+candidate)
			await finish(1)
			return
	# Block all native candidates during construction; recovery may never be bypassed.
	for action in ["resume","escape"]:
		game.state.from_dict(nursery)
		game._save()
		game.show_title()
		game.continue_campaign()
		var blocker = StaticBody3D.new()
		blocker.collision_layer = 1
		var shape = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(1000,10,1000)
		shape.shape = box
		blocker.add_child(shape)
		game.level.add_child(blocker)
		blocker.position = Vector3(0,2,0)
		await physics_frame
		await physics_frame
		await physics_frame
		if action == "resume": game.resume_game()
		else:
			var press = InputEventKey.new()
			press.physical_keycode = KEY_ESCAPE
			press.pressed = true
			Input.parse_input_event(press)
			await process_frame
			var release = press.duplicate()
			release.pressed = false
			Input.parse_input_event(release)
		if game.playing or Input.mouse_mode != Input.MOUSE_MODE_VISIBLE or game.level != null or not game.message.begins_with("NO SAFE RECOVERY POSITION"):
			push_error("INTENDED RED: all native candidates rejected must fail closed even after "+action)
			await finish(1)
			return
	# Queued old startup must never reactivate title or overwrite a replacement map.
	invalid = game.state.to_dict().duplicate(true)
	invalid.position = bad.duplicate()
	game.state.from_dict(invalid)
	game._save()
	for cancel in ["title","new_campaign","focus","pause","settings","controls","difficulty"]:
		game.show_title()
		game.continue_campaign()
		if game.playing or not game.placement_pending or Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
			push_error("Unverified native placement must remain nonplaying and uncaptured")
			await finish(1)
			return
		game.resume_game()
		if game.playing:
			push_error("Resume must not bypass pending placement validation")
			await finish(1)
			return
		match cancel:
			"title": game.show_title()
			"new_campaign":
				game.start_campaign(0)
				freeze()
			"focus": game._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
			"pause": game.pause_game()
			"settings": game.show_settings()
			"controls": game.show_controls()
			"difficulty": game.show_difficulty()
		await physics_frame
		await physics_frame
		await physics_frame
		if cancel == "new_campaign":
			if not game.playing or game.state.level_index != 0 or game.state.difficulty != 0 or game.placement_pending:
				push_error("Old pending continuation must not mutate replacement campaign")
				await finish(1)
				return
		elif game.playing or game.level != null or game.placement_pending:
			push_error("INTENDED RED: pending startup must not reactivate after menu/cancellation: "+cancel)
			await finish(1)
			return
		if cancel in ["settings","controls","difficulty"]:
			var selected_menu = {"settings":"SETTINGS","controls":"CONTROLS","difficulty":"RECOVERY PROTOCOL"}[cancel]
			if not game.menu_scroll.visible or game.menu.get_child(0).text != selected_menu:
				push_error("Pending startup must retain the menu the player actually selected: "+cancel)
				await finish(1)
				return
	# Revalidate existing alive-state invariants across the new native-frame yield.
	game.show_title()
	game.continue_campaign()
	game.state.damage(10000)
	await physics_frame
	await physics_frame
	await physics_frame
	if game.playing or not paused or Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		push_error("INTENDED RED: health becoming zero during placement wait cannot reactivate/capture dead gameplay")
		await finish(1)
		return
	print("PASS native eight-map imported-placement fallback before activation with current resources/story/routes preserved")
	await finish(0)

func freeze():
	game.player.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)

func finish(status: int):
	game.show_title()
	paused = false
	var until = Time.get_ticks_usec()+150000
	while Time.get_ticks_usec() < until: await process_frame
	game.free()
	await process_frame
	for suffix in ["_campaign.json","_campaign.json.tmp","_preferences.json","_preferences.json.tmp"]:
		var path = prefix+suffix
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	quit(status)
