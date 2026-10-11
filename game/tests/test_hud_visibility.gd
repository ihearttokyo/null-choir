extends SceneTree

const CONDITIONAL = ["InteractionPrompt","InteractionBinding","BossTitle","BossHealth","BossPhase","Transmission"]
const REFRESHES = 4
var game
var prefix = "user://hud_visibility_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
var changes: Dictionary = {}

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
	game.set_process(false)
	game.set_process_unhandled_input(false)
	game.hud.set_process(false)
	game.start_campaign(1)
	if not expect(game.playing and is_instance_valid(game.player),"SETUP: native campaign must start before visibility measurement"): return
	freeze()
	await physics_frame
	await physics_frame
	game.message_time = 0
	for id in CONDITIONAL:
		var label = game.hud.message_label if id == "Transmission" else game.hud.labels.get(id)
		if not expect(label is Label,"SETUP: actual native conditional label "+id): return
		changes[id] = 0
		label.visibility_changed.connect(_visibility_changed.bind(id))
	game.hud._process(0)
	if not expect(game.nearest_interaction().is_empty() and game.hud.view.boss.is_empty(),"SETUP: quiet entry has no prompt or boss"): return
	for id in CONDITIONAL:
		if not expect(not game.hud.labels[id].visible,"SETUP: quiet conditional label must finish hidden: "+id): return
	if not await stable("quiet"): return

	game.state.health = 25
	game.state.armor = 200
	game.state.ammo[1] = 0
	game.hud._process(0)
	if not expect(game.hud.labels.VitalValue.text == "25" and game.hud.labels.ArmorValue.text == "200" and game.hud.labels.AmmoValue.text == "EMPTY","True vitals and empty ammunition remain explicit"): return
	if not await stable("empty_low_health"): return

	game.notify("HUD VISIBILITY TRANSMISSION",2)
	game.hud._process(0)
	if not expect(game.hud.message_label.visible and game.hud.message_label.text == game.message and game.hud.message_label.position.y == 64,"Live transmission keeps its text and ordinary position"): return
	if not await stable("message"): return
	game.pause_game()
	game.hud._process(0)
	if not expect(not game.hud.labels.VitalValue.visible and game.hud.message_label.visible and game.hud.message_label.position.y == 324,"Pause hides vitals but preserves the live transmission"): return
	if not await stable("paused_message"): return
	game._process(3)
	game.hud._process(0)
	if not expect(not game.hud.message_label.visible and game.hud.message_label.text.is_empty(),"Actual Main timer expires the paused transmission"): return
	if not await stable("paused_quiet"): return
	game.resume_game()
	if not expect(game.playing,"SETUP: actual Resume returns to play"): return

	var door: Dictionary = game.level.layout.data.doors[0]
	var location: Vector3 = game.level.layout.world_position(door.cell)
	game.player.position = location+Vector3(0,0.04,3)
	game.player.camera.look_at(location+Vector3(0,door.size[1]/2,0),Vector3.UP)
	await physics_frame
	await physics_frame
	var key = InputEventKey.new()
	key.physical_keycode = KEY_PRINT
	key.pressed = true
	key.ctrl_pressed = true
	if not expect(game.preferences.bind_event("interact",key),"SETUP: native control rebind succeeds"): return
	game.hud._process(0)
	if not expect(game.nearest_interaction().get("id","") == door.id and game.hud.labels.InteractionPrompt.visible and game.hud.labels.InteractionPrompt.text.contains("BLOOD") and game.hud.labels.InteractionPrompt.text.contains("IVORY"),"Actual aimed gate retains its missing-seal prompt"): return
	if not expect(game.hud.labels.InteractionBinding.visible and game.hud.labels.InteractionBinding.text == game.preferences.binding_text("interact"),"Prompt retains the exact native desktop/gamepad binding"): return
	if not await stable("prompt_rebound"): return

	game.state.new_campaign(1)
	game.state.level_index = 4
	game.start_level()
	if not expect(game.playing and is_instance_valid(game.player),"SETUP: native Nursery must start"): return
	freeze()
	await physics_frame
	await physics_frame
	var boss
	for actor in game.enemies:
		if actor.kind == "nursery_warden": boss = actor
	if not expect(is_instance_valid(boss),"SETUP: authored native Nursery Warden exists"): return
	for spec in game.level.layout.data.interactions:
		if spec.kind == "key": game.collect_key(spec.id)
	for gate in game.level.layout.data.doors:
		if not expect(game.unlock_door(gate.id),"SETUP: real seals unlock the boss gate"): return
	game.player.position = boss.position+Vector3(0,0,8)
	game.activate_encounter(boss.encounter_id)
	game.hud._process(0)
	if not expect(game.hud.labels.BossTitle.visible and game.hud.labels.BossHealth.visible and game.hud.labels.BossPhase.visible and game.hud.labels.BossTitle.text == "NURSERY WARDEN" and game.hud.labels.BossPhase.text == "MANIFEST" and game.hud.labels.BossHealth.text == "%d / %d" % [boss.hp,boss.max_hp],"Actual active boss retains full HP, title and phase"): return
	if not expect(game.hud.message_label.position.y == 100,"Boss transmission clears the encounter instrument"): return
	if not await stable("boss_manifest"): return
	boss.take_damage(int(boss.max_hp/2)+1,game.player)
	boss._physics_process(0)
	game.hud._process(0)
	if not expect(boss.phase == 1 and game.hud.labels.BossPhase.text == "RUPTURE" and game.hud.labels.BossHealth.text == "%d / %d" % [boss.hp,boss.max_hp],"Actual boss damage retains exact HP and latched rupture phase"): return
	if not await stable("boss_rupture"): return
	game.pause_game()
	game.hud._process(0)
	for id in ["InteractionPrompt","InteractionBinding","BossTitle","BossHealth","BossPhase"]:
		if not expect(not game.hud.labels[id].visible,"Pause hides live conditional instrument: "+id): return
	if not await stable("boss_paused"): return
	game.resume_game()
	boss.take_damage(100000,game.player)
	game.hud._process(0)
	if not expect(game.hud.view.boss.is_empty() and not game.hud.labels.BossTitle.visible and not game.hud.labels.BossHealth.visible and not game.hud.labels.BossPhase.visible and game.hud.labels.Objective.text == "REACH DESCENT" and game.hud.message_label.position.y == 64,"Real defeat clears the boss instrument and restores ordinary transmission placement"): return
	if not await stable("boss_defeated"): return

	game.notify("TITLE TRANSMISSION",1)
	game.show_title()
	game.hud._process(0)
	if not expect(game.hud.view.is_empty() and not game.hud.labels.VitalValue.visible and not game.hud.labels.InteractionPrompt.visible and not game.hud.labels.BossTitle.visible and game.hud.message_label.visible and game.hud.message_label.position.y == 324,"Title clears map labels without hiding the current transmission"): return
	if not await stable("title_message"): return
	game._process(2)
	game.hud._process(0)
	if not expect(not game.hud.message_label.visible and game.hud.message_label.text.is_empty(),"Title transmission expires through actual Main"): return
	if not await stable("title_quiet"): return
	print("PASS native HUD zero redundant visibility transitions with unchanged presentation and state")
	await finish(0)

