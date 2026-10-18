extends SceneTree
const WallClock = preload("res://tests/wall_clock_wait.gd")
const NC = preload("res://tests/test_nursery_earned_campaign.gd")
var game
class Probe:
    extends Node
    var game
    var source
    var victim
    var done = false
    var report = {}
    func _physics_process(_delta):
        if done: return
        done = true
        source._try_melee()
        report = {"ok":game.nc_ok,"hp":victim.hp if victim!=game.player else game.state.health,
                  "mode":game.nc_finishes.get(victim.id,"") if victim!=game.player else "player",
                  "contacts":game.nc_events.filter(func(row): return row[1]=="melee_contact").size()}
        set_physics_process(false)
func _initialize():
    AudioServer.set_bus_mute(0,true)
    call_deferred("run")
func run():
    var results = []
    for player_intercepts in [false,true]:
        game=NC.NurseryCampaignMain.new()
        var prefix="user://brute_witness_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
        game.progress_path=prefix+"_campaign.json"
        game.settings_path=prefix+"_preferences.json"
        root.add_child(game)
        game.state.new_campaign(1)
        game.state.level_index=4
        game.start_level()
        game.set_process(false)
        game.set_physics_process(false)
        game.player.set_physics_process(false)
        game.player.set_process_unhandled_input(false)
        for actor in game.enemies:
            actor.set_physics_process(false)
            actor.collision_layer=0
            actor.collision_mask=0
            var capsule=actor.get_child(0)
            game.nc_bindings[actor.id]=[actor.get_instance_id(),capsule.get_instance_id(),capsule.shape.get_instance_id()]
        var source=game.enemies.filter(func(actor): return actor.kind=="brute")[0]
        var crawler=game.enemies.filter(func(actor): return actor.kind=="crawler")[0]
        source.active=true
        crawler.active=true
        source.collision_layer=4
        source.collision_mask=7
        crawler.collision_layer=4
        crawler.collision_mask=7
        source.position=Vector3(18,.04,132)
        crawler.position=Vector3(18,.04,134 if player_intercepts else 133)
        game.player.position=Vector3(18,.04,133 if player_intercepts else 134)
        crawler.hp=6
        source._committed_target=crawler if player_intercepts else game.player
        game.n_level_id=game.level.get_instance_id()
        game.n_player_id=game.player.get_instance_id()
        game.nc_ledger=game.budget().duplicate(true)
        game.nc_enabled=true
        await physics_frame
        await physics_frame
        var probe=Probe.new()
        probe.game=game
        probe.source=source
        probe.victim=game.player if player_intercepts else crawler
        root.add_child(probe)
        while not probe.done: await physics_frame
        results.append(probe.report)
        game.nc_enabled=false
        game.music.stop()
        game.free()
        probe.free()
        await process_frame
        await process_frame
    await WallClock.seconds(self,0.1)
    print("BRUTE_INTERCEPTION_WITNESS ",results)
    var valid=results[0].ok and results[0].hp==0 and results[0].mode=="infighting" and results[0].contacts==1 and results[1].ok and results[1].hp==76 and results[1].contacts==1
    if not valid:push_error("NATIVE RED brute actual first-collider enemy/player interceptions must have proven melee contact")
    else:print("PASS controlled native actual brute first-collider interception witness; not earned campaign/AI/physical/GPU acceptance")
    quit(0 if valid else 1)
