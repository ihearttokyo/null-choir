extends SceneTree

var game
var prefix = "user://boss_hud_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func run() -> void:
	game = load("res://scripts/main.gd").new()
	game.settings_path = prefix+"_preferences.json"
	game.progress_path = prefix+"_campaign.json"
	root.add_child(game)
	# Frozen-player presentation fixtures still publish on the native physics clock.
	physics_frame.connect(game.observe_player)
	for index in [4,7]:
		game.state.new_campaign(2)
		game.state.level_index = index
		game.start_level()
		freeze()
		await settle()
		if not expect(game.hud.draw_state().get("boss",{}).is_empty(),"Dormant manifestation must not expose an encounter bar"): return
		for spec in game.level.layout.data.interactions:
			if spec.kind == "key": game.collect_key(spec.id)
		for door in game.level.layout.data.doors: game.unlock_door(door.id)
		var boss = game.enemies.filter(func(actor): return actor.kind == ("nursery_warden" if index == 4 else "choir_avatar"))[0]
		game.player.position = boss.position+Vector3(0,0,8)
		game._process(0)
		game.hud._process(0)
		var view: Dictionary = game.hud.draw_state()
		if not expect(not view.get("boss",{}).is_empty(),"INTENDED RED: active native manifestation requires its real restraint HP instrument"): return
		if not expect(view.boss.id == boss.id and view.boss.hp == boss.hp and view.boss.max_hp == boss.max_hp and view.boss.phase == 0,"Instrument derives exact current native boss HP/maximum/phase"): return
		if not expect(view.objective == "BREAK THE RESTRAINT","Opened two-seal gate cannot advertise descent while its manifestation lives"): return
		var title: Label = game.hud.find_child("BossTitle",true,false)
		var health: Label = game.hud.find_child("BossHealth",true,false)
		var phase: Label = game.hud.find_child("BossPhase",true,false)
		await process_frame
		if not expect(title != null and health != null and phase != null and title.visible and health.visible and phase.visible,"Actual native labels expose the boss instrument"): return
		if not expect(title.text == ("NURSERY WARDEN" if index == 4 else "CHOIR AVATAR") and health.text == str(boss.hp)+" / "+str(boss.max_hp) and phase.text == "MANIFEST","Full-strength boss title, HP and phase have exact readable copy"): return
		for label in [title,health,phase]:
			if not expect(label.get_visible_line_count() == label.get_line_count() and label.get_line_count() == 1,"Instrument must not clip any boss label at 640x360"): return
		if not expect(game.hud.message_label.position.y >= 100,"Transient transmission must clear the active restraint instrument"): return
		boss.take_damage(int(boss.max_hp/2)+1,game.player)
		boss._physics_process(0)
		game.hud._process(0)
		view = game.hud.draw_state()
		if not expect(view.boss.hp == boss.hp and view.boss.phase == 1 and phase.text == "RUPTURE" and health.text == str(boss.hp)+" / "+str(boss.max_hp),"Real damage and latched below-half phase update actual labels without a cached estimate"): return
		var exit = game.level.layout.data.interactions.filter(func(spec): return spec.kind == "exit")[0]
		game.player.position = game.level.layout.world_position(exit.cell)+Vector3(0,0.04,1.3)
		game.player.camera.look_at(game.level.layout.world_position(exit.cell)+Vector3.UP*0.7,Vector3.UP)
		await settle()
		game.hud._process(0)
		if not expect(game.nearest_interaction().get("id","") == exit.id and game.hud.draw_state().prompt == "MANIFESTATION STILL LIVING","Real aimed exit explains its persisted boss requirement"): return
		game.pause_game()
		game.hud._process(0)
		if not expect(not title.visible and not health.visible and not phase.visible,"Paused menus hide all encounter labels"): return
		game.resume_game()
		await settle()
		boss.take_damage(100000,game.player)
		game.hud._process(0)
		view = game.hud.draw_state()
		if not expect(view.boss.is_empty() and not title.visible and not health.visible and not phase.visible and view.objective == "REACH DESCENT" and view.prompt == "DESCEND","One-shot manifested death removes the instrument and releases actual descent feedback"): return
		if not expect(game.hud.message_label.position.y == 64,"Ordinary transmission placement returns after defeat"): return
		game.show_title()
		game.hud._process(0)
		if not expect(game.hud.draw_state().is_empty() and not title.visible,"Retired map cannot retain a stale boss bar on title"): return
	print("PASS native boss HUD: dormant/active, exact HP/phase, readable labels, living-exit objective/prompt, pause/death/title and transmission clearance")
	await finish(0)

func freeze() -> void:
	game.set_process(false)
	game.player.set_physics_process(false)
	game.player.set_process_unhandled_input(false)
	for actor in game.enemies: actor.set_physics_process(false)

func settle() -> void:
	await physics_frame
	await physics_frame

func expect(condition: bool, detail: String) -> bool:
	if not condition:
		push_error(detail)
		finish.call_deferred(1)
	return condition

func finish(status: int) -> void:
	if is_instance_valid(game): game.show_title()
	paused = false
	await create_timer(0.1).timeout
	if is_instance_valid(game): game.free()
	await process_frame
	await process_frame
	for suffix in ["_campaign.json","_campaign.json.tmp","_preferences.json","_preferences.json.tmp"]:
		if FileAccess.file_exists(prefix+suffix): DirAccess.remove_absolute(prefix+suffix)
	quit(status)
