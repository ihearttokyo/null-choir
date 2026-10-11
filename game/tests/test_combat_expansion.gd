extends SceneTree

const Projectile = preload("res://scripts/projectile.gd")
var game
var test_prefix = "user://test_combat_expansion_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())

func _initialize() -> void:
	AudioServer.set_bus_mute(0,true)
	call_deferred("run")

func run() -> void:
	game = load("res://scripts/main.gd").new()
	game.progress_path = test_prefix+"_campaign.json"
	game.settings_path = test_prefix+"_preferences.json"
	root.add_child(game)
	# Controlled third-map entry, not an earned campaign route.
	game.state.new_campaign(1)
	game.state.level_index = 2
	game.loaded_positions = false
	await game.start_level()
	freeze_actors()
	if not (await check_pickups()): return
	if not "--pickups-only" in OS.get_cmdline_user_args():
		if not (await check_projectiles()): return
	var progress = game.progress_path
	game.show_title()
	game.queue_free()
	paused = false
	await process_frame
	await process_frame
	# Fixed-fps simulation timers can outrun the real audio thread at teardown.
	OS.delay_msec(100)
	await process_frame
	await process_frame
	if FileAccess.file_exists(progress): DirAccess.remove_absolute(progress)
	print("PASS native combat expansion"+(" pickups only" if "--pickups-only" in OS.get_cmdline_user_args() else " pickups, caster flight, swept collision, infighting, pause, lifetime and map cleanup"))
	quit()

func freeze_actors() -> void:
	game.set_process(false)
	game.player.set_physics_process(false)
	for actor in game.enemies: actor.set_physics_process(false)

