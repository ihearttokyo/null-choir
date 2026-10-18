extends SceneTree

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
                var outside = point+(point-inside)
                for offset in [.02,level.layout.roof_height(cell)-.02]:
                    var start = inside+Vector3.UP*offset
                    var end = outside+Vector3.UP*offset
                    var hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(start,end,1))
                    queries += 1
                    # This geometry-only Level directly owns wall bodies, never the floor bodies.
                    if hit.is_empty() or hit.collider.get_parent()!=level:
                        failures.append({"cell":[cell.x,cell.y],"direction":[direction.x,direction.y],"u":u,"height_above_floor":offset,"floor_y":point.y,"ray_start":[start.x,start.y,start.z],"ray_end":[end.x,end.y,end.z],"hit":str(hit.get("position",Vector3.INF))})
    print("FLOOR_WALL_CONTACT_RESULT ",JSON.stringify({"map":index,"queries":queries,"failure_count":failures.size(),"failures":failures}))
    level.free()
    await process_frame
    await physics_frame
    var passed = queries>0 and failures.is_empty()
    if passed: print("PASS native floor-to-roof wall contacts; map=",index," queries=",queries)
    quit(0 if passed else 1)
