extends CharacterBody3D

const WEAPONS = [
	{"name":"IMPACT TOOL","asset":"impact_tool","damage":28,"interval":0.36,"range":2.7,"pellets":1},
	{"name":"RIVET PISTOL","asset":"rivet_pistol","damage":22,"interval":0.21,"range":140.0,"pellets":1},
	{"name":"SCATTERGUN","asset":"scattergun","damage":15,"interval":0.7,"range":90.0,"pellets":7},
	{"name":"SAWTOOTH REPEATER","asset":"sawtooth_repeater","damage":15,"interval":0.085,"range":140.0,"pellets":1},
	{"name":"MARROW LAUNCHER","asset":"marrow_launcher","damage":110,"interval":0.8,"range":140.0,"pellets":1},
	{"name":"CHOIR DISRUPTOR","asset":"choir_disruptor","damage":40,"interval":0.16,"range":140.0,"pellets":3}]
var game: Node
var camera: Camera3D
var cooldown: float = 0.0
var shot_flash: float = 0.0
var stride: float = 0.0
var recoil: float = 0.0

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
	if game == null or not game.playing: return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(event.relative * game.settings.sensitivity * 0.002)

func look(delta: Vector2) -> void:
	rotation.y -= delta.x
	camera.rotation.x = clampf(camera.rotation.x - delta.y * (-1 if game.settings.invert_y else 1), -1.35, 1.35)

func _physics_process(delta: float) -> void:
	if game == null or not game.playing or game.state.health <= 0: return
	cooldown = maxf(0,cooldown-delta)
	shot_flash = maxf(0,shot_flash-delta)
	recoil = move_toward(recoil,0,delta*7)
	var axes = Input.get_vector("move_left","move_right","move_forward","move_back")
	var direction = basis * Vector3(axes.x,0,axes.y)
	velocity.x = move_toward(velocity.x,direction.x*9.0,delta*50)
	velocity.z = move_toward(velocity.z,direction.z*9.0,delta*50)
	if not is_on_floor(): velocity.y -= delta*24
	else: velocity.y = -0.5
	move_and_slide()
	var stick = Input.get_vector("look_left","look_right","look_up","look_down")
	look(stick * delta * 2.6 * game.settings.sensitivity)
	stride += Vector2(velocity.x,velocity.z).length()*delta
	camera.position.y = 1.55 + (sin(stride*1.8)*0.035 if game.settings.head_bob else 0.0)
	if game.settings.camera_shake: camera.position.x = sin(shot_flash*200)*shot_flash*0.1
	else: camera.position.x = 0
	if Input.is_action_pressed("fire"): fire()
	if Input.is_action_just_pressed("interact"): game.interact()
	if Input.is_action_just_pressed("weapon_next"): cycle_weapon(1)
	if Input.is_action_just_pressed("weapon_previous"): cycle_weapon(-1)
	for index in range(6):
		if Input.is_action_just_pressed("weapon_"+str(index+1)) and index in game.state.owned_weapons:
			game.state.weapon = index
	game.state.position = position
	if position.y < -12: game.hurt_player(200)

func cycle_weapon(direction: int) -> void:
	var inventory = game.state.owned_weapons
	var index = inventory.find(game.state.weapon)
	game.state.weapon = inventory[posmod(index+direction,inventory.size())]

func fire() -> bool:
	if not game.playing or cooldown > 0 or game.state.health <= 0: return false
	var index = game.state.weapon
	if index > 0 and game.state.ammo[index] <= 0: return false
	if index > 0: game.state.ammo[index] -= 1
	var weapon = WEAPONS[index]
	cooldown = weapon.interval
	shot_flash = 0.12
	recoil = 1
	game.shot(index)
	for pellet in range(weapon.pellets):
		var direction = -camera.global_basis.z
		if weapon.pellets > 1:
			direction = (direction + camera.global_basis.x*randf_range(-0.065,0.065) + camera.global_basis.y*randf_range(-0.045,0.045)).normalized()
		var query = PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position+direction*weapon.range,1|4)
		query.exclude = [get_rid()]
		var hit = get_world_3d().direct_space_state.intersect_ray(query)
		if game.settings.auto_aim and (hit.is_empty() or not hit.collider.has_method("take_damage")):
			var target = game.autoaim_target(camera.global_position,direction,weapon.range)
			if target != null:
				query.to = target.global_position + Vector3(0,0.85,0)
				hit = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			if hit.collider.has_method("take_damage"):
				hit.collider.take_damage(weapon.damage,self)
				game.hit_feedback()
			game.impact(hit.position)
	return true
