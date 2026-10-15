extends SceneTree

# Parent installs the selected candidate here in an isolated native test project.
const Finale = preload("res://tests/test_nursery_finale_loop.gd")
const Projectile = preload("res://scripts/projectile.gd")
const WallClock = preload("res://tests/wall_clock_wait.gd")
const IDS = ["nursery_enemy_24","nursery_warden","nursery_enemy_27","nursery_enemy_22"]

class Probe:
    extends Node
    var game
    var mode: int
    var done: bool = false
    var report: Dictionary = {}
    var rays: Array = []
    func ray(source, origin: Vector3, end: Vector3, victim) -> bool:
        var query = PhysicsRayQueryParameters3D.create(origin,end,1|2|4)
        query.exclude = [source.get_rid()]
        query.hit_from_inside = true
        var hit = game.level.get_world_3d().direct_space_state.intersect_ray(query)
        var collider = hit.get("collider")
        rays.append([source.id,collider.get_instance_id() if is_instance_valid(collider) else 0,str(hit.get("rid")),origin,end])
        return collider == victim and hit.get("rid") == victim.get_rid()
    func release(source, victim) -> void:
        source.target = victim
        source._begin_attack(victim.global_position+Vector3.UP*1.4)
        source._release_attack()
    func snapshot(worker) -> Dictionary:
        return {"tick":Engine.get_physics_frames(),"worker_hp":worker.hp,"nf_hp":game.nf_hp[worker.id],
                "worker_target":worker.target.get_instance_id() if is_instance_valid(worker.target) else 0,
                "player_hp":game.state.health,"ledger":game.nf_ledger.duplicate(true),"nf_ok":game.nf_ok,
                "worker_cache":game.nf_worker.size(),"melee_cache":game.nf_melee.size()}
    func _physics_process(_delta: float) -> void:
        if done: return
        done = true
        set_physics_process(false)
        var worker = game.enemies.filter(func(actor): return actor.id == IDS[0])[0]
        var warden = game.enemies.filter(func(actor): return actor.id == IDS[1])[0]
        var caster = game.enemies.filter(func(actor): return actor.id == IDS[2])[0]
        var crawler = game.enemies.filter(func(actor): return actor.id == IDS[3])[0]
        var tick: int = Engine.get_physics_frames()
        var before: Dictionary = snapshot(worker)
        var setup: bool = Engine.is_in_physics_frame() and OS.is_debug_build() and game.nf_current() and game.nf_ok
        setup = setup and game.enemies.size() == 29 and game.level.layout.data.id == "nursery" and worker.hp == 90 and game.nf_hp[worker.id] == 90 and game.state.health == 100 and game.state.armor == 0 and game.budget() == game.nf_ledger
        setup = setup and [worker.kind,warden.kind,caster.kind,crawler.kind] == ["worker","nursery_warden","caster","crawler"]
        setup = setup and not game.is_processing() and not game.is_physics_processing() and not game.player.is_physics_processing()
        for actor in game.enemies:
            var capsule = actor.get_child(0)
            setup = setup and game.nf_actor(actor) and not actor.is_physics_processing() and game.nf_bindings[actor.id] == [actor.get_instance_id(),capsule.get_instance_id(),capsule.shape.get_instance_id()] and capsule.shape is CapsuleShape3D and not capsule.disabled
        if mode == 0:
            setup = setup and warden.active and caster.active and worker.active and warden.position.distance_to(worker.position) < 2.4
            setup = ray(warden,warden.global_position+Vector3.UP*0.6,worker.global_position+Vector3.UP*0.7,worker) and setup
            var origin: Vector3 = caster.global_position+Vector3.UP*1.4
            var gap: float = Vector2(origin.x-worker.global_position.x,origin.z-worker.global_position.z).length()-worker.get_child(0).shape.radius
            setup = setup and gap > 0.0 and gap < 0.2
            setup = ray(caster,origin,origin+Vector3(0,0,-0.2),worker) and setup
        else:
            setup = ray(worker,worker.global_position+Vector3.UP*1.4,game.player.global_position+Vector3.UP*1.4,game.player) and setup
            var melee = warden if mode == 1 else crawler
            setup = setup and worker.active and melee.active and melee.position.distance_to(game.player.position) < (2.4 if mode == 1 else 1.9)
            setup = ray(melee,melee.global_position+Vector3.UP*0.6,game.player.global_position+Vector3.UP*0.7,game.player) and setup
        report = {"case":["A_charge_projectile","B_worker_warden","C_crawler_worker"][mode],"setup":setup,"tick":tick,"before":before,"rays":rays,"bindings":game.nf_bindings.duplicate(true)}
        if not setup: return
        if "--forged-melee-source" in OS.get_cmdline_user_args():
            release(warden,worker)
            warden._rush_hit = "--forged-rush-hit" in OS.get_cmdline_user_args()
            # Deliberate negative: event plus direct damage is not native melee provenance.
            warden._event("melee_contact")
            worker.take_damage(32,warden)
            var refused: bool = not game.nf_ok and game.nf_current() and worker.hp == 58 and game.nf_hp[worker.id] == 90 and game.nf_damage_events.is_empty() and game.nf_charge_contacts.is_empty() and game.nf_melee.is_empty()
            report.merge({"case":"forged_melee_source","forged":true,"rush_hit":warden._rush_hit,"final":snapshot(worker),"damage":game.nf_damage_events.duplicate(true),"contacts":game.nf_charge_contacts.duplicate(true),"valid":refused},true)
            return
        if mode == 0:
            release(warden,worker)
            warden._try_melee()
        elif mode == 1: release(worker,game.player)
        else:
            release(crawler,game.player)
            crawler._try_melee()
        report.first = snapshot(worker)
        if mode == 0:
            release(caster,worker)
            var flights: Array = game.level.get_children().filter(func(node): return node.get_script() == Projectile)
            report.projectiles = flights.size()
            if flights.size() == 1:
                report.flight = [flights[0].get_instance_id(),flights[0].shooter.get_instance_id(),flights[0].global_position,flights[0].velocity,flights[0].is_physics_processing()]
                flights[0]._physics_process(1.0/60.0)
        elif mode == 1:
            release(warden,game.player)
            warden._try_melee()
        else: release(worker,game.player)
        report.final = snapshot(worker)
        report.events = game.nf_events.duplicate(true)
        report.hurts = game.nf_hurts.duplicate(true)
        report.damage = game.nf_damage_events.duplicate(true)
        report.births = game.nf_births.size()
        report.birth_records = game.nf_births.values().map(func(row): return [row[1],row[2]])
        report.contacts = game.nf_contacts.duplicate(true)
        report.boss_attacks = game.nf_boss_attacks.duplicate(true)
        var same_tick: bool = game.nf_events.all(func(row): return row[2] == tick) and game.nf_hurts.all(func(row): return row[0] == tick) and game.nf_damage_events.all(func(row): return row[0] == tick)
        same_tick = same_tick and game.nf_births.values().all(func(row): return row[2] == tick) and game.nf_contacts.values().all(func(row): return row[3] == tick)
        var valid: bool = game.nf_ok and game.nf_current() and game.budget() == game.nf_ledger and same_tick and game.enemies.all(func(actor): return actor.hp == game.nf_hp[actor.id])
        for actor in game.enemies:
            var capsule = actor.get_child(0)
            valid = valid and game.nf_actor(actor) and game.nf_bindings[actor.id] == [actor.get_instance_id(),capsule.get_instance_id(),capsule.shape.get_instance_id()]
        if mode == 0:
            valid = valid and report.first.worker_hp == 58 and worker.hp == 44 and game.nf_hp[worker.id] == 44 and worker.target == caster and game.state.health == 100 and game.nf_hurts.is_empty()
            valid = valid and game.nf_births.size() == 1 and game.nf_contacts.size() == 1 and game.nf_contacts.values()[0][0] == "queued_enemy_contact" and game.nf_contacts.values()[0][1] == caster.id and game.nf_contacts.values()[0][2] == worker.get_instance_id()
        else:
            var expected: Array = [[worker.id,10,0],[warden.id,32,0]] if mode == 1 else [[crawler.id,12,0],[worker.id,10,0]]
            valid = valid and report.first.player_hp == (90 if mode == 1 else 88) and game.state.health == (58 if mode == 1 else 78) and game.nf_hurts.map(func(row): return [row[1],row[2],row[3]]) == expected
            valid = valid and game.nf_worker.is_empty() and game.nf_melee.is_empty() and game.nf_births.is_empty() and game.nf_contacts.is_empty()
        report.same_tick = same_tick
        report.valid = valid

