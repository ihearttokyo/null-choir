extends RefCounted

class PhysicsProbe:
	extends Node
	var pending: Callable
	var completed: bool = false
	var accepted: bool = false
	func _physics_process(_delta: float) -> void:
		if not pending.is_valid(): return
		var action: Callable = pending
		pending = Callable()
		accepted = action.call()
		completed = true
		set_physics_process(false)

static func scan(game) -> bool:
	if not is_instance_valid(game) or not game.is_inside_tree():
		push_error("Passive fixture needs its live Main")
		return false
	var scene = game.level
	var observer = game.player
	if not is_instance_valid(scene) or not is_instance_valid(observer) or game.is_processing() or observer.is_physics_processing():
		push_error("Passive fixture needs its staged map/player with automatic render/player callbacks held")
		return false
	var tree: SceneTree = game.get_tree()
	var pose: Vector3 = observer.position
	var driver = PhysicsProbe.new()
	var reference = weakref(driver)
	driver.process_mode = Node.PROCESS_MODE_ALWAYS
	driver.pending = func():
		if not is_instance_valid(game) or not is_instance_valid(scene) or not is_instance_valid(observer) or game.level != scene or game.player != observer or observer.position != pose: return false
		game.update_passive_triggers(observer)
		return true
	tree.root.add_child(driver)
	# physics_frame precedes Node callbacks; completion is checked on the following signal.
	for _frame in range(4):
		await tree.physics_frame
		if driver.completed: break
	var ok: bool = driver.completed and driver.accepted
	driver.pending = Callable()
	driver.free()
	ok = ok and reference.get_ref() == null and is_instance_valid(game) and is_instance_valid(scene) and is_instance_valid(observer) and game.level == scene and game.player == observer and observer.position == pose
	if not ok: push_error("Passive physics callback did not complete within four frames, preserve staged identities/pose, or drain its Node")
	return ok
