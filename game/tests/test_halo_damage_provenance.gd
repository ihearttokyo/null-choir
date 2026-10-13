extends SceneTree

const STEP = 1.0/60.0
# SYNTHETIC: poses, HP and committed timers arrange these counterexamples.
# Only real Enemy/Projectile/Player contact and damage paths are observed.
class ArenaMain:
	extends "res://tests/test_reliquary_halo_feasibility.gd".FourthMain
	var kill_after_birth: bool = false
	var cancellation: String = ""
	var contact_seen: bool = false
	var dead_source_id: int = 0
	var shots_at_release: Array = []
	var crawler_releases: Array = []
	var melee_observations: Array = []
	var melee_cancellation: String = ""
	var owner_hurts: Array = []
	func hurt_player(amount: int) -> void:
		if melee_cancellation == "owner-queue": owner_hurts.append(amount)
		super.hurt_player(amount)
	func _ready() -> void:
		set_process(false)
		set_process_unhandled_input(false)
	func _physics_process(_delta: float) -> void: pass
	func h_current() -> bool:
		return playing and not get_tree().paused and is_instance_valid(level) and level.get_instance_id() == h_level and is_instance_valid(player) and player.get_instance_id() == h_player and player.get_parent() == level and prefix_bookkeeping_retired
	func impact(_point: Vector3) -> void: pass
	func enemy_event(actor, event: String) -> void:
		if h_enabled and event == "attack" and actor.kind == "crawler":
			crawler_releases.append([actor.id,Engine.get_physics_frames()])
		if h_enabled and event == "melee_contact":
			var intended = actor._committed_target
			var origin: Vector3 = actor.global_position+Vector3.UP*0.6
			var end: Vector3 = intended.global_position+Vector3.UP*0.7
			var query = PhysicsRayQueryParameters3D.create(origin,end,1|2|4)
			query.exclude = [actor.get_rid()]
			query.hit_from_inside = true
			var hit = level.get_world_3d().direct_space_state.intersect_ray(query)
			melee_observations.append([actor.id,Engine.get_physics_frames(),hit.get("collider") == player,hit.get("rid") == player.get_rid(),actor.global_position.distance_to(intended.global_position)])
			if not melee_cancellation.is_empty():
				match melee_cancellation:
					"pause": playing = false
					"owner-queue": queue_free()
					"source-queue": actor.queue_free()
					"source-free": actor.free()
					"victim-reparent": hit.collider.reparent(self)
					"victim-queue": hit.collider.queue_free()
					"victim-free": hit.collider.free()
					"map-queue": level.queue_free()
					"map-free": level.free()
					"replace-map":
						level = Level.new()
						add_child(level)
					"replace-player":
						player = Player.new()
						level.add_child(player)
						player.configure(self)
						player.set_physics_process(false)
				return
		if h_enabled and event == "attack" and actor.kind == "worker":
			var origin: Vector3 = actor.global_position+Vector3.UP*1.4
			var query = PhysicsRayQueryParameters3D.create(origin,origin+(actor._committed_aim-origin).normalized()*30.0,1|2|4)
			query.exclude = [actor.get_rid()]
			query.hit_from_inside = true
			var hit = level.get_world_3d().direct_space_state.intersect_ray(query)
			shots_at_release.append([actor.id,Engine.get_physics_frames(),hit.get("collider") == player])
		super.enemy_event(actor,event)
	func _debug_projectile_event(projectile: Node3D, event: String, data: Dictionary) -> void:
		if event == "queued_enemy_contact":
			contact_seen = true
			if cancellation == "malformed-rid":
				data = data.duplicate(true)
				data.hit.rid = RID()
			if cancellation in ["pause","victim-reparent","victim-queue","victim-free","map-queue","map-free","replace-map","replace-player","projectile-reparent"]:
				match cancellation:
					"pause": playing = false
					"victim-reparent": data.hit.collider.reparent(self)
					"victim-queue": data.hit.collider.queue_free()
					"victim-free": data.hit.collider.free()
					"map-queue": data.map.queue_free()
					"map-free": data.map.free()
					"replace-map":
						level = Level.new()
						add_child(level)
					"replace-player":
						player = Player.new()
						level.add_child(player)
						player.configure(self)
						player.set_physics_process(false)
					"projectile-reparent": projectile.reparent(self)
				return
		super._debug_projectile_event(projectile,event,data)
		if event == "configured_birth" and kill_after_birth:
			# Synthetic source death uses real take_damage, not earned Player combat.
			kill_after_birth = false
			dead_source_id = projectile.shooter.get_instance_id()
			h_enabled = false
			projectile.shooter.take_damage(1000,player)
			projectile.shooter.set_physics_process(false)
			h_removed = state.removed.duplicate()
			h_enabled = true

