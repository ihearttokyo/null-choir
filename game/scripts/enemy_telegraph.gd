extends Node3D
const Motion = preload("res://scripts/enemy_motion.gd")
# Committed worker shot / brute and Warden charge intent. No gameplay writes.
# Depth-tested geometry (no through-wall HUD), at most30 world-ray queries/sec.
var beam: MeshInstance3D
var _shape: CylinderMesh
var _material: StandardMaterial3D
var _until_sample := 0.0
var lane: MultiMeshInstance3D
var _lane_built := false
var _lane_pose: Transform3D
var _lane_aim: Vector3
var _lane_progress := -1.0
var _lane_invalidated := false
var lane_nominal_distance := 0.0
var lane_clipped_distance := 0.0
var lane_radius := 0.0
var lane_points: Array[Vector3] = []

func _ready() -> void:
	beam = MeshInstance3D.new()
	_shape = CylinderMesh.new()
	_shape.radial_segments = 6
	_shape.rings = 1
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = Color(1.0,0.48,0.12)
	# Opaque, low-radius depth-tested line: no glare, lights or flashing.
	beam.mesh = _shape
	beam.material_override = _material
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.visible = false
	add_child(beam)
	beam.top_level = true
	lane = MultiMeshInstance3D.new()
	var dots = MultiMesh.new()
	dots.transform_format = MultiMesh.TRANSFORM_3D
	var dot = SphereMesh.new()
	dot.radius = 0.035
	dot.height = 0.035
	dot.radial_segments = 6
	dot.rings = 3
	dots.mesh = dot
	dots.instance_count = 48
	dots.visible_instance_count = 0
	lane.multimesh = dots
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.95,0.66,0.19)
	lane.material_override = material
	lane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lane)
	lane.top_level = true
	lane.global_transform = Transform3D.IDENTITY
	lane.hide()

func _physics_process(delta: float) -> void:
	var actor = get_parent()
	if not is_instance_valid(actor) or actor.is_queued_for_deletion() or not actor.is_inside_tree():
		queue_free();return
	var host: Variant = actor.get("game")
	if not is_instance_valid(host) or host.is_queued_for_deletion() or not actor.has_method("combat_visual_state"):
		_hide_all();return
	var state: Dictionary = actor.combat_visual_state()
	if state.is_empty() or state.get("phase") == "dead":
		_hide_all();queue_free();return
	var charge: bool = actor.get("kind") == "brute" or (actor.get("kind") == "nursery_warden" and state.get("variant",-1) == 0)
	if (actor.get("kind") != "worker" and not charge) or state.get("phase") != "windup" or not host.get("playing"):
		_hide_all();_until_sample = 0.0;_lane_built = false;_lane_progress = -1.0;_lane_invalidated = false;return
	var player: Variant = host.get("player")
	var camera: Variant = player.get("camera") if is_instance_valid(player) else null
	var origin: Vector3 = actor.global_position+Vector3.UP*1.4
	if not camera is Camera3D or not is_instance_valid(camera) or not camera.is_inside_tree() or not camera.is_position_in_frustum(origin):
		_hide_all();return
	if charge:
		beam.hide()
		var progress: float = state.get("progress",0.0)
		if progress < _lane_progress:
			_lane_built = false;_lane_invalidated = false
		_lane_progress = progress
		if _lane_built and (_meaningful_lane_pose_change(actor) or actor.get("_committed_aim") != _lane_aim):
			_lane_invalidated = true
		if _lane_invalidated:
			lane.hide();return
		if not _lane_built:
			_lane_pose = actor.global_transform
			_lane_aim = actor.get("_committed_aim")
			_build_lane(actor)
			_lane_built = true
		lane.visible = not lane_points.is_empty()
		return
	_until_sample -= delta
	if _until_sample > 0: return
	_until_sample = 1.0/30.0
	# Exactly the release ray's committed direction/range; never follow the player.
	var aim: Vector3 = actor.get("_committed_aim")
	var direction := (aim-origin).normalized()
	if direction.length_squared() < 0.5:
		_hide_all();return
	var end := origin+direction*30.0
	var query := PhysicsRayQueryParameters3D.create(origin,end,1)
	if actor is CollisionObject3D: query.exclude = [actor.get_rid()]
	query.hit_from_inside = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): end = hit.position
	var span := end-origin
	if span.length_squared() < 0.0001:
		_hide_all();return
	_shape.height = span.length()
	_shape.top_radius = 0.009+0.006*clampf(state.get("progress",0.0),0.0,1.0)
	_shape.bottom_radius = _shape.top_radius
	beam.global_transform = Transform3D(Basis(Quaternion(Vector3.UP,span.normalized())),origin+span*0.5)
	beam.show()

