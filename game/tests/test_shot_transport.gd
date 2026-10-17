extends SceneTree

class ObservedGame extends "res://scripts/main.gd":
	var impacts: Array[Vector3] = []
	func _capture_game_mouse() -> void: pass
	func impact(point: Vector3) -> void:
		impacts.append(point)
		super.impact(point)

var game

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func run() -> void:
	game = ObservedGame.new()
	var prefix = "user://shot_transport_"+str(OS.get_process_id())
	game.progress_path = prefix+"_campaign.json"
	game.settings_path = prefix+"_preferences.json"
	root.add_child(game)
	game.set_process(false)
	game.settings.auto_aim = false
	for weapon in [1,2,3,5]:
		for wall in [false,true]:
			await arena(wall)
			game.state.weapon = weapon
			seed(738)
			if not expect(game.player.fire(),"Actual physics shot fires"): return
			var driver = game.ammo_visuals()
			driver.set_process(false)
			var row = 3 if weapon == 5 else 0
			var routes = driver.slots.filter(func(slot): return slot.sprite.visible and slot.row == row and slot.get("route",false))
			if not expect(routes.size()==(7 if weapon == 2 else 1),"Real shot must emit each travelling route (intended RED)"): return
			if not expect(game.state.ammo[weapon]==9,"Presentation preserves one-round discharge"): return
			for slot in routes:
				if not expect(slot.start.is_finite() and slot.end.is_finite(),"Route endpoints are finite"): return
				if wall:
					if not expect(game.impacts.any(func(point): return point.distance_to(slot.end)<0.001),"Each tracer ends at its real wall contact"): return
				else:
					if not expect(absf(slot.start.distance_to(slot.end)-game.player.WEAPONS[weapon].range)<0.001,"Miss uses the actual finite range"): return
				if not expect(slot.sprite.global_position==slot.start,"Route begins at its captured firing origin"): return
			var state: Dictionary = game.state.to_dict().duplicate(true)
			var impact_count = game.impacts.size()
			var end: Vector3 = routes[0].end
			driver._process(routes[0].duration*0.5)
			if not expect(routes[0].sprite.global_position.is_equal_approx(routes[0].start.lerp(end,0.5)),"Cosmetic follows finite segment"): return
			game.playing = false
			var point: Vector3 = routes[0].sprite.global_position
			driver._process(0.1)
			if not expect(routes[0].sprite.global_position==point,"Paused route freezes"): return
			game.playing = true
			driver._process(10.0)
			if not expect(routes[0].sprite.global_position.is_equal_approx(end) and not routes[0].sprite.visible,"Oversized delta clamps at the endpoint and retires"): return
			if not expect(game.state.to_dict()==state and game.impacts.size()==impact_count,"Cosmetic arrival never adds damage, ammo or impact"): return
			await physics_frame
			if not expect(not game.player.fire() and driver.slots.all(func(slot): return not slot.sprite.visible),"Cooldown refusal emits nothing"): return
			game.player.cooldown = 0
			game.state.ammo[weapon] = 0
			if not expect(not game.player.fire() and driver.slots.all(func(slot): return not slot.sprite.visible),"Dry shot emits nothing"): return
	for count in [2,3,4]:
		if not await piercing(count,false): return
	if not await piercing(2,true): return
	if not await saturation(): return
	print("PASS native shot transport: real finite routes, piercing contacts, protected saturation, reuse, pause and combat parity")
	await finish(0)

