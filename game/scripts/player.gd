extends CharacterBody3D

const Projectile = preload("res://scripts/projectile.gd")
const WEAPONS = [
	{"name":"IMPACT TOOL","asset":"impact_tool","damage":28,"interval":0.36,"range":2.7,"pellets":1,"max_ammo":0,"low_ammo":0,"useful_range":2.7},
	{"name":"RIVET PISTOL","asset":"rivet_pistol","damage":22,"interval":0.21,"range":140.0,"pellets":1,"max_ammo":180,"low_ammo":20,"useful_range":140.0},
	{"name":"SCATTERGUN","asset":"scattergun","damage":15,"interval":0.7,"range":32.0,"pellets":7,"max_ammo":32,"low_ammo":4,"useful_range":8.0},
	{"name":"SAWTOOTH REPEATER","asset":"sawtooth_repeater","damage":15,"interval":0.085,"range":140.0,"pellets":1,"max_ammo":240,"low_ammo":30,"useful_range":24.0},
	{"name":"MARROW LAUNCHER","asset":"marrow_launcher","damage":110,"interval":0.8,"range":96.0,"pellets":1,"max_ammo":24,"low_ammo":3,"useful_range":48.0},
	{"name":"CHOIR DISRUPTOR","asset":"choir_disruptor","damage":40,"interval":0.16,"range":24.0,"pellets":3,"max_ammo":120,"low_ammo":12,"useful_range":16.0}]
const SPREAD = [Vector2.ZERO,Vector2(-0.065,0),Vector2(0.065,0),Vector2(-0.0325,-0.039),Vector2(0.0325,-0.039),Vector2(-0.0325,0.039),Vector2(0.0325,0.039)]
var game: Node
var camera: Camera3D
var weapon_cooldowns: Array[float] = [0.0,0.0,0.0,0.0,0.0,0.0]
var cooldown: float:
	get:
		return weapon_cooldowns[game.state.weapon] if game != null else 0.0
	set(value):
		if game != null: weapon_cooldowns[game.state.weapon] = maxf(0,value)
var dry_fire_time: float = 0.0
var shot_flash: float = 0.0
var stride: float = 0.0
var recoil: float = 0.0
var _repeater_spread: float = 0.0
var active_play_time: float = 0.0
var _last_shots: Array[float] = [-INF,-INF,-INF,-INF,-INF,-INF]
var _repeat_weapon: int = -1
var _fire_pressed: bool = false
var _weapon_intent: int = -1
var _fire_release_required: bool = false
var _interact_release_required: bool = false

func configure(owner_game: Node) -> void:
	game = owner_game
	collision_layer = 2
	collision_mask = 1 | 4
	floor_snap_length = 0.5
	var shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.65
	shape.shape = capsule
	shape.position.y = 0.85
	add_child(shape)
	camera = Camera3D.new()
	camera.position.y = 1.55
	camera.fov = 85
	camera.near = 0.08
	add_child(camera)
	camera.current = true

func _unhandled_input(event: InputEvent) -> void:
	if not _current_map() or not game.playing: return
	if event is InputEventMouseMotion:
		look(event.screen_relative * game.settings.sensitivity * 0.002)
	if event.is_action_released("interact"): _interact_release_required = false
	if event.is_action_pressed("interact") and not event.is_echo() and not _interact_release_required and game.has_method("_queue_interaction_input"):
		game._queue_interaction_input(self)
	if event.is_action_released("fire"):
		_end_repeat()
		_fire_release_required = false
	if event.is_action_pressed("fire") and not event.is_echo() and not _fire_release_required:
		_fire_pressed = true
	if not event.is_echo():
		if event.is_action_pressed("weapon_next"): _weapon_intent = 6
		if event.is_action_pressed("weapon_previous"): _weapon_intent = 7
		for index in range(6):
			if event.is_action_pressed("weapon_"+str(index+1)): _weapon_intent = index

func look(delta: Vector2) -> void:
	if delta != Vector2.ZERO and game.has_method("clear_observations"): game.clear_observations()
	rotation.y -= delta.x
	camera.rotation.x = clampf(camera.rotation.x - delta.y * (-1 if game.settings.invert_y else 1), -1.35, 1.35)

