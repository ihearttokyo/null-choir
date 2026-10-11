extends "res://tests/test_active_boss_fights.gd"

const Layout = preload("res://scripts/level_data.gd")
var authored_ids: Array = []
var actor_samples: Dictionary = {}

func run() -> void:
	prefix = "user://campaign_prefix_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	if not expect(Engine.physics_ticks_per_second == 60,"SETUP: requires native 60-Hz physics"):
		await finish(1)
		return
	release_actions()
	seed(1304)
	game = ObservedMain.new()
	game.settings_path = prefix+"_preferences.json"
	game.progress_path = prefix+"_campaign.json"
	root.add_child(game)
	game.set_process(false)
	game.set_process_unhandled_input(false)
	if not press_button("New campaign") or not press_button("Relentless") or not await settle_entry(0):
		await finish(1)
		return
	if not expect(game.state.difficulty == 1 and game.state.health == 100 and game.state.armor == 0 and game.state.ammo == [0,90,0,0,0,0] and game.state.owned_weapons == [0,1] and game.state.weapon == 1 and game.state.discoveries.is_empty(),"Real New campaign/Relentless starts default resources and no discoveries"):
		await finish(1)
		return
	for index in range(8):
		if not await check_map(index):
			await finish(1)
			return
	print("PASS single synthetically staged eight-map campaign: eight E discoveries, seven Descends, naturally carried resources, both active boss fights, all-clue ending and completed disk Continue. Not branch traversal, human play, campaign budget, graphics or packed-app acceptance.")
	await finish(0)

