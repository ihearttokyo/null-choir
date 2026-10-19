extends SceneTree

func _initialize(): call_deferred("run")

func bodies(node: Node, door: Node, out: Array[RID]) -> void:
    if node is CollisionObject3D and node != door: out.append(node.get_rid())
    for child in node.get_children(): bodies(child,door,out)

func run():
    var fixture=OS.get_environment("NULL_CHOIR_TERRAIN_FIXTURE_ROOT")
    var home=fixture.get_base_dir().get_base_dir()+"/home"
    if fixture.is_empty() or ProjectSettings.globalize_path("res://").trim_suffix("/")!=fixture or OS.get_environment("HOME")!=home or not OS.get_user_data_dir().begins_with(home+"/"):
        print("REFUSED DOOR CONTACT FIXTURE: disposable project and private HOME required")
        quit(2)
        return
    AudioServer.set_bus_mute(0,true)
    var game = load("res://scripts/main.gd").new()
    var prefix = "user://door_contact_"+str(OS.get_process_id())
    game.settings_path=prefix+"_preferences.json"
    game.progress_path=prefix+"_campaign.json"
    root.add_child(game)
    var rows=[]
    var misses=0
    for index in range(8):
        game.start_campaign(1)
        game.state.new_campaign(1)
        game.state.level_index=index
        await game.start_level()
        game.set_process(false)
        game.player.set_physics_process(false)
        for actor in game.enemies:actor.set_physics_process(false)
        await physics_frame
        await physics_frame
        var space=game.level.get_world_3d().direct_space_state
        for spec in game.level.layout.data.doors:
            var door=game.level.doors[spec.id]
            var exclude:Array[RID]=[]
            bodies(root,door,exclude)
            for u in [-.45,-.225,0,.225,.45]:
                var center=door.to_global(Vector3(spec.size[0]*u,0,0))
                var cell=[center.x/game.level.layout.data.cell_size,center.z/game.level.layout.data.cell_size]
                var floor_point=game.level.layout.world_position(cell)
                var local_y=floor_point.y+.02-door.global_position.y
                var start=door.to_global(Vector3(spec.size[0]*u,local_y,-spec.size[2]/2-.2))
                var end=door.to_global(Vector3(spec.size[0]*u,local_y,spec.size[2]/2+.2))
                var query=PhysicsRayQueryParameters3D.create(start,end,1,exclude)
                var hit=space.intersect_ray(query)
                var walkable=game.level.layout.is_walkable(Vector2i(floori(cell[0]),floori(cell[1])))
                var found=walkable and not hit.is_empty() and hit.collider==door
                if not found:misses+=1
                rows.append({"map":index,"door":spec.id,"u":u,"base_minus_floor":door.global_position.y-spec.size[1]/2-floor_point.y,"hit":found,"walkable":walkable})
        game.show_title()
        await process_frame
        await physics_frame
    game.queue_free()
    await process_frame
    await physics_frame
    print("VERTICAL_DOOR_CONTACT_RESULT ",JSON.stringify({"misses":misses,"samples":rows}))
    var passed=misses==0 and rows.size()==40
    if passed:print("PASS native closed-door floor contacts; eight maps40 queries")
    quit(0 if passed else 1)
