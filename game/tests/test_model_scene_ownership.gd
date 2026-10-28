extends SceneTree

const StaticSelectedLevel = preload("res://tests/fixtures/static_selected_level.gd")
class WorldOwner extends Node3D:
	var state = preload("res://scripts/campaign.gd").new()
	var level

var owner
func _initialize(): call_deferred("run")
func run():
	owner = WorldOwner.new()
	root.add_child(owner)
	owner.state = StaticSelectedLevel.fresh_selected(0,1)
	owner.level = load("res://scripts/level.gd").new()
	owner.add_child(owner.level)
	if not expect(owner.level.build(owner,0),"Fresh selected Intake fixture builds before scene ownership checks"): return
	var path = "res://assets/art/world/conduit.glb"
	if not expect(ResourceLoader.has_cached(path), "Level must retain the repeated native PackedScene"): return
	var models = owner.level.get_children().filter(func(n): return n.scene_file_path == path)
	if not expect(models.size() == 214, "All original boundary placements remain scene instances"): return
	var paths = {}
	for model in owner.level.get_children():
		if model.scene_file_path.ends_with(".glb"):
			paths[model.scene_file_path] = true
	for model_path in paths:
		if not expect(ResourceLoader.has_cached(model_path), "Every authored world scene remains level-owned"): return
	owner.level.free()
	owner.level = null
	await process_frame
	await process_frame
	for model_path in paths:
		if not expect(not ResourceLoader.has_cached(model_path), "Level destruction must release its PackedScene ownership"): return
	owner.free()
	owner = null
	print("PASS level-owned PackedScene reuse, unchanged placements and teardown release")
	quit()

func expect(value: bool, detail: String) -> bool:
	if not value:
		if is_instance_valid(owner): owner.free()
		owner = null
		push_error(detail)
		quit(1)
	return value
