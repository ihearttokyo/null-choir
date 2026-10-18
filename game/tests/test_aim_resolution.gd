extends SceneTree

class NativeGame extends "res://scripts/main.gd":
	func _ready() -> void:
		set_process(false)

var game
var failures: int = 0

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func actor(id: String, location: Vector3, role: String = "worker"):
	var body = game.Enemy.new()
	game.level.add_child(body)
	body.configure(game,{"id":id,"kind":role,"cell":[0.5,0.5],"yaw":0})
	body.position = location
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
	expect(solution.contact.get("collider") == wrong,"SETUP wrong-map native collider actually intersects manual ray")
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
	if failures == 0: print("PASS native aim contacts, floor/angle limits, capsule roles, ranking and lifetime; synthetic arena, not physical/GPU/HUD acceptance")
	quit(0 if failures == 0 else 1)

func contact_is(solution: Dictionary, body, reach: float, label: String) -> void:
	expect(Engine.is_in_physics_frame(),label+": query/assertion runs inside native physics")
	expect(solution.actor_id == body.id and solution.contact.get("collider") == body,label+": selected ID matches native first contact")
	var point: Vector3 = solution.contact.get("position",Vector3.INF)
	expect(point.is_finite() and solution.origin.distance_to(point) <= reach+.00001,label+": actual 3D contact is finite and within reach")

func tool_solution() -> Dictionary:
	return game.resolve_aim(game.player.camera.global_position,-game.player.camera.global_basis.z,game.Player.WEAPONS[0].range,true)

func check_contacts() -> void:
	# Native floors/capsules in a synthetic arena; no normal navigation or actor settling claim.
	var hp: int = 0
	var player_floor = game.level._box(Vector3(1.4,.2,1.4),Vector3(0,-.1,0),null,true)
	var floor = game.level._box(Vector3(1.4,.2,1.4),Vector3(0,-.1,-1.8),null,true)
	var low = actor("floor_crawler",Vector3(0,.04,-1.8),"crawler")
	game.enemies = [low]
	game.state.weapon = 0
	for elevation in [-.4,.4]:
		floor.position.y = elevation-.1
		low.position.y = elevation+.04
		await physics_frame
		await physics_frame
		var support_query := PhysicsRayQueryParameters3D.create(low.global_position+Vector3.UP*.2,low.global_position-Vector3.UP*.2,1)
		var support: Dictionary = game.level.get_world_3d().direct_space_state.intersect_ray(support_query)
		expect(support.get("collider") == floor and absf(support.get("position",Vector3.INF).y-elevation) < .00001 and support.get("normal",Vector3.ZERO).y > .99,"Offset crawler has an actual native floor at "+str(elevation))
		var solution := tool_solution()
		contact_is(solution,low,2.7,"Offset crawler "+str(elevation))
		hp = low.hp
		game.player.cooldown = 0
		expect(game.player.fire() and low.hp == hp-28,"Real tool damages offset-floor crawler exactly once")
		low.hp = hp
	floor.collision_layer = 0
	player_floor.collision_layer = 0
	low.position = Vector3(0,.04,-2.4)
	for yaw in [12.7,13.0]:
		low.position = Vector3(sin(deg_to_rad(yaw))*2.4,.04,-cos(deg_to_rad(yaw))*2.4)
		await physics_frame
		await physics_frame
		var solution := tool_solution()
		if yaw < 12.8: contact_is(solution,low,2.7,"Inside horizontal cone")
		else: expect(solution.actor_id.is_empty(),"Outside narrow horizontal cone cannot acquire crawler")
		hp = low.hp
		game.player.cooldown = 0
		expect(game.player.fire() and low.hp == hp-(28 if yaw < 12.8 else 0),"Real tool obeys horizontal cone boundary")
		low.hp = hp
	# Both targets remain physically reachable; only the vertical correction bound differs.
	for elevation in [0.0,-.2]:
		low.position = Vector3(0,elevation,-.8)
		await physics_frame
		await physics_frame
		var reach_query := PhysicsRayQueryParameters3D.create(game.player.camera.global_position,low.get_child(0).global_position,1|4)
		reach_query.exclude = [game.player.get_rid()]
		var reachable: Dictionary = game.level.get_world_3d().direct_space_state.intersect_ray(reach_query)
		expect(reachable.get("collider") == low and game.player.camera.global_position.distance_to(reachable.get("position",Vector3.INF)) < 2.7,"SETUP rejected/accepted vertical capsules both have a real reachable native contact")
		var solution := tool_solution()
		if elevation == 0: contact_is(solution,low,2.7,"Inside vertical correction bound")
		else: expect(solution.actor_id.is_empty(),"Reachable low capsule outside vertical correction bound is not acquired")
		hp = low.hp
		game.player.cooldown = 0
		expect(game.player.fire() and low.hp == hp-(28 if elevation == 0 else 0),"Real tool obeys bounded vertical correction")
		low.hp = hp
	# Centre lies beyond 2.7m, while the real capsule's front surface is still reachable.
	low.position = Vector3(0,.04,-2.9)
	await physics_frame
	await physics_frame
	var surface := tool_solution()
	expect(surface.origin.distance_to(low.get_child(0).global_position) > 2.7,"SETUP capsule centre is outside tool reach")
	contact_is(surface,low,2.7,"Surface, not centre, reach")
	hp = low.hp
	game.player.cooldown = 0
	expect(game.player.fire() and low.hp == hp-28,"Reachable front surface accepts one real tool hit despite distant centre")
	low.collision_layer = 0
	game.state.weapon = 1
	game.state.ammo[1] = 180
	for role in ["crawler","brute","caster"]:
		var body = actor("role_"+role,Vector3(0,1.04 if role == "caster" else .04,-8),role)
		game.enemies = [body]
		var shape_node: CollisionShape3D = body.get_child(0)
		var capsule: CapsuleShape3D = shape_node.shape
		expect(is_equal_approx(capsule.radius,game.Enemy.capsule_radius(role)) and is_equal_approx(capsule.height,game.Enemy.capsule_height(role)),"Actual "+role+" capsule is unchanged")
		if role == "caster": expect(body.motion_mode == CharacterBody3D.MOTION_MODE_FLOATING,"Actual caster keeps its native floating body mode")
		game.player.camera.look_at(shape_node.global_position+Vector3.UP*(capsule.height*.5+.2),Vector3.UP)
		await physics_frame
		await physics_frame
		var solution := solve()
		expect(solution.assisted,"Above-body manual miss acquires actual "+role+" role")
		contact_is(solution,body,40.0,"Capsule role "+role)
		hp = body.hp
		game.player.cooldown = 0
		expect(game.player.fire() and body.hp == hp-22,"Resolved "+role+" first contact receives one actual rivet")
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
	game.enemies = [body]
	var cover = game.level._box(Vector3(.25,1.65,.1),Vector3(.5,.825,-5),null,true)
	await physics_frame
	await physics_frame
	var origin: Vector3 = game.player.camera.global_position
	# Independent world-space rays prove the chosen cover actually hides two body points.
	for height in [1.59,1.39,2.4]:
		var query := PhysicsRayQueryParameters3D.create(origin,Vector3(1,height,-10),1|4)
		query.exclude = [game.player.get_rid()]
		var hit: Dictionary = game.level.get_world_3d().direct_space_state.intersect_ray(query)
		expect(hit.get("collider") == (body if height > 2 else cover),"SETUP actual partial cover blocks lower points but not upper capsule ray")
	var solution := solve()
	contact_is(solution,body,40.0,"Visible upper-body point survives covered preferred points")
	var hp: int = body.hp
	game.player.cooldown = 0
	expect(game.player.fire() and body.hp == hp-22,"Native rivet damages actual acquired partial-cover contact")
	body.collision_layer = 0
	cover.collision_layer = 0

