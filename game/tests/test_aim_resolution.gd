extends SceneTree

class NativeGame extends "res://scripts/main.gd":
	func _ready() -> void:
		set_process(false)

var game
var failures: int = 0

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func deterministic_sprite(body, pixels: Array = [Vector2i(1,1)]) -> void:
	# Independent analytic atlas: 3x3 frames, centre pixel has exact world centre.
	# Adjacent frame deliberately transparent, preventing whole-texture occupancy.
	var image = Image.create(6,3,false,Image.FORMAT_RGBA8)
	image.fill(Color(0,0,0,0))
	for pixel in pixels: image.set_pixelv(pixel,Color.WHITE)
	body.sprite.texture = ImageTexture.create_from_image(image)
	body.sprite.hframes = 2
	body.sprite.vframes = 1
	body.sprite.frame = 0
	body.sprite.pixel_size = 0.2
	body.sprite.position = Vector3(0,1.55,0)
	body.sprite.modulate = Color.WHITE
	body.sprite.alpha_scissor_threshold = 0.5

func actor(id: String, location: Vector3, role: String = "worker", analytic: bool = true):
	var body = game.Enemy.new()
	game.level.add_child(body)
	body.configure(game,{"id":id,"kind":role,"cell":[0.5,0.5],"yaw":0})
	body.position = location
	if analytic: deterministic_sprite(body)
	body.set_physics_process(false)
	body.active = true
	game.enemies.append(body)
	return body

func expect(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)

func solve() -> Dictionary:
	return game.resolve_aim(game.player.camera.global_position,-game.player.camera.global_basis.z,40.0)

func run() -> void:
	preload("res://scripts/preferences.gd").new().apply_bindings()
	game = NativeGame.new()
	root.add_child(game)
	game.state.new_campaign(1)
	game.level = game.Level.new()
	game.add_child(game.level)
	expect(game.level.layout.load_level(0),"SETUP load actual map ownership")
	game.player = game.Player.new()
	game.level.add_child(game.player)
	game.player.configure(game)
	game.player.set_physics_process(false)
	game.player.position = Vector3(0,.04,0)
	game.settings.auto_aim = true
	game.playing = true
	var wrong = actor("wrong_map",Vector3(0,.04,-3))
	wrong.reparent(game)
	await physics_frame
	await physics_frame
	var solution := solve()
	expect(solution.contact.is_empty(),"Wrong-map visual capsule is NOT a substitute for current visible sprite occupancy")
	expect(solution.actor_id.is_empty() and game.autoaim_target(solution.origin,solution.manual_direction,40.0) == null,"Wrong-map native manual obstruction cannot become selected actor")
	wrong.collision_layer = 0
	var near = actor("near",Vector3(10*sqrt(1-.99000001*.99000001),.04,-10*.99000001))
	var far = actor("far",Vector3(-20*sqrt(1-.99000502*.99000502),.04,-20*.99000502))
	await physics_frame
	await physics_frame
	game.enemies = [near,far]
	var forward := solve()
	game.enemies.reverse()
	var reverse := solve()
	print("MEASURE angular ranking forward=",forward.actor_id," reverse=",reverse.actor_id)
	expect(forward.actor_id == "far" and reverse.actor_id == "far","Angular-first target must not depend on enemy enumeration")
	near.position = Vector3(1,.04,-10)
	far.position = Vector3(-1,.04,-10)
	near.id = "a_stable"
	far.id = "z_stable"
	await physics_frame
	await physics_frame
	game.enemies = [near,far]
	forward = solve()
	game.enemies.reverse()
	reverse = solve()
	print("MEASURE exact symmetric tie forward=",forward.actor_id," reverse=",reverse.actor_id)
	expect(forward.actor_id == "a_stable" and reverse.actor_id == "a_stable","Symmetric native contact ties use stable authored ID")
	near.collision_layer = 0
	far.collision_layer = 0
	await check_contacts()
	await check_occluded_fallback()
	await check_partial_cover()
	await check_ranking_and_lifetime()
	wrong.free()
	game.free()
	await process_frame
	if failures == 0: print("PASS visible-sprite aim: deterministic atlas angle/id ranking, exact plane reach, melee bounds, cover, real-role alpha, real damage/ammo and lifetime; synthetic arena, not physical/GPU/HUD acceptance")
	quit(0 if failures == 0 else 1)

