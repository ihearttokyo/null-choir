extends SceneTree

const WallClock = preload("res://tests/wall_clock_wait.gd")
const StaticSelectedLevel = preload("res://tests/fixtures/static_selected_level.gd")

func _initialize(): call_deferred("run")

func exclude_nonfloor(node: Node, out: Array[RID], floor_rids: Dictionary) -> void:
    # Floor identity is owned by Level, not inferred from the render-mesh name.
    # Revision-3 Ossuary's real floor colliders are AuthoredSurface_* meshes.
    if node is CollisionObject3D and not floor_rids.has(node.get_rid()):
        out.append(node.get_rid())
    for child in node.get_children(): exclude_nonfloor(child,out,floor_rids)

func run():
    var fixture=OS.get_environment("NULL_CHOIR_TERRAIN_FIXTURE_ROOT")
    var home=fixture.get_base_dir().get_base_dir()+"/home"
    if fixture.is_empty() or ProjectSettings.globalize_path("res://").trim_suffix("/")!=fixture or OS.get_environment("HOME")!=home or not OS.get_user_data_dir().begins_with(home+"/"):
        print("REFUSED HERO CONTACT FIXTURE: disposable project/private HOME required")
        quit(2)
        return
    AudioServer.set_bus_mute(0,true)
    var game=load("res://scripts/main.gd").new()
    var prefix="user://hero_contacts_"+str(OS.get_process_id())
    game.settings_path=prefix+"_preferences.json"
    game.progress_path=prefix+"_campaign.json"
    root.add_child(game)
    var failures=0
    var queries=0
    var rows=[]
    for index in range(8):
        # Selected current/checkpoint/entry books and floor belong to THIS map,
        # not an Intake new_campaign with only its level_index overwritten.
        var selected = StaticSelectedLevel.fresh_selected(index,1)
        if selected == null:
            push_error("Selected contact fixture has no valid current chapter image")
            game.free()
            quit(1)
            return
        game.state=selected
        await game.start_level()
        if not game.playing or not is_instance_valid(game.level) or not is_instance_valid(game.player) or game.state.level_index!=index or game._scene_level_index!=index:
            push_error("Actual selected contact world failed to build; no default-map proxy")
            game.free()
            quit(1)
            return
        game.set_process(false)
        game.player.set_physics_process(false)
        for actor in game.enemies: actor.set_physics_process(false)
        await physics_frame
        await physics_frame
        var exclude:Array[RID]=[]
        var floor_rids:Dictionary={}
        for body in game.level.floor_bodies: floor_rids[body.get_rid()]=true
        exclude_nonfloor(root,exclude,floor_rids)
        var space=game.level.get_world_3d().direct_space_state
        for hero in game.level.layout.data.heroes:
            if not hero.has("base"): continue
            var body=game.level.get_node("LandmarkBase_"+hero.id)
            var shape=body.get_child(0).shape
            var round_base=bool(hero.get("round",false))
            var shape_ok=shape is CylinderShape3D and is_equal_approx(shape.radius,hero.base[0]/2) and is_equal_approx(shape.height,hero.base[1]) if round_base else shape is BoxShape3D and shape.size.is_equal_approx(Vector3(hero.base[0],hero.base[1],hero.base[2]))
            shape_ok=shape_ok and is_equal_approx(body.rotation.y,deg_to_rad(hero.yaw))
            var samples=[Vector3.ZERO]
            for i in range(16):
                var angle=TAU*i/16
                var direction=Vector2(cos(angle),sin(angle))
                if not round_base: direction/=maxf(absf(direction.x),absf(direction.y))
                samples.append(Vector3(direction.x*(hero.base[0]/2+.02),0,direction.y*(hero.base[2]/2+.02)))
            var worst=0.0
            var misses=0
            for sample in samples:
                var point=body.to_global(sample-Vector3.UP*hero.base[1]/2)
                var hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*5,point-Vector3.UP*5,1,exclude))
                queries+=1
                if hit.is_empty(): misses+=1
                else: worst=maxf(worst,absf(hit.position.y-point.y))
            var passed=shape_ok and misses==0 and worst<.003
            if not passed: failures+=1
            rows.append({"map":index,"hero":hero.id,"shape_yaw_ok":shape_ok,"misses":misses,"max_floor_base_gap":worst,"pass":passed})
        game.show_title()
        await process_frame
        await physics_frame
    game.music.stop()
    game.queue_free()
    await WallClock.seconds(self,0.15)
    await process_frame
    await physics_frame
    print("HERO_FLOOR_CONTACT_RESULT ",JSON.stringify({"bases":rows,"queries":queries,"failures":failures}))
    var passed=failures==0 and rows.size()==15 and queries==255
    if passed: print("PASS native15 hero base shapes/yaw/255 floor contacts; sampled native plus separate full-footprint source proof, not visual/physical gameplay")
    quit(0 if passed else 1)
