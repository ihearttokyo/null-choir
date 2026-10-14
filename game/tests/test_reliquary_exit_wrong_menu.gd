extends "res://tests/test_reliquary_earned_exit.gd"
func run() -> void:
	if not await walk_through_reliquary_exit(ReliquaryExitMain.new()):
		await finish(1)
		return
	var offered: Array = game.menu.get_children().filter(func(node): return node is Button and not node.is_queued_for_deletion() and node.text == "Descend to The Nursery")
	if not expect(offered.size() == 1 and offered[0].get_signal_connection_list("pressed").size() == 1 and offered[0].get_signal_connection_list("pressed")[0].callable == Callable(game,"start_level"),"Wrong-menu control requires intact earned completion and exactly one original Nursery callback"):
		await finish(1)
		return
	offered[0].pressed.disconnect(Callable(game,"start_level"))
	offered[0].pressed.connect(Callable(game,"show_title"))
	var accepted: bool = reliquary_completion_result()
	if accepted: push_error("NATIVE RED Exit completion falsely accepted wrong Nursery callback after intact earned baseline")
	else: print("PASS wrong Nursery callback rejected; only binding changed, no input/physics/scene/save mutation")
	await finish(1 if accepted else 0)
