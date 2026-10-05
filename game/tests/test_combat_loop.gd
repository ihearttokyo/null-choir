extends SceneTree

const Enemy = preload("res://scripts/enemy.gd")
const Player = preload("res://scripts/player.gd")
const Level = preload("res://scripts/level.gd")
const Projectile = preload("res://scripts/projectile.gd")
const STEP = 1.0/60.0
const WINDUPS = {"worker":0.45,"crawler":0.25,"caster":0.70}

class TestGame extends Node3D:
	var state = preload("res://scripts/campaign.gd").new()
	var playing = false
	var level
	var player
	var events: Dictionary = {}
	var activations: Array = []
	func hurt_player(amount: int) -> void: state.damage(amount)
	func enemy_event(_actor, event: String) -> void:
		events[event] = events.get(event,0)+1
	func activate_encounter(id: String) -> void:
		activations.append(id)
		if not "encounter:"+id in state.removed: state.removed.append("encounter:"+id)
		for child in level.get_children():
			if child.get_script() == Enemy and child.encounter_id == id:
				child.active = true
				child.alerted = true

var game
var actor
var base: Vector3

func _initialize() -> void: call_deferred("run")

func run() -> void:
	for check in [check_windups,check_committed_aim,check_counter,check_blocking,check_pause,check_lifetime,check_dormancy]:
		if not await check.call(): return
	game.free()
	print("PASS native combat loop: anticipation, committed aim, counters/refractory, cover, pause, lifetime and dormant vulnerability")
	quit()

func fixture(kind: String, distance: float = 12.0, encounter: String = "") -> bool:
	if is_instance_valid(game): game.free()
	paused = false
	game = TestGame.new()
	root.add_child(game)
	game.state.new_campaign(1)
	game.level = Level.new()
	game.level.process_mode = Node.PROCESS_MODE_PAUSABLE
	game.add_child(game.level)
	if not expect(game.level.layout.load_level(0),"SETUP: real Intake layout must load"): return false
	base = game.level.layout.world_position(game.level.layout.data.spawn)
	game.level._box(Vector3(60,1,60),base+Vector3(0,-0.5,-12),game.level._material(Color.WHITE),true)
	game.player = Player.new()
	game.level.add_child(game.player)
	game.player.configure(game)
	game.player.set_physics_process(false)
	game.player.set_process_unhandled_input(false)
	game.player.position = base+Vector3(0,0.04,-distance)
	actor = Enemy.new()
	game.level.add_child(actor)
	actor.configure(game,{"id":"loop_"+kind,"kind":kind,"cell":game.level.layout.data.spawn,"yaw":0,"encounter":encounter})
	actor.set_physics_process(false)
	await settle()
	if not expect(actor.sprite.texture != null,"SETUP: real enemy atlas must load"): return false
	var query = PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*1.4,game.player.global_position+Vector3.UP,1|2|4)
	query.exclude = [actor.get_rid()]
	var hit = actor.get_world_3d().direct_space_state.intersect_ray(query)
	if not expect(not hit.is_empty() and hit.collider == game.player,"SETUP: unobstructed attack ray must intersect the real player capsule"): return false
	game.playing = true
	return true

func settle() -> void:
	await physics_frame
	await physics_frame

func flights() -> Array:
	return game.level.get_children().filter(func(node): return node.get_script() == Projectile and not node.is_queued_for_deletion())

func advance(frames: int, stream_damage: bool = false) -> void:
	for frame in range(frames):
		await physics_frame
		actor._physics_process(STEP)
		# Freeze flight only so launch timing and subsequent swept travel are checked separately.
		for flight in flights(): flight.set_physics_process(false)
		if stream_damage and frame%6 == 0: actor.take_damage(1,game.player)

func check_windups() -> bool:
	for kind in ["worker","crawler","caster"]:
		if not await fixture(kind,1.65 if kind == "crawler" else 12.0): return false
		actor._physics_process(0)
		for flight in flights(): flight.set_physics_process(false)
		# This behavioral check deliberately precedes every new-state property access.
		if not expect(game.state.health == 100 and flights().is_empty(),kind.capitalize()+" must enter windup without immediate damage or projectile launch"): return false
		if not expect(is_equal_approx(actor.telegraph_time,WINDUPS[kind]),kind+" must expose its authored windup duration"): return false
		if not expect(game.events.get("windup",0) == 1,kind+" emits one windup event"): return false
		await advance(int(round(WINDUPS[kind]/STEP))-1)
		if not expect(game.state.health == 100 and flights().is_empty() and actor.telegraph_time > 0,kind+" cannot release before anticipation expires"): return false
		await advance(3)
		if not expect(game.events.get("attack",0) == 1 and actor.telegraph_time == 0,kind+" releases exactly once after anticipation"): return false
		var recovered = actor.recovery_time > 0
		if kind == "crawler":
			for frame in range(15):
				await advance(1)
				recovered = recovered or actor.recovery_time > 0
		if not expect(recovered,kind+" exposes recovery after its attack"): return false
		if kind == "caster":
			if not expect(flights().size() == 1 and game.state.health == 100,"Caster releases one flight, never instantaneous damage"): return false
			var flight = flights()[0]
			flight._physics_process(2.0)
			if not expect(game.state.health == 86 and flight.is_queued_for_deletion(),"Stationary player takes existing normal-difficulty caster damage on swept contact"): return false
		else:
			if not expect(game.state.health == (88 if kind == "crawler" else 90),kind+" can hit a stationary exposed player after its tell"): return false
	return true