func check_map(index: int) -> bool:
	var data: Dictionary = game.level.layout.data
	print("PREFIX_ENTRY index=",index," resources=",inventory()," discoveries=",game.state.discoveries)
	var story: Dictionary = interaction("story")
	if not expect(story.get("id","") == data.id+"_story","Registered map retains its authored discovery"): return false
	if not await interact_at(story): return false
	if not expect(game.state.discoveries == range(index+1) and game.state.removed.count(story.id) == 1 and not game.level.markers.has(story.id) and game.message == story.text,"E discovers exactly one authored story and consumes its marker/text"): return false
	for spec in data.pickups:
		if not collect_supply(spec): return false
	for key in data.interactions.filter(func(spec): return spec.kind == "key"):
		if not await interact_at(key): return false
		if not expect(key.key in game.state.keys and game.state.removed.count(key.id) == 1 and not game.level.markers.has(key.id) and game.message == key.text,"Actual E earns each seal and its authored message once"): return false
	if not expect(game.state.keys.size() == 2,"Both seals are earned without direct state edits"): return false
	var checkpoint: Dictionary = interaction("checkpoint")
	if not move_to(checkpoint.cell): return false
	game._process(0)
	var saved = load("res://scripts/campaign.gd").new()
	print("PREFIX_CHECKPOINT expected=",checkpoint.id," actual=",game.state.checkpoint_id," removed=",game.state.removed.count(checkpoint.id)," marker=",game.level.markers.has(checkpoint.id)," load=",saved.load_progress(game.progress_path)," saved_index=",saved.level_index," saved_checkpoint=",saved.checkpoint_id," saved_discoveries=",saved.discoveries," current_discoveries=",game.state.discoveries," message=",game.message)
	if not expect(game.state.checkpoint_id == checkpoint.id and game.state.removed.count(checkpoint.id) == 1 and saved.load_progress(game.progress_path) and saved.level_index == index and saved.checkpoint_id == checkpoint.id and saved.discoveries == game.state.discoveries,"Actual proximity checkpoint records removal exactly once and persists this map/discoveries; terminal marker behavior is not a collection contract"): return false
	for gate in data.doors:
		if not await interact_at(gate): return false
		if not expect(game.state.removed.count(gate.id) == 1 and not game.level.doors.has(gate.id),"E opens the actual two-seal native gate"): return false
	if index in [4,7]:
		game.boss_id = "nursery_warden" if index == 4 else "heart_choir_avatar"
		var bosses: Array = game.enemies.filter(func(actor): return actor.id == game.boss_id)
		if not expect(bosses.size() == 1,"Nursery retains its actual manifestation"): return false
		var boss = bosses[0]
		var finale: Dictionary = data.encounters.filter(func(group): return group.id == data.id+"_finale")[0]
		if not move_to(ENTRIES[index]): return false
		game._process(0)
		if not expect(boss.hp == boss.max_hp and boss.max_hp == (1200 if index == 4 else 1600) and boss.phase == 0 and boss.active and "encounter:"+finale.id in game.state.removed,"Real finale activates the untouched full-health Nursery boss"): return false
		await tap_key(KEY_2) # Select the carried pistol through real numeric input, never overwrite inventory.
		if not expect(game.state.weapon == 1 and game.state.discoveries == range(index+1),"All earned discoveries and naturally carried pistol enter the shared fight"): return false
		print("PREFIX_BATTLE_START resources=",inventory()," activated_groups=",activated_groups())
		actor_samples.clear()
		if not await battle(index,boss,finale): return false
		print("PREFIX_BATTLE_END resources=",inventory()," activated_groups=",activated_groups())
		if not battle_groups_ok(finale.id) or not expect(game.state.discoveries == range(index+1),"Battle preserves every earned discovery"): return false
		game.set_process(false)
		game.player.set_physics_process(false)
		for actor in game.enemies: actor.set_physics_process(false) # Interaction staging resumes only after observed victory.
	var carried: Dictionary = inventory()
	var discovered: Array = game.state.discoveries.duplicate()
	var old_nodes: Array = [weakref(game.level)]
	for child in game.level.get_children(): old_nodes.append(weakref(child))
	retired.append_array(old_nodes)
	if not await interact_at(interaction("exit")): return false
	if not expect(game.state.level_index == index+1 and not game.playing and game.level == null and game.state.position == Vector3.ZERO and game.state.keys.is_empty() and game.state.removed.is_empty() and game.state.explored.is_empty() and game.state.actors == null,"Actual exit advances once and clears level-local state"): return false
	if not expect(saved.load_progress(game.progress_path) and saved.level_index == index+1 and saved.discoveries == discovered,"Exit atomically persists the actual next campaign index"): return false
	var disk_resources: Dictionary = saved._resources()
	for field in carried:
		if not expect(disk_resources[field] == carried[field],"Exit disk save carries the exact earned resource: "+field): return false
	if index == 7:
		var revelation = "YOUR VOICE ISSUED THE FIRST ORDER\nTHE RESTRAINT WAS BUILT AROUND YOU"
		if not expect(game.state.level_index == 8 and game.state.discoveries == range(8) and game.level == null and game.menu.get_child(0).text == revelation,"Actual Heart exit presents the earned all-eight revelation"): return false
		if not expect(not Layout.new().load_level(8),"Completed campaign has no ninth map"): return false
		if not press_button("Return to title"): return false
		var old_main: Array = [weakref(game),weakref(game.music),weakref(game.effects)]
		retired.append_array(old_main)
		await create_timer(0.1,true).timeout
		game.free()
		game = null
		await process_frame
		await process_frame
		if not expect(old_main.all(func(reference): return reference.get_ref() == null),"Completed previous Main/audio must drain before fresh disk Continue"): return false
		game = ObservedMain.new()
		game.settings_path = prefix+"_preferences.json"
		game.progress_path = prefix+"_campaign.json"
		root.add_child(game)
		game.set_process_unhandled_input(false)
		if not expect(game.state.level_index == 0 and game.state.discoveries.is_empty() and game.state.ammo == [0,90,0,0,0,0] and inventory() != carried,"Fresh title Main has default state distinct from completed disk save"): return false
		if not press_button("Continue"): return false
		await process_frame
		await process_frame
		return expect(game.state.level_index == 8 and inventory() == carried and game.state.discoveries == discovered and game.level == null and not game.playing and game.menu.get_child(0).text == revelation,"Completed real disk Continue reloads exact earned resources/discoveries and revelation")
	var next_layout = Layout.new()
	if not expect(next_layout.load_level(index+1),"Next actual registered map loads"): return false
	release_actions()
	if not press_button("Descend to "+next_layout.data.title.capitalize()) or not await settle_entry(index+1): return false
	return expect(old_nodes.all(func(reference): return reference.get_ref() == null) and inventory() == carried and game.state.discoveries == discovered,"Real Descend frees retired native nodes and carries health/armor/ammo/ownership/selection/discoveries")

