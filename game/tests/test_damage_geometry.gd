extends SceneTree

class NativeGame extends "res://scripts/main.gd":
	var shot_call_log: Array[int] = []
	func _ready() -> void:
		set_process(false)
		# Apply production defaults only; never load a user's saved preferences.
		var default_preferences = Preferences.new()
		default_preferences.apply_bindings()
	func shot(weapon: int) -> void:
		shot_call_log.append(weapon)
		super.shot(weapon)

var failures := 0

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func run() -> void:
	for shooter_z in [-8.0,8.0]:
		var game = NativeGame.new()
		root.add_child(game)
		game.state.new_campaign(1)
		game.level = game.Level.new()
		game.add_child(game.level)
		game.level.layout.load_level(0)
		game.playing = true
		game.player = game.Player.new()
		game.level.add_child(game.player)
		game.player.configure(game)
		game.player.set_physics_process(false)
		game.player.position = Vector3(20,.04,0)
		var guardian = game.Enemy.new()
		game.level.add_child(guardian)
		guardian.configure(game,{"id":"geometry_guardian","kind":"guardian","cell":[.5,.5],"yaw":0})
		guardian.position = Vector3.ZERO
		guardian.set_physics_process(false)
		opaque_guardian_contact(guardian)
		game.enemies = [guardian]
		var source = CharacterBody3D.new()
		game.level.add_child(source)
		source.position = Vector3(0,0,-8)
		var shot = preload("res://scripts/projectile.gd").new()
		game.level.add_child(shot)
		shot.configure(game,source,Vector3(0,1,-6),Vector3(0,1,0))
		shot.set_physics_process(false)
		source.position.z = shooter_z
		await physics_frame
		await physics_frame
		var hp: int = guardian.hp
		shot._physics_process(.7)
		var damage: int = hp-guardian.hp
		print("MEASURE identical front projectile source_z=",shooter_z," damage=",damage)
		if damage != 4:
			failures += 1
			push_error("Guardian front armor must use actual projectile arrival, not moved shooter position")
		game.free()
		await process_frame
	await check_arrivals()
	await check_open_windows()
	await check_blasts()
	await check_context()
	await check_controlled_rivet_range()
	if failures == 0: print("PASS native damage geometry/identity, armor windows, blasts, cover and controlled 70m Rivet; manually stepped/test-built arena, not authored-route/physical/GPU acceptance")
	quit(0 if failures == 0 else 1)

func expect(condition: bool, detail: String) -> void:
	if condition: return
	failures += 1
	push_error(detail)

func fixture():
	var game = NativeGame.new()
	root.add_child(game)
	game.state.new_campaign(1)
	game.level = game.Level.new()
	game.add_child(game.level)
	expect(game.level.layout.load_level(0),"SETUP actual level metadata loads")
	game.playing = true
	game.player = game.Player.new()
	game.level.add_child(game.player)
	game.player.configure(game)
	game.player.set_physics_process(false)
	game.player.position = Vector3(20,.04,0)
	return game

func body(game, id: String, role: String, location: Vector3):
	var actor = game.Enemy.new()
	game.level.add_child(actor)
	actor.configure(game,{"id":id,"kind":role,"cell":[.5,.5],"yaw":0})
	actor.position = location
	actor.set_physics_process(false)
	actor.active = true
	if role == "guardian": opaque_guardian_contact(actor)
	game.enemies.append(actor)
	return actor

func projectile(game, source, side: float, damage: int = 0):
	var shot = preload("res://scripts/projectile.gd").new()
	game.level.add_child(shot)
	shot.configure(game,source,Vector3(0,1,side*6),Vector3(0,1,0),damage)
	shot.set_physics_process(false)
	return shot

func dispose(game) -> void:
	var released: WeakRef = weakref(game)
	game.free()
	await process_frame
	expect(released.get_ref() == null,"Owned fixture game is freed after teardown")

