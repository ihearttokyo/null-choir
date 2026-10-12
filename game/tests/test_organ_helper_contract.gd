extends SceneTree
func _initialize() -> void:
	var source = load("res://tests/test_processional_earned_organ.gd")
	if source == null or not source.get_script_method_list().any(func(spec): return spec.name == "walk_to_organ_loop"):
		push_error("Missing actual nonquitting earned Organ loop helper")
		quit(1)
		return
	print("PASS actual parser exposes nonquitting earned Organ loop; traversal separate")
	quit(0)