func freeze() -> void:
	game.player.set_physics_process(false)
	game.player.set_process_unhandled_input(false)
	for actor in game.enemies: actor.set_physics_process(false)
	game.hud.survey.set_physics_process(false)

func _visibility_changed(id: String) -> void:
	changes[id] += 1

func presentation() -> Dictionary:
	var snapshot: Dictionary = {"view":game.hud.view.duplicate(true)}
	for id in game.hud.labels:
		var label: Label = game.hud.labels[id]
		snapshot[id] = [label.visible,label.text,label.position,label.size,label.get_theme_color("font_color"),label.autowrap_mode,label.clip_text,label.mouse_filter,label.horizontal_alignment]
	return snapshot

func stable(stage: String) -> bool:
	await physics_frame
	# Settle legitimate stage changes before counting synchronous native signals.
	game.hud._process(0)
	await process_frame
	await process_frame
	var before = presentation()
	var campaign: Dictionary = game.state.to_dict().duplicate(true)
	var preferences: Dictionary = game.preferences.to_dict().duplicate(true)
	for id in changes: changes[id] = 0
	# Diagnostic includes snapshot assertions; it is not a HUD/FPS benchmark.
	var started = Time.get_ticks_usec()
	for index in REFRESHES:
		game.hud._process(0)
		if not expect(presentation() == before,"PARITY: repeated refresh changed settled presentation: "+stage): return false
	var elapsed = Time.get_ticks_usec()-started
	var total = 0
	for id in changes: total += changes[id]
	print("HUD_VISIBILITY %s refreshes=%d changes=%s elapsed_usec=%d" % [stage,REFRESHES,str(changes),elapsed])
	if not expect(game.state.to_dict() == campaign and game.preferences.to_dict() == preferences,"PARITY: refresh mutated campaign or controls: "+stage): return false
	return expect(total == 0,"INTENDED RED: settled "+stage+" refreshes emitted redundant native visibility changes: "+str(changes))

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
