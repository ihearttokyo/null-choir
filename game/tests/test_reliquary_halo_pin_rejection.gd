extends "res://tests/test_reliquary_halo_feasibility.gd"
func run() -> void:
	if not expect(has_method("walk_through_halo"),"CONTRACT RED missing actual nonquitting earned Halo helper"):
		await finish(1)
		return
	prefix = "user://reliquary_halo_pin_rejection_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())
	var observer = FourthMain.new()
	var reference = weakref(observer)
	var result: bool = await call("walk_through_halo",observer,prefix)
	var disposed: bool = reference.get_ref() == null
	var untouched: bool = game == null and root.get_child_count() == 0 and not FileAccess.file_exists(prefix+"_campaign.json") and not FileAccess.file_exists(prefix+"_preferences.json") and not FileAccess.file_exists("user://campaign.json")
	if not expect(not result and disposed and untouched,"Deliberately rejected source pin disposes only the unadopted fresh observer before tree/profile work"):
		if is_instance_valid(observer): observer.free()
		await finish(1)
		return
	print("PASS intended Halo pin rejection; run only with a parent-owned deliberate dependency-pin mismatch")
	await finish(0)
