extends SceneTree

const Projectile = preload("res://scripts/projectile.gd")
const STEP = 1.0/60.0

# Observe production callbacks; collision, damage, audio and scene ownership stay real.
class ObservedGame extends "res://scripts/main.gd":
	var impacts: Array[Vector3] = []
	var shots: Array = []
	var dry_events: Array = []
	var events: Dictionary = {}
	func impact(point: Vector3) -> void:
		impacts.append(point)
		super.impact(point)
	func shot(index: int) -> void:
		shots.append(index)
		super.shot(index)
	func dry_fire(index: int) -> void:
		dry_events.append(index)
		super.dry_fire(index)
	func enemy_event(actor, event: String) -> void:
		events[event] = events.get(event,0)+1
		super.enemy_event(actor,event)

var game
var serial: int = 0
var test_prefix = "user://test_late_weapons_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func run() -> void:
	game = ObservedGame.new()
	game.settings_path = test_prefix+"_preferences.json"
	game.progress_path = test_prefix+"_campaign.json"
	game.preferences.values.music_volume = 0.0
	game.preferences.values.effects_volume = 0.0
	root.add_child(game)
	game.set_process(false)
	game.set_process_unhandled_input(false)
	# First RED precedes any assumption about new late-weapon state or APIs.
	if not await check_launcher_travel():
		await finish(1)
		return
	if not await check_launcher_boss_caps():
		await finish(1)
		return
	for difficulty in range(3):
		for assisted in [false,true]:
			if not await check_blast(difficulty,assisted):
				await finish(1)
				return
		if not await check_self_radius(difficulty):
			await finish(1)
			return
	for check in [check_flight_lifetime,check_resources,check_repeater,check_disruptor,check_transition]:
		if not await check.call():
			await finish(1)
			return
	print("PASS native late weapons: travelling capsule, covered falloff/self radius, finite paused flight, resources, sustained spread, bounded pulse/counter and map teardown")
	await finish(0)

func arena(difficulty: int = 1, assisted: bool = false) -> bool:
	Input.action_release("fire")
	game.show_title()
	paused = false
	await process_frame
	await process_frame
	game.state.new_campaign(difficulty)
	game.settings.auto_aim = assisted
	game.settings.head_bob = false
	game.settings.camera_shake = false
	game.level = game.Level.new()
	game.level.process_mode = Node.PROCESS_MODE_PAUSABLE
	game.add_child(game.level)
	if not expect(game.level.layout.load_level(0),"SETUP: existing Intake layout must load"): return false
	box(Vector3(300,1,300),Vector3(0,-0.5,-60))
	game.player = game.Player.new()
	game.level.add_child(game.player)
	game.player.configure(game)
	game.player.position = Vector3(0,0.04,0)
	game.player.set_physics_process(false)
	game.player.set_process_unhandled_input(false)
	game.state.owned_weapons = [0,1,2,3,4,5]
	game.state.ammo = [0,90,32,240,24,120]
	game.state.health = 200
	game.state.armor = 0
	game.state.weapon = 4
	game.impacts.clear()
	game.shots.clear()
	game.dry_events.clear()
	game.events.clear()
	game.playing = true
	await settle()
	return true

func worker(location: Vector3):
	serial += 1
	var actor = game.Enemy.new()
	game.level.add_child(actor)
	actor.configure(game,{"id":"late_worker_"+str(serial),"kind":"worker","cell":[0.5,0.5],"yaw":0})
	actor.position = location
	# Survive repeated measurements so death-clamped HP cannot conceal falloff or locks.
	actor.hp = 1000
	actor.set_physics_process(false)
	game.enemies.append(actor)
	return actor

func box(size: Vector3, location: Vector3) -> Node3D:
	return game.level._box(size,location,game.level._material(Color.WHITE),true)

func settle() -> void:
	await physics_frame
	await physics_frame

func flights() -> Array:
	return game.level.get_children().filter(func(node): return node.get_script() == Projectile and not node.is_queued_for_deletion())

func capsule():
	var live = flights()
	if not expect(live.size() == 1,"Launcher must own exactly one real projectile in the current level"): return null
	live[0].set_physics_process(false)
	return live[0]

func resolve(flight) -> bool:
	# Static real colliders permit deterministic swept travel without wall-clock sleeps.
	for tick in range(360):
		if flight.is_queued_for_deletion(): return true
		flight._physics_process(STEP)
	return expect(flight.is_queued_for_deletion(),"Capsule must hit or expire within six simulated seconds")

