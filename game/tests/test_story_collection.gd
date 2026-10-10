extends SceneTree

const Campaign = preload("res://scripts/campaign.gd")
const MAPS = ["intake","foundry","processional","reliquary","nursery","ossuary","inversion","heart"]
const REVELATION = "YOUR VOICE ISSUED THE FIRST ORDER\nTHE RESTRAINT WAS BUILT AROUND YOU"
var game
var earned: Array = []
var prefix = "user://story_collection_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func run() -> void:
	game = load("res://scripts/main.gd").new()
	game.settings_path = prefix+"_preferences.json"
	game.progress_path = prefix+"_campaign.json"
	root.add_child(game)
	game.set_process(false)
	game.state.new_campaign(1)
	if not expect(game.state.discoveries.is_empty(),"SETUP: new campaign has no earned discoveries"):
		await finish(1)
		return
	for index in range(8):
		if not await collect_story(index):
			await finish(1)
			return
		game.show_title()
		await settle()
		# Completion is arranged; no route, seals or boss victory is claimed.
		game.state.complete_level()
	game.show_ending()
	if not expect(game.state.discoveries == earned and game.menu.get_child(0).text == REVELATION,"Eight actually collected clues select the alternate revelation"):
		await finish(1)
		return
	if not expect(game._save() == OK,"Completed earned-story campaign saves through the actual boundary"):
		await finish(1)
		return
	game.show_title()
	game.state = Campaign.new()
	await game.continue_campaign()
	if not expect(not game.playing and game.level == null and game.state.level_index == 8 and game.state.discoveries == earned and game.menu.get_child(0).text == REVELATION,"Saved Continue retains eight earned clues and their actual ending"):
		await finish(1)
		return
	print("PASS controlled native eight-story collection from empty campaign, actual interaction guards, one-shot text/markers, per-map save roundtrip and earned-clue ending/Continue; navigation, combat and completion are not played")
	await finish(0)

func collect_story(index: int) -> bool:
	await game.start_level()
	if not expect(game.playing and not game.placement_pending and game.state.level_index == index and game.level.layout.data.id == MAPS[index],"SETUP: actual registered map starts: "+MAPS[index]): return false
	game.player.set_physics_process(false)
	game.hud.survey.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)
	await settle()
	var stories: Array = game.level.layout.data.interactions.filter(func(spec): return spec.kind == "story")
	if not expect(stories.size() == 1,"Exactly one authored optional story per map: "+MAPS[index]): return false
	var story: Dictionary = stories[0]
	if not expect(story.id == MAPS[index]+"_story" and story.get("requires",[]).is_empty() and story.get("requires_defeated",[]).is_empty() and game.state.keys.is_empty(),"Actual story is optional without seals or boss prerequisites: "+story.id): return false
	if not expect(story.get("text") is String and not story.text.strip_edges().is_empty() and game.level.markers.has(story.id) and game.state.discoveries == earned and not index in earned,"Uncollected authored story retains its marker, text and unearned index: "+story.id): return false
	if not await interact_at(story): return false
	earned.append(index) # Expected observations only; never assigned to campaign discoveries.
	if not expect(game.state.discoveries == earned and game.state.discoveries.count(index) == 1 and game.state.removed.count(story.id) == 1 and not game.level.markers.has(story.id) and game.message == story.text,"Actual Main.interact earns exactly this index, removes its marker and notifies its authored text: "+story.id): return false
	var once: Dictionary = game.state.to_dict().duplicate(true)
	game.interact()
	if not expect(game.state.to_dict() == once and not game.level.markers.has(story.id) and game.message == story.text,"Repeated interaction cannot duplicate or change the collected story: "+story.id): return false
	if not expect(game._save() == OK,"Actual per-map campaign save succeeds: "+story.id): return false
	var restored = Campaign.new()
	if not expect(restored.load_progress(game.progress_path),"Actual saved campaign decodes: "+story.id): return false
	if not expect(restored.to_dict() == game.state.to_dict() and restored.discoveries == earned and restored.removed.count(story.id) == 1,"Disk roundtrip preserves the full actual campaign and earned story: "+story.id): return false
	print("EARNED ",index," ",story.id," count=",earned.size())
	return true

func settle() -> void:
	await physics_frame
	await physics_frame
	await process_frame

func floor_position(cell: Array):
	var layout = game.level.layout
	if not layout.is_walkable(Vector2i(floori(cell[0]),floori(cell[1]))): return null
	var floor_point: Vector3 = layout.world_position(cell)
	var space = game.level.get_world_3d().direct_space_state
	var ray = PhysicsRayQueryParameters3D.create(floor_point+Vector3.UP*2,floor_point-Vector3.UP*0.5,1)
	var hit = space.intersect_ray(ray)
	if hit.is_empty() or absf(hit.position.y-floor_point.y) > 0.08 or hit.normal.y < 0.7: return null
	var position: Vector3 = floor_point+Vector3.UP*0.04
	var collider: CollisionShape3D = game.player.get_children().filter(func(node): return node is CollisionShape3D)[0]
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.transform = Transform3D(Basis.IDENTITY,position+collider.position)
	query.collision_mask = game.player.collision_mask
	query.exclude = [game.player.get_rid()]
	if not space.intersect_shape(query,1).is_empty(): return null
	return position

func interact_at(spec: Dictionary) -> bool:
	var layout = game.level.layout
	var aim: Vector3 = layout.world_position(spec.cell)+Vector3.UP*0.7
	var directions = [Vector2.DOWN,Vector2.UP,Vector2.RIGHT,Vector2.LEFT,Vector2(1,1).normalized(),Vector2(-1,1).normalized(),Vector2(1,-1).normalized(),Vector2(-1,-1).normalized()]
	for radius in [1.5,2.25,3.0,3.75]:
		for direction in directions:
			var cell: Array = [spec.cell[0]+direction.x*radius/float(layout.data.cell_size),spec.cell[1]+direction.y*radius/float(layout.data.cell_size)]
			var position = floor_position(cell)
			if position == null: continue
			game.player.position = position
			game.player.velocity = Vector3.ZERO
			game.player.look_at(Vector3(aim.x,position.y,aim.z),Vector3.UP)
			game.player.camera.look_at(aim,Vector3.UP)
			await settle()
			if game.nearest_interaction().get("id","") != spec.id: continue
			game.interact()
			return true
	return expect(false,"SETUP: no clear native floor/capsule pose passes actual range/facing/line-of-sight for "+spec.id)

func expect(condition: bool, detail: String) -> bool:
	if not condition: push_error(detail)
	return condition

func finish(status: int) -> void:
	if is_instance_valid(game): game.show_title()
	paused = false
	await create_timer(0.1).timeout
	if is_instance_valid(game): game.free()
	await process_frame
	await process_frame
	print("RETAINED isolated user files: ",ProjectSettings.globalize_path(prefix)," status=",status)
	quit(status)