func contact_is(solution: Dictionary, body, reach: float, label: String) -> void:
	expect(Engine.is_in_physics_frame(),label+": query/assertion runs inside native physics")
	expect(solution.actor_id == body.id and solution.contact.get("collider") == body,label+": selected ID matches visible-sprite first contact")
	expect(solution.contact.get("coverage") == "visible_sprite",label+": contact uses actual opaque sprite coverage, not capsule")
	var point: Vector3 = solution.contact.get("position",Vector3.INF)
	expect(point.is_finite() and solution.origin.distance_to(point) <= reach+.00001,label+": actual 3D contact is finite and within reach")

func tool_solution() -> Dictionary:
	return game.resolve_aim(game.player.camera.global_position,-game.player.camera.global_basis.z,game.Player.WEAPONS[0].range,true)

func check_contacts() -> void:
	# Native floors are still physical; analytic visible pixels, NOT capsules, are hit geometry.
	var floor = game.level._box(Vector3(1.4,.2,1.4),Vector3(0,-.1,-1.8),null,true)
	var low = actor("floor_crawler",Vector3(0,.04,-1.8),"crawler")
	game.enemies = [low]
	game.state.weapon = 0
	low.sprite.position.y = .7
	for elevation in [-.4,.4]:
		floor.position.y = elevation-.1
		low.position.y = elevation+.04
		await physics_frame
		await physics_frame
		var query := PhysicsRayQueryParameters3D.create(low.position+Vector3.UP*.2,low.position-Vector3.UP*.2,1)
		var support: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
		expect(support.get("collider") == floor and absf(support.get("position",Vector3.INF).y-elevation)<.00001,"Actual offset native floor remains independent of sprite hits")
		contact_is(tool_solution(),low,2.7,"Offset-floor visible crawler pixel "+str(elevation))
		var hp: int = low.hp
		game.player.cooldown = 0
		expect(game.player.fire() and low.hp==hp-28,"Tool damages visible offset-floor pixel exactly once")
		low.hp = hp
	floor.collision_layer = 0
	low.sprite.position.y = 1.55
	for yaw in [12.7,13.0]:
		low.position = Vector3(sin(deg_to_rad(yaw))*2.4,.04,-cos(deg_to_rad(yaw))*2.4)
		await physics_frame
		await physics_frame
		var solution := tool_solution()
		if yaw<12.8: contact_is(solution,low,2.7,"Inside horizontal cone exact occupied centre")
		else: expect(solution.actor_id.is_empty(),"Outside .975 horizontal centre cone rejected")
		var hp: int = low.hp
		game.player.cooldown = 0
		expect(game.player.fire() and low.hp==hp-(28 if yaw<12.8 else 0),"Real tool obeys horizontal correction bound")
		low.hp = hp
	low.sprite.position.y = .55
	for elevation in [0.04,-.16]:
		low.position = Vector3(0,elevation,-.8)
		await physics_frame
		await physics_frame
		var centre: Vector3 = low.sprite.global_position
		expect(game.player.camera.global_position.distance_to(centre)<2.7,"Both analytic occupied centres are physically in finite reach")
		var vertical: float = absf((centre-game.player.camera.global_position).normalized().y)
		expect((vertical<=.8)==(elevation>0),"Independent .8 vertical correction analytic classification")
		var solution := tool_solution()
		if elevation>0: contact_is(solution,low,2.7,"Inside vertical centre correction")
		else: expect(solution.actor_id.is_empty(),"Reachable occupied pixel outside vertical bound rejected")
		var hp: int = low.hp
		game.player.cooldown = 0
		expect(game.player.fire() and low.hp==hp-(28 if elevation>0 else 0),"Actual tool obeys vertical correction")
		low.hp = hp
	low.sprite.position.y = 1.55
	for distance in [2.699,2.701,2.9]:
		low.position = Vector3(0,.04,-distance)
		await physics_frame
		await physics_frame
		var solution := tool_solution()
		if distance<2.7: contact_is(solution,low,2.7,"Inside exact sprite-plane reach")
		else: expect(solution.actor_id.is_empty(),"Sprite plane outside finite reach is NOT rescued by nearer movement capsule")
		var hp: int = low.hp
		game.player.cooldown = 0
		expect(game.player.fire() and low.hp==hp-(28 if distance<2.7 else 0),"Real tool damage agrees with finite visible plane")
		low.hp = hp
	low.position = Vector3(0,.04,-2.4)
	low.sprite.frame = 1
	await physics_frame
	await physics_frame
	expect(tool_solution().actor_id.is_empty(),"Transparent adjacent atlas frame cannot fall back to unchanged movement capsule")
	var transparent_hp: int = low.hp
	game.player.cooldown = 0
	expect(game.player.fire() and low.hp==transparent_hp,"Actual tool cannot damage an empty rendered atlas frame")
	low.collision_layer = 0
	game.state.weapon = 1
	game.state.ammo[1] = 180
	for role in ["crawler","brute","caster"]:
		var body = actor("actual_role_"+role,Vector3(0,1.04 if role=="caster" else .04,-8),role,false)
		game.enemies = [body]
		var sprite: Sprite3D = body.sprite
		var image: Image = sprite.texture.get_image()
		if image.is_compressed(): expect(image.decompress()==OK,"Actual atlas decompresses")
		image.convert(Image.FORMAT_RGBA8)
		var size = Vector2i(image.get_width()/sprite.hframes,image.get_height()/sprite.vframes)
		var offset = Vector2i(sprite.frame%sprite.hframes,sprite.frame/sprite.hframes)*size
		var chosen = Vector2i(-1,-1)
		for y in range(size.y):
			for x in range(size.x):
				if image.get_pixelv(offset+Vector2i(x,y)).a>=sprite.alpha_scissor_threshold:
					chosen = Vector2i(x,y)
		if not chosen.x>=0:
			expect(false,"Actual role frame has occupied art: "+role)
			body.collision_layer = 0
			continue
		# Independent documented Sprite3D billboard pixel-centre construction.
		var local = Vector2(chosen)+Vector2(.5,.5)-Vector2(size)*.5
		var point: Vector3 = sprite.global_position+game.player.camera.global_basis.x*local.x*sprite.pixel_size-game.player.camera.global_basis.y*local.y*sprite.pixel_size
		await physics_frame
		await physics_frame
		var origin: Vector3 = game.player.camera.global_position
		var solution: Dictionary = game.resolve_aim(origin,(point-origin).normalized(),40.0)
		contact_is(solution,body,40.0,"Actual visible atlas "+role)
		expect(solution.contact.get("sprite_pixel")==offset+chosen,"Actual role exact alpha texel agrees with independently decoded frame")
		var acquired := solve()
		contact_is(acquired,body,40.0,"Actual-role visible auto/manual acquisition "+role)
		var hp: int = body.hp
		var ammo: int = game.state.ammo[1]
		game.player.cooldown = 0
		expect(game.player.fire() and body.hp==hp-22 and game.state.ammo[1]==ammo-1,"Actual role visible artwork receives exactly one native rivet: "+role)
		body.collision_layer = 0
	game.player.camera.rotation = Vector3.ZERO