func check_launcher_travel() -> bool:
	if not await arena(): return false
	var target = worker(Vector3(0,0.03,-12))
	await settle()
	var origin: Vector3 = game.player.camera.global_position
	var query = PhysicsRayQueryParameters3D.create(origin,origin+Vector3.FORWARD*20,1|4)
	var hit = game.get_world_3d().direct_space_state.intersect_ray(query)
	if not expect(not hit.is_empty() and hit.collider == target,"SETUP: centered ray must intersect the real worker capsule"): return false
	var hp: int = target.hp
	if not expect(game.player.fire() and game.state.ammo[4] == 23,"Launcher discharge spends one capsule"): return false
	print("MEASURE launcher immediate_damage=",hp-target.hp," live_flights=",flights().size())
	if not expect(target.hp == hp,"LATE WEAPONS RED: marrow launcher must travel before damage; observed instant damage "+str(hp-target.hp)): return false
	var flight = capsule()
	if flight == null: return false
	var start: Vector3 = flight.global_position
	flight._physics_process(0.05)
	var travelled: float = start.distance_to(flight.global_position)
	if not expect(travelled > 0.2 and travelled < 6.0 and target.hp == hp and not flight.is_queued_for_deletion(),"Capsule travels for a visible interval before contacting a twelve-metre target"): return false
	if not resolve(flight): return false
	var damage: int = hp-target.hp
	if not expect(damage > 0 and damage <= game.player.WEAPONS[4].damage and game.state.health == 200,"Contact damages the actual enemy once without remote self-damage"): return false
	flight._physics_process(1.0)
	return expect(target.hp == hp-damage,"Queued capsule cannot detonate or damage twice")

func check_launcher_boss_caps() -> bool:
	for difficulty in range(3):
		for kind in ["nursery_warden","choir_avatar"]:
			if not await arena(difficulty): return false
			serial += 1
			var actor = game.Enemy.new()
			game.level.add_child(actor)
			actor.configure(game,{"id":"upper_cap_"+str(serial),"kind":kind,"cell":[0.5,0.5],"yaw":0})
			actor.position = Vector3(0,1.03 if kind == "choir_avatar" else 0.03,-12)
			actor.set_physics_process(false)
			game.enemies.append(actor)
			var shape = actor.get_child(0).shape
			game.player.camera.look_at(actor.global_position+Vector3.UP*(shape.height-0.15))
			await settle()
			var origin: Vector3 = game.player.camera.global_position
			var query = PhysicsRayQueryParameters3D.create(origin,origin-game.player.camera.global_basis.z*20,1|4)
			var hit = game.get_world_3d().direct_space_state.intersect_ray(query)
			if not expect(not hit.is_empty() and hit.collider == actor,"SETUP: upper-cap shot must hit the real boss capsule"): return false
			var blast_point: Vector3 = hit.position+hit.normal*0.05
			if not expect(blast_point.distance_to(actor.global_position+Vector3.UP*0.85)>Projectile.BLAST_RADIUS,"SETUP: native upper-cap impact must lie outside the splash-centre radius"): return false
			var hp: int = actor.hp
			if not expect(game.player.fire() and game.state.ammo[4]==23 and actor.hp==hp,"Upper-cap discharge spends one capsule and travels before damage"): return false
			var flight = capsule()
			if flight == null or not resolve(flight): return false
			print("MEASURE upper_cap kind=",kind," difficulty=",difficulty," direct_damage=",hp-actor.hp)
			if not expect(actor.hp==hp-game.player.WEAPONS[4].damage,"Direct marrow hit must damage the tall boss cap fully, regardless of splash-centre distance (intended RED)"): return false
			flight._physics_process(1.0)
			if not expect(actor.hp==hp-game.player.WEAPONS[4].damage and game.state.health==200,"Upper-cap contact remains one-shot without remote self-damage"): return false
	return true

