extends SceneTree

func _initialize() -> void:
	var layout = load("res://scripts/level_data.gd").new()
	if not expect(layout.load_level(2),"Processional must be an authored loadable third level"): return
	var legacy = layout.original_floor(2)
	if not expect(layout.data.id == "processional" and layout.data.loops.size() == 2,"Two Processional loops required"): return
	var heroes = []
	for loop in layout.data.loops:
		if not expect(loop.route[0] == loop.route[-1] and not loop.hero in heroes,"Closed route and unique loop landmark required"): return
		heroes.append(loop.hero)
		for i in range(loop.route.size()-1):
			if not expect(load("res://tests/test_level.gd").reachable(layout,Vector2i(loop.route[i][0],loop.route[i][1]),Vector2i(loop.route[i+1][0],loop.route[i+1][1])),"Disconnected Processional loop"): return
	if not expect(heroes == ["walking_bone_organ","ossified_palanquin"],"Original Processional landmark identities"): return
	if not expect(is_equal_approx(legacy.height_at(Vector2(12,11)),0.75),"Organ approach ramp midpoint"): return
	if not expect(is_equal_approx(legacy.height_at(Vector2(21,8)),1.0),"Palanquin approach ramp midpoint"): return
	if not expect(is_equal_approx(legacy.height_at(Vector2(7,14)),1.5) and is_equal_approx(legacy.height_at(Vector2(27,12)),2.0),"Distinct raised chambers"): return
	if not expect(is_equal_approx(layout.height_at(Vector2(7,14)),2.5) and is_equal_approx(layout.height_at(Vector2(21,8)),5.0),"Revision1 distinct raised chambers"): return
	if not expect(is_equal_approx(layout.height_at(Vector2(12,11)),25.0/6.0) and is_equal_approx(layout.height_at(Vector2(27,12)),10.0/3.0),"Revision1 organ and palanquin approach ramps"): return
	var stories = 0
	var scatterguns = 0
	var casters = 0
	for feature in layout.data.enemies + layout.data.pickups + layout.data.interactions + layout.data.heroes:
		if not expect(layout.is_walkable(Vector2i(floor(feature.cell[0]),floor(feature.cell[1]))),"Feature outside floor: "+feature.id): return
		if feature.get("kind") == "story": stories += 1
		if feature.get("kind") == "weapon" and feature.get("weapon") == 2: scatterguns += 1
		if feature.get("kind") == "caster": casters += 1
	if not expect(stories == 1 and scatterguns == 1 and casters >= 2,"One optional clue, earned scattergun and projectile-caster encounters"): return
	if not expect(not load("res://tests/test_level.gd").reachable(layout,Vector2i(21,29),Vector2i(15,1),[Vector2i(15,4),Vector2i(16,4)]),"Gate must block the actual exit route"): return
	print("PASS native Processional layout: two distinct closed loops, raised organ/palanquin chambers, gated exit, optional clue and new combat introductions")
	quit()

func expect(condition: bool, detail: String) -> bool:
	if not condition:
		push_error(detail)
		quit(1)
	return condition