func check_pickups() -> bool:
	var matches = game.level.layout.data.pickups.filter(func(pickup): return pickup.id == "processional_scattergun")
	if not expect(matches.size() == 1,"SETUP: Use the single authored Processional scattergun"): return false
	var spec: Dictionary = matches[0]
	if not expect(game.state.level_index == 2 and game.level.layout.data.id == "processional" and spec.kind == "weapon" and spec.weapon is float and spec.weapon == 2 and spec.amount == 16 and spec.cell == [20.5,25.5],"SETUP: Preserve the actual JSON weapon index, amount and source cell"): return false
	if not expect(game.level.markers.has(spec.id),"SETUP: Authored weapon must have its native marker"): return false
	var marker = game.level.markers[spec.id]
	if not expect(marker.position.is_equal_approx(game.level.layout.world_position(spec.cell)+Vector3.UP*0.06),"SETUP: Native pickup marker retains authored source geometry"): return false
	game.collect_pickup(spec.id)
	if not expect(2 in game.state.owned_weapons,"Weapon pickup must grant scattergun ownership"): return false
	if not expect(game.state.weapon == 2 and game.state.ammo[2] == 16,"New scattergun must be selected and supplied"): return false
	if not expect(spec.id in game.state.removed and not game.level.markers.has(spec.id),"Pickup must remove its marker"): return false
	game.collect_pickup(spec.id)
	if not expect(game.state.ammo[2] == 16 and game.state.owned_weapons == [0,1,2],"Duplicate pickup must not grant ammo or ownership twice"): return false
	await process_frame
	await physics_frame
	await physics_frame
	if not expect(not is_instance_valid(marker),"Collected marker must actually leave the scene"): return false
	if not expect(game._capture_actor_state(),"SETUP: Shared production actor capture precedes the controlled combat checkpoint"): return false
	game.state.mark_checkpoint("combat_checkpoint",game.player.position)
	var profile = game.player.WEAPONS[2]
	if not expect(profile.pellets == 7 and profile.damage == 15 and profile.interval == 0.7 and profile.range == 32.0 and profile.max_ammo == 32,"Scattergun retains its close-range profile and bounded reserve"): return false
	if not expect(game.player.fire() and game.state.ammo[2] == 15 and is_equal_approx(game.player.cooldown,0.7),"Real scattergun fire consumes one shell and sets cooldown"): return false
	if not expect(not game.player.fire() and game.state.ammo[2] == 15,"Cooldown blocks repeat fire without consuming ammo"): return false
	game.player._physics_process(0.35)
	if not expect(not game.player.fire(),"Half cooldown must still block fire"): return false
	game.player._physics_process(0.35)
	if not expect(game.player.fire() and game.state.ammo[2] == 14,"Cooldown expires through the native player tick"): return false
	game.player.cycle_weapon(1)
	if not expect(game.state.weapon == 0,"Inventory cycle wraps from scattergun to impact tool"): return false
	game.player.cycle_weapon(-1)
	if not expect(game.state.weapon == 2,"Inventory cycle returns to the earned scattergun"): return false
	game.hurt_player(300)
	await game.restore_checkpoint()
	freeze_actors()
	if not expect(game.playing and game.state.health == 100 and game.state.ammo[2] == 16 and game.state.weapon == 2 and spec.id in game.state.removed,"Death restores checkpoint weapon, ammo and pickup removal"): return false
	if not expect(game._save() == OK,"Save earned scattergun through the real game path"): return false
	game.show_title()
	await game.continue_campaign()
	freeze_actors()
	if not expect(game.state.owned_weapons == [0,1,2] and game.state.weapon == 2 and game.state.ammo[2] == 16 and spec.id in game.state.removed,"Save Continue restores earned inventory and one-shot removal"): return false
	# Controlled reavailability of the same authored weapon tests the owned-weapon branch.
	game.state.removed.erase(spec.id)
	game.state.weapon = 1
	game.state.ammo[2] = 31
	game.collect_pickup(spec.id)
	game.collect_pickup(spec.id)
	if not expect(game.state.weapon == 1 and game.state.ammo[2] == 32 and game.state.owned_weapons == [0,1,2],"Owned weapon refill caps ammo, preserves selection and remains one-shot"): return false
	if not expect(game.state.removed.count(spec.id) == 1,"Owned authored weapon refill records exactly one removal"): return false
	await game.restart_level()
	freeze_actors()
	if not expect(game.state.owned_weapons == [0,1] and game.state.ammo[2] == 0 and game.state.weapon == 1 and not spec.id in game.state.removed,"Level restart restores pre-pickup entry resources"): return false
	await game.continue_campaign()
	game.state.complete_level()
	game.loaded_positions = false
	await game.start_level()
	freeze_actors()
	if not expect(game.state.level_index == 3 and game.state.owned_weapons == [0,1,2] and game.state.ammo[2] == 16 and game.state.weapon == 2 and game.state.removed.is_empty(),"Level progression retains earned inventory while resetting removals"): return false
	await process_frame
	print("PASS native scattergun pickup, cap, firing/cooldown, checkpoint, save Continue, restart and progression")
	return true

func launch(source: CollisionObject3D, origin: Vector3, destination: Vector3) -> Node3D:
	var projectile = Projectile.new()
	game.level.add_child(projectile)
	projectile.configure(game,source,origin,destination)
	projectile.set_physics_process(false)
	return projectile

