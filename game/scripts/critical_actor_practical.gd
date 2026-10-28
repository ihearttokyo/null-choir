extends OmniLight3D
## Local actor readability; critical carriers retain their original brighter light; follows the actual billboard's front.
## No collision, gameplay, save or atlas writes. Walls clamp the emitter and cast shadows.
var _source: Sprite3D
var _ordinary_living_only: bool = false

func bind(source: Sprite3D, critical: bool = true) -> void:
	_source=source
	_ordinary_living_only=not critical
	name="CarriedPractical"
	light_color=Color(.95,.8,.6)
	light_energy=1.4 if critical else 0.65
	omni_range=maxf(3.2,source.pixel_size*float(source.texture.get_height()/source.vframes)*.7)
	light_cull_mask=0xFFFFF if critical else 2
	shadow_enabled=critical # No additional shadow maps for ordinary actors.
	set_meta("practical_source","critical_actor_billboard" if critical else "ordinary_actor_billboard")

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_source) or not _source.is_inside_tree() or _source.is_queued_for_deletion():
		hide();return
	if _ordinary_living_only and _source.get_parent().hp <= 0:
		hide();return
	var camera: Camera3D=get_viewport().get_camera_3d()
	if camera==null or not _source.is_visible_in_tree(): hide();return
	var center: Vector3=_source.global_position
	var front: Vector3=camera.global_position-center
	if front.length_squared()<.0001: hide();return
	front=front.normalized()
	# The sprite itself billboards on the GPU; use that same visible front, not
	# actor yaw (which can place a light behind the visible card). Never cross walls.
	var point: Vector3=center+front*.75
	var query := PhysicsRayQueryParameters3D.create(center,point,1)
	query.hit_from_inside=true
	var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		if center.distance_to(hit.position)<.06: hide();return
		point=hit.position-front*.04
	global_position=point
	show()
