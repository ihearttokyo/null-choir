extends SceneTree

const Transport = preload("res://tests/test_ossuary_transport_loop.gd")
const Current = preload("res://tests/ossuary_second_loop_witness.gd")
const WallClock = preload("res://tests/wall_clock_wait.gd")
const ADMISSION = "guardian projectile uses actual single-pattern release, not caster assumptions"
const IDENTITY = "original guardian birth identity/origin1.65/pattern direction/speed12/lifetime4/budget"
const CALLBACK = "actual current-map finite native projectile callback"
const CONTACT = "once-only native queued projectile contact"
const CASES = ["pistol","caster","crawler","origin","direction","nonfinite","source","map","player","tick","release_tick","dead_birth","duplicate_birth","victim","rid","contact_tick","duplicate_contact","replace_map","replace_player","replaced_source","dead_source","forged_release"]

class ControlMain:
    extends "res://tests/test_ossuary_transport_loop.gd".TransportMain
    var control: String
    var callback_seen: bool = false
    var preserved: bool = false
    var replacement
    var original
    var probe_projectile
    var source_setup: bool = false
    func accepted() -> Dictionary:
        return Current.fields_image(transport_witness,["births","guardian_birth_ticks","guardian_releases","contacts","used_contacts","hp","damage","shield_records","pending_player"])
    func _debug_projectile_event(projectile: Node3D, event: String, data: Dictionary) -> void:
        var birth: bool = event == "configured_birth"
        var contact: bool = event == "queued_enemy_contact"
        if birth: probe_projectile = weakref(projectile)
        var perturb: bool = birth and control in ["origin","direction","nonfinite","source","map","player","tick","release_tick","dead_birth","duplicate_birth"] or contact and control in ["victim","rid","contact_tick","duplicate_contact","replace_map","replace_player","replaced_source"]
        if not perturb:
            super._debug_projectile_event(projectile,event,data)
            return
        callback_seen = true
        var source = projectile.shooter
        var original_hp: int = source.hp
        var original_velocity: Vector3 = projectile.velocity
        match control:
            "origin": data.origin += Vector3.RIGHT
            "direction":
                projectile.velocity = projectile.velocity.rotated(Vector3.UP,0.2)
                data.velocity = projectile.velocity
            "nonfinite":
                projectile.velocity = Vector3(NAN,0,0)
                data.velocity = projectile.velocity
            "source": data.source = enemies.filter(func(actor): return actor.id == "ossuary_enemy_02")[0]
            "map": data.map = self
            "player": data.player = source
            "tick", "contact_tick": data.tick -= 1
            "release_tick":
                var tick: int = Engine.get_physics_frames()
                transport_witness.guardian_releases[tick-1] = transport_witness.guardian_releases[tick]
                transport_witness.guardian_releases.erase(tick)
            "dead_birth": source.hp = 0
            "victim": data.hit.collider = source
            "rid": data.hit.rid = source.get_rid()
            "replaced_source":
                var replacement_source = Enemy.new()
                level.add_child(replacement_source)
                replacement_source.configure(self,{"id":source.id,"kind":source.kind,"cell":[24.0,24.0],"yaw":0})
                replacement_source.set_process(false)
                replacement_source.set_physics_process(false)
                replacement_source.position = source.position
                replacement_source.active = true
                replacement_source.collision_layer = 0
                replacement_source.collision_mask = 0
                source_setup = replacement_source.get_script() == source.get_script() and replacement_source.id == source.id and replacement_source._current_map() and replacement_source.get_instance_id() != source.get_instance_id() and transport_witness.bindings[source.id][0] == source.get_instance_id() and not transport_witness.actor(replacement_source)
                projectile.shooter = replacement_source
                data.source = replacement_source
            "replace_map":
                original = level
                replacement = Node3D.new()
                add_child(replacement)
                level = replacement
            "replace_player":
                original = player
                replacement = CharacterBody3D.new()
                level.add_child(replacement)
                player = replacement
        if control in ["duplicate_birth","duplicate_contact"]: super._debug_projectile_event(projectile,event,data)
        var before: Dictionary = accepted()
        super._debug_projectile_event(projectile,event,data)
        preserved = accepted() == before
        if control == "replaced_source":
            var rejected_source = projectile.shooter
            projectile.shooter = source
            rejected_source.queue_free()
        projectile.velocity = original_velocity
        source.hp = original_hp

