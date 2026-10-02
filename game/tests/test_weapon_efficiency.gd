extends SceneTree

# Use production collision, damage, assistance and firing; omit menus, music and file I/O.
class NativeGame extends "res://scripts/main.gd":
	var assist_calls: int = 0
	var dry_events: Array = []
	var fired_weapons: Array = []
	func _ready() -> void:
		set_process(false)
	func autoaim_target(origin: Vector3, direction: Vector3, max_range: float) -> Node3D:
		assist_calls += 1
		return super.autoaim_target(origin,direction,max_range)
	func shot(index: int) -> void:
		fired_weapons.append(index)
		super.shot(index)
	func dry_fire(index: int) -> void:
		dry_events.append(index)

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func run() -> void:
	preload("res://scripts/preferences.gd").new().apply_bindings()
	# Deliberately miss above a distant capsule, still inside the real assistance cone.
	# Baseline redirects every pellet independently; this is the first behavioral RED.
	var game = await fixture(1,true,28.0)
	if game == null: return
	game.player.camera.rotation.x = 0.1
	if not expect(game.autoaim_target(game.player.camera.global_position,-game.player.camera.global_basis.z,32.0) == game.enemies[0],"SETUP: exposed distant worker must be eligible for real assistance"): return
	game.assist_calls = 0
	var hp: int = game.enemies[0].hp
	if not expect(game.player.fire(),"Assisted scatter shot must fire"): return
	var damage: int = hp-game.enemies[0].hp
	print("MEASURE first assisted scatter distance=28 damage=",damage," assist_calls=",game.assist_calls)
	if not expect(game.assist_calls <= 1,"AMMO RED: one scatter shot must resolve aim assistance at most once; observed "+str(game.assist_calls)): return
	if not expect(damage > 0 and damage < 22,"Distant assisted scatter must land damage but lose precision to one 22-damage rivet"): return
	game.free()
	for difficulty in range(3):
		for assisted in [false,true]:
			if not (await check_efficiency(difficulty,assisted)): return
	if not (await check_recovery()): return
	if not (await check_empty()): return
	var profiles = preload("res://scripts/player.gd").WEAPONS
	for index in range(6):
		if not expect(profiles[index].get("max_ammo") == [0,180,32,240,24,120][index] and profiles[index].get("low_ammo") == [0,20,4,30,3,12][index],"All six profiles must expose frozen capacity and warning thresholds"): return
		if not expect(float(profiles[index].get("useful_range",0)) > 0 and float(profiles[index].useful_range) <= float(profiles[index].range),"Useful range must describe an actual reachable weapon role"): return
	print("PASS native weapon efficiency: three difficulties, assistance on/off, capsules/walls, range, recovery, fallback and legacy reserves")
	quit()

func fixture(difficulty: int, assisted: bool, distance: float):
	var game = NativeGame.new()
	root.add_child(game)
	game.state.new_campaign(difficulty)
	game.settings.auto_aim = assisted
	game.settings.head_bob = false
	game.settings.camera_shake = false
	game.level = game.Level.new()
	game.add_child(game.level)
	if not expect(game.level.layout.load_level(0),"SETUP: load existing real enemy placement contract"): return null
	game.level._box(Vector3(100,1,100),Vector3(0,-0.5,-20),game.level._material(Color.WHITE),true)
	game.level._box(Vector3(20,8,0.2),Vector3(0,4,-distance-5),game.level._material(Color.GRAY),true)
	game.player = game.Player.new()
	game.level.add_child(game.player)
	game.player.configure(game)
	game.player.position = Vector3(0,0.04,0)
	game.player.set_physics_process(false)
	var target = game.Enemy.new()
	game.level.add_child(target)
	target.configure(game,{"id":"efficiency_worker","kind":"worker","cell":[0.5,0.5],"yaw":0})
	target.position = Vector3(0,0.03,-distance)
	target.set_physics_process(false)
	game.enemies.append(target)
	game.state.owned_weapons = [0,1,2]
	game.state.ammo = [0,90,32,0,0,0]
	game.state.weapon = 2
	game.playing = true
	await physics_frame
	await physics_frame
	var query = PhysicsRayQueryParameters3D.create(game.player.camera.global_position,target.global_position+Vector3.UP*1.35,1|4)
	var hit = game.get_world_3d().direct_space_state.intersect_ray(query)
	if not expect(not hit.is_empty() and hit.collider == target and target.hp == int(90*[0.85,1.0,1.3][difficulty]),"SETUP: ray must hit production worker capsule with fixed difficulty health"): return null
	return game

