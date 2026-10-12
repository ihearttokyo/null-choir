extends SceneTree

const ExitFixture = preload("res://tests/test_processional_earned_exit.gd")
class ProbeMain:
	extends "res://tests/test_processional_earned_exit.gd".ExitMain
	var witnessed: bool = false
	var death_count: int = 0
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func enemy_event(actor, event: String) -> void:
		if event == "attack": x_attacks[actor.id] = Engine.get_physics_frames()
		if event == "death":
			death_count += 1
			witnessed = Engine.is_in_physics_frame() and witnessed_infighting(actor)

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func run() -> void:
	for role in ["worker","crawler"]:
		var game = ProbeMain.new()
		root.add_child(game)
		game.state.new_campaign(1)
		for value in [-25.7,-PI,-3.1415925,-0.3,0.0,0.7,PI,25.7]:
			var saved: float = game.observed_yaw(value)
			if not is_finite(saved) or saved < -PI or saved >= PI or absf(angle_difference(saved,value)) > 0.000002:
				push_error("Independent observed facing must be finite/canonical/angular-equivalent")
				game.free()
				quit(1)
				return
		game.level = game.Level.new()
		game.add_child(game.level)
		game.level.layout.load_level(0)
		var base: Vector3 = game.level.layout.world_position(game.level.layout.data.spawn)
		game.level._box(Vector3(60,1,60),base+Vector3(0,-0.5,-12),game.level._material(Color.WHITE),true)
		game.player = game.Player.new()
		game.level.add_child(game.player)
		game.player.configure(game)
		game.player.position = base+Vector3(15,0.04,-16)
		game.player.set_physics_process(false)
		game.player.set_process_unhandled_input(false)
		var source = game.Enemy.new()
		game.level.add_child(source)
		source.configure(game,{"id":"processional_enemy_23","kind":role,"cell":game.level.layout.data.spawn,"yaw":0})
		source.set_physics_process(false)
		var victim = game.Enemy.new()
		game.level.add_child(victim)
		victim.configure(game,{"id":"processional_enemy_25","kind":"worker","cell":game.level.layout.data.spawn,"yaw":180})
		victim.position = base+Vector3(0,0.03,-1.3 if role == "crawler" else -8.0)
		victim.hp = 10 # Synthetic one-hit setup, not earned campaign resources.
		victim.set_physics_process(false)
		source.target = victim
		source.alerted = true
		game.enemies = [source,victim]
		for actor in game.enemies: game.x_bindings[actor.id] = actor.get_instance_id()
		await physics_frame
		await physics_frame
		if game.witnessed_infighting(victim):
			push_error("No real native attack stack must be rejected")
			game.free()
			quit(1)
			return
		game.playing = true
		source.set_physics_process(true)
		for frame in 180:
			await physics_frame
			await process_frame
			if game.death_count > 0: break
		var accepted: bool = game.death_count == 1 and game.witnessed and victim.hp == 0 and victim.target == source and victim.collision_layer == 0 and victim.collision_mask == 0
		game.free()
		await process_frame
		await process_frame
		if not accepted:
			push_error("Automatic native "+role+" infighting death must retain original-source attack-stack provenance")
			quit(1)
			return
	print("PASS synthetic native automatic worker/crawler infighting witness and independent yaw boundaries; not earned campaign or HID/GPU acceptance")
	quit(0)
