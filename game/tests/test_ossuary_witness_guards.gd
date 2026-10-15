extends SceneTree

const Transport = preload("res://tests/test_ossuary_transport_loop.gd")
const Witness = preload("res://tests/ossuary_transport_witness.gd")
const WallClock = preload("res://tests/wall_clock_wait.gd")
const SUMMON_CASES = ["summon","summon_death","unbacked_birth","duplicate_birth"]

class Probe:
    extends Node
    var game
    var witness
    var mode: String
    var done: bool = false
    var death_shots: int = 0
    var report: Dictionary = {}
    func _physics_process(_delta: float) -> void:
        if done: return
        done = true
        set_physics_process(false)
        if mode == "death_pending":
            var source = game.enemies.filter(func(actor): return actor.id == Witness.OWNER+"_add_1")[0]
            var worker = game.enemies.filter(func(actor): return actor.id == "ossuary_enemy_02")[0]
            var setup: bool = witness.ok and witness.actor(source) and witness.hp[source.id] == source.hp and source.hp == 50-10*death_shots and witness.damage.size() == 1+death_shots
            worker.target = source
            worker._begin_attack(source.global_position+Vector3.UP*0.7)
            worker._release_attack()
            death_shots += 1
            if death_shots < 5 and setup and witness.ok:
                done = false
                set_physics_process(true)
                return
            var valid: bool = setup and witness.ok and source.hp == 0 and witness.hp[source.id] == 0 and witness.deaths.get(source.id,0) == 1 and witness.finishes.get(source.id) == "infighting" and game.state.removed.count(source.id) == 1 and witness.lethal.is_empty() and witness.damage.size() == 6 and witness.used_contacts.size() == 6
            report = {"case":"summon_death","setup":setup,"valid":valid,"actual_hp":source.hp,"ledger_hp":witness.hp[source.id],"damage":witness.damage.size(),"tokens":witness.used_contacts.size(),"deaths":witness.deaths.duplicate(),"failures":witness.failures.duplicate()}
            return
        if mode in ["capture","save"]:
            var before: Dictionary = game.state.to_dict().duplicate(true)
            var original: String = FileAccess.get_sha256(game.progress_path)
            var setup: bool = witness.current() and not original.is_empty()
            var result = game._capture_actor_state() if mode == "capture" else game._save()
            var refused: bool = result == false if mode == "capture" else result == ERR_INVALID_DATA
            report = {"case":mode,"setup":setup,"valid":setup and refused and not witness.ok and witness.failures == ["forbidden transport side effect: "+mode] and game.state.to_dict() == before and FileAccess.get_sha256(game.progress_path) == original}
            return
        if mode in ["replace_map","replace_player"]:
            var source = game.enemies.filter(func(actor): return actor.id == "ossuary_enemy_01")[0]
            var old = game.level if mode == "replace_map" else game.player
            var replacement = Node3D.new() if mode == "replace_map" else CharacterBody3D.new()
            var setup: bool = witness.current() and witness.actor(source) and source.active and Engine.is_in_physics_frame()
            if mode == "replace_map":
                game.add_child(replacement)
                game.level = replacement
            else:
                game.level.add_child(replacement)
                game.player = replacement
            var hp: Dictionary = witness.hp.duplicate(true)
            source._event("windup")
            var refused: bool = not witness.current() and not witness.ok and witness.failures == ["production synchronous original/born enemy event"] and witness.hp == hp and witness.events.is_empty() and witness.damage.is_empty() and witness.used_contacts.is_empty()
            if mode == "replace_map": game.level = old
            else: game.player = old
            replacement.free()
            report = {"case":mode,"setup":setup,"valid":setup and refused and witness.current()}
            return
        if mode in SUMMON_CASES:
            var owner = game.enemies.filter(func(actor): return actor.id == Witness.OWNER)[0]
            var victim = game.enemies.filter(func(actor): return actor.id == "ossuary_enemy_04")[0]
            var setup: bool = witness.current() and witness.actor(owner) and witness.actor(victim) and owner._summon_budget() == 2
            if mode == "unbacked_birth":
                var fake = game.Enemy.new()
                game.level.add_child(fake)
                fake.configure(game,{"id":Witness.OWNER+"_add_1","kind":"crawler","cell":[23.6,24.0],"yaw":0})
                fake.set_process(false)
                fake.set_physics_process(false)
                fake._summon_owner_id = Witness.OWNER
                fake.target = victim
                game.enemies.append(fake)
                var original_hp: Dictionary = witness.hp.duplicate(true)
                var original_bindings: Dictionary = witness.bindings.duplicate(true)
                witness.register_summons()
                report = {"case":mode,"setup":setup,"valid":setup and not witness.ok and witness.failures == ["birth requires witnessed original summoner release"] and witness.summons.is_empty() and witness.hp == original_hp and witness.bindings == original_bindings}
                return
            owner.target = victim
            owner._begin_attack(victim.global_position+Vector3.UP*1.4)
            owner._release_attack()
            var born: Array = game.enemies.filter(func(actor): return actor._summon_owner_id == Witness.OWNER)
            var births: bool = born.size() > 0 and born.size() <= 2 and owner._summoned_total == born.size()
            var ray_ok: bool = false
            if births:
                var source = born[0]
                for actor in born:
                    actor.set_process(false)
                    actor.set_physics_process(false)
                var query = PhysicsRayQueryParameters3D.create(source.global_position+Vector3.UP*0.6,victim.global_position+Vector3.UP*0.7,7)
                query.exclude = [source.get_rid()]
                query.hit_from_inside = true
                var hit = game.level.get_world_3d().direct_space_state.intersect_ray(query)
                ray_ok = source.global_position.distance_to(victim.global_position) < 1.9 and hit.get("collider") == victim
                if mode == "duplicate_birth":
                    witness.register_summons()
                    var good: bool = witness.ok and witness.summons.size() == born.size()
                    var fake = game.Enemy.new()
                    game.level.add_child(fake)
                    fake.configure(game,{"id":source.id,"kind":"crawler","cell":[23.6,24.0],"yaw":0})
                    fake.set_process(false)
                    fake.set_physics_process(false)
                    # Foreign duplicate ID, not an extra owned summon: isolate identity.
                    fake.target = victim
                    fake.active = true
                    game.enemies.append(fake)
                    witness.register_summons()
                    good = good and witness.ok and fake._summon_owner_id.is_empty() and game.enemies.filter(func(actor): return actor.hp > 0 and actor._summon_owner_id == Witness.OWNER).size() == 2
                    var original_hp: Dictionary = witness.hp.duplicate(true)
                    var original_bindings: Dictionary = witness.bindings.duplicate(true)
                    var original_events: Array = witness.events.duplicate(true)
                    fake._event("windup")
                    report = {"case":mode,"setup":setup and births and good,"valid":setup and births and good and not witness.ok and witness.failures == ["production synchronous original/born enemy event"] and witness.hp == original_hp and witness.bindings == original_bindings and witness.events == original_events and witness.damage.is_empty() and witness.used_contacts.is_empty()}
                    return
                # Earliest same-physics-tick contact: no manual witness registration.
                source.target = victim
                source._begin_attack(victim.global_position+Vector3.UP*1.4)
                source._release_attack()
                source._try_melee()
                if mode == "summon_death" and witness.ok and victim.hp == 78 and witness.hp[victim.id] == 78:
                    # The newborn collider enters the native broadphase on the next tick.
                    mode = "death_pending"
                    done = false
                    set_physics_process(true)
                    return
            var valid: bool = setup and births and ray_ok and witness.ok and witness.summons.size() == born.size() and born.all(func(actor): return witness.actor(actor) and witness.hp.get(actor.id,-1) == actor.hp) and victim.hp == 78 and witness.hp[victim.id] == 78 and witness.damage.size() == (6 if mode == "summon_death" else 1) and witness.used_contacts.size() == (6 if mode == "summon_death" else 1)
            if mode == "summon_death": valid = valid and born[0].hp == 0 and witness.deaths.get(born[0].id,0) == 1 and witness.finishes.get(born[0].id) == "infighting" and game.state.removed.count(born[0].id) == 1 and witness.lethal.is_empty()
            report = {"case":mode,"setup":setup,"births":births,"born":born.map(func(actor): return [actor.id,actor.position,actor.hp]),"ray":ray_ok,"valid":valid,"actual_hp":victim.hp,"ledger_hp":witness.hp.get(victim.id),"registered":witness.summons.size(),"failures":witness.failures.duplicate()}
            return
        var source = game.enemies.filter(func(actor): return actor.id == ("ossuary_enemy_02" if mode == "worker" else "ossuary_enemy_01"))[0]
        var victim = game.enemies.filter(func(actor): return actor.id == "ossuary_enemy_04")[0]
        var query = PhysicsRayQueryParameters3D.create(source.global_position+Vector3.UP*(1.4 if mode == "worker" else 0.6),victim.global_position+Vector3.UP*(1.4 if mode == "worker" else 0.7),7)
        query.exclude = [source.get_rid()]
        query.hit_from_inside = true
        var hit: Dictionary = game.level.get_world_3d().direct_space_state.intersect_ray(query)
        var setup: bool = witness.current() and witness.actor(source) and witness.actor(victim) and hit.get("collider") == victim and hit.get("rid") == victim.get_rid() and victim.hp == 90
        if setup:
            source.target = victim
            source._begin_attack(victim.global_position+Vector3.UP*1.4)
            if mode == "positive":
                source._release_attack()
                source._try_melee()
            elif mode == "worker":
                # Deliberately forged event: neither production release nor damage.
                source._released = true
                source._event("attack")
            else:
                source._rush_hit = true
                source._event("melee_contact")
        var valid: bool = setup
        if mode == "positive":
            valid = valid and witness.ok and victim.hp == 78 and witness.hp[victim.id] == 78 and witness.damage.size() == 1 and witness.used_contacts.size() == 1
        else:
            valid = valid and not witness.ok and witness.failures == (["committed native attack release"] if mode == "worker" else ["committed native rush contact"]) and victim.hp == 90 and witness.hp[victim.id] == 90 and witness.damage.is_empty() and witness.used_contacts.is_empty() and witness.pending_player.is_empty() and witness.rituals.is_empty()
        report = {"case":mode,"setup":setup,"valid":valid,"actual_hp":victim.hp,"ledger_hp":witness.hp.get(victim.id),"damage":witness.damage.size(),"tokens":witness.used_contacts.size(),"failures":witness.failures.duplicate()}

