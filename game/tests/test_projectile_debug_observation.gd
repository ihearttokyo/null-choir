extends SceneTree

const Projectile = preload("res://scripts/projectile.gd")

class PlainGame extends "res://scripts/main.gd":
	var order: Array = []
	var hurts: Array = []
	var impacts: Array = []
	func _ready() -> void: set_process(false)
	func hurt_player(amount: int) -> void:
		order.append("hurt")
		hurts.append(amount)
		super.hurt_player(amount)
	func impact(point: Vector3) -> void:
		impacts.append(point)
		super.impact(point)

class ObservedGame extends PlainGame:
	var records: Array = []
	var action: String = ""
	var contact_was_queued: bool = false
	var contact_was_physics: bool = false
	var contact_before_hurt: bool = false
	var birth_visual_ready: bool = false
	func _debug_projectile_event(projectile: Node3D, event: String, data: Dictionary) -> void:
		order.append(event)
		records.append({"event":event,"data":data.duplicate(true)})
		if event == "configured_birth":
			if projectile.blast_damage > 0:
				var visuals = level.get_node_or_null("AmmoVisuals")
				birth_visual_ready = visuals != null and visuals.slots.any(func(slot): return slot.target != null and slot.target.get_ref() == projectile and slot.sprite.visible)
			else:
				birth_visual_ready = projectile.get_child_count() == 2 and projectile.get_child(0) is MeshInstance3D and projectile.get_child(1) is OmniLight3D
			return
		contact_was_queued = projectile.is_queued_for_deletion()
		contact_was_physics = Engine.is_in_physics_frame()
		contact_before_hurt = hurts.is_empty()
		match action:
			"pause": playing = false
			"replace_map":
				level = Node3D.new()
				add_child(level)
			"replace_player":
				player = CharacterBody3D.new()
				level.add_child(player)
			"reparent_player": player.reparent(self)
			"queue_map": level.queue_free()
			"queue_player": player.queue_free()
			"mutate_data":
				data.hit.position = Vector3(99,99,99)
				data.hit.collider = null
				data.hit.clear()
				data.clear()

var failures: int = 0

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func expect(condition: bool, detail: String) -> void:
	if condition: return
	failures += 1
	push_error(detail)

func arena(observed: bool, difficulty: int = 1):
	var game = ObservedGame.new() if observed else PlainGame.new()
	root.add_child(game)
	game.state.new_campaign(difficulty)
	game.state.armor = 30
	game.level = Node3D.new()
	game.add_child(game.level)
	game.playing = true
	game.player = game.Player.new()
	game.level.add_child(game.player)
	game.player.configure(game)
	game.player.set_physics_process(false)
	game.player.position = Vector3.ZERO
	return game

func source_body(game):
	var source = CharacterBody3D.new()
	source.collision_layer = 4
	source.collision_mask = 0
	game.level.add_child(source)
	source.position = Vector3(0,0,-8)
	return source

func launch(game, source, marrow_damage: int = 0):
	var projectile = Projectile.new()
	game.level.add_child(projectile)
	projectile.set_physics_process(false)
	projectile.configure(game,source,Vector3(0,1,-6),Vector3(0,1,0),marrow_damage)
	return projectile

# Attribution rejection tests use copies of a real native contact, never emit guessed events.
func pair_valid(birth: Dictionary, contact: Dictionary, used: bool = false) -> bool:
	if used or birth.is_empty() or contact.is_empty(): return false
	for field in ["projectile","source","map","player"]:
		if not birth.has(field) or not contact.has(field) or birth[field] != contact[field] or not is_instance_valid(contact[field]): return false
	if contact.source.is_queued_for_deletion() or contact.map.is_queued_for_deletion() or contact.player.is_queued_for_deletion(): return false
	if not contact.projectile.game.playing or contact.projectile.game.level != contact.map or contact.projectile.game.player != contact.player: return false
	if contact.projectile.get_parent() != contact.map or contact.source.get_parent() != contact.map or contact.player.get_parent() != contact.map: return false
	if not contact.projectile.is_queued_for_deletion() or birth.blast_damage != 0 or contact.blast_damage != 0: return false
	if contact.tick < birth.tick or not contact.has("hit") or contact.hit.get("collider") != contact.player: return false
	if not contact.ray_start.is_finite() or not contact.ray_end.is_finite() or not contact.hit.get("position",Vector3(INF,0,0)).is_finite(): return false
	return true