class Probe:
    extends Node
    var game
    var witness
    var mode: String
    var done: bool = false
    var stage: int = 0
    var frames: int = 0
    var kills: int = 0
    var initial: bool = false
    var report: Dictionary = {}
    func finish(setup: bool, valid: bool) -> void:
        done = true
        Input.action_release("fire")
        if is_instance_valid(game.player): game.player.set_physics_process(false)
        report = {"case":mode,"setup":setup,"valid":setup and valid,"failures":witness.failures.duplicate(),"births":witness.births.size(),"contacts":witness.contacts.size(),"damage":witness.damage.size(),"shots":witness.shots.size(),"shield":witness.shield_records.duplicate(true),"preserved":game.preserved,"callback_seen":game.callback_seen,"frames":frames,"kills":kills,"hp":witness.hp.duplicate()}
    func _physics_process(_delta: float) -> void:
        if done: return
        frames += 1
        var guardian = game.enemies.filter(func(actor): return actor.id == "ossuary_enemy_08")[0]
        var worker = game.enemies.filter(func(actor): return actor.id == "ossuary_enemy_02")[0]
        if stage == 1:
            if mode == "dead_source":
                if guardian.hp > 0:
                    worker.target = guardian
                    worker._begin_attack(guardian.global_position+Vector3.UP*1.4)
                    worker._release_attack()
                    kills += 1
                    return
                var projectile = game.probe_projectile.get_ref()
                initial = initial and kills == 26 and guardian.hp == 0 and witness.hp[guardian.id] == 0 and witness.deaths.get(guardian.id,0) == 1 and witness.finishes.get(guardian.id) == "infighting" and game.state.removed.count(guardian.id) == 1 and witness.lethal.is_empty() and is_instance_valid(projectile) and witness.births.size() == 1
                projectile.set_physics_process(true)
                stage = 2
                return
            if mode == "pistol":
                if witness.shots.size() == 1 or frames >= 60:
                    finish(initial,witness.ok and frames < 60 and guardian.hp == 253 and witness.hp[guardian.id] == 253 and witness.shield_records.size() == 1 and witness.damage.size() == 1 and game.state.ammo[1] == witness.ledger.ammo[1])
                return
        if stage > 0:
            if game.callback_seen or witness.contacts.size() == 1 or frames >= 60:
                if game.replacement != null:
                    if mode == "replace_map": game.level = game.original
                    else: game.player = game.original
                    game.replacement.free()
                    game.replacement = null
                if mode == "caster":
                    finish(initial,witness.ok and frames < 60 and guardian.hp == 256 and witness.hp[guardian.id] == 256 and witness.births.size() == 1 and witness.contacts.size() == 1 and witness.damage.size() == 1 and witness.shield_records.size() == 1)
                elif mode == "dead_source":
                    finish(initial,witness.ok and frames < 60 and guardian.hp == 0 and worker.hp == 76 and witness.hp[worker.id] == 76 and witness.births.size() == 1 and witness.contacts.size() == 1 and witness.damage.size() == 27 and witness.used_contacts.size() == 27)
                else:
                    var label: String = CALLBACK if mode in ["contact_tick","replace_map","replace_player","replaced_source"] else CONTACT
                    var credited: int = 1 if mode == "duplicate_contact" else 0
                    finish(initial and (game.source_setup if mode == "replaced_source" else true),frames < 60 and game.callback_seen and game.preserved and not witness.ok and witness.failures == [label] and witness.births.size() == 1 and witness.contacts.size() == credited and witness.damage.size() == credited and witness.used_contacts.size() == credited and worker.hp == (90 if mode in ["replace_map","replace_player"] else 76) and witness.current())
            return
        initial = Engine.is_in_physics_frame() and witness.current() and witness.actor(guardian) and witness.actor(worker) and guardian.hp == 260 and worker.hp == 90 and guardian.active and worker.active
        if mode == "pistol":
            game.player.camera.look_at(guardian.global_position+guardian.get_child(0).position,Vector3.UP)
            Input.action_press("fire")
            game.player.set_physics_process(true)
            stage = 1
            return
        if mode == "crawler":
            var crawler = game.enemies.filter(func(actor): return actor.id == "ossuary_enemy_01")[0]
            initial = initial and witness.actor(crawler) and crawler.global_position.distance_to(guardian.global_position) < 1.9
            crawler.target = guardian
            crawler._begin_attack(guardian.global_position+Vector3.UP*0.7)
            crawler._release_attack()
            crawler._try_melee()
            finish(initial,witness.ok and guardian.hp == 256 and witness.hp[guardian.id] == 256 and witness.damage.size() == 1 and witness.used_contacts.size() == 1 and witness.shield_records.size() == 1)
            return
        if mode == "caster":
            var caster = game.enemies.filter(func(actor): return actor.id == "ossuary_enemy_05")[0]
            initial = initial and witness.actor(caster)
            caster.target = guardian
            caster._begin_attack(guardian.global_position+Vector3.UP*1.4)
            caster._release_attack()
            initial = initial and witness.ok and witness.births.size() == 1
            stage = 1
            return
        guardian.target = worker
        guardian._begin_attack(worker.global_position+Vector3.UP*1.4)
        if mode == "forged_release":
            guardian._released = true
            guardian._event("attack")
            finish(initial,not witness.ok and witness.failures == ["committed native attack release"] and witness.guardian_releases.is_empty() and witness.births.is_empty() and witness.damage.is_empty() and witness.used_contacts.is_empty())
            return
        guardian._release_attack()
        if mode in ["victim","rid","contact_tick","duplicate_contact","replace_map","replace_player","replaced_source","dead_source"]:
            initial = initial and witness.ok and witness.guardian_releases.size() == 1 and witness.births.size() == 1 and witness.guardian_birth_ticks.size() == 1
            if mode == "dead_source": game.probe_projectile.get_ref().set_physics_process(false)
            stage = 1
            return
        var duplicate: int = 1 if mode == "duplicate_birth" else 0
        var label: String = ADMISSION if mode in ["release_tick","dead_birth","duplicate_birth"] else IDENTITY
        finish(initial,game.callback_seen and game.preserved and not witness.ok and witness.failures == [label] and witness.guardian_releases.size() == 1 and witness.births.size() == duplicate and witness.guardian_birth_ticks.size() == duplicate and witness.damage.is_empty() and witness.used_contacts.is_empty())

