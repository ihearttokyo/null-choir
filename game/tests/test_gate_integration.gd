extends SceneTree
## One source-bound real Main/Level selected-chapter path (default Intake). Requires the normally imported production GLB;
## this is lifecycle/integration evidence only, not independent art acceptance or an eight-gate release.
const MainSource = preload("res://scripts/main.gd")
const LevelSource = preload("res://scripts/level.gd")
const Campaign = preload("res://scripts/campaign.gd")
const LayoutSource = preload("res://scripts/level_data.gd")
const GateArt = preload("res://scripts/gate_art.gd")
var failures := 0
var report := {"scope":"actual Main + actual selected Level + actual imported production GLBs; no disk save/Continue, campaign-wide, intended-use, FPS, listening or release claim","checks":[]}

func check(ok: bool, message: String) -> void:
	report.checks.append({"passed":ok,"message":message})
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func _level(main: Node, index: int = 0) -> Node:
	var level = LevelSource.new()
	root.add_child(level)
	main.level = level
	if not level.build(main,index):
		check(false,"Actual current Level builds")
		main.level = null
		level.free()
		return null
	var routes = level.get_node_or_null("NavigationRoutes")
	if routes != null:
		routes.set_process(false)
		routes.set_physics_process(false)
	return level

func _retire_level(level: Node) -> void:
	if is_instance_valid(level):
		level.queue_free()
		await process_frame

func _gate_rig(level: Node, id: String):
	var presentation: Dictionary = level.gate_presentations.get(id,{})
	return presentation.get("rig")

func _door_ray(level: Node, body: StaticBody3D) -> Dictionary:
	var center: Vector3 = body.global_position
	var direction: Vector3 = body.global_basis.z*2.0
	return level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(center+direction,center-direction,1))

func _key_state(level: Node, id: String, blood: bool, ivory: bool, blood_origin: Vector3, ivory_origin: Vector3) -> void:
	var rig = _gate_rig(level,id)
	if rig == null:
		check(false,"Registered selected production art attaches to actual Level")
		return
	var blood_latch: Node3D = rig.blood_latch
	var ivory_latch: Node3D = rig.ivory_latch
	var released: Node3D = rig.released_closure
	level.game.state.keys = (["blood"] if blood else []) + (["ivory"] if ivory else [])
	level.refresh_gate_presentations()
	check(blood_latch.position.is_equal_approx(blood_origin+Vector3(-1.35 if blood else 0,0,0)),"Blood latch follows the existing absolute key pose")
	check(ivory_latch.position.is_equal_approx(ivory_origin+Vector3(1.35 if ivory else 0,0,0)),"Ivory latch follows the existing absolute key pose")
	check(level.gate_presentations[id].cover.visible and not released.visible,"Every seal combination remains visibly closed")

