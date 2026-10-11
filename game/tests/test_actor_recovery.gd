extends "res://tests/test_late_encounters.gd"

# G07 PREPARED ONLY / NOT RUN while native holds persist, including parsing.
# Nine independent cases: one actual late map, three fixed difficulties, and
# Continue/checkpoint-death/entry-restart boundaries. Clear poses, frozen AI and
# direct production damage/summoning are controlled staging, not full fights.
# Actor records below are fixture observations, not a proposed save schema.

func run() -> void:
	prefix = "user://actor_recovery_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	if not expect(AudioServer.get_driver_name() == "CoreAudio","SETUP: controlled actor recovery requires --audio-driver CoreAudio"):
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
	game.settings.auto_aim = false # The controlled resource shot must not seek a survivor.
	var passed: bool = true
	for difficulty in range(3):
		for boundary in ["Continue","checkpoint death","entry restart"]:
			if not await check_actor_recovery(difficulty,boundary): passed = false
	if passed:
		print("PASS G07 controlled actor recovery: Nursery/three fixed difficulties/three independent recovery boundaries; actual scene actors and separate player-resource controls. Not full combat or campaign victory.")
	await finish(0 if passed else 1)

func check_actor_recovery(difficulty: int, boundary: String) -> bool:
	game.loaded_positions = false
	await boot(4,difficulty)
	var label: String = "G07 controlled Nursery difficulty="+str(difficulty)+" "+boundary+": "
	if not expect(game.playing and not game.placement_pending and game.level.layout.data.id == "nursery",label+"actual registered map must start before staging"): return false
	var entry_resources: Dictionary = player_record()
	for field in entry_resources:
		if not expect(game.state.level_start.get(field) == entry_resources[field],label+"entry player control matches its actual level_start field: "+field): return false
	var entry_actors: Array = game.enemies.map(func(actor): return actor_record(actor))
	var summoner = actor_named("nursery_enemy_17")
	var survivor = actor_named("nursery_enemy_16")
	if not expect(summoner != null and survivor != null and summoner.kind == "summoner" and survivor.kind == "crawler" and summoner._summon_owner_id.is_empty() and survivor._summon_owner_id.is_empty(),label+"use the actual authored summoner and crawler survivor"): return false
	# Move real authored bodies into distinct clear delivery-arena poses. No
	# authored specs, HP, collision shapes or production placement code are replaced.
	if not await stage_actor(summoner,[29.5,7.5],0.73): return false
	if not await stage_actor(survivor,[29.5,11.5],-0.41): return false
	summoner.take_damage(1,game.player) # Existing damage exception wakes its real group.
	survivor.take_damage(7,game.player)
	if not expect(summoner.active and survivor.active and summoner.hp > 0 and summoner.hp < summoner.max_hp and survivor.hp > 0 and survivor.hp == survivor.max_hp-7 and membership_matches(),label+"actual damage leaves authored survivors alive and activates only native membership"): return false
	for round_index in range(3):
		if not expect(summoner._summon_budget() == 2,label+"each of exactly three controlled rituals admits only its bounded pair"): return false
		summoner._summon()
		freeze_adds()
		await settle()
		var pair: Array = living_adds()
		if not expect(pair.size() == 2 and summoner._summoned_total == (round_index+1)*2 and summoner._summon_budget() == 0,label+"production ritual creates exactly two owned adds, not retry-until-success"): return false
		for number in range(round_index*2+1,round_index*2+3):
			var add = actor_named(summoner.id+"_add_"+str(number))
			if not expect(add != null and add.hp > 0 and add.kind == "crawler" and add._summon_owner_id == summoner.id,label+"actual sequential birth identity/owner "+str(number)): return false
			if not capsule_clear(add): return false
			if round_index < 2:
				add.take_damage(10000,game.player)
				if not expect(add.hp == 0 and game.state.removed.count(add.id) == 1,label+"first four adds die through actual mortality/tombstones"): return false
		if round_index < 2:
			await settle()
			if not expect(living_adds().is_empty(),label+"only the first four births are killed during setup"): return false
	var fifth = actor_named(summoner.id+"_add_5")
	var sixth = actor_named(summoner.id+"_add_6")
	if not await stage_actor(fifth,[28.5,10.5],0.29): return false
	if not await stage_actor(sixth,[32.0,9.0],-0.67): return false
	fifth.take_damage(9,game.player)
	sixth.take_damage(11,game.player)
	if not expect(fifth.hp == fifth.max_hp-9 and sixth.hp == sixth.max_hp-11 and fifth.hp > 0 and sixth.hp > 0 and living_adds().size() == 2,label+"fifth/sixth remain damaged and alive; setup must not hide their loss"): return false
	if not check_birth_markers(summoner.id,label): return false
	# Earn the two actual keys with inherited native E-input helpers; the existing
	# automatic checkpoint, not direct mark_checkpoint or a fictional API, commits.
	for key in game.level.layout.data.interactions.filter(func(spec): return spec.kind == "key"):
		if not await interact_at(key): return false
	if not expect(game.state.keys.size() == 2 and "blood" in game.state.keys and "ivory" in game.state.keys,label+"native E actually earns both checkpoint seals"): return false
	var checkpoint_spec: Dictionary = interaction("checkpoint")
	if not expect(game.state.checkpoint_id == "entry" and not checkpoint_spec.id in game.state.removed,label+"actual checkpoint is still uncommitted before the staged actor/resource boundary"): return false
	if not move_to(checkpoint_spec.cell): return false
	game.player.camera.rotation.x = 1.1
	await physics_frame # Spend through the physics-owned firing boundary before capture.
	var ammo_before: int = game.state.ammo[1]
	if not expect(game.state.weapon == 1 and game.player.fire() and game.state.ammo[1] == ammo_before-1,label+"actual pistol fire spends a round before the recovery snapshot"): return false
	var retained_actors: Array = [actor_record(fifth),actor_record(sixth),actor_record(survivor),actor_record(summoner)]
	game._process(0)
	if not expect(game.state.checkpoint_id == checkpoint_spec.id and game.state.removed.count(checkpoint_spec.id) == 1 and game.state.position.is_equal_approx(game.player.position) and game.state.ammo[1] == ammo_before-1 and game.state.checkpoint.ammo[1] == ammo_before-1 and FileAccess.file_exists(game.progress_path),label+"actual proximity commits spent ammo and the moved player's native pose, not stale frozen campaign.position"): return false
	var checkpoint_resources: Dictionary = player_record()
	var saved_campaign: Dictionary = game.state.to_dict().duplicate(true)
	if not check_actor_records(retained_actors,label+"pre-boundary staging: "): return false
	if boundary == "Continue":
		game.pause_game()
		if not press_button("Save and return to title"): return false
		if not expect(not game.playing and game.level == null and game.player == null,label+"actual Save returns to title and retires the staged scene"): return false
		if not press_button("Continue"): return false
		if not await hold_recovery(label): return false
	elif boundary == "checkpoint death":
		# Proposed actor-checkpoint expectation: restore this observed coherent
		# boundary, including a sixth add killed AFTER it. No future fields accessed.
		fifth.take_damage(3,game.player)
		sixth.take_damage(10000,game.player)
		survivor.take_damage(5,game.player)
		if not expect(fifth.hp == retained_actors[0].hp-3 and sixth.hp == 0 and survivor.hp == retained_actors[2].hp-5 and game.state.removed.count(sixth.id) == 1,label+"actual post-checkpoint damage/death changes scene actors before restoration"): return false
		# A later production capture must not alias or replace frozen checkpoint actors.
		if not expect(game._save() == OK,label+"actual later save captures changed current actors without mutating the earlier checkpoint"): return false
		game.hurt_player(game.state.health+game.state.armor+1)
		if not expect(game.state.health == 0 and not game.playing and paused,label+"actual lethal player damage opens paused recovery"): return false
		if not press_button("Restore checkpoint"): return false
		if not await hold_recovery(label): return false
	else:
		game.pause_game()
		if not press_button("Restart level"): return false
		if not await hold_recovery(label): return false
		var restart_ok: bool = check_player_record(entry_resources,label)
		if not check_actor_records(entry_actors,label+"entry rewind: "): restart_ok = false
		summoner = actor_named("nursery_enemy_17")
		if not expect(summoner != null and summoner._summoned_total == 0 and summoner._summon_budget() == 2 and living_adds().is_empty() and flags().is_empty() and game.state.keys.is_empty() and game.state.removed.is_empty() and membership_matches(),label+"entry Restart intentionally rewinds damage, poses, births, removals, keys and encounter activation"): restart_ok = false
		return restart_ok
	# Keep resource controls independent, and do not short-circuit actor checks:
	# baseline dictionaries can match while BOTH missing adds and healed authored
	# HP are reported from the actual reconstructed scene.
	var recovered_ok: bool = check_player_record(checkpoint_resources,label)
	if boundary == "Continue" and not expect(game.state.to_dict() == saved_campaign,label+"existing exact campaign dictionary control remains independent of scene actors"): recovered_ok = false
	if not check_actor_records(retained_actors,label+"scene restoration: "): recovered_ok = false
	if not check_birth_markers("nursery_enemy_17",label): recovered_ok = false
	if not expect(membership_matches(),label+"restoration retains actual authored encounter memberships"): recovered_ok = false
	summoner = actor_named("nursery_enemy_17")
	if not expect(summoner != null and summoner._summoned_total == 6 and summoner._summon_budget() == 0,label+"six spent births retain an exhausted native lifetime budget"):
		return false
	var add_ids: Array = living_adds().map(func(actor): return actor.id)
	summoner._summon()
	freeze_adds()
	await settle()
	if not expect(living_adds().map(func(actor): return actor.id) == add_ids and summoner._summoned_total == 6 and summoner._summon_budget() == 0 and actor_named(summoner.id+"_add_7") == null and not "summon:"+summoner.id+":7" in game.state.removed,label+"actual exhausted ritual cannot create a seventh add or change the restored add set"): recovered_ok = false
	return recovered_ok

