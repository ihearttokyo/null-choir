extends SceneTree

# Focused source regression, not a replacement for test_save_placement.gd.
# Physical cursor/foreground/capture, full campaign and pixels are UNPROVED.
var game
var prefix = "user://placement_menus_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())

func _initialize(): call_deferred("run")

func run():
	print("UNPROVED: physical cursor/foreground/capture, full campaign and pixels; focused menu/state regression only")
	AudioServer.set_bus_mute(0,true)
	game = load("res://scripts/main.gd").new()
	game.progress_path = prefix+"_campaign.json"
	game.settings_path = prefix+"_preferences.json"
	root.add_child(game)
	game.set_process(false)
	game.hud.survey.set_physics_process(false)
	game.state.new_campaign(1)
	game.state.level_index = 4
	await game.start_level()
	if not game.playing or not is_instance_valid(game.level) or not is_instance_valid(game.player):
		push_error("SETUP: real Nursery entry must create the level and player")
		await finish(1)
		return
	freeze()
	await physics_frame
	await physics_frame
	game.state.health = 73
	game.state.armor = 21
	game.state.ammo[1] = 37
	game.state.discoveries = [0,3]
	game.state.explored = [[int(game.level.layout.data.spawn[0]),int(game.level.layout.data.spawn[1])]]
	var document: Dictionary = game.state.to_dict().duplicate(true)
	document.position = [99999.0,0.0,99999.0]
	game.show_title()
	for elapsed_frames in [0,1]:
		for selection in ["settings","controls","difficulty"]:
			if not game.state.from_dict(document) or game._save() != OK:
				push_error("SETUP: each menu case must pass the real strict save boundary")
				await finish(1)
				return
			game.show_title()
			# Do not await Continue: select the menu inside its actual two-frame wait.
			game.continue_campaign()
			if not is_instance_valid(game.level) or not is_instance_valid(game.player):
				push_error("SETUP: real saved Continue must construct native level/player objects")
				await finish(1)
				return
			freeze()
			var old_level = weakref(game.level)
			var old_player = weakref(game.player)
			var pending_document: Dictionary = game.state.to_dict().duplicate(true)
			if elapsed_frames == 1: await physics_frame
			var context = "selection="+selection+" phase="+str(elapsed_frames)
			if game.playing or paused or not game.loaded_positions or not game.placement_pending or Input.mouse_mode != Input.MOUSE_MODE_VISIBLE or game.level != old_level.get_ref() or game.player != old_player.get_ref() or game.player.get_parent() != game.level or game.state.to_dict() != document:
				push_error("SETUP: imported placement must still be genuinely pending with unchanged native identities/state: "+context)
				await finish(1)
				return
			game.resume_game()
			if game.playing or not game.placement_pending or Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
				push_error("Resume must not bypass pending placement: "+context)
				await finish(1)
				return
			match selection:
				"settings": game.show_settings()
				"controls": game.show_controls()
				"difficulty": game.show_difficulty()
			var title: String = {"settings":"SETTINGS","controls":"CONTROLS","difficulty":"RECOVERY PROTOCOL"}[selection]
			if old_level.get_ref() == null or not old_level.get_ref().is_queued_for_deletion() or old_player.get_ref() == null or old_player.get_ref().get_parent() != old_level.get_ref():
				push_error("Menu cancellation must queue the actual old level and its player for teardown: "+context)
				await finish(1)
				return
			for settled_frame in range(4):
				if settled_frame > 0: await physics_frame
				if not cancelled(title,pending_document,context+" settled="+str(settled_frame)):
					await finish(1)
					return
			# queue_free is flushed at frame end, not at the physics-frame signal.
			await process_frame
			if old_level.get_ref() != null or old_player.get_ref() != null:
				push_error("Cancelled old native level/player must actually be freed: "+context)
				await finish(1)
				return
			if not cancelled(title,pending_document,context+" deletion flush"):
				await finish(1)
				return
			print("PASS focused pending menu ",context," immediate and three subsequent physics frames; old native objects freed")
	print("PASS focused six-case menu/state regression ONLY; broad save-placement acceptance is unchanged")
	print("UNPROVED: physical cursor/foreground/capture, full campaign and pixels")
	await finish(0)

func cancelled(title: String, expected_document: Dictionary, context: String) -> bool:
	if game.state.to_dict() != expected_document:
		push_error("Pending continuation must preserve resources/story/routes/recovery snapshots: "+context)
		return false
	if game.playing or not paused or game.level != null or game.player != null or game.placement_pending or Input.mouse_mode != Input.MOUSE_MODE_VISIBLE or not game.music.player.playing or game.music.player.stream_paused or not game.music.player.stream is AudioStreamOggVorbis or game.music.player.stream.resource_path != game.music.title_track:
		push_error("Pending continuation must not reactivate after menu cancellation: "+context)
		return false
	if not game.menu_scroll.visible or not game.menu.visible or game.menu.get_child_count() == 0 or game.menu.get_child(0).text != title:
		push_error("Pending continuation must preserve the actual selected menu: "+context)
		return false
	return true

func freeze():
	game.player.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)

func finish(status: int):
	game.show_title()
	game.music.stop()
	paused = false
	var until = Time.get_ticks_usec()+150000
	while Time.get_ticks_usec() < until: await process_frame
	game.free()
	await process_frame
	for suffix in ["_campaign.json","_campaign.json.tmp","_preferences.json","_preferences.json.tmp"]:
		var path = prefix+suffix
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	quit(status)