func check_efficiency(difficulty: int, assisted: bool) -> bool:
	var game = await fixture(difficulty,assisted,3.0)
	if game == null: return false
	var target = game.enemies[0]
	if not expect(game.player.fire() and game.state.ammo[2] == 31 and is_equal_approx(game.player.cooldown,0.7),"Close scatter consumes one shell with its retained recovery"): return false
	if not expect(target.hp == (12 if difficulty == 2 else 0),"Centered close worker: Merciful/Relentless die in one scatter shot; Terminal retains exactly 12 health"): return false
	if difficulty == 2:
		game.player.cooldown = 0
		if not expect(game.player.fire() and target.hp == 0 and game.state.ammo[2] == 30,"Terminal close worker takes exactly two shells"): return false
	print("MEASURE difficulty=",difficulty," assist=",assisted," close_shells=",2 if difficulty == 2 else 1)
	game.free()
	var distances: Array = []
	for distance in [15.0,28.0]:
		game = await fixture(difficulty,assisted,distance)
		if game == null: return false
		target = game.enemies[0]
		var original_hp: int = target.hp
		seed(11)
		game.assist_calls = 0
		if not expect(game.player.fire(),"Distance measurement must fire through production collision"): return false
		var damage: int = original_hp-target.hp
		distances.append(damage)
		if not expect(damage > 0 and damage < 22 and (not assisted or game.assist_calls <= 1),"Medium/far scatter lands less damage than a precise rivet without per-pellet assistance"): return false
		target.hp = original_hp
		game.player.cooldown = 0
		seed(987)
		if not expect(game.player.fire() and original_hp-target.hp == damage,"Fixed scatter rays must produce the same capsule damage regardless of random seed"): return false
		# 9999 is a valid legacy reserve: measure ammunition cost without fallback interference.
		target.hp = original_hp
		game.state.ammo[2] = 9999
		var shells: int = shots_to_defeat(game,2)
		if shells < 0: return false
		target.hp = original_hp
		target.collision_layer = 4
		target.collision_mask = 1|2|4
		game.state.removed.erase(target.id)
		await physics_frame
		await physics_frame
		game.state.ammo[1] = 9999
		var rivets: int = shots_to_defeat(game,1)
		if rivets < 0: return false
		if not expect(rivets == int(ceil(float(original_hp)/22.0)) and shells > rivets,"Pistol precision must defeat the medium/far worker using fewer ammunition units"): return false
		print("MEASURE difficulty=",difficulty," assist=",assisted," distance=",distance," scatter_damage=",damage," shells=",shells," rivets=",rivets)
		game.free()
	if not expect(distances[1] < distances[0],"Scatter damage must decline further between 15 and 28 metres"): return false
	game = await fixture(difficulty,assisted,35.0)
	if game == null: return false
	var hp: int = game.enemies[0].hp
	if not expect(game.player.fire() and game.enemies[0].hp == hp,"Scatter cannot hit or acquire a worker beyond its finite reach"): return false
	game.state.weapon = 1
	game.player.cooldown = 0
	if not expect(game.player.fire() and game.enemies[0].hp == hp-22,"Pistol retains its distant precision role beyond scatter reach"): return false
	game.free()
	game = await fixture(difficulty,assisted,15.0)
	if game == null: return false
	game.level._box(Vector3(8,5,0.05),Vector3(0,2.5,-6),game.level._material(Color.GRAY),true)
	await physics_frame
	await physics_frame
	hp = game.enemies[0].hp
	for index in [2,1]:
		game.state.weapon = index
		game.player.cooldown = 0
		if not expect(game.player.fire() and game.enemies[0].hp == hp,"World obstruction must block all pellets and assisted pistol rays"): return false
	game.free()
	return true