func _hide_all() -> void:
	beam.hide()
	lane.hide()

func _build_lane(actor: Node3D) -> void:
	# Nominal movement corridor, NOT a damage radius/prediction of final travel.
	# Early impact/targets can stop the real rush; melee has a separate reach.
	lane_points.clear()
	lane.multimesh.visible_instance_count = 0
	lane_clipped_distance = 0.0
	var collider: CollisionShape3D
	for child in actor.get_children():
		if child is CollisionShape3D and child.shape is CapsuleShape3D:
			collider = child;break
	if collider == null: return
	lane_radius = collider.shape.radius
	lane_nominal_distance = Motion.charge_distance(str(actor.get("kind")))
	var aim: Vector3 = actor.get("_committed_aim")
	var direction := aim-actor.global_position
	direction.y = 0.0
	if direction.length_squared() < 0.0001: return
	direction = direction.normalized()
	var space := get_world_3d().direct_space_state
	var sweep := PhysicsShapeQueryParameters3D.new()
	sweep.shape = collider.shape
	sweep.transform = collider.global_transform
	sweep.motion = direction*lane_nominal_distance
	sweep.collision_mask = 1
	sweep.margin = 0.001
	if actor is CollisionObject3D: sweep.exclude = [actor.get_rid()]
	var fractions := space.cast_motion(sweep)
	if fractions.size()!=2: return
	var travel: float = lane_nominal_distance*fractions[0]
	if travel <= 0.01: return # Initial overlap/floor contact fails closed; never bypass sweep.
	var side := Vector3(-direction.z,0,direction.x)
	var previous_height: float = actor.global_position.y
	# At most16stations x3rays +1actualcapsule sweep, once per committed windup.
	# Disconnected dots sit on queried surfaces; never draw a strip across a gap.
	for station in range(1,17):
		var distance: float = travel*float(station)/16.0
		var center := actor.global_position+direction*distance
		var samples: Array[Vector3] = []
		var supported := true
		for edge in [-1.0,0.0,1.0]:
			var point: Vector3 = center+side*lane_radius*edge
			var query := PhysicsRayQueryParameters3D.create(point+Vector3.UP*0.45,point-Vector3.UP*0.65,1)
			var hit := space.intersect_ray(query)
			if hit.is_empty() or hit.normal.y < 0.7 or absf(hit.position.y-previous_height)>0.35:
				supported = false;break
			samples.append(hit.position+Vector3.UP*0.018)
		if not supported: break
		previous_height = samples[1].y-0.018
		lane_clipped_distance = distance
		for point in samples:
			lane.multimesh.set_instance_transform(lane_points.size(),Transform3D(Basis.IDENTITY,point))
			lane_points.append(point)
	lane.multimesh.visible_instance_count = lane_points.size()

func _meaningful_lane_pose_change(actor: Node3D) -> bool:
	# Visual cache stability ONLY, never collision/nav/AI tolerances. Ground
	# settling and sub-mm physics noise must not permanently erase a windup.
	var shift := actor.global_position-_lane_pose.origin
	return Vector2(shift.x,shift.z).length()>0.01 or absf(shift.y)>0.03 or actor.global_basis.y.normalized().dot(_lane_pose.basis.y.normalized())<cos(deg_to_rad(1.0))