func check_arrivals() -> void:
	# Path side, final shooter side, guardian yaw, freed shooter, expected damage.
	for row in [[-1.0,-8.0,0.0,true,4], [1.0,-8.0,0.0,false,14], [1.0,8.0,0.0,false,14], [1.0,8.0,0.0,true,14], [-1.0,-8.0,PI,false,14], [1.0,-8.0,PI,false,4]]:
		var game = fixture()
		var guardian = body(game,"arrival_guardian","guardian",Vector3.ZERO)
		guardian.rotation.y = row[2]
		var source = body(game,"arrival_source","worker",Vector3(0,0,-8))
		var shot = projectile(game,source,row[0])
		source.position.z = row[1]
		if row[3]: source.free()
		await physics_frame
		await physics_frame
		expect(Engine.is_in_physics_frame(),"Projectile step belongs to native physics")
		var hp: int = guardian.hp
		var ammo: Array = game.state.ammo.duplicate()
		shot._physics_process(.7)
		expect(shot.is_queued_for_deletion(),"Real opaque sprite contact retires traveling projectile")
		expect(hp-guardian.hp == row[4],"Actual arrival path/guardian rotation determine armor, not shooter location or survival: "+str(row))
		expect(game.state.ammo == ammo,"NPC projectile geometry does not spend campaign ammunition")
		expect(guardian.target == null if row[3] else guardian.target == source,"Retaliation retains only the actual living eligible source")
		await dispose(game)

func check_open_windows() -> void:
	for phase in ["telegraph_time","pose_time","recovery_time"]:
		var game = fixture()
		var guardian = body(game,"open_guardian","guardian",Vector3.ZERO)
		guardian.set(phase,.2)
		var source = body(game,"open_source","worker",Vector3(0,0,-8))
		var shot = projectile(game,source,-1)
		await physics_frame
		await physics_frame
		var hp: int = guardian.hp
		shot._physics_process(.7)
		expect(shot.is_queued_for_deletion() and hp-guardian.hp == 14,"Front projectile retains full14 damage during "+phase)
		await dispose(game)

func check_blasts() -> void:
	# Direct calls isolate radial-origin policy; traveling cases below exercise the full contact path.
	for side in [-1.0,1.0]:
		var game = fixture()
		var guardian = body(game,"radial_guardian","guardian",Vector3.ZERO)
		var source = body(game,"radial_source","worker",Vector3(0,0,-side*8))
		var shot = projectile(game,source,side,110)
		await physics_frame
		await physics_frame
		var hp: int = guardian.hp
		shot._blast(Vector3(0,.85,side*2),null)
		expect(hp-guardian.hp == (19 if side < 0 else 55),"Radial armor uses actual front/rear detonation origin despite shooter on opposite side")
		expect(guardian.target == source,"Blast geometry does not replace eligible retaliation identity")
		await dispose(game)
	for covered in [false,true]:
		var game = fixture()
		var guardian = body(game,"direct_guardian","guardian",Vector3.ZERO)
		var splash = body(game,"splash_worker","worker",Vector3(1.5,0,0))
		var source = body(game,"blast_source","worker",Vector3(0,0,8))
		if covered: game.level._box(Vector3(.1,4,4),Vector3(.75,2,0),null,true)
		var shot = projectile(game,source,-1,110)
		await physics_frame
		await physics_frame
		var guardian_hp: int = guardian.hp
		var splash_hp: int = splash.hp
		var ammo: Array = game.state.ammo.duplicate()
		shot._physics_process(.7)
		expect(shot.is_queued_for_deletion(),"Real marrow first contact retires projectile")
		expect(guardian_hp-guardian.hp == 38,"Direct guardian receives exactly one110 hit with retained front multiplier, never an added splash hit")
		expect(splash_hp-splash.hp == (0 if covered else 64),"Actual blast falloff reaches exposed worker exactly once, while thin native cover blocks it")
		expect(game.state.ammo == ammo,"Manual projectile stepping does not alter finite ammunition")
		await dispose(game)

