extends Node3D

const Variation = preload("res://scripts/weapon_variation.gd")
const ATLAS = preload("res://assets/art/effects/ammo_vfx.png")
const SHOT_ATLAS = preload("res://assets/art/effects/shot_travel.png")
const CAPACITY = 32
var game: Node
var slots: Array[Dictionary] = []
var next_slot: int = 0

func _current_map() -> bool:
	return is_instance_valid(game) and not game.is_queued_for_deletion() and is_instance_valid(game.level) and get_parent() == game.level and not game.level.is_queued_for_deletion()

func _spawn(row: int, point: Vector3, duration: float, motion: Vector3 = Vector3.ZERO, target: Node3D = null) -> Dictionary:
	if not _current_map() or not game.playing or row < 0 or row > 3 or not point.is_finite() or not motion.is_finite() or not is_finite(duration) or duration <= 0: return {}
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
	slot.frame_bias = 0
	slot.opacity = 1.0
	slot.trail_clock = 0.0
	slot.trail_last = point
	slot.sequence = 0
	slot.sprite.texture = ATLAS
	slot.sprite.frame = row*4
	slot.sprite.pixel_size = 0.0012 if row == 1 else 0.012
	slot.sprite.rotation.z = 0
	slot.sprite.scale = Vector3.ONE
	slot.sprite.modulate = Color.WHITE
	slot.sprite.global_position = point
	slot.sprite.visible = true
	return slot

func _reduced() -> bool:
	return is_instance_valid(game) and game.settings.get("reduced_damage_flashes",false)

func trace(weapon: int, origin: Vector3, endpoint: Vector3, sequence: int = 0) -> void:
	var row: int = {1:0,2:1,3:2,5:3}.get(weapon,-1)
	if row < 0 or not origin.is_finite() or not endpoint.is_finite(): return
	# Hitscan damage is instantaneous: simultaneous finite ray marks, NEVER a
	# cosmetic bullet arriving later. Every point lies on the actual resolved ray.
	var fractions: Array = [1.0] if _reduced() else [.35,.85] if weapon == 1 else [.65] if weapon == 2 else [.5] if weapon == 3 else [.18,.5,.82]
	for fraction in fractions:
		var slot = _spawn(row,origin.lerp(endpoint,fraction),.065 if weapon == 3 else .10)
		if slot.is_empty(): continue
		slot.route = true
		slot.sprite.texture = SHOT_ATLAS
		slot.sprite.pixel_size = .004 if weapon == 5 else .0018
		slot.sprite.modulate = Variation.TINTS[weapon]
		slot.frame_bias = int(Variation.unit(sequence,weapon,50)*2)
		slot.opacity = .3 if _reduced() else .8
		slot.sprite.modulate.a = slot.opacity

func impact(point: Vector3, weapon: int = -1, sequence: int = 0, surface: String = "structure") -> void:
	if weapon < 0: # Original generic hook keeps its declared atlas/scale contract.
		var generic = _spawn(3,point,0.28)
		if not generic.is_empty() and _reduced():
			generic.opacity = .3
			generic.sprite.modulate.a = .3
		return
	if weapon > 5 or surface not in ["structure","flesh"]: return
	var row: int = 2 if weapon == 4 else 3 if weapon == 5 else 0
	var slot = _spawn(row,point,.22 if weapon in [4,5] else .12)
	if slot.is_empty(): return
	slot.sprite.pixel_size = [.0035,.004,.006,.003,.012,.0135][weapon]
	slot.sprite.modulate = Color(.82,.34,.30) if surface == "flesh" else Variation.TINTS[weapon]
	slot.sprite.scale.x = 1.6 if weapon == 2 else 1.0
	slot.frame_bias = int(Variation.unit(sequence,weapon,60)*2)
	slot.opacity = .3 if _reduced() else .85
	slot.sprite.modulate.a = slot.opacity


func casing(player: Node3D, weapon: int = -1, sequence: int = -1) -> void:
	if _reduced(): return
	if weapon < 0: weapon = game.state.weapon
	if sequence < 0: sequence = player.last_shot_sequence(weapon)
	var right: Vector3 = player.camera.global_basis.x
	var speed: float = 2.2+.6*Variation.unit(sequence,weapon,70)
	_spawn(1,player.camera.global_position+right*0.24-player.camera.global_basis.z*0.45-Vector3.UP*0.18,0.6,right*speed+Vector3.UP*1.3)

func marrow(projectile: Node3D) -> void:
	var slot = _spawn(2,projectile.global_position,projectile.lifetime,Vector3.ZERO,projectile)
	if slot.is_empty(): return
	slot.sequence = projectile.visual_sequence
	slot.sprite.modulate = Variation.TINTS[4]


func _process(delta: float) -> void:
	if not _current_map() or not game.playing: return
	var trails: Array = []
	for slot in slots:
		var sprite: Sprite3D = slot.sprite
		if not sprite.visible: continue
		slot.age += delta
		if slot.target != null:
			var target = slot.target.get_ref()
			if not is_instance_valid(target) or target.is_queued_for_deletion() or target.get_parent() != get_parent():
				sprite.visible = false
				continue
			slot.trail_clock += delta
			if not _reduced() and slot.trail_clock >= .06 and slot.trail_last.distance_to(target.global_position) > .12:
				trails.append({"point":slot.trail_last,"sequence":slot.sequence})
				slot.trail_clock = 0.0 # At most one trail station/frame; no catch-up burst.
			slot.trail_last = target.global_position
			sprite.global_position = target.global_position
		else:
			sprite.position += slot.motion*delta
			if slot.row == 1 and not slot.route:
				slot.motion.y -= 9.8*delta
				sprite.rotation.z += delta*9
		if slot.target == null and slot.age >= slot.duration:
			sprite.visible = false
		else:
			sprite.frame = slot.row*4+mini(3,(int(slot.age/(0.09 if slot.row == 2 and not slot.route else slot.duration/4.0))%4)+slot.frame_bias)
			if slot.target == null: sprite.modulate.a = slot.opacity*clampf(1.0-slot.age/slot.duration,0.0,1.0)
	# Allocate only after iteration: pooled sprite additions never mutate the loop.
	for trail in trails:
		var slot = _spawn(2,trail.point,.16)
		if slot.is_empty(): continue
		slot.sprite.pixel_size = .004
		slot.sprite.modulate = Color(.64,.48,.44)
		slot.frame_bias = int(Variation.unit(trail.sequence,4,80)*2)
		slot.opacity = .45
		slot.sprite.modulate.a = slot.opacity