var failures: int = 0
var game
var prior_mute: bool

func _initialize() -> void:
	prior_mute = AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func expect(condition: bool, detail: String) -> bool:
	if condition: return true
	failures += 1
	push_error(detail)
	return false

func fixture() -> void:
	game = ArenaMain.new()
	game.prefix_bookkeeping_retired = true
	root.add_child(game)
	game.state.new_campaign(1)
	game.state.health = 100
	game.state.armor = 200
	game.state.ammo = [0,125,32,0,0,0]
	game.state.owned_weapons = [0,1,2]
	game.state.weapon = 1
	game.level = game.Level.new()
	game.add_child(game.level)
	expect(game.level.layout.load_level(3),"SETUP synthetic arena uses real Reliquary metadata; no earned route")
	game.player = game.Player.new()
	game.level.add_child(game.player)
	game.player.configure(game)
	game.player.set_physics_process(false)
	game.player.set_process_unhandled_input(false)
	game.player.position = Vector3(0,0.04,0)
	game.h_level = game.level.get_instance_id()
	game.h_player = game.player.get_instance_id()
	game.playing = true
	game.h_enabled = true
	var floor_body = StaticBody3D.new()
	floor_body.collision_layer = 1
	var floor_shape = CollisionShape3D.new()
	floor_shape.shape = BoxShape3D.new()
	floor_shape.shape.size = Vector3(80,0.2,80)
	floor_shape.position.y = -0.1
	floor_body.add_child(floor_shape)
	game.level.add_child(floor_body)

func body(id: String, role: String, point: Vector3):
	var actor = game.Enemy.new()
	game.level.add_child(actor)
	actor.configure(game,{"id":id,"kind":role,"cell":[0.5,0.5],"yaw":0})
	actor.position = point
	actor.active = true
	actor.alerted = true
	actor.target = game.player
	actor.set_physics_process(false)
	game.enemies.append(actor)
	game.h_bindings[id] = actor.get_instance_id()
	game.h_activated[id] = [actor.get_instance_id(),Engine.get_physics_frames()]
	return actor

func settle() -> void:
	await physics_frame
	await physics_frame
	await process_frame

func arm(actor, intended, aim: Vector3) -> void:
	# Timer arrangement only; native physics releases the actual attack.
	actor.target = intended
	actor._committed_target = intended
	actor._committed_aim = aim
	actor.telegraph_time = STEP/2.0
	actor.attack_time = 20.0
	actor.set_physics_process(true)

func drain() -> void:
	if is_instance_valid(game): game.queue_free()
	await process_frame
	await process_frame
	game = null

func dead_caster(control: String = "") -> void:
	fixture()
	game.cancellation = control
	game.player.position.x = 15.0
	var caster = body("reliquary_enemy_07","caster",Vector3(0,0.03,-6))
	var crawler = body("reliquary_enemy_00","crawler",Vector3(0,0.03,0))
	crawler.hp = 6
	var victim_id: int = crawler.get_instance_id()
	var victim_rid: RID = crawler.get_rid()
	var original_level = game.level
	await settle()
	game.kill_after_birth = true
	arm(caster,crawler,crawler.global_position+Vector3.UP*0.55)
	for frame in range(100):
		await physics_frame
		await process_frame
		if game.contact_seen or (is_instance_valid(crawler) and crawler.hp == 0): break
	var cancelled: bool = control in ["pause","victim-reparent","victim-queue","victim-free","map-queue","map-free","replace-map","replace-player","projectile-reparent"]
	if cancelled:
		expect(game.contact_seen and not game.h_deaths.has("reliquary_enemy_00") and not "reliquary_enemy_00" in game.state.removed and (not is_instance_valid(crawler) or crawler.hp == 6),"Callback cancellation must not damage stale original victim: "+control)
	elif control == "malformed-rid":
		expect(game.contact_seen and not game.h_ok,"Malformed contact RID must latch the narrow provenance guard")
	else:
		expect(caster.hp == 0 and game.dead_source_id == caster.get_instance_id() and game.h_births.size() == 1,"SETUP original caster released one retained projectile before synthetic source death")
		expect(crawler.get_instance_id() == victim_id and crawler.get_rid() == victim_rid and crawler.target == game.player and crawler.hp == 0 and game.h_deaths.get(crawler.id,0) == 1 and game.h_finishes.get(crawler.id,"unproven") == "infighting" and game.h_ok and game.state.removed.count(crawler.id) == 1 and crawler.collision_layer == 0 and crawler.collision_mask == 0,"PROVENANCE exact dead-caster retained projectile/contact death; missing enemy callback must fail here")
	if original_level != game.level and is_instance_valid(original_level): original_level.queue_free()
	await drain()

