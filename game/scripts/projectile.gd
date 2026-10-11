extends Node3D

const SPEED = 12.0
const DAMAGE = 14
const MARROW_SPEED = 24.0
const BLAST_RADIUS = 4.0
var game: Node
var shooter: CollisionObject3D
var velocity: Vector3
var lifetime: float = 4.0
var blast_damage: int = 0

func configure(owner_game: Node, source: CollisionObject3D, origin: Vector3, destination: Vector3, marrow_damage: int = 0) -> void:
	game = owner_game
	shooter = source
	blast_damage = marrow_damage
	global_position = origin
	velocity = (destination-origin).normalized()*(MARROW_SPEED if blast_damage > 0 else SPEED)
	if blast_damage > 0:
		if game.has_method("ammo_visuals"):
			var visuals = game.ammo_visuals()
			if visuals != null: visuals.marrow(self)
		return
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
	if not _current_map():
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
		if blast_damage > 0:
			# Offset toward the exposed side, never through thin cover to the hidden victims.
			_blast(hit.position+hit.normal*0.05,hit.collider)
		elif hit.collider == game.player:
			game.hurt_player(int(DAMAGE*[0.7,1.0,1.4][game.state.difficulty]))
		elif hit.collider.has_method("take_damage"):
			hit.collider.take_damage(DAMAGE,shooter if is_instance_valid(shooter) else null,{"attack_kind":"projectile","incoming_direction":velocity.normalized(),"hit_position":hit.position})
		if _current_map() and game.playing and game.has_method("impact"):
			game.impact(hit.position)
		return
	global_position = end
	lifetime = maxf(0,lifetime-delta)
	if lifetime <= 0: queue_free()

func _current_map() -> bool:
	return is_instance_valid(game) and not game.is_queued_for_deletion() and is_instance_valid(game.level) and game.level == get_parent() and not game.level.is_queued_for_deletion()

func _blast(origin: Vector3, direct_hit: Node) -> void:
	var victims: Array = game.enemies.duplicate()
	victims.append(game.player)
	for victim in victims:
		if not _current_map() or not game.playing: return
		if not is_instance_valid(victim) or victim.is_queued_for_deletion() or victim.get_parent() != get_parent(): continue
		var is_player: bool = victim == game.player
		if (game.state.health if is_player else victim.hp) <= 0: continue
		var center: Vector3 = victim.global_position+Vector3.UP*0.85
		var distance: float = origin.distance_to(center)
		if victim != direct_hit:
			if distance >= BLAST_RADIUS: continue
			var sight = PhysicsRayQueryParameters3D.create(origin,center,1)
			sight.hit_from_inside = true
			if not get_world_3d().direct_space_state.intersect_ray(sight).is_empty(): continue
		var amount: int = blast_damage if victim == direct_hit else maxi(1,int(round(blast_damage*(1.0-distance/BLAST_RADIUS))))
		if is_player:
			game.hurt_player(int(amount*[0.7,1.0,1.4][game.state.difficulty]))
		else:
			victim.take_damage(amount,shooter if is_instance_valid(shooter) else null,{"attack_kind":"blast","origin":origin})
			if _current_map() and game.playing and game.has_method("hit_feedback"): game.hit_feedback()
