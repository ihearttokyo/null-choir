extends "res://tests/test_passive_trigger_occlusion.gd"

class FrameMain:
	extends "res://scripts/main.gd"
	var captures: int = 0
	var saves: int = 0
	var callback_ticks: Array[int] = []
	var outside_visibility: int = 0
	var observer_ticks: int = 0
	var cancel_on_collect: bool = false
	func _physics_process(_delta: float) -> void:
		observer_ticks += 1 # Deliberately no super: Player still owns passive publication.
	func _passive_trigger_visible(spec: Dictionary) -> bool:
		if str(spec.id).begins_with("fixture_physics_"):
			if Engine.is_in_physics_frame(): callback_ticks.append(Engine.get_physics_frames())
			else: outside_visibility += 1
		return super._passive_trigger_visible(spec)
	func _capture_actor_state() -> bool:
		captures += 1
		return super._capture_actor_state()
	func _save() -> Error:
		saves += 1
		return super._save()
	func collect_pickup(id: String) -> void:
		super.collect_pickup(id)
		if cancel_on_collect and id == "fixture_physics_ammo": show_title()

class PhysicsStep:
	extends Node
	var game
	var observer
	var pending: bool = false
	var steps: int = 0
	func _physics_process(_delta: float) -> void:
		if not pending: return
		pending = false
		game.update_passive_triggers(observer)
		game.update_passive_triggers(observer)
		steps += 1

func run() -> void:
	release_actions()
	for suffix in ["_campaign.json","_campaign.json.tmp","_preferences.json","_preferences.json.tmp"]:
		if not expect(not FileAccess.file_exists(prefix+suffix),"SETUP: isolated physics profile must be new"):
			AudioServer.set_bus_mute(0,previous_mute)
			Input.mouse_mode = previous_mouse
			quit(1)
			return
	game = FrameMain.new()
	game.settings_path = prefix+"_preferences.json"
	game.progress_path = prefix+"_campaign.json"
	root.add_child(game)
	game.set_process(false)
	game.set_process_unhandled_input(false)
	var physics_ok: bool = await callback_boundary()
	if not physics_ok:
		await finish(1)
		return
	retire_level()
	await settle()
	var pickup_ok: bool = await pair("ammo",1.1)
	retire_level()
	await settle()
	var checkpoint_ok: bool = await pair("checkpoint",2.4)
	retire_level()
	await settle()
	var west_ok: bool = await earned_west()
	if physics_ok and pickup_ok and checkpoint_ok and west_ok:
		print("PASS actual physics callback ownership, once-per-tick/reentry/lifecycle fences and native wall pairs. Controlled poses/input; not a threaded-space, performance, physical-control or packaged-app claim.")
	await finish(0 if physics_ok and pickup_ok and checkpoint_ok and west_ok else 1)