func shots_to_defeat(game, index: int) -> int:
	var before: int = game.state.ammo[index]
	game.state.weapon = index
	for shot in range(128):
		game.player.cooldown = 0
		if not expect(game.player.fire(),"Efficiency measurement cannot dry-fire or stall"): return -1
		if game.enemies[0].hp == 0:
			var used: int = before-game.state.ammo[index]
			if not expect(used == shot+1,"Each ranged shot must consume exactly one ammunition unit"): return -1
			return used
	expect(false,"Efficiency measurement exceeded bounded 128-shot defeat limit")
	return -1

func check_recovery() -> bool:
	var game = await fixture(1,false,35.0)
	if game == null: return false
	if not expect(game.player.fire(),"Recovery fixture starts with a real scatter shot"): return false
	game.player.cycle_weapon(-1)
	if not expect(game.state.weapon == 1 and is_zero_approx(game.player.cooldown) and game.player.fire(),"Ready pistol must fire immediately after switching away from recovering scatter"): return false
	game.state.weapon = 2
	if not expect(is_equal_approx(game.player.cooldown,0.7) and not game.player.fire() and game.state.ammo[2] == 31,"Switching back cannot reset or bypass scatter recovery"): return false
	game.player._physics_process(0.1)
	game.state.weapon = 1
	if not expect(is_equal_approx(game.player.cooldown,0.11),"Unselected pistol recovery ticks with selected scatter recovery"): return false
	game.playing = false
	game.player._physics_process(1.0)
	if not expect(is_equal_approx(game.player.cooldown,0.11) and not game.player.fire(),"Paused weapon recovery and firing remain frozen"): return false
	game.state.weapon = 2
	if not expect(is_equal_approx(game.player.cooldown,0.6),"Paused unselected recovery also remains frozen"): return false
	game.playing = true
	game.player._physics_process(0.12)
	game.state.weapon = 1
	if not expect(game.player.fire(),"Unselected pistol becomes ready through elapsed playing time"): return false
	game.state.weapon = 2
	if not expect(not game.player.fire(),"Scatter remains unavailable until its own interval ends"): return false
	game.player._physics_process(0.5)
	if not expect(game.player.fire() and game.state.ammo[2] == 30,"Scatter recovery expires without resetting from switches"): return false
	game.free()
	return true

func check_empty() -> bool:
	var game = await fixture(1,false,2.0)
	if game == null: return false
	game.state.ammo = [0,5,0,20,0,0]
	var before = game.state.ammo.duplicate()
	if not expect(not game.player.fire() and game.state.weapon == 1 and game.state.ammo == before and game.fired_weapons.is_empty() and game.dry_events == [2],"Empty scatter reports once, selects supplied owned pistol and never fires fallback in the failed call"): return false
	game.state.weapon = 2
	if not expect(not game.player.fire() and game.dry_events == [2],"Repeated immediate empty attempts must debounce dry-fire feedback"): return false
	game.state.ammo[1] = 0
	game.state.weapon = 2
	before = game.state.ammo.duplicate()
	if not expect(not game.player.fire() and game.state.weapon == 0 and game.state.ammo == before and game.fired_weapons.is_empty(),"Empty owned ranged inventory falls back to free tool, ignoring unowned repeater reserve"): return false
	var hp: int = game.enemies[0].hp
	if not expect(game.player.fire() and game.enemies[0].hp == hp-28 and game.state.ammo == before,"Next explicit fire swings the free impact tool against the actual close capsule"): return false
	game.player.cycle_weapon(1)
	if not expect(game.state.weapon == 1,"Manual cycle still permits selecting an empty owned weapon"): return false
	game.state.ammo[1] = 9999
	if not expect(game.player.fire() and game.state.ammo[1] == 9998,"Firing a valid legacy over-cap reserve must preserve it except for one spent rivet"): return false
	game.free()
	return true

func expect(condition: bool, detail: String) -> bool:
	if not condition:
		push_error(detail)
		quit(1)
	return condition
