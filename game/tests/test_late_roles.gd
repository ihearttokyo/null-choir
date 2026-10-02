extends SceneTree

const Projectile = preload("res://scripts/projectile.gd")
const STEP = 1.0/60.0
const CELL = [30.5,9.5]
const ROLES = ["brute","guardian","summoner","nursery_warden","choir_avatar"]
const SCALES = {"brute":4.4,"guardian":4.7,"summoner":5.6,"nursery_warden":7.3,"choir_avatar":7.6}
const MIN_TELLS = {"brute":0.65,"guardian":0.65,"summoner":1.0,"nursery_warden":0.8,"choir_avatar":0.8}

# Observe an existing callback; AI, damage, collision and scene lifetime stay real.
class ObservedGame extends "res://scripts/main.gd":
	var events: Dictionary = {}
	func enemy_event(actor, event: String) -> void:
		var key = actor.id+":"+event
		events[key] = events.get(key,0)+1
		super.enemy_event(actor,event)

var game
var actor
var base: Vector3
var serial: int = 0
var test_prefix = "user://test_late_roles_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func run() -> void:
	seed(41003)
	game = ObservedGame.new()
	game.settings_path = test_prefix+"_preferences.json"
	game.progress_path = test_prefix+"_campaign.json"
	game.preferences.values.music_volume = 0.0
	game.preferences.values.effects_volume = 0.0
	root.add_child(game)
	game.set_process(false)
	game.set_process_unhandled_input(false)
	# First RED is real missing charge behavior, before scale/HP or new phase fields.
	if not await check_brute():
		await finish(1)
		return
	if "--red-only" in OS.get_cmdline_user_args():
		print("PASS late-role brute RED contract now GREEN")
		await finish(0)
		return
	for check in [check_guardian,check_counters,check_summoner,check_bosses,check_lifetime,check_old_roles]:
		if not await check.call():
			await finish(1)
			return
	print("PASS native late roles: committed charge, armor opening, refractory, bounded clear-floor adds, two boss patterns/phases/resources/retry, sprite origins, pause/death/stale-map and old roles")
	await finish(0)

func freeze_world() -> void:
	game.set_process(false)
	game.player.set_physics_process(false)
	game.player.set_process_unhandled_input(false)
	for enemy in game.enemies:
		if is_instance_valid(enemy): enemy.set_physics_process(false)
	game.music.stop()
	game.effects.stop()

func arena(kind: String, distance: float = 10.0, difficulty: int = 1) -> bool:
	Input.action_release("fire")
	game.show_title()
	paused = false
	await process_frame
	await process_frame
	game.state.new_campaign(difficulty)
	game.state.level_index = 4
	game.start_level()
	freeze_world()
	# Remove only this fixture's authored guards, not world geometry or production logic.
	for guard in game.enemies: guard.queue_free()
	game.enemies.clear()
	await process_frame
	await settle()
	base = game.level.layout.world_position(CELL)
	game.player.position = base+Vector3(0,0.04,-distance)
	game.settings.auto_aim = false
	game.settings.head_bob = false
	game.settings.camera_shake = false
	game.state.health = 200
	game.state.armor = 0
	game.events.clear()
	actor = spawn(kind,base)
	await settle()
	if not expect(actor.sprite.texture != null,"SETUP: installed "+kind+" atlas must load"): return false
	var floor_ray = PhysicsRayQueryParameters3D.create(base+Vector3.UP*2,base-Vector3.UP*2,1)
	var floor_hit = game.level.get_world_3d().direct_space_state.intersect_ray(floor_ray)
	if not expect(not floor_hit.is_empty() and absf(floor_hit.position.y-base.y) < 0.003,"SETUP: use the actual Nursery triangulated floor"): return false
	var sight = PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP,game.player.global_position+Vector3.UP,1)
	if not expect(game.level.get_world_3d().direct_space_state.intersect_ray(sight).is_empty(),"SETUP: Nursery ten-metre sightline must be clear"): return false
	game.playing = true
	return true

func spawn(kind: String, location: Vector3, identity: String = ""):
	serial += 1
	var enemy = game.Enemy.new()
	game.level.add_child(enemy)
	enemy.configure(game,{"id":identity if not identity.is_empty() else "late_role_"+kind+"_"+str(serial),"kind":kind,"cell":CELL,"yaw":0})
	enemy.position.x = location.x
	enemy.position.z = location.z
	enemy.set_physics_process(false)
	game.enemies.append(enemy)
	return enemy

