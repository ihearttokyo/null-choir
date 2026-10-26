extends "res://tests/test_profile_pressure.gd"

var guard_spans: Dictionary = {"clear_point":[],"live_route":[]}

func measuring() -> bool:
	return is_instance_valid(game) and game.tracing

func clear_point(cell: Array):
	if not measuring(): return super.clear_point(cell)
	var started: int = Time.get_ticks_usec()
	var result = super.clear_point(cell)
	var elapsed: int = Time.get_ticks_usec()-started
	guard_spans.clear_point.append([walk_ticks,started,elapsed])
	return result

func live_route() -> bool:
	if not measuring(): return super.live_route()
	var started: int = Time.get_ticks_usec()
	var result: bool = super.live_route()
	var elapsed: int = Time.get_ticks_usec()-started
	guard_spans.live_route.append([walk_ticks,started,elapsed])
	return result

func finish(status: int) -> void:
	var summaries: Dictionary = {}
	for label in guard_spans:
		var spans: Array = guard_spans[label]
		if status == 0 and not expect(spans.size() == PROFILE_TICKS,"Every1440 native "+label+" guard must execute and be timed"):
			status = 1
		var top: Array = []
		var total: int = 0
		for index in range(spans.size()):
			var row: Array = spans[index]
			total += row[2]
			top.append({"tick":row[0],"start_us":row[1],"elapsed_us":row[2],"previous_start_gap_us":row[1]-spans[index-1][1] if index > 0 else null,"next_start_gap_us":spans[index+1][1]-row[1] if index+1 < spans.size() else null})
		top.sort_custom(func(a,b): return a.elapsed_us > b.elapsed_us)
		summaries[label] = {"n":spans.size(),"sum_us":total,"top":top.slice(0,8)}
	print("PRESSURE_HARNESS ",JSON.stringify({"guards":summaries,"scope":"existing test clearance/membership guards execute once per original call; inclusive elapsed may include native physics synchronization and host interruption, not threadCPU/GPU/display timing; adjacent gaps include normal60Hz pacing; no guard removed or optimization claimed"}))
	await super.finish(status)
