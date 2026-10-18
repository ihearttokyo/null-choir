extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var trace_script = load("res://scripts/app_frame_trace.gd")
	if not expect(trace_script != null,"INTENDED RED: app-owned bounded trace helper must exist"): return
	var fixed_metrics_existed: bool = FileAccess.file_exists(trace_script.METRICS_PATH)
	var fixed_metrics_sha: String = FileAccess.get_sha256(trace_script.METRICS_PATH) if fixed_metrics_existed else ""
	var main_script = load("res://scripts/main.gd")
	for args in [[],["--verify-export"],["--verify-stall"],["--verify-export","--verify-stall"]]:
		if not expect(main_script._verify_stall_requested(PackedStringArray(args)) == (args.size() == 2),"Only both verifier flags route and skip mouse capture"): return
	for edge in [[-1,-1],[0,0],[3999999,0],[4000000,1],[7999999,1],[8000000,2],[12000000,3],[16000000,4],[20000000,5],[23999999,5],[24000000,-1]]:
		if not expect(trace_script.phase_at(edge[0]) == edge[1],"Fixed six-phase boundaries: "+str(edge)): return
	var home = "/isolated/validation-home"
	var args = PackedStringArray(["--verify-export","--verify-stall"])
	if not expect(trace_script.early_failure(args,home,home+"/userdata","user://export_validation.json",false).is_empty(),"Isolated fresh guard admits only fixed profile"): return
	for invalid in [[PackedStringArray(["--verify-stall"]),home,home+"/userdata","user://export_validation.json",false,"flags_required"],[args,"/ordinary/home","/ordinary/home/userdata","user://export_validation.json",false,"isolated_home_required"],[args,home,home+"-other/userdata","user://export_validation.json",false,"isolated_home_required"],[args,home,home+"/userdata","user://campaign.json",false,"wrong_progress_path"],[args,home,home+"/userdata","user://export_validation.json",true,"metrics_already_exist"]]:
		if not expect(trace_script.early_failure(invalid[0],invalid[1],invalid[2],invalid[3],invalid[4]) == invalid[5],"Early guard refuses before any world allocation: "+invalid[5]): return
	var summary: Dictionary = trace_script.summarize([1200000,1208333,1225000,1275000,1375000,2375001])
	if not expect(summary.first_draw_us == 1200000 and summary.steady.count == 5 and summary.steady.p50_us == 50000 and summary.steady.p95_us == 1000001 and summary.steady.p99_us == 1000001 and summary.steady.worst_us == 1000001,"First draw is separate; nearest-rank quantiles use consecutive timestamps"): return
	if not expect(summary.steady.hitches_gt_50ms == 2 and summary.steady.hitches_gt_100ms == 1 and summary.steady.hitches_gt_1000ms == 1 and summary.including_first.hitches_gt_1000ms == 2,"Strict hitch thresholds retain first gap, including exact threshold edges"): return
	if not expect(trace_script.summarize([]).steady.count == 0 and trace_script.summarize([9]).first_draw_us == 9 and not trace_script.target_passed(trace_script.summarize([9]),true),"Empty or single-draw capture cannot pass performance"): return
	var fast: Dictionary = trace_script.summarize([8000,16000,24000,32000])
	if not expect(trace_script.target_passed(fast,true) and not trace_script.target_passed(fast,false) and not trace_script.target_passed(trace_script.summarize([200000,208000,216000]),true),"Collection validity and first-gap hitch guard remain independent from fast steady rate"): return
	var repairs_ok: bool = true
	var terminal_times: Array = []
	for usec in range(8000,23896001,8000): terminal_times.append(usec)
	var terminal_summary: Dictionary = trace_script.summarize(terminal_times,30000000)
	repairs_ok = expect(terminal_summary.terminal_no_draw_lower_bound_us == 6104000 and terminal_summary.steady_fps == 125 and terminal_summary.steady.count == terminal_times.size()-1 and terminal_summary.steady.hitches_gt_100ms == 0,"Terminal lower bound is separate from actual-draw FPS, quantiles and hitch counts") and repairs_ok
	repairs_ok = expect(not trace_script.target_passed(terminal_summary,true),"INTENDED RED: a fast real-draw prefix cannot hide a terminal no-draw lower bound") and repairs_ok
	repairs_ok = expect(not trace_script.collection_complete(23896000,30000000),"INTENDED RED: completion after a stall requires an actual deadline-crossing draw") and repairs_ok
	repairs_ok = expect(trace_script.collection_complete(24008000,24009000),"An actual normal closing draw completes collection") and repairs_ok
	repairs_ok = expect(not trace_script.collection_complete(0,30000000) and not trace_script.collection_complete(8000,9000) and not trace_script.collection_complete(24008000,24000000) and not trace_script.collection_complete(26000001,30000000),"Empty/early/backwards/late closing observations cannot complete collection") and repairs_ok
	var crossed_times: Array = terminal_times.duplicate()
	for usec in range(23904000,24008001,8000): crossed_times.append(usec)
	var crossed_summary: Dictionary = trace_script.summarize(crossed_times,30000000)
	repairs_ok = expect(crossed_summary.terminal_no_draw_lower_bound_us == 5992000 and trace_script.collection_complete(crossed_times.back(),30000000),"Closing draw remains real collection evidence while its later unmeasured tail is explicit") and repairs_ok
	repairs_ok = expect(not trace_script.target_passed(crossed_summary,true),"INTENDED RED: a real closing draw does not hide a later process-continuation stall") and repairs_ok
	repairs_ok = expect(trace_script.target_passed(trace_script.summarize(crossed_times,24009000),true) and trace_script.target_passed(trace_script.summarize(crossed_times,24108000),true) and not trace_script.target_passed(trace_script.summarize(crossed_times,24108001),true),"Normal closing draw passes; the terminal >100ms guard has an exact strict boundary") and repairs_ok
	var rounding_summary: Dictionary = trace_script.summarize([8000,16331,24331,32331,40331,48331,56331,64331,72331,80331,88331])
	repairs_ok = expect(rounding_summary.steady.p95_us == 8331 and rounding_summary.steady_fps >= 120 and not trace_script.target_passed(rounding_summary,true),"INTENDED RED: 8331us p95 exceeds the predeclared 8.33ms limit") and repairs_ok
	for action in trace_script.ACTIONS:
		if not InputMap.has_action(action): InputMap.add_action(action)
		Input.action_press(action)
	var trace = trace_script.new()
	for index in range(trace_script.MAX_RENDER_ROWS): trace.record_draw(index+1,index,index)
	trace.record_draw(trace_script.MAX_RENDER_ROWS+1,0,0)
	if not expect(trace.render_rows.size() == trace_script.MAX_RENDER_ROWS and trace.reason == "render_sample_cap","Render rows are capped and cap invalidates instead of truncating silently"): return
	for action in trace_script.ACTIONS:
		if not expect(not Input.is_action_pressed(action),"Failure releases every verifier-owned engine action"): return
	trace = trace_script.new()
	for index in range(trace_script.MAX_PHYSICS_ROWS): trace.record_physics(index+1,index)
	trace.record_physics(trace_script.MAX_PHYSICS_ROWS+1,0)
	if not expect(trace.physics_rows.size() == trace_script.MAX_PHYSICS_ROWS and trace.reason == "physics_sample_cap","Physics rows have a finite independent cap"): return
	trace = trace_script.new()
	trace.record_draw(2,1,1)
	trace.record_draw(2,2,2)
	if not expect(trace.reason == "nonmonotonic_render_timestamp" and trace.render_rows.size() == 1,"Repeated draw timestamp invalidates the prefix"): return
	trace = trace_script.new()
	trace.record_draw(23896000,1,1)
	for action in trace_script.ACTIONS: Input.action_press(action)
	trace.record_draw(26000001,2,2)
	if not expect(trace.reason == "terminal_draw_timeout" and trace.render_rows == [[23896000,5,1,1]],"A closing draw outside the two-second bound invalidates without inventing or extending the valid draw prefix"): return
	for action in trace_script.ACTIONS:
		if not expect(not Input.is_action_pressed(action),"Closing timeout releases all five owned actions"): return
	trace = trace_script.new()
	for action in trace_script.ACTIONS: Input.action_press(action)
	trace.record_physics(24000000,1)
	for action in trace_script.ACTIONS:
		if not expect(not Input.is_action_pressed(action),"First physics callback at the deadline releases actions before a closing draw"): return
	var fixture_path = "user://app_frame_trace_test_"+str(OS.get_process_id())+"_"+str(Time.get_ticks_usec())+".json"
	if not expect(not FileAccess.file_exists(fixture_path),"Fresh unique metrics fixture"): return
	var metrics = FileAccess.open(fixture_path,FileAccess.WRITE)
	metrics.store_string("preserve-existing-metrics")
	metrics.close()
	if not expect(trace_script.early_failure(args,home,home+"/userdata","user://export_validation.json",FileAccess.file_exists(fixture_path)) == "metrics_already_exist" and FileAccess.get_file_as_string(fixture_path) == "preserve-existing-metrics","Actual preexisting isolated metrics are refused without overwriting"): return
	var source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	var main_markers: Array = ['var validation_home = OS.get_environment("HOME")','if validation_home.get_file() != "validation-home" or not OS.get_user_data_dir().begins_with(validation_home+"/"):','push_error("Export validation requires isolated HOME/userdata")','get_tree().quit(1)','progress_path = "user://export_validation.json"','_verify_stall_requested(OS.get_cmdline_user_args())','load("res://scripts/app_frame_trace.gd").new()','await trace.run(self)','start_campaign(1)']
	if not expect(guard_order_valid(source,"func _verify_export()",main_markers),"Existing isolated HOME guard precedes lazy trace routing and gameplay"): return
	var helper: String = FileAccess.get_file_as_string("res://scripts/app_frame_trace.gd")
	var helper_markers: Array = ['reason = early_failure(','FileAccess.file_exists(METRICS_PATH)','if not reason.is_empty():','await cleanup(tree)','tree.quit(1)','game.start_campaign(1)']
	if not expect(guard_order_valid(helper,"func run(",helper_markers),"Runtime applies real output refusal before production startup"): return
	if not expect(guard_order_valid(helper,"func run(",['if elapsed_us >= DURATION_US:','if collection_complete(','invalidate("terminal_draw_timeout")','continue','var phase: int = phase_at(elapsed_us)']),"Deadline branch requires a real closing draw or bounded timeout, never phase -1 input"): return
	if not expect(guard_order_valid(helper,"func run(",['elapsed_us = Time.get_ticks_usec()-capture_start if capture_start > 0 else 0','capturing = false','RenderingServer.frame_post_draw.disconnect(on_draw)','summarize(times,elapsed_us)','var collection_passed: bool = reason.is_empty() and collection_complete(']),"Actual observation end is captured before disconnect and feeds tail scoring and collection"): return
	for contract in [[source,"func _verify_export()",main_markers],[helper,"func run(",helper_markers]]:
		for marker in [contract[1]]+contract[2]:
			repairs_ok = expect(not guard_order_valid(contract[0].replace(marker,""),contract[1],contract[2]),"INTENDED RED: missing function/guard/call/anchor must fail ordering: "+marker) and repairs_ok
	if not expect(FileAccess.file_exists(trace_script.METRICS_PATH) == fixed_metrics_existed and (not fixed_metrics_existed or FileAccess.get_sha256(trace_script.METRICS_PATH) == fixed_metrics_sha),"Fixed production metrics existence and SHA256 remain unchanged, including absent stays absent"): return
	print("PASS fixed metrics preservation existed=",fixed_metrics_existed," sha256=",fixed_metrics_sha)
	if not repairs_ok: return
	print("PASS app-frame trace phase/quantile/hitch/cap/early-guard/routing contracts; no Main or world instantiated, no GPU/timing claim")
	quit(0)

func guard_order_valid(source: String, function_marker: String, markers: Array) -> bool:
	var function_at: int = source.find(function_marker)
	if function_at < 0: return false
	var entry: String = source.substr(function_at)
	var previous: int = -1
	for marker in markers:
		var found: int = entry.find(marker)
		if found < 0 or found <= previous: return false
		previous = found
	return true

func expect(condition: bool, detail: String) -> bool:
	if not condition:
		push_error(detail)
		quit(1)
	return condition
