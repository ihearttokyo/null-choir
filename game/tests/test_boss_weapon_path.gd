extends SceneTree

const Enemy = preload("res://scripts/enemy.gd")
const Player = preload("res://scripts/player.gd")
const Level = preload("res://scripts/level.gd")
const Projectile = preload("res://scripts/projectile.gd")
const STEP = 1.0/60.0

class TestGame extends Node3D:
	var state = preload("res://scripts/campaign.gd").new()
	var settings = {"auto_aim":false,"head_bob":false,"camera_shake":false,"sensitivity":1.0,"invert_y":false}
	var playing = false
	var level
	var player
	var enemies: Array = []
	var deaths = 0
	var shots = 0
	func shot(_weapon: int) -> void: shots += 1
	func hurt_player(amount: int) -> void: state.damage(amount)
	func enemy_event(actor, event: String) -> void:
		if playing and actor._current_map() and actor.active and event == "death": deaths += 1

var game
var actor
var master_muted: bool

func _initialize() -> void: call_deferred("run")

func run() -> void:
	master_muted = AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0,true)
	preload("res://scripts/preferences.gd").new().apply_bindings()
	for index in [4,7]:
		for weapon in range(Player.WEAPONS.size()):
			if not await check_path(index,weapon): return
	AudioServer.set_bus_mute(0,master_muted)
	print("PASS controlled stationary native boss fixture: both bosses/all six weapons, full HP, real fire/cooldown/ammo/collision, once-only death and cleanup. Not active-fight/survival/campaign/app/graphics acceptance.")
	quit()