func check_context() -> void:
	var game = fixture()
	var guardian = body(game,"context_guardian","guardian",Vector3.ZERO)
	var source = body(game,"context_source","worker",Vector3(0,0,-8))
	var hp: int = 0
	await physics_frame
	await physics_frame
	expect(Engine.is_in_physics_frame(),"Damage context checks run inside native physics")
	var accepts_context := false
	for method in guardian.get_method_list():
		if method.name == "take_damage" and method.args.size() == 3: accepts_context = true
	if not accepts_context:
		expect(false,"Proposed optional damage context is not implemented; earlier real projectile witnesses establish semantic RED independently")
		await dispose(game)
		return
	# Expected damage is the frozen contract, not a copy of the production bearing calculation.
	var cases := [
		[{"incoming_direction":Vector3(0,0,1)},8.0,4],
		[{"incoming_direction":Vector3(0,0,-1)},-8.0,14],
		[{"origin":Vector3(0,0,-2)},8.0,4],
		[{"origin":Vector3(0,0,2)},-8.0,14],
		[{"incoming_direction":Vector3.ZERO},-8.0,14],
		[{"incoming_direction":Vector3.UP},-8.0,14],
		[{"incoming_direction":Vector3(INF,0,1)},-8.0,14],
		[{"incoming_direction":Vector3(0,NAN,1)},-8.0,14],
		[{"incoming_direction":Vector3(0,INF,1)},-8.0,14],
		[{"origin":Vector3(0,NAN,-2)},-8.0,14],
		[{"origin":Vector3(0,INF,-2)},-8.0,14],
		[{"origin":Vector3(INF,0,0)},-8.0,14],
		[{"origin":Vector3.ZERO},-8.0,14],
		[{"origin":Vector3.UP},-8.0,14],
		[{"attack_kind":"projectile"},-8.0,14],
		[{},-8.0,4],
		[{},8.0,14]]
	for row in cases:
		source.position.z = row[1]
		guardian.target = null
		hp = guardian.hp
		guardian.call("take_damage",14,source,row[0])
		expect(hp-guardian.hp == row[2],"Explicit finite/invalid/legacy context follows declared armor fallback: "+str(row[0]))
		expect(guardian.target == source,"Geometry validity remains independent of eligible retaliation identity")
	# A live but retired-map source cannot become the retaliation target.
	source.reparent(game)
	guardian.target = null
	hp = guardian.hp
	guardian.call("take_damage",14,source,{"incoming_direction":Vector3(0,0,1)})
	expect(hp-guardian.hp == 4 and guardian.target == null,"Retired-map source retains valid incoming geometry but cannot cause retaliation")
	await dispose(game)


