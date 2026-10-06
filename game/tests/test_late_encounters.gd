extends "res://tests/test_late_campaign_flow.gd"

const REGULAR_COUNTS = [28,27,30,32]
const LATE_ROLES = ["brute","guardian","summoner"]
const Projectile = preload("res://scripts/projectile.gd")

func run() -> void:
	prefix = "user://late_encounters_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	# First behavioral RED is real missing authored data, before Main/audio setup.
	for index in range(4,8):
		var layout = Layout.new()
		if not expect(layout.load_level(index),"SETUP: real registered late map must load"):
			await finish(1)
			return
		for kind in LATE_ROLES:
			if not expect(layout.data.enemies.any(func(spec): return spec.kind == kind),"LATE ENCOUNTERS RED: "+layout.data.id+" requires an authored "+kind):
				await finish(1)
				return
	if not expect(AudioServer.get_driver_name() == "CoreAudio","SETUP: requires --audio-driver CoreAudio"):
		await finish(1)
		return
	game = load("res://scripts/main.gd").new()
	game.settings_path = prefix+"_preferences.json"
	game.progress_path = prefix+"_campaign.json"
	root.add_child(game)
	game.set_process(false)
	game.set_process_unhandled_input(false)
	game.settings.head_bob = false
	game.settings.camera_shake = false
	for index in range(4,8):
		for difficulty in range(3):
			for order in [["first","second"],["second","first"]]:
				if not await check_integration(index,difficulty,order):
					await finish(1)
					return
			if index == 7 and not await check_heart_launcher(difficulty):
				await finish(1)
				return
	print("PASS late native encounters: all four maps/three fixed modes/both seal orders, real capsule staging, isolated once-only memberships, finite pickups, checkpoint/Continue and bounded persistent summon creation. Controlled staging, not full fights.")
	await finish(0)