func check_projectiles() -> bool:
	if not expect(ResourceLoader.exists("res://assets/art/sprites/caster.png") and ResourceLoader.exists("res://assets/art/weapons/scattergun.png"),"Full combat validation requires the original caster and scattergun art"): return false
	game.show_title()
	paused = false
	await process_frame
	game.state.new_campaign(1)
	game.level = game.Level.new()
	game.level.process_mode = Node.PROCESS_MODE_PAUSABLE
	game.add_child(game.level)
	if not expect(game.level.layout.load_level(0),"Use the existing authored navigation layout"): return false
	var base = game.level.layout.world_position(game.level.layout.data.spawn)
	game.level._box(Vector3(40,1,40),base+Vector3.UP*1.5,game.level._material(Color.WHITE),true)
	game.player = game.Player.new()
	game.level.add_child(game.player)
	game.player.configure(game)
	game.player.position = base+Vector3(0,2.04,-12)
	game.player.set_physics_process(false)
	var caster = game.Enemy.new()
	game.level.add_child(caster)
	caster.configure(game,{"id":"combat_caster","kind":"caster","cell":game.level.layout.data.spawn,"yaw":0})
	caster.position = base+Vector3.UP*3.0
	caster.set_physics_process(false)
	game.enemies.append(caster)
	game.playing = true
	await physics_frame
	await physics_frame
	if not expect(caster.sprite.texture != null and caster.sprite.hframes == 8 and caster.sprite.vframes == 5 and is_equal_approx(caster.sprite.pixel_size*128,3.65),"Caster uses its real directional atlas at worker-scale height"): return false
	if not expect(caster.motion_mode == CharacterBody3D.MOTION_MODE_FLOATING and caster.floor_snap_length == 0,"Caster must float rather than snap to the floor"): return false
	caster._physics_process(0.05)
	if not expect(is_equal_approx(caster.telegraph_time,0.70) and game.state.health == 100,"Caster must present its full tell before release"): return false
	if not expect(not game.level.get_children().any(func(node): return node.get_script() == Projectile),"Caster cannot launch immediately during windup"): return false
	caster._physics_process(0.70)
	var projectile
	for node in game.level.get_children():
		if node.get_script() == Projectile: projectile = node
	if not expect(projectile != null and game.state.health == 100 and caster.pose_time > 0 and is_equal_approx(caster.attack_time,2.2),"Caster launches a visible projectile without instantaneous damage"): return false
	projectile.set_physics_process(false)
	if not expect(projectile.get_child(0) is MeshInstance3D and projectile.get_child(0).material_override.emission_enabled and projectile.get_child(1) is OmniLight3D,"Projectile has native glowing mesh and light feedback"): return false
	caster._physics_process(0)
	if not expect(int(caster.sprite.frame/8) == 3,"Caster retains directional attack poses"): return false
	var launched = 0
	for node in game.level.get_children():
		if node.get_script() == Projectile and not node.is_queued_for_deletion(): launched += 1
	if not expect(launched == 1,"Caster attack cooldown prevents duplicate launches"): return false
	var start = projectile.global_position
	projectile._physics_process(0.05)
	if not expect(projectile.global_position.distance_to(start) > 0.5 and game.state.health == 100 and not projectile.is_queued_for_deletion(),"Projectile travels visibly before damage"): return false
	projectile._physics_process(1.2)
	if not expect(game.state.health == 86 and projectile.is_queued_for_deletion(),"Projectile hits the real player capsule once"): return false
	projectile._physics_process(1)
	if not expect(game.state.health == 86,"Queued projectile cannot damage twice"): return false
	await process_frame
	if not expect(not is_instance_valid(projectile),"Hit projectile is freed"): return false
	for tick in range(10): caster._physics_process(0.1)
	if not expect(caster.position.y > base.y+2.8 and caster.position.y < base.y+3.25,"Caster hovers over native floor two metres above the layout height"): return false
	var wall = game.level._box(Vector3(2,2,0.05),base+Vector3(0,3.2,-6),game.level._material(Color.WHITE),true)
	await physics_frame
	await physics_frame
	projectile = launch(caster,caster.global_position+Vector3.UP*1.4,game.player.global_position+Vector3.UP)
	projectile.velocity = projectile.velocity.normalized()*3000
	projectile._physics_process(0.02)
	if not expect(projectile.is_queued_for_deletion() and game.state.health == 86 and absf(projectile.position.z-wall.position.z) < 0.1,"Swept fast projectile hits a thin wall without tunneling or hurting the player"): return false
	wall.queue_free()
	await process_frame
	await physics_frame
	projectile = launch(caster,caster.global_position+Vector3.UP*1.4,game.player.global_position+Vector3.UP)
	projectile.velocity = projectile.velocity.normalized()*3000
	projectile._physics_process(0.02)
	if not expect(projectile.is_queued_for_deletion() and game.state.health == 72,"Swept fast travel hits the real player capsule"): return false
	var worker = game.Enemy.new()
	game.level.add_child(worker)
	worker.configure(game,{"id":"combat_worker","kind":"worker","cell":game.level.layout.data.spawn,"yaw":0})
	worker.position = base+Vector3(0,2.03,-6)
	worker.set_physics_process(false)
	game.enemies.append(worker)
	await physics_frame
	await physics_frame
	projectile = launch(caster,caster.global_position+Vector3.UP*1.4,game.player.global_position+Vector3.UP)
	projectile._physics_process(1.2)
	if not expect(worker.hp == 76 and worker.target == caster and game.state.health == 72,"Intervening enemy takes projectile damage and starts infighting"): return false
	worker._physics_process(0)
	if not expect(is_equal_approx(worker.telegraph_time,0.45) and caster.hp == 90,"Infighting worker still gives its full tell before hitscan retaliation"): return false
	worker._physics_process(0.45)
	if not expect(caster.hp == 80 and caster.target == worker,"Existing worker hitscan retaliates and caster retargets"): return false
	caster.attack_time = 0
	caster._physics_process(caster.recovery_time)
	if not expect(is_equal_approx(caster.telegraph_time,0.70),"Infighting caster finishes recovery and gives a new full tell"): return false
	caster._physics_process(0.70)
	for node in game.level.get_children():
		if node.get_script() == Projectile and not node.is_queued_for_deletion(): projectile = node
	projectile.set_physics_process(false)
	if not expect(worker.hp == 76,"Infighting caster still uses delayed damage"): return false
	projectile._physics_process(1)
	if not expect(worker.hp == 62 and worker.target == caster,"Caster projectile retaliates against an enemy"): return false
	worker.queue_free()
	await process_frame
	await physics_frame
	for difficulty in [0,2]:
		game.state.new_campaign(difficulty)
		projectile = launch(caster,caster.global_position+Vector3.UP*1.4,game.player.global_position+Vector3.UP)
		projectile._physics_process(1.2)
		if not expect(game.state.health == 100-int(14*[0.7,1.0,1.4][difficulty]),"Projectile preserves fixed player difficulty scaling"): return false
	game.state.new_campaign(1)
	projectile = launch(caster,base+Vector3.UP*10,base+Vector3.UP*10+Vector3.RIGHT*1000)
	start = projectile.global_position
	projectile._physics_process(3.9)
	if not expect(not projectile.is_queued_for_deletion() and projectile.lifetime > 0,"Projectile remains alive until its finite lifetime"): return false
	projectile._physics_process(0.2)
	if not expect(projectile.is_queued_for_deletion() and is_equal_approx(projectile.global_position.distance_to(start),48),"Expiry clamps travel to the remaining lifetime"): return false
	projectile = launch(caster,base+Vector3.UP*10,base+Vector3.UP*10+Vector3.RIGHT*1000)
	start = projectile.global_position
	projectile.set_physics_process(true)
	game.pause_game()
	var lifetime = projectile.lifetime
	projectile._physics_process(0.5)
	await physics_frame
	await process_frame
	if not expect(not projectile.can_process() and projectile.global_position == start and projectile.lifetime == lifetime,"Level pause freezes projectile position and lifetime"): return false
	projectile.set_physics_process(false)
	game.resume_game()
	projectile._physics_process(0.1)
	if not expect(projectile.global_position != start and projectile.lifetime < lifetime,"Resume restores projectile travel"): return false
	projectile.queue_free()
	caster.target = game.player
	caster.attack_time = 0
	caster._physics_process(caster.recovery_time)
	if not expect(is_equal_approx(caster.telegraph_time,0.70),"Destroyed-shooter case must first launch through a complete caster tell"): return false
	caster._physics_process(0.70)
	for node in game.level.get_children():
		if node.get_script() == Projectile and not node.is_queued_for_deletion(): projectile = node
	projectile.set_physics_process(false)
	caster.free()
	projectile._physics_process(1.2)
	if not expect(projectile.is_queued_for_deletion() and game.state.health == 86,"Destroyed shooter does not invalidate in-flight player damage"): return false
	var survivor = game.Enemy.new()
	game.level.add_child(survivor)
	survivor.configure(game,{"id":"combat_survivor","kind":"caster","cell":game.level.layout.data.spawn,"yaw":0})
	survivor.position = base+Vector3.UP*3
	survivor.set_physics_process(false)
	var victim = game.Enemy.new()
	game.level.add_child(victim)
	victim.configure(game,{"id":"combat_victim","kind":"worker","cell":game.level.layout.data.spawn,"yaw":0})
	victim.position = base+Vector3(0,2.03,-6)
	victim.set_physics_process(false)
	await physics_frame
	await physics_frame
	projectile = launch(survivor,survivor.global_position+Vector3.UP*1.4,victim.global_position+Vector3.UP)
	survivor.free()
	projectile._physics_process(1)
	if not expect(victim.hp == 76 and victim.target == null,"Destroyed shooter safely yields null enemy damage attribution"): return false
	victim._physics_process(0)
	if not expect(victim.target == game.player,"Existing target fallback accepts destroyed shooter attribution"): return false
	var seeker = game.Enemy.new()
	game.level.add_child(seeker)
	seeker.configure(game,{"id":"combat_seeker","kind":"caster","cell":game.level.layout.data.spawn,"yaw":0})
	seeker.position = base+Vector3(5,3,0)
	seeker.set_physics_process(false)
	seeker.target = victim
	await physics_frame
	await physics_frame
	seeker._physics_process(0)
	if not expect(is_equal_approx(seeker.telegraph_time,0.70),"Targeted caster commits a complete tell before release"): return false
	seeker._physics_process(0.70)
	projectile = null
	for node in game.level.get_children():
		if node.get_script() == Projectile and not node.is_queued_for_deletion(): projectile = node
	if not expect(is_instance_valid(projectile),"Targeted caster releases a new projectile after its tell"): return false
	projectile.set_physics_process(false)
	start = projectile.global_position
	victim.free()
	seeker._physics_process(0)
	projectile._physics_process(0.1)
	if not expect(seeker.target == game.player and not projectile.is_queued_for_deletion() and projectile.global_position != start,"Destroyed target safely retargets caster while its projectile follows the launch trajectory"): return false
	projectile.queue_free()
	seeker.take_damage(1000,game.player)
	if not expect(seeker.hp == 0 and seeker.collision_layer == 0 and seeker.collision_mask == 0 and "combat_seeker" in game.state.removed,"Caster death retains collision and checkpoint removal conventions"): return false
	var removed_count = game.state.removed.size()
	seeker.take_damage(1,game.player)
	if not expect(game.state.removed.size() == removed_count,"Caster corpse removal is one-shot"): return false
	var player_position = game.player.position
	for view in [[Vector3.FORWARD,0],[Vector3.RIGHT,2],[Vector3.BACK,4],[Vector3.LEFT,6]]:
		game.player.position = seeker.position+seeker.basis*view[0]*5
		seeker._physics_process(0)
		if not expect(int(seeker.sprite.frame/8) == 4 and seeker.sprite.frame%8 == view[1],"Caster retains directional death frames"): return false
	game.player.position = player_position
	projectile = launch(seeker,base+Vector3.UP*10,base+Vector3.UP*10+Vector3.RIGHT*1000)
	var old_level = game.level
	var mesh_ref = weakref(projectile.get_child(0))
	var sphere_ref = weakref(projectile.get_child(0).mesh)
	var material_ref = weakref(projectile.get_child(0).material_override)
	var light_ref = weakref(projectile.get_child(1))
	# Discard transient projectile-fixture IDs before building a real authored entry.
	game.start_campaign(1)
	freeze_actors()
	projectile._physics_process(0.1)
	if not expect(projectile.is_queued_for_deletion(),"Old-map projectile cannot act in the replacement level"): return false
	await process_frame
	await process_frame
	if not expect(not is_instance_valid(old_level) and not is_instance_valid(projectile) and mesh_ref.get_ref() == null and sphere_ref.get_ref() == null and material_ref.get_ref() == null and light_ref.get_ref() == null,"Map teardown frees projectiles, mesh/light nodes and procedural resources"): return false
	return true

func expect(condition: bool, detail: String) -> bool:
	if not condition:
		push_error(detail)
		if is_instance_valid(game): game.free()
		paused = false
		quit(1)
	return condition
