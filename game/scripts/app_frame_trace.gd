extends RefCounted

class PhysicalInputGuard extends Node:
	signal observed(event: InputEvent)
	func _input(event: InputEvent) -> void: observed.emit(event)

func on_physical_input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouse or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		invalidate("physical_input_detected")

static func has_active_input() -> bool:
	for action in InputMap.get_actions():
		if Input.get_action_raw_strength(action) > 0: return true
	return false

const DURATION_US = 24000000
const CLOSING_WAIT_US = 2000000
const MAX_RENDER_ROWS = 65536
const MAX_PHYSICS_ROWS = 16384
const MAX_REPORT_BYTES = 16*1024*1024
const METRICS_PATH = "user://export_stall_metrics.json"
const ACTIONS = ["move_forward","move_left","move_back","move_right","fire"]
const PHASE_ACTIONS = ["move_forward","move_left","move_back","move_right","move_forward","move_back"]

var render_rows: Array = []
var physics_rows: Array = []
var focus_events: Array = []
var reason: String = ""
var stop_elapsed_us: int = 0
var capture_start: int = 0
var capturing: bool = false
var focus_required: bool = false
var game: Node
var window: Window
var level_id: int = 0
var player_id: int = 0
var input_guard: PhysicalInputGuard

static func phase_at(usec: int) -> int:
	return int(usec/4000000.0) if usec >= 0 and usec < DURATION_US else -1

static func early_failure(args: PackedStringArray, home: String, userdata: String, progress: String, metrics_exist: bool) -> String:
	if not ("--verify-export" in args and "--verify-stall" in args): return "flags_required"
	if home.get_file() != "validation-home" or not userdata.begins_with(home+"/"): return "isolated_home_required"
	if progress != "user://export_validation.json": return "wrong_progress_path"
	if metrics_exist: return "metrics_already_exist"
	return ""

static func gap_stats(gaps: Array) -> Dictionary:
	var result = {"count":gaps.size(),"p50_us":0,"p95_us":0,"p99_us":0,"worst_us":0,"hitches_gt_50ms":0,"hitches_gt_100ms":0,"hitches_gt_1000ms":0}
	if gaps.is_empty(): return result
	var ordered: Array = gaps.duplicate()
	ordered.sort()
	result.p50_us = ordered[ceili(ordered.size()*0.50)-1]
	result.p95_us = ordered[ceili(ordered.size()*0.95)-1]
	result.p99_us = ordered[ceili(ordered.size()*0.99)-1]
	result.worst_us = ordered.back()
	for gap in gaps:
		if gap > 50000: result.hitches_gt_50ms += 1
		if gap > 100000: result.hitches_gt_100ms += 1
		if gap > 1000000: result.hitches_gt_1000ms += 1
	return result

static func summarize(times_us: Array, observation_end_us: int = -1) -> Dictionary:
	var gaps: Array = []
	for index in range(1,times_us.size()): gaps.append(times_us[index]-times_us[index-1])
	var all_gaps: Array = gaps.duplicate()
	if not times_us.is_empty(): all_gaps.push_front(times_us[0])
	return {"first_draw_us":times_us[0] if not times_us.is_empty() else null,"steady":gap_stats(gaps),"including_first":gap_stats(all_gaps),"steady_fps":gaps.size()*1000000.0/(times_us.back()-times_us.front()) if not gaps.is_empty() and times_us.back() > times_us.front() else 0.0,"terminal_no_draw_lower_bound_us":maxi(0,observation_end_us-(times_us.back() if not times_us.is_empty() else 0))}

static func target_passed(summary: Dictionary, collection_passed: bool) -> bool:
	return collection_passed and summary.steady.count > 0 and summary.steady_fps >= 120.0 and summary.steady.p95_us <= 8330 and summary.steady.p99_us <= 16667 and summary.steady.worst_us <= 50000 and summary.including_first.hitches_gt_100ms == 0 and summary.terminal_no_draw_lower_bound_us <= 100000

static func collection_complete(last_draw_us: int, observation_end_us: int) -> bool:
	return last_draw_us >= DURATION_US and last_draw_us <= DURATION_US+CLOSING_WAIT_US and observation_end_us >= last_draw_us

func invalidate(why: String) -> void:
	if not reason.is_empty(): return
	reason = why
	stop_elapsed_us = Time.get_ticks_usec()-capture_start if capture_start > 0 else 0
	release_actions()

