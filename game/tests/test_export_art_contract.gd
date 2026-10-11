extends SceneTree

const Main = preload("res://scripts/main.gd")
const Level = preload("res://scripts/level.gd")
const PurposeContract = preload("res://tests/test_marker_purposes.gd")
var game

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = Main.new() # No _ready, audio, settings or save writes.
	var passed: bool = await check_maps()
	if is_instance_valid(game.level): game.level.free()
	game.free()
	if passed: print("PASS export art evaluator: eight authored maps, surviving purpose families and rejection counterfactuals; no graphics/app/art-quality claim")
	quit(0 if passed else 1)

func check_maps() -> bool:
	for index in range(8):
		game.state.new_campaign(1)
		game.state.level_index = index
		game.level = Level.new()
		root.add_child(game.level)
		if not expect(game.level.build(game,index),"Actual authored level builds"): return false
		var level = game.level
		var colliders = PurposeContract.collision_nodes(level)
		var before: Dictionary = game.state.to_dict().duplicate(true)
		if not expect(all_pass(game._export_art_checks()),"Complete actual art passes: "+level.layout.data.id): return false
		for spec in level.layout.data.pickups+level.layout.data.interactions:
			if not PurposeContract.check_marker(level,spec,expect): return false
		var spec: Dictionary = level.layout.data.pickups[0]
		var marker = level.markers[spec.id]
		var art: String = PurposeContract.expected_art(spec)
		level.remove_child(marker)
		var checks: Dictionary = game._export_art_checks()
		level.add_child(marker)
		if not expect(not checks["art_"+art] and not checks["marker_"+spec.id],"Dropped native instance fails multiplicity and ID"): return false
		var wrong = level._place_model("marker_exit",marker.position,180)
		level.markers[spec.id] = wrong
		checks = game._export_art_checks()
		level.markers[spec.id] = marker
		wrong.free()
		if not expect(not checks["marker_"+spec.id],"Unrelated GLB cannot impersonate a pickup ID"): return false
		var floor = level.find_children("Floor*","MeshInstance3D",false,false)[0]
		level.markers[spec.id] = floor
		checks = game._export_art_checks()
		level.markers[spec.id] = marker
		if not expect(not checks["marker_"+spec.id],"Actual floor mesh cannot satisfy imported marker identity"): return false
		var duplicate = level._place_marker(spec)
		checks = game._export_art_checks()
		duplicate.free()
		if not expect(not checks["art_"+art],"Extra purpose instance fails exact multiplicity"): return false
		var body = StaticBody3D.new()
		marker.add_child(body)
		checks = game._export_art_checks()
		body.free()
		if not expect(not checks["marker_"+spec.id],"Purpose scene cannot introduce a collision body"): return false
		var capsule
		for node in level.get_children():
			if node.scene_file_path.get_file() == "containment_capsule.glb":
				capsule = node
				break
		if not expect(capsule != null,"Current authored capsule scenery remains required"): return false
		level.remove_child(capsule)
		checks = game._export_art_checks()
		level.add_child(capsule)
		if not expect(not checks.art_containment_capsule,"Removing one authored capsule fails its retained scenery count"): return false
		if not expect(all_pass(game._export_art_checks()) and game.state.to_dict() == before and PurposeContract.collision_nodes(level) == colliders,"Read-only checks preserve state and exact collision-body identities"): return false
		game.state.removed.append(spec.id)
		level.remove_marker(spec.id)
		await process_frame
		await process_frame
		if not expect(all_pass(game._export_art_checks()) and PurposeContract.collision_nodes(level) == colliders,"Only remaining authored IDs contribute counts; visual removal leaves native bodies intact"): return false
		level.free()
		game.level = null
		await process_frame
	return true

func all_pass(checks: Dictionary) -> bool:
	return checks.values().all(func(value): return value)

func expect(condition: bool, detail: String) -> bool:
	if not condition: push_error(detail)
	return condition