func check_heart_launcher(difficulty: int) -> bool:
	# PREPARED ONLY / NOT RUN while native holds remain. Incoming inventory and
	# free capacity are explicitly staged; proximity/recovery use production paths.
	# No earlier weapon acquisition, combat route or boss victory is asserted.
	for mode in ["missing","owned","full"]:
		game.loaded_positions = false # Each staged case starts fresh, not as an imported save.
		await boot(7,difficulty)
		var pods: Array = game.level.layout.data.pickups.filter(func(spec): return spec.id == "heart_finale_launcher")
		if not expect(pods.size() == 1,"Heart retains exactly its actual finale launcher pod"): return false
		var spec: Dictionary = pods[0]
		if not expect(spec.kind == "weapon" and int(spec.weapon) == 4 and spec.amount == 8 and spec.cell == [30.5,18.5],"Actual Heart pod grants weapon 4 with unchanged eight rounds and authored cell"): return false
		var capacity: int = game.player.WEAPONS[4].max_ammo
		# Controlled incoming state, not ownership earned in earlier native fights.
		game.state.owned_weapons = [0,1,2] if mode == "missing" else [0,1,2,4]
		game.state.ammo = [0,0,0,0,0,0]
		game.state.ammo[4] = 0 if mode == "missing" else capacity-3 if mode == "owned" else capacity
		game.state.weapon = 1
		if not expect(game.playing and not game.placement_pending and flags().is_empty() and membership_matches() and game.level.markers.has(spec.id),"Staged Heart case begins live with its real pod and dormant encounters"): return false
		if not move_to(spec.cell): return false
		game._process(0) # Actual player proximity invokes Main's existing collector.
		if mode == "full":
			var full: Dictionary = game.state._resources().duplicate(true)
			if not expect(game.state.ammo[4] == capacity and game.state.weapon == 1 and game.state.owned_weapons == [0,1,2,4] and not spec.id in game.state.removed and game.level.markers.has(spec.id),"Full owned launcher leaves its actual pod unconsumed without switching weapons"): return false
			game._process(0)
			if not expect(game.state._resources() == full and game.level.markers.has(spec.id),"Repeated full-capacity proximity still preserves the pod"): return false
			game.state.ammo[4] = capacity-3 # Explicitly staged space, not a claimed fight.
			game._process(0)
		var expected_ammo: int = 8 if mode == "missing" else capacity
		var expected_weapon: int = 4 if mode == "missing" else 1
		if not expect(game.state.owned_weapons == [0,1,2,4] and game.state.weapon == expected_weapon and game.state.ammo == [0,0,0,0,expected_ammo,0] and game.state.removed.count(spec.id) == 1 and not game.level.markers.has(spec.id),"Real proximity grants a missed launcher/eight rounds or caps owned ammo without a spurious switch"): return false
		var collected: Dictionary = game.state._resources().duplicate(true)
		game._process(0)
		if not expect(game.state._resources() == collected and game.state.removed.count(spec.id) == 1,"Consumed actual launcher pod cannot grant ownership or ammo twice"): return false
		# Earn the real seals and automatic checkpoint; only poses are staged.
		for key in game.level.layout.data.interactions.filter(func(item): return item.kind == "key"):
			if not await interact_at(key): return false
		var checkpoint: Dictionary = interaction("checkpoint")
		if not move_to(checkpoint.cell): return false
		game._process(0)
		var finale: Dictionary = group_named("heart_finale")
		if not expect(game.state.checkpoint_id == checkpoint.id and checkpoint.id in game.state.removed and game.state.removed.count(spec.id) == 1 and group_dormant(finale) and membership_matches() and game._valid_saved_position(game.state.position),"Actual safe pre-final checkpoint captures the consumed launcher and dormant finale"): return false
		var recovery: Dictionary = game.state.checkpoint.duplicate(true)
		var saved: Dictionary = game.state.to_dict().duplicate(true)
		game.pause_game()
		if not press_button("Save and return to title"): return false
		if not expect(not game.playing and game.level == null and FileAccess.file_exists(game.progress_path),"Launcher case saves only its isolated future campaign profile and returns to title"): return false
		if not press_button("Continue"): return false
		freeze()
		game.music.stop()
		await settle()
		if not expect(game.playing and not game.placement_pending and game.state.level_index == 7 and game.state.difficulty == difficulty and game.state.to_dict() == saved and game._valid_saved_position(game.state.position) and game.player.position.is_equal_approx(game.state.position+Vector3.UP*0.04) and not game.level.markers.has(spec.id) and group_dormant(finale) and membership_matches(),"Actual safe Continue preserves exact launcher ownership/ammo/removal and checkpoint resources"): return false
		if not move_to(spec.cell): return false
		game._process(0)
		if not expect(game.state._resources() == recovery and game.state.removed.count(spec.id) == 1 and not game.level.markers.has(spec.id),"Revisiting the consumed launcher after Continue cannot recollect it"): return false
		await tap_key(KEY_5)
		game.player.camera.rotation.x = 1.1
		var ammunition: int = game.state.ammo[4]
		if not expect(game.state.weapon == 4 and game.player.fire() and game.state.ammo[4] == ammunition-1,"Real launcher selection/discharge spends one recovered round; not a boss fight"): return false
		game.hurt_player(game.state.health+game.state.armor+1)
		if not expect(game.state.health == 0 and not game.playing and paused,"Actual lethal damage enters launcher checkpoint recovery"): return false
		if not press_button("Restore checkpoint"): return false
		freeze()
		game.music.stop()
		await settle()
		if not expect(game.playing and not game.placement_pending and game.state._resources() == recovery and game.state.checkpoint == recovery and game._valid_saved_position(game.state.position) and game.player.position.is_equal_approx(game.state.position+Vector3.UP*0.04) and game.state.removed.count(spec.id) == 1 and not game.level.markers.has(spec.id) and group_dormant(finale) and membership_matches(),"Actual safe death restoration rewinds launcher spending without respawning its consumed pod or waking the finale"): return false
	print("STAGED Heart launcher difficulty=",difficulty," cases=missing/owned/full; actual proximity and isolated recovery, not campaign/boss completion")
	return true

