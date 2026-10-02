extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var script = load("res://scripts/campaign.gd")
	if script == null:
		push_error("Missing campaign behavior")
		quit(1)
		return
	var state = script.new()
	state.new_campaign(1)
	if not expect(state.level_index == 0 and state.health == 100): return
	if not expect(state.owned_weapons == [0, 1]): return
	state.ammo[1] = 19
	state.mark_checkpoint("intake_bell", Vector3(12, 0, -4))
	state.damage(140)
	if not expect(state.health == 0): return
	state.restore_checkpoint()
	if not expect(state.health == 100 and state.ammo[1] == 19): return
	if not expect(state.checkpoint_id == "intake_bell"): return
	state.discover(0)
	state.complete_level()
	if not expect(state.level_index == 1 and state.discoveries == [0]): return
	state.health = 51
	state.mark_checkpoint("foundry_entry", Vector3(1, 0, 1))
	state.health = 8
	var snapshot = state.to_dict()
	var restored = script.new()
	if not expect(restored.from_dict(snapshot)): return
	if not expect(restored.health == 8 and restored.discoveries == [0]): return
	restored.restore_checkpoint()
	if not expect(restored.health == 51): return
	var before = restored.to_dict()
	if not expect(not restored.from_dict({"version": 999})): return
	if not expect(restored.to_dict() == before): return
	state.new_campaign(2)
	state.armor = 50
	state.damage(30)
	if not expect(state.health == 80 and state.armor == 40): return
	if not expect(not state.from_dict({"version": 1, "level_index": -1})): return
	# Checkpoint and entry keep exact native float32 floor positions across JSON.
	state.mark_checkpoint("entry",Vector3(18,0.04,134))
	state.mark_checkpoint("fractional_floor",Vector3(102,0.04,78))
	var path = "user://campaign_contract.json"
	if not expect(state.save_progress(path) == OK): return
	if not expect(restored.load_progress(path)): return
	if not expect(restored.to_dict() == state.to_dict()): return
	state.health = 73
	if not expect(state.save_progress(path) == OK): return
	if not expect(restored.load_progress(path) and restored.health == 73): return
	var malformed = state.to_dict()
	malformed.ammo[1] = 1.5
	if not expect(not restored.from_dict(malformed)): return
	malformed = state.to_dict()
	malformed.checkpoint.position = [0, INF, 0]
	if not expect(not restored.from_dict(malformed)): return
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	before = restored.to_dict()
	if not expect(not restored.load_progress(path) and restored.to_dict() == before): return
	if not expect(DirAccess.remove_absolute(path) == OK): return
	print("PASS campaign checkpoint, resource restoration, progression and invalid-save rejection")
	quit()

func expect(condition: bool) -> bool:
	if not condition:
		push_error("Campaign assertion failed")
		quit(1)
	return condition
