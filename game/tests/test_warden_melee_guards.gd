extends SceneTree

const WallClock = preload("res://tests/wall_clock_wait.gd")
const CASES = ["survive","lethal","intercept","armor0","armor1","armor2","range","wall","miss","rush","pause","queue_source","queue_victim","reparent_victim","replace_map","retire_map","replace_player"]
const CANCEL = ["pause","queue_source","queue_victim","reparent_victim","replace_map","retire_map","replace_player"]

class GuardMain:
    extends "res://scripts/main.gd"
    var observing: bool = false
    var cancellation: String = ""
    var cancelled: int = 0
    var mutation_ok: bool = false
    var contacts: Array = []
    var events: Array = []
    var holder: Node3D
    var spare_map: Node3D
    var spare_player: CharacterBody3D
    func _capture_game_mouse() -> void: pass
    func melee_ray(actor, intended) -> Dictionary:
        var query = PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*0.6,intended.global_position+Vector3.UP*0.7,1|2|4)
        query.exclude = [actor.get_rid()]
        query.hit_from_inside = true
        return level.get_world_3d().direct_space_state.intersect_ray(query)
    func enemy_event(actor, event: String) -> void:
        super.enemy_event(actor,event)
        if not observing: return
        events.append([actor.get_instance_id(),actor.id,event,Engine.get_physics_frames(),actor.hp,actor.collision_layer,actor.collision_mask])
        if event != "melee_contact": return
        var hit: Dictionary = melee_ray(actor,actor._committed_target)
        var body = hit.get("collider")
        var hp: int = state.health if body == player else body.hp if is_instance_valid(body) and body.has_method("take_damage") else -1
        var stack: bool = get_stack().any(func(row): return str(row.get("source","")).ends_with("/enemy.gd") and row.get("function","") == "_try_melee")
        contacts.append({"tick":Engine.get_physics_frames(),"source":actor.get_instance_id(),"source_id":actor.id,"intended":actor._committed_target.get_instance_id(),"victim":body.get_instance_id() if is_instance_valid(body) else 0,"rid":str(hit.get("rid")),"pre_hp":hp,"ray_from":actor.global_position+Vector3.UP*0.6,"ray_to":actor._committed_target.global_position+Vector3.UP*0.7,"hit_position":hit.get("position"),"native_rid":is_instance_valid(body) and hit.get("rid") == body.get_rid(),"stack":stack,"physics":Engine.is_in_physics_frame(),"enemy_physics_stack":get_stack().any(func(frame): return str(frame.get("source","")).ends_with("/enemy.gd") and frame.get("function","") == "_physics_process")})
        if cancellation.is_empty() or cancelled != 0: return
        cancelled += 1
        match cancellation:
            "pause":
                pause_game()
                mutation_ok = not playing and get_tree().paused
            "queue_source":
                actor.queue_free()
                mutation_ok = actor.is_queued_for_deletion()
            "queue_victim":
                body.queue_free()
                mutation_ok = body.is_queued_for_deletion()
            "reparent_victim":
                body.reparent(holder)
                mutation_ok = body.get_parent() == holder
            "replace_map":
                level = spare_map
                mutation_ok = level == spare_map and actor.get_parent() != level
            "retire_map":
                level.queue_free()
                mutation_ok = level.is_queued_for_deletion()
            "replace_player":
                player = spare_player
                mutation_ok = player == spare_player