func check_ranking_and_lifetime() -> void:
	var peripheral = actor("peripheral",Vector3(sin(deg_to_rad(8))*10,.04,-cos(deg_to_rad(8))*10))
	var centered = actor("centered",Vector3(-sin(deg_to_rad(3))*20,.04,-cos(deg_to_rad(3))*20))
	game.enemies = [peripheral,centered]
	await physics_frame
	await physics_frame
	var solution := solve()
	contact_is(solution,centered,40.0,"Far centered beats near peripheral")
	var hp: int = centered.hp
	var peripheral_hp: int = peripheral.hp
	game.player.cooldown = 0
	expect(game.player.fire() and centered.hp == hp-22 and peripheral.hp == peripheral_hp,"Real ranged damage follows angular winner, not nearer peripheral actor")
	var manual = actor("manual",Vector3(0,.04,-6))
	await physics_frame
	await physics_frame
	solution = solve()
	expect(not solution.assisted,"Direct manual centre hit is never redirected")
	contact_is(solution,manual,40.0,"Manual centre priority")
	hp = manual.hp
	var centered_hp: int = centered.hp
	game.player.cooldown = 0
	expect(game.player.fire() and manual.hp == hp-22 and centered.hp == centered_hp and peripheral.hp == peripheral_hp,"Manual actor alone receives real ranged damage")
	for body in [peripheral,centered,manual]: body.collision_layer = 0
	var doomed = actor("a_die",Vector3(1,.04,-10))
	var survivor = actor("z_live",Vector3(-1,.04,-10))
	game.enemies = [doomed,survivor]
	await physics_frame
	await physics_frame
	contact_is(solve(),doomed,40.0,"Live pre-death target")
	doomed.take_damage(doomed.hp,game.player)
	await physics_frame
	await physics_frame
	expect(doomed.hp == 0 and doomed.collision_layer == 0 and doomed.id in game.state.removed,"Actual damage/death retires capsule and records removal")
	contact_is(solve(),survivor,40.0,"Dead actor cannot suppress live replacement")
	survivor.queue_free()
	expect(survivor.is_queued_for_deletion() and solve().actor_id.is_empty(),"Queued actor is excluded before deferred destruction")
	var retired_level = game.level
	var retired_player = game.player
	var retired_origin: Vector3 = retired_player.camera.global_position
	retired_player.cooldown = 0
	var ammo_before: Array = game.state.ammo.duplicate()
	game.level = game.Level.new()
	game.add_child(game.level)
	expect(game.level.layout.load_level(0),"SETUP replacement level owns actual layout")
	var stale: Dictionary = game.resolve_aim(retired_origin,Vector3.FORWARD,40.0)
	expect(stale.actor_id.is_empty() and stale.contact.is_empty(),"Replacing map rejects old player's queries even while playing remains true")
	expect(not retired_player.fire() and game.state.ammo == ammo_before,"Retired player cannot spend ammunition or damage a new map")
	game.player = game.Player.new()
	game.level.add_child(game.player)
	game.player.configure(game)
	game.player.set_physics_process(false)
	game.player.position = Vector3(0,.04,0)
	game.enemies.clear()
	var replacement = actor("new_map",Vector3(0,.04,-6))
	retired_level.queue_free()
	await physics_frame
	await physics_frame
	contact_is(solve(),replacement,40.0,"Replacement map has a real positive contact")

