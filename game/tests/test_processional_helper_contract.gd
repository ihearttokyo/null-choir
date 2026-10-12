extends SceneTree
func _initialize() -> void:
	var source = load("res://tests/test_processional_earned_entry.gd")
	if source == null or not source.get_script_method_list().any(func(spec): return spec.name == "walk_to_processional_entry"):
		push_error("Missing actual nonquitting Processional entry helper")
		quit(1)
		return
	print("PASS actual parser exposes nonquitting Processional entry; traversal separate")
	quit(0)