func check_occluded_fallback() -> void:
	var rear = actor("occluded_rear",Vector3(0,.04,-8),"crawler")
	var front = actor("dormant_obstruction",Vector3(0,.04,-5),"crawler")
	front.active = false
	game.enemies = [rear,front]
	await physics_frame
	await physics_frame
	var origin: Vector3 = game.player.camera.global_position
	var manual := PhysicsRayQueryParameters3D.create(origin,origin+Vector3.FORWARD*40,1|4)
	manual.exclude = [game.player.get_rid()]
	var space: PhysicsDirectSpaceState3D = game.level.get_world_3d().direct_space_state
	expect(space.intersect_ray(manual).is_empty(),"SETUP manual ray actually misses both low capsules")
	var blocked := PhysicsRayQueryParameters3D.create(origin,rear.get_child(0).global_position+Vector3.UP*.13,1|4)
	blocked.exclude = [game.player.get_rid()]
	expect(space.intersect_ray(blocked).get("collider") == front,"SETUP assisted rear ray actually meets intervening native actor")
	var solution := solve()
	expect(solution.actor_id.is_empty() and solution.contact.is_empty(),"Occluded automatic fallback cannot advertise rear actor over intervening dormant body")
	var rear_hp: int = rear.hp
	var front_hp: int = front.hp
	game.player.cooldown = 0
	expect(game.player.fire() and rear.hp == rear_hp and front.hp == front_hp,"No hidden redirection damages obstructed actor or dormant blocker on manual miss")
	front.collision_layer = 0
	rear.collision_layer = 0