func _initialize() -> void:
    AudioServer.set_bus_mute(0,true)
    call_deferred("run")

func save_controls() -> bool:
    var game = Transport.TransportMain.new()
    var prefix: String = "user://ossuary_guard_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
    game.progress_path = prefix+"_campaign.json"
    game.state.new_campaign(1)
    var file = FileAccess.open(game.progress_path,FileAccess.WRITE)
    if file == null:
        game.free()
        return false
    file.store_string("pre-existing owned predecessor canary")
    file.close()
    var original: String = FileAccess.get_sha256(game.progress_path)
    var before: Dictionary = game.state.to_dict().duplicate(true)
    var witness = Witness.new()
    game.transport_witness = witness
    var captured: bool = game._capture_actor_state()
    var capture_ok: bool = not captured and not witness.ok and witness.captures == 1 and game.state.to_dict() == before and FileAccess.get_sha256(game.progress_path) == original
    witness.ok = true
    var result: Error = game._save()
    var save_ok: bool = result == ERR_INVALID_DATA and not witness.ok and witness.saves == 1 and witness.captures == 1 and game.state.to_dict() == before and FileAccess.get_sha256(game.progress_path) == original
    game.transport_witness = null
    var ordinary: Error = game._save()
    var delegated: bool = ordinary == OK and FileAccess.get_sha256(game.progress_path) != original
    print("OSSUARY_SAVE_GUARDS ",{"capture":capture_ok,"save":save_ok,"ordinary_delegation":delegated})
    game.free()
    return capture_ok and save_ok and delegated