func settle() -> void:
	await physics_frame
	await physics_frame

func flights() -> Array:
	return game.level.get_children().filter(func(node): return node.get_script() == Projectile and not node.is_queued_for_deletion())

func adds() -> Array:
	return game.enemies.filter(func(node): return is_instance_valid(node) and not node.is_queued_for_deletion() and node._current_map() and node.kind == "crawler" and node.hp > 0)

func events(event: String) -> int:
	return game.events.get(actor.id+":"+event,0)

func advance(frames: int, pressure: bool = false, peers: Array = []) -> void:
	for frame in range(frames):
		await physics_frame
		actor._physics_process(STEP)
		for peer in peers: peer._physics_process(STEP)
		# Separate release timing from swept flight; adds remain real vulnerable actors.
		for flight in flights(): flight.set_physics_process(false)
		for enemy in game.enemies:
			if is_instance_valid(enemy): enemy.set_physics_process(false)
		if pressure and frame%6 == 0: actor.take_damage(1,game.player)

func expect(condition: bool, detail: String) -> bool:
	if not condition: push_error("Late-role contract: "+detail)
	return condition

func check_brute() -> bool:
	if not await arena("brute"): return false
	await advance(1)
	if not expect(actor.telegraph_time >= MIN_TELLS.brute and actor.telegraph_time <= 1.5 and events("windup") == 1,"INTENDED RED: real brute at a clear 10m sightline must begin a visible ram-crouch charge windup, not generic chase forever"): return false
	if not expect(game.state.health == 200 and flights().is_empty(),"Brute tell cannot deal immediate damage or launch a ranged substitute"): return false
	actor._physics_process(0)
	if not expect(int(actor.sprite.frame/8) == 3,"Brute tell uses the actual directional attack row"): return false
	game.player.position.x += 4
	await settle()
	await advance(int(ceil(actor.telegraph_time/STEP))+2)
	if not expect(events("attack") == 1 and actor._rush_time > 0,"Brute commits one actual straight charge after its tell"): return false
	for frame in range(90):
		await advance(1)
		if actor._rush_time == 0: break
	if not expect(actor.position.distance_to(base) > 3 and absf(actor.position.x-base.x) < 0.1 and game.state.health == 200,"Committed brute travels forward and misses a player who strafed clear; no homing or stale melee"): return false
	if not expect(actor._rush_time == 0 and actor.recovery_time > 0,"Charge ends in finite visible recovery"): return false
	await advance(300)
	if not expect(events("windup") >= 2,"Brute eventually leaves recovery and can give a fresh tell"): return false
	if not await arena("brute",2.2): return false
	actor._physics_process(0)
	await advance(int(ceil(actor.telegraph_time/STEP))+18)
	var health: int = game.state.health
	if not expect(health < 200 and health > 0 and actor._rush_hit,"Exposed real player capsule takes one charge hit"): return false
	await advance(12)
	if not expect(game.state.health == health and events("attack") == 1,"A single charge cannot damage the same capsule twice"): return false
	if not await arena("brute"): return false
	actor._physics_process(0)
	var wall = game.level._box(Vector3(14,7,0.1),base+Vector3(0,3.5,-5),game.level._material(Color.WHITE),true)
	await settle()
	await advance(int(ceil(actor.telegraph_time/STEP))+70)
	return expect(game.state.health == 200 and actor.position.z > wall.position.z+0.3 and actor._rush_time == 0,"Brute charge stops on native cover and cannot hit through it")

func check_guardian() -> bool:
	if not await arena("guardian"): return false
	var hp: int = actor.hp
	actor.take_damage(40,game.player)
	var frontal: int = hp-actor.hp
	if not expect(frontal > 0 and frontal <= 20,"Closed frontal plates reduce damage, never grant invisible immunity"): return false
	game.player.position = base+Vector3(0,0.04,10)
	hp = actor.hp
	actor.take_damage(40,game.player)
	if not expect(hp-actor.hp == 40,"Rear pressure seam rewards flanking with full damage"): return false
	game.player.position = base+Vector3(10,0.04,0)
	hp = actor.hp
	actor.take_damage(40,game.player)
	if not expect(hp-actor.hp == 40,"Side flank lies outside the frontal plate cone"): return false
	game.player.position = base+Vector3(0,0.04,-10)
	actor._physics_process(0)
	if not expect(actor.telegraph_time >= MIN_TELLS.guardian,"Guardian opens its plates in a readable attack tell"): return false
	actor._physics_process(0)
	hp = actor.hp
	actor.take_damage(40,game.player)
	return expect(int(actor.sprite.frame/8) == 3 and hp-actor.hp == 40 and actor.telegraph_time == 0 and actor.stagger_time > 0,"Visible opening exposes the core to full frontal damage and the existing interrupt counter")

