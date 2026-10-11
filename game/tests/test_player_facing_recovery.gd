extends SceneTree

var game
var prefix := "user://facing_"+str(OS.get_process_id())

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func expect(ok: bool, detail: String) -> bool:
	if not ok: push_error(detail)
	return ok

func freeze() -> void:
	game.set_process(false)
	game.player.set_physics_process(false)
	game.hud.survey.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)

func facing(yaw: float, pitch: float) -> bool:
	return absf(wrapf(game.player.rotation.y-yaw,-PI,PI)) < .00001 and absf(game.player.camera.rotation.x-pitch) < .00001

func run() -> void:
	game = preload("res://scripts/main.gd").new()
	game.progress_path = prefix+"_campaign.json"
	game.settings_path = prefix+"_preferences.json"
	root.add_child(game)
	game.start_campaign(1)
	freeze()
	game.settings.head_bob = false
	game.settings.camera_shake = false
	await physics_frame
	await physics_frame
	var entry_yaw: float = deg_to_rad(game.level.layout.data.spawn_yaw)
	if not expect(game.playing and facing(entry_yaw,0),"Fresh entry uses authored facing"):
		await finish(1)
		return
	for boundary in [-1.35,1.35]:
		game.player.camera.rotation.x = boundary
		game.player._physics_process(0)
		var restored = game.Campaign.new()
		if not expect(game.state.pitch == boundary and game._save() == OK and restored.load_progress(game.progress_path),"Actual native float32 look boundary remains a valid finite serialized pitch"):
			await finish(1)
			return
	game.player.camera.rotation.x = 0
	if not expect(game._save() == OK,"SETUP clean native save before malformed live capture"):
		await finish(1)
		return
	var capture_before: Dictionary = game.state.to_dict().duplicate(true)
	var disk_before := FileAccess.get_file_as_string(game.progress_path)
	for invalid_pitch in [INF,-INF,2.0,-2.0]:
		game.player.camera.rotation.x = invalid_pitch
		if not expect(game.player.camera.rotation.x == invalid_pitch,"SETUP native camera retains deliberately invalid raw pitch"):
			await finish(1)
			return
		if not expect(not game._capture_actor_state() and game.state.to_dict() == capture_before,"Invalid live pitch rejects capture without actor/facing mutation"):
			game.player.camera.rotation.x = 0
			await finish(1)
			return
		if not expect(game._save() == ERR_INVALID_DATA and FileAccess.get_file_as_string(game.progress_path) == disk_before,"Invalid live pitch cannot replace existing native save"):
			game.player.camera.rotation.x = 0
			await finish(1)
			return
		game.player.camera.rotation.x = 0
	# Controlled staging earns the real automatic checkpoint; not normal navigation/key collection.
	var checkpoint: Dictionary = game.level.layout.data.interactions.filter(func(spec): return spec.kind == "checkpoint")[0]
	game.state.keys = checkpoint.get("requires",[]).duplicate()
	game.player.position = game.level.layout.world_position(checkpoint.cell)+Vector3.UP*.04
	game.player.rotation.y = -.8
	game.player.camera.rotation.x = .4
	game.state.health = 81
	game.state.ammo[1] = 44
	await physics_frame
	await physics_frame
	game.player._physics_process(0) # Real native physics domain, manually controlled active step.
	if not expect(Engine.is_in_physics_frame() and is_equal_approx(game.state.yaw,-.8) and is_equal_approx(game.state.pitch,.4) and game.state.position == game.player.position,"Physics captures position and facing together"):
		await finish(1)
		return
	game._process(0)
	if not expect(game.state.checkpoint_id == checkpoint.id and is_equal_approx(game.state.checkpoint.get("yaw",INF),-.8) and is_equal_approx(game.state.checkpoint.get("pitch",INF),.4),"Actual proximity checkpoint records its native facing"):
		await finish(1)
		return
	game.player.rotation.y = .7
	game.player.camera.rotation.x = -.5
	game.state.health = 73
	game.state.armor = 21
	game.state.ammo[1] = 37
	game.player._physics_process(0)
	game.save_and_title()
	var saved: Dictionary = game.state.to_dict().duplicate(true)
	game.state = game.Campaign.new()
	await game.continue_campaign()
	freeze()
	if not expect(game.playing and facing(.7,-.5) and game.state.health == 73 and game.state.ammo[1] == 37,"Continue reads saved current facing/resources, not live memory or checkpoint"):
		await finish(1)
		return
	game.hurt_player(10000)
	if not expect(not game.playing and game.state.health == 0,"Actual mortality opens recovery"):
		await finish(1)
		return
	await game.restore_checkpoint()
	freeze()
	if not expect(game.playing and facing(-.8,.4) and game.state.health == 81 and game.state.ammo[1] == 44,"Death restoration chooses checkpoint facing and resources"):
		await finish(1)
		return
	game.player.velocity = Vector3(9,2,0)
	game.pause_game()
	if not expect(game.player.velocity == Vector3.ZERO and not game.player._fire_pressed,"Pause clears transient motion and queued trigger"):
		await finish(1)
		return
	await game.restart_level()
	freeze()
	if not expect(game.playing and facing(entry_yaw,0) and game.state.health == 100 and game.player.velocity == Vector3.ZERO and not game.player._fire_pressed,"Restart chooses entry facing with fresh transient state"):
		await finish(1)
		return
	var relocated: Dictionary = saved.duplicate(true)
	relocated.position = [99999,0,99999]
	relocated.yaw = 1.1
	relocated.pitch = -.6
	if not expect(game.state.from_dict(relocated) and game.state.save_progress(game.progress_path) == OK,"SETUP structurally valid unsafe position/facing image"):
		await finish(1)
		return
	game.show_title()
	await game.continue_campaign()
	freeze()
	if not expect(game.playing and facing(1.1,-.6) and game.state.health == 73 and game.state.ammo[1] == 37 and game.state.checkpoint == relocated.checkpoint and game.state.level_start == relocated.level_start and game.message.begins_with("RECOVERY POSITION REPAIRED"),"Position repair preserves selected current facing/resources and both saved envelopes"):
		await finish(1)
		return
	var legacy: Dictionary = saved.duplicate(true)
	for envelope in [legacy,legacy.checkpoint,legacy.level_start]:
		envelope.erase("yaw")
		envelope.erase("pitch")
	game.state.from_dict(legacy)
	game.state.save_progress(game.progress_path)
	game.show_title()
	await game.continue_campaign()
	freeze()
	if not expect(game.playing and facing(entry_yaw,0) and not game.state.checkpoint.has("yaw"),"Legacy Continue uses authored facing without rewriting saved checkpoint"):
		await finish(1)
		return
	# Cancel the actual two-frame placement wait, not a simulated flag transition.
	game._save()
	game.show_title()
	game.continue_campaign()
	if not expect(game.placement_pending,"SETUP actual asynchronous Continue is pending"):
		await finish(1)
		return
	game.show_title()
	await physics_frame
	await physics_frame
	if not expect(not game.playing and not game.placement_pending and game.level == null and game.player == null,"Cancelled reconstruction cannot reactivate stale facing/player"):
		await finish(1)
		return
	print("PASS native facing Continue/death/restart, automatic checkpoint, legacy/relocation and cancellation; controlled staging/manual clock, not physical mouse capture")
	await finish(0)

func finish(code: int) -> void:
	if is_instance_valid(game): game.show_title()
	paused = false
	await create_timer(.1,true).timeout
	game.free()
	await process_frame
	await process_frame
	quit(code)