func _initialize() -> void:
    AudioServer.set_bus_mute(0,true)
    call_deferred("run")

func run() -> void:
    var results: Array = []
    var retired: Array = []
    for mode in CASES:
        var game = ControlMain.new()
        var prefix: String = "user://guardian_extended_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
        game.progress_path = prefix+"_campaign.json"
        game.settings_path = prefix+"_preferences.json"
        game.prefix_bookkeeping_retired = true
        root.add_child(game)
        game.state.new_campaign(1)
        game.state.level_index = 5
        await game.start_level()
        game.set_process(false)
        game.set_physics_process(false)
        game.player.set_process(false)
        game.player.set_physics_process(false)
        game.player.set_process_unhandled_input(false)
        game.player.position = Vector3(96,0.04,94) if mode == "pistol" else Vector3(108,0.04,100)
        for actor in game.enemies:
            actor.set_process(false)
            actor.set_physics_process(false)
            actor.active = false
            actor.collision_layer = 0
            actor.collision_mask = 0
            if actor.id in ["ossuary_enemy_08","ossuary_enemy_02","ossuary_enemy_01","ossuary_enemy_05"]:
                actor.active = true
                actor.collision_layer = 4 if actor.id in ["ossuary_enemy_08","ossuary_enemy_02"] or mode == "caster" and actor.id == "ossuary_enemy_05" or mode == "crawler" and actor.id == "ossuary_enemy_01" else 0
                actor.collision_mask = 7
                actor.rotation.y = 0
                actor.position = Vector3(96,0.04,96) if actor.id == "ossuary_enemy_08" else Vector3(96,0.04,94.5) if actor.id == "ossuary_enemy_01" else Vector3(96,0.04,92) if actor.id == "ossuary_enemy_05" else Vector3(96,0.04,94)
                if mode in ["pistol","caster","crawler"] and actor.id == "ossuary_enemy_02": actor.collision_layer = 0
        var witness = Current.new()
        witness.game = game
        witness.scene = game.level
        witness.player = game.player
        witness.main_id = game.get_instance_id()
        witness.campaign_id = game.state.get_instance_id()
        witness.level_id = game.level.get_instance_id()
        witness.player_id = game.player.get_instance_id()
        witness.profile = game.progress_path
        witness.settings = game.settings_path
        witness.ledger = game.budget().duplicate(true)
        for actor in game.enemies:
            var capsule = actor.get_child(0)
            witness.bindings[actor.id] = [actor.get_instance_id(),capsule.get_instance_id(),capsule.shape.get_instance_id()]
            witness.hp[actor.id] = actor.hp
            witness.originals[actor.id] = []
            witness.activated[actor.encounter_id] = true
        for frame in range(12): await physics_frame
        game.control = mode
        game.transport_witness = witness
        var probe = Probe.new()
        probe.game = game
        probe.witness = witness
        probe.mode = mode
        root.add_child(probe)
        for frame in range(70):
            await physics_frame
            await process_frame
            if probe.done: break
        results.append(probe.report.duplicate(true))
        print("GUARDIAN_EXTENDED ",probe.report)
        Input.action_release("fire")
        game.transport_witness = null
        game.music.stop()
        game.effects.stop()
        for node in game.level.get_children():
            if node.get_script() == preload("res://scripts/projectile.gd"): retired.append(weakref(node))
        retired.append_array([weakref(game),weakref(game.level),weakref(game.player),weakref(probe)])
        game.free()
        probe.free()
        await process_frame
        await process_frame
        await WallClock.seconds(self,0.1)
    var valid: bool = results.size() == CASES.size() and results.all(func(row): return row.get("setup",false) and row.get("valid",false)) and retired.all(func(ref): return ref.get_ref() == null)
    if valid: print("PASS 22 controlled guardian geometry/callback/identity/lifetime cases; not earned campaign")
    else: push_error("NATIVE RED extended guardian controls require exact rejection/preserved evidence/production damage/drain")
    quit(0 if valid else 1)