func check_partial_cover() -> void:
	var body = actor("partial_cover",Vector3(1,.04,-10))
	deterministic_sprite(body,[Vector2i(1,0),Vector2i(1,1),Vector2i(1,2)])
	game.enemies = [body]
	var cover = game.level._box(Vector3(.25,1.65,.1),Vector3(.5,.825,-5),null,true)
	await physics_frame
	await physics_frame
	var origin: Vector3 = game.player.camera.global_position
	for height in [1.39,1.59,1.79]:
		var query := PhysicsRayQueryParameters3D.create(origin,Vector3(1,height,-10),1)
		query.exclude = [game.player.get_rid()]
		var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
		expect(hit.is_empty() if height>1.7 else hit.get("collider")==cover,"Independent solid-only ray proves actual partial cover lower/centre vs upper occupied pixels")
	var solution := solve()
	contact_is(solution,body,40.0,"Visible upper occupied texel survives covered centre")
	expect(solution.contact.get("frame_pixel")==Vector2i(1,0),"Partial cover resolves exposed atlas texel, not capsule sample")
	var hp: int = body.hp
	var ammo: int = game.state.ammo[1]
	game.player.cooldown = 0
	expect(game.player.fire() and body.hp==hp-22 and game.state.ammo[1]==ammo-1,"Native rivet spends one round and damages visible partial-cover contact")
	var wall = game.level._box(Vector3(3,4,.2),Vector3(.5,2,-5),null,true)
	await physics_frame
	await physics_frame
	var blocked := solve()
	expect(blocked.actor_id.is_empty() and blocked.contact.get("collider")==wall,"Complete native wall preserves manual obstruction and excludes all sprite candidates")
	hp = body.hp
	ammo = game.state.ammo[1]
	game.player.cooldown = 0
	expect(game.player.fire() and body.hp==hp and game.state.ammo[1]==ammo-1,"Full wall stops real damage without refunding actual round")
	wall.collision_layer = 0
	body.collision_layer = 0
	cover.collision_layer = 0

func check_occluded_fallback() -> void:
	var rear = actor("occluded_rear",Vector3(1,.04,-8),"crawler")
	var front = actor("dormant_obstruction",Vector3(.625,.04,-5),"crawler")
	front.active = false
	game.enemies = [rear,front]
	await physics_frame
	await physics_frame
	var origin: Vector3 = game.player.camera.global_position
	var space = game.get_world_3d().direct_space_state
	var exclusions: Array[RID] = [game.player.get_rid()]
	var manual: Dictionary = game.SpriteHitQuery.cast(space,origin,origin+Vector3.FORWARD*40,game.player.camera,game.enemies,exclusions,5)
	expect(manual.is_empty(),"Manual centre ray misses both offset visible pixels")
	var blocked: Dictionary = game.SpriteHitQuery.cast(space,origin,rear.sprite.global_position,game.player.camera,game.enemies,exclusions,5)
	expect(blocked.get("collider")==front,"Dormant visible sprite actually obstructs rear occupied pixel")
	var solution := solve()
	expect(solution.actor_id.is_empty() and solution.contact.is_empty(),"Occluded assisted fallback cannot advertise rear over dormant sprite")
	var rear_hp: int = rear.hp
	var front_hp: int = front.hp
	var ammo: int = game.state.ammo[1]
	game.player.cooldown = 0
	expect(game.player.fire() and rear.hp==rear_hp and front.hp==front_hp and game.state.ammo[1]==ammo-1,"Manual miss spends one rivet without damaging occluded or dormant actors")
	front.collision_layer = 0
	rear.collision_layer = 0
