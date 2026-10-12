extends SceneTree
# Typed constructor boundary only; real checkpoint and route evidence are separate.
func _initialize() -> void:
	var observer = preload("res://tests/test_foundry_earned_walk.gd").FoundryMain
	var budget = {"health":70,"armor":0,"ammo":[0,80,0,0,0,0],"owned_weapons":[0,1],"weapon":1}
	var capture = {"keys":["blood","ivory"],"removed":["foundry_checkpoint"],"checkpoint_id":"foundry_checkpoint","position":[10.0,0.0,20.0],"actors":[],"yaw":0.5,"pitch":0.2}
	var start = {"health":70,"ammo":[0,80,0,0,0,0],"checkpoint_id":"entry"}
	var current = {"checkpoint":{"health":1},"level_start":{"health":1},"difficulty":1}
	var result = observer.checkpoint_expectation(current,budget,capture,start)
	if result.checkpoint.get("health") != 70 or result.level_start != start or result.checkpoint.get("position") != capture.position:
		push_error("Independent checkpoint constructor must reject jointly stale current/saved resource baselines")
		quit(1)
		return
	result.checkpoint.ammo[1] = 0
	result.level_start.health = 1
	if budget.ammo[1] != 80 or start.health != 70 or current.checkpoint.health != 1:
		push_error("Expected snapshot must not alias live resources or original level-start")
		quit(1)
		return
	print("PASS typed independent checkpoint expectation and deep-copy boundaries; not live campaign")
	quit()