func check_blast(difficulty: int, assisted: bool) -> bool:
	if not await arena(difficulty,assisted): return false
	var wall = box(Vector3(20,5,0.05),Vector3(0,2.5,-8))
	# Exposed blast victims sit outside the assistance cone so this remains a wall shot.
	var near = worker(Vector3(2,0.03,-7))
	var far = worker(Vector3(3.25,0.03,-7))
	var covered = worker(Vector3(0,0.03,-9))
	var outside = worker(Vector3(8,0.03,-7))
	var corner = worker(Vector3(-1.5,0.03,-5))
	box(Vector3(0.05,4,1.8),Vector3(-0.6,2,-6.5))
	box(Vector3(1.2,4,0.05),Vector3(-1.15,2,-5.6))
	await settle()
	var origin: Vector3 = game.player.camera.global_position
	var sight = PhysicsRayQueryParameters3D.create(origin,origin+Vector3.FORWARD*20,1|4)
	var hit = game.get_world_3d().direct_space_state.intersect_ray(sight)
	if not expect(not hit.is_empty() and hit.collider == wall,"SETUP: center shot must meet thin blast cover, not an actor"): return false
	if assisted and not expect(game.autoaim_target(origin,Vector3.FORWARD,140.0) == null,"SETUP: assistance must have no exposed candidate away from the wall shot"): return false
	if not expect(game.player.fire(),"Covered blast fixture must discharge"): return false
	var flight = capsule()
	if flight == null: return false
	flight.velocity = flight.velocity.normalized()*3000.0
	flight._physics_process(0.01)
	if not expect(flight.is_queued_for_deletion() and absf(flight.position.z-wall.position.z) < 0.1,"Swept marrow capsule hits thin native cover without tunnelling"): return false
	var near_damage: int = 1000-near.hp
	var far_damage: int = 1000-far.hp
	print("MEASURE blast difficulty=",difficulty," assist=",assisted," near=",near_damage," far=",far_damage," covered=",1000-covered.hp)
	if not expect(near_damage > far_damage and far_damage > 0 and near_damage <= game.player.WEAPONS[4].damage,"Native blast must damage exposed near and far capsules with distance falloff"): return false
	if not expect(covered.hp == 1000 and corner.hp == 1000 and outside.hp == 1000 and game.state.health == 200,"Thin wall and L-corner block blast; out-of-radius actors and remote player remain unharmed"): return false
	var resources: Array = [near.hp,far.hp,covered.hp,corner.hp,outside.hp,game.state.health]
	flight._physics_process(0.5)
	return expect(resources == [near.hp,far.hp,covered.hp,corner.hp,outside.hp,game.state.health],"Wall detonation remains one-shot")

func check_self_radius(difficulty: int) -> bool:
	for distance in [2.0,8.0]:
		if not await arena(difficulty): return false
		box(Vector3(20,5,0.05),Vector3(0,2.5,-distance))
		await settle()
		if not expect(game.player.fire(),"Self-radius fixture must discharge"): return false
		var flight = capsule()
		if flight == null or not resolve(flight): return false
		if not expect((game.state.health < 200 and game.state.health > 0) if distance == 2.0 else game.state.health == 200,"Self-damage is finite inside a two-metre blast, absent eight metres away, at every fixed difficulty"): return false
	return true

func check_flight_lifetime() -> bool:
	if not await arena(): return false
	game.player.camera.rotation.x = 0.5
	if not expect(game.player.fire(),"Lifetime fixture must launch into empty space"): return false
	var flight = capsule()
	if flight == null: return false
	var start: Vector3 = flight.global_position
	var lifetime: float = flight.lifetime
	var speed: float = flight.velocity.length()
	if not expect(is_finite(lifetime) and lifetime > 0 and lifetime <= 6.0 and is_finite(speed) and speed > 0,"Capsule exposes existing finite velocity/lifetime state, bounded to six seconds"): return false
	game.pause_game()
	flight.set_physics_process(true)
	flight._physics_process(1.0)
	await settle()
	if not expect(not flight.can_process() and flight.position == start and flight.lifetime == lifetime,"Native level pause freezes capsule travel and expiry"): return false
	flight.set_physics_process(false)
	game.resume_game()
	flight._physics_process(lifetime+1.0)
	if not expect(flight.is_queued_for_deletion() and is_equal_approx(flight.global_position.distance_to(start),speed*lifetime),"Expiry clamps actual travel to remaining lifetime and removes the capsule"): return false
	return expect(game.state.health == 200 and game.impacts.is_empty(),"Empty-space expiry produces no phantom blast or self-damage")

