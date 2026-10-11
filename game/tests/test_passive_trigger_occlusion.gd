extends SceneTree

const Preferences = preload("res://scripts/preferences.gd")
var game
var retired: Array = []
var prefix = "user://passive_trigger_occlusion_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
var previous_mute: bool
var previous_mouse: int
var physics_probe_driver

class ObservedMain:
	extends "res://scripts/main.gd"
	var captures: int = 0
	var saves: int = 0
	func _capture_actor_state() -> bool:
		captures += 1
		return super._capture_actor_state()
	func _save() -> Error:
		saves += 1
		return super._save()

class PhysicsProbe:
	extends Node
	var pending: Callable
	var result
	var steps: int = 0
	func _physics_process(_delta: float) -> void:
		if not pending.is_valid(): return
		var action: Callable = pending
		pending = Callable()
		result = action.call()
		steps += 1

func in_physics(action: Callable):
	if not is_instance_valid(physics_probe_driver):
		physics_probe_driver = PhysicsProbe.new()
		physics_probe_driver.process_mode = Node.PROCESS_MODE_ALWAYS
		root.add_child(physics_probe_driver)
	var previous: int = physics_probe_driver.steps
	physics_probe_driver.pending = action
	while physics_probe_driver.steps == previous: await physics_frame
	var result = physics_probe_driver.result
	await process_frame
	return result

func scan() -> void:
	await in_physics(func(): game.update_passive_triggers(game.player))
	game._process(0)

func _initialize() -> void:
	previous_mute = AudioServer.is_bus_mute(0)
	previous_mouse = Input.mouse_mode
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func run() -> void:
	release_actions()
	for suffix in ["_campaign.json","_campaign.json.tmp","_preferences.json","_preferences.json.tmp"]:
		if not expect(not FileAccess.file_exists(prefix+suffix),"SETUP: isolated profile must be new; never clean an existing file"):
			AudioServer.set_bus_mute(0,previous_mute)
			Input.mouse_mode = previous_mouse
			quit(1)
			return
	game = ObservedMain.new()
	game.settings_path = prefix+"_preferences.json"
	game.progress_path = prefix+"_campaign.json"
	root.add_child(game)
	game.set_process(false) # Native ready registers callbacks; hold after entry, not before it.
	if not expect(not game.is_processing(),"SETUP: automatic Main render callback is held before all paired checks"):
		await finish(1)
		return
	game.set_process_unhandled_input(false)
	# Each independent case reaches its blocked assertion even if the other is RED.
	var pickup_ok: bool = await pair("ammo",1.1)
	retire_level()
	await settle()
	var checkpoint_ok: bool = await pair("checkpoint",2.4)
	retire_level()
	await settle()
	var west_ok: bool = await earned_west()
	if pickup_ok and checkpoint_ok and west_ok:
		print("PASS controlled native passive blocked/clear pairs: held actors/poses, actual physics callback invokes production passive facade, then Main._process(0); real actor capture and isolated save. Not authored-map incidence, earned traversal, OS input, GPU, packed app or performance acceptance.")
	await finish(0 if pickup_ok and checkpoint_ok and west_ok else 1)