func settle_entry(index: int) -> bool:
	for frame in range(120):
		if game.playing and not game.placement_pending and is_instance_valid(game.player): break
		await physics_frame
	if not expect(game.playing and not game.placement_pending and is_instance_valid(game.level) and is_instance_valid(game.player) and game.state.level_index == index,"Menu callback must finish actual level placement within 120 physics frames"): return false
	game.set_process(false)
	game.player.set_physics_process(false)
	game.hud.survey.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)
	await physics_frame
	await physics_frame
	await process_frame
	var data: Dictionary = game.level.layout.data
	authored_ids = data.enemies.map(func(spec): return spec.id)
	var actual: Array = game.enemies.map(func(actor): return actor.id)
	actual.sort()
	var expected: Array = authored_ids.duplicate()
	expected.sort()
	return expect(actual == expected and game.state.checkpoint_id == "entry" and game.state.keys.is_empty() and game.state.position.is_equal_approx(game.level.layout.world_position(data.spawn)) and floor_position(data.spawn) != null,"Each real entry reacquires the complete authored actors and its native floor/capsule")

func inventory() -> Dictionary:
	var result: Dictionary = {}
	for field in ["health","armor","ammo","owned_weapons","weapon"]: result[field] = game.state._resources()[field]
	return result

func activated_groups() -> Array:
	return game.level.layout.data.encounters.filter(func(group): return "encounter:"+group.id in game.state.removed).map(func(group): return group.id)

func battle_groups_ok(_finale: String) -> bool:
	for id in authored_ids:
		if not expect(game.enemies.any(func(actor): return is_instance_valid(actor) and actor.id == id and actor._current_map()),"Battle retains every authored Nursery actor: "+id): return false
	for actor in game.enemies:
		if not expect(is_instance_valid(actor) and actor._current_map() and actor.is_physics_processing(),"All authored/summoned battle actors resume automatic physics"): return false
		var id: int = actor.get_instance_id()
		if actor_samples.has(id) and not expect(actor.age > actor_samples[id],"Every authored/summoned actor advances its production age through automatic physics: "+actor.id): return false
		actor_samples[id] = actor.age
		if actor.hp > 0 and "encounter:"+actor.encounter_id in game.state.removed and not expect(actor.active,"Every genuinely activated group participates: "+actor.encounter_id): return false
	return true

func collect_supply(spec: Dictionary) -> bool:
	if spec.id in game.state.removed: return expect(game.state.removed.count(spec.id) == 1 and not game.level.markers.has(spec.id),"Earlier real proximity collection stays consumed once: "+spec.id)
	var field: String = "ammo" if spec.kind in ["ammo","weapon"] else spec.kind
	var weapon: int = int(spec.get("weapon",0))
	var before: int = game.state.ammo[weapon] if field == "ammo" else game.state.get(field)
	var capacity: int = game.player.WEAPONS[weapon].max_ammo if field == "ammo" else (100 if field == "health" else 200)
	var acquired: bool = spec.kind == "weapon" and not weapon in game.state.owned_weapons
	if not move_proximity(spec.cell): return false
	game._process(0)
	var after: int = game.state.ammo[weapon] if field == "ammo" else game.state.get(field)
	var consumed: bool = before < capacity or acquired
	if not expect(after == mini(capacity,before+int(spec.amount)) and game.state.removed.count(spec.id) == (1 if consumed else 0) and game.level.markers.has(spec.id) == (not consumed),"Finite authored supply obeys its cap and removal rule: "+spec.id): return false
	if not expect(not acquired or (weapon in game.state.owned_weapons and game.state.weapon == weapon),"Real weapon pickup grants ownership/selection: "+spec.id): return false
	print("PREFIX_SUPPLY id=",spec.id," before=",before," after=",after," consumed=",consumed)
	game._process(0)
	return expect((game.state.ammo[weapon] if field == "ammo" else game.state.get(field)) == after and game.state.removed.count(spec.id) == (1 if consumed else 0),"Repeated proximity processing cannot duplicate finite supplies: "+spec.id)

