extends SceneTree

var game
var failures = 0

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func run() -> void:
	game = load("res://scripts/main.gd").new()
	root.add_child(game)
	game.start_campaign(1)
	game.set_process(false)
	game.player.set_physics_process(false)
	game.settings.auto_aim = true
	for actor in game.enemies:
		actor.set_physics_process(false)
		actor.collision_layer = 0
	var target = game.enemies.filter(func(actor): return actor.kind == "crawler")[0]
	target.collision_layer = 4
	target.position = game.player.position+Vector3(0,0,-15)
	var wall = game.level._box(Vector3(4,4,0.2),game.player.position+Vector3(0,2,-20),game.level._material(Color.GRAY),true)
	await physics_frame
	await physics_frame
	var hp = target.hp
	game.player.fire()
	if not expect(target.hp == hp-22,"Classic auto-aim must hit a visible low enemy with a wall behind it"):
		await finish()
		return
	# A nearer world obstruction must still prevent the assisted shot.
	wall.position.z = game.player.position.z-8
	await physics_frame
	await physics_frame
	game.player.cooldown = 0
	hp = target.hp
	game.player.fire()
	if not expect(target.hp == hp,"Classic auto-aim cannot shoot through world geometry"):
		await finish()
		return
	wall.collision_layer = 0
	var hidden = game.enemies.filter(func(actor): return actor.kind == "crawler" and actor != target)[0]
	hidden.collision_layer = 4
	hidden.position = game.player.position+Vector3(-2.5,0,-10)
	target.position = game.player.position+Vector3(2.5,0,-15)
	# Old .8m cover hid only the capsule centre. Actual art spans3.8m:
	# place distinct silhouettes, then cover the ENTIRE nearer billboard quad.
	var cover = game.level._box(Vector3(2.2,4,.25),game.player.position+Vector3(-1.25,2,-5),game.level._material(Color.GRAY),true)
	await physics_frame
	await physics_frame
	var origin: Vector3 = game.player.camera.global_position
	var space = game.get_world_3d().direct_space_state
	# Independent convex full-quad projection: all four corners intersect the
	# same rectangular cover. Every alpha pixel lies inside that covered quad.
	var sprite: Sprite3D = hidden.sprite
	var frame_size = Vector2(sprite.texture.get_width()/sprite.hframes,sprite.texture.get_height()/sprite.vframes)
	var half_size: Vector2 = frame_size*sprite.pixel_size*.5
	for x in [-1.0,1.0]:
		for y in [-1.0,1.0]:
			var point: Vector3 = sprite.global_position+game.player.camera.global_basis.x*half_size.x*x+game.player.camera.global_basis.y*half_size.y*y
			var query = PhysicsRayQueryParameters3D.create(origin,point,1)
			query.exclude = [game.player.get_rid()]
			expect(space.intersect_ray(query).get("collider")==cover,"Actual native cover hides full nearer art quad corner, not just capsule")
	var visible_points = 0
	for point in game.SpriteHitQuery.candidate_points(target,game.player.camera,origin):
		var query = PhysicsRayQueryParameters3D.create(origin,point,1)
		query.exclude = [game.player.get_rid()]
		if space.intersect_ray(query).is_empty(): visible_points += 1
	expect(visible_points>0,"Far actual rendered frame has occupied texels exposed beyond cover")
	var solution: Dictionary = game.resolve_aim(origin,-game.player.camera.global_basis.z,40.0)
	expect(solution.actor_id==target.id and solution.contact.get("coverage")=="visible_sprite","Fully occluded nearer art cannot suppress exposed farther actual frame")
	game.player.cooldown = 0
	hp = target.hp
	var hidden_hp = hidden.hp
	var ammo: int = game.state.ammo[1]
	expect(game.player.fire() and target.hp==hp-22 and hidden.hp==hidden_hp and game.state.ammo[1]==ammo-1,"Occluded nearer candidate must not suppress exposed crawler assistance; exact real damage/ammo")
	if failures==0: print("PASS native classic auto-aim actual art: visible low target/background wall, full obstruction, entire nearer silhouette covered and exposed farther frame damage")
	await finish()

func expect(condition: bool, detail: String) -> bool:
	if not condition:
		push_error(detail)
		failures += 1
	return condition

func finish() -> void:
	var recording: WeakRef
	if is_instance_valid(game):
		# This fixture owns playback. Do not start another title recording merely
		# to tear down; stop existing native playback and prove mixer release.
		game.playing = false
		if is_instance_valid(game.player): game.player.cancel_actions()
		if game.music.player.stream != null: recording = weakref(game.music.player.stream)
		game.music.stop()
		game.effects.stop()
		game.queue_free()
	paused = false
	await process_frame
	game = null
	var deadline: int = Time.get_ticks_usec()+2000000
	while recording != null and recording.get_ref() != null and Time.get_ticks_usec()<deadline:
		OS.delay_msec(2)
		await process_frame
	expect(recording == null or recording.get_ref() == null,"Fixture-owned actual campaign MP3 releases after stopped playback before exit")
	await process_frame
	call_deferred("terminal")

func terminal() -> void:
	await process_frame
	await process_frame
	quit(0 if failures==0 else 1)
