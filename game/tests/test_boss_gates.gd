extends SceneTree

var game
var prefix = "user://boss_gates_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())

func _initialize() -> void: call_deferred("run")

func run() -> void:
	# Prove missing authored manifestations before requiring new runtime behavior.
	for index in [4,7]:
		var layout = load("res://scripts/level_data.gd").new()
		if not expect(layout.load_level(index),"Boss map must actually load"): return
		var kind = "nursery_warden" if index == 4 else "choir_avatar"
		var bosses = layout.data.enemies.filter(func(spec): return spec.kind == kind)
		if not expect(bosses.size() == 1,"INTENDED RED: "+layout.data.id+" must author its real manifested "+kind): return
		var exit = layout.data.interactions.filter(func(spec): return spec.kind == "exit")[0]
		if not expect(exit.get("requires_defeated",[]) == [bosses[0].id],"Boss defeat is an explicit persisted descent requirement"): return
	game = load("res://scripts/main.gd").new()
	game.settings_path = prefix+"_preferences.json"
	game.progress_path = prefix+"_campaign.json"
	root.add_child(game)
	AudioServer.set_bus_mute(0,true)
	for index in [4,7]:
		for all_clues in ([false,true] if index == 7 else [false]):
			game.state.new_campaign(1)
			game.state.level_index = index
			if all_clues: game.state.discoveries = [0,1,2,3,4,5,6,7]
			game.start_level()
			freeze()
			var boss = game.enemies.filter(func(actor): return actor.kind == ("nursery_warden" if index == 4 else "choir_avatar"))[0]
			var boss_id: String = boss.id
			if not expect(not boss.active,"Manifestation stays dormant outside its real arena encounter"): return
			for spec in game.level.layout.data.interactions:
				if spec.kind == "key": game.collect_key(spec.id)
			for spec in game.level.layout.data.doors: game.unlock_door(spec.id)
			var exit = game.level.layout.data.interactions.filter(func(spec): return spec.kind == "exit")[0]
			game.player.position = game.level.layout.world_position(exit.cell)+Vector3(0,.04,1.3)
			game.player.camera.look_at(game.level.layout.world_position(exit.cell)+Vector3.UP*.7,Vector3.UP)
			await physics_frame
			await physics_frame
			if not expect(game.nearest_interaction().get("id","") == exit.id,"Actual exit pod must be interactable through native aim and cover"): return
			var before = game.state.to_dict().duplicate(true)
			game.interact()
			if not expect(game.playing and game.state.to_dict() == before and game.level != null,"Two seals cannot bypass a living boss or consume progress"): return
			boss.take_damage(100000,game.player)
			if not expect(boss.hp == 0 and game.state.removed.count(boss_id) == 1,"Actual manifested death persists once through the shared actor path"): return
			game.save_and_title()
			await game.continue_campaign()
			freeze()
			if not expect(game.playing and game.enemies.all(func(actor): return actor.id != boss_id),"Saved Continue retains defeat and cannot resurrect the boss"): return
			game.player.position = game.level.layout.world_position(exit.cell)+Vector3(0,.04,1.3)
			game.player.camera.look_at(game.level.layout.world_position(exit.cell)+Vector3.UP*.7,Vector3.UP)
			await physics_frame
			await physics_frame
			game.interact()
			if not expect(not game.playing and game.level == null and game.state.level_index == index+1,"Defeated manifestation permits exactly one actual exit"): return
			if index == 7:
				var title = game.menu.get_child(0).text
				if not expect(title == ("YOUR VOICE ISSUED THE FIRST ORDER\nTHE RESTRAINT WAS BUILT AROUND YOU" if all_clues else "THE RESTRAINT IS OPEN\nTHE VOICE NOW USES YOUR NAME"),"All eight optional discoveries change the actual final revelation"): return
				await game.continue_campaign()
				if not expect(game.menu.get_child(0).text == title and game.level == null,"Completed saved Continue returns to its real ending rather than development placeholder"): return
	await finish(0)
	print("PASS actual manifested boss gates, persisted defeat, two final revelations and completed Continue")
	quit()

func freeze() -> void:
	game.set_process(false)
	game.player.set_physics_process(false)
	game.player.set_process_unhandled_input(false)
	for actor in game.enemies: actor.set_physics_process(false)

func expect(condition: bool, detail: String) -> bool:
	if not condition:
		push_error(detail)
		finish.call_deferred(1)
	return condition

func finish(status: int) -> void:
	if is_instance_valid(game): game.show_title()
	paused = false
	await create_timer(.1).timeout
	if is_instance_valid(game): game.free()
	await process_frame
	await process_frame
	for suffix in ["_campaign.json","_campaign.json.tmp","_preferences.json","_preferences.json.tmp"]:
		if FileAccess.file_exists(prefix+suffix): DirAccess.remove_absolute(prefix+suffix)
	if status != 0: quit(status)