func check_counters() -> bool:
	for kind in ROLES:
		if not await arena(kind): return false
		actor._physics_process(0)
		if not expect(actor.telegraph_time >= MIN_TELLS[kind],kind+" begins its full tell before counter stress"): return false
		actor.take_damage(1,game.player)
		var lock: float = actor._counter_time
		var stagger: float = actor.stagger_time
		if not expect(actor.telegraph_time == 0 and stagger > 0 and events("stagger") == 1,kind+" counter cancels the pending release"): return false
		for pellet in range(6): actor.take_damage(1,game.player)
		if not expect(actor._counter_time == lock and actor.stagger_time == stagger and events("stagger") == 1,kind+" extra pellets cannot refresh lock or stagger"): return false
		await advance(20)
		if not expect(events("attack") == 0,kind+" cancelled attack cannot release at its old deadline"): return false
		await advance(240,true)
		if not expect(actor.hp > 0 and events("attack") > 0,kind+" survives light pressure and attacks through the nonrefreshing refractory lock"): return false
	return true

func clear_add(add) -> bool:
	var collider: CollisionShape3D = add.get_child(0)
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.transform = collider.global_transform
	query.collision_mask = 1|2|4
	query.exclude = [add.get_rid()]
	var space = add.get_world_3d().direct_space_state
	if not expect(space.intersect_shape(query,8).is_empty(),"Actual summoned crawler capsule must not overlap player, solid geometry or another actor"): return false
	var ray = PhysicsRayQueryParameters3D.create(add.position+Vector3.UP*0.5,add.position-Vector3.UP,1)
	var hit = space.intersect_ray(ray)
	var size: float = game.level.layout.data.cell_size
	var cell = Vector2i(floor(add.position.x/size),floor(add.position.z/size))
	return expect(game.level.layout.is_walkable(cell) and not hit.is_empty() and absf(add.position.y-hit.position.y) < 0.1,"Summoned crawler must stand on real authored floor, never off map or suspended")

func check_summoner() -> bool:
	if not await arena("summoner"): return false
	actor._physics_process(0)
	if not expect(actor.telegraph_time >= MIN_TELLS.summoner and adds().is_empty(),"Planted summoner rituals visibly before creating any real add"): return false
	var planted: Vector3 = actor.position
	await advance(int(ceil(actor.telegraph_time/STEP))+2)
	if not expect(adds().size() == 2 and actor.position.distance_to(planted) < 0.05,"Clear-floor summoner stays planted and releases its bounded pair of real crawlers"): return false
	await settle()
	for add in adds():
		if not expect(add.get_script() == game.Enemy and add in game.level.get_children(),"Adds use actual enemy AI/collision and current level ownership"): return false
		if not clear_add(add): return false
	var initial_ids = adds().map(func(node): return node.id)
	await advance(420)
	if not expect(adds().map(func(node): return node.id) == initial_ids,"Two living owned adds prevent replacement or unbounded ritual chains"): return false
	var seen: Dictionary = {}
	for round_index in range(5):
		for add in adds():
			seen[add.id] = true
			add.take_damage(10000,game.player)
			if not expect(add.hp == 0 and add.id in game.state.removed,"Summoned adds are mortal and use one-shot death/removal"): return false
		await advance(300)
		if not expect(adds().size() <= 2,"Per-owner living cap holds after adds die"): return false
		await settle()
		for add in adds():
			if not clear_add(add): return false
	for add in adds(): seen[add.id] = true
	if not expect(seen.size() == 6 and adds().is_empty(),"Summoner may create six unique crawlers per life, then exhausts its resource permanently"): return false
	var peers = [spawn("summoner",base+Vector3.RIGHT*8),spawn("summoner",base+Vector3.LEFT*8),spawn("summoner",base+Vector3.BACK*8)]
	await settle()
	await advance(420,false,peers)
	if not expect(adds().size() == 4,"Small global add cap is four living crawlers across three fresh summoners"): return false
	await settle()
	for add in adds():
		if not clear_add(add): return false
	for peer in peers: peer.take_damage(10000,game.player)
	var count: int = game.enemies.size()
	await advance(240,false,peers)
	if not expect(game.enemies.size() == count,"Dead summoners cannot ritual again or create orphan chains"): return false
	var old_adds = adds().duplicate()
	var old_level = game.level
	game.start_level()
	freeze_world()
	var health: int = game.state.health
	for add in old_adds: add._physics_process(2)
	if not expect(game.state.health == health,"Stale summoned actors cannot attack the replacement player"): return false
	await process_frame
	await process_frame
	if not expect(not is_instance_valid(old_level) and old_adds.all(func(add): return not is_instance_valid(add)),"Actual map teardown frees every living summoned crawler"): return false
	if not await arena("summoner"): return false
	actor._physics_process(0)
	# Introduce cover after commitment, blocking the bounded local spawn search.
	game.level._box(Vector3(12,5,12),base+Vector3.UP*2.5,game.level._material(Color.WHITE),true)
	await settle()
	await advance(int(ceil(actor.telegraph_time/STEP))+3)
	return expect(adds().is_empty(),"Committed ritual with no clear local capsule placements must safely create no adds")