func pair(kind: String, distance: float) -> bool:
	game.state.new_campaign(1)
	game.loaded_positions = false
	await game.start_level()
	if not expect(game.playing and not game.placement_pending and is_instance_valid(game.player),"SETUP: actual Main/Level/Player startup completes"): return false
	game.player.set_physics_process(false)
	game.player.set_process_unhandled_input(false)
	game.hud.survey.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)
	await settle()
	var layout = game.level.layout
	var originals: Dictionary = layout.data.duplicate(true)
	var entry: Vector3 = layout.world_position(layout.data.spawn)
	game.player.position = entry+Vector3.UP*0.04
	game.player.velocity = Vector3.ZERO
	game.player.rotation = Vector3.ZERO
	game.player.camera.rotation = Vector3.ZERO
	var cell: Array = [layout.data.spawn[0]+distance/float(layout.data.cell_size),layout.data.spawn[1]]
	var target: Vector3 = layout.world_position(cell)
	var pose: Vector3 = game.player.position
	if not expect(pose.distance_to(target) < (1.4 if kind == "ammo" else 3.2),"SETUP: identical blocked/clear pose is strictly within production proximity"): return false
	await settle()
	if not await in_physics(func(): return floor_and_capsule(entry)) or not await in_physics(func(): return floor_and_capsule(target)): return false
	var id: String = "fixture_passive_"+kind
	var spec: Dictionary = {"id":id,"kind":kind,"cell":cell,"text":"FIXTURE RECOVERY IMAGE","requires":[]}
	if kind == "ammo":
		spec.merge({"weapon":1,"amount":35})
		layout.data.pickups.append(spec)
	else:
		layout.data.interactions.append(spec)
	# Only this live scene receives appended synthetic metadata; disk maps stay untouched.
	game.level.markers[id] = game.level._place_marker(spec)
	if not expect(game._save() == OK,"SETUP: actual actor capture and isolated baseline save succeed"): return false
	game.captures = 0
	game.saves = 0
	game.notify("FIXTURE DISCOVERY MESSAGE",8)
	var before: Dictionary = game.state.to_dict().duplicate(true)
	var disk: String = FileAccess.get_file_as_string(game.progress_path)
	var marker = weakref(game.level.markers[id])
	if not await in_physics(func(): return rays(target,null)): return false
	# Thin world wall spans below the capsule foot through above the actual eye.
	var wall = game.level._box(Vector3(0.08,2.5,2.0),(entry+target)/2+Vector3.UP*1.15,null,true)
	var wall_ref = weakref(wall)
	await settle()
	if not expect(wall is StaticBody3D and wall.collision_layer == 1,"SETUP: native world wall uses production Level._box"): return false
	if not await in_physics(func(): return floor_and_capsule(entry)) or not await in_physics(func(): return rays(target,wall)): return false
	await scan() # Actual native physics callback; player/actors and automatic Main updates stay held.
	if not expect(game.state.to_dict() == before and game.level.markers.has(id) and marker.get_ref() != null and not marker.get_ref().is_queued_for_deletion() and game.captures == 0 and game.saves == 0 and FileAccess.get_file_as_string(game.progress_path) == disk and not FileAccess.file_exists(game.progress_path+".tmp") and game.message == "FIXTURE DISCOVERY MESSAGE","BLOCKED "+kind+": no through-wall resource/removal/marker/story/capture/save mutation"): return false
	wall.queue_free()
	wall = null
	await settle()
	if not expect(wall_ref.get_ref() == null,"SETUP: removed wall must drain before clear pair"): return false
	if not expect(game.player.position == pose,"SETUP: clear pair must keep exactly the blocked pose"): return false
	if not await in_physics(func(): return rays(target,null)): return false
	# The entire native marker envelope stays beyond this wall, only .02 m behind its far face.
	var edge: float = INF
	for mesh in marker.get_ref().find_children("*","MeshInstance3D",true,false):
		edge = minf(edge,(mesh.global_transform*mesh.mesh.get_aabb()).position.x)
	if not expect(is_finite(edge) and target.x-edge > 0.1 and target.x-edge < 0.45,"SETUP: near-wall boundary derives from the actual compact marker mesh bounds"): return false
	wall = game.level._box(Vector3(0.08,2.5,2.0),Vector3(edge-0.06,entry.y+1.15,target.z),null,true)
	wall_ref = weakref(wall)
	await settle()
	if not await in_physics(func(): return floor_and_capsule(entry)) or not await in_physics(func(): return rays(Vector3(edge,target.y,target.z),wall)): return false
	await scan()
	if not expect(game.state.to_dict() == before and game.level.markers.has(id) and not marker.get_ref().is_queued_for_deletion() and game.captures == 0 and game.saves == 0 and FileAccess.get_file_as_string(game.progress_path) == disk and game.message == "FIXTURE DISCOVERY MESSAGE","NEAR WALL "+kind+": full tangible marker envelope behind thin wall cannot grant/capture/save"): return false
	wall.queue_free()
	wall = null
	await settle()
	if not expect(wall_ref.get_ref() == null and game.player.position == pose,"SETUP: near wall drains; clear pose is unchanged"): return false
	if not await in_physics(func(): return rays(target,null)) or not await in_physics(func(): return guards(spec)): return false
	await scan()
	if kind == "ammo":
		var wanted: Dictionary = before.duplicate(true)
		wanted.ammo[1] += 35
		wanted.removed.append(id)
		if not expect(game.state.to_dict() == wanted and not game.level.markers.has(id) and game.captures == 0 and game.saves == 0 and FileAccess.get_file_as_string(game.progress_path) == disk,"CLEAR ammo: exactly one finite grant/removal, without checkpoint or save"): return false
		await settle()
		if not expect(marker.get_ref() == null,"Collected native marker drains"): return false
	else:
		var saved = JSON.parse_string(FileAccess.get_file_as_string(game.progress_path))
		var actual: Array = game.enemies.map(func(actor): return actor.snapshot())
		if not expect(game.captures == 2 and game.saves == 1 and game.state.checkpoint_id == id and game.state.position == pose and game.state.removed.count(id) == 1 and game.state.actors == actual and game.state.checkpoint.actors == actual and game.state.checkpoint.removed.count(id) == 1,"CLEAR checkpoint: real pre-mark and save actor captures, one mark/save"): return false
		for field in ["health","armor","ammo","owned_weapons","weapon","keys","discoveries","explored","level_start"]:
			if not expect(game.state.to_dict()[field] == before[field],"CLEAR checkpoint preserves arranged resources/story: "+field): return false
		# Synthetic IDs intentionally do not constitute a replayable authored campaign save.
		if not expect(saved is Dictionary and saved == JSON.parse_string(JSON.stringify(game.state.to_dict(),"",true,true)) and not FileAccess.file_exists(game.progress_path+".tmp"),"Actual atomic save persists the entire synthetic resource/story/actor image"): return false
	var once: Dictionary = game.state.to_dict().duplicate(true)
	var once_disk: String = FileAccess.get_file_as_string(game.progress_path)
	var captures: int = game.captures
	var saves: int = game.saves
	await scan()
	if not expect(game.state.to_dict() == once and game.captures == captures and game.saves == saves and FileAccess.get_file_as_string(game.progress_path) == once_disk,"Repeated proximity never grants, captures or saves twice"): return false
	if kind == "ammo":
		if not await capacities(cell): return false
	var recovered_originals: Dictionary = layout.data.duplicate(true)
	recovered_originals.pickups = recovered_originals.pickups.filter(func(record): return not record.id.begins_with("fixture_passive_"))
	recovered_originals.interactions = recovered_originals.interactions.filter(func(record): return not record.id.begins_with("fixture_passive_"))
	return expect(recovered_originals == originals,"Fixture appends only its own metadata; original live records are unchanged")