func record_draw(elapsed: int, drawn: int, physics_tick: int) -> void:
	if not reason.is_empty(): return
	if elapsed >= DURATION_US: release_actions()
	if elapsed > DURATION_US+CLOSING_WAIT_US:
		invalidate("terminal_draw_timeout")
		return
	if render_rows.size() >= MAX_RENDER_ROWS:
		invalidate("render_sample_cap")
		return
	if elapsed < 0 or (not render_rows.is_empty() and elapsed <= render_rows.back()[0]):
		invalidate("nonmonotonic_render_timestamp")
		return
	render_rows.append([elapsed,phase_at(elapsed),drawn,physics_tick])

func record_physics(elapsed: int, tick: int) -> void:
	if not reason.is_empty(): return
	if elapsed >= DURATION_US: release_actions()
	if physics_rows.size() >= MAX_PHYSICS_ROWS:
		invalidate("physics_sample_cap")
		return
	if elapsed < 0 or (not physics_rows.is_empty() and elapsed < physics_rows.back()[0]):
		invalidate("nonmonotonic_physics_timestamp")
		return
	physics_rows.append([elapsed,tick])

func live_failure() -> String:
	if not window.has_focus(): return "focus_lost"
	if game.state.health <= 0: return "death"
	if game.placement_pending: return "placement_pending"
	if game.get_tree().paused: return "paused"
	if not game.playing: return "not_playing"
	if game.state.level_index != 0 or game._scene_level_index != 0: return "scene_changed"
	if not is_instance_valid(game.level) or game.level.is_queued_for_deletion() or game.level.get_instance_id() != level_id: return "level_changed"
	if not is_instance_valid(game.player) or game.player.is_queued_for_deletion() or game.player.get_instance_id() != player_id or game.player.get_parent() != game.level: return "player_changed"
	return ""

func on_draw() -> void:
	if not capturing: return
	var why: String = live_failure()
	if not why.is_empty():
		invalidate(why)
		return
	record_draw(Time.get_ticks_usec()-capture_start,Engine.get_frames_drawn(),Engine.get_physics_frames())

func on_physics() -> void:
	if not capturing: return
	var why: String = live_failure()
	if not why.is_empty():
		invalidate(why)
		return
	record_physics(Time.get_ticks_usec()-capture_start,Engine.get_physics_frames())

func on_focus_in() -> void:
	record_focus("in")

func on_focus_out() -> void:
	record_focus("out")
	if focus_required: invalidate("focus_lost")

func record_focus(event: String) -> void:
	if focus_events.size() >= 128:
		invalidate("focus_event_cap")
		return
	focus_events.append([Time.get_ticks_usec(),event])

func release_actions() -> void:
	for action in ACTIONS: Input.action_release(action)

func resources() -> Dictionary:
	var state = game.state
	var result = {"difficulty":state.difficulty,"level_index":state.level_index,"health":state.health,"armor":state.armor,"ammo":state.ammo.duplicate(),"owned_weapons":state.owned_weapons.duplicate(),"weapon":state.weapon,"actors":game.enemies.size(),"auto_aim":game.settings.auto_aim,"playing":game.playing,"paused":game.get_tree().paused,"placement_pending":game.placement_pending}
	if is_instance_valid(game.player):
		var p: Vector3 = game.player.position
		result.position = [p.x,p.y,p.z]
		result.yaw = game.player.rotation.y
	return result