# Observe both attacks through normal cooldowns; no artificial variant selector.
func boss_patterns(low_phase: bool = false) -> bool:
	var signatures: Array = []
	for cycle in range(2):
		actor.position.x = base.x
		actor.position.z = base.z
		game.player.position = base+Vector3(0,0.04,-10)
		await settle()
		for frame in range(360):
			await advance(1)
			if actor.telegraph_time > 0: break
		if not expect(actor.telegraph_time >= MIN_TELLS[actor.kind]-STEP and actor.telegraph_time <= 1.5,"Boss must offer a bounded readable tell within six seconds, including pressure phase"): return false
		var attacks: int = events("attack")
		game.player.position.x += 4
		await settle()
		await advance(int(ceil(actor.telegraph_time/STEP))+2)
		var shots = flights()
		if not expect(events("attack") == attacks+1 and game.state.health == 200,"Boss releases once after its tell, without unavoidable instantaneous damage"): return false
		actor._physics_process(0)
		if not expect(int(actor.sprite.frame/8) == 3 and actor.pose_time > 0,"Boss release visibly opens its actual attack silhouette/core"): return false
		if actor.kind == "nursery_warden":
			signatures.append("clamp" if actor._rush_time > 0 else "roots")
			if not expect((actor._rush_time > 0 and shots.is_empty()) or (actor._rush_time == 0 and shots.size() == (5 if low_phase else 3)),"Warden alternates native clamp charge with a limited root projectile pattern"): return false
		else:
			signatures.append(shots.size())
			if not expect(shots.size() in ([5,12] if low_phase else [3,8]),"Avatar uses a bounded travelling fan or gapped radial pulse, never a hitscan storm"): return false
		var directions: Array = []
		for flight in shots:
			if not expect(flight.velocity.length() > 0 and flight.velocity.length() <= 18 and flight.lifetime > 0 and flight.lifetime <= 4,"Boss projectiles have dodgeable travel and finite lifetime"): return false
			directions.append(flight.velocity.normalized())
			flight._physics_process(1.5)
			if is_instance_valid(flight) and not flight.is_queued_for_deletion(): flight.queue_free()
		if directions.size() > 1:
			if not expect(directions.any(func(direction): return direction.dot(directions[0]) < 0.99),"Boss fan/pulse consists of separated directions rather than stacked guaranteed hits"): return false
		var recovered: bool = actor.recovery_time > 0
		for frame in range(65):
			await advance(1)
			recovered = recovered or actor.recovery_time > 0
		if not expect(game.state.health == 200 and actor._rush_time == 0 and recovered and actor.attack_time > 0,"Boss attack can be strafed clear and exposes finite recovery before retry"): return false
		await process_frame
	return expect(signatures[0] != signatures[1],actor.kind+" must perform two genuinely distinct native attacks in consecutive cycles")

