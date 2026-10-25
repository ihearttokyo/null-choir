extends "res://tests/test_profile_workload.gd"

const SavedCampaign = preload("res://scripts/campaign.gd")
var owns_profile: bool = false

# Passive diagnostics only: invoke each production restoration method once and
# report its unchanged result before Main may retire the rejected scene.
class RestoreObservedMain:
	extends "res://tests/test_active_boss_fights.gd".ObservedMain
	func _valid_restored_actors() -> bool:
		var valid: bool = super._valid_restored_actors()
		if valid: return true
		var failures: Array = []
		var space = level.get_world_3d().direct_space_state
		for actor in enemies:
			if not is_instance_valid(actor):
				failures.append({"invalid_actor":true})
				continue
			var collider: CollisionShape3D = actor.get_child(0)
			var allowance: float = minf(actor.safe_margin,0.001)
			var support: float = level.layout.capsule_floor_support(Vector2(actor.position.x,actor.position.z),collider.shape.radius)
			var query = PhysicsShapeQueryParameters3D.new()
			query.shape = collider.shape
			query.transform = collider.global_transform
			query.collision_mask = 1|4
			query.exclude = [actor.get_rid()]
			var contacts: Array = space.intersect_shape(query,8)
			query.transform.origin.y += allowance
			var raised_contacts: Array = space.intersect_shape(query,8)
			var cell = Vector2(actor.position.x,actor.position.z)/float(level.layout.data.cell_size)
			var floor_point: Vector3 = level.layout.world_position([cell.x,cell.y])
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(floor_point+Vector3.UP*0.5,floor_point-Vector3.UP,1))
			if not contacts.is_empty() or hit.is_empty() or hit.normal.y < 0.5 or absf(hit.position.y-floor_point.y)>0.08:
				var bodies: Array = []
				for contact in contacts:
					var body = contact.collider
					bodies.append({"path":str(body.get_path()) if body is Node else str(body),"owned_floor":body in level.floor_bodies,"shape":contact.shape})
				failures.append({"id":actor.id,"position":str(actor.position),"floor":str(floor_point),"capsule_support":support,"signed_support_gap":actor.position.y-support,"allowance":allowance,"contacts":bodies,"raised_contact_count":raised_contacts.size(),"ray_position":str(hit.get("position",Vector3.INF)),"ray_normal":str(hit.get("normal",Vector3.ZERO))})
		print("RESTORATION_ACTOR_REJECTION ",JSON.stringify({"map":level.layout.data.id,"details":failures}))
		return valid
	func _repair_loaded_position() -> bool:
		var valid: bool = super._repair_loaded_position()
		print("RESTORATION_PLAYER_RESULT ",JSON.stringify({"valid":valid,"state_position":str(state.position),"player_position":str(player.position),"message":message}))
		return valid

