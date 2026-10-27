extends SceneTree
# Arranged production-boundary fixture, NOT earned combat/balance or visual acceptance.
const Main = preload("res://scripts/main.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Seals = preload("res://scripts/seal_guardians.gd")
var game
var failures: Array = []
var chapters: Array = range(8)

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func run() -> void:
	# Optional single-chapter shard retains the same assertions and external cap.
	# Default execution still covers all eight; never silently skip a bad selector.
	var selected: bool = false
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--seal-chapter="): continue
		var value: String = argument.trim_prefix("--seal-chapter=")
		if not check(not selected and value in ["0","1","2","3","4","5","6","7"],"invalid/duplicate seal chapter selector"):
			await finish()
			return
		selected = true
		chapters = [int(value)]
	game = Main.new()
	var prefix = "user://seal_guardian_fixture_"+str(OS.get_process_id())
	game.settings_path = prefix+"_never_saved_preferences.json"
	game.progress_path = prefix+"_never_saved_campaign.json"
	root.add_child(game)
	game.set_process(false)
	game.set_process_unhandled_input(false)
	for index in chapters:
		print("SEAL_FIXTURE_CHAPTER_BEGIN ",index)
		game.state.new_campaign(1)
		game.state.level_index = index
		game.state._label_floor()
		# new_campaign made Intake's envelopes. Rebuild BOTH entry snapshots for
		# this chapter (notably Ossuary revision3), then use the production validator.
		game.state.mark_checkpoint("entry",Vector3.ZERO)
		game.loaded_positions = false
		var entry: Dictionary = game.state.to_dict()
		var validated = Campaign.new()
		if not check(validated.from_dict(entry),"chapter "+str(index)+" full entry envelopes validate: "+validated.level_load_error):
			await finish()
			return
		await game.start_level()
		var started: bool = is_instance_valid(game.level) and not game.level.is_queued_for_deletion() and is_instance_valid(game.player) and not game.player.is_queued_for_deletion() and game.player.get_parent() == game.level and game.playing and not game.placement_pending and game._scene_level_index == index
		if not check(started,"chapter "+str(index)+" production start created current playing player: "+game.message):
			await finish()
			return
		game.player.set_physics_process(false)
		for actor in game.enemies: actor.set_physics_process(false)
		# Arranged fixture: freeze AI/input, not the production validity boundary.
		# Allow native shape registration before capture/death/marker queries.
		await physics_frame
		await physics_frame
		await process_frame
		var keys: Array = game.level.layout.data.interactions.filter(func(k): return k.has("seal_bearer"))
		if index%2 == 1: keys.reverse() # Both Blood-first and Ivory-first routes.
		for key in keys:
			var matches: Array = game.enemies.filter(func(a): return a.id == key.seal_bearer)
			check(matches.size() == 1,"one actual bearer")
			if matches.size() != 1: continue
			var actor = matches[0]
			check(actor.max_hp > actor.health_cap(actor.kind,1),"seal bearer stronger than base role")
			check(actor.champion_identity is Label3D and not actor.champion_identity.no_depth_test,"visible depth-tested named identity")
			game.collect_key(key.id)
			check(not key.key in game.state.keys and not key.id in game.state.removed,"live guardian blocks direct collection")
			check(not game.level.markers[key.id].visible,"live guardian has no free floor marker")
			var marker = game.level.markers[key.id]
			marker.show()
			check(not game._export_art_checks()["marker_"+key.id],"live free floor marker rejected")
			marker.hide()
			var before: Vector3 = actor.position
			actor.take_damage(actor.hp+1000,game.player) # Production death transaction, arranged damage.
			check(actor.hp == 0 and actor.id in game.state.removed,"real death records defeat")
			var drop: Dictionary = Seals.drop_for(game.state,actor.id)
			check(not drop.is_empty(),"corpse releases pending seal")
			if drop.is_empty(): continue
			check(absf(drop.position[0]-before.x)<.001 and absf(drop.position[2]-before.z)<.001,"drop comes from corpse, not original key cell")
			check(game.level.markers[key.id].visible and game.level.markers[key.id].position == Vector3(drop.position[0],drop.position[1],drop.position[2]),"real marker is at drop origin")
			check(game._export_art_checks()["marker_"+key.id],"dead persisted drop passes verifier")
			var drop_position: Vector3 = marker.position
			marker.position = game.level.layout.world_position(key.cell)+Vector3.UP*.06
			check(not game._export_art_checks()["marker_"+key.id],"old floor location rejected after death")
			marker.position = drop_position
			check(game._capture_actor_state(),"complete living-state capture")
			var data: Dictionary = game.state.to_dict()
			var restored = Campaign.new()
			check(restored.from_dict(data),"actual pending-drop snapshot reloads")
			check(restored.seal_drops == game.state.seal_drops,"save reload keeps exact corpse origins")
			game.collect_key(key.id)
			check(key.key in game.state.keys and key.id in game.state.removed,"corpse seal collected")
			check(Seals.drop_for(game.state,actor.id).is_empty(),"collection consumes only its drop")
			game.collect_key(key.id)
			check(game.state.keys.count(key.key) == 1 and game.state.removed.count(key.id) == 1,"no duplicate pickup")
			check(not is_instance_valid(game.level.markers.get(key.id)),"collected marker retired")
		print("SEAL_FIXTURE_CHAPTER_END ",index," failures=",failures.size())
		await process_frame
	await finish()

func finish() -> void:
	if is_instance_valid(game):
		if game.music != null: game.music.stop()
		game.queue_free()
		await process_frame
	if failures.is_empty(): print("PASS arranged seal guardian production death/drop/collection and actual snapshot reload chapters=",chapters)
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

func check(value: bool, context: String) -> bool:
	if not value: failures.append(context)
	return value
