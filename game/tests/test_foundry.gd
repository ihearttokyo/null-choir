extends SceneTree

func _initialize() -> void:
	var layout = load("res://scripts/level_data.gd").new()
	if not expect(layout.load_level(1),"Foundry must be an authored, loadable second level"): return
	if not expect(layout.data.id == "foundry" and layout.data.loops.size() == 2,"Two Foundry loops required"): return
	var heroes = []
	for loop in layout.data.loops:
		if not expect(loop.route[0] == loop.route[-1],"Traversal loop must close"): return
		if not expect(not loop.hero in heroes,"Each loop has its own hero"): return
		heroes.append(loop.hero)
		for i in range(loop.route.size()-1):
			if not expect(load("res://tests/test_level.gd").reachable(layout,Vector2i(loop.route[i][0],loop.route[i][1]),Vector2i(loop.route[i+1][0],loop.route[i+1][1])),"Disconnected loop"): return
	if not expect(heroes == ["vertebral_furnace","marrow_crucible"],"Bespoke Foundry hero identities"): return
	if not expect(is_equal_approx(layout.height_at(Vector2(26,12)),2.0),"Raised crucible gallery"): return
	if not expect(is_equal_approx(layout.height_at(Vector2(19.5,7)),1.0),"Northern ramp midpoint"): return
	if not expect(is_equal_approx(layout.height_at(Vector2(23,18.5)),1.0),"Southern ramp midpoint"): return
	if not expect(is_zero_approx(layout.height_at(Vector2(23,24))),"Foundry must not inherit Intake elevation"): return
	var stories = 0
	for feature in layout.data.enemies + layout.data.pickups + layout.data.interactions + layout.data.heroes:
		if not expect(layout.is_walkable(Vector2i(floor(feature.cell[0]),floor(feature.cell[1]))),"Feature outside floor: "+feature.id): return
		if feature.get("kind") == "story": stories += 1
	if not expect(stories == 1,"One optional environmental clue"): return
	if not expect(not load("res://tests/test_level.gd").reachable(layout,Vector2i(14,30),Vector2i(12,1),[Vector2i(12,4),Vector2i(13,4)]),"Gate must block the actual exit route"): return
	print("PASS native Foundry layout: two closed loops, distinct heroes, connected placements, independent ramp elevations and gated exit")
	quit()

func expect(condition: bool, detail: String) -> bool:
	if not condition:
		push_error(detail)
		quit(1)
	return condition