func boot(index: int, difficulty: int) -> void:
	game.show_title()
	paused = false
	await process_frame
	await process_frame
	game.state.new_campaign(difficulty)
	game.state.level_index = index
	game.start_level()
	freeze()
	game.music.stop() # MIDI acceptance remains in the frozen live-flow fixture.
	await settle()

func check_integration(index: int, difficulty: int, order: Array) -> bool:
	await boot(index,difficulty)
	var data: Dictionary = game.level.layout.data
	var regular: Array = data.enemies.filter(func(spec): return spec.id.begins_with(data.id+"_enemy_"))
	if not expect(regular.size() == REGULAR_COUNTS[index-4] and data.encounters.size() == 5,"Original regular counts and five authored groups remain intact"): return false
	for kind in LATE_ROLES:
		var role_ids: Array = regular.filter(func(spec): return spec.kind == kind).map(func(spec): return spec.id)
		var introduced: bool = false
		for group in data.encounters:
			if group.id == data.id+"_finale": continue
			for id in group.enemy_ids:
				if id in role_ids: introduced = true
		if not expect(introduced,"Each actual late regular role introduces a branch/return commitment before the finale"): return false
	for spec in data.pickups:
		if spec.kind in ["ammo","weapon"]:
			var capacity: int = game.player.WEAPONS[int(spec.weapon)].max_ammo
			if not expect((spec.amount is float or spec.amount is int) and is_finite(spec.amount) and spec.amount >= 0 and spec.amount <= capacity and spec.amount == floor(spec.amount),"Every actual authored weapon/ammo pod is finite, integral and bounded by its native cap"): return false
	for spec in data.enemies:
		var actor = actor_named(spec.id)
		if not expect(actor != null and not actor.active,"Every actual authored actor starts dormant: "+spec.id): return false
		var groups: Array = data.encounters.filter(func(group): return spec.id in group.enemy_ids)
		if not expect(groups.size() == 1 and actor.encounter_id == groups[0].id,"Real actor configuration derives exact sole authored membership"): return false
		var expected_hp: int = int(actor.LATE.get(spec.kind,{"hp":50 if spec.kind == "crawler" else 90}).hp*[0.85,1.0,1.3][difficulty])
		if not expect(actor.hp == expected_hp and capsule_clear(actor),"Real staged HP/capsule honors fixed difficulty and native floor/solid/actor/roof clearance: "+spec.id): return false
	if not expect(game.state.health == 100 and flags().is_empty(),"Entry has no forced damage or activated encounter"): return false
	var entry_resources: Dictionary = game.state.to_dict().duplicate(true)
	for actor in game.enemies: actor.set_physics_process(true)
	await create_timer(1.3).timeout # Real dormant ticks span the longest regular windup.
	freeze()
	if not expect(game.enemies.all(func(actor): return actor.age >= 1.0 and not actor.active and actor.telegraph_time == 0 and actor._summoned_total == 0) and game.level.get_children().all(func(node): return not node is Projectile) and game.state.to_dict() == entry_resources,"Live dormant AI ticks cannot fire, summon, telegraph, activate or spend entry health/resources"): return false
	# Real damage is an activation exception, not a seal/region bypass assertion.
	var brute = game.enemies.filter(func(actor): return actor.kind == "brute")[0]
	var hit_group: String = brute.encounter_id
	brute.take_damage(1,game.player)
	if not expect(flags() == [hit_group] and membership_matches(),"A real dormant hit activates only its authored group"): return false
	game.restore_checkpoint()
	freeze()
	game.music.stop()
	await settle()
	if not expect(flags().is_empty() and membership_matches(),"Entry restoration rewinds the hit and all activation state"): return false
	if not recover_pools(data.id+"_entry_"): return false
	var finale: Dictionary = group_named(data.id+"_finale")
	if not enter_region(finale): return false
	game._process(0)
	if not expect(not "encounter:"+finale.id in game.state.removed and membership_matches(),"Final threshold with no seals cannot wake its guards or manifestation"): return false
	for branch in order:
		var commit: Dictionary = group_named(data.id+"_"+branch+"_commit")
		if not recover_pools(data.id+"_"+branch+"_approach_"): return false
		if not await activate_by_region(commit): return false
		var required = "blood" if branch == "first" else "ivory"
		var key: Dictionary = data.interactions.filter(func(spec): return spec.kind == "key" and spec.key == required)[0]
		var return_group: Dictionary = group_named(data.id+"_"+branch+"_return")
		if not enter_region(return_group): return false
		var before: Array = flags()
		game._process(0)
		if not expect(flags() == before and membership_matches(),"Seal-conditioned return cannot activate before its actual key"): return false
		if not await interact_at(key): return false
		if not expect(required in game.state.keys,"Production E input actually earns the return seal"): return false
		if not recover_pools(data.id+"_"+branch+"_return_"): return false
		if not await activate_by_region(return_group): return false
		if game.state.keys.size() == 1:
			if not enter_region(finale): return false
			game._process(0)
			if not expect(not "encounter:"+finale.id in game.state.removed and membership_matches(),"One seal still cannot wake final guards or the boss"): return false
	var checkpoint: Dictionary = interaction("checkpoint")
	if not recover_pools(data.id+"_finale_"): return false
	if not move_to(checkpoint.cell): return false
	game._process(0)
	if not expect(game.state.checkpoint_id == checkpoint.id and not "encounter:"+finale.id in game.state.removed and membership_matches(),"Both branch orders store actual recovery before final commitment"): return false
	var recovery: Dictionary = game.state.to_dict().duplicate(true)
	if not await interact_at(data.doors[0]): return false
	if not expect(not game.level.doors.has(data.doors[0].id),"Actual E opens the two-seal native gate after the recovery snapshot"): return false
	if not await activate_by_region(finale): return false
	if not await check_creation_budget(recovery,finale): return false
	game.pause_game()
	if not press_button("Restart level"): return false
	freeze()
	game.music.stop()
	await settle()
	var restarted = game.enemies.filter(func(actor): return actor.kind == "summoner")[0]
	if not expect(game.playing and game.state.checkpoint_id == "entry" and game.state.keys.is_empty() and game.state.removed.is_empty() and flags().is_empty() and membership_matches() and restarted._summoned_total == 0 and living_adds().is_empty(),"Actual Restart level rewinds earned seals, recovery pickups, activations and creation markers to dormant entry"): return false
	print("STAGED map=",data.id," difficulty=",difficulty," first_branch=",order[0]," authored=",data.enemies.size())
	return true