func check_bosses() -> bool:
	for kind in ["nursery_warden","choir_avatar"]:
		if not await arena(kind): return false
		if not await boss_patterns(): return false
		var full_hp: int = actor.hp
		actor.take_damage(int(full_hp/2)+1,game.player)
		actor._physics_process(0)
		if not expect(actor.get("phase") == 1,"Boss below-half pressure phase is a one-way scalar transition"): return false
		if not await boss_patterns(true): return false
		# Healing is fixture-only: prove the transition cannot oscillate across the threshold.
		actor.hp = full_hp
		actor._physics_process(0)
		if not expect(actor.get("phase") == 1,"Pressure phase stays latched if HP later rises"): return false
		if not await boss_patterns(true): return false
		if not await arena(kind): return false
		actor._physics_process(0)
		var wall = game.level._box(Vector3(18,10,0.1),base+Vector3(0,5,-5),game.level._material(Color.WHITE),true)
		await settle()
		await advance(int(ceil(actor.telegraph_time/STEP))+70)
		for flight in flights(): flight._physics_process(2)
		if not expect(game.state.health == 200 and actor.position.z > wall.position.z+0.3,"Boss committed attack respects real cover"): return false
		for difficulty in range(3):
			if not await boss_fight(kind,difficulty): return false
	return true

func boss_fight(kind: String, difficulty: int) -> bool:
	if not await arena(kind,10,difficulty): return false
	game.state.owned_weapons = [0,1,5]
	game.state.weapon = 5
	game.state.ammo[5] = 80
	game.state.armor = 100
	game.state.mark_checkpoint("late_role_boss",game.player.position)
	var identity: String = actor.id
	var initial_hp: int = actor.hp
	var successful_shots: int = 0
	for frame in range(900):
		await physics_frame
		game.player._physics_process(STEP)
		game.player.position.x = base.x+sin(frame*STEP*1.4)*4
		game.player.camera.look_at(actor.global_position+Vector3.UP*2.8,Vector3.UP)
		if frame%10 == 0 and game.player.fire(): successful_shots += 1
		actor._physics_process(STEP)
		for flight in flights():
			flight.set_physics_process(false)
			flight._physics_process(STEP)
		if actor.hp <= 0 or not game.playing: break
	print("MEASURE late_role=",kind," difficulty=",difficulty," initial_hp=",initial_hp," shots=",successful_shots," remaining_ammo=",game.state.ammo[5]," health=",game.state.health," armor=",game.state.armor)
	if not expect(actor.hp == 0 and game.state.health > 0 and successful_shots > 0 and game.state.ammo[5] > 0 and game.state.removed.count(identity) == 1,"Boss must be mortal in a real bounded-ammo native fight on every difficulty, without production invulnerability"): return false
	game.hurt_player(10000)
	game.restore_checkpoint()
	freeze_world()
	if not expect(game.playing and game.state.health == 200 and game.state.armor == 100 and game.state.ammo[5] == 80 and not identity in game.state.removed,"Real death/checkpoint restoration returns exact pre-boss resources and removal state"): return false
	for guard in game.enemies: guard.queue_free()
	game.enemies.clear()
	actor = spawn(kind,base,identity)
	await settle()
	return expect(actor.hp == initial_hp and actor.get("phase") == 0,"Fresh boss retry starts at full difficulty-scaled HP with no inherited phase or summon budget")