func check_resources() -> bool:
	if not await arena(): return false
	var profiles = game.player.WEAPONS
	for index in range(6):
		if not expect(profiles[index].max_ammo == [0,180,32,240,24,120][index] and profiles[index].low_ammo == [0,20,4,30,3,12][index],"All six authoritative capacities and low thresholds remain intact"): return false
	if not expect(profiles[2].damage == 15 and profiles[2].pellets == 7 and profiles[2].interval == 0.7,"Old close scatter signature remains intact"): return false
	for index in [3,4,5]:
		game.state.weapon = index
		game.state.ammo[index] = 9999
		if not expect(game.player.fire() and game.state.ammo[index] == 9998 and is_equal_approx(game.player.cooldown,profiles[index].interval),"Each late discharge spends one unit from a valid legacy reserve and starts local recovery"): return false
		var before: Array = game.state.ammo.duplicate()
		if not expect(not game.player.fire() and game.state.ammo == before,"Late local cooldown blocks duplicates without extra spending"): return false
	game.state.weapon = 4
	var remaining: float = game.player.cooldown
	game.state.weapon = 1
	if not expect(game.player.fire(),"Ready pistol fires immediately while late weapons recover"): return false
	game.state.weapon = 4
	if not expect(game.player.cooldown == remaining and not game.player.fire(),"Switch-back cannot reset launcher recovery"): return false
	game.pause_game()
	var timers: Array = game.player.weapon_cooldowns.duplicate()
	game.player._physics_process(1.0)
	if not expect(timers == game.player.weapon_cooldowns and not game.player.fire(),"Pause freezes every local weapon recovery"): return false
	game.resume_game()
	game.player._physics_process(0.1)
	if not expect(is_equal_approx(game.player.cooldown,remaining-0.1),"Playing time advances unselected and selected late recovery"): return false
	# Missing future ownership may coexist with valid legacy ammunition.
	game.state.owned_weapons = [0,1,4]
	game.state.ammo = [0,5,0,20,0,10]
	game.state.weapon = 4
	var before: Array = game.state.ammo.duplicate()
	var shots: int = game.shots.size()
	if not expect(not game.player.fire() and game.state.weapon == 1 and game.state.ammo == before and game.shots.size() == shots and game.dry_events == [4],"Empty launcher deliberately selects a supplied owned gun without firing it or spending unowned reserves"): return false
	game.state.weapon = 4
	if not expect(not game.player.fire() and game.dry_events == [4],"Immediate late empty attempts debounce feedback"): return false
	game.state.ammo[1] = 0
	game.state.weapon = 4
	if not expect(not game.player.fire() and game.state.weapon == 0 and game.shots.size() == shots,"All empty owned guns fall back to the free tool without an extra attack"): return false
	before = game.state.ammo.duplicate()
	if not expect(game.player.fire() and game.state.ammo == before,"Only the next explicit call swings the free tool"): return false
	game.player.cycle_weapon(1)
	return expect(game.state.weapon == 1,"Manual cycling still reaches empty owned weapons")

func check_repeater() -> bool:
	for assisted in [false,true]:
		if not await arena(1,assisted): return false
		box(Vector3(80,40,0.1),Vector3(0,10,-30))
		await settle()
		game.state.weapon = 3
		seed(11)
		var angles: Array[float] = []
		Input.action_press("fire")
		for shot in range(32):
			var count: int = game.impacts.size()
			game.player._physics_process(0 if shot == 0 else game.player.WEAPONS[3].interval+0.001)
			if not expect(game.impacts.size() == count+1,"Each held-fire tick produces one real repeater wall impact"): return false
			var offset: Vector3 = game.impacts.back()-game.player.camera.global_position
			angles.append(acos(clampf(offset.normalized().dot(-game.player.camera.global_basis.z),-1,1)))
		Input.action_release("fire")
		if not expect(game.state.ammo[3] == 208 and game.shots.size() == 32,"Sustained repeater burst consumes exactly one unit per native discharge"): return false
		var sustained: Array = angles.slice(16)
		print("MEASURE repeater assist=",assisted," first_deg=",rad_to_deg(angles[0])," sustained_max_deg=",rad_to_deg(sustained.max()))
		if not expect(angles[0] <= 0.01 and angles[1] <= 0.01 and sustained.max() > 0.015 and angles.max() <= deg_to_rad(6),"Repeater starts precise, develops meaningful sustained spread, and stays inside six degrees"): return false
		game.pause_game()
		var timers: Array = game.player.weapon_cooldowns.duplicate()
		game.player._physics_process(2.0)
		if not expect(timers == game.player.weapon_cooldowns and game.state.ammo[3] == 208,"Paused burst recovery never ticks or fires"): return false
		game.resume_game()
		game.state.weapon = 1
		game.player._physics_process(2.0)
		game.state.weapon = 3
		game.impacts.clear()
		if not expect(game.player.fire() and game.impacts.size() == 1,"Released repeater is ready after unselected recovery"): return false
		var recovered: Vector3 = game.impacts[0]-game.player.camera.global_position
		if not expect(recovered.normalized().dot(-game.player.camera.global_basis.z) >= cos(0.01),"Released burst regains its initial precision within two playing seconds"): return false
	return true

func pulse_line() -> Array:
	var actors: Array = []
	for distance in [4,6,8,10,12,14,16,40]:
		actors.append(worker(Vector3(0,0.03,-distance)))
	return actors