func dispose(game) -> void:
	var reference = weakref(game)
	game.free()
	await process_frame
	expect(reference.get_ref() == null,"Synthetic arena releases its owner")

func check_contact(action: String, difficulty: int = 1) -> Dictionary:
	var game = arena(true,difficulty)
	game.action = action
	var source = source_body(game)
	var projectile = launch(game,source)
	var birth: Dictionary = game.records[0].data if game.records.size() == 1 else {}
	expect(game.records.size() == 1 and game.records[0].event == "configured_birth","RED without instrumentation: one configured birth is emitted synchronously")
	expect(game.birth_visual_ready,"Birth follows actual configured sphere/light setup")
	if birth.is_empty():
		await dispose(game)
		return {}
	expect(birth.projectile == projectile and birth.source == source and birth.map == game.level and birth.player == game.player and birth.tick == Engine.get_physics_frames(),"Birth contains exact original native identities and tick")
	expect(birth.position == Vector3(0,1,-6) and birth.origin == birth.position and birth.destination == Vector3(0,1,0) and birth.velocity == Vector3(0,0,12) and birth.lifetime == 4.0 and birth.blast_damage == 0,"Birth reports actual configured fields without inferred attack identity")
	await physics_frame
	await physics_frame
	var ray_start: Vector3 = projectile.global_position
	var ray_end: Vector3 = ray_start+projectile.velocity*.7
	var query = PhysicsRayQueryParameters3D.create(ray_start,ray_end,1|2|4)
	query.exclude = [source.get_rid()]
	query.hit_from_inside = true
	var native_hit: Dictionary = game.level.get_world_3d().direct_space_state.intersect_ray(query)
	expect(not native_hit.is_empty() and native_hit.get("collider") == game.player,"SETUP: independent native ray hits the original actual player capsule")
	if native_hit.is_empty() or native_hit.get("collider") != game.player:
		await dispose(game)
		return {}
	if action == "queued_source": source.queue_free()
	projectile._physics_process(.7)
	expect(game.records.size() == 2 and game.records[1].event == "queued_player_contact","RED without instrumentation: native contact emits exactly one second event")
	if game.records.size() != 2:
		await dispose(game)
		return {}
	var contact: Dictionary = game.records[1].data
	expect(game.contact_was_queued and game.contact_was_physics and game.contact_before_hurt,"Contact callback is native physics, after queue_free and before actual hurt")
	expect(contact.projectile == projectile and contact.source == source and contact.map == birth.map and contact.player == birth.player and contact.tick == Engine.get_physics_frames(),"Contact retains exact birth projectile/source/map/player and current physics tick")
	expect(contact.ray_start == ray_start and contact.ray_end == ray_end and contact.hit == native_hit and contact.position == native_hit.position,"Contact reports pre-move ray start, unchanged native end and exact full native hit")
	expect(pair_valid(birth,contact) == (action not in ["queued_source","pause","replace_map","replace_player","reparent_player","queue_map","queue_player"]),"Exact pair rejects queued or replaced source/map/player and pause instead of guessing queued14 damage")
	var cancelled: bool = action in ["pause","replace_map","replace_player","reparent_player","queue_map","queue_player"]
	var expected_amount: int = [9,14,19][difficulty]
	expect(game.hurts == ([] if cancelled else [expected_amount]),"Reentrant map/player/playing changes cancel stale damage; copy mutation and queued source retain production damage")
	expect(game.order == (["configured_birth","queued_player_contact"] if cancelled else ["configured_birth","queued_player_contact","hurt"]),"Exact birth/contact/hurt order contains no duplicate credit")
	if not cancelled:
		expect(game.impacts == [native_hit.position] and projectile.position == native_hit.position,"Copied observation mutation cannot change the production hit or impact point")
	if action == "":
		expect(not pair_valid({},contact) and not pair_valid(birth,contact,true),"Missing birth and duplicate credit are rejected")
		for field in ["projectile","source","map","player"]:
			var wrong: Dictionary = contact.duplicate(true)
			wrong[field] = game
			expect(not pair_valid(birth,wrong),"Wrong original "+field+" cannot receive attribution")
		var wrong: Dictionary = contact.duplicate(true)
		wrong.hit.collider = source
		expect(not pair_valid(birth,wrong),"Wrong native collider is rejected")
		for field in ["ray_start","ray_end"]:
			wrong = contact.duplicate(true)
			wrong[field] = Vector3(NAN,0,0)
			expect(not pair_valid(birth,wrong),"Nonfinite "+field+" is rejected")
		wrong = contact.duplicate(true)
		wrong.hit.position = Vector3(INF,0,0)
		expect(not pair_valid(birth,wrong),"Nonfinite native hit is rejected")
	var result: Dictionary = {"hurts":game.hurts.duplicate(),"health":game.state.health,"armor":game.state.armor,"impacts":game.impacts.duplicate(),"position":projectile.position,"lifetime":projectile.lifetime,"queued":projectile.is_queued_for_deletion()}
	projectile._physics_process(.7)
	expect(game.records.size() == 2 and game.hurts.size() == (0 if cancelled else 1),"Repeated call on queued projectile emits no duplicate contact/damage")
	await dispose(game)
	return result