func run(owner: Node) -> void:
	game = owner
	var tree: SceneTree = game.get_tree()
	window = tree.root
	reason = early_failure(OS.get_cmdline_user_args(),OS.get_environment("HOME"),OS.get_user_data_dir(),game.progress_path,FileAccess.file_exists(METRICS_PATH))
	if not reason.is_empty():
		push_error("App frame trace refused: "+reason)
		await cleanup(tree)
		tree.quit(1)
		return
	var report = {"diagnostic_only":true,"artifact_kind":"app-owned verifier; parent must bind actual binary/PCK hashes","input_method":"synthetic_engine_actions_and_scripted_look","physical_input":false,"physical_presentation_measured":false,"capture":false,"requested_duration_us":DURATION_US,"closing_wait_limit_us":CLOSING_WAIT_US,"observation_boundary":"consecutive RenderingServer.frame_post_draw timestamps, NOT physical presentation","physics_boundary":"SceneTree.physics_frame timestamps, NOT CPU durations or physical keyboard events","memory_limit":"Retained trace arrays and report serialization confound process memory; not a memory-performance proof","cpu_duration_proof":false,"target":{"fps":120,"p95_us":8330,"p99_us":16667,"worst_ordinary_us":50000,"hitches_gt_100ms":0,"scope":"steady render-loop cadence; >100ms guard includes first draw and terminal no-draw lower bound"}}
	for path in ["user://campaign.json","user://preferences.json",game.progress_path,game.progress_path+".tmp"]:
		if FileAccess.file_exists(path): invalidate("fresh_profile_required")
	if game.playing or game.placement_pending or game.level != null or game.player != null: invalidate("wrong_context")
	if DisplayServer.get_name() == "headless": invalidate("native_gpu_required")
	if RenderingServer.get_current_rendering_method() != "mobile" or RenderingServer.get_current_rendering_driver_name() != "metal": invalidate("mobile_metal_required")
	for arg in OS.get_cmdline_args():
		if arg == "--fixed-fps" or arg.begins_with("--fixed-fps=") or arg == "--write-movie" or arg.begins_with("--write-movie="): invalidate("realtime_capture_free_required")
	if Engine.time_scale != 1.0: invalidate("realtime_time_scale_required")
	if not ClassDB.class_has_method("Window","has_focus"): invalidate("focus_api_unavailable")
	window.focus_entered.connect(on_focus_in)
	window.focus_exited.connect(on_focus_out)
	var deadline: int = Time.get_ticks_usec()+2000000
	var focused_since: int = 0
	while reason.is_empty() and Time.get_ticks_usec() < deadline:
		var now: int = Time.get_ticks_usec()
		if window.has_focus():
			if focused_since == 0: focused_since = now
			if now-focused_since >= 200000: break
		else: focused_since = 0
		await tree.process_frame
	if reason.is_empty() and (focused_since == 0 or Time.get_ticks_usec()-focused_since < 200000): invalidate("focus_not_stable")
	if reason.is_empty():
		input_guard = PhysicalInputGuard.new()
		input_guard.process_mode = Node.PROCESS_MODE_ALWAYS
		input_guard.observed.connect(on_physical_input)
		game.add_child(input_guard)
		if has_active_input(): invalidate("physical_input_held")
	report.input_guard = "Physical keyboard/mouse/controller events and initially active mapped actions invalidate collection; event contents are not recorded."
	var initial: Dictionary = {}
	var phases: Array = []
	var counters: Array = []
	var fire_started_us: int = -1
	var construction_us: int = 0
	var elapsed_us: int = 0
	if reason.is_empty():
		focus_required = true
		var construction_start: int = Time.get_ticks_usec()
		game.start_campaign(1)
		construction_us = Time.get_ticks_usec()-construction_start
		var ready_deadline: int = Time.get_ticks_usec()+2000000
		for _tick in range(120):
			if not reason.is_empty() or (game.playing and not game.placement_pending): break
			if Time.get_ticks_usec() >= ready_deadline: break
			await tree.process_frame
		if not game.playing or game.placement_pending or not is_instance_valid(game.level) or not is_instance_valid(game.player): invalidate("startup_not_ready")
	if reason.is_empty():
		level_id = game.level.get_instance_id()
		player_id = game.player.get_instance_id()
		initial = resources()
		if initial.difficulty != 1 or initial.level_index != 0 or initial.actors != 23 or initial.health != 100 or initial.armor != 0 or initial.ammo != [0,90,0,0,0,0] or initial.owned_weapons != [0,1] or initial.weapon != 1 or initial.auto_aim or game.level.layout.data.id != "intake": invalidate("initial_contract_mismatch")
	if reason.is_empty():
		capture_start = Time.get_ticks_usec()
		capturing = true
		RenderingServer.frame_post_draw.connect(on_draw)
		tree.physics_frame.connect(on_physics)
		var previous: int = capture_start
		var previous_phase: int = -1
		var next_counter: int = 0
		while reason.is_empty():
			var now: int = Time.get_ticks_usec()
			elapsed_us = now-capture_start
			var why: String = live_failure()
			if not why.is_empty():
				invalidate(why)
				break
			if elapsed_us >= DURATION_US:
				release_actions()
				if collection_complete(render_rows.back()[0] if not render_rows.is_empty() else 0,elapsed_us): break
				if elapsed_us >= DURATION_US+CLOSING_WAIT_US:
					invalidate("terminal_draw_timeout")
					break
				await tree.process_frame
				continue
			var phase: int = phase_at(elapsed_us)
			if phase != previous_phase:
				for action in ACTIONS.slice(0,4): Input.action_release(action)
				Input.action_press(PHASE_ACTIONS[phase])
				phases.append([elapsed_us,phase,PHASE_ACTIONS[phase]])
				previous_phase = phase
			if phase == 1 or phase == 3: game.player.look(Vector2(TAU/8.0*minf((now-previous)/1000000.0,0.1),0))
			if fire_started_us < 0 and elapsed_us >= 1000000:
				Input.action_press("fire")
				fire_started_us = elapsed_us
			if elapsed_us >= next_counter:
				counters.append([elapsed_us,Performance.get_monitor(Performance.TIME_PROCESS),Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS),Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),Performance.get_monitor(Performance.OBJECT_COUNT),Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS),Performance.get_monitor(Performance.MEMORY_STATIC)])
				next_counter = elapsed_us+500000
			previous = now
			await tree.process_frame
	elapsed_us = Time.get_ticks_usec()-capture_start if capture_start > 0 else 0
	capturing = false
	focus_required = false
	if RenderingServer.frame_post_draw.is_connected(on_draw): RenderingServer.frame_post_draw.disconnect(on_draw)
	if tree.physics_frame.is_connected(on_physics): tree.physics_frame.disconnect(on_physics)
	window.focus_entered.disconnect(on_focus_in)
	window.focus_exited.disconnect(on_focus_out)
	if reason.is_empty() and (render_rows.size() < 2 or physics_rows.size() < 2 or phases.size() != 6 or fire_started_us < 0): invalidate("insufficient_observations")
	var times: Array = []
	for row in render_rows: times.append(row[0])
	var summary: Dictionary = summarize(times,elapsed_us)
	var collection_passed: bool = reason.is_empty() and collection_complete(render_rows.back()[0] if not render_rows.is_empty() else 0,elapsed_us)
	report.merge({"collection_passed":collection_passed,"collection_status":"PASS" if collection_passed else "INCOMPLETE","target_passed":target_passed(summary,collection_passed),"performance_status":"PASS" if target_passed(summary,collection_passed) else ("FAIL" if collection_passed else "UNSCORED"),"reason":reason,"stop_elapsed_us":stop_elapsed_us,"elapsed_us":elapsed_us,"valid_prefix_us":render_rows.back()[0] if not render_rows.is_empty() else 0,"construction_us":construction_us,"initial":initial,"final":resources(),"phases":phases,"fire_started_us":fire_started_us,"focus_events":focus_events,"backend":RenderingServer.get_current_rendering_driver_name(),"method":RenderingServer.get_current_rendering_method(),"window":[window.size.x,window.size.y],"target_size":[window.get_texture().get_size().x,window.get_texture().get_size().y],"logical_size":[window.content_scale_size.x,window.content_scale_size.y],"refresh_hz":DisplayServer.screen_get_refresh_rate(window.current_screen),"max_fps":Engine.max_fps,"vsync":DisplayServer.window_get_vsync_mode(window.get_window_id()),"time_scale":Engine.time_scale,"physics_ticks_per_second":Engine.physics_ticks_per_second,"render_columns":["elapsed_us","phase","frames_drawn","physics_tick"],"render_rows":render_rows,"physics_columns":["elapsed_us","physics_tick"],"physics_rows":physics_rows,"counter_columns":["elapsed_us","engine_time_process_s","engine_time_physics_s","draw_calls","objects","resources","collision_pairs","static_bytes"],"counters":counters,"render_summary":summary})
	await cleanup(tree)
	var payload: String = JSON.stringify(report)
	if payload.to_utf8_buffer().size() > MAX_REPORT_BYTES or FileAccess.file_exists(METRICS_PATH):
		push_error("App frame trace report refused: "+("report_size_cap" if payload.to_utf8_buffer().size() > MAX_REPORT_BYTES else "metrics_appeared_during_run"))
		tree.quit(1)
		return
	var file = FileAccess.open(METRICS_PATH,FileAccess.WRITE)
	if file == null:
		push_error("App frame trace report open failed: "+error_string(FileAccess.get_open_error()))
		tree.quit(1)
		return
	file.store_string(payload)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		push_error("App frame trace report write failed: "+error_string(write_error))
		tree.quit(1)
		return
	print("APP_FRAME_TRACE collection=",report.collection_status," performance=",report.performance_status," reason=",reason," render_rows=",render_rows.size()," physics_rows=",physics_rows.size(),"; synthetic input/render-loop evidence only")
	tree.quit(0 if collection_passed else 1)

func cleanup(tree: SceneTree) -> void:
	release_actions()
	if is_instance_valid(input_guard):
		input_guard.set_process_input(false)
		input_guard.observed.disconnect(on_physical_input)
		input_guard.queue_free()
		input_guard = null
	game.show_title()
	tree.paused = false
	var drain_until: int = Time.get_ticks_usec()+100000
	while Time.get_ticks_usec() < drain_until: await tree.process_frame
	await tree.process_frame
	await tree.process_frame