func guards(spec: Dictionary) -> bool:
	if not expect(game._passive_trigger_visible(spec),"CLEAR: actual live helper sees bounded floor supply"): return false
	paused = true
	var pause_ok: bool = not game._passive_trigger_visible(spec)
	paused = false
	game.placement_pending = true
	var pending_ok: bool = not game._passive_trigger_visible(spec)
	game.placement_pending = false
	var health: int = game.state.health
	game.state.health = 0
	var dead_ok: bool = not game._passive_trigger_visible(spec)
	game.state.health = health
	var scene_index: int = game._scene_level_index
	game._scene_level_index = -1
	var stale_ok: bool = not game._passive_trigger_visible(spec)
	game._scene_level_index = scene_index
	var live_player = game.player
	game.player = null
	var absent_ok: bool = not game._passive_trigger_visible(spec)
	game.player = live_player
	return expect(pause_ok and pending_ok and dead_ok and stale_ok and absent_ok,"Actual helper rejects paused/pending/dead/stale/absent participants; no world mock")

func earned_west() -> bool:
	game.state.new_campaign(1)
	game.loaded_positions = false
	await game.start_level()
	if not expect(game.playing and not game.placement_pending,"SETUP: authored Intake startup completes for exposed supply"): return false
	game.player.set_physics_process(false)
	game.player.set_process_unhandled_input(false)
	game.hud.survey.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)
	var spec: Dictionary = game.level.layout.data.pickups.filter(func(record): return record.id == "entry_ammo")[0]
	var target: Vector3 = game.level.layout.world_position(spec.cell)
	var floor_pose = Vector3(46.802,target.y,108.118)
	game.player.position = floor_pose+Vector3.UP*0.04
	game.player.velocity = Vector3.ZERO
	await settle()
	if not await in_physics(func(): return floor_and_capsule(floor_pose)): return false
	if not expect(spec.cell == [12.0,27.0] and target.x == 48 and target.z == 108 and game.player.position.distance_to(target) < 1.4,"SETUP: actual entry supply and retained west-route pose are within unchanged proximity"): return false
	if not await in_physics(func(): return embedded_center_rays(target)): return false
	var ammo: int = game.state.ammo[1]
	await scan()
	if not expect(game.state.ammo[1] == ammo+35 and game.state.removed.count(spec.id) == 1 and not game.level.markers.has(spec.id),"Exposed authored entry supply stays recoverable beside low scenery; staged retained route pose, not new traversal evidence"): return false
	await scan()
	return expect(game.state.ammo[1] == ammo+35 and game.state.removed.count(spec.id) == 1,"Exposed authored supply stays once-only")

func embedded_center_rays(target: Vector3) -> bool:
	var collider: CollisionShape3D = game.player.get_child(0)
	var capsule: CapsuleShape3D = collider.shape
	var usable: float = capsule.height/2-capsule.radius
	var space = game.level.get_world_3d().direct_space_state
	for origin in [collider.to_global(Vector3.DOWN*usable),collider.to_global(Vector3.UP*usable)]:
		for height in [0.08,0.35]:
			if not expect(not space.intersect_ray(PhysicsRayQueryParameters3D.create(origin,target+Vector3.UP*height,1)).is_empty(),"SETUP: decorative entry center is inside the actual low scenery base"): return false
	return true