func check_path(index: int, weapon: int) -> bool:
	seed(12000+index*10+weapon)
	game = TestGame.new()
	root.add_child(game)
	game.state.new_campaign(1)
	game.state.level_index = index
	game.state.owned_weapons = [0,1,2,3,4,5]
	game.state.ammo = Player.WEAPONS.map(func(item): return item.max_ammo)
	game.state.weapon = weapon
	game.level = Level.new()
	game.add_child(game.level)
	if not expect(game.level.layout.load_level(index),"SETUP: actual boss layout loads"): return false
	var kind: String = "nursery_warden" if index == 4 else "choir_avatar"
	var specs: Array = game.level.layout.data.enemies.filter(func(spec): return spec.kind == kind)
	if not expect(specs.size() == 1,"SETUP: one actual authored boss"): return false
	var base: Vector3 = game.level.layout.world_position(specs[0].cell)
	# Controlled flat native floor, not an assertion about the authored arena route.
	game.level._box(Vector3(30,1,30),base-Vector3.UP*0.5,null,true)
	game.player = Player.new()
	game.level.add_child(game.player)
	game.player.configure(game)
	game.player.set_physics_process(false)
	game.player.set_process_unhandled_input(false)
	game.player.position = base+Vector3(0,0.04,6.0 if weapon == 4 else 2.0)
	actor = Enemy.new()
	game.level.add_child(actor)
	actor.configure(game,specs[0])
	actor.active = true
	actor.set_physics_process(false) # Stationary target; no AI/survival claim.
	game.enemies = [actor]
	await settle()
	game.playing = true
	for frame in range(8): game.player._physics_process(STEP)
	await settle()
	var collider: CollisionShape3D = actor.get_child(0)
	var shape = PhysicsShapeQueryParameters3D.new()
	shape.shape = collider.shape
	shape.transform = collider.global_transform
	shape.collision_mask = 1|2|4
	shape.exclude = [actor.get_rid()]
	var space = actor.get_world_3d().direct_space_state
	if not expect(space.intersect_shape(shape,8).is_empty() and game.player.is_on_floor(),"SETUP: real boss capsule is clear and player stands on native floor"): return false
	if not expect(actor.sprite.texture != null and actor.hp == Enemy.health_cap(kind,1) and actor.max_hp == actor.hp and actor._current_map() and game.player._current_map(),"SETUP: actual atlas/full normal HP/current-level ownership"): return false
	var damage: int = Player.WEAPONS[weapon].damage*(7 if weapon == 2 else 1)
	var limit: int = ceili(float(actor.hp)/damage)
	var spent: int = 0 if weapon == 0 else 1
	var initial_ammo: Array = game.state.ammo.duplicate()
	for shot in range(limit):
		game.player.camera.look_at(collider.global_position,Vector3.UP)
		var origin: Vector3 = game.player.camera.global_position
		var ray = PhysicsRayQueryParameters3D.create(origin,origin-game.player.camera.global_basis.z*Player.WEAPONS[weapon].range,1|4)
		if not expect(space.intersect_ray(ray).get("collider") == actor,"SETUP: weapon range ray intersects actual boss capsule without cover"): return false
		var hp: int = actor.hp
		var ammo: Array = game.state.ammo.duplicate()
		if not expect(game.player.fire() and game.state.ammo[weapon] == ammo[weapon]-spent and game.shots == shot+1,"Successful real fire spends exactly one ranged/zero melee round"): return false
		var after: Array = game.state.ammo.duplicate()
		if not expect(not game.player.fire() and game.state.ammo == after and game.shots == shot+1,"Immediate cooldown refusal spends nothing and emits no shot"): return false
		if weapon == 4:
			var flights: Array = game.level.get_children().filter(func(node): return node.get_script() == Projectile)
			if not expect(flights.size() == 1 and actor.hp == hp,"Launcher creates one real flight, not immediate damage"): return false
			var flight = flights[0]
			flight.set_physics_process(false)
			if not expect(flight._current_map() and flight.shooter == game.player and flight.blast_damage == damage,"Launcher belongs to current map and actual shooter"): return false
			for frame in range(60):
				if flight.is_queued_for_deletion(): break
				flight._physics_process(STEP)
			if not expect(flight.is_queued_for_deletion(),"Bounded native swept flight must contact capsule"): return false
			flight._physics_process(1.0) # A queued impact must not apply a second blast.
		if not expect(actor.hp == maxi(0,hp-damage) and game.state.health == 100,"Exact capsule damage per shot (disruptor once, scatter seven); launcher staging avoids self-blast"): return false
		var expected: Array = initial_ammo.duplicate()
		expected[weapon] -= (shot+1)*spent
		if not expect(game.state.ammo == expected,"Other weapon pools stay unchanged; capacity inventory is never refilled"): return false
		for frame in range(ceili(Player.WEAPONS[weapon].interval/STEP)+1): game.player._physics_process(STEP)
		await settle()
	if not expect(actor.hp == 0 and actor.collision_layer == 0 and actor.collision_mask == 0 and game.deaths == 1 and game.state.removed == [actor.id],"Full HP defeat disables collision and persists/emits death exactly once"): return false
	actor._physics_process(STEP)
	var postmortem_ammo: Array = game.state.ammo.duplicate()
	postmortem_ammo[weapon] -= spent
	if not expect(game.player.fire() and game.state.ammo == postmortem_ammo and game.shots == limit+1,"Real postmortem shot obeys ready cooldown and exact ammo spend"): return false
	for flight in game.level.get_children().filter(func(node): return node.get_script() == Projectile):
		flight.set_physics_process(false)
		for frame in range(241):
			if flight.is_queued_for_deletion(): break
			flight._physics_process(STEP)
		if not expect(flight.is_queued_for_deletion(),"Postmortem flight has bounded native lifetime"): return false
	await settle()
	if not expect(actor.hp == 0 and game.deaths == 1 and game.state.removed == [actor.id] and game.state.health == 100,"Postmortem native shot/processing cannot duplicate death or removal"): return false
	print("CASE kind=",kind," weapon=",weapon," defeat_shots=",limit)
	var refs = [weakref(game),weakref(game.level),weakref(game.player),weakref(actor)]
	game.free()
	game = null
	return expect(refs.all(func(ref): return ref.get_ref() == null),"Fixture teardown frees game, level, player and boss")

func settle() -> void:
	await physics_frame
	await physics_frame

func expect(condition: bool, detail: String) -> bool:
	if not condition:
		push_error("Boss-weapon-path contract: "+detail)
		if is_instance_valid(game): game.free()
		AudioServer.set_bus_mute(0,master_muted)
		quit(1)
	return condition
