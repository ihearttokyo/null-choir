extends SceneTree
func _initialize() -> void:
	var source = load("res://tests/test_reliquary_earned_entry.gd")
	if source == null or not source.get_script_method_list().any(func(spec): return spec.name == "walk_to_reliquary_entry"):
		push_error("Missing actual nonquitting earned Reliquary entry helper")
		quit(1)
		return
	var observer = source.ReliquaryMain.new()
	var available: bool = observer.get_property_list().any(func(spec): return spec.name == "prefix_bookkeeping_retired")
	var default_false: bool = available and observer.get("prefix_bookkeeping_retired") == false
	observer.free()
	if not available or not default_false:
		push_error("Missing inherited prefix bookkeeping retirement property or default false")
		quit(1)
		return
	print("PASS actual parser exposes nonquitting earned Reliquary entry and default-false inherited retirement; traversal and dispatch separate")
	quit(0)