func piercing(count: int, wall: bool) -> bool:
	await arena(wall)
	var actors: Array = []
	for index in range(count):
		var actor = game.Enemy.new()
		game.level.add_child(actor)
		actor.configure(game,{"id":"transport_"+str(index),"kind":"worker","cell":[0.5,0.5],"yaw":0})
		actor.position = Vector3(0,0.03,-3-3*index)
		actor.hp = 1000
		actor.set_physics_process(false)
		game.enemies.append(actor)
		actors.append(actor)
	await physics_frame
	await physics_frame
	var origin: Vector3 = game.player.camera.global_position
	var endpoint: Vector3 = origin+Vector3.FORWARD*24
	if wall or count >= 3:
		var query = PhysicsRayQueryParameters3D.create(origin,endpoint,1|4)
		query.exclude = [game.player.get_rid(),actors[0].get_rid(),actors[1].get_rid()]
		var hit = game.get_world_3d().direct_space_state.intersect_ray(query)
		if not expect(not hit.is_empty(),"Piercing fixture has a real terminal contact"): return false
		endpoint = hit.position
	game.state.weapon = 5
	if not expect(game.player.fire(),"Real piercing discharge fires"): return false
	var driver = game.ammo_visuals()
	driver.set_process(false)
	var routes = driver.slots.filter(func(slot): return slot.route and slot.sprite.visible)
	if not expect(routes.size()==1 and routes[0].end.distance_to(endpoint)<0.001,"Piercing tracer stops at actual third actor, wall or range"): return false
	for index in range(count):
		if not expect(actors[index].hp==(960 if index<3 else 1000),"Original three-actor damage cap is unchanged"): return false
	var hp = actors.map(func(actor): return actor.hp)
	var impacts: int = game.impacts.size()
	driver._process(10)
	return expect(actors.map(func(actor): return actor.hp)==hp and game.impacts.size()==impacts,"Piercing cosmetic arrival adds no hits")

func saturation() -> bool:
	await arena(false)
	game.state.weapon = 4
	if not expect(game.player.fire(),"Real marrow projectile supplies protected pool slot"): return false
	var projectile = game.level.get_children().filter(func(node): return node.get_script()==game.player.Projectile)[0]
	projectile.set_physics_process(false)
	var driver = game.ammo_visuals()
	driver.set_process(false)
	var origin: Vector3 = game.player.camera.global_position
	for index in range(31): driver.trace(1,origin,origin+Vector3.FORWARD*(index+1))
	if not expect(driver.slots.size()==32,"Mixed protected fixture fills exact pool bound"): return false
	var snapshot = driver.slots.map(func(slot): return [slot.sprite,slot.sprite.global_position,slot.row,slot.age,slot.route,slot.target])
	for index in range(64):
		driver.impact(origin+Vector3.LEFT)
		driver.trace(5,origin,origin+Vector3.RIGHT*10)
	if not expect(driver.slots.size()==32 and driver.slots.map(func(slot): return [slot.sprite,slot.sprite.global_position,slot.row,slot.age,slot.route,slot.target])==snapshot,"Saturation never evicts admitted routes or live marrow"): return false
	driver._process(10)
	if not expect(driver.slots[0].sprite.visible and not driver.slots[1].sprite.visible,"Expired routes release while live marrow remains"): return false
	var slot: Dictionary = driver.slots[1]
	driver.impact(origin)
	if not expect(slot.sprite.visible and not slot.route and slot.row==3,"Impact reuse clears expired route behavior"): return false
	slot.sprite.visible = false
	driver.casing(game.player)
	var point: Vector3 = slot.sprite.global_position
	var motion: Vector3 = slot.motion
	driver._process(0.1)
	if not expect(not slot.route and slot.row==1 and slot.sprite.global_position.is_equal_approx(point+motion*0.1),"Casing reuse follows casing motion, not stale route"): return false
	projectile.queue_free()
	driver._process(0.01)
	return expect(not driver.slots[0].sprite.visible,"Queued marrow releases protected slot")

func arena(wall: bool) -> void:
	game.show_title()
	paused = false
	await process_frame
	await process_frame
	game.state.new_campaign(1)
	game.level = game.Level.new()
	game.add_child(game.level)
	assert(game.level.layout.load_level(0))
	game.player = game.Player.new()
	game.level.add_child(game.player)
	game.player.configure(game)
	game.player.set_physics_process(false)
	game.player.set_process_unhandled_input(false)
	game.state.owned_weapons.assign([0,1,2,3,4,5])
	game.state.ammo.assign([0,10,10,10,10,10])
	game.playing = true
	game.impacts.clear()
	if wall: game.level._box(Vector3(40,10,0.2),Vector3(0,1,-8),game.level._material(Color.WHITE),true)
	await physics_frame
	await physics_frame

func expect(ok: bool, detail: String) -> bool:
	if not ok:
		push_error(detail)
		finish(1)
	return ok

func finish(status: int) -> void:
	game.show_title()
	paused = false
	await create_timer(0.15).timeout
	game.free()
	await process_frame
	await process_frame
	quit(status)
