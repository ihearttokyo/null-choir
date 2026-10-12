extends "res://tests/test_processional_earned_exit.gd"
func run() -> void:
	prefix = "user://processional_exit_handoff_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	if not await walk_to_processional_exit(ExitMain.new(),prefix):
		await finish(1)
		return
	if not expect(is_instance_valid(game) and game.get_instance_id() == x_main_id and game.progress_path == x_profile and game.state.level_index == 3 and not game.playing and game.level == null and game.player == null and game.state.to_dict() == game.x_exit_expected and retired.all(func(reference): return reference.get_ref() == null),"Earned helper returns same Main/profile/live SceneTree at fourth-level menu without quitting or replacing it"):
		await finish(1)
		return
	print("PASS nonquitting earned third-exit helper returns to its caller after complete native virtual-input prefix; no fourth start, physical input, GPU, audio or packed-app acceptance")
	await finish(0)
