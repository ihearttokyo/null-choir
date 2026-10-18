extends "res://tests/test_reliquary_earned_entry.gd"
func run() -> void:
	prefix = "user://reliquary_pin_rejection_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	var observer = ReliquaryMain.new()
	var reference = weakref(observer)
	var result: bool = await walk_to_reliquary_entry(observer,prefix)
	var disposed: bool = reference.get_ref() == null
	var untouched: bool = game == null and root.get_child_count() == 0 and not FileAccess.file_exists(prefix+"_campaign.json") and not FileAccess.file_exists(prefix+"_preferences.json")
	if not expect(not result and disposed and untouched,"Rejected source/map pin disposes the unadopted observer before any tree/profile work"):
		if is_instance_valid(observer): observer.free()
		await finish(1)
		return
	print("PASS intended pin rejection: detached observer disposed, no tree insertion/profile work, no native orphan/resource leaks")
	await finish(0)