func interaction(kind: String) -> Dictionary:
	for spec in game.level.layout.data.interactions:
		if spec.kind == kind: return spec
	return {}

func floor_position(cell: Array):
	var layout = game.level.layout
	if not layout.is_walkable(Vector2i(floori(cell[0]),floori(cell[1]))): return null
	var point: Vector3 = layout.world_position(cell)
	var space = game.level.get_world_3d().direct_space_state
	var hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*2,point-Vector3.UP*0.5,1))
	if hit.is_empty() or absf(hit.position.y-point.y) > 0.08 or hit.normal.y < 0.7: return null
	var pose: Vector3 = point+Vector3.UP*0.04
	var collider: CollisionShape3D = game.player.get_child(0)
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.transform = Transform3D(Basis.IDENTITY,pose+collider.position)
	query.collision_mask = game.player.collision_mask
	query.exclude = [game.player.get_rid()]
	return pose if space.intersect_shape(query,1).is_empty() else null

func move_proximity(cell: Array) -> bool:
	var size: float = game.level.layout.data.cell_size
	for radius in [0.0,0.4,0.8,1.2]:
		for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(1,1).normalized(),Vector2(-1,1).normalized(),Vector2(1,-1).normalized(),Vector2(-1,-1).normalized()]:
			var pose = floor_position([cell[0]+direction.x*radius/size,cell[1]+direction.y*radius/size])
			if pose == null: continue
			game.player.position = pose
			game.player.velocity = Vector3.ZERO
			return true
	return expect(false,"Production proximity pickup needs bounded nearby native capsule clearance: "+str(cell))

func move_to(cell: Array) -> bool:
	var pose = floor_position(cell)
	if not expect(pose != null,"Synthetic staging needs real native floor/capsule clearance: "+str(cell)): return false
	game.player.position = pose
	game.player.velocity = Vector3.ZERO
	return true

func interact_at(spec: Dictionary) -> bool:
	var layout = game.level.layout
	var location: Vector3 = layout.world_position(spec.cell)
	var directions = [Vector2.DOWN,Vector2.UP,Vector2.RIGHT,Vector2.LEFT,Vector2(1,1).normalized(),Vector2(-1,1).normalized(),Vector2(1,-1).normalized(),Vector2(-1,-1).normalized()]
	if spec.has("size"):
		var checkpoint = interaction("checkpoint")
		directions.push_front(Vector2(checkpoint.cell[0]-spec.cell[0],checkpoint.cell[1]-spec.cell[1]).normalized())
	for radius in [1.5,2.25,3.0,3.75]:
		for direction in directions:
			var cell: Array = [spec.cell[0]+direction.x*radius/float(layout.data.cell_size),spec.cell[1]+direction.y*radius/float(layout.data.cell_size)]
			var pose = floor_position(cell)
			if pose == null: continue
			game.player.position = pose
			game.player.velocity = Vector3.ZERO
			var aim: Vector3 = location+Vector3.UP*(spec.size[1]/2.0 if spec.has("size") else 0.7)
			game.player.look_at(Vector3(aim.x,pose.y,aim.z),Vector3.UP)
			game.player.camera.look_at(aim,Vector3.UP)
			await physics_frame
			if game.nearest_interaction().get("id","") != spec.id: continue
			game._process(0)
			await tap_key(KEY_E)
			return true
	return expect(false,"E requires a bounded clear native floor pose and visible nearest interaction: "+spec.id)

func tap_key(code: int) -> void:
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	game.player.set_physics_process(true)
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await physics_frame
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	if is_instance_valid(game.player): game.player.set_physics_process(false)
	await process_frame

func press_button(label: String) -> bool:
	for node in game.menu.get_children():
		if node is Button and not node.is_queued_for_deletion() and node.text == label:
			node.pressed.emit()
			return true
	return expect(false,"Actual native menu action must exist: "+label)
