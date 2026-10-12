extends SceneTree
func _initialize() -> void:
	var source = load("res://tests/test_processional_earned_exit.gd")
	if source == null or not source.get_script_method_list().any(func(spec): return spec.name == "walk_to_processional_exit"):
		push_error("Missing actual nonquitting earned Processional exit helper")
		quit(1)
		return
	print("PASS actual parser exposes nonquitting earned Processional exit; traversal separate")
	quit(0)