class Probe:
    extends Node
    var game
    var source
    var intended
    var victim
    var case_name: String
    var bindings: Dictionary
    var steps: int = 0
    var done: bool = false
    var report: Dictionary = {}
    func _physics_process(_delta: float) -> void:
        if done: return
        var armor_case: bool = case_name.begins_with("armor")
        if steps == 0:
            var hit: Dictionary = game.melee_ray(source,intended)
            var body = hit.get("collider")
            var distance: float = source.position.distance_to(intended.position)
            var initial: int = 100 if armor_case else 20 if case_name == "lethal" else 90
            var setup: bool = Engine.is_in_physics_frame() and OS.is_debug_build() and game.playing and not get_tree().paused and game.level.layout.data.id == "nursery" and game.enemies.size() == 29
            setup = setup and not game.is_processing() and not game.is_physics_processing() and not game.player.is_physics_processing() and source.active and source.kind == "nursery_warden" and source._attack_variant == 0
            setup = setup and (game.state.health if armor_case else victim.hp) == initial and game.state.health == 100 and game.state.armor == (50 if armor_case else 0)
            for actor in game.enemies:
                var capsule = actor.get_child(0)
                setup = setup and actor.get_script() == game.Enemy and actor._current_map() and not actor.is_physics_processing() and capsule.shape is CapsuleShape3D and not capsule.disabled and bindings[actor.id] == [actor.get_instance_id(),capsule.get_instance_id(),capsule.shape.get_instance_id()]
            if case_name == "wall": setup = setup and distance < 2.4 and body is StaticBody3D and (body.collision_layer & 1) != 0 and body != victim and body.get_parent() == game.level and absf(hit.position.x-8.0) < 0.15
            elif case_name == "miss": setup = setup and distance < 2.4 and hit.is_empty() and victim.collision_layer == 0
            else: setup = setup and body == victim and hit.get("rid") == victim.get_rid() and (distance >= 2.4 if case_name == "range" else distance < 2.4)
            report = {"case":case_name,"setup":setup,"initial_hp":initial,"main":game.get_instance_id(),"map":game.level.get_instance_id(),"player":game.player.get_instance_id(),"source":source.get_instance_id(),"victim":victim.get_instance_id(),"source_capsule":[source.get_child(0).get_instance_id(),source.get_child(0).shape.get_instance_id()],"victim_capsule":[victim.get_child(0).get_instance_id(),victim.get_child(0).shape.get_instance_id()],"intended":intended.get_instance_id(),"victim_rid":str(victim.get_rid()),"distance":distance,"preflight_hit":str(hit),"bindings":bindings.duplicate(true),"ticks":[],"step_hp":[],"rush_states":[]}
            if not setup:
                finish()
                return
            source.target = intended
            source._begin_attack(intended.global_position+Vector3.UP*1.4)
            # Controlled staging expires the windup; release/contact/damage remain production calls.
            source.telegraph_time = 0.0
            source._release_attack()
            report.release = [source._committed_variant,source._rush_time,source._released]
        report.ticks.append(Engine.get_physics_frames())
        if case_name == "rush": source._physics_process(1.0/60.0)
        else: source._try_melee()
        steps += 1
        report.rush_states.append([source._rush_hit,source._rush_time,source.attack_time])
        report.step_hp.append(game.state.health if case_name.begins_with("armor") else victim.hp)
        if case_name == "rush" and steps == 1: return
        var rejected: bool = case_name in ["range","wall","miss"]
        var cancellation: bool = case_name in CANCEL
        var expected_hp: int = 90 if rejected or cancellation else 0 if case_name == "lethal" else 58
        var expected_health: int = [85,78,70][game.state.difficulty] if armor_case else 100
        var expected_armor: int = [43,40,36][game.state.difficulty] if armor_case else 0
        var deaths: Array = game.events.filter(func(row): return row[2] == "death")
        var attacks: Array = game.events.filter(func(row): return row[2] == "attack")
        var valid: bool = game.state.health == expected_health and game.state.armor == expected_armor and (armor_case or victim.hp == expected_hp) and game.contacts.size() == (0 if rejected else 1) and attacks.size() == 1 and report.release[0] == 0 and report.release[1] > 0 and report.release[2]
        valid = valid and report.source_capsule == [source.get_child(0).get_instance_id(),source.get_child(0).shape.get_instance_id()] and report.victim_capsule == [victim.get_child(0).get_instance_id(),victim.get_child(0).shape.get_instance_id()]
        if not rejected:
            var row: Dictionary = game.contacts[0] if game.contacts.size() == 1 else {}
            valid = valid and row.get("source") == report.source and row.get("source_id") == "nursery_warden" and row.get("victim") == report.victim and row.get("intended") == report.intended and row.get("rid") == report.victim_rid and row.get("pre_hp") == report.initial_hp and row.get("native_rid",false) and row.get("stack",false) and row.get("physics",false) and row.get("tick") == report.ticks[0]
        valid = valid and deaths.size() == (1 if case_name == "lethal" else 0) and game.state.removed.count(victim.id if not armor_case else "unused") == (1 if case_name == "lethal" else 0)
        if case_name == "lethal": valid = valid and victim.collision_layer == 0 and victim.collision_mask == 0 and deaths[0][0] == report.victim and deaths[0][4] == 0 and deaths[0][5] == 0 and deaths[0][6] == 0
        if cancellation: valid = valid and game.cancelled == 1 and game.mutation_ok
        else: valid = valid and game.cancelled == 0
        if case_name == "rush": valid = valid and steps == 2 and report.step_hp == [58,58] and report.ticks[1] == report.ticks[0]+1 and source._rush_hit and source._rush_time == 0 and game.contacts[0].enemy_physics_stack
        report.merge({"valid":valid,"hp":game.state.health if armor_case else victim.hp,"player_health":game.state.health,"armor":game.state.armor,"contacts":game.contacts.duplicate(true),"events":game.events.duplicate(true),"cancelled":game.cancelled,"mutation_ok":game.mutation_ok,"steps":steps})
        finish()
    func finish() -> void:
        game.observing = false
        # Detach gameplay pointers only after capturing outcomes; owned trees still free together.
        game.level = null
        game.player = null
        done = true
        set_physics_process(false)

func _initialize() -> void:
    AudioServer.set_bus_mute(0,true)
    if DisplayServer.get_name() != "headless":
        push_error("Warden guard fixture requires headless; no desktop pointer capture")
        quit(1)
        return
    call_deferred("run")

