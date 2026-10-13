extends "res://tests/test_reliquary_earned_entry.gd"

const H_ENTRY_FIELDS = ["r_ok","r_main_origin","r_campaign_origin","r_profile_origin","r_settings_origin","r_captures","r_capture_attempts","r_bindings","r_level_id","r_player_id","r_start","r_ticks","r_explored","r_last_cell"]
const H_PHASE_FLAGS = ["foundry_enabled","entry_enabled","organ_enabled","palanquin_enabled","exit_enabled"]

func run() -> void:
	prefix = "user://reliquary_entry_handoff_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	var observer = ReliquaryMain.new()
	if not await walk_to_reliquary_entry(observer,prefix):
		await finish(1)
		return
	if not expect(game == observer and game.get_instance_id() == r_main_id and game.state.get_instance_id() == r_campaign_id and game.progress_path == r_profile and game.progress_path == prefix+"_campaign.json" and game.settings_path == prefix+"_preferences.json" and not game.prefix_bookkeeping_retired and observers_retired(),"Nonquitting helper returns its once-created live Main/Campaign/isolated profile; caller has not retired bookkeeping") or not reliquary_entry_result():
		await finish(1)
		return
	# Deep-copy all accepted witnesses before retiring; never reset a counter or flag.
	var fields: Array = R_THIRD_FIELDS+R_INHERITED_FIELDS+H_ENTRY_FIELDS+H_PHASE_FLAGS+["ticks","shot_slot"]
	var witness: Dictionary = observer_witness(fields)
	var current: Dictionary = game.state.to_dict().duplicate(true)
	var ages: Dictionary = {}
	for actor in game.enemies: ages[actor.id] = actor.age
	var play_time: float = route_player.active_play_time
	var frame: int = Engine.get_physics_frames()
	var wall: int = Time.get_ticks_usec()
	game.prefix_bookkeeping_retired = true
	for tick in range(6):
		await physics_frame
		await process_frame
		if not expect(Engine.get_physics_frames()-frame <= 30 and Time.get_ticks_usec()-wall <= 3000000,"Retirement control bounded to30 native frames/3 wall seconds") or not handoff_unchanged(fields,witness,current):
			await finish(1)
			return
	if not expect(Engine.get_physics_frames()-frame >= 6 and route_player.active_play_time > play_time and game.enemies.all(func(actor): return actor.age > ages[actor.id]),"Real automatic Player and original31 actor clocks advance while obsolete observer clocks stay frozen"):
		await finish(1)
		return
	print("RELIQUARY_HANDOFF native idle ticks only; no movement, combat, actor/HP/resource writes or physical-input claim")
	if not synthetic_dispatch(fields,witness,current):
		await finish(1)
		return
	print("PASS nonquitting earned fourth ENTRY and explicit prefix-bookkeeping retirement: real unchanged prefix/entry plus bounded automatic idle ticks; SYNTHETIC callback dispatch only, not earned fourth combat, physical capture, rendering/audio/performance, packed-app or full-eight acceptance")
	await finish(0)

func handoff_unchanged(fields: Array, witness: Dictionary, current: Dictionary) -> bool:
	if not expect(is_instance_valid(game) and game.prefix_bookkeeping_retired and game.fourth_scene() and game.get_instance_id() == r_main_id and game.state.get_instance_id() == r_campaign_id and game.progress_path == r_profile and game.level == route_level and game.player == route_player and game.playing and not paused and not game.placement_pending and not game.loaded_positions and game.is_processing() and game.is_physics_processing() and route_player._current_map() and route_player.is_physics_processing(),"Retired bookkeeping retains live same Main/Campaign/profile/fourth automatic scene"): return false
	if not expect(observer_witness(fields) == witness and observers_retired() and retired.all(func(reference): return reference.get_ref() == null) and x_marker_refs.values().all(func(reference): return reference.get_ref() == null),"Independent deep-frozen prefix/entry flags, counters, clocks, bindings, capture history, start and Survey witnesses remain exact"): return false
	if not expect(game.scene_roster_matches() and game.enemies.size() == 31 and route_player.position.is_finite() and route_player.position.x == 78.0 and route_player.position.z == 154.0 and absf(route_player.position.y) <= 0.05 and route_player.rotation.y == 0.0 and route_player.camera.rotation.x == 0.0,"Original31 roster and unchanged spawn pose; only bounded natural vertical settling allowed"): return false
	for index in range(R_ACTORS.size()):
		var actor = game.enemies[index]
		var spec: Array = R_ACTORS[index]
		var record: Dictionary = witness.r_start.actors[index]
		if not expect(is_instance_valid(actor) and actor.get_instance_id() == witness.r_bindings[spec[0]] and actor.id == spec[0] and actor.kind == spec[1] and actor.get_script() == game.Enemy and actor._current_map() and actor.is_physics_processing() and actor.hp == spec[2] and actor.max_hp == spec[2] and not actor.active and not actor.alerted and actor.position == Vector3(record.position[0],record.position[1],record.position[2]) and actor.rotation.y == Vector3(0,deg_to_rad(spec[6]),0).y and actor.collision_layer == 4 and actor.collision_mask == 7 and not (actor.get_child(0) as CollisionShape3D).disabled,"Unmodified live original fourth actor: "+spec[0]): return false
	var expected: Dictionary = current.duplicate(true)
	expected.position = [route_player.position.x,route_player.position.y,route_player.position.z]
	return expect(game.state.to_dict() == expected and FileAccess.get_sha256(r_profile) == r_saved_sha,"Production current/checkpoint/start resources and isolated on-disk boundary remain exact; no forced save or rewrite")

func synthetic_dispatch(fields: Array, witness: Dictionary, current: Dictionary) -> bool:
	print("SYNTHETIC Main callback probes: no Player.fire, ammo spend, enemy attack/death, earned combat or physical mouse-capture evidence")
	game.shot(1)
	var visuals = route_level.get_node_or_null("AmmoVisuals")
	if not expect(visuals != null and visuals.get_script() == game.AmmoVisuals and visuals.slots.any(func(slot): return slot.row == 1 and slot.sprite.visible),"SYNTHETIC shot still dispatches production casing effect while legacy shot bookkeeping stays frozen") or not handoff_unchanged(fields,witness,current): return false
	game.hit_feedback()
	if not expect(game.hit_flash == 0.12,"SYNTHETIC hit_feedback still dispatches production feedback") or not handoff_unchanged(fields,witness,current): return false
	var point: Vector3 = route_player.camera.global_position
	game.impact(point)
	if not expect(visuals.slots.any(func(slot): return slot.row == 3 and slot.sprite.visible and slot.sprite.global_position == point),"SYNTHETIC impact still dispatches production impact effect") or not handoff_unchanged(fields,witness,current): return false
	# Hold the prior Array reference, not a copy, to prove production replaced it.
	var prior_actors: Array = game.state.actors
	if not expect(game._capture_actor_state() and not is_same(game.state.actors,prior_actors) and game.state.actors == witness.r_start.actors and game.state.yaw == 0.0 and game.state.pitch == 0.0,"SYNTHETIC capture dispatches fresh production actor snapshot without mutating entry witnesses") or not handoff_unchanged(fields,witness,current): return false
	game._capture_game_mouse()
	# The unchanged production setter is invoked; headless mode readback is not physical proof.
	print("SYNTHETIC default mouse-capture setter invoked after retirement; no OS capture assertion")
	return handoff_unchanged(fields,witness,current)