func run() -> void:
	expect(OS.is_debug_build(),"This fixture requires a source debug engine; release-template absence is a separate parent check")
	if not OS.is_debug_build():
		quit(1)
		return
	for difficulty in range(3):
		var observed: Dictionary = await check_contact("",difficulty)
		var game = arena(false,difficulty)
		var source = source_body(game)
		var projectile = launch(game,source)
		expect(not game.has_method("_debug_projectile_event"),"No-observer parity owner has no reserved method")
		await physics_frame
		await physics_frame
		projectile._physics_process(.7)
		var plain: Dictionary = {"hurts":game.hurts.duplicate(),"health":game.state.health,"armor":game.state.armor,"impacts":game.impacts.duplicate(),"position":projectile.position,"lifetime":projectile.lifetime,"queued":projectile.is_queued_for_deletion()}
		expect(plain == observed,"Observed/no-observer exact damage, armor, impact, position, lifetime and retirement parity at all difficulties")
		expect(not plain.hurts.is_empty() and [plain.hurts[0],plain.health,plain.armor] == [[9,94,27],[14,90,26],[19,87,24]][difficulty],"Frozen original difficulty/armor damage remains unchanged")
		await dispose(game)
	for action in ["pause","replace_map","replace_player","reparent_player","queue_map","queue_player","mutate_data","queued_source"]:
		await check_contact(action)
	var game = arena(true)
	var source = source_body(game)
	var marrow = launch(game,source,110)
	expect(game.records.size() == 1 and game.records[0].event == "configured_birth" and game.birth_visual_ready,"Marrow birth occurs after actual pooled marrow visual setup, not before the former early return")
	if game.records.size() == 1:
		expect(game.records[0].data.velocity == Vector3(0,0,24) and game.records[0].data.blast_damage == 110 and game.records[0].data.projectile == marrow,"Marrow birth retains actual speed, damage and identity")
	await dispose(game)
	game = arena(true)
	source = source_body(game)
	var paused_shot = launch(game,source)
	game.playing = false
	await physics_frame
	await physics_frame
	paused_shot._physics_process(.7)
	expect(game.records.size() == 1 and game.hurts.is_empty() and paused_shot.position == Vector3(0,1,-6) and paused_shot.lifetime == 4.0 and not paused_shot.is_queued_for_deletion(),"Already paused shot emits no contact and preserves position/lifetime")
	await dispose(game)
	if failures == 0: print("PASS source-debug projectile observation: manually stepped synthetic native collision arena; not earned campaign or packed-app attribution")
	quit(0 if failures == 0 else 1)