func _initialize() -> void:
    AudioServer.set_bus_mute(0,true)
    call_deferred("run")

func run() -> void:
    print("WARDEN_CONTACT_SOURCE ",FileAccess.get_sha256("res://tests/test_nursery_finale_loop.gd")," enemy=",FileAccess.get_sha256("res://scripts/enemy.gd")," projectile=",FileAccess.get_sha256("res://scripts/projectile.gd"))
    var results: Array = []
    var retired: Array = []
    var forged: bool = "--forged-melee-source" in OS.get_cmdline_user_args()
    for mode in range(1 if forged else 3):
        var game = Finale.NurseryFinaleMain.new()
        var prefix: String = "user://warden_contact_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())+"_"+str(mode)
        game.progress_path = prefix+"_campaign.json"
        game.settings_path = prefix+"_preferences.json"
        game.prefix_bookkeeping_retired = true
        root.add_child(game)
        game.state.new_campaign(1)
        game.state.level_index = 4
        game.start_level()
        game.set_process(false)
        game.set_physics_process(false)
        game.player.set_process(false)
        game.player.set_physics_process(false)
        game.player.set_process_unhandled_input(false)
        for actor in game.enemies:
            actor.set_process(false)
            actor.set_physics_process(false)
            actor.active = false
            actor.collision_layer = 0
            actor.collision_mask = 0
            var capsule = actor.get_child(0)
            game.nf_bindings[actor.id] = [actor.get_instance_id(),capsule.get_instance_id(),capsule.shape.get_instance_id()]
            game.nf_hp[actor.id] = actor.hp
        # Reuse the original brute witness's clear Nursery lane; no automatic AI movement.
        game.player.position = Vector3(18,0.04,140 if mode == 0 else 134)
        var selected: Array = [IDS[0],IDS[1],IDS[2]] if mode == 0 else [IDS[0],IDS[1]] if mode == 1 else [IDS[0],IDS[3]]
        for actor in game.enemies:
            if not actor.id in selected: continue
            actor.active = true
            actor.collision_layer = 4
            actor.collision_mask = 7
            if actor.id == IDS[0]: actor.position = Vector3(18 if mode == 0 else 16,0.04,134)
            elif actor.id == IDS[1]: actor.position = Vector3(18,0.04,132)
            elif actor.id == IDS[2]: actor.position = Vector3(18,0.04,134.44)
            else: actor.position = Vector3(18,0.04,132.6)
        game.n_level_id = game.level.get_instance_id()
        game.n_player_id = game.player.get_instance_id()
        game.nf_ledger = game.budget().duplicate(true)
        for frame in range(12): await physics_frame
        game.nf_enabled = true
        var probe = Probe.new()
        probe.game = game
        probe.mode = mode
        root.add_child(probe)
        retired.append_array([weakref(game),weakref(game.level),weakref(game.player),weakref(probe)])
        # The physics_frame signal precedes callbacks; process_frame observes this one probe tick.
        await physics_frame
        await process_frame
        results.append(probe.report.duplicate(true))
        print("WARDEN_CONTACT_CASE ",probe.report)
        game.nf_enabled = false
        game.music.stop()
        game.effects.stop()
        game.free()
        probe.free()
        await process_frame
        await process_frame
        await WallClock.seconds(self,0.2)
    var valid: bool = retired.all(func(ref): return ref.get_ref() == null) and results.size() == (1 if forged else 3) and results.all(func(row): return row.get("setup",false) and row.get("valid",false))
    if valid: print("PASS controlled forged melee source rejected before HP ledger mutation; explicit negative, not earned combat" if forged else "PASS controlled native same-tick Warden/projectile and Player contact ordering; not earned combat/campaign, physical input, GUI/GPU, audio or packed-app acceptance")
    else: push_error("NATIVE RED same-tick contact control requires all setups true, A44/B58/C78 HP, independent ledgers, correct native sources and consumed Player contact caches; inspect WARDEN_CONTACT_CASE")
    quit(0 if valid else 1)
