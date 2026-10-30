extends SceneTree

const WallClock = preload("res://tests/wall_clock_wait.gd")
const PassivePhysicsStep = preload("res://tests/passive_physics_step.gd")

class FixturePhysicsAction extends Node:
	var action: Callable
	var done: bool = false
	func _physics_process(_delta: float) -> void:
		set_physics_process(false)
		action.call()
		done = true

func in_physics(action: Callable) -> void:
	var driver = FixturePhysicsAction.new()
	driver.action = action
	root.add_child(driver)
	while not driver.done: await physics_frame
	driver.free()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var blocker = "user://save_contract_parent_"+str(Time.get_ticks_usec())
	var file = FileAccess.open(blocker,FileAccess.WRITE)
	file.store_string("Owned save failure fixture")
	file.close()
	var game = load("res://scripts/main.gd").new()
	game.progress_path = blocker+"/campaign.json"
	root.add_child(game)
	game.start_campaign(1)
	game.set_process(false)
	game.player.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)
	# Arrange the checkpoint's real prerequisites through production death and
	# walk-over collection, rather than forging keys on living seal bearers.
	await physics_frame
	await physics_frame
	for key in game.level.layout.data.interactions:
		if key.kind != "key": continue
		var bearer
		for actor in game.enemies:
			if actor.id == key.seal_bearer: bearer = actor
		if not is_instance_valid(bearer): push_error("Owned seal bearer fixture required");quit(1);return
		await in_physics(func(): bearer.take_damage(99999,game.player))
		if bearer.hp != 0 or game.earned_recovery_only: push_error("Production bearer death must commit");quit(1);return
		var point: Vector3 = game.SealGuardians.interaction_position(game,key)
		game.player.position = Vector3(point.x,game.level.layout.capsule_floor_support(Vector2(point.x,point.z),.32)+.04,point.z)
		game.reset_supply_sweep()
		if not await PassivePhysicsStep.scan(game): quit(1);return
		if not await PassivePhysicsStep.scan(game): quit(1);return
		if not key.key in game.state.keys or not key.id in game.state.removed:
			push_error("Production walk-over seal pickup required for save fixture");quit(1);return
	game.state.ammo[1] = 17
	for spec in game.level.layout.data.interactions:
		if spec.kind != "checkpoint": continue
		if not game._has_keys(spec.get("requires",[])): push_error("Checkpoint prerequisites must be genuinely owned in arranged fixture");quit(1);return
		game.player.position = game.level.layout.world_position(spec.cell)+Vector3.UP*.04
		game.reset_supply_sweep()
		if not await PassivePhysicsStep.scan(game):
			quit(1)
			return
		game._process(0)
		print("SAVE_FAILURE_CHECKPOINT_DIAGNOSTIC ",JSON.stringify({"expected":spec.id,"actual":game.state.checkpoint_id,"message":game.message,"playing":game.playing,"placement_pending":game.placement_pending,"player_position":str(game.player.position),"floor_revision":game.state.floor_revision,"actors":game.enemies.size()}))
		if game.state.checkpoint_id != spec.id or not game.message.begins_with("RECOVERY MEMORY ONLY: SAVE FAILED"):
			push_error("Actual automatic checkpoint disk failure must never display stored-success feedback")
			quit(1)
			return
		break
	# Encounter presentation still activates, but cannot hide an active disk failure.
	var authored_encounters: Array = game.level.layout.data.encounters.duplicate(true)
	var authored_removed: Array = game.state.removed.duplicate()
	var recovery_message: String = game.message
	var cue: Dictionary = game.level.layout.data.encounters[0].duplicate(true)
	cue.id = "fixture_after_checkpoint_failure"
	game.level.layout.data.encounters.append(cue)
	game.activate_encounter(cue.id)
	if game.message != recovery_message or not "encounter:"+cue.id in game.state.removed:
		push_error("Encounter activation must retain active checkpoint disk-failure feedback")
		quit(1)
		return
	game.message_time = 0
	cue = cue.duplicate(true)
	cue.id = "fixture_after_failure_expiry"
	game.level.layout.data.encounters.append(cue.duplicate(true))
	game.activate_encounter(cue.id)
	if game.message != cue.cue.text or game.message_time != 5:
		push_error("Expired recovery failure must not suppress subsequent encounter text")
		quit(1)
		return
	# Retire only this transient fixture data before canonical save validation.
	game.level.layout.data.encounters = authored_encounters
	game.state.removed = authored_removed
	game.pause_game()
	var current = game.level
	game.save_and_title()
	if game.level != current or game.state.ammo[1] != 17 or not game.message.begins_with("SAVE FAILED"):
		push_error("Save failure must preserve paused scene/resources and report failure")
		quit(1)
		return
	if game.quit_game() or game.level != current or not paused:
		push_error("Failed close save must preserve paused scene")
		quit(1)
		return
	DirAccess.remove_absolute(blocker)
	game.progress_path = "user://dead_continue_"+str(Time.get_ticks_usec())+".json"
	var dead_startups = [0]
	var observe_start = func():
		if game.state.health <= 0 and (game.playing or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED): dead_startups[0] += 1
	game.music.playback_started.connect(observe_start)
	for usable_recovery in [true,false]:
		game.state.health = 0
		game.state.checkpoint.health = 100 if usable_recovery else 0
		game.state.level_start.health = 100 if usable_recovery else 0
		if game._save() != OK:
			push_error("Owned dead-Continue fixture must save successfully")
			quit(1)
			return
		game.show_title()
		await game.continue_campaign()
		if dead_startups[0] != 0:
			push_error("Dead Continue must never activate or capture gameplay during synchronous music initialization")
			quit(1)
			return
		if game.playing or not paused or Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
			push_error("Zero-health Continue must display recovery rather than trap controls in dead gameplay")
			quit(1)
			return
		var actions: Array = []
		for node in game.menu.get_children():
			if node is Button: actions.append(node.text)
		if ("Restore checkpoint" in actions) != usable_recovery or ("Restart level" in actions) != usable_recovery or not "Return to title" in actions:
			push_error("Recovery offers only healthy snapshots, with an exit when none exist")
			quit(1)
			return
		if usable_recovery:
			for node in game.menu.get_children():
				if node is Button and node.text == "Restore checkpoint":
					node.pressed.emit()
					break
			await physics_frame
			await physics_frame
			await physics_frame
			if not game.playing or game.state.health != 100:
				push_error("Real recovery menu callback restores a healthy playable checkpoint")
				quit(1)
				return
			game._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
			if game.playing or not paused or not game.music.player.stream_paused:
				push_error("Native focus-loss notification pauses live combat and recorded music")
				quit(1)
				return
			game._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
			if game.playing:
				push_error("Focus return must never resume combat automatically")
				quit(1)
				return
			game.state.health = 0
			game.show_recovery()
			for node in game.menu.get_children():
				if node is Button and node.text == "Restart level":
					node.pressed.emit()
					break
			await physics_frame
			await physics_frame
			await physics_frame
			if not game.playing or game.state.health != 100 or game.state.checkpoint_id != "entry":
				push_error("Real recovery Restart-level button restores healthy entry resources")
				quit(1)
				return
		else:
			game.resume_game()
			if game.playing:
				push_error("No recovery path may resume dead gameplay")
				quit(1)
				return
	DirAccess.remove_absolute(game.progress_path)
	game.music.playback_started.disconnect(observe_start)
	game.show_title()
	game.music.stop()
	game.queue_free()
	paused = false
	await WallClock.seconds(self,0.15)
	print("PASS actual checkpoint failure feedback, failed save/close, dead Continue, healthy recovery and focus-loss pause")
	quit()
