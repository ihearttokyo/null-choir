extends SceneTree

func _initialize() -> void:
	var layout = load("res://scripts/level_data.gd").new()
	if not expect(layout.load_level(0)): return
	if not expect(is_equal_approx(layout.height_at(Vector2(23,14)), 2.0)): return
	if not expect(is_equal_approx(layout.height_at(Vector2(23,21)), 1.0)): return
	if not expect(is_equal_approx(layout.height_at(Vector2(20,8)), 1.0)): return
	if not expect(layout.data.loops.size() >= 2): return
	var art = {}
	for loop in layout.data.loops:
		if not expect(loop.route[0] == loop.route[-1]): return
		if not expect(not art.has(loop.hero)): return
		art[loop.hero] = true
		for i in range(loop.route.size() - 1):
			if not expect(reachable(layout, Vector2i(loop.route[i][0],loop.route[i][1]), Vector2i(loop.route[i+1][0],loop.route[i+1][1]))): return
	for feature in layout.data.enemies + layout.data.pickups + layout.data.interactions + layout.data.heroes:
		if not expect(layout.is_walkable(Vector2i(floor(feature.cell[0]),floor(feature.cell[1])))): return
	if not expect(not reachable(layout, Vector2i(14,28), Vector2i(14,1), [Vector2i(13,5),Vector2i(14,5)])): return
	if not expect(not layout.load_level(-1) and not layout.load_level(8)): return
	print("PASS Intake authored closed routes, distinct loop art, connected placements and ramp elevations")
	quit()

func reachable(layout, start: Vector2i, finish: Vector2i, blocked: Array = []) -> bool:
	var queue = [start]
	var seen = {start: true}
	while not queue.is_empty():
		var cell = queue.pop_front()
		if cell == finish:
			return true
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next = cell + direction
			if layout.is_walkable(next) and not seen.has(next) and not next in blocked:
				seen[next] = true
				queue.append(next)
	return false

func expect(condition: bool) -> bool:
	if not condition:
		push_error("Level contract assertion failed")
		quit(1)
	return condition