func _physics_process(delta: float) -> void:
	if not _current_map() or not game.playing or game.state.health <= 0: return
	var held := Input.is_action_pressed("fire") and not _fire_release_required
	if _repeat_weapon >= 0 and (not held or _repeat_weapon != game.state.weapon): _end_repeat()
	active_play_time += delta
	for index in range(weapon_cooldowns.size()):
		var remaining := weapon_cooldowns[index]-delta
		weapon_cooldowns[index] = remaining if index == _repeat_weapon and held else maxf(0,remaining)
	if not Input.is_action_pressed("fire"): _fire_release_required = false
	if not Input.is_action_pressed("interact"): _interact_release_required = false
	if game.state.weapon != 3 or not Input.is_action_pressed("fire"):
		_repeater_spread = move_toward(_repeater_spread,0,delta*0.06)
	dry_fire_time = maxf(0,dry_fire_time-delta)
	shot_flash = maxf(0,shot_flash-delta)
	recoil = move_toward(recoil,0,delta*7)
	var axes = Input.get_vector("move_left","move_right","move_forward","move_back")
	var direction = basis * Vector3(axes.x,0,axes.y)
	var planar := Vector2(velocity.x,velocity.z).move_toward(Vector2(direction.x,direction.z)*9.0,delta*50)
	velocity.x = planar.x
	velocity.z = planar.y
	if not is_on_floor(): velocity.y -= delta*24
	else: velocity.y = -0.5
	move_and_slide()
	var stick = Input.get_vector("look_left","look_right","look_up","look_down")
	look(stick * delta * 2.6 * game.settings.sensitivity)
	stride += Vector2(velocity.x,velocity.z).length()*delta
	camera.position.y = 1.55 + (sin(stride*1.8)*0.035 if game.settings.head_bob else 0.0)
	if game.settings.camera_shake: camera.position.x = sin(shot_flash*200)*shot_flash*0.1
	else: camera.position.x = 0
	var interaction: bool = game._consume_interaction_input(self,not _interact_release_required) if game.has_method("_consume_interaction_input") else false
	if interaction: game.interact()
	if not _current_map() or not game.playing: return # Interaction may retire this player/map.
	var selection := _weapon_intent
	_weapon_intent = -1
	if selection < 0:
		if Input.is_action_just_pressed("weapon_next"): selection = 6
		if Input.is_action_just_pressed("weapon_previous"): selection = 7
		for index in range(6):
			if Input.is_action_just_pressed("weapon_"+str(index+1)): selection = index
	if selection == 6: cycle_weapon(1)
	elif selection == 7: cycle_weapon(-1)
	elif selection in game.state.owned_weapons: game.state.weapon = selection
	if _repeat_weapon >= 0 and _repeat_weapon != game.state.weapon: _end_repeat()
	var attempt := _fire_pressed or (Input.is_action_pressed("fire") and not _fire_release_required)
	_fire_pressed = false
	var fired := fire() if attempt else false
	if not _current_map() or not game.playing: return
	if not fired and game.has_method("observe_player"): game.observe_player()
	elif fired and game.has_method("observe_interaction"): game.observe_interaction()
	if game.has_method("update_passive_triggers"): game.update_passive_triggers(self)
	if not _current_map() or not game.playing: return
	game.state.position = position
	game.state.yaw = preload("res://scripts/enemy.gd").canonical_yaw(rotation.y)
	# Native float32 Euler limits can round beyond the serialized +/-1.35 bound.
	game.state.pitch = clampf(camera.rotation.x,-1.35,1.35)
	if position.y < -12: game.hurt_player(200)

func cycle_weapon(direction: int) -> void:
	var inventory = game.state.owned_weapons
	var index = inventory.find(game.state.weapon)
	game.state.weapon = inventory[posmod(index+direction,inventory.size())]

func shot_age(index: int = -1) -> float:
	if index < 0: index = game.state.weapon
	return active_play_time-_last_shots[index]

func weapon_frame() -> int:
	var age := shot_age()
	var interval: float = WEAPONS[game.state.weapon].interval
	if age >= interval: return 0
	return 1 if age < interval*0.5 else 2

func _end_repeat() -> void:
	if _repeat_weapon < 0: return
	var index := _repeat_weapon
	weapon_cooldowns[index] = maxf(weapon_cooldowns[index],WEAPONS[index].interval-shot_age(index))
	_repeat_weapon = -1

func cancel_actions() -> void:
	velocity = Vector3.ZERO
	if game.has_method("clear_observations"): game.clear_observations()
	_end_repeat()
	_fire_pressed = false
	_weapon_intent = -1
	if game != null and game.has_method("_cancel_interaction_input"): game._cancel_interaction_input(self)
	_fire_release_required = Input.is_action_pressed("fire")
	_interact_release_required = Input.is_action_pressed("interact")

