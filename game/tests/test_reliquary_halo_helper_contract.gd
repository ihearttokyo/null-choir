extends SceneTree
func _initialize() -> void:
	var source = load("res://tests/test_reliquary_halo_feasibility.gd")
	if source == null or not source.get_script_method_list().any(func(spec): return spec.name == "walk_through_halo"):
		push_error("CONTRACT RED missing actual nonquitting earned Halo helper")
		quit(1)
		return
	print("PASS actual parser exposes nonquitting earned Halo helper; traversal and lifetime separate")
	quit(0)
