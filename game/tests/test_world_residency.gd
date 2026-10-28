extends SceneTree

class WorldOwner extends Node3D:
	var state = preload("res://scripts/campaign.gd").new()
	var level

var owner

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	owner = WorldOwner.new()
	root.add_child(owner)
	for cycle in range(3):
		owner.state.new_campaign(1)
		observe_memory("cycle_begin", cycle, -1)
		for index in range(8):
			if not expect(owner.state.level_index == index, "Campaign advances through all eight maps"): return
			owner.level = load("res://scripts/level.gd").new()
			owner.add_child(owner.level)
			if not expect(owner.level.build(owner,index),"Progressed actual Campaign has authoritative finite stock for selected map"): return
			var observed = capture_ownership(owner.level)
			if observed.is_empty(): return
			print("OBSERVE world_ownership cycle=", cycle, " map=", index,
				" scenes=", observed.scenes.size(), " nodes=", observed.nodes.size())
			observe_memory("built", cycle, index)
			owner.level.free()
			owner.level = null
			await process_frame
			await process_frame
			for path in observed.scenes:
				if not expect(observed.scenes[path].get_ref() == null,
					"PackedScene released after teardown: " + path): return
				if not expect(not ResourceLoader.has_cached(path),
					"Native scene cache ownership released: " + path): return
			for node_ref in observed.nodes:
				if not expect(node_ref.get_ref() == null, "Observed level and descendant nodes are freed"): return
			if not expect(owner.level == null and owner.get_child_count() == 0,
				"Owner retains neither a level nor child nodes"): return
			observe_memory("torn_down", cycle, index)
			owner.state.complete_level()
		if not expect(owner.state.level_index == 8, "Each cycle completes all eight Campaign maps"): return
		observe_memory("cycle_end", cycle, -1)
	cleanup()
	observe_memory("owner_freed", 3, -1)
	print("PASS source-native scene/cache/node ownership: 3 cycles x 8 maps; memory observations are not RSS/GPU or leak proof")
	quit()

func capture_ownership(level) -> Dictionary:
	# Return before teardown: only paths and WeakRefs escape this helper.
	var paths = {}
	var nodes = [weakref(level)]
	for node in level.find_children("*", "", true, false):
		nodes.append(weakref(node))
	for model in level.get_children():
		if model.scene_file_path.ends_with(".glb"):
			paths[model.scene_file_path] = paths.get(model.scene_file_path, 0) + 1
	if not expect(paths.get("res://assets/art/world/conduit.glb", 0) > 1,
		"Every map exercises repeated native world-art instances"): return {}
	if not expect(paths.size() == level._model_scenes.size(),
		"Every instantiated world-art path has one level-owned scene"): return {}
	var scenes = {}
	for id in level._model_scenes:
		var path = "res://assets/art/world/" + id + ".glb"
		var scene = level._model_scenes[id]
		if not expect(scene is PackedScene and paths.has(path),
			"Level owns a used native PackedScene: " + path): return {}
		if not expect(ResourceLoader.has_cached(path), "Scene stays cached during construction: " + path): return {}
		if not expect(load(path) == scene, "Native loads reuse the exact level-owned PackedScene: " + path): return {}
		scenes[path] = weakref(scene)
	return {"scenes": scenes, "nodes": nodes}

func observe_memory(stage: String, cycle: int, index: int) -> void:
	var bytes: int = OS.call("get_static_memory_usage") if OS.has_method("get_static_memory_usage") else 0
	if bytes > 0:
		print("OBSERVE static_memory stage=", stage, " cycle=", cycle, " map=", index, " bytes=", bytes)
	else:
		print("OBSERVE static_memory stage=", stage, " cycle=", cycle, " map=", index, " unavailable (API/build reports no measurement)")

func cleanup() -> void:
	if is_instance_valid(owner):
		if is_instance_valid(owner.level): owner.level.free()
		owner.level = null
		owner.free()
	owner = null

func expect(condition: bool, detail: String) -> bool:
	if not condition:
		cleanup()
		push_error(detail)
		quit(1)
	return condition
