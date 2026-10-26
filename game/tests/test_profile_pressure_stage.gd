extends "res://tests/test_profile_pressure_harness.gd"

var stage_rows: Array = []

func clear_point(cell: Array):
	if measuring():
		var started: int = Time.get_ticks_usec()
		var row: Dictionary = {
			"tick":walk_ticks,"sample_us":started,
			"physics_frame":Engine.get_physics_frames(),"process_frame":Engine.get_process_frames(),
			"process_us":Performance.get_monitor(Performance.TIME_PROCESS)*1000000.0,
			"physics_us":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000000.0,
			"navigation_us":Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS)*1000000.0,
			"active_objects":int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)),
			"collision_pairs":int(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS))}
		stage_rows.append(row)
		row["sample_elapsed_us"] = Time.get_ticks_usec()-started
	return super.clear_point(cell)

func finish(status: int) -> void:
	if status == 0:
		if not expect(stage_rows.size() == PROFILE_TICKS and guard_spans.clear_point.size() == PROFILE_TICKS and guard_spans.live_route.size() == PROFILE_TICKS,"Exactly1440 engine-stage samples paired with unchanged original guards"):
			status = 1
		for index in range(stage_rows.size()):
			var row: Dictionary = stage_rows[index]
			if not expect(row.tick == index and (index == 0 or row.physics_frame == stage_rows[index-1].physics_frame+1),"Native stage samples follow each original pressure physics tick exactly once"):
				status = 1
			for label in ["process_us","physics_us","navigation_us","sample_elapsed_us"]:
				if not expect(is_finite(float(row[label])) and float(row[label]) >= 0.0,"Finite nonnegative engine-published stage observation: "+label):
					status = 1
	var summaries: Dictionary = {}
	for label in ["process_us","physics_us","navigation_us","sample_elapsed_us"]:
		var ranked: Array = stage_rows.duplicate()
		ranked.sort_custom(func(a,b): return a[label] > b[label])
		var top: Array = []
		for row in ranked.slice(0,8):
			var item: Dictionary = row.duplicate()
			var index: int = int(row.tick)
			for guard in ["clear_point","live_route"]:
				if index < guard_spans[guard].size():
					var span: Array = guard_spans[guard][index]
					item[guard+"_start_us"] = span[1]
					item[guard+"_elapsed_us"] = span[2]
			top.append(item)
		var values: Array = stage_rows.map(func(row): return row[label])
		var initial_zero: int = 0
		var changes: int = 0
		var longest_hold: int = 0
		var hold: int = 0
		for index in range(values.size()):
			if initial_zero == index and values[index] == 0: initial_zero += 1
			if index == 0 or values[index] != values[index-1]:
				if index > 0: changes += 1
				hold = 1
			else: hold += 1
			longest_hold = maxi(longest_hold,hold)
		values.sort()
		var stats: Dictionary = {"n":values.size(),"nonzero":values.filter(func(value): return value > 0).size(),"p50":values[int(values.size()*0.5)] if not values.is_empty() else null,"p95":values[int(values.size()*0.95)] if not values.is_empty() else null,"max":values.back() if not values.is_empty() else null}
		if label == "sample_elapsed_us":
			summaries[label] = {"kind":"observer_wall_elapsed_samples","sampling_overhead_statistics":stats,"top":top}
		else:
			summaries[label] = {"kind":"held_engine_monitor_snapshots","held_value_snapshot_statistics":stats,"initial_zero_observations":initial_zero,"first_nonzero_tick":initial_zero if initial_zero < stage_rows.size() else null,"observed_value_changes_not_confirmed_refreshes":changes,"longest_identical_value_run_observations":longest_hold,"top":top}
	print("PRESSURE_NATIVE_STAGES ",JSON.stringify({"stages":summaries,"scope":"held engine monitor snapshots at the original clearance-call phase, not independent per-frame stage timings. Coarse publication can repeat old values and retain startup work from before pressure tracing; value changes are not confirmed refreshes. Snapshot quantiles/top rows describe repeated observations only. Sampling-overhead elapsed statistics are separate. Inclusive engine values may include fixture/host/native blocking and overlap; navigation stage excludes asynchronous bake-worker cost. Paired guard timestamps provide context only: no subtraction, threadCPU/GPU/display/FPS/freezediagnosis or optimization claim; zero navigation remains visible"}))
	await super.finish(status)