func fire() -> bool:
	if not Engine.is_in_physics_frame(): return false
	if not _current_map() or not game.playing or game.state.health <= 0: return false
	var index = game.state.weapon
	if index > 0 and game.state.ammo[index] <= 0:
		if dry_fire_time <= 0:
			dry_fire_time = 0.35
			if game.has_method("dry_fire"): game.dry_fire(index)
			if not _current_map() or not game.playing: return false
		var inventory = game.state.owned_weapons
		var selected = inventory.find(index)
		game.state.weapon = 0
		for offset in range(1,inventory.size()+1):
			var candidate = inventory[posmod(selected+offset,inventory.size())]
			if candidate > 0 and game.state.ammo[candidate] > 0:
				game.state.weapon = candidate
				break
		_end_repeat()
		return false
	if cooldown > 0: return false
	if index > 0: game.state.ammo[index] -= 1
	var weapon = WEAPONS[index]
	var held := Input.is_action_pressed("fire") and not _fire_release_required
	var recovery: float = weapon.interval
	if _repeat_weapon == index and held:
		recovery += cooldown
		# Skip missed slots after a hitch; never discharge more than once in this tick.
		if recovery <= 0:
			recovery = weapon.interval-fposmod(-cooldown,weapon.interval)
		if is_zero_approx(recovery): recovery = weapon.interval
	cooldown = recovery
	_last_shots[index] = active_play_time
	_repeat_weapon = index if held else -1
	shot_flash = 0.12
	recoil = 1
	game.shot(index)
	if not _current_map() or not game.playing: return true
	var origin = camera.global_position
	var direction = -camera.global_basis.z
	var query = PhysicsRayQueryParameters3D.create(origin,origin+direction*weapon.range,1|4)
	query.exclude = [get_rid()]
	var space = get_world_3d().direct_space_state
	if game.has_method("resolve_aim"):
		var solution: Dictionary = game.resolve_aim(origin,direction,weapon.range,index == 0)
		direction = solution.direction
		game.aim_observation = solution
	if index == 4:
		var projectile = Projectile.new()
		game.level.add_child(projectile)
		projectile.configure(game,self,origin,origin+direction*weapon.range,weapon.damage)
		return true
	if index == 5:
		query.to = origin+direction*weapon.range
		query.hit_from_inside = true
		var endpoint: Vector3 = query.to
		for actor_hit in range(weapon.pellets):
			if not _current_map() or not game.playing: break
			var hit = space.intersect_ray(query)
			if hit.is_empty(): break
			if (hit.collider.collision_layer & 1) != 0 or not hit.collider.has_method("take_damage"):
				endpoint = hit.position
				if game.has_method("impact"): game.impact(hit.position)
				break
			if actor_hit == weapon.pellets-1: endpoint = hit.position
			# Keep the same finite ray, excluding each real capsule once; walls remain queryable.
			query.exclude = query.exclude+[hit.collider.get_rid()]
			hit.collider.take_damage(weapon.damage,self,{"attack_kind":"piercing","weapon":index,"origin":origin,"incoming_direction":direction,"hit_position":hit.position})
			if not _current_map() or not game.playing: break
			if game.has_method("hit_feedback"): game.hit_feedback()
			if _current_map() and game.playing and game.has_method("impact"): game.impact(hit.position)
		if _current_map() and game.playing and game.has_method("ammo_visuals"):
			var visuals = game.ammo_visuals()
			if visuals != null: visuals.trace(index,origin,endpoint)
		return true
	var right = direction.cross(camera.global_basis.y).normalized()
	var up = right.cross(direction).normalized()
	for pellet in range(weapon.pellets):
		if not _current_map() or not game.playing: break
		var spread = SPREAD[pellet] if weapon.pellets > 1 else Vector2.ZERO
		if index == 3:
			spread = Vector2.from_angle(randf()*TAU)*_repeater_spread*sqrt(randf())
			_repeater_spread = minf(0.07,_repeater_spread+0.004)
		var ray_direction = (direction+right*spread.x+up*spread.y).normalized()
		query.to = origin+ray_direction*weapon.range
		var hit = space.intersect_ray(query)
		if index > 0 and game.has_method("ammo_visuals"):
			var visuals = game.ammo_visuals()
			if visuals != null: visuals.trace(index,origin,hit.position if not hit.is_empty() else query.to)
		if not hit.is_empty():
			if hit.collider.has_method("take_damage"):
				var damage: int = weapon.damage
				if index == 2:
					var falloff = clampf((origin.distance_to(hit.position)-weapon.useful_range)/(weapon.range-weapon.useful_range),0,1)
					damage = maxi(1,int(round(weapon.damage*lerpf(1.0,0.2,falloff))))
				hit.collider.take_damage(damage,self,{"attack_kind":"melee" if index == 0 else "hitscan","weapon":index,"origin":origin,"incoming_direction":ray_direction,"hit_position":hit.position})
				if not _current_map() or not game.playing: break
				if game.has_method("hit_feedback"): game.hit_feedback()
			if not _current_map() or not game.playing: break
			if game.has_method("impact"): game.impact(hit.position)
	return true

func _current_map() -> bool:
	return is_instance_valid(game) and not game.is_queued_for_deletion() and is_instance_valid(game.level) and game.level == get_parent() and not game.level.is_queued_for_deletion() and game.player == self and not is_queued_for_deletion()