func check_lifetime() -> bool:
	for kind in ROLES:
		if not await arena(kind): return false
		var cell: int = 256 if kind in ["nursery_warden","choir_avatar"] else 128
		if not expect(actor.sprite.hframes == 8 and actor.sprite.vframes == 5 and is_equal_approx(actor.sprite.pixel_size*cell,SCALES[kind]),"Late role quad derives height from its actual source SPECS and atlas cell size"): return false
		if not expect(is_equal_approx(actor.sprite.position.y,(cell/2.0-8)*actor.sprite.pixel_size),"Eight-pixel bottom margin preserves regular origin 64/120 and boss origin 128/248 above the floor"): return false
		var shape: CapsuleShape3D = actor.get_child(0).shape
		if not expect(shape.radius >= 0.4 and shape.radius <= 1.2 and shape.height >= 3 and shape.height <= 6,"Late-role central capsule fits its silhouette and the authored wide arena, rather than worker-size fallback"): return false
		if not expect(actor.motion_mode == (CharacterBody3D.MOTION_MODE_FLOATING if kind == "choir_avatar" else CharacterBody3D.MOTION_MODE_GROUNDED),"Only the hollow-jaw avatar floats; summoner and Warden stay grounded"): return false
		actor._physics_process(0)
		await advance(15)
		var clearance: float = actor.position.y-base.y
		if not expect((clearance > 0.7 and clearance < 1.3) if kind == "choir_avatar" else absf(clearance) < 0.1,"Actual native floor contact/hover preserves grounded feet or avatar clearance during anticipation"): return false
		var timers = [actor.age,actor.telegraph_time,actor.attack_time,actor.stagger_time,actor.recovery_time,actor._rush_time]
		var location: Vector3 = actor.position
		game.pause_game()
		actor.set_physics_process(true)
		actor._physics_process(0.5)
		await settle()
		if not expect(not actor.can_process() and actor.position == location and timers == [actor.age,actor.telegraph_time,actor.attack_time,actor.stagger_time,actor.recovery_time,actor._rush_time],"Pause freezes role placement and all anticipation/charge/recovery timers"): return false
		game.resume_game()
		actor.set_physics_process(false)
		actor.take_damage(100000,game.player)
		actor.take_damage(1,game.player)
		actor._physics_process(1)
		if not expect(actor.hp == 0 and actor.telegraph_time == 0 and actor._rush_time == 0 and actor.collision_layer == 0 and actor.collision_mask == 0 and game.state.removed.count(actor.id) == 1 and events("death") == 1,"Death cancels pending attacks, disables collision and persists once"): return false
		for facing in range(8):
			actor.rotation.y = facing*TAU/8
			for direction in range(8):
				var view = Vector3(sin(direction*TAU/8),0,-cos(direction*TAU/8))
				game.player.position = actor.position+actor.basis*view*6
				actor._physics_process(0)
				if not expect(int(actor.sprite.frame/8) == 4 and actor.sprite.frame%8 == direction,"All eight actor yaws and view directions preserve the actual directional death row"): return false
		# A live stale actor cannot attack/spawn or mutate either map after replacement.
		actor = spawn(kind,base)
		game.player.position = base+Vector3(0,0.04,-10)
		await settle()
		actor._physics_process(0)
		var old_level = game.level
		var old_hp: int = actor.hp
		var old_count: int = events("attack")
		game.start_level()
		freeze_world()
		var health: int = game.state.health
		var count: int = game.enemies.size()
		actor._physics_process(3)
		actor.take_damage(100000,game.player)
		if not expect(actor.hp == old_hp and events("attack") == old_count and game.state.health == health and game.enemies.size() == count,"Stale-map role cannot release, spawn, damage or consume new-map state"): return false
		await process_frame
		await process_frame
		if not expect(not is_instance_valid(old_level) and not is_instance_valid(actor),"Replacement frees the actual old role and all level-owned adds/projectiles"): return false
	return true

func check_old_roles() -> bool:
	for difficulty in range(3):
		for kind in ["crawler","worker","caster"]:
			if not await arena(kind,1.65 if kind == "crawler" else 10,difficulty): return false
			var multiplier: float = [0.85,1.0,1.3][difficulty]
			if not expect(actor.hp == int((50 if kind == "crawler" else 90)*multiplier) and actor.speed == (5.4 if kind == "crawler" else 3.1),"Old role HP/speed difficulty multipliers remain exact"): return false
			if not expect(is_equal_approx(actor.sprite.pixel_size*128,3.8 if kind == "crawler" else 3.65),"Old sprite sizing stays unchanged"): return false
			actor._physics_process(0)
			var tell: float = {"crawler":0.25,"worker":0.45,"caster":0.70}[kind]
			if not expect(is_equal_approx(actor.telegraph_time,tell),"Old anticipation timings remain exact"): return false
			await advance(int(ceil(tell/STEP))+15)
			for flight in flights(): flight._physics_process(2)
			var damage: int = 12 if kind == "crawler" else 10 if kind == "worker" else 14
			if not expect(game.state.health == 200-int(damage*[0.7,1.0,1.4][difficulty]),"Old roles retain one-hit damage on all three difficulties"): return false
	return true

func finish(status: int) -> void:
	Input.action_release("fire")
	if is_instance_valid(game): game.show_title()
	paused = false
	# Established native mix-release grace before freeing production audio/HUD nodes.
	await create_timer(0.1).timeout
	if is_instance_valid(game): game.free()
	await process_frame
	await process_frame
	for suffix in ["_campaign.json","_campaign.json.tmp","_preferences.json","_preferences.json.tmp"]:
		var path = test_prefix+suffix
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	quit(status)