func stage_actor(actor, cell: Array, yaw: float) -> bool:
	if not expect(actor != null and floor_position(cell) != null,"SETUP: controlled actor staging requires an actual clear native floor pose at "+str(cell)): return false
	actor.set_physics_process(false)
	actor.position = game.level.layout.world_position(cell)+Vector3.UP*0.03
	actor.rotation.y = yaw
	actor.velocity = Vector3.ZERO
	await settle()
	return capsule_clear(actor)

func actor_record(actor) -> Dictionary:
	return {"id":actor.id,"kind":actor.kind,"owner":actor._summon_owner_id,"hp":actor.hp,"position":actor.position,"yaw":actor.rotation.y,"active":actor.active,"alerted":actor.alerted,"encounter":actor.encounter_id}

func player_record() -> Dictionary:
	# Only existing player/removal fields: scene actor expectations stay separate.
	var resources: Dictionary = game.state._resources()
	var record: Dictionary = {}
	for field in ["health","armor","ammo","owned_weapons","weapon","keys","removed","checkpoint_id","position"]:
		record[field] = resources[field]
	return record.duplicate(true)

func check_player_record(expected: Dictionary, label: String) -> bool:
	var ok: bool = expect(player_record() == expected,label+"exact player resources/removals retain spent ammo independently of actor records")
	var point = Vector3(expected.position[0],expected.position[1],expected.position[2])
	var size: float = game.level.layout.data.cell_size
	if not expect(game.playing and not game.placement_pending and game.state.position.is_equal_approx(point) and game.player.position.is_equal_approx(point+Vector3.UP*0.04) and game._valid_saved_position(point) and floor_position([point.x/size,point.z/size]) != null,label+"restored player has actual native floor/capsule clearance and the real +0.04 offset from its saved pose"): ok = false
	return ok