func check_disruptor() -> bool:
	for assisted in [false,true]:
		if not await arena(1,assisted): return false
		var actors = pulse_line()
		await settle()
		game.state.weapon = 5
		if not expect(game.player.fire() and game.state.ammo[5] == 119,"One disruptor discharge consumes one cell"): return false
		for index in range(actors.size()):
			var damage: int = 1000-actors[index].hp
			if not expect((damage > 0 and damage <= game.player.WEAPONS[5].damage) if index < 3 else damage == 0,"One bounded pulse reaches the first three real capsules once each, never the remaining or distant actors"): return false
		if not expect(game.player.WEAPONS[5].range >= 12 and game.player.WEAPONS[5].range <= 32,"Pressure reach is short/medium, rather than the old 140-metre generic hitscan"): return false
		if not await arena(1,assisted): return false
		actors = pulse_line()
		box(Vector3(8,5,0.05),Vector3(0,2.5,-7))
		await settle()
		game.state.weapon = 5
		if not expect(game.player.fire(),"Covered pulse must discharge"): return false
		for index in range(actors.size()):
			if not expect(actors[index].hp < 1000 if index < 2 else actors[index].hp == 1000,"Native wall terminates pressure penetration after the two exposed actors, including with assistance"): return false
		if not await arena(1,assisted): return false
		var distant = worker(Vector3(0,0.03,-40))
		await settle()
		game.state.weapon = 5
		if not expect(game.player.fire() and distant.hp == 1000,"Native pulse cannot damage a lone forty-metre capsule even when no actor cap is exhausted"): return false
	if not await arena(): return false
	var actor = worker(Vector3(0,0.03,-12))
	actor.target = game.player
	await settle()
	actor._physics_process(0)
	if not expect(actor.telegraph_time > 0,"SETUP: real worker must enter its eligible windup"): return false
	game.state.weapon = 5
	if not expect(game.player.fire() and actor.telegraph_time == 0 and actor.stagger_time > 0 and actor.stagger_time <= 0.5 and game.events.get("stagger",0) == 1,"Pressure cancels an eligible windup through a finite existing counter window"): return false
	var stagger: float = actor.stagger_time
	var lock: float = actor._counter_time
	game.player.cooldown = 0
	if not expect(game.player.fire() and actor.stagger_time == stagger and actor._counter_time == lock and game.events.get("stagger",0) == 1,"A second pulse cannot refresh interruption or its refractory lock"): return false
	# A surviving target must escape pressure spam and release its actual committed attack.
	var pressure_hits: int = 0
	for frame in range(144):
		await physics_frame
		game.player._physics_process(STEP)
		if frame%10 == 0:
			game.player.camera.look_at(actor.global_position+Vector3.UP*1.35,Vector3.UP)
			var hp: int = actor.hp
			if game.player.fire():
				if not expect(actor.hp < hp,"Counter stress must keep hitting the moving real capsule, rather than miss until it attacks"): return false
				pressure_hits += 1
		actor._physics_process(STEP)
	print("MEASURE pressure_hits=",pressure_hits," attacks=",game.events.get("attack",0)," player_damage=",200-game.state.health)
	return expect(pressure_hits >= 12 and actor.hp > 0 and game.events.get("attack",0) > 0 and game.state.health < 200,"Existing refractory allows a surviving worker to attack through repeated confirmed disruptor pressure")

func check_transition() -> bool:
	if not await arena(): return false
	game.player.camera.rotation.x = 0.5
	if not expect(game.player.fire(),"Transition fixture must own an in-flight capsule"): return false
	var flight = capsule()
	if flight == null: return false
	var old_level = game.level
	game.start_level()
	game.set_process(false)
	game.player.set_physics_process(false)
	game.player.set_process_unhandled_input(false)
	for actor in game.enemies: actor.set_physics_process(false)
	var health: int = game.state.health
	flight._physics_process(1.0)
	if not expect(flight.is_queued_for_deletion() and game.state.health == health,"Old-map marrow flight cannot detonate against replacement-map actors or player"): return false
	await process_frame
	await process_frame
	return expect(not is_instance_valid(old_level) and not is_instance_valid(flight),"Actual start_level teardown frees the old level and capsule")

func expect(condition: bool, detail: String) -> bool:
	if not condition: push_error(detail)
	return condition

func finish(status: int) -> void:
	Input.action_release("fire")
	if is_instance_valid(game): game.show_title()
	paused = false
	# Established native effects/HUD grace: stopped voices release on the next mix.
	await create_timer(0.1).timeout
	if is_instance_valid(game): game.free()
	await process_frame
	await process_frame
	for suffix in ["_campaign.json","_campaign.json.tmp","_preferences.json","_preferences.json.tmp"]:
		var path = test_prefix+suffix
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	quit(status)
