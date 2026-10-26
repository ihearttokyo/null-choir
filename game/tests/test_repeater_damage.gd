extends SceneTree

class ObservedGame extends "res://scripts/main.gd":
	func _capture_game_mouse() -> void: pass

class ObservedWorker extends "res://scripts/enemy.gd":
	var hits: Array = []
	func take_damage(amount: int, source: Node3D, context: Dictionary = {}) -> void:
		super.take_damage(amount,source,context)
		hits.append({"amount":amount,"hp_after":hp,"physics":Engine.is_in_physics_frame(),"tick":Engine.get_physics_frames(),"ray":context.get("incoming_direction"),"weapon":context.get("weapon"),"player_source":source==game.player})

var game

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func run() -> void:
	game = ObservedGame.new()
	var prefix = "user://repeater_role_"+str(OS.get_process_id())
	game.progress_path = prefix+"_campaign.json"
	game.settings_path = prefix+"_preferences.json"
	root.add_child(game)
	Input.action_release("fire")
	game.set_process(false)
	game.set_process_unhandled_input(false)
	game.settings.auto_aim = false
	game.settings.head_bob = false
	game.settings.camera_shake = false
	game.state.new_campaign(0)
	game.level = game.Level.new()
	game.add_child(game.level)
	game.level.process_mode = Node.PROCESS_MODE_PAUSABLE
	if not game.level.layout.load_level(0): await finish(2);return
	game.level._box(Vector3(30,1,30),Vector3(0,-0.5,-8),game.level._material(Color.WHITE),true)
	game.player = game.Player.new()
	game.level.add_child(game.player)
	game.player.configure(game)
	game.player.position = Vector3(0,0.04,0)
	game.player.set_process_unhandled_input(false)
	game.state.owned_weapons.assign([0,1,3])
	game.state.ammo.assign([0,90,0,6,0,0])
	game.state.weapon = 3
	var actor = ObservedWorker.new()
	game.level.add_child(actor)
	actor.configure(game,{"id":"role_worker","kind":"worker","cell":[0.5,0.5],"yaw":0})
	actor.position = Vector3(0,0.03,-3)
	actor.set_physics_process(false)
	game.enemies.append(actor)
	game.playing = true
	paused = false
	await physics_frame
	await physics_frame
	if actor.hp!=76:
		push_error("SETUP: natural Merciful worker must have76HP")
		await finish(2);return
	var origin: Vector3 = game.player.camera.global_position
	var query = PhysicsRayQueryParameters3D.create(origin,origin+Vector3.FORWARD*10,1|4)
	query.exclude = [game.player.get_rid()]
	var hit = game.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.collider!=actor:
		push_error("SETUP: actual native ray must see natural worker capsule")
		await finish(2);return
	seed(20261018)
	Input.action_press("fire")
	var deadline = Time.get_ticks_msec()+2500
	while actor.hits.size()<5 and Time.get_ticks_msec()<deadline: await physics_frame
	Input.action_release("fire")
	if actor.hits.size()!=5 or game.state.ammo[3]!=1 or not actor.hits.all(func(hit): return hit.physics and hit.player_source and hit.weapon==3):
		push_error("SETUP: five genuine native hits must spend five rounds")
		await finish(2);return
	for index in range(5):
		if actor.hits[index].amount != 16 or actor.hits[index].hp_after != maxi(0,76-16*(index+1)):
			push_error("INTENDED RED: each native repeater hit must deal16 to natural76HP worker")
			await finish(1);return
	print("MEASURE first_hp=",actor.hits[0].hp_after," final_hp=",actor.hp," spent=",6-game.state.ammo[3])
	if actor.hits[0].hp_after!=60:
		push_error("INTENDED RED: first repeater hit must deal16 to natural76HP worker")
		await finish(1);return
	if actor.hp!=0 or not "role_worker" in game.state.removed:
		push_error("Five confirmed16damage hits must naturally kill the76HP worker")
		await finish(1);return
	print("PASS native repeater16: real heldfire, five rounds, first60HP and natural fifth-hit death")
	await finish(0)

func finish(status: int) -> void:
	Input.action_release("fire")
	var recording: WeakRef
	if is_instance_valid(game):
		game.show_title()
		recording = weakref(game.music.player.stream)
		game.music.stop()
		game.effects.stop()
	paused = false
	if is_instance_valid(game): game.queue_free()
	await process_frame
	# Title playback belongs to this fixture. Let the native mixer release it,
	# checking actual resource lifetime rather than sleeping or ignoring leaks.
	var deadline: int = Time.get_ticks_usec() + 2000000
	while recording != null and recording.get_ref() != null and Time.get_ticks_usec() < deadline:
		OS.delay_msec(2)
		await process_frame
	if recording != null and recording.get_ref() != null:
		push_error("Fixture-owned title recording must be released before exit")
		status = 1
	quit(status)