func check_committed_aim() -> bool:
	for kind in ["worker","caster"]:
		if not await fixture(kind): return false
		var committed_point = game.player.global_position+Vector3.UP
		actor._physics_process(0)
		game.player.position.x += 3.0
		await settle()
		await advance(int(round(WINDUPS[kind]/STEP))+2)
		if not expect(game.events.get("attack",0) == 1,kind+" must actually release its committed attack"): return false
		if kind == "caster":
			if not expect(flights().size() == 1,"Committed caster release creates one projectile"): return false
			var flight = flights()[0]
			if not expect(flight.velocity.normalized().dot((committed_point-flight.global_position).normalized()) > 0.999,"Caster aims toward the committed point, not the strafed player"): return false
			flight._physics_process(2.0)
		if not expect(game.state.health == 100,kind+" committed attack must miss a player who strafed clear during windup"): return false
	return true

func check_counter() -> bool:
	if not await fixture("worker"): return false
	actor._physics_process(0)
	await advance(6)
	actor.take_damage(1,game.player)
	if not expect(actor.telegraph_time == 0 and actor.stagger_time > 0 and game.events.get("stagger",0) == 1,"Damaging windup counter cancels the pending attack and staggers once"): return false
	var stagger = actor.stagger_time
	for pellet in range(6): actor.take_damage(1,game.player)
	if not expect(is_equal_approx(actor.stagger_time,stagger) and game.events.get("stagger",0) == 1,"Additional pellets cannot refresh stagger or repeat the counter event"): return false
	await advance(24) # Past the cancelled deadline, before any fresh .45-second windup can release.
	if not expect(game.state.health == 100 and game.events.get("attack",0) == 0,"Cancelled attack never releases at its old deadline"): return false
	await advance(144,true)
	if not expect(actor.hp > 0 and game.events.get("attack",0) > 0 and game.state.health < 100,"Refractory permits a surviving worker to attack through a sustained ten-hit-per-second damage stream"): return false
	return true

func check_blocking() -> bool:
	if not await fixture("worker"): return false
	actor._physics_process(0)
	var wall = game.level._box(Vector3(4,3,0.05),base+Vector3(0,1.5,-6),game.level._material(Color.WHITE),true)
	await settle()
	var query = PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*1.4,game.player.global_position+Vector3.UP,1)
	var hit = actor.get_world_3d().direct_space_state.intersect_ray(query)
	if not expect(not hit.is_empty() and hit.collider == wall,"SETUP: thin cover must block the real attack ray"): return false
	await advance(32)
	if not expect(game.state.health == 100,"Worker release must respect cover introduced during windup"): return false
	if not await fixture("crawler",1.65): return false
	actor._physics_process(0)
	wall = game.level._box(Vector3(60,3,0.05),base+Vector3(0,1.5,-0.825),game.level._material(Color.WHITE),true)
	await settle()
	await advance(50)
	if not expect(game.state.health == 100 and actor.position.z > wall.position.z+0.3,"Crawler rush and melee respect native wall collision"): return false
	if not await fixture("crawler",1.65): return false
	actor._physics_process(0)
	game.player.position.z -= 8.0
	await settle()
	await advance(50)
	if not expect(game.state.health == 100,"Crawler cannot apply stale melee damage after target retreats beyond rush reach"): return false
	if not await fixture("caster"): return false
	wall = game.level._box(Vector3(4,5,0.05),base+Vector3(0,2.5,-6),game.level._material(Color.WHITE),true)
	await settle()
	var flight = Projectile.new()
	game.level.add_child(flight)
	flight.configure(game,actor,actor.global_position+Vector3.UP*1.4,game.player.global_position+Vector3.UP)
	flight.set_physics_process(false)
	flight.velocity = flight.velocity.normalized()*3000
	flight._physics_process(0.02)
	if not expect(flight.is_queued_for_deletion() and game.state.health == 100 and absf(flight.position.z-wall.position.z) < 0.1,"Existing swept flight hits thin native cover without tunneling"): return false
	flight._physics_process(1.0)
	if not expect(game.state.health == 100,"Queued wall impact cannot later damage the player"): return false
	return true

