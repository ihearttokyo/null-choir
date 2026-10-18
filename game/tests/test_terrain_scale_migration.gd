extends "res://tests/test_actor_snapshot_trust.gd"

func run() -> void:
    var fixture = OS.get_environment("NULL_CHOIR_TERRAIN_FIXTURE_ROOT")
    var home = fixture.get_base_dir().get_base_dir()+"/home"
    if fixture.is_empty() or ProjectSettings.globalize_path("res://").trim_suffix("/")!=fixture or OS.get_environment("HOME")!=home or not OS.get_user_data_dir().begins_with(home+"/"):
        print("REFUSED TERRAIN SCALE FIXTURE: disposable project and private HOME required")
        quit(2)
        return
    AudioServer.set_bus_mute(0,true)
    var path = "res://data/01_intake.json"
    var original = FileAccess.get_file_as_string(path)
    var old_layout = Layout.new()
    if not old_layout.load_level(0):
        push_error(old_layout.load_error)
        quit(2)
        return
    var documents: Array = []
    for mode in range(3):
        var document = fresh_document(0,mode)
        var kept = document.actors[0].duplicate(true)
        var point = old_layout.world_position([18.0,8.5])+Vector3.UP*.03
        kept.position = [point.x,point.y,point.z]
        document.actors = [kept]
        document.removed = old_layout.data.enemies.filter(func(spec): return spec.id!=kept.id).map(func(spec): return spec.id)
        var state = Campaign.new()
        expect(state.from_dict(document),"Legacy actor-bearing staged document is valid before scale edit")
        state.position = old_layout.world_position([18.25,8.75])+Vector3.UP*.04
        state.health = 73
        state.ammo[1] = 37
        state.mark_checkpoint("entry",state.position)
        document = state.to_dict()
        document.checkpoint.health = 81
        document.checkpoint.ammo[1] = 44
        document.level_start.health = 97
        document.level_start.ammo[1] = 88
        point = old_layout.world_position([18.5,8.75])+Vector3.UP*.04
        document.checkpoint.position = [point.x,point.y,point.z]
        point = old_layout.world_position([18.75,8.75])+Vector3.UP*.04
        document.level_start.position = [point.x,point.y,point.z]
        expect(Campaign.new().from_dict(document),"All three native old-floor envelopes validate")
        documents.append(document)
    var changed: Dictionary = JSON.parse_string(original)
    changed.floor_revision = 1
    changed.cell_size = 3
    for region in changed.elevations: region.height *= 1.25
    write_map(path,JSON.stringify(changed))
    var layout = Layout.new()
    expect(layout.load_level(0),"Rescaled revision1 real map loads")
    var level = load("res://scripts/level.gd").new()
    root.add_child(level)
    level.layout = layout
    level._build_geometry()
    await physics_frame
    await physics_frame
    var rays = 0
    for mode in range(3):
        var document: Dictionary = documents[mode]
        var before = document.duplicate(true)
        var state = Campaign.new()
        var accepted = state.from_dict(document)
        expect(accepted,"INTENDED RED: current cell scale must sample new floor at preserved world XZ")
        if not accepted: continue
        var migrated = state.to_dict()
        expect(document==before,"Scale migration leaves input dictionary untouched")
        for envelope in ["current","checkpoint","level_start"]:
            var a: Dictionary = document if envelope=="current" else document[envelope]
            var b: Dictionary = migrated if envelope=="current" else migrated[envelope]
            for field in a:
                if field in ["version","position","actors","checkpoint","level_start"]: continue
                expect(a[field]==b[field],"Rescale preserves original resource "+envelope+" "+field)
            expect(b.floor_revision==1,"Rescale labels every migrated envelope")
            for pair in [[a.position,b.position],[a.actors[0].position,b.actors[0].position]]:
                var old_cell = [pair[0][0]/old_layout.data.cell_size,pair[0][2]/old_layout.data.cell_size]
                var new_cell = [pair[0][0]/layout.data.cell_size,pair[0][2]/layout.data.cell_size]
                var old_floor = old_layout.world_position(old_cell).y
                var new_floor = layout.world_position(new_cell).y
                expect(pair[0][0]==pair[1][0] and pair[0][2]==pair[1][2] and absf(pair[1][1]-pair[0][1]-(new_floor-old_floor))<.00002,"Actual world XZ preserved with independently scaled native floor delta")
                expect(absf(new_floor-layout.world_position(old_cell).y)>1.0,"Counterexample distinguishes old/new cell coordinates")
                var p = Vector3(pair[1][0],new_floor,pair[1][2])
                var hit = level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*.1,p-Vector3.UP*.1,1))
                expect(not hit.is_empty() and absf(hit.position.y-new_floor)<.003,"Rescaled production floor agrees with actual native collision")
                rays += 1
            expect(a.actors[0].id==b.actors[0].id and a.actors[0].hp==b.actors[0].hp and a.actors[0].yaw==b.actors[0].yaw and a.actors[0].alerted==b.actors[0].alerted,"Rescale preserves original actor identity/state")
        var again = Campaign.new()
        expect(again.from_dict(migrated) and again.to_dict()==migrated,"Rescaled load is exactly idempotent")
    write_map(path,original)
    level.free()
    await physics_frame
    print("TERRAIN_SCALE_RESULT ",JSON.stringify({"difficulties":3,"envelopes_each":3,"native_floor_rays":rays,"old_cell_size":4,"new_cell_size":3,"failures":failures}))
    if failures==0: print("PASS terrain scale migration native codec and floor collision; not traversal/GPU/packed acceptance")
    quit(0 if failures==0 else 1)

func write_map(path: String, text: String) -> void:
    var file = FileAccess.open(path,FileAccess.WRITE)
    expect(file!=null,"Disposable map output opens")
    if file==null: return
    file.store_string(text)
    file.close()
