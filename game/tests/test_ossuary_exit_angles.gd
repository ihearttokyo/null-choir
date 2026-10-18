extends "res://tests/test_interaction_edges.gd"

const Exit = preload("res://tests/ossuary_finale_exit_witness.gd")
const TARGET = {"id":"CONTROLLED_pose_target","kind":"exit","cell":[0.5,-0.5]}

class PoseGame:
	extends "res://tests/test_ammo_input.gd".NativeGame
	var observations: Array = []
	func interact() -> void:
		observations.append({"physics":Engine.is_in_physics_frame(),"lag":state.yaw != Enemy.canonical_yaw(player.rotation.y) or state.pitch != clampf(player.camera.rotation.x,-1.35,1.35),"valid":Exit.valid_angles(player.rotation.y,player.camera.rotation.x,state.yaw,state.pitch),"nearest":nearest_interaction()})

func run() -> void:
	game = PoseGame.new()
	root.add_child(game)
	game.preferences.apply_bindings()
	game.settings.head_bob = false
	game.settings.camera_shake = false
	game.state.new_campaign(1)
	game.level = arena()
	game.level.layout.data.interactions = [TARGET]
	game.level.layout.data.doors = []
	game.player = player_in(game.level,Vector3(0,0.04,0))
	game.playing = true
	for frame in range(12): await physics_frame
	await process_frame
	var ok: bool = expect(game.player.is_on_floor(),"CONTROLLED actual production capsule settled on native floor")
	var saved_yaw: float = game.state.yaw
	var saved_pitch: float = game.state.pitch
	var aim: Vector3 = game.level.layout.world_position(TARGET.cell)+Vector3.UP*0.7
	var heading: Vector3 = aim-game.player.camera.global_position
	game.player.rotation.y = atan2(-heading.x,-heading.z)
	game.player.camera.look_at(aim,Vector3.UP)
	ok = expect(game.state.yaw == saved_yaw and game.state.pitch == saved_pitch and game.state.yaw != game.Enemy.canonical_yaw(game.player.rotation.y),"SETUP native look changes before stored campaign angles synchronize") and ok
	ok = expect(Exit.valid_angles(game.player.rotation.y,game.player.camera.rotation.x,game.state.yaw,game.state.pitch),"NATIVE RED valid lagging angles must not reject prephysics steering") and ok
	# Physical rebound E uses real Main input edge and production Player scheduling.
	physical_edge(true)
	for frame in range(6): await physics_frame
	physical_edge(false)
	for frame in range(6): await physics_frame
	await process_frame
	ok = expect(game.observations.size() == 1 and game.observations[0].physics and game.observations[0].lag and game.observations[0].valid and game.observations[0].nearest == TARGET,"NATIVE RED queued E uses live facing while cached angles may lag") and ok
	ok = expect(game.state.yaw == game.Enemy.canonical_yaw(game.player.rotation.y) and game.state.pitch == clampf(game.player.camera.rotation.x,-1.35,1.35),"Production Player synchronizes actual angles after nonretiring callback") and ok
	for pitch in [-1.35,1.35]:
		game.player.camera.rotation.x = pitch
		ok = expect(Exit.valid_angles(game.player.rotation.y,game.player.camera.rotation.x,game.state.yaw,pitch),"NATIVE RED native float32 pitch endpoint remains valid: "+str(pitch)) and ok
		ok = expect(not Exit.valid_angles(game.player.rotation.y,game.player.camera.rotation.x,game.state.yaw,game.player.camera.rotation.x),"NATIVE RED stored pitch must reject raw float32 endpoint: "+str(pitch)) and ok
	game.player.camera.rotation.x = 0
	for values in [[INF,0.0,0.0,0.0],[0.0,INF,0.0,0.0],[NAN,0.0,0.0,0.0],[0.0,NAN,0.0,0.0],[0.0,1.36,0.0,0.0],[0.0,-1.36,0.0,0.0],[0.0,0.0,INF,0.0],[0.0,0.0,0.0,INF],[0.0,0.0,PI,0.0],[0.0,0.0,-PI-0.01,0.0],[0.0,0.0,0.0,1.36],[0.0,0.0,null,0.0],[0.0,0.0,0.0,null]]:
		ok = expect(not Exit.valid_angles(values[0],values[1],values[2],values[3]),"Invalid native/stored angles reject: "+str(values)) and ok
	game.player.cancel_actions()
	game.playing = false
	game.queue_free()
	await process_frame
	await process_frame
	ok = expect(not is_instance_valid(game) and not Input.is_physical_key_pressed(KEY_E) and not Input.is_action_pressed("interact"),"CONTROLLED fixture and physical key drain without saves") and ok
	AudioServer.set_bus_mute(0,master_muted)
	if ok: print("PASS CONTROLLED C angle predicate/native steering/queued physical E/live facing/posttick sync/endpoints/invalid values; no earned C/save/app")
	quit(0 if ok else 1)

func physical_edge(pressed: bool) -> void:
	var event = InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