func actor_named(id: String):
	for actor in game.enemies:
		if is_instance_valid(actor) and actor.id == id: return actor
	return null

func group_named(id: String) -> Dictionary:
	return game.level.layout.data.encounters.filter(func(group): return group.id == id)[0]

func flags() -> Array:
	return game.level.layout.data.encounters.filter(func(group): return "encounter:"+group.id in game.state.removed).map(func(group): return group.id)

func membership_matches() -> bool:
	for group in game.level.layout.data.encounters:
		for id in group.enemy_ids:
			var actor = actor_named(id)
			if actor == null or actor.active != ("encounter:"+group.id in game.state.removed): return false
	return true

func activate_by_region(group: Dictionary) -> bool:
	var before: Array = flags()
	if not expect(not group.id in before,"SETUP: chosen commitment was not triggered by its earlier resupply"): return false
	if not enter_region(group): return false
	game._process(0)
	var expected: Array = before+[group.id]
	var after: Array = flags()
	expected.sort()
	after.sort()
	if not expect(after == expected and membership_matches() and game.state.removed.count("encounter:"+group.id) == 1 and game.message == group.cue.text,"Only the intended actual group activates at its qualified threshold"): return false
	if not expect(game.effects.players.seal_release.playing,"First actual threshold emits its original native encounter sound"): return false
	for id in group.cue.light_ids:
		var earned: bool = game.level.layout.data.heroes.any(func(hero): return hero.get("seal","") in game.state.keys and id in hero.get("light_ids",[]))
		var expected_color: Color = Color(1.0,0.76,0.44) if earned else Color(1.0,0.28,0.1)
		if not expect(game.level.machine_lights.has(id) and game.level.machine_lights[id].light_color.is_equal_approx(expected_color),"Actual feed-light cue changes its native machine, while earned seal light retains priority"): return false
	game.message_time = 1.25
	game.effects.players.seal_release.stop()
	game._process(0)
	return expect(game.message_time == 1.25 and not game.effects.players.seal_release.playing and game.state.removed.count("encounter:"+group.id) == 1,"Repeated threshold processing cannot replay cue text/audio or duplicate activation")

