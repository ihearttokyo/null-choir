extends SceneTree

# Actual Nursery collision, controlled active boss; not an earned campaign fight.
class Step extends Node:
	var actor
	var remaining := 40
	var travel := 0.0
	func _physics_process(delta: float) -> void:
		if remaining <= 0: return
		var before: Vector3 = actor.global_position
		actor._physics_process(delta)
		travel += actor.global_position.distance_to(before)
		remaining -= 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var game = preload("res://scripts/main.gd").new()
	game.settings_path = "user://boss_corner_preferences.json"
	game.progress_path = "user://boss_corner_campaign.json"
	root.add_child(game)
	game.set_process(false)
	game.hud.survey.set_physics_process(false)
	game.state.new_campaign(1)
	game.state.level_index = 4
	await game.start_level()
	game.player.set_physics_process(false)
	var actor
	for enemy in game.enemies:
		enemy.set_physics_process(false)
		if enemy.kind == "nursery_warden": actor = enemy
	game.player.position = Vector3(147.53,.04,16.47)
	actor.active = true
	actor.alerted = true
	actor.target = game.player
	var routes = game.level.get_node("NavigationRoutes")
	var deadline := Time.get_ticks_usec()+3000000
	while not routes.is_ready(actor.kind) and Time.get_ticks_usec()<deadline:
		OS.delay_msec(2)
		await process_frame
		await physics_frame
	var collider: CollisionShape3D
	for child in game.player.get_children():
		if child is CollisionShape3D: collider = child
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.transform = collider.global_transform
	query.collision_mask = 1
	var clear: bool = game.level.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
	var initial: float = actor.global_position.distance_to(game.player.global_position)
	var initial_position: Vector3 = actor.global_position
	var next: Vector3 = actor._next_step(game.player.global_position)
	var step := Step.new()
	step.actor = actor
	root.add_child(step)
	while step.remaining > 0: await physics_frame
	var progressed: bool = next.distance_to(initial_position) > .01 and step.travel > .8 and actor.global_position.distance_to(game.player.global_position) < initial-.5
	print("BOSS_CORNER ",JSON.stringify({"player_capsule_clear":clear,"initial_range":initial,"travel":step.travel,"remaining_range":actor.global_position.distance_to(game.player.global_position),"ready":routes.is_ready(actor.kind),"controlled_staging":true}))
	step.free()
	game.show_title()
	game.free()
	paused = false
	OS.delay_msec(100)
	await process_frame
	await process_frame
	if not clear or initial < 30 or initial > 34:
		push_error("SETUP actual valid player corner must alert the boss outside attack reach")
		quit(2)
		return
	if not progressed:
		push_error("Eligible Nursery boss must approach the valid player corner despite role-sized goal clearance")
		quit(1)
		return
	print("PASS actual Nursery boss approaches capsule-clear player wall corner; controlled forty-tick pursuit")
	quit(0)
