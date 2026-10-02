extends CharacterBody3D

var game: Node
var id: String
var kind: String
var hp: int
var alerted: bool = false
var target: Node3D
var attack_time: float = 0
var hurt_time: float = 0
var pose_time: float = 0
var age: float = 0
var path_time: float = 0
var waypoint: Vector3
var sprite: Sprite3D
var speed: float = 4.0

func configure(owner_game: Node, spec: Dictionary) -> void:
	game = owner_game
	id = spec.id
	kind = spec.kind
	hp = int((50 if kind == "crawler" else 90) * [0.85,1.0,1.3][game.state.difficulty])
	speed = 5.4 if kind == "crawler" else 3.1
	position = game.level.layout.world_position(spec.cell) + Vector3(0,0.03,0)
	rotation.y = deg_to_rad(spec.yaw)
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	floor_snap_length = 0.5
	var collider = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.42 if kind == "crawler" else 0.34
	shape.height = 1.1 if kind == "crawler" else 2.7
	collider.shape = shape
	collider.position.y = shape.height/2
	add_child(collider)
	sprite = Sprite3D.new()
	sprite.texture = load("res://assets/art/sprites/"+kind+".png")
	sprite.hframes = 8
	sprite.vframes = 5
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = true
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.pixel_size = (3.8 if kind == "crawler" else 3.65)/128.0
	sprite.position.y = 56 * sprite.pixel_size
	add_child(sprite)

func _physics_process(delta: float) -> void:
	if game == null or not game.playing: return
	age += delta
	hurt_time = maxf(0,hurt_time-delta)
	attack_time = maxf(0,attack_time-delta)
	pose_time = maxf(0,pose_time-delta)
	var camera = game.player.camera
	var view = global_basis.inverse()*(camera.global_position-global_position)
	var direction_index = posmod(int(round(atan2(view.x,-view.z)/TAU*8)),8)
	var frame = 4 if hp <= 0 else 3 if pose_time > 0 else 1+int(age*6)%2 if alerted else 0
	sprite.frame = frame*8+direction_index
	sprite.modulate = Color(1.7,0.7,0.6) if hurt_time > 0 else Color.WHITE
	if hp <= 0: return
	if not is_instance_valid(target) or (target != game.player and target.hp <= 0): target = game.player
	var aim = target.global_position+Vector3(0,1.0,0)
	var query = PhysicsRayQueryParameters3D.create(global_position+Vector3(0,1,0),aim,1)
	var sight = get_world_3d().direct_space_state.intersect_ray(query)
	var range_to_target = global_position.distance_to(target.global_position)
	if range_to_target < 34 and sight.is_empty(): alerted = true
	velocity.y -= delta*24
	if alerted:
		var heading = target.global_position-global_position
		heading.y = 0
		if not sight.is_empty():
			path_time -= delta
			if path_time <= 0:
				waypoint = _next_step(target.global_position)
				path_time = 1.0
			heading = waypoint-global_position
			heading.y = 0
		var move = heading.normalized()
		var desired = 0.0 if kind == "worker" and range_to_target < 18 and sight.is_empty() else speed
		velocity.x = move.x*desired
		velocity.z = move.z*desired
		if heading.length() > 0.2: rotation.y = atan2(-heading.x,-heading.z)
		if attack_time <= 0 and sight.is_empty():
			if kind == "crawler" and range_to_target < 1.9:
				_attack(target,12)
				attack_time = 0.8
			elif kind == "worker" and range_to_target < 30:
				var shot = PhysicsRayQueryParameters3D.create(global_position+Vector3(0,1.4,0),aim,1|2|4)
				shot.exclude = [get_rid()]
				var hit = get_world_3d().direct_space_state.intersect_ray(shot)
				if not hit.is_empty(): _attack(hit.collider,10)
				attack_time = 1.7
	else:
		velocity.x = 0
		velocity.z = 0
	move_and_slide()

func _attack(victim: Node, amount: int) -> void:
	pose_time = 0.22
	if victim == game.player:
		game.hurt_player(int(amount*[0.7,1.0,1.4][game.state.difficulty]))
	elif victim.has_method("take_damage"):
		victim.take_damage(amount,self)

func take_damage(amount: int, source: Node3D) -> void:
	if hp <= 0: return
	hp = maxi(0,hp-amount)
	hurt_time = 0.12
	alerted = true
	if source != self: target = source
	if hp == 0:
		collision_layer = 0
		collision_mask = 0
		velocity = Vector3.ZERO
		if not id in game.state.removed: game.state.removed.append(id)

func _next_step(destination: Vector3) -> Vector3:
	var layout = game.level.layout
	var size = float(layout.data.cell_size)
	var start = Vector2i(floor(global_position.x/size),floor(global_position.z/size))
	var finish = Vector2i(floor(destination.x/size),floor(destination.z/size))
	var queue = [start]
	var previous = {start:start}
	var cursor = 0
	# ponytail: under 1k authored cells; native navigation if profiled map scale exceeds this.
	while cursor < queue.size():
		var cell = queue[cursor]
		cursor += 1
		if cell == finish:
			while previous[cell] != start and cell != start: cell = previous[cell]
			return layout.world_position([cell.x+0.5,cell.y+0.5])
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next = cell+direction
			if layout.is_walkable(next) and not previous.has(next):
				previous[next] = cell
				queue.append(next)
	return global_position
