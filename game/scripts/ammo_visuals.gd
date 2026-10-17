extends Node3D

const ATLAS = preload("res://assets/art/effects/ammo_vfx.png")
const CAPACITY = 32
var game: Node
var slots: Array[Dictionary] = []
var next_slot: int = 0

func _current_map() -> bool:
	return is_instance_valid(game) and not game.is_queued_for_deletion() and is_instance_valid(game.level) and get_parent() == game.level and not game.level.is_queued_for_deletion()

func _spawn(row: int, point: Vector3, duration: float, motion: Vector3 = Vector3.ZERO, target: Node3D = null) -> Dictionary:
	if not _current_map() or not game.playing: return {}
	var slot: Dictionary = {}
	for candidate in slots:
		if not candidate.sprite.visible:
			slot = candidate
			break
	if slot.is_empty():
		if slots.size() < CAPACITY:
			var sprite = Sprite3D.new()
			sprite.texture = ATLAS
			sprite.hframes = 4
			sprite.vframes = 4
			sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			sprite.shaded = false
			sprite.add_to_group("ammo_visuals")
			add_child(sprite)
			slot = {"sprite":sprite}
			slots.append(slot)
		else:
			# Cosmetic saturation never changes a projectile, hit or ammunition.
			for attempt in range(CAPACITY):
				var candidate = slots[next_slot]
				next_slot = (next_slot+1)%CAPACITY
				var target_ref = candidate.target.get_ref() if candidate.target != null else null
				if is_instance_valid(target_ref) and not target_ref.is_queued_for_deletion(): continue
				if candidate.route: continue
				slot = candidate
				break
			if slot.is_empty(): return {}
	slot.age = 0.0
	slot.duration = duration
	slot.row = row
	slot.motion = motion
	slot.target = weakref(target) if target != null else null
	slot.route = false
	slot.sprite.frame = row*4
	slot.sprite.pixel_size = 0.0012 if row == 1 else 0.012
	slot.sprite.rotation.z = 0
	slot.sprite.global_position = point
	slot.sprite.visible = true
	return slot

func trace(weapon: int, origin: Vector3, endpoint: Vector3) -> void:
	if not origin.is_finite() or not endpoint.is_finite(): return
	var slot = _spawn(3 if weapon == 5 else 0,origin,clampf(origin.distance_to(endpoint)/180.0,0.07,0.24))
	if slot.is_empty(): return
	# Damage already resolved; the captured ray is cosmetic, including its arrival.
	slot.route = true
	slot.start = origin
	slot.end = endpoint
	slot.sprite.pixel_size = 0.004 if weapon == 5 else 0.0018

func impact(point: Vector3) -> void:
	_spawn(3,point,0.28)

func casing(player: Node3D) -> void:
	var right: Vector3 = player.camera.global_basis.x
	_spawn(1,player.camera.global_position+right*0.24-player.camera.global_basis.z*0.45-Vector3.UP*0.18,0.6,right*2.5+Vector3.UP*1.3)

func marrow(projectile: Node3D) -> void:
	_spawn(2,projectile.global_position,projectile.lifetime,Vector3.ZERO,projectile)

func _process(delta: float) -> void:
	if not _current_map() or not game.playing: return
	for slot in slots:
		var sprite: Sprite3D = slot.sprite
		if not sprite.visible: continue
		slot.age += delta
		if slot.route:
			sprite.global_position = slot.start.lerp(slot.end,minf(slot.age/slot.duration,1.0))
		elif slot.target != null:
			var target = slot.target.get_ref()
			if not is_instance_valid(target) or target.is_queued_for_deletion() or target.get_parent() != get_parent():
				sprite.visible = false
				continue
			sprite.global_position = target.global_position
		else:
			sprite.position += slot.motion*delta
			if slot.row == 1:
				slot.motion.y -= 9.8*delta
				sprite.rotation.z += delta*9
		if slot.target == null and slot.age >= slot.duration:
			sprite.visible = false
		else:
			sprite.frame = slot.row*4+mini(3,int(slot.age/(0.09 if slot.row == 2 else slot.duration/4.0))%4)
