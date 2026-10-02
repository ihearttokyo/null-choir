extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var game = load("res://scripts/main.gd").new()
	# This workflow never saves options or progress; do not read the player's preferences.
	game.settings_path = "user://hud_contract_unused_"+str(Time.get_ticks_usec())+".json"
	root.add_child(game)
	game.start_campaign(1)
	game.set_process(false)
	game.player.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)
	game.settings.head_bob = false
	game.settings.camera_shake = false
	game.message_time = 0
	await redraw(game)
	var name_label = game.hud.find_child("WeaponName",true,false)
	if not expect(name_label is Label and name_label.text == game.player.WEAPONS[1].name,"Selected weapon name must be visible in the live HUD"): return
	if not expect(game.hud.has_method("draw_state"),"Rendering must derive its presentation from the live-state helper"): return
	var view: Dictionary = game.hud.draw_state()
	if not expect(view.arsenal.size() == 6,"All six arsenal slots remain visible, including unavailable weapons"): return
	for index in 6:
		var slot: Dictionary = view.arsenal[index]
		var slot_label = game.hud.find_child("ArsenalSlot"+str(index+1),true,false)
		if not expect(slot_label is Label and slot_label.visible and not slot_label.text.is_empty(),"Each arsenal entry has a visible rendered slot"): return
		if not expect(slot.owned == (index in game.state.owned_weapons) and slot.selected == (index == game.state.weapon),"Arsenal ownership and selection come from campaign state"): return
		if not expect(slot.empty == (slot.owned and index > 0 and game.state.ammo[index] == 0),"Only an owned finite-ammo weapon can be empty"): return
	game.state.owned_weapons.append(2)
	game.state.weapon = 2
	game.state.ammo[2] = 0
	await redraw(game)
	view = game.hud.draw_state()
	if not expect(view.arsenal[2].owned and view.arsenal[2].empty and view.arsenal[2].selected and not view.arsenal[1].selected,"Newly owned empty scattergun is selected without losing other ownership"): return
	if not expect(name_label.text == game.player.WEAPONS[2].name and label_text(game,"AmmoValue") == "EMPTY","Selected empty weapon has its actual name and explicit EMPTY feedback"): return
	game.state.ammo[2] = 9999
	game.state.health = 200
	game.state.armor = 200
	await redraw(game)
	if not expect(label_text(game,"AmmoValue") == "9999" and label_text(game,"VitalValue") == "200" and label_text(game,"ArmorValue") == "200","Legacy over-cap reserves and legal maximum vitals show true amounts"): return
	game.state.weapon = 0
	game.state.health = 0
	game.state.armor = 0
	await redraw(game)
	if not expect(label_text(game,"AmmoValue") == "TOOL" and not game.hud.draw_state().arsenal[0].empty,"Impact tool is usable without invented ammunition"): return
	if not expect(label_text(game,"VitalValue") == "0" and label_text(game,"ArmorValue") == "0","Zero vitals remain explicit"): return
	game.state.health = 100
	game.state.weapon = 1
	await redraw(game)
	view = game.hud.draw_state()
	if not expect(view.seals.size() == 2 and not seal_owned(view,"blood") and not seal_owned(view,"ivory"),"Required seals derive from this map's authored requirements"): return
	if not expect(label_text(game,"Objective").contains("RECOVER SEALS") and label_text(game,"Objective").contains("0/2"),"Objective persists after the transient mission expires"): return
	var door: Dictionary = game.level.layout.data.doors[0]
	await face(game,door)
	if not expect(game.nearest_interaction().get("id") == door.id,"The real interaction query selects the aimed gate"): return
	await redraw(game)
	var prompt = game.hud.find_child("InteractionPrompt",true,false)
	if not expect(prompt is Label and prompt.text.contains("BLOOD") and prompt.text.contains("IVORY"),"Locked gate prompt names its missing seals"): return
	game.collect_key("blood_key")
	await redraw(game)
	view = game.hud.draw_state()
	if not expect(seal_owned(view,"blood") and not seal_owned(view,"ivory") and label_text(game,"Objective").contains("1/2"),"Recovering one seal updates persistent possession and progress"): return
	if not expect(prompt.text.contains("IVORY") and not prompt.text.contains("BLOOD"),"Gate prompt removes recovered requirements"): return
	game.collect_key("ivory_key")
	await redraw(game)
	if not expect(label_text(game,"Objective").contains("OPEN GATE") and prompt.text.contains("OPEN GATE"),"Both seals expose the gate-opening action"): return
	if not expect(game.unlock_door(door.id),"Real gate unlock succeeds with the recovered seals"): return
	await redraw(game)
	if not expect(label_text(game,"Objective").contains("REACH DESCENT"),"Opened gate changes the objective to descent"): return
	if not expect(not game.hud.draw_state().discovery and label_text(game,"Discovery").contains("UNREAD"),"Current optional discovery begins unread"): return
	game.state.discover(game.state.level_index)
	await redraw(game)
	if not expect(game.hud.draw_state().discovery and label_text(game,"Discovery").contains("RECOVERED") and label_text(game,"Discovery").contains("1/8"),"Discovery feedback preserves the full eight-level campaign"): return
	var exit_spec: Dictionary = {}
	for spec in game.level.layout.data.interactions:
		if spec.kind == "exit": exit_spec = spec
	await face(game,exit_spec)
	if not expect(game.nearest_interaction().get("kind") == "exit","The real query selects the visible descent point"): return
	var chord = InputEventKey.new()
	chord.physical_keycode = KEY_PRINT
	chord.pressed = true
	chord.ctrl_pressed = true
	chord.alt_pressed = true
	chord.shift_pressed = true
	chord.meta_pressed = true
	if not expect(game.preferences.bind_event("interact",chord),"A long real modifier chord can be bound without saving preferences"): return
	await redraw(game)
	var binding = game.hud.find_child("InteractionBinding",true,false)
	if not expect(prompt.text.contains("DESCEND") and binding is Label and binding.text.contains(game.preferences.binding_text("interact")),"Specific descent prompt uses the exact rebound desktop/gamepad binding"): return
	for label in [prompt,binding]:
		if not expect(label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART and label.clip_text,"Context and binding labels wrap within bounded native controls"): return
		var rect: Rect2 = label.get_global_rect()
		if not expect(rect.position.x >= 0 and rect.end.x <= 640 and rect.position.y >= 0 and rect.end.y <= 322,"Interaction labels stay inside the internal viewport above the instrument"): return
		if not expect(not rect.intersects(Rect2(288,148,64,64)),"Context labels leave the aiming center unobscured"): return
		if not expect(label.get_combined_minimum_size().y <= label.size.y,"Long binding and context fit their allocated height"): return
	for field in ["WeaponName","AmmoValue","VitalValue","ArmorValue"]:
		var label = game.hud.find_child(field,true,false)
		if not expect(label is Label,"Instrument exposes its actual rendered values"): return
		if not expect(label.get_visible_line_count() >= 1,"Actual vital, armor and ammo text must have a drawable visible line, not merely stored text (intended RED)"): return
		var rect: Rect2 = label.get_global_rect()
		if not expect(rect.position.x >= 0 and rect.end.x <= 640 and rect.position.y >= 322 and rect.end.y <= 360,"Instrument labels preserve the 38-pixel bottom footprint"): return
	var campaign_before: Dictionary = game.state.to_dict().duplicate(true)
	var preferences_before: Dictionary = game.preferences.to_dict().duplicate(true)
	game.hud.draw_state()
	await redraw(game)
	if not expect(game.state.to_dict() == campaign_before and game.preferences.to_dict() == preferences_before,"HUD derivation and refresh never mutate campaign or preferences"): return
	game.pause_game()
	await redraw(game)
	if not expect(not prompt.visible and not binding.visible,"Paused menus do not retain active interaction prompts"): return
	game.show_title()
	await redraw(game)
	if not expect(not name_label.visible and not prompt.visible,"Returning to title clears the instrument and context without stale map state"): return
	# Match native effects validation: stopped voices release on the next mix callback.
	await create_timer(0.1).timeout
	game.free()
	paused = false
	await process_frame
	print("PASS native HUD inventory, true resource values, seal/objective/discovery progression, real interaction/rebind prompts, bounds and read-only state")
	quit()

func redraw(game: Node) -> void:
	game.hud.queue_redraw()
	await process_frame
	await process_frame

func face(game: Node, spec: Dictionary) -> void:
	var location: Vector3 = game.level.layout.world_position(spec.cell)
	game.player.position = location+Vector3(0,0.04,3)
	var aim = location+Vector3(0,spec.size[1]/2 if spec.has("size") else 0.7,0)
	game.player.camera.look_at(aim,Vector3.UP)
	await physics_frame
	await physics_frame

func label_text(game: Node, field: String) -> String:
	var label = game.hud.find_child(field,true,false)
	return label.text if label is Label else ""

func seal_owned(view: Dictionary, key: String) -> bool:
	for seal in view.seals:
		if seal.key == key: return seal.owned
	return false

func expect(condition: bool, text: String) -> bool:
	if not condition:
		push_error(text)
		quit(1)
	return condition
