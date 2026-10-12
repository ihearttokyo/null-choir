extends SceneTree
func _initialize() -> void:
 var source = load("res://tests/test_foundry_earned_walk.gd")
 if source == null or not source.get_script_method_list().any(func(spec): return spec.name == "walk_to_foundry_exit"):
  push_error("Missing real nonquitting Foundry helper")
  quit(1)
  return
 print("PASS actual Godot parser exposes nonquitting Foundry helper; traversal acceptance separate")
 quit(0)