func recover(spec: Dictionary) -> bool:
	if not expect(spec.kind == "ammo" and (spec.amount is float or spec.amount is int) and is_finite(spec.amount) and spec.amount > 0 and spec.amount == floor(spec.amount),"Actual authored ammo supply is positive finite integral JSON data"): return false
	if not move_to(spec.cell): return false
	var weapon: int = int(spec.weapon)
	var before: int = game.state.ammo[weapon]
	var capacity: int = game.player.WEAPONS[weapon].max_ammo
	game._process(0)
	if not expect(game.state.ammo[weapon] == mini(capacity,before+int(spec.amount)) and (spec.id in game.state.removed if before < capacity else not spec.id in game.state.removed),"Production pickup respects finite capacity and leaves a full recovery pod available"): return false
	var after: int = game.state.ammo[weapon]
	game._process(0)
	return expect(game.state.ammo[weapon] == after,"Finite actual pickup cannot duplicate ammunition")

func recover_pools(id_prefix: String) -> bool:
	# Real native pickup storage/caps; these controlled poses do not certify a
	# reachable combat route, late weapon ownership, or a completion budget.
	for spec in game.level.layout.data.pickups:
		if spec.kind == "ammo" and spec.id.begins_with(id_prefix):
			if not recover(spec): return false
	return true