func run() -> void:
	var selection=OS.get_environment("GATE_TEST_MAP_INDEX")
	if selection not in ["","0","1","2","3","4","5","6","7"]:push_error("Explicit gate fixture map must be0..7");quit(1);return
	var map_index=int(selection) if not selection.is_empty() else 0
	var layout=LayoutSource.new()
	check(layout.load_level(map_index),"Actual selected Layout loads")
	if failures>0:quit(1);return
	var selected_spec:Dictionary=layout.data.doors[0]
	var door_id:String=selected_spec.id
	var chapter:String=layout.data.id
	report["map_index"]=map_index;report["map_id"]=chapter
	report["door_id"]=door_id;report["door_origin"]=str(layout.world_position(selected_spec.cell))
	report["door_yaw_degrees"]=selected_spec.yaw;report["door_width"]=selected_spec.size[0]
	# Both frozen production pair resources remain strict preconditions, plus the selected chapter.
	var required_indices=[0,1]
	if not map_index in required_indices:required_indices.append(map_index)
	for required_index in required_indices:
		var required=LayoutSource.new()
		check(required.load_level(required_index),"Actual required Layout loads")
		if required.data.is_empty():continue
		var imported:Dictionary=GateArt.create(required.data.doors[0])
		check(imported.get("rig") is Node3D and imported.get("cover") is Node3D,"Normal importer creates required production presentation: "+str(required.data.id))
		if imported.get("rig") is Node:imported.rig.free()
	if failures > 0:
		print("GATE_INTEGRATION_PRECONDITION_FAILED missing-or-invalid required production asset")
		quit(1)
		return

	var main = MainSource.new()
	main.state.new_campaign(1)
	for step in range(map_index):main.state.complete_level()
	var level = _level(main,map_index)
	if level == null: main.free();quit(1);return
	check(main.state.level_index==map_index and level.layout.data.id==chapter,"Actual selected map/state identity, not a default Intake proxy")
	# Actual fresh-level entry boundary, not an Intake checkpoint pasted onto map1.
	main.state.mark_checkpoint("entry",level.layout.world_position(level.layout.data.spawn))
	if not level.doors.has(door_id):
		check(false,"Existing selected collision body remains registered while closed")
		await _retire_level(level)
		main.free();quit(1);return
	var id = door_id
	var body: StaticBody3D = level.doors[id]
	var rig = _gate_rig(level,id)
	await physics_frame
	await physics_frame
	check(rig is Node3D and body.collision_layer==1 and not body.visible,"Production art is sibling; original closed collider remains and fallback mesh is hidden")
	check(_door_ray(level,body).get("collider")==body,"Actual closed selected body blocks a real WORLD ray")
	if not rig is Node3D:
		await _retire_level(level);main.free();quit(1);return
	var blood_origin: Vector3 = rig.blood_latch.position
	var ivory_origin: Vector3 = rig.ivory_latch.position
	_key_state(level,id,false,false,blood_origin,ivory_origin)
	_key_state(level,id,true,false,blood_origin,ivory_origin)
	_key_state(level,id,false,true,blood_origin,ivory_origin)
	_key_state(level,id,true,true,blood_origin,ivory_origin)

	# Exercise actual Main key acquisition and eligibility, without changing authored requirements.
	main.state.keys=[]
	var blood_id="";var ivory_id=""
	for interaction in level.layout.data.interactions:
		if interaction.kind!="key":continue
		if interaction.key=="blood":blood_id=interaction.id
		if interaction.key=="ivory":ivory_id=interaction.id
	check(not blood_id.is_empty() and not ivory_id.is_empty(),"Actual selected layout has both authored key interactions")
	check(not main.unlock_door(id) and body.collision_layer==1,"Actual Main denies door before both keys without clearing collision")
	if not blood_id.is_empty():main.collect_key(blood_id)
	if not ivory_id.is_empty():main.collect_key(ivory_id)
	check(main.state.keys.has("blood") and main.state.keys.has("ivory"),"Actual Main key path records both existing seals")
	var lift_start_y:float=body.position.y
	var lift_observation={"final_y":NAN}
	var body_ref=weakref(body)
	body.tree_exiting.connect(func():
		var live=body_ref.get_ref()
		if live!=null:lift_observation.final_y=live.position.y)
	var nav=level.get_node_or_null("NavigationRoutes")
	var nav_revision:int=nav.revision if nav!=null else -1
	check(main.unlock_door(id),"Actual Main unlocks only after both existing keys")
	check(body.collision_layer==0 and not level.gate_presentations[id].cover.visible,"Actual Level clears original collider and complete authored aperture cover synchronously")
	check(rig.released_closure.visible,"Actual Level reveals the authored exterior released closure after native clearance")
	check(not level.doors.has(id),"Successful native opening removes the door registry entry exactly once")
	await physics_frame
	check(_door_ray(level,body).is_empty(),"Actual opened selected body no longer blocks the WORLD ray")
	var position_after_first_open: Vector3 = body.position
	check(main.unlock_door(id),"Duplicate eligible unlock preserves the existing benign Main return value")
	check(body.position.is_equal_approx(position_after_first_open) and body.collision_layer==0 and not level.gate_presentations[id].cover.visible and rig.released_closure.visible,"Duplicate unlock preserves API return but cannot restart tween or restore cover")

	if nav!=null:
		check(nav._dirty and nav.revision>=nav_revision and nav.revision<=nav_revision+1,"Actual navigation owner remains invalidated/coalesced after original door transaction")
		report["navigation_scope"]={"initial_revision":nav_revision,"after_revision":nav.revision,"dirty":nav._dirty,"baked_path_acceptance":false}
	await create_timer(.20).timeout
	check(is_instance_valid(body) and body.position.y>lift_start_y and body.position.y<lift_start_y+6.0,"Original native tween is genuinely in-flight before .65seconds")
	await create_timer(.55).timeout
	check(not is_instance_valid(body) and absf(float(lift_observation.final_y)-(lift_start_y+6.0))<.0001,"Original .65second/six-unit native lift completes and frees sole original body")
	report["native_lift"]={"start_y":lift_start_y,"observed_final_y":lift_observation.final_y,"source_seconds":.65}

	# Earlier checkpoint restores its saved removed/key state through the real Campaign boundary.
	var opened_snapshot: Dictionary = main.state.to_dict()
	var serialized = Campaign.new()
	check(serialized.from_dict(opened_snapshot),"Campaign serializer accepts the opened gate state without a new schema")
	main.state.restore_checkpoint()
	check(not id in main.state.removed and main.state.keys.is_empty(),"Existing earlier checkpoint restores its original closed-gate resources")
	await _retire_level(level)
	level = _level(main,map_index)
	if level == null: main.free();quit(1);return
	check(level.doors.has(id) and level.doors[id].collision_layer==1,"Checkpoint-rebuilt actual Level restores the original closed blocker")
	rig = _gate_rig(level,id)
	check(rig is Node3D and level.gate_presentations[id].cover.visible and not rig.released_closure.visible,"Checkpoint-rebuilt production gate hydrates closed, not stale-open")

	# The serialized opened image reconstructs final art with no body or registry entry.
	main.state = serialized
	await _retire_level(level)
	level = _level(main,map_index)
	if level == null: main.free();quit(1);return
	check(id in main.state.removed and not level.doors.has(id),"Loaded removed-ID creates no collision body or door registry entry")
	rig = _gate_rig(level,id)
	check(rig is Node3D and not level.gate_presentations[id].cover.visible and rig.released_closure.visible,"Loaded removed-ID reconstructs its final released art directly")
	check(main.unlock_door(id),"Loaded removed eligible ID preserves Main's historical benign true return")
	check(not level.doors.has(id) and not level.gate_presentations[id].cover.visible and rig.released_closure.visible,"Loaded duplicate cannot recreate the original body, registry, or opaque cover")

	# Unknown IDs cannot borrow a neighbor's production geometry; closed legacy fallback remains intact.
	var unsupported: Dictionary = level.layout.data.doors[0].duplicate(true)
	unsupported.id="unregistered_threshold_negative"
	level._build_gate(unsupported)
	check(level.doors.has(unsupported.id) and level.doors[unsupported.id].visible and level.doors[unsupported.id].collision_layer==1,"Unregistered/absent art preserves visible original-style closed fallback")
	var bad_body: Node = level.doors.get(unsupported.id)
	level.doors.erase(unsupported.id)
	bad_body.queue_free()

	report.failures=failures
	print("GATE_INTEGRATION_RESULT ",JSON.stringify(report))
	await _retire_level(level)
	main.free()
	quit(0 if failures==0 else 1)