func same_tick_workers() -> void:
	fixture()
	var miss = body("reliquary_enemy_04","worker",Vector3(-4,0.03,-6))
	var hit = body("reliquary_enemy_06","worker",Vector3(0,0.03,-6))
	await settle()
	arm(miss,game.player,Vector3(-4,1.0,6))
	arm(hit,game.player,game.player.global_position+Vector3.UP)
	await settle()
	miss.set_physics_process(false)
	hit.set_physics_process(false)
	expect(game.shots_at_release.size() == 2 and game.shots_at_release[0][0] == miss.id and not game.shots_at_release[0][2] and game.shots_at_release[1][0] == hit.id and game.shots_at_release[1][2] and game.shots_at_release[0][1] == game.shots_at_release[1][1],"SETUP first native worker misses and second hits in the same physics tick")
	expect(game.h_hurts.size() == 1 and game.h_hurts[0][1] == hit.id and game.h_hurts[0][2] == 10 and game.h_hurts[0][3] == 3 and game.state.health == 93 and game.state.armor == 197 and game.h_ok,"PROVENANCE same-tick source must be the actual second ray, not first matching tick")
	await drain()

func enemy_intent_player_contact() -> void:
	fixture()
	var worker = body("reliquary_enemy_04","worker",Vector3(0,0.03,-6))
	var intended = body("reliquary_enemy_00","crawler",Vector3(0,0.03,6))
	await settle()
	arm(worker,intended,intended.global_position+Vector3.UP*0.55)
	await settle()
	worker.set_physics_process(false)
	expect(worker._committed_target == intended and intended.hp == 50 and game.shots_at_release.size() == 1 and game.shots_at_release[0][2],"SETUP enemy-committed worker native ray hits intervening Player")
	expect(game.h_hurts.size() == 1 and game.h_hurts[0][1] == worker.id and game.h_hurts[0][2] == 10 and game.h_hurts[0][3] == 3 and game.state.health == 93 and game.state.armor == 197 and game.h_ok,"PROVENANCE native Player interception accepted independently of target intent")
	await drain()

func delayed_crawlers(control: String = "") -> void:
	fixture()
	game.melee_cancellation = control
	var miss = body("reliquary_enemy_00","crawler",Vector3(-4,0.03,-6))
	var hit = body("reliquary_enemy_01","crawler",Vector3(0,0.03,-2.1))
	await settle()
	arm(miss,game.player,game.player.global_position+Vector3.UP)
	await settle()
	expect(game.crawler_releases.size() == 1 and game.crawler_releases[0][0] == miss.id and game.h_hurts.is_empty() and not miss._rush_hit and miss.global_position.distance_to(game.player.global_position) >= 1.9,"SETUP first original crawler really released earlier but remains outside native melee range")
	arm(hit,game.player,game.player.global_position+Vector3.UP)
	for frame in range(12):
		await physics_frame
		await process_frame
		if not game.melee_observations.is_empty() or not game.h_hurts.is_empty(): break
	if control.is_empty():
		miss.set_physics_process(false)
		hit.set_physics_process(false)
		expect(game.crawler_releases.size() == 2 and game.crawler_releases[0][1] < game.crawler_releases[1][1] and game.melee_observations.size() == 1 and game.melee_observations[0][0] == hit.id and game.melee_observations[0][2] and game.melee_observations[0][3] and game.melee_observations[0][4] < 1.9 and game.melee_observations[0][1] > game.crawler_releases[1][1] and game.melee_observations[0][1]-game.crawler_releases[0][1] <= 12 and not miss._rush_hit and miss.global_position.distance_to(game.player.global_position) >= 1.9,"SETUP native delayed second crawler Player contact; first remains an eligible recent release but misses")
		expect(game.h_hurts.size() == 1 and game.h_hurts[0][1] == hit.id and game.h_hurts[0][2] == 12 and game.h_hurts[0][3] == 4 and game.state.health == 92 and game.state.armor == 196 and game.h_ok,"PROVENANCE delayed crawler source must be actual second contact, not first timing match")
	else:
		expect(game.melee_observations.size() == 1 and game.melee_observations[0][0] == "reliquary_enemy_01" and game.melee_observations[0][2] and game.melee_observations[0][3] and game.h_hurts.is_empty() and game.state.health == 100 and game.state.armor == 200,"Native melee callback cancellation prevents stale Player damage: "+control)
	await drain()

