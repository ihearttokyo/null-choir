extends "res://tests/test_profile_workload.gd"

const EARNED_SAVE_SHA = "a91b2e2de81a15d3b4f79af6d39d653b216cff4cbe3215c26101ba41a41ee707"
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
	prefix = "user://earned_profile_continue_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	release_actions()
	var source: String = OS.get_environment("NULL_CHOIR_EARNED_PROFILE")
	if not expect(not source.is_empty() and FileAccess.file_exists(source) and FileAccess.get_sha256(source) == EARNED_SAVE_SHA,"SETUP: exact retained production-earned Foundry exit save required"):
		await finish(1)
		return
	var saved: PackedByteArray = FileAccess.get_file_as_bytes(source)
	var parsed: Variant = JSON.parse_string(saved.get_string_from_utf8())
	if not expect(parsed is Dictionary,"Authenticated earned bytes contain a save object"):
		await finish(1)
		return
	var original: Dictionary = parsed
	var original_image: PackedByteArray = var_to_bytes(original)
	if not expect(saved.size() == 616 and Engine.physics_ticks_per_second == 60 and Engine.time_scale == 1.0 and original.version == 2 and original.floor_revision == 1 and original.level_index == 2 and original.health == 93 and original.armor == 89 and original.ammo.all(func(value): return (value is int or value is float) and value == floor(value)) and original.ammo.map(func(value): return int(value)) == [0,164,0,0,0,0],"Authenticated raw revision1 save retains its exact earned identity/resources"):
		await finish(1)
		return
	# Foundry completion retired the prior actors and stored the next-entry zero
	# sentinel. Preserve those authentic bytes; do not rewrite the earned profile.
	var document: Dictionary = original.duplicate(true)
	for index in range(3):
		var raw: Dictionary = [original,original.checkpoint,original.level_start][index]
		var migrated: Dictionary = [document,document.checkpoint,document.level_start][index]
		if not expect(raw.floor_revision == 1 and raw.position == [0.0,0.0,0.0] and not raw.has("actors"),"Authentic current/checkpoint/start are historical next-entry sentinels, not invented actor history"):
			await finish(1)
			return
		migrated.floor_revision = 2
		# JSON arrays contain floats; independently normalize integer codec fields
		# without changing any numeric value or the authenticated input dictionary.
		for field in ["health","armor","weapon"]: migrated[field] = int(raw[field])
		for field in ["ammo","owned_weapons"]: migrated[field] = raw[field].map(func(value): return int(value))
	for field in ["version","difficulty","level_index"]: document[field] = int(original[field])
	document.discoveries = original.discoveries.map(func(value): return int(value))
	document.explored = original.explored.map(func(cell): return cell.map(func(value): return int(value)))
	var independent = SavedCampaign.new()
	if not expect(independent.from_dict(original) and independent.to_dict() == document and var_to_bytes(original) == original_image,"Production migrates authentic1→2 in all three envelopes, changing only floor labels and leaving input/earned resources exact"):
		await finish(1)
		return
	var roundtrip = SavedCampaign.new()
	if not expect(roundtrip.from_dict(document) and roundtrip.to_dict() == document,"Current revision2 earned entry is exactly idempotent"):
		await finish(1)
		return
	var future: Dictionary = document.duplicate(true)
	for snapshot in [future,future.checkpoint,future.level_start]: snapshot.floor_revision = 3
	var future_image: PackedByteArray = var_to_bytes(future)
	if not expect(not independent.from_dict(future) and independent.to_dict() == document and var_to_bytes(future) == future_image,"Future terrain3 is atomically rejected against current2 without mutating live or supplied envelopes"):
		await finish(1)
		return
	var suffixes: Array = ["_campaign.json","_campaign.json.tmp","_preferences.json","_preferences.json.tmp"]
	if not expect(suffixes.all(func(suffix): return not FileAccess.file_exists(prefix+suffix)),"Use only a fresh process-owned isolated profile"):
		await finish(1)
		return
	var progress: String = prefix+"_campaign.json"
	var output = FileAccess.open(progress,FileAccess.WRITE)
	if not expect(output != null,"Copy exact earned bytes into isolated profile without resaving or reconstructing history"):
		await finish(1)
		return
	owns_profile = true
	output.store_buffer(saved)
	output.flush()
	var written: bool = output.get_error() == OK
	output.close()
	if not expect(written and FileAccess.get_sha256(progress) == EARNED_SAVE_SHA,"Isolated input remains byte-exact to the actual production save"):
		await finish(1)
		return
	game = RestoreObservedMain.new()
	game.settings_path = prefix+"_preferences.json"
	game.progress_path = progress
	game.state.new_campaign(1)
	root.add_child(game)
	if not expect(game.state.level_index == 0 and game.state.health == 100 and game.state.ammo == [0,90,0,0,0,0] and game.state.to_dict() != document,"Main starts in distinct default Intake state before disk load"):
		await finish(1)
		return
	var buttons: Array = game.menu.get_children().filter(func(node): return node is Button and node.text == "Continue")
	if not expect(buttons.size() == 1 and buttons[0].pressed.is_connected(Callable(game,"continue_campaign")),"Real title Continue is connected to production load/start") or not press_menu("Continue"):
		await finish(1)
		return
	for tick in range(120):
		if game.playing and not game.placement_pending: break
		await physics_frame
	if not game.playing:
		print("RESTORATION_TERMINAL ",JSON.stringify({"playing":game.playing,"pending":game.placement_pending,"paused":paused,"level_alive":is_instance_valid(game.level),"message":game.message,"floor_revision":game.state.floor_revision}))
	if not expect(game.playing and not game.placement_pending and not paused and is_instance_valid(game.level) and is_instance_valid(game.player),"Actual earned Continue resolves placement within120 native ticks"):
		await finish(1)
		return
	if not expect(game.state.level_index == 2 and game.state.floor_revision == 2 and game.state.health == 93 and game.state.armor == 89 and game.state.ammo == [0,164,0,0,0,0],"Continue must restore actual earned state from disk, never retain preloaded defaults"):
		await finish(1)
		return
	route_level = game.level
	route_player = game.player
	for tick in range(6): await physics_frame
	var data: Dictionary = route_level.layout.data
	var ok: bool = expect(data.id == "processional" and route_level.layout.floor_revision() == 2 and data.spawn == [21.5,29.5] and data.enemies.size() == 26 and game._scene_level_index == 2 and game.state.difficulty == 1,"Earned disk Continue builds the original third map and26actor roster")
	ok = expect(game.is_processing() and game.is_physics_processing() and route_player.is_physics_processing() and route_player._current_map() and game.rate_ok,"Main/Player keep automatic native processing") and ok
	ok = expect(clear_point(data.spawn) != null and route_player.is_on_floor() and route_player.position.distance_to(route_level.layout.world_position(data.spawn)) < 0.1,"Actual loaded zero-position entry resolves to authored native floor/capsule support") and ok
	var expected_ids: Array = data.enemies.map(func(spec): return spec.id)
	var actual_ids: Array = game.enemies.map(func(actor): return actor.id)
	expected_ids.sort()
	actual_ids.sort()
	ok = expect(actual_ids == expected_ids and game.enemies.all(func(actor): return actor._current_map() and actor.is_physics_processing() and actor.hp == actor.max_hp and actor.age >= 4.0/60.0),"All26original actors advance automatically without removal, grants or staging") and ok
	ok = expect(game.state.health == 93 and game.state.armor == 89 and game.state.ammo == [0,164,0,0,0,0] and game.state.owned_weapons == [0,1] and game.state.weapon == 1 and game.state.keys.is_empty() and game.state.removed.is_empty() and game.state.discoveries.is_empty(),"Exact finite earned resources/story survive Continue without pickup or refund") and ok
	ok = expect(game.hud.survey.is_physics_processing() and game.state.explored.has([21,29]) and game.state.explored.size() <= 25 and game.state.explored.all(func(cell): return absi(int(cell[0])-21) <= 2 and absi(int(cell[1])-29) <= 2 and route_level.layout.is_walkable(Vector2i(cell[0],cell[1]))),"Automatic Survey reveals the native spawn cell and only its original bounded walkable neighborhood") and ok
	ok = expect(game.state.checkpoint_id == "entry" and game.state.checkpoint == document.checkpoint and game.state.level_start == document.level_start,"Both earned recovery envelopes equal independently migrated revision2 images without resource changes") and ok
	ok = expect(FileAccess.get_file_as_bytes(game.progress_path) == saved and FileAccess.get_sha256(source) == EARNED_SAVE_SHA,"Continue preserves both the isolated disk image and immutable original evidence") and ok
	print("EARNED_PROFILE_CONTINUE ",JSON.stringify({"save_sha256":EARNED_SAVE_SHA,"input_floor_revision":1,"loaded_floor_revision":2,"map":data.id,"actors":game.enemies.size(),"health":game.state.health,"armor":game.state.armor,"ammo":game.state.ammo,"scope":"actual prior normal-time earned Foundry save through fresh titleContinue; not returned C history, continued third-level traversal, physical input, GPU, listening or release acceptance"}))
	if ok: print("PASS actual earned Foundry disk save through fresh title Continue; exact finite resources,26automatic original actors and unchanged recovery envelopes")
	await finish(0 if ok else 1)

func finish(status: int) -> void:
	if not owns_profile:
		release_actions()
		quit(status)
		return
	await super.finish(status)