func check_actor_records(records: Array, label: String) -> bool:
	var ok: bool = true
	var expected_adds: Array = records.filter(func(record): return not record.owner.is_empty()).map(func(record): return record.id)
	var actual_adds: Array = living_adds().map(func(actor): return actor.id)
	expected_adds.sort()
	actual_adds.sort()
	if not expect(actual_adds == expected_adds,label+"exact live dynamic IDs survive; resource dictionary equality cannot prove this"): ok = false
	for record in records:
		var matches: Array = game.enemies.filter(func(actor): return is_instance_valid(actor) and actor.id == record.id)
		if not expect(matches.size() == 1,label+"exactly one actual scene actor must survive: "+record.id):
			ok = false
			continue
		var actor = matches[0]
		if not expect(actor._current_map() and actor.hp > 0 and actor.kind == record.kind and actor._summon_owner_id == record.owner and actor.encounter_id == record.encounter and actor.active == record.active and actor.alerted == record.alerted,label+"real actor identity/kind/ownership/membership: "+record.id): ok = false
		if not expect(actor.hp == record.hp,label+"survived damage must not heal on reconstruction: "+record.id): ok = false
		if not expect(actor.position.is_equal_approx(record.position) and is_zero_approx(wrapf(actor.rotation.y-record.yaw,-PI,PI)),label+"real actor pose/yaw must survive: "+record.id): ok = false
		if not capsule_clear(actor): ok = false
	return ok

func check_birth_markers(owner_id: String, label: String) -> bool:
	var ok: bool = true
	for number in range(1,7):
		if not expect(game.state.removed.count("summon:"+owner_id+":"+str(number)) == 1,label+"birth marker persists exactly once: "+str(number)): ok = false
		if not expect(game.state.removed.count(owner_id+"_add_"+str(number)) == (1 if number <= 4 else 0),label+"first four death tombstones remain; living fifth/sixth are not removals"): ok = false
	return ok

func hold_recovery(label: String) -> bool:
	if not expect(is_instance_valid(game.level) and is_instance_valid(game.player),label+"recovery must construct real native bodies before freezing"): return false
	freeze()
	freeze_adds()
	game.music.stop()
	await settle()
	if not expect(game.playing and not game.placement_pending and is_instance_valid(game.level) and is_instance_valid(game.player),label+"recovery must finish safe native placement before scene assertions"): return false
	freeze()
	freeze_adds()
	game.music.stop() # Loaded startup can begin the score after its physics awaits.
	return true
