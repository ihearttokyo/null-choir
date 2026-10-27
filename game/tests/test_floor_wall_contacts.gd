extends SceneTree

# Independent regression envelope, NOT imported from the implementation profile:
# authored backing ends <=1.58 m outside the floor; require a real wall within2m.
# A recess may be open at the old +/-0.2m front plane, never to the exterior.
const OUTWARD_LIMIT = 2.0

func _initialize() -> void: call_deferred("run")

func run() -> void:
    var index = 0
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--level="): index = int(arg.trim_prefix("--level="))
    var level = preload("res://scripts/level.gd").new()
    root.add_child(level)
    if not level.layout.load_level(index):
        push_error(level.layout.load_error)
        level.free()
        quit(2)
        return
    level._build_geometry()
    await physics_frame
    await physics_frame
    var space = level.get_world_3d().direct_space_state
    var failures: Array = []
    var queries = 0
    var size = float(level.layout.data.cell_size)
    for cell in level.layout.tiles:
        for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
            if level.layout.is_walkable(cell+direction): continue
            var outward = Vector3(direction.x,0,direction.y)
            var tangent = Vector2(-direction.y,direction.x)
            for u in [.1,.5,.9]:
                var edge = Vector2(cell)+Vector2(.5,.5)+Vector2(direction)*.5+tangent*(u-.5)
                var point = level.layout.world_position([edge.x,edge.y])
                var inside_cell = edge-Vector2(direction)*.2/size
                var inside = level.layout.world_position([inside_cell.x,inside_cell.y])
                for offset in [.02,level.layout.roof_height(cell)-.02]:
                    var start = inside+Vector3.UP*offset
                    var seam = point+Vector3.UP*offset
                    var end = seam+outward*OUTWARD_LIMIT
                    var hit = wall_ray(space,start,seam,end)
                    queries += 1
                    if not owned_wall_hit(level,hit):
                        failures.append({"cell":[cell.x,cell.y],"direction":[direction.x,direction.y],"u":u,"height_above_floor":offset,"floor_y":point.y,"ray_start":[start.x,start.y,start.z],"ray_end":[end.x,end.y,end.z],"hit":str(hit.get("position",Vector3.INF))})
    # This is an actual native mutation of a temporary fixture collider, not a
    # stubbed ray result: retain front ribs but remove the selected bay's backing.
    # The known Intake centre aperture previously demonstrated the obsolete
    # planar test's failure. Its exterior must become detectably OPEN here.
    var missing_backing_refused: bool = true
    if index == 0: missing_backing_refused = await missing_backing_control(level,space)
    print("FLOOR_WALL_CONTACT_RESULT ",JSON.stringify({"map":index,"queries":queries,"outward_limit":OUTWARD_LIMIT,"failure_count":failures.size(),"failures":failures,"missing_backing_control":missing_backing_refused if index == 0 else "Intake-only"}))
    level.free()
    await process_frame
    await physics_frame
    var passed = queries>0 and failures.is_empty() and missing_backing_refused
    if passed: print("PASS native floor-to-roof wall contacts; map=",index," queries=",queries)
    quit(0 if passed else 1)

func wall_ray(space, start: Vector3, seam: Vector3, end: Vector3) -> Dictionary:
    # Retain the original inside-floor-to-edge seam sample on slopes. Extending
    # its slope another2m could descend below the wall or intersect floor first.
    # Continue horizontally OUTSIDE at the sampled edge height instead. The
    # first actual hit must be a wall; never retry past an unexpected floor hit.
    var hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(start,seam,1))
    if not hit.is_empty(): return hit
    return space.intersect_ray(PhysicsRayQueryParameters3D.create(seam,end,1))

func owned_wall_hit(level, hit: Dictionary) -> bool:
    return not hit.is_empty() and hit.collider is StaticBody3D and hit.collider.get_parent() == level and str(hit.collider.name).begins_with("WallArchitecture_")

func missing_backing_control(level, space) -> bool:
    # Fixed authored counterexample, independent of WallArchitecture.profile:
    # Intake cell[4,7], LEFT, u=.5, local roof-.02; no front rib at its centre.
    var layout = level.layout
    var point: Vector3 = layout.world_position([4.0,7.5])
    var outward = Vector3.LEFT
    var offset: float = layout.roof_height(Vector2i(4,7))-.02
    var seam = point+Vector3.UP*offset
    var start: Vector3 = layout.world_position([4.05,7.5])+Vector3.UP*offset
    var end = seam+outward*OUTWARD_LIMIT
    var original_hit = wall_ray(space,start,seam,end)
    if not owned_wall_hit(level,original_hit):
        push_error("Missing-backing negative control requires the actual intact Intake wall")
        return false
    var collider: CollisionShape3D = null
    for child in original_hit.collider.get_children():
        if child is CollisionShape3D and child.shape is ConcavePolygonShape3D:
            collider = child
            break
    if collider == null:
        push_error("Missing-backing control requires the actual concave wall collider")
        return false
    var original: ConcavePolygonShape3D = collider.shape
    var faces: PackedVector3Array = original.get_faces()
    var retained = PackedVector3Array()
    var removed: int = 0
    for i in range(0,faces.size(),3):
        var exterior: bool = true
        for j in range(3):
            var local: Vector3 = collider.global_transform*faces[i+j]-point
            var depth: float = local.dot(outward)
            # Remove only exterior triangles of this4m bay. The shallow front
            # ribs and original shape/resource remain unchanged and recoverable.
            if depth < .2 or depth > OUTWARD_LIMIT or absf(local.z)>2.001:
                exterior = false
                break
        if exterior: removed += 1
        else:
            for j in range(3): retained.append(faces[i+j])
    if removed == 0:
        push_error("Negative control removed no actual backing triangles")
        return false
    var open_shape = ConcavePolygonShape3D.new()
    open_shape.backface_collision = original.backface_collision
    open_shape.set_faces(retained)
    collider.shape = open_shape
    await physics_frame
    await physics_frame
    var open_hit = wall_ray(space,start,seam,end)
    var open_exterior: bool = open_hit.is_empty()
    collider.shape = original
    await physics_frame
    await physics_frame
    var restored: bool = owned_wall_hit(level,wall_ray(space,start,seam,end))
    print("FLOOR_WALL_MISSING_BACKING_CONTROL ",JSON.stringify({"removed_triangles":removed,"open_exterior_detected":open_exterior,"original_shape_restored":collider.shape == original,"restored_wall_hit":restored}))
    if not open_exterior or not restored:
        push_error("Missing exterior backing must fail the same wall probe; restored backing must pass")
    return open_exterior and restored
