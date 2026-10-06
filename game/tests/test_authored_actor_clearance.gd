extends SceneTree

const Layout = preload("res://scripts/level_data.gd")
const Enemy = preload("res://scripts/enemy.gd")
var game
var failures: int = 0
var prefix = "user://authored_clearance_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())

func _initialize() -> void: call_deferred("run")

func run() -> void:
	if not expect(AudioServer.get_driver_name() == "CoreAudio","SETUP: authored-world clearance requires CoreAudio"):
		quit(1)
		return
	AudioServer.set_bus_mute(0,true)
	game = load("res://scripts/main.gd").new()
	game.progress_path = prefix+"_campaign.json"
	game.settings_path = prefix+"_preferences.json"
	root.add_child(game)
	game.set_process(false)
	game.set_process_unhandled_input(false)
	game.hud.survey.set_physics_process(false)
	for index in range(8):
		for difficulty in range(3):
			# Complete every case even when an earlier authored world has contacts.
			game.show_title()
			paused = false
			await process_frame
			await process_frame
			var layout = Layout.new()
			if not expect(layout.load_level(index),"SETUP: registered source layout loads: "+str(index)): continue
			game.loaded_positions = false
			game.state.new_campaign(difficulty)
			game.state.level_index = index
			game.start_level()
			var label: String = layout.data.id+" difficulty="+str(difficulty)+": "
			if not expect(game.playing and not game.placement_pending and is_instance_valid(game.level) and is_instance_valid(game.player),label+"actual authored scene constructs before native registration"): continue
			game.player.set_physics_process(false)
			game.player.set_process_unhandled_input(false)
			for actor in game.enemies: actor.set_physics_process(false)
			game.hud.survey.set_physics_process(false)
			game.music.stop()
			await physics_frame
			await physics_frame
			var before: int = failures
			expect(game.level.layout.data.id == layout.data.id and game.enemies.size() == layout.data.enemies.size(),label+"actual authored map and actor count match source")
			var expected_ids: Array = layout.data.enemies.map(func(spec): return spec.id)
			var actual_ids: Array = game.enemies.map(func(actor): return actor.id)
			expected_ids.sort()
			actual_ids.sort()
			expect(actual_ids == expected_ids,label+"all actual authored IDs survive exactly once")
			for spec in layout.data.enemies:
				var matches: Array = game.enemies.filter(func(actor): return actor.id == spec.id)
				if not expect(matches.size() == 1,label+"unique actual actor: "+spec.id): continue
				var actor = matches[0]
				var hp: int = Enemy.health_cap(spec.kind,difficulty)
				var point: Vector3 = layout.world_position(spec.cell)+Vector3.UP*0.03
				if spec.kind in ["caster","choir_avatar"]: point.y += 1.0
				expect(actor._current_map() and actor.kind == spec.kind and actor._summon_owner_id.is_empty() and actor.hp == hp and actor.max_hp == hp,label+"native authored identity/profile/full difficulty HP: "+spec.id)
				var groups: Array = layout.data.get("encounters",[]).filter(func(group): return spec.id in group.enemy_ids)
				var encounter: String = "" if groups.is_empty() else groups[0].id
				expect(actor.encounter_id == encounter and actor.active == encounter.is_empty() and not actor.alerted,label+"native entry retains authored encounter membership/dormancy: "+spec.id)
				expect(actor.position == point and is_zero_approx(wrapf(actor.rotation.y-deg_to_rad(spec.yaw),-PI,PI)),label+"actual authored pose/yaw is not repaired or displaced by the fixture: "+spec.id)
				expect(actor.sprite is Sprite3D and actor.sprite.texture is Texture2D and actor.sprite.texture == load("res://assets/art/sprites/"+spec.kind+".png") and actor.sprite.hframes == 8 and actor.sprite.vframes == 5,label+"actual original actor atlas/model is configured: "+spec.id)
				var collider: CollisionShape3D = actor.get_child(0)
				var dimensions = Vector3(Enemy.capsule_radius(spec.kind),Enemy.capsule_height(spec.kind),0)
				expect(collider.shape is CapsuleShape3D and is_equal_approx(collider.shape.radius,dimensions.x) and is_equal_approx(collider.shape.height,dimensions.y) and actor.collision_layer == 4 and actor.collision_mask == (1|2|4),label+"native capsule and collision remain enabled: "+spec.id)
				check_clearance(actor,layout,label)
			expect(game._valid_restored_actors(),label+"production actor clearance accepts the actual registered authored world")
			print("AUTHORED_CLEARANCE map=",layout.data.id," difficulty=",difficulty," actors=",game.enemies.size()," failures=",failures-before)
	await finish()

func check_clearance(actor, layout, label: String) -> void:
	var collider: CollisionShape3D = actor.get_child(0)
	var space = actor.get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.transform = collider.global_transform
	query.collision_mask = 1|2|4
	query.exclude = [actor.get_rid()]
	var contacts = space.intersect_shape(query,8)
	for contact in contacts:
		var body = contact.collider
		print("AUTHORED_CONTACT actor=",actor.id," position=",actor.position," body=",body.name," position=",body.global_position," ",label)
	expect(contacts.is_empty(),label+"authored capsule must not overlap scenery/world/player/actors: "+actor.id)
	var cell = Vector2(actor.position.x,actor.position.z)/float(layout.data.cell_size)
	var floor_point: Vector3 = layout.world_position([cell.x,cell.y])
	var support = PhysicsRayQueryParameters3D.create(floor_point+Vector3.UP*0.5,floor_point-Vector3.UP,1)
	var hit = space.intersect_ray(support)
	expect(layout.is_walkable(Vector2i(cell.floor())) and not hit.is_empty() and hit.normal.y >= 0.5 and absf(hit.position.y-floor_point.y) < 0.08,label+"actual native floor supports the authored actor: "+actor.id)
	for offset in [Vector2.ZERO,Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
		var sample: Vector2 = cell+offset*collider.shape.radius/float(layout.data.cell_size)
		var roof: float = layout.world_position([sample.x,sample.y]).y+layout.roof_height(Vector2i(sample.floor()))
		expect(actor.position.y+collider.shape.height+0.03 < roof,label+"authored capsule remains below the original roof: "+actor.id)

func expect(condition: bool, label: String) -> bool:
	if not condition:
		failures += 1
		push_error(label)
	return condition

func finish() -> void:
	game.show_title()
	paused = false
	await create_timer(0.1).timeout
	await process_frame
	await process_frame
	game.free()
	await process_frame
	for suffix in ["_campaign.json","_campaign.json.tmp","_preferences.json","_preferences.json.tmp"]:
		var path = prefix+suffix
		if FileAccess.file_exists(path): expect(DirAccess.remove_absolute(path) == OK,"Cleanup only the isolated authored-clearance fixture file")
	if failures == 0: print("PASS actual all-eight authored actor clearance/IDs/HP/poses/models/collision, three difficulties and two native registration frames; not played combat or visual acceptance")
	quit(0 if failures == 0 else 1)