func run() -> void:
    if "--save-controls" in OS.get_cmdline_user_args():
        var valid: bool = save_controls()
        if valid: print("PASS controlled Ossuary capture/save guards preserve owned predecessor; ordinary delegation remains")
        quit(0 if valid else 1)
        return
    var results: Array = []
    var retired: Array = []
    for mode in ["positive","melee","worker","capture","save","replace_map","replace_player"]+SUMMON_CASES:
        var game = Transport.TransportMain.new()
        var prefix: String = "user://ossuary_guard_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
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
        game.player.position = Vector3(96,0.04,100)
        for actor in game.enemies:
            actor.set_process(false)
            actor.set_physics_process(false)
            actor.active = false
            actor.collision_layer = 0
            actor.collision_mask = 0
            if actor.id in (["ossuary_enemy_02","ossuary_enemy_04","ossuary_enemy_16"] if mode in SUMMON_CASES else ["ossuary_enemy_01","ossuary_enemy_02","ossuary_enemy_04"]):
                actor.active = true
                actor.collision_layer = 4
                actor.collision_mask = 7
                if mode in SUMMON_CASES:
                    actor.position = Vector3(96,0.04,92) if actor.id == "ossuary_enemy_02" else Vector3(92,0.04,96) if actor.id == "ossuary_enemy_16" else Vector3(96,0.04,96)
                else:
                    actor.position = Vector3(96,0.04,94.6) if actor.id == "ossuary_enemy_01" else Vector3(94.5,0.04,96) if actor.id == "ossuary_enemy_02" else Vector3(96,0.04,96)
        # Controlled binding, not earned adoption: exercise real scene/RID/stack callbacks.
        var witness = Witness.new()
        witness.game = game
        witness.scene = game.level
        witness.player = game.player
        witness.main_id = game.get_instance_id()
        witness.campaign_id = game.state.get_instance_id()
        witness.level_id = game.level.get_instance_id()
        witness.player_id = game.player.get_instance_id()
        witness.profile = game.progress_path
        witness.settings = game.settings_path
        for actor in game.enemies:
            var capsule = actor.get_child(0)
            witness.bindings[actor.id] = [actor.get_instance_id(),capsule.get_instance_id(),capsule.shape.get_instance_id()]
            witness.hp[actor.id] = actor.hp
            witness.originals[actor.id] = []
            witness.activated[actor.encounter_id] = true
        for frame in range(12): await physics_frame
        if mode in ["capture","save"]:
            if game._save() != OK:
                push_error("controlled setup requires a valid owned predecessor save")
                quit(1)
                return
            # The native view now differs from its retained recovery image.
            game.player.rotation.y = 0.5
        game.transport_witness = witness
        var probe = Probe.new()
        probe.game = game
        probe.witness = witness
        probe.mode = mode
        root.add_child(probe)
        for frame in range(7):
            await physics_frame
            await process_frame
        results.append(probe.report.duplicate(true))
        print("OSSUARY_CONTACT_GUARD ",probe.report)
        game.transport_witness = null
        game.music.stop()
        game.effects.stop()
        retired.append_array([weakref(game),weakref(game.level),weakref(game.player),weakref(probe)])
        game.free()
        probe.free()
        await process_frame
        await process_frame
    await WallClock.seconds(self,0.2)
    var valid: bool = results.size() == 11 and results.all(func(row): return row.get("valid",false)) and retired.all(func(ref): return ref.get_ref() == null)
    if valid: print("PASS eleven controlled bound Ossuary contact/save/stale-map/summon guards; not earned campaign")
    else: push_error("NATIVE RED Ossuary bound guards require valid positive plus side-effect-free provenance rejection")
    quit(0 if valid else 1)