func run() -> void:
	prefix = "user://CONTROLLED_heart_entry_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	release_actions()
	if not expect(Engine.physics_ticks_per_second == 60 and Engine.time_scale == 1.0,"Controlled Heart Continue requires normal60Hz/time scale"):
		await finish(1)
		return
	# Prepared defaults only, independently specified; no earned campaign history.
	var entry: Dictionary = {"health":100,"armor":0,"ammo":[0,90,0,0,0,0],"owned_weapons":[0,1],"weapon":1,"keys":[],"removed":[],"floor_revision":1,"checkpoint_id":"entry","position":[0.0,0.0,0.0]}
	var document: Dictionary = entry.duplicate(true)
	document.merge({"version":2,"difficulty":1,"level_index":7,"discoveries":[],"explored":[],"checkpoint":entry.duplicate(true),"level_start":entry.duplicate(true)},true)
	var input_image: PackedByteArray = var_to_bytes(document)
	var migrated_document: Dictionary = document.duplicate(true)
	for snapshot in [migrated_document,migrated_document.checkpoint,migrated_document.level_start]: snapshot.floor_revision = 2
	var independent = SavedCampaign.new()
	if not expect(independent.from_dict(document) and independent.to_dict() == migrated_document and var_to_bytes(document) == input_image,"Prepared historical Heart1→2 changes only three floor labels, preserving all defaults/sentinels and caller input"):
		await finish(1)
		return
	# Retain original floor0 coverage as an explicitly prepared legacy control;
	# neither prepared document represents an earned Inversion exit.
	var legacy: Dictionary = document.duplicate(true)
	legacy.version = 1
	for snapshot in [legacy,legacy.checkpoint,legacy.level_start]: snapshot.erase("floor_revision")
	var legacy_image: PackedByteArray = var_to_bytes(legacy)
	var legacy_state = SavedCampaign.new()
	if not expect(legacy_state.from_dict(legacy) and legacy_state.to_dict() == migrated_document and var_to_bytes(legacy) == legacy_image,"Prepared floor0→2 retains the same finite default resources and immutable input"):
		await finish(1)
		return
	var future: Dictionary = migrated_document.duplicate(true)
	for snapshot in [future,future.checkpoint,future.level_start]: snapshot.floor_revision = 3
	var future_image: PackedByteArray = var_to_bytes(future)
	if not expect(not independent.from_dict(future) and independent.to_dict() == migrated_document and var_to_bytes(future) == future_image,"Future floor3 is rejected atomically against actual current2"):
		await finish(1)
		return
	var suffixes: Array = ["_campaign.json","_campaign.json.tmp","_preferences.json","_preferences.json.tmp"]
	if not expect(suffixes.all(func(suffix): return not FileAccess.file_exists(prefix+suffix)),"Use only a fresh process-owned isolated Heart profile"):
		await finish(1)
		return
	var progress: String = prefix+"_campaign.json"
	# Claim only this previously absent family; also own atomic-save failure leftovers.
	owns_profile = true
	if not expect(independent.save_progress(progress) == OK,"Independent Campaign atomically saves only the owned prepared Heart profile"):
		await finish(1)
		return
	var reload = SavedCampaign.new()
	if not expect(reload.load_progress(progress) and reload.to_dict() == migrated_document,"Atomic current2 save roundtrip preserves the independently migrated Heart image"):
		await finish(1)
		return
	# Now stage the unchanged PREPARED historical1 bytes at this same owned path.
	# Main must perform its own real disk migration, not consume our migrated2 save.
	var saved: PackedByteArray = JSON.stringify(document,"",true,true).to_utf8_buffer()
	var output = FileAccess.open(progress,FileAccess.WRITE)
	if not expect(output != null,"Open only the claimed prepared Heart profile to stage historical input"):
		await finish(1)
		return
	output.store_buffer(saved)
	output.flush()
	var written: bool = output.get_error() == OK
	output.close()
	var saved_sha: String = FileAccess.get_sha256(progress)
	if not expect(written and FileAccess.get_file_as_bytes(progress) == saved and reload.load_progress(progress) and reload.to_dict() == migrated_document and FileAccess.get_file_as_bytes(progress) == saved,"Independent disk load migrates historical1→2 without rewriting original prepared bytes"):
		await finish(1)
		return
	# Construct Main only after ownership and successful save, never on a collision.
	game = RestoreObservedMain.new()
	game.settings_path = prefix+"_preferences.json"
	game.progress_path = progress
	game.state.new_campaign(1)
	root.add_child(game)
	if not expect(game.state.get_instance_id() != independent.get_instance_id() and game.state.level_index == 0 and game._scene_level_index == -1 and game.level == null and game.state.to_dict() != migrated_document,"Distinct fresh Main begins at default Intake before actual disk restoration"):
		await finish(1)
		return
	var buttons: Array = game.menu.get_children().filter(func(node): return node is Button and node.text == "Continue")
	if not expect(buttons.size() == 1 and buttons[0].pressed.is_connected(Callable(game,"continue_campaign")),"Actual title Continue is connected to production load/start") or not press_menu("Continue"):
		await finish(1)
		return
	for tick in range(120):
		if game.playing and not game.placement_pending: break
		await physics_frame
	if not game.playing:
		print("RESTORATION_TERMINAL ",JSON.stringify({"playing":game.playing,"pending":game.placement_pending,"paused":paused,"level_alive":is_instance_valid(game.level),"message":game.message,"floor_revision":game.state.floor_revision}))
	if not expect(game.playing and not game.placement_pending and not paused and is_instance_valid(game.level) and is_instance_valid(game.player),"Actual Heart Continue resolves live placement within120 native ticks"):
		await finish(1)
		return
	if not expect(game.state.level_index == 7 and game.state.floor_revision == 2 and game.state.health == 100 and game.state.armor == 0 and game.state.ammo == [0,90,0,0,0,0],"Continue must restore distinct prepared Heart state from disk, never retain Main Intake defaults"):
		await finish(1)
		return
	route_level = game.level
	route_player = game.player
	for tick in range(6): await physics_frame
	var data: Dictionary = route_level.layout.data
	var ok: bool = expect(data.id == "heart" and route_level.layout.floor_revision() == 2 and data.spawn == [4.5,5.5] and data.spawn_yaw == 270 and data.enemies.size() == 33 and game._scene_level_index == 7 and game.state.difficulty == 1,"Actual Continue builds original eighth Heart metadata and33actor roster")
	ok = expect(game.is_processing() and game.is_physics_processing() and route_player.is_physics_processing() and route_player._current_map() and game.rate_ok and game.ticks >= 4,"Main/Player advance automatically at native60Hz") and ok
	var support: Dictionary = route_level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(route_player.position+Vector3.UP*0.5,route_player.position-Vector3.UP*0.5,1))
	var capsule: CollisionShape3D = route_player.get_child(0)
	ok = expect(clear_point(data.spawn) != null and route_player.is_on_floor() and route_player.position.distance_to(route_level.layout.world_position(data.spawn)) < 0.1 and not support.is_empty() and support.normal.y >= 0.7 and absf(route_player.position.y-support.position.y) <= 0.15,"Authored Heart spawn retains actual native floor/capsule support") and ok
	ok = expect(route_player.collision_layer == 2 and route_player.collision_mask == 5 and not capsule.disabled and capsule.shape is CapsuleShape3D and capsule.shape.radius == Vector3(0.32,0,0).x and capsule.shape.height == Vector3(1.65,0,0).x and capsule.position == Vector3(0,0.85,0) and absf(wrapf(route_player.rotation.y-deg_to_rad(270),-PI,PI)) < 0.00001 and route_player.camera.rotation.x == 0.0,"Original Player geometry and authored entry facing remain unchanged") and ok
	var expected_ids: Array = data.enemies.map(func(spec): return spec.id)
	var actual_ids: Array = game.enemies.map(func(actor): return actor.id)
	expected_ids.sort()
	actual_ids.sort()
	ok = expect(actual_ids == expected_ids and game.enemies.all(func(actor): return actor.get_script() == game.Enemy and actor.get_parent() == route_level and actor._current_map() and actor.is_physics_processing() and actor.hp == actor.max_hp and actor.age >= 4.0/60.0),"All33original living actors advance automatically without staging or removals") and ok
	ok = expect(game.state.health == 100 and game.state.armor == 0 and game.state.ammo == [0,90,0,0,0,0] and game.state.owned_weapons == [0,1] and game.state.weapon == 1 and game.state.keys.is_empty() and game.state.removed.is_empty() and game.state.discoveries.is_empty(),"Finite prepared normal defaults survive without grants/refunds/pickups") and ok
	ok = expect(game.hud.survey.is_physics_processing() and game.state.explored.has([4,5]) and game.state.explored.size() <= 25 and game.state.explored.all(func(cell): return absi(int(cell[0])-4) <= 2 and absi(int(cell[1])-5) <= 2 and route_level.layout.is_walkable(Vector2i(cell[0],cell[1]))),"Automatic Survey reveals Heart spawn and only its bounded walkable neighborhood") and ok
	ok = expect(game.state.checkpoint_id == "entry" and game.state.checkpoint == migrated_document.checkpoint and game.state.level_start == migrated_document.level_start,"Both recovery envelopes retain independently expected migrated2 resources and sentinels") and ok
	ok = expect(FileAccess.get_file_as_bytes(progress) == saved and FileAccess.get_sha256(progress) == saved_sha,"Continue and Survey preserve the prepared disk bytes and hash") and ok
	print("CONTROLLED_HEART_ENTRY ",JSON.stringify({"map":data.id,"actors":game.enemies.size(),"health":game.state.health,"armor":game.state.armor,"ammo":game.state.ammo,"saved_sha256":saved_sha,"input_floor_revision":1,"loaded_floor_revision":2,"scope":"prepared default Heart document through fresh titleContinue/placement only; not earned Inversion/C/Heart combat, campaign, FPS, Mac, physical input, listening or release acceptance"}))
	if ok: print("PASS CONTROLLED Heart saved-entry through actual title Continue; finite defaults,33automatic original actors, native support, Survey and unchanged disk/recovery")
	await finish(0 if ok else 1)

func finish(status: int) -> void:
	if not owns_profile:
		release_actions()
		quit(status)
		return
	await super.finish(status)
