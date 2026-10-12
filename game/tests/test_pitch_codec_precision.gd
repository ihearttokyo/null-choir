extends SceneTree

const Campaign = preload("res://scripts/campaign.gd")
func _initialize() -> void:
	var values: Array = [Vector3(0.09440097212791443,0,0).x,-1.35,1.35,0.0,Vector3(-0.2,0,0).x,Vector3(0.2,0,0).x]
	for i in range(1,65): values.append(clampf(Vector3((i-32)*0.0403,0,0).x,-1.35,1.35))
	for index in values.size():
		var state = Campaign.new()
		state.new_campaign(1)
		state.pitch = values[index]
		state.mark_checkpoint("entry",Vector3.ZERO)
		var before: Dictionary = state.to_dict().duplicate(true)
		var path: String = "user://pitch_precision_"+str(OS.get_process_id())+"_"+str(index)+".json"
		var saved = Campaign.new()
		var error: Error = state.save_progress(path)
		var loaded: bool = error == OK and saved.load_progress(path)
		if not loaded or saved.to_dict() != before:
			push_error("RED: actual atomic codec must round-trip native/clamped camera pitch exactly in current/checkpoint/level-start; index="+str(index))
			quit(1)
			return
		if DirAccess.remove_absolute(path) != OK:
			push_error("Remove only this isolated fixture's own file")
			quit(1)
			return
	var state = Campaign.new()
	state.new_campaign(1)
	var legacy: Dictionary = state.to_dict().duplicate(true)
	if not state.from_dict(legacy) or state.pitch != null or state.checkpoint.has("pitch") or state.level_start.has("pitch"):
		push_error("Absent legacy facing remains absent")
		quit(1)
		return
	var imported: Dictionary = legacy.duplicate(true)
	imported.pitch = 0.2
	imported.checkpoint.pitch = 0.2
	imported.level_start.pitch = 0.2
	var native_pitch: float = Vector3(0.2,0,0).x
	if not state.from_dict(imported) or state.pitch != native_pitch or state.checkpoint.pitch != native_pitch or state.level_start.pitch != native_pitch:
		push_error("Imported pitch must use the actual native camera representation in all envelopes")
		quit(1)
		return
	state.new_campaign(1)
	for where in ["current","checkpoint","level_start"]:
		for value in [NAN,INF,-INF,1.3500001,-1.3500001]:
			var bad: Dictionary = legacy.duplicate(true)
			if where == "current": bad.pitch = value
			else: bad[where].pitch = value
			var before: Dictionary = state.to_dict().duplicate(true)
			if state.from_dict(bad) or state.to_dict() != before:
				push_error("Invalid pitch must reject atomically before canonicalization")
				quit(1)
				return
	print("PASS 70 exact native/clamped pitch codec round-trips; legacy absence and15 atomic invalid-pitch boundaries; no GUI/earned-campaign claim")
	quit(0)
