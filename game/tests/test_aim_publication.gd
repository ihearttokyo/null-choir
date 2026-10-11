extends SceneTree

class NativeGame extends "res://scripts/main.gd":
	var aim_queries := 0
	var prompt_queries := 0
	var replace_on_shot := false
	var replace_on_dry := false
	func _ready() -> void: set_process(false)
	func resolve_aim(origin: Vector3,direction: Vector3,reach: float,melee: bool = false) -> Dictionary:
		aim_queries += 1
		return super.resolve_aim(origin,direction,reach,melee)
	func nearest_interaction() -> Dictionary:
		prompt_queries += 1
		return super.nearest_interaction()
	func shot(index: int) -> void:
		if replace_on_shot: replace_scene()
		else: super.shot(index)
	func dry_fire(_index: int) -> void:
		if replace_on_dry: replace_scene()
	func replace_scene() -> void:
		level = Level.new()
		add_child(level)
		level.layout.load_level(0)
		player = Player.new()
		level.add_child(player)
		player.configure(self)
		player.set_physics_process(false)

class Driver extends Node:
	var player
	var remaining := 0
	var steps := 0
	func _physics_process(delta: float) -> void:
		if remaining <= 0: return
		player._physics_process(delta)
		steps += 1
		remaining -= 1

var failures := 0

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func expect(condition: bool,message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)

func fixture():
	var game = NativeGame.new()
	root.add_child(game)
	game.state.new_campaign(1)
	game.level = game.Level.new()
	game.add_child(game.level)
	game.level.layout.load_level(0)
	game.player = game.Player.new()
	game.level.add_child(game.player)
	game.player.configure(game)
	game.player.set_physics_process(false)
	game.settings.head_bob = false
	game.settings.camera_shake = false
	game.playing = true
	var key: Dictionary = game.level.layout.data.interactions.filter(func(spec): return spec.kind == "key")[0]
	var location: Vector3 = game.level.layout.world_position(key.cell)
	game.level._box(Vector3(10,1,10),location-Vector3.UP*.5,null,true)
	game.player.position = location+Vector3(0,.04,3)
	game.player.camera.look_at(location+Vector3.UP*.7,Vector3.UP)
	return game

func tick(driver) -> void:
	driver.remaining = 1
	var previous: int = driver.steps
	while driver.steps == previous: await physics_frame

func run() -> void:
	preload("res://scripts/preferences.gd").new().apply_bindings()
	var game = fixture()
	var driver = Driver.new()
	driver.player = game.player
	root.add_child(driver)
	await physics_frame
	await physics_frame
	await tick(driver)
	expect(game.aim_queries == 1 and game.prompt_queries == 1,"Real non-firing Player tick publishes exactly one aim and interaction observation")
	expect(not game.interaction_display().is_empty() and game.interaction_display().get("kind") == "key","Automatic physics publication supplies a real aimed prompt")
	Input.action_press("fire")
	await tick(driver)
	Input.action_release("fire")
	expect(game.aim_queries == 2 and game.prompt_queries == 2 and game.state.ammo[1] == 89,"Accepted-shot tick resolves only once and refreshes its prompt")
	driver.free()
	game.free()
	for mode in ["shot","dry"]:
		game = fixture()
		driver = Driver.new()
		driver.player = game.player
		root.add_child(driver)
		if mode == "shot": game.replace_on_shot = true
		else:
			game.replace_on_dry = true
			game.state.ammo[1] = 0
		await physics_frame
		await physics_frame
		Input.action_press("fire")
		await tick(driver)
		Input.action_release("fire")
		expect(not driver.player._current_map(),"SETUP actual synchronous "+mode+" callback replaces owning scene/player")
		expect(game.aim_queries == 0 and game.prompt_queries == 0 and game.aim_observation.is_empty() and game.interaction_observation.is_empty(),"Retired Player callback cannot query or publish replacement scene after "+mode)
		driver.free()
		game.free()
	await process_frame
	if failures == 0: print("PASS real Player physics publication, one resolution per tick and synchronous shot/dry retirement fences")
	quit(0 if failures == 0 else 1)