func check_controlled_rivet_range() -> void:
	# Purpose-built, collision-backed test arena: this is not campaign geometry.
	# Loaded Level metadata only supplies the real Main/Enemy execution context.
	var game = fixture()
	game.settings.auto_aim = false
	game.state.weapon = 1
	game.state.ammo[1] = 12
	game.state.shot_sequence[1] = 0
	game.player.position = Vector3(0,0.04,0)
	game.player.rotation = Vector3.ZERO
	game.player.camera.rotation = Vector3.ZERO
	game.player.weapon_cooldowns[1] = 0
	var floor_body = game.level._box(Vector3(20,.2,160),Vector3(0,-.1,-80),null,true)
	expect(floor_body is StaticBody3D and floor_body.get_child_count() > 0,"Controlled Rivet lane has an actual static floor and collision shape")
	var victim = _controlled_rivet_worker(game,70.0)
	await physics_frame
	await physics_frame
	expect(Engine.is_in_physics_frame(),"Controlled 70m shot is fired during native physics")
	var camera_origin: Vector3 = game.player.camera.global_position
	var victim_hp: int = victim.hp
	var ammo_before: int = game.state.ammo[1]
	var sequence_before: int = game.state.shot_sequence[1]
	expect(is_equal_approx(float(game.Player.WEAPONS[1].range),140.0),"Rivet maximum range remains the production 140m value")
	expect(InputMap.has_action("fire"),"Production default fire action exists before Actual Player.fire accepts controlled Rivet shot")
	expect(game.player.fire(),"Actual Player.fire accepts controlled Rivet shot")
	var observation: Dictionary = game.aim_observation
	var contact: Dictionary = observation.get("contact",{})
	var hit_position: Vector3 = contact.get("position",Vector3(INF,INF,INF))
	expect(game.shot_call_log == [1],"Actual Player.fire traverses NativeGame.shot and its super Main.shot implementation")
	expect(victim.hp == victim_hp-22,"Actual 70m visible-sprite contact applies exact worker Rivet damage")
	expect(game.state.ammo[1] == ammo_before-1 and game.state.shot_sequence[1] == sequence_before+1,"Real fire transaction consumes exactly one finite round and advances one shot sequence")
	expect(contact.get("collider") == victim and contact.get("coverage","") == "visible_sprite" and contact.has("sprite_pixel"),"70m contact is the actual opaque SpriteHitQuery texel, not a capsule/effect claim")
	expect(hit_position.is_finite() and camera_origin.distance_to(hit_position) >= 69.0 and camera_origin.distance_to(hit_position) <= 71.0,"Measured 70m hit position is within the original long-range test band")
	expect(not observation.get("assisted",true) and observation.get("manual_direction",Vector3.ZERO).dot(observation.get("direction",Vector3.ZERO)) > .99999,"70m test retains the straight physical ray without aim assistance or bend")
	expect(game.player.camera.global_position.distance_to(victim.sprite.global_position) >= 69.0,"Actual target sprite remains at its authored 70m fixture position")
	await dispose(game)

	# Opaque physical cover must win the same real Main/Player query at 70m.
	game = fixture()
	game.settings.auto_aim = false
	game.state.weapon = 1
	game.state.ammo[1] = 12
	game.player.position = Vector3(0,0.04,0)
	game.player.rotation = Vector3.ZERO
	game.player.camera.rotation = Vector3.ZERO
	game.player.weapon_cooldowns[1] = 0
	game.level._box(Vector3(20,.2,160),Vector3(0,-.1,-80),null,true)
	game.level._box(Vector3(8,5,.2),Vector3(0,2.5,-35),null,true)
	victim = _controlled_rivet_worker(game,70.0)
	await physics_frame
	await physics_frame
	victim_hp = victim.hp
	ammo_before = game.state.ammo[1]
	expect(InputMap.has_action("fire"),"Production default fire action exists before Real Player.fire accepts covered controlled shot")
	expect(game.player.fire(),"Real Player.fire accepts covered controlled shot")
	contact = game.aim_observation.get("contact",{})
	expect(contact.get("collider") is StaticBody3D and (contact.collider.collision_layer & 1) != 0,"Actual opaque wall intercepts 70m ray before sprite coverage")
	expect(victim.hp == victim_hp and game.state.ammo[1] == ammo_before-1,"Wall-negative consumes a fired round but causes no through-wall damage")
	expect(game.shot_call_log == [1],"Wall-negative still traverses actual Main.shot")
	await dispose(game)

	# A real 145m target lies beyond the production Rivet's unchanged 140m ray.
	game = fixture()
	game.settings.auto_aim = false
	game.state.weapon = 1
	game.state.ammo[1] = 12
	game.player.position = Vector3(0,0.04,0)
	game.player.rotation = Vector3.ZERO
	game.player.camera.rotation = Vector3.ZERO
	game.player.weapon_cooldowns[1] = 0
	game.level._box(Vector3(20,.2,300),Vector3(0,-.1,-150),null,true)
	victim = _controlled_rivet_worker(game,145.0)
	await physics_frame
	await physics_frame
	victim_hp = victim.hp
	ammo_before = game.state.ammo[1]
	expect(InputMap.has_action("fire"),"Production default fire action exists before Actual Player.fire accepts uncapped-range negative shot transaction")
	expect(game.player.fire(),"Actual Player.fire accepts uncapped-range negative shot transaction")
	observation = game.aim_observation
	contact = observation.get("contact",{})
	expect(float(observation.get("range",0)) == 140.0 and observation.get("actor_id","").is_empty(),"Beyond-cap observation uses exactly 140m and does not resolve the 145m target")
	expect(contact.is_empty() and victim.hp == victim_hp,"Actual query has no 145m sprite hit or damage past the 140m endpoint")
	expect(game.state.ammo[1] == ammo_before-1 and game.shot_call_log == [1],"Beyond-cap negative still records the real shot/ammo transaction")
	await dispose(game)

func _controlled_rivet_worker(game, distance: float):
	var actor = game.Enemy.new()
	game.level.add_child(actor)
	actor.configure(game,{"id":"controlled_rivet_"+str(int(distance)),"kind":"worker","cell":[.5,.5],"yaw":0})
	actor.position = Vector3(0,0,-distance)
	actor.active = true
	actor.set_physics_process(false)
	# Actual Sprite3D/alpha-query input in a purpose-built controlled atlas.
	# This opaque test texture validates geometry, not production art quality.
	var image := Image.create(1024,640,false,Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	actor.sprite.texture = ImageTexture.create_from_image(image)
	actor.sprite.hframes = 8
	actor.sprite.vframes = 5
	actor.sprite.frame = 0
	game.enemies = [actor]
	return actor

func opaque_guardian_contact(actor) -> void:
	# Fixture-only opacity, not replacement game art: a solid2m square centred
	# at y1,z−0.65 reproduces the old front contact and exact38/64 damage setup.
	var image := Image.create(16,16,false,Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	actor.sprite.texture = ImageTexture.create_from_image(image)
	actor.sprite.hframes = 1
	actor.sprite.vframes = 1
	actor.sprite.frame = 0
	actor.sprite.pixel_size = 0.125
	actor.sprite.position = Vector3(0,1,-0.65)
	assert(image.get_pixel(8,8).a == 1.0)