func enemy_intent_crawler_contact() -> void:
	fixture()
	var attacker = body("reliquary_enemy_01","crawler",Vector3(0,0.03,-1.0))
	var intended = body("reliquary_enemy_00","crawler",Vector3(0,0.03,0.8))
	await settle()
	arm(attacker,intended,intended.global_position+Vector3.UP)
	for frame in range(12):
		await physics_frame
		await process_frame
		if not game.melee_observations.is_empty() or not game.h_hurts.is_empty(): break
	attacker.set_physics_process(false)
	expect(attacker._committed_target == intended and intended.hp == 50 and game.melee_observations.size() == 1 and game.melee_observations[0][0] == attacker.id and game.melee_observations[0][2] and game.melee_observations[0][3] and game.melee_observations[0][4] < 1.9,"SETUP enemy-directed crawler native range/ray contacts intervening Player, not intended enemy")
	expect(game.h_hurts.size() == 1 and game.h_hurts[0][1] == attacker.id and game.h_hurts[0][2] == 12 and game.h_hurts[0][3] == 4 and game.state.health == 92 and game.state.armor == 196 and game.h_ok,"PROVENANCE crawler native Player interception accepted independently of intended target")
	await drain()

func owner_queue_contact() -> void:
	fixture()
	game.melee_cancellation = "owner-queue"
	var state = game.state
	var owner_reference = weakref(game)
	var contacts: Array = game.melee_observations
	var hurts: Array = game.owner_hurts
	var crawler = body("reliquary_enemy_01","crawler",Vector3(0,0.03,-2.1))
	await settle()
	arm(crawler,game.player,game.player.global_position+Vector3.UP)
	for frame in range(20):
		await physics_frame
		await process_frame
		if not contacts.is_empty(): break
	expect(contacts.size() == 1 and contacts[0][0] == "reliquary_enemy_01" and contacts[0][2] and contacts[0][3] and contacts[0][4] < 1.9,"SETUP native crawler actual Player contact queues Main; retained external witness survives disposal")
	expect(hurts.is_empty() and state.health == 100 and state.armor == 200,"OWNER LIFETIME queued Main must cancel native melee damage before deferred disposal")
	expect(owner_reference.get_ref() == null,"Owner queue control drains the actual Main")
	if is_instance_valid(game): game.queue_free()
	await process_frame
	await process_frame
	game = null

func run() -> void:
	var args = OS.get_cmdline_user_args()
	if "--owner-queue" in args:
		await owner_queue_contact()
	elif "--dead-caster" in args:
		await dead_caster()
	elif "--same-tick-workers" in args:
		await same_tick_workers()
	elif "--enemy-intent-player-contact" in args:
		await enemy_intent_player_contact()
	elif "--delayed-crawlers" in args:
		await delayed_crawlers()
	elif "--enemy-intent-crawler-contact" in args:
		await enemy_intent_crawler_contact()
	elif "--melee-source-free-rejected" in args:
		await delayed_crawlers("source-free")
	elif "--melee-callback-controls" in args:
		# Godot locks the dispatch source; retain its failing immediate-free trial separately.
		print("NOT RUN immediate source-free cancellation: native Godot rejects freeing its active callback source; retained --melee-source-free-rejected trial is not a passing control")
		for control in ["pause","source-queue","victim-reparent","victim-queue","victim-free","map-queue","map-free","replace-map","replace-player"]:
			await delayed_crawlers(control)
	elif "--callback-controls" in args:
		for control in ["pause","victim-reparent","victim-queue","victim-free","map-queue","map-free","replace-map","replace-player","projectile-reparent","malformed-rid"]:
			await dead_caster(control)
	else:
		await dead_caster()
		await same_tick_workers()
		await enemy_intent_player_contact()
		await delayed_crawlers()
		await enemy_intent_crawler_contact()
	AudioServer.set_bus_mute(0,prior_mute)
	if failures == 0: print("PASS SYNTHETIC native Halo provenance arenas only; arranged poses/HP/timers are not earned route or campaign evidence")
	quit(0 if failures == 0 else 1)
