extends Node3D

const SPEED = 12.0
const DAMAGE = 14
var game: Node
var shooter: CollisionObject3D
var velocity: Vector3
var lifetime: float = 4.0

func configure(owner_game: Node, source: CollisionObject3D, origin: Vector3, destination: Vector3) -> void:
	game = owner_game
	shooter = source
	global_position = origin
	velocity = (destination-origin).normalized()*SPEED
	var mesh = MeshInstance3D.new()
	mesh.mesh = SphereMesh.new()
	mesh.mesh.radius = 0.18
	mesh.mesh.height = 0.36
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0,0.3,0.12)
	material.emission_enabled = true
	material.emission = material.albedo_color
	material.emission_energy_multiplier = 3.0
	mesh.material_override = material
	add_child(mesh)
	var light = OmniLight3D.new()
	light.light_color = material.albedo_color
	light.light_energy = 2.0
	light.omni_range = 3.0
	add_child(light)

func _physics_process(delta: float) -> void:
	if is_queued_for_deletion(): return
	if not is_instance_valid(game) or game.level != get_parent():
		queue_free()
		return
	if not game.playing: return
	var end = global_position+velocity*minf(delta,lifetime)
	var query = PhysicsRayQueryParameters3D.create(global_position,end,1|2|4)
	query.exclude = [shooter.get_rid()] if is_instance_valid(shooter) else []
	query.hit_from_inside = true
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position
		queue_free()
		if hit.collider == game.player:
			game.hurt_player(int(DAMAGE*[0.7,1.0,1.4][game.state.difficulty]))
		elif hit.collider.has_method("take_damage"):
			hit.collider.take_damage(DAMAGE,shooter if is_instance_valid(shooter) else null)
		return
	global_position = end
	lifetime = maxf(0,lifetime-delta)
	if lifetime <= 0: queue_free()