func callback_boundary() -> bool:
	game.state.new_campaign(1)
	game.loaded_positions = false
	await game.start_level()
	game.player.set_physics_process(false)
	game.player.set_process_unhandled_input(false)
	game.hud.survey.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)
	var entry: Vector3 = game.level.layout.world_position(game.level.layout.data.spawn)
	game.player.position = entry+Vector3.UP*0.04
	game.player.velocity = Vector3.ZERO
	var cell: Array = [game.level.layout.data.spawn[0]+1.1/float(game.level.layout.data.cell_size),game.level.layout.data.spawn[1]]
	var spec: Dictionary = {"id":"fixture_physics_ammo","kind":"ammo","cell":cell,"weapon":1,"amount":35}
	game.level.layout.data.pickups.append(spec)
	game.level.markers[spec.id] = game.level._place_marker(spec)
	await settle()
	if not await in_physics(func(): return floor_and_capsule(entry)) or not await in_physics(func(): return rays(game.level.layout.world_position(cell),null)): return false
	if not expect(not Engine.is_in_physics_frame(),"SETUP: nonphysics probe must actually run outside physics"): return false
	# This assertion is RED on the retained baseline, even with single-thread physics.
	if not expect(not game._passive_trigger_visible(spec),"Nonphysics helper must reject before direct-space access"): return false
	var before: Dictionary = game.state.to_dict().duplicate(true)
	game.outside_visibility = 0
	game._process(0)
	if not expect(game.state.to_dict() == before and game.outside_visibility == 0,"Render callback performs no passive query or grant"): return false
	if not expect(game.has_method("update_passive_triggers"),"Physics-owned passive boundary must exist"): return false
	game.update_passive_triggers(game.player)
	if not expect(game.state.to_dict() == before and game.outside_visibility == 0,"Explicit nonphysics facade does not query or mutate"): return false
	var driver = PhysicsStep.new()
	driver.process_mode = Node.PROCESS_MODE_ALWAYS
	driver.game = game
	driver.observer = game.player
	root.add_child(driver)
	game.state.ammo[1] = 180
	game.callback_ticks.clear()
	await step(driver)
	var good: bool = expect(game.callback_ticks.size() == 1 and not spec.id in game.state.removed,"Two facade calls in one actual callback scan once; full supply stays available")
	# No published visibility is replayed after an idle pose/resource change.
	game.state.ammo[1] = 100
	game.player.position = entry+Vector3(0,0.04,5)
	game._process(0)
	await step(driver)
	good = expect(game.state.ammo[1] == 100 and not spec.id in game.state.removed,"No stale tick or pose grants after leaving reach") and good
	game.player.position = entry+Vector3.UP*0.04
	game.pause_game()
	await step(driver)
	good = expect(not spec.id in game.state.removed,"Actual pause rejects an always-running physics caller") and good
	game.resume_game()
	game.placement_pending = true
	await step(driver)
	game.placement_pending = false
	good = expect(not spec.id in game.state.removed,"Placement pending rejects before any passive mutation") and good
	var impostor = game.Player.new()
	game.level.add_child(impostor)
	impostor.configure(game)
	impostor.set_physics_process(false)
	driver.observer = impostor
	await step(driver)
	good = expect(not spec.id in game.state.removed,"Same-map noncurrent Player identity cannot publish") and good
	impostor.free()
	driver.observer = game.player
	game.player.set_physics_process(true)
	await physics_frame
	await process_frame
	game.player.set_physics_process(false)
	good = expect(game.observer_ticks > 0 and game.state.ammo[1] == 135 and game.state.removed.count(spec.id) == 1 and not game.level.markers.has(spec.id) and game.outside_visibility == 0,"Real Player callback grants once despite Main override without super") and good
	var old = weakref(game.player)
	await game.restart_level()
	game.player.set_physics_process(false)
	game.player.set_process_unhandled_input(false)
	game.hud.survey.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)
	driver.observer = game.player
	good = expect(old.get_ref() == null and game.playing and not game.placement_pending,"Actual restart replaces/drains old Player and resumes current identity") and good
	game.level.layout.data.pickups.append(spec)
	game.level.markers[spec.id] = game.level._place_marker(spec)
	var checkpoint: Dictionary = {"id":"fixture_physics_checkpoint","kind":"checkpoint","cell":cell,"requires":[],"text":"MUST NOT CAPTURE RETIRED MAP"}
	game.level.layout.data.interactions.append(checkpoint)
	game.level.markers[checkpoint.id] = game.level._place_marker(checkpoint)
	game.player.position = entry+Vector3.UP*0.04
	game.cancel_on_collect = true
	await settle()
	var captures: int = game.captures
	var saves: int = game.saves
	if not expect(game.has_method("_verify_passive_tick"),"Export verifier needs its real physics-callback bridge"):
		driver.free()
		return false
	retired.append(weakref(game.level))
	for child in game.level.get_children(): retired.append(weakref(child))
	await game._verify_passive_tick()
	good = expect(not game.playing and game.player == null and game.state.removed.count(spec.id) == 1 and not checkpoint.id in game.state.removed and game.captures == captures and game.saves == saves,"Collection reentry to title stops before retired checkpoint capture/save") and good
	retired.append(weakref(driver))
	driver.free()
	return good

func step(driver) -> void:
	var previous: int = driver.steps
	driver.pending = true
	while driver.steps == previous: await physics_frame
	await process_frame
