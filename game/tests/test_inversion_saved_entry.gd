extends "res://tests/test_profile_workload.gd"

const Exit = preload("res://tests/ossuary_finale_exit_witness.gd")
const Campaign = preload("res://scripts/campaign.gd")

func run() -> void:
	prefix = "user://CONTROLLED_inversion_entry_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	release_actions()
	if not expect(Engine.physics_ticks_per_second == 60 and Engine.time_scale == 1.0,"Controlled Continue uses normal60Hz/time scale"):
		await finish(1)
		return
	var defaults = Campaign.new()
	defaults.new_campaign(1)
	# Controlled document boundary only: these are default resources, not an earned prefix.
	var document: Dictionary = Exit.entry_document(defaults._resources())
	var saved_state = Campaign.new()
	if not expect(saved_state.from_dict(document) and saved_state.to_dict() == document,"Actual independent Campaign accepts the exact C entry document"):
		await finish(1)
		return
	game = ObservedMain.new()
	game.settings_path = prefix+"_preferences.json"
	game.progress_path = prefix+"_campaign.json"
	game.state.new_campaign(1)
	root.add_child(game)
	if not expect(game.state.level_index == 0 and game.state.discoveries.is_empty() and game.state.to_dict() != document,"Main begins at distinct Intake state before disk restoration"):
		await finish(1)
		return
	if not expect(saved_state.save_progress(game.progress_path) == OK,"Write only unique controlled entry via independent atomic Campaign save"):
		await finish(1)
		return
	var saved: PackedByteArray = FileAccess.get_file_as_bytes(game.progress_path)
	var saved_sha: String = FileAccess.get_sha256(game.progress_path)
	var buttons: Array = game.menu.get_children().filter(func(node): return node is Button and node.text == "Continue")
	if not expect(buttons.size() == 1 and buttons[0].pressed.is_connected(Callable(game,"continue_campaign")),"Actual title Continue remains connected to production load/start") or not press_menu("Continue"):
		await finish(1)
		return
	for tick in range(120):
		if game.playing and not game.placement_pending: break
		await physics_frame
	if not expect(game.playing and not game.placement_pending and not paused and is_instance_valid(game.level) and is_instance_valid(game.player),"Actual Continue resolves restored placement within120 native ticks"):
		await finish(1)
		return
	if not expect(game.state.level_index == 6 and game.state.discoveries == [3,4,5],"Actual Continue must restore distinct C entry from disk"):
		await finish(1)
		return
	route_level = game.level
	route_player = game.player
	for tick in range(6): await physics_frame
	var data: Dictionary = route_level.layout.data
	var ok: bool = expect(data.id == "inversion" and data.spawn == [18.5,36.5] and data.enemies.size() == 30 and game.state.level_index == 6 and game._scene_level_index == 6 and game.state.difficulty == 1,"Real Centry Continue builds original Inversion metadata and30actor roster")
	ok = expect(game.is_processing() and game.is_physics_processing() and route_player.is_physics_processing() and route_player._current_map() and game.rate_ok,"Main/Player retain automatic native processing") and ok
	var point = clear_point(data.spawn)
	ok = expect(point != null and route_player.is_on_floor() and route_player.position.distance_to(route_level.layout.world_position(data.spawn)) < 0.1,"Zero-position entry resolves to authored spawn with real floor/capsule support") and ok
	var expected_ids: Array = data.enemies.map(func(spec): return spec.id)
	var actual_ids: Array = game.enemies.map(func(actor): return actor.id)
	expected_ids.sort()
	actual_ids.sort()
	ok = expect(actual_ids == expected_ids and game.enemies.all(func(actor): return actor._current_map() and actor.is_physics_processing() and actor.hp == actor.max_hp and actor.age >= 4.0/60.0),"All30original live actors advance automatically; no synthetic removal or staging") and ok
	ok = expect(game.state.health == 100 and game.state.armor == 0 and game.state.ammo == [0,90,0,0,0,0] and game.state.owned_weapons == [0,1] and game.state.weapon == 1 and game.state.keys.is_empty() and game.state.removed.is_empty(),"Prepared finite default resources survive Continue without grants/refunds/pickups") and ok
	ok = expect(game.state.discoveries == [3,4,5] and game.state.checkpoint_id == "entry" and game.state.checkpoint == document.checkpoint and game.state.level_start == document.level_start,"Controlled entry metadata and detached recovery envelopes remain unchanged") and ok
	ok = expect(FileAccess.get_file_as_bytes(game.progress_path) == saved and FileAccess.get_sha256(game.progress_path) == saved_sha,"Native placement/Continue never rewrites the prepared entry save") and ok
	print("CONTROLLED_INVERSION_ENTRY ",JSON.stringify({"map":data.id,"actors":game.enemies.size(),"health":game.state.health,"ammo":game.state.ammo,"position":[route_player.position.x,route_player.position.y,route_player.position.z],"saved_sha256":saved_sha,"scope":"prepared C entry document and actual Continue/placement only; not earned Ossuary exit, prefix traversal, physical input, GPU, listening or release acceptance"}))
	if ok: print("PASS CONTROLLED C saved-entry through actual title Continue into native Inversion; finite resources,30automaticoriginalactors and unchanged disk image")
	await finish(0 if ok else 1)
