extends SceneTree

class MissingArtLayout extends "res://scripts/level_data.gd":
	func _art_exists(_id: String) -> bool: return false

class RetiredPlayer extends CharacterBody3D:
	var actions_cancelled: bool = false
	func cancel_actions() -> void: actions_cancelled = true

class NativeGame extends "res://scripts/main.gd":
	var attempted_level: WeakRef
	var rejected_layout = MissingArtLayout.new()
	func _ready() -> void:
		child_entered_tree.connect(_intercept_level)
		super._ready()
		set_process(false)
	func _intercept_level(child: Node) -> void:
		if child.get_script() != Level: return
		child.layout = rejected_layout
		attempted_level = weakref(child)


var game

func _initialize() -> void: call_deferred("run")

func run() -> void:
	AudioServer.set_bus_mute(0,true)
	game = NativeGame.new()
	var prefix = "user://invalid_level_start_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	game.settings_path = prefix+"_preferences.json"
	game.progress_path = prefix+"_campaign.json"
	root.add_child(game)
	game.hud.survey.set_physics_process(false)
	game.state.new_campaign(1)
	game.state.health = 73
	game.state.armor = 21
	game.state.ammo[1] = 37
	game.state.discoveries = [0,3]
	game.state.mark_checkpoint("entry",Vector3.ZERO)
	var before: Dictionary = game.state.to_dict().duplicate(true)
	for entry in ["start","loaded","checkpoint","restart"]:
		var old_level = Node3D.new()
		var old_player = RetiredPlayer.new()
		game.add_child(old_level)
		old_level.add_child(old_player)
		game.level = old_level
		game.player = old_player
		game.loaded_positions = entry == "loaded"
		match entry:
			"checkpoint": await game.restore_checkpoint()
			"restart": await game.restart_level()
			_: await game.start_level()
		if not expect(safe_menu("NULL CHOIR") and game.state.to_dict() == before,"Failed "+entry+" returns safely to title without changing campaign resources/recovery"): return
		if not expect(old_player.actions_cancelled and old_level.is_queued_for_deletion(),"Replacement cancels the stale player's actions and retires its map"): return
		old_player = null
		old_level = null
		if not expect(game.message.begins_with("LEVEL LOAD FAILED:") and "res://data/01_intake.json" in game.message and "heroes[0].id" in game.message and "retry" in game.message.to_lower(),"Actual loader error reaches the title with source, field and recovery action"): return
		var attempted = game.attempted_level.get_ref()
		if not expect(attempted != null and attempted.is_queued_for_deletion() and attempted.get_child_count() == 0,"Failed level is queued without geometry, player or enemies"): return
		attempted = null
		game.resume_game()
		if not expect(safe_menu("NULL CHOIR"),"Resume cannot enter a failed map"): return
		game.show_settings()
		for frame in range(4):
			if frame > 0: await physics_frame
			if not expect(safe_menu("SETTINGS") and game.state.to_dict() == before,"Failed start never overwrites selected Settings or reactivates after physics waits"): return
		await process_frame
		await process_frame
		if not expect(game.attempted_level.get_ref() == null,"Failed native level is actually freed"): return
	game.show_title()
	game.music.stop()
	await load("res://tests/wall_clock_wait.gd").seconds(self,0.15)
	game.free()
	paused = false
	print("PASS Main invalid source: start/loaded/checkpoint/restart fail before construction, safe title/error, Resume fence and Settings stability")
	print("UNPROVED: pixels, physical cursor/capture and full campaign; parent owns native execution")
	quit(0)

func safe_menu(title: String) -> bool:
	return not game.playing and paused and not game.placement_pending and game._scene_level_index == -1 and game.level == null and game.player == null and game.enemies.is_empty() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and game.menu_scroll.visible and game.menu.visible and game.menu.get_child(0).text == title and game.music.player.playing and not game.music.player.stream_paused and game.music.player.stream is AudioStreamOggVorbis and game.music.player.stream.resource_path == game.music.title_track

func expect(ok: bool, detail: String) -> bool:
	if not ok:
		push_error("Invalid level start: "+detail)
		if is_instance_valid(game): game.free()
		paused = false
		quit(1)
	return ok