func capsule_clear(actor) -> bool:
	var collider: CollisionShape3D = actor.get_child(0)
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.transform = collider.global_transform
	query.collision_mask = 1|2|4
	query.exclude = [actor.get_rid()]
	var space = actor.get_world_3d().direct_space_state
	if not expect(space.intersect_shape(query,8).is_empty(),"Actual dormant/add capsule cannot overlap world, heroes, scenery, player or other actors: "+actor.id): return false
	var layout = game.level.layout
	var cell: Vector2 = Vector2(actor.position.x,actor.position.z)/float(layout.data.cell_size)
	var floor_point: Vector3 = layout.world_position([cell.x,cell.y])
	var ray = PhysicsRayQueryParameters3D.create(floor_point+Vector3.UP*0.5,floor_point-Vector3.UP,1)
	var hit = space.intersect_ray(ray)
	var hover: float = 1.0 if actor.kind in ["caster","choir_avatar"] else 0.0
	if not expect(layout.is_walkable(Vector2i(cell.floor())) and not hit.is_empty() and absf(hit.position.y-floor_point.y) < 0.08 and absf(actor.position.y-floor_point.y-hover) < 0.1,"Actual actor has authored native floor and correct grounded/hover height: "+actor.id): return false
	# Roof meshes are visual, not physical colliders; verify their native authored height too.
	for offset in [Vector2.ZERO,Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
		var point: Vector2 = cell+offset*float(collider.shape.radius)/float(layout.data.cell_size)
		var ceiling: float = layout.world_position([point.x,point.y]).y+layout.roof_height(Vector2i(point.floor()))
		if not expect(actor.position.y+collider.shape.height+0.03 < ceiling,"Real capsule top/footprint remains below the authored native roof: "+actor.id): return false
	return true

func living_adds() -> Array:
	return game.enemies.filter(func(actor): return is_instance_valid(actor) and actor.hp > 0 and not actor._summon_owner_id.is_empty())

func freeze_adds() -> void:
	for actor in living_adds(): actor.set_physics_process(false)

func check_creation_budget(recovery: Dictionary, finale: Dictionary) -> bool:
	var summoner = game.enemies.filter(func(actor): return actor.kind == "summoner")[0]
	var id: String = summoner.id
	if not expect(game.enemies.any(func(actor): return actor.kind == "crawler" and actor._summon_owner_id.is_empty() and actor.hp > 0) and summoner._summon_budget() == 2,"Authored crawler populations do not consume the native owned/global add caps"): return false
	summoner._summon()
	freeze_adds()
	await settle()
	if not expect(living_adds().size() == 2 and summoner._summoned_total == 2 and summoner._summon_budget() == 0,"Actual role placement admits a native bounded pair, never more than two owned adds"): return false
	for add in living_adds():
		if not capsule_clear(add): return false
		add.take_damage(10000,game.player) # Actual mortality/removed strings, not a scripted battle claim.
	game.player.camera.rotation.x = 1.1
	var ammunition: int = game.state.ammo[1]
	if not expect(game.state.weapon == 1 and game.player.fire() and game.state.ammo[1] == ammunition-1,"Real pistol discharge spends an actual resource before the save/recovery boundary"): return false
	if not expect(game._capture_actor_state(),"SETUP: actual shared save capture precedes the exact observed campaign boundary"): return false
	var saved: Dictionary = game.state.to_dict().duplicate(true)
	var cue_lights: Array = []
	for group in game.level.layout.data.encounters: cue_lights.append(light_colors(group.cue.light_ids))
	game.pause_game()
	if not press_button("Save and return to title"): return false
	if not press_button("Continue"): return false
	freeze()
	game.music.stop()
	await settle()
	summoner = actor_named(id)
	if not expect(summoner != null and game.state.to_dict() == saved and membership_matches() and summoner._summoned_total == 2 and summoner._summon_budget() == 2 and living_adds().is_empty(),"Actual Save/Continue retains spent creation markers and group state, not fresh lifetime budget"): return false
	var restored_lights: Array = []
	for group in game.level.layout.data.encounters: restored_lights.append(light_colors(group.cue.light_ids))
	if not expect(restored_lights == cue_lights and not game.effects.players.seal_release.playing,"Continue restores actual machine-light consequences silently, without replaying the encounter sound"): return false
	for _round in range(2):
		summoner._summon()
		freeze_adds()
		await settle()
		if not expect(living_adds().size() == 2 and living_adds().size() <= 4,"Owned and native global add bounds remain finite after restoration"): return false
		for add in living_adds():
			if not capsule_clear(add): return false
			add.take_damage(10000,game.player)
	if not expect(summoner._summoned_total == 6 and summoner._summon_budget() == 0,"Real continued summoner stops at six births across its saved life"): return false
	summoner._summon()
	if not expect(living_adds().is_empty(),"An exhausted actual summoner cannot create a seventh add"): return false
	game.hurt_player(game.state.health+game.state.armor+1)
	if not expect(game.state.health == 0 and not game.playing and paused,"Actual damage enters recovery without fixture invulnerability"): return false
	if not press_button("Restore checkpoint"): return false
	freeze()
	game.music.stop()
	await settle()
	summoner = actor_named(id)
	return expect(game.playing and game.state.to_dict() == recovery and not "encounter:"+finale.id in game.state.removed and membership_matches() and summoner._summoned_total == 0 and summoner._summon_budget() == 2 and living_adds().is_empty(),"Real pre-final checkpoint rewinds removed creation markers, budget, deaths, resources and final dormancy")