func check_pause() -> bool:
	if not await fixture("worker"): return false
	actor._physics_process(0)
	await advance(6)
	var timers = [actor.telegraph_time,actor.stagger_time,actor.recovery_time,actor.attack_time]
	var location = actor.position
	game.playing = false
	paused = true
	actor.set_physics_process(true)
	actor._physics_process(0.5)
	await settle()
	if not expect(not actor.can_process() and actor.position == location and timers == [actor.telegraph_time,actor.stagger_time,actor.recovery_time,actor.attack_time],"Native pause freezes enemy position and all attack-state timers"): return false
	paused = false
	game.playing = true
	actor.set_physics_process(false)
	await advance(22)
	if not expect(game.state.health == 90 and game.events.get("attack",0) == 1,"Resume finishes the remaining windup once, without resetting or skipping it"): return false
	if not await fixture("caster"): return false
	actor._physics_process(0)
	await advance(44)
	if not expect(flights().size() == 1,"Pause fixture requires a real released projectile"): return false
	var flight = flights()[0]
	location = flight.position
	var lifetime = flight.lifetime
	game.playing = false
	paused = true
	flight.set_physics_process(true)
	flight._physics_process(0.5)
	await settle()
	if not expect(not flight.can_process() and flight.position == location and flight.lifetime == lifetime,"Native pause freezes projectile travel and lifetime"): return false
	flight.set_physics_process(false)
	paused = false
	game.playing = true
	flight._physics_process(0.1)
	return expect(flight.position != location and flight.lifetime < lifetime,"Resume restores finite projectile travel")

func check_lifetime() -> bool:
	if not await fixture("worker"): return false
	actor._physics_process(0)
	actor.take_damage(1000,game.player)
	actor.take_damage(1,game.player)
	actor._physics_process(1.0)
	if not expect(game.state.health == 100 and actor.telegraph_time == 0 and actor.collision_layer == 0 and game.events.get("death",0) == 1 and game.state.removed.count(actor.id) == 1,"Death cancels windup, disables collision and emits/removes once"): return false
	if not await fixture("worker"): return false
	var victim = Enemy.new()
	game.level.add_child(victim)
	victim.configure(game,{"id":"loop_victim","kind":"worker","cell":game.level.layout.data.spawn,"yaw":0})
	victim.set_physics_process(false)
	victim.position = base+Vector3(0,0.03,-10)
	game.player.position.x += 8.0
	actor.target = victim
	await settle()
	actor._physics_process(0)
	await advance(18)
	victim.free()
	await advance(15)
	if not expect(game.state.health == 100,"Freed target cannot transfer its nearly finished attack onto a new victim without a fresh tell"): return false
	if not await fixture("worker"): return false
	actor._physics_process(0)
	var flight = Projectile.new()
	game.level.add_child(flight)
	flight.configure(game,actor,actor.global_position+Vector3.UP*1.4,game.player.global_position+Vector3.UP)
	flight.set_physics_process(false)
	var old_level = game.level
	old_level.queue_free()
	game.level = Level.new()
	game.add_child(game.level)
	game.player = Player.new()
	game.level.add_child(game.player)
	game.player.configure(game)
	game.player.set_physics_process(false)
	game.player.set_process_unhandled_input(false)
	game.player.position = base+Vector3(0,0.04,-12)
	actor._physics_process(0.6)
	flight._physics_process(2.0)
	if not expect(game.state.health == 100 and game.events.get("attack",0) == 0 and flight.is_queued_for_deletion(),"Old-map enemy and projectile cannot damage the replacement player"): return false
	await process_frame
	await process_frame
	return expect(not is_instance_valid(old_level) and not is_instance_valid(actor) and not is_instance_valid(flight),"Scene teardown frees the old actor and its projectile")

func check_dormancy() -> bool:
	if not await fixture("worker",12.0,"test_nave"): return false
	if not expect(not actor.active and actor.encounter_id == "test_nave","Grouped enemy starts dormant before persistent activation"): return false
	actor._physics_process(0)
	await advance(36)
	if not expect(game.state.health == 100 and game.events.get("windup",0) == 0,"Sight alone cannot activate a dormant group"): return false
	var hp = actor.hp
	actor.take_damage(7,game.player)
	if not expect(actor.hp == hp-7 and actor.active and game.activations == ["test_nave"] and "encounter:test_nave" in game.state.removed,"Dormant enemy remains vulnerable and requests parent group activation"): return false
	actor._physics_process(0)
	await advance(30)
	return expect(game.state.health == 90 and game.events.get("attack",0) == 1,"Activated group uses the same real anticipation and attack path")

func expect(condition: bool, detail: String) -> bool:
	if not condition:
		push_error("Combat-loop contract: "+detail)
		paused = false
		if is_instance_valid(game): game.free()
		quit(1)
	return condition