func run() -> void:
    print("WARDEN_GUARD_SOURCE enemy=",FileAccess.get_sha256("res://scripts/enemy.gd")," main=",FileAccess.get_sha256("res://scripts/main.gd")," campaign=",FileAccess.get_sha256("res://scripts/campaign.gd")," map=",FileAccess.get_sha256("res://data/05_nursery.json"))
    var results: Array = []
    var retired: Array = []
    for case_name in CASES:
        var difficulty: int = ["armor0","armor1","armor2"].find(case_name)
        if difficulty < 0: difficulty = 1
        var game = GuardMain.new()
        var prefix: String = "user://warden_guards_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())+"_"+case_name
        game.progress_path = prefix+"_campaign.json"
        game.settings_path = prefix+"_preferences.json"
        root.add_child(game)
        game.state.new_campaign(difficulty)
        game.state.level_index = 4
        game.start_level()
        game.set_process(false)
        game.set_physics_process(false)
        game.hud.hide()
        game.hud.set_process(false)
        game.hud.survey.set_process(false)
        game.hud.survey.set_physics_process(false)
        game.player.set_process(false)
        game.player.set_physics_process(false)
        game.player.set_process_unhandled_input(false)
        var bindings: Dictionary = {}
        for actor in game.enemies:
            actor.set_process(false)
            actor.set_physics_process(false)
            actor.active = false
            actor.collision_layer = 0
            actor.collision_mask = 0
            var capsule = actor.get_child(0)
            bindings[actor.id] = [actor.get_instance_id(),capsule.get_instance_id(),capsule.shape.get_instance_id()]
        var source = game.enemies.filter(func(actor): return actor.id == "nursery_warden")[0]
        var worker = game.enemies.filter(func(actor): return actor.id == "nursery_enemy_24")[0]
        var crawler = game.enemies.filter(func(actor): return actor.id == "nursery_enemy_22")[0]
        var armor_case: bool = case_name.begins_with("armor")
        var victim = game.player if armor_case else crawler if case_name == "lethal" else worker
        game.player.position = Vector3(18,0.04,134 if armor_case else 134.3 if case_name == "intercept" else 140)
        source.position = Vector3(9.5 if case_name == "wall" else 18,0.04,132)
        source.active = true
        source.collision_layer = 4
        source.collision_mask = 7
        if not armor_case:
            victim.position = Vector3(7.5 if case_name == "wall" else 18,0.04,132 if case_name == "wall" else 133.5 if case_name == "intercept" else 135 if case_name == "range" else 134)
            victim.active = true
            victim.collision_layer = 0 if case_name == "miss" else 4
            victim.collision_mask = 7
        if case_name == "lethal": victim.hp = 20
        if armor_case: game.state.armor = 50
        game.cancellation = case_name if case_name in CANCEL else ""
        game.holder = Node3D.new()
        game.add_child(game.holder)
        if case_name == "replace_map":
            game.spare_map = game.Level.new()
            game.add_child(game.spare_map)
            retired.append(weakref(game.spare_map))
        if case_name == "replace_player":
            game.spare_player = game.Player.new()
            game.level.add_child(game.spare_player)
            game.spare_player.configure(game)
            game.spare_player.collision_layer = 0
            game.spare_player.collision_mask = 0
            game.spare_player.set_physics_process(false)
            game.spare_player.set_process_unhandled_input(false)
            retired.append(weakref(game.spare_player))
        var probe = Probe.new()
        probe.process_mode = Node.PROCESS_MODE_ALWAYS
        probe.game = game
        probe.source = source
        probe.victim = victim
        probe.intended = game.player if case_name == "intercept" else victim
        probe.case_name = case_name
        probe.bindings = bindings
        retired.append_array([weakref(game),weakref(game.level),weakref(game.player),weakref(source),weakref(victim),weakref(game.holder),weakref(probe)])
        for frame in range(12): await physics_frame
        game.observing = true
        root.add_child(probe)
        for frame in range(4):
            await physics_frame
            if probe.done: break
        await process_frame
        results.append(probe.report.duplicate(true))
        print("WARDEN_GUARD_CASE ",probe.report)
        paused = false
        game.music.stop()
        game.effects.stop()
        game.free()
        probe.free()
        await process_frame
        await process_frame
        await WallClock.seconds(self,0.2)
    var valid: bool = results.size() == CASES.size() and results.all(func(row): return row.get("setup",false) and row.get("valid",false)) and retired.all(func(ref): return ref.get_ref() == null)
    if valid: print("PASS controlled native Warden melee guard/difficulty/contact controls; not earned combat/campaign, release-app parity, GUI/GPU, hearing or packed-app acceptance")
    else: push_error("NATIVE RED Warden guard control: require true setup, exact HP/armor/contact/death/cancellation and two-step once-per-rush outcomes; inspect WARDEN_GUARD_CASE")
    quit(0 if valid else 1)