func capacities(cell: Array) -> bool:
	var id: String = "fixture_passive_capacity"
	var spec: Dictionary = {"id":id,"kind":"ammo","cell":cell,"weapon":1,"amount":35}
	game.level.layout.data.pickups.append(spec)
	game.level.markers[id] = game.level._place_marker(spec)
	for amount in [180,210]:
		game.state.ammo[1] = amount
		var before: Dictionary = game.state.to_dict().duplicate(true)
		await scan()
		if not expect(game.state.to_dict() == before and game.level.markers.has(id),"Unobstructed full/legacy over-cap supply remains available: "+str(amount)): return false
	game.state.ammo[1] = 179
	await scan()
	if not expect(game.state.ammo[1] == 180 and game.state.removed.count(id) == 1 and not game.level.markers.has(id),"Unobstructed partial supply grants only one available round"): return false
	await scan()
	return expect(game.state.ammo[1] == 180 and game.state.removed.count(id) == 1,"Partial grant remains once-only")

func floor_and_capsule(point: Vector3) -> bool:
	var space = game.level.get_world_3d().direct_space_state
	var hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*0.5,point-Vector3.UP*0.5,1))
	if not expect(not hit.is_empty() and hit.normal.y >= 0.7 and absf(hit.position.y-point.y) < 0.08,"SETUP: synthetic entry/target requires actual native finite floor"): return false
	var collider: CollisionShape3D = game.player.get_child(0)
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.transform = Transform3D(Basis.IDENTITY,point+Vector3.UP*0.04)*collider.transform
	query.collision_mask = game.player.collision_mask
	query.exclude = [game.player.get_rid()]
	return expect(space.intersect_shape(query,1).is_empty(),"SETUP: actual native player capsule must clear scenery/wall at fixture floor")

func rays(target: Vector3, wall) -> bool:
	var collider: CollisionShape3D = game.player.get_child(0)
	var capsule: CapsuleShape3D = collider.shape
	var usable: float = capsule.height/2-capsule.radius
	var origins: Array = [collider.to_global(Vector3.DOWN*usable),collider.to_global(Vector3.UP*usable),game.player.camera.global_position]
	var space = game.level.get_world_3d().direct_space_state
	# Floor-supply endpoints stay above the support, never inside scenery or an art center.
	for origin in origins:
		for height in [0.08,0.35]:
			var endpoint: Vector3 = target+Vector3.UP*height
			if not expect(origin.is_finite() and endpoint.is_finite(),"SETUP: bounded usable capsule/eye and floor endpoints must be finite"): return false
			var hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(origin,endpoint,1))
			if not expect(hit.is_empty() if wall == null else not hit.is_empty() and hit.collider == wall,"SETUP: every meaningful native ray must be clear / hit exactly the fixture wall"): return false
	return true

func settle() -> void:
	await physics_frame
	await physics_frame
	await process_frame

func release_actions() -> void:
	for action in Preferences.ACTIONS:
		if InputMap.has_action(action): Input.action_release(action)

func retire_level() -> void:
	if not is_instance_valid(game): return
	if is_instance_valid(game.level):
		retired.append(weakref(game.level))
		for child in game.level.get_children(): retired.append(weakref(child))
	game.show_title()
	paused = false

func finish(status: int) -> void:
	if is_instance_valid(physics_probe_driver):
		retired.append(weakref(physics_probe_driver))
		physics_probe_driver.free()
	release_actions()
	if is_instance_valid(game):
		retire_level()
		for node in [game,game.music,game.effects]: retired.append(weakref(node))
	paused = false
	await create_timer(0.1,true).timeout
	if is_instance_valid(game): game.free()
	await process_frame
	await process_frame
	if not expect(retired.all(func(reference): return reference.get_ref() == null),"Native fixture level/player/actors/walls/markers/Main/audio must drain"): status = 1
	for suffix in ["_campaign.json","_campaign.json.tmp","_preferences.json","_preferences.json.tmp"]:
		var path: String = prefix+suffix
		if FileAccess.file_exists(path) and not expect(DirAccess.remove_absolute(path) == OK,"Cleanup only the unique isolated fixture profile"): status = 1
	AudioServer.set_bus_mute(0,previous_mute)
	Input.mouse_mode = previous_mouse
	if not expect(AudioServer.is_bus_mute(0) == previous_mute,"Restore prior master mute"): status = 1
	quit(status)

func expect(ok: bool, text: String) -> bool:
	if not ok: push_error(text)
	return ok
