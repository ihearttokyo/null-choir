extends "res://tests/test_actor_recovery.gd"

# Direct native production boundaries in isolated profiles; no replacement actors.
func run() -> void:
	prefix = "user://actor_lifecycle_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	if not expect(AudioServer.get_driver_name() == "CoreAudio","SETUP: actor lifecycle requires CoreAudio"):
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
	for difficulty in range(3):
		if not await owner_death_and_legacy(difficulty):
			await finish(1)
			return
	if not await level_history():
		await finish(1)
		return
	print("PASS controlled native actor owner-death, transient reset, legacy capture, authoritative empty, failed-exit rollback and retired-level boundaries; not full combat")
	await finish(0)

func owner_death_and_legacy(difficulty: int) -> bool:
	game.loaded_positions = false
	await boot(4,difficulty)
	var owner = actor_named("nursery_enemy_17")
	var owner_id: String = owner.id
	if not await stage_actor(owner,[29.5,7.5],0.73): return false
	owner.take_damage(1,game.player)
	owner._summon()
	freeze_adds()
	await settle()
	if not expect(living_adds().size() == 2,"Actual owner creates its bounded pair before death"): return false
	var expected: Array = []
	for add in living_adds():
		add.take_damage(3,game.player)
		add.attack_time = 3
		add.telegraph_time = 1
		add.velocity = Vector3.ONE
		expected.append(actor_record(add))
	owner.take_damage(10000,game.player)
	if not expect(owner.hp == 0 and living_adds().size() == 2,"Actual authored owner death does not kill its children"): return false
	game.pause_game()
	if not expect(game._save() == OK,"Owner-death current snapshot saves through production capture"): return false
	var saved: Dictionary = game.state.to_dict()
	if not press_button("Save and return to title") or not press_button("Continue"): return false
	if not await hold_recovery("owner death: "): return false
	if not expect(actor_named(owner_id) == null and game.state.to_dict() == saved,"Dead owner stays absent without dropping live child records"): return false
	if not check_actor_records(expected,"owner-death live children: "): return false
	for add in living_adds():
		if not expect(add.attack_time == 0 and add.telegraph_time == 0 and add.target == null and add.velocity == Vector3.ZERO,"Fresh native restoration resets transient attacks/targets/velocity without healing"): return false
	# An old save may already have lost born-not-dead nodes. Keep it explicitly legacy.
	var legacy = saved.duplicate(true)
	legacy.erase("actors")
	if not expect(game.state.from_dict(legacy),"Legacy current with independent authoritative entry/checkpoint loads"): return false
	game.show_title()
	if not expect(game._save() == OK,"Save unknown legacy envelope without manufacturing actors"): return false
	if not press_button("Continue") or not await hold_recovery("legacy: "): return false
	if not expect(living_adds().is_empty() and game.state.actors == null,"Legacy reconstruction cannot invent lost living adds"): return false
	var removals: Array = game.state.removed.duplicate()
	if not expect(game._save() == OK and game.state.actors == null and game.state.removed == removals and not game.state.to_dict().has("actors"),"Ambiguous native capture stays legacy without inventing deaths or refunds"): return false
	game.pause_game()
	if not press_button("Restart level") or not await hold_recovery("legacy entry restart: "): return false
	return expect(game.state.actors is Array and living_adds().is_empty() and game.state.removed.is_empty(),"Coherent authoritative entry still restores independently of legacy current")

func level_history() -> bool:
	game.loaded_positions = false
	await boot(4,1)
	for actor in game.enemies: actor.take_damage(10000,game.player)
	if not expect(game._save() == OK and game.state.actors == [],"Last actual authored death captures an authoritative empty array"): return false
	game.pause_game()
	if not press_button("Save and return to title") or not press_button("Continue"): return false
	if not await hold_recovery("empty living set: "): return false
	if not expect(game.enemies.is_empty() and game.state.actors == [],"Continue never rebuilds full-health actors from explicit empty"): return false
	for key in game.level.layout.data.interactions.filter(func(spec): return spec.kind == "key"):
		if not await interact_at(key): return false
	var exit_spec: Dictionary = interaction("exit")
	var disk_path: String = game.progress_path
	game.progress_path = prefix+"_absent_parent/campaign.json"
	if not await interact_at(exit_spec): return false
	# Native E stages the actual exit. Freeze the next retry's exact boundary,
	# rather than comparing against the player's earlier pre-interaction pose.
	await physics_frame
	var prior: Dictionary = game.state.to_dict()
	if not expect(game.nearest_interaction().get("id","") == exit_spec.id,"Actual failed exit remains the nearest native interaction"): return false
	game.interact()
	if not expect(game.playing and game.level.layout.data.id == "nursery" and game.state.to_dict() == prior,"Actual failed exit save rolls back the full prior actor envelope"): return false
	game.progress_path = disk_path
	game.interact()
	if not expect(game.level == null and game.state.level_index == 5 and game.state.actors == null and not game.state.checkpoint.has("actors") and not game.state.level_start.has("actors"),"Successful exit clears all retired actor snapshots before next-level save"): return false
	var pending: Dictionary = game.state.to_dict()
	if not expect(game._save() == OK and game.state.to_dict() == pending,"Missing retired scene cannot recapture into the pending level"): return false
	if not press_button("Descend to "+"THE OSSUARY".capitalize()): return false
	freeze()
	game.music.stop()
	await settle()
	if not expect(game.playing and game.level.layout.data.id == "ossuary" and game.state.actors is Array and game.state.level_start.actors == game.state.actors,"Next authored entry captures only its own constructed actors"): return false
	return expect(game.state.actors.all(func(record): return record.id.begins_with("ossuary_")),"No prior-level IDs contaminate fresh entry")
