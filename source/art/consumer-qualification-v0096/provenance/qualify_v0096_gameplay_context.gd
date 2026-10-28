extends SceneTree
## SOURCE-arranged moving/pixel/transaction evidence; NOT hardware, earned campaign or performance.
const MainSource = preload("res://scripts/main.gd")
const Seals = preload("res://scripts/seal_guardians.gd")
const Supply = preload("res://scripts/earned_supplies.gd")
const BuildInfo = preload("res://scripts/build_info.gd")
const WallClock = preload("res://tests/wall_clock_wait.gd")
class CaptureHost extends "res://scripts/main.gd":
 func _capture_game_mouse() -> void: pass # Established test-only OS cursor boundary; no gameplay override.
var host
var view: SubViewport
var output: String
var chapter: int = 0
var mode: String
var case_id: String
var case_contract: Dictionary = {}
var trace_sequence: int = 0
var active_role_arrangement: Dictionary = {}
var weapon: int = -1
var png_bytes: int = 0
var failed: bool = false
var report = {"status":"CAPTURED_PENDING_INDEPENDENT_REVIEW","resolution":[640,360],"arranged":true,"earned_combat":false,"hardware_input":false,"performance_claim":false,"frames":[],"events":[],"motion":[],"arrangements":[]}
class PhysicsAction extends Node:
 var callback: Callable
 var done: bool = false
 var result: Variant
 func _physics_process(_delta: float) -> void:
  set_physics_process(false)
  result=callback.call()
  done=true
func fail(message: String) -> bool:
 failed=true
 push_error("Context96: "+message)
 return false
func _initialize() -> void: call_deferred("run")
func sha(bytes: PackedByteArray) -> String:
 var h=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(bytes);return h.finish().hex_encode()
func state_binding() -> Dictionary:
 if not is_instance_valid(host) or not is_instance_valid(host.level):return {}
 var stations: Array=[]
 var actors: Array=[]
 for actor in host.enemies:
  if is_instance_valid(actor):actors.append({"id":actor.id,"world_position":v3(host.level.to_global(actor.position)),"yaw_degrees":actor.rotation_degrees.y,"hp":actor.hp,"sprite_frame":actor.sprite.frame if is_instance_valid(actor.sprite) else -1})
 actors.sort_custom(func(a,b):return a.id<b.id)
 for station_id in host.level.healing_stations:
  var row: Dictionary=host.level.healing_stations[station_id]
  var machine=host.level.healing_machinery
  var root: Node3D=row.get("root") as Node3D
  var target: MeshInstance3D=machine.use_target(station_id)
  var anchor: Vector3=machine.station_world_point(station_id)
  var root_world: Vector3=host.level.to_global(root.position) if is_instance_valid(root) else Vector3.INF
  var dial_center: Vector3=station_control_center(target) if is_instance_valid(target) else Vector3.INF
  var triangle_faces: int=0
  var fixed_shape: Shape3D=row.get("colliders",{}).get("fixed_structure",{}).get("shape")
  if fixed_shape is ConcavePolygonShape3D:triangle_faces=(fixed_shape as ConcavePolygonShape3D).get_faces().size()/3
  stations.append({"id":station_id,"chapter":row.get("chapter",""),"family":row.get("family",""),"remaining":row.get("remaining",-1),"capacity":row.get("capacity",-1),"root_instance":root.get_instance_id() if is_instance_valid(root) else -1,
   "control_instance":target.get_instance_id() if is_instance_valid(target) else -1,"root_local":v3(root.position) if is_instance_valid(root) else v3(Vector3.INF),"root_world":v3(root_world),"yaw_degrees":rad_to_deg(root.rotation.y) if is_instance_valid(root) else 0.0,
   "front_anchor_world":v3(anchor),"dial_face_center_world":v3(dial_center),
   "dial_face_local_position":v3(target.position) if is_instance_valid(target) else v3(Vector3.INF),
   "dial_face_local_scale":v3(target.scale) if is_instance_valid(target) else v3(Vector3.INF),
   "dial_face_local_rotation":v3(target.rotation) if is_instance_valid(target) else v3(Vector3.INF),
   "mesh_names":row.get("nodes",{}).keys(),"fixed_triangle_faces":triangle_faces})
 stations.sort_custom(func(a,b):return a.id<b.id)
 var player_support_y: float=host.level.layout.capsule_floor_support(Vector2(host.player.position.x,host.player.position.z),.32)
 var open_doors: Dictionary={}
 for door_id in host.level.doors:
  var body: StaticBody3D=host.level.doors[door_id] as StaticBody3D
  open_doors[door_id]={"instance_id":body.get_instance_id() if is_instance_valid(body) else -1,
   "collision_layer":body.collision_layer if is_instance_valid(body) else 0,"visible":body.visible if is_instance_valid(body) else false}
 return {"scene_id":host.level.layout.data.id,"level_index":host.state.level_index,
  "player_position":v3(host.player.position),"player_velocity":v3(host.player.velocity),
  "player_support":{"is_on_floor":host.player.is_on_floor(),"floor_y":player_support_y,"root_minus_floor":host.player.position.y-player_support_y},
  "health":host.state.health,"ammo":host.state.ammo.duplicate(),"shot_sequence":host.state.shot_sequence.duplicate(),
  "keys":host.state.keys.duplicate(),"removed":host.state.removed.duplicate(),"doors":open_doors,
  "earned_supply":host.state.earned_supply.duplicate(true),
  "healing_remaining":host.state.earned_supply.healing_remaining.duplicate(true),"machines":stations,"actors":actors}
func state_binding_encoded(value: Dictionary) -> String:
 return JSON.stringify(value,"",true,true)
func state_binding_sha(value: Dictionary) -> String:
 return sha(state_binding_encoded(value).to_utf8_buffer())
func trace_event(event: Dictionary) -> void:
 var state: Dictionary=state_binding();trace_sequence+=1
 event["case_id"]=case_id;event["trace_seq"]=trace_sequence;event["physics_tick"]=Engine.get_physics_frames()
 event["scene_id"]=state.get("scene_id","");event["state_json"]=state_binding_encoded(state);event["state_sha256"]=sha(event["state_json"].to_utf8_buffer());event["state"]=state
 event["source_manifest_sha256"]=case_contract.get("source_manifest_sha256","")
 event["fixture_sha256"]=case_contract.get("fixture_sha256","")
 event["producer_sha256"]=case_contract.get("producer_sha256","")
 event["capture_controller_sha256"]=case_contract.get("capture_controller_sha256","")
 event["case_schema_sha256"]=case_contract.get("case_schema_sha256","")
 report.events.append(event)
func trace_motion(row: Dictionary) -> void:
 var state: Dictionary=state_binding();trace_sequence+=1
 row["case_id"]=case_id;row["trace_seq"]=trace_sequence;row["scene_id"]=state.get("scene_id","")
 row["state"]=state;row["state_json"]=state_binding_encoded(state);row["state_sha256"]=sha(row["state_json"].to_utf8_buffer());row["source_manifest_sha256"]=case_contract.get("source_manifest_sha256","")
 row["fixture_sha256"]=case_contract.get("fixture_sha256","");row["producer_sha256"]=case_contract.get("producer_sha256","")
 row["capture_controller_sha256"]=case_contract.get("capture_controller_sha256","");row["case_schema_sha256"]=case_contract.get("case_schema_sha256","")
 report.motion.append(row)
func load_case_contract() -> bool:
 var contract_path: String=OS.get_environment("NC_CASE_CONTRACT")
 if contract_path.is_empty() or not FileAccess.file_exists(contract_path):return fail("Typed per-job case/provenance contract required")
 var parsed=JSON.parse_string(FileAccess.get_file_as_string(contract_path))
 if not parsed is Dictionary:return fail("Typed case contract JSON required")
 case_contract=parsed
 if case_contract.get("schema")!="null-choir-v096-capture-case-v2" or case_contract.get("case_id")!=case_id:return fail("Wrong case ID/schema contract")
 if case_contract.get("build_version")!=BuildInfo.DISPLAY_NAME:return fail("Current build identity differs from per-job source contract")
 if case_contract.get("mode")!=mode or int(case_contract.get("chapter",-1))!=chapter or int(case_contract.get("weapon",-2))!=weapon:return fail("Case args do not match explicit case contract")
 var expected_scene: int=int(case_contract.get("scene_chapter",-1))
 if expected_scene<0 or expected_scene>7:return fail("Per-job contract selects invalid production scene")
 var own_script: PackedByteArray=FileAccess.get_file_as_bytes("res://tests/qualify_v0096_gameplay_context.gd")
 if own_script.is_empty() or sha(own_script)!=case_contract.get("fixture_sha256"):return fail("Fixture source bytes differ from declared provenance")
 for field in ["source_manifest_sha256","fixture_sha256","producer_sha256","capture_controller_sha256","case_schema_sha256","original22_contract_sha256"]:
  if not str(case_contract.get(field,"" )).is_valid_hex_number() or str(case_contract[field]).length()!=64:return fail("Missing typed provenance pin: "+field)
 report["capture_contract"]={"schema":case_contract.schema,"build_version":case_contract.build_version,"case_id":case_id,"mode":mode,"chapter":chapter,"weapon":weapon,
  "fixture_sha256":case_contract.fixture_sha256,"producer_sha256":case_contract.producer_sha256,"capture_controller_sha256":case_contract.capture_controller_sha256,
  "scene_chapter":case_contract.scene_chapter,"scene_id":case_contract.scene_id,"frame_labels":case_contract.frame_labels,
  "preferred_ranges_m":case_contract.get("preferred_ranges_m",[]),"role_arrangement":case_contract.get("role_arrangement",{}),
  "case_schema_sha256":case_contract.case_schema_sha256,"source_manifest_sha256":case_contract.source_manifest_sha256,
  "original22_contract_sha256":case_contract.get("original22_contract_sha256","")}
 return true
func v3(point: Vector3) -> Array: return [point.x,point.y,point.z]
func v2i(point: Vector2i) -> Array: return [point.x,point.y]
func physics_call(callback: Callable) -> Variant:
 var action=PhysicsAction.new();action.callback=callback;root.add_child(action)
 while not action.done: await physics_frame
 var result=action.result;action.free();return result
func release_actions() -> void:
 for action in ["move_left","move_right","move_forward","move_back","run","fire","interact","use_asset"]:
  if InputMap.has_action(action):Input.action_release(action)
 if is_instance_valid(host) and is_instance_valid(host.player):host.player.cancel_actions()
func disable(node: Node) -> void:
 node.set_process(false);node.set_physics_process(false);node.set_process_input(false);node.set_process_unhandled_input(false)
 for child in node.get_children():disable(child)
func actor_pose(actor, delta: float = 0.0, pause_ai: bool = true) -> void:
 # Execute the production selector; callers may freeze movement while preserving
 # actual AI state, but never force sprite.frame/telegraph fields.
 var active: bool = actor.active
 if pause_ai:actor.active=false
 actor._physics_process(delta)
 if pause_ai:actor.active=active
 var tell = actor.get_node_or_null("CommittedShotTell")
 if tell != null: tell._physics_process(0.0)
func safe_foot(foot: Vector3) -> bool:
 var cell=Vector2i(floori(foot.x/4.0),floori(foot.z/4.0))
 if not host.level.layout.is_walkable(cell):return false
 var support=host.level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(foot+Vector3.UP*.2,foot-Vector3.UP*.25,1))
 if support.is_empty() or not support.collider in host.level.floor_bodies:return false
 var shape := CapsuleShape3D.new(); shape.radius = 0.32; shape.height = 1.65
 var query := PhysicsShapeQueryParameters3D.new(); query.shape = shape
 query.transform.origin = foot+Vector3.UP*0.85; query.collision_mask = 1|4
 query.exclude = [host.player.get_rid()]
 return host.level.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func foot_at(point: Vector2) -> Vector3:
 return Vector3(point.x,host.level.layout.capsule_floor_support(point,0.32)+0.04,point.y)
func aim_world(target: Vector3) -> void:
 # Production orientation convention: yaw belongs to Player, pitch to camera;
 # no local camera yaw/roll, camera position/FOV are never rewritten.
 for pass_index in range(2):
  var d: Vector3=target-host.player.camera.global_position
  host.player.rotation=Vector3(0,atan2(-d.x,-d.z),0)
  host.player.camera.rotation=Vector3(clampf(atan2(d.y,Vector2(d.x,d.z).length()),-1.35,1.35),0,0)
func aim_off_center(target: Vector3) -> void:
 aim_world(target)
 var distance: float=host.player.camera.global_position.distance_to(target)
 var right: Vector3=host.player.camera.global_basis.x
 aim_world(target+right*distance*.65-Vector3.UP*distance*.10)
func clear_subject_outline(actor, eye: Vector3, decoration: Array) -> bool:
 # TEST-only visibility for the known Foundry Blood composition defect.
 # World-model ornament often has no physics collider. Reject conservatively
 # against its actual local mesh bounds; never hide or move that geometry.
 var center: Vector3 = actor.sprite.global_position
 var right: Vector3 = (center-eye).cross(Vector3.UP).normalized()
 var width: float = actor.sprite.texture.get_width()/float(actor.sprite.hframes)*actor.sprite.pixel_size
 var height: float = actor.sprite.texture.get_height()/float(actor.sprite.vframes)*actor.sprite.pixel_size
 var samples: Array[Vector3] = []
 for x: float in [-0.4,0.0,0.4]:
  for y: float in [-0.4,0.0,0.4]: samples.append(center+right*width*x+Vector3.UP*height*y)
 if is_instance_valid(actor.champion_identity):
  for x: float in [-1.5,0.0,1.5]: samples.append(actor.champion_identity.global_position+right*x+Vector3.UP*0.25)
 for point: Vector3 in samples:
  if not host.level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,point,1)).is_empty(): return false
  for bound: Dictionary in decoration:
   var local_eye: Vector3 = bound.inverse*eye
   var local_point: Vector3 = bound.inverse*point
   if bound.box.intersects_segment(local_eye,local_point) != null: return false
 return true
func world_decoration_bounds(with_faces: bool=false) -> Array:
 var result: Array = []
 for model: Node in host.level.get_children():
  if not model.scene_file_path.begins_with("res://assets/art/world/"): continue
  var meshes: Array = model.find_children("*","MeshInstance3D",true,false)
  if model is MeshInstance3D: meshes.append(model)
  for mesh: MeshInstance3D in meshes:
   if mesh.is_visible_in_tree() and mesh.mesh != null:
    result.append({"inverse":mesh.global_transform.affine_inverse(),"box":mesh.get_aabb(),"instance_id":mesh.get_instance_id(),"node_path":str(mesh.get_path()),"faces":mesh.mesh.get_faces() if with_faces else PackedVector3Array()})
 return result
func clear_actual_carrier_body_and_drop(actor, eye: Vector3, decoration: Array) -> bool:
 var center: Vector3=actor.sprite.global_position
 var right: Vector3=(center-eye).cross(Vector3.UP).normalized()
 var width: float=actor.sprite.texture.get_width()/float(actor.sprite.hframes)*actor.sprite.pixel_size
 var height: float=actor.sprite.texture.get_height()/float(actor.sprite.vframes)*actor.sprite.pixel_size
 var samples: Array[Vector3]=[actor.global_position+Vector3.UP*.20]
 for x: float in [-.4,0.0,.4]:
  for y: float in [-.4,0.0,.4]:samples.append(center+right*width*x+Vector3.UP*height*y)
 for point: Vector3 in samples:
  if not host.level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,point,1)).is_empty():return false
  for bound: Dictionary in decoration:
   var a: Vector3=bound.inverse*eye;var b: Vector3=bound.inverse*point
   if bound.box.intersects_segment(a,b)==null:continue
   var faces: PackedVector3Array=bound.faces
   if faces.is_empty() or faces.size()%3!=0:return false
   # Broad bounds select actual renderer triangles; hollow props are not boxes.
   for index in range(0,faces.size(),3):
    if Geometry3D.segment_intersects_triangle(a,b,faces[index],faces[index+1],faces[index+2])!=null:return false
 return true
func frame_subject(actor) -> bool:
 var target: Vector3 = actor.sprite.global_position
 if is_instance_valid(actor.champion_identity): target = (target+actor.champion_identity.global_position)/2.0
 var best := INF; var selected := Vector3.INF
 var frame_height: float = actor.sprite.texture.get_height()/float(actor.sprite.vframes)*actor.sprite.pixel_size
 var preferred_distance: float = clampf(frame_height*1.55,7.0,12.0)
 var outline_check: bool = (chapter==3 and actor.id=="reliquary_enemy_06") or (chapter==1 and actor.id=="foundry_enemy_03") or (chapter==6 and actor.id=="inversion_enemy_26")
 var decoration: Array = world_decoration_bounds(chapter==3 and actor.id=="reliquary_enemy_06") if outline_check else []
 for cell in host.level.layout.tiles:
  var xz := (Vector2(cell)+Vector2(0.5,0.5))*4.0
  if xz.distance_to(Vector2(actor.position.x,actor.position.z))>18.0 or xz.distance_to(Vector2(actor.position.x,actor.position.z))<6.0: continue
  var foot: Vector3 = foot_at((Vector2(cell)+Vector2(0.5,0.5))*4.0)
  var distance: float = foot.distance_to(actor.position)
  if distance < 6.0 or distance > 18.0 or absf(foot.y-actor.position.y)>2.0: continue
  var cost: float = absf(distance-preferred_distance)
  if cost >= best: continue
  var ray = PhysicsRayQueryParameters3D.create(foot+Vector3.UP*1.55,target,1)
  if not host.level.get_world_3d().direct_space_state.intersect_ray(ray).is_empty() or not safe_foot(foot): continue
  if outline_check and not (chapter==3 and actor.id=="reliquary_enemy_06") and not clear_subject_outline(actor,foot+Vector3.UP*1.55,decoration): continue
  if chapter==3 and actor.id=="reliquary_enemy_06" and not clear_actual_carrier_body_and_drop(actor,foot+Vector3.UP*1.55,decoration):continue
  selected = foot; best = cost
 if not selected.is_finite(): return false
 host.player.cancel_actions();host.player.position=selected;host.reset_supply_sweep();report.arrangements.append({"kind":"explicit_portrait_start_not_travel","foot":v3(selected)});aim_off_center(target);return true
func frame_wall() -> bool:
 var layout = host.level.layout
 # Prefer a real wider room view; fallback still leaves a full bay/floor in frame.
 # No geometry/lighting/actor edits and no raised/free camera.
 for distance in [5.4,4.2,3.2]:
  for cell in layout.tiles:
   for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
    if layout.is_walkable(cell+direction): continue
    var cell_point := Vector2(cell)+Vector2(0.5,0.5)+Vector2(direction)*0.5
    var edge := Vector2(-direction.y,direction.x)*0.5
    var a: float = layout.height_at(cell_point-edge)
    var b: float = layout.height_at(cell_point+edge)
    if absf(a-b)>0.1: continue
    var point := cell_point*4.0
    var outward := Vector2(direction); var tangent := Vector2(-direction.y,direction.x)
    var location: Vector2 = point-outward*distance+tangent*1.6
    if not layout.is_walkable(Vector2i(floori(location.x/4.0),floori(location.y/4.0))): continue
    var foot: Vector3 = foot_at(location)
    if not foot.is_finite() or absf(foot.y-a)>0.4 or not safe_foot(foot): continue
    host.player.cancel_actions();host.player.position=foot;host.reset_supply_sweep();report.arrangements.append({"kind":"explicit_wall_start_not_travel","foot":v3(foot)})
    aim_world(Vector3(point.x,a+1.7,point.y)+Vector3(direction.x,0,direction.y)*0.5)
    return true
 return false
func pose(foot: Vector3, target: Vector3, reason: String, portrait: bool=false) -> bool:
 if not foot.is_finite() or not safe_foot(foot):return fail("No actual collision-clear standing pose: "+reason)
 release_actions();host.player.position=foot;host.player.velocity=Vector3.ZERO
 host.reset_supply_sweep()
 if portrait:aim_off_center(target)
 else:aim_world(target)
 report.arrangements.append({"kind":"explicit_start_pose_not_travel","reason":reason,"foot":v3(foot),"production_discontinuity_reset":true})
 await physics_frame;await physics_frame
 return true
func place_near(point: Vector3, distance: float, reason: String, actual_target: Vector3=Vector3.INF) -> bool:
 var aim: Vector3=actual_target if actual_target.is_finite() else point+Vector3.UP*.55
 for direction: Vector2 in [Vector2(1,0),Vector2(-1,0),Vector2(0,1),Vector2(0,-1),Vector2(.707,.707),Vector2(-.707,.707),Vector2(.707,-.707),Vector2(-.707,-.707)]:
  var foot: Vector3=foot_at(Vector2(point.x,point.z)+direction*distance)
  if not safe_foot(foot) or absf(foot.y-point.y)>.65:continue
  if not host.level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(foot+Vector3.UP*1.55,aim,1)).is_empty():continue
  return await pose(foot,aim,reason)
 return fail("No real supported LOS approach: "+reason)
func station_target(station: Dictionary) -> MeshInstance3D:
 if not host.level.healing_machinery.validate_station(station.id,true):return null
 return host.earned_runtime.station_use_target(host,station)
func station_root_local(station_id: String) -> Vector3:
 return host.level.healing_machinery.root_point(station_id)
func station_control_center(target: MeshInstance3D) -> Vector3:
 if not is_instance_valid(target) or target.mesh==null:return Vector3.INF
 return target.global_transform*target.mesh.get_aabb().get_center()
func negative_probe_snapshot(row: Dictionary) -> Dictionary:
 var root: Node3D=row.get("root") as Node3D
 var nodes: Dictionary=row.get("nodes",{})
 var collider: Dictionary=row.get("colliders",{}).get("fixed_structure",{})
 var target: MeshInstance3D=nodes.get("DialFace") as MeshInstance3D
 var stock: MeshInstance3D=nodes.get("StockVolume") as MeshInstance3D
 var body: StaticBody3D=collider.get("body") as StaticBody3D
 var collision: CollisionShape3D=collider.get("node") as CollisionShape3D
 var shape: Shape3D=collision.shape if is_instance_valid(collision) else null
 return {"family":row.get("family",""),"remaining":row.get("remaining",-1),"capacity":row.get("capacity",-1),
  "root_transform":var_to_str(root.transform) if is_instance_valid(root) else "invalid",
  "dial_visible":target.visible if is_instance_valid(target) else false,
  "dial_transform":var_to_str(target.transform) if is_instance_valid(target) else "invalid",
  "dial_mesh_class":target.mesh.get_class() if is_instance_valid(target) and target.mesh!=null else "none",
  "stock_transform":var_to_str(stock.transform) if is_instance_valid(stock) else "invalid",
  "body_collision_layer":body.collision_layer if is_instance_valid(body) else -1,
  "shape_class":shape.get_class() if is_instance_valid(shape) else "none",
  "triangle_faces":shape.get_faces().size()/3 if shape is ConcavePolygonShape3D else 0}
func visible_station_control_approach(eye: Vector3, point: Vector3, row: Dictionary, decoration: Array) -> bool:
 var hit: Dictionary=host.level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye,point,1))
 if not hit.is_empty() and hit.get("collider")!=row.colliders.fixed_structure.body:return false
 for bound: Dictionary in decoration:
  if bound.box.intersects_segment(bound.inverse*eye,bound.inverse*point)!=null:return false
 return true
func place_near_station(station: Dictionary, distance: float, reason: String) -> bool:
 var machine=host.level.healing_machinery
 var row: Dictionary=host.level.healing_stations.get(station.id,{})
 var root_point: Vector3=machine.root_point(station.id) # Current placed root, never old layout-cell locator.
 var anchor: Vector3=machine.station_world_point(station.id)
 var target: MeshInstance3D=station_target(station)
 if not root_point.is_finite() or not anchor.is_finite() or not is_instance_valid(target):return fail("No actual current family/control/front anchor: "+str(station.id))
 var control_center: Vector3=station_control_center(target)
 if not control_center.is_finite():return fail("Current visible DialFace has no finite mesh center: "+str(station.id))
 var decoration: Array=world_decoration_bounds()
 var candidates: Array[Vector3]=[]
 for direction: Vector2 in [Vector2(1,0),Vector2(-1,0),Vector2(0,1),Vector2(0,-1),Vector2(.707,.707),Vector2(-.707,.707),Vector2(.707,-.707),Vector2(-.707,-.707)]:
  candidates.append(foot_at(Vector2(root_point.x,root_point.z)+direction*distance))
 for candidate: Vector3 in candidates:
  var candidate_world: Vector3=host.level.to_global(candidate)
  if not safe_foot(candidate) or absf(candidate.y-root_point.y)>.60:continue
  # UseTarget is the production front/LOS anchor. The visible DialFace is a
  # different point inside a closed fixed collider, so raying to its center
  # self-intersects the machine. Keep both points in the trace and never
  # exclude the collider or waive nearest_station's actual LOS check.
  if not host.level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(candidate_world+Vector3.UP*1.55,anchor,1)).is_empty():continue
  if station.id=="ossuary_reservoir_final" and not visible_station_control_approach(candidate_world+Vector3.UP*1.55,control_center,row,decoration):continue
  if not await pose(candidate,control_center,reason+" actual control approach"):return false
  # Natural floor settle, production nearest-target/anchor/FOV/LOS check. No teleport qualifies itself.
  for settle_tick in range(8):
   if host.player.is_on_floor():break
   await physics_frame
  var observed: Dictionary=await physics_call(func():return {"station":host.earned_runtime.nearest_station(host),"foot":v3(host.player.position),"height_delta":absf(host.player.position.y-root_point.y),"on_floor":host.player.is_on_floor()})
  var eligible: Dictionary=observed.station
  var accepted: bool=eligible.get("id","")==station.id and observed.height_delta<=.60 and observed.on_floor
  trace_event({"kind":"actual_machine_supported_front_control_candidate","station":station.id,"family":row.get("family",""),"chapter":row.get("chapter",""),"root_local":v3(root_point),"front_anchor_world":v3(anchor),"visible_dial_face_center_world":v3(control_center),"eligible":accepted,"nearest_station":eligible.get("id","")})
  if not accepted:continue
  var current_target: MeshInstance3D=station_target(station)
  if not is_instance_valid(current_target):return fail("Registered actual current visible control unavailable after eligibility")
  var current_center: Vector3=station_control_center(current_target)
  if station.id=="ossuary_reservoir_final" and not visible_station_control_approach(host.player.camera.global_position,current_center,row,decoration):continue
  aim_world(current_center) # Actual supported player eye aimed at real authored visible control.
  var current_anchor: Vector3=machine.station_world_point(station.id)
  var exact: bool=machine.validate_station(station.id,true) and machine.validate_book(host.state.earned_supply,true)
  if not exact or current_anchor!=anchor:return fail("Current family/mesh/anchor/stock book changed after approach")
  trace_event({"kind":"actual_visible_machine_view","station":station.id,"family":row.family,"chapter":row.chapter,
   "root_local":v3(root_point),"root_world":v3(host.level.to_global(machine.root_point(station.id))),"yaw_degrees":rad_to_deg(row.root.rotation.y),"front_anchor_world":v3(current_anchor),
   "dial_face_center_world":v3(current_center),"dial_face_local_position":v3(current_target.position),
   "dial_face_local_scale":v3(current_target.scale),"dial_face_local_rotation":v3(current_target.rotation),
   "control_global_basis_z":v3(current_target.global_basis.z),"stock":row.remaining,"capacity":row.capacity,
   "mesh_names":row.nodes.keys(),"fixed_triangle_faces":row.colliders.fixed_structure.shape.get_faces().size()/3,
   "deep_station_validation":machine.validate_station(station.id,true),"finite_stock_book_validation":machine.validate_book(host.state.earned_supply,true),
   "supported_eligible_player_position":v3(host.player.position),"nearest_station":eligible.id})
  return true
 return fail("No actual-production eligible supported visible-control approach: "+str(station.id))
func registered_target_negative_contract() -> bool:
 # Use actual imported machinery nodes/mesh/stock/collider book. Mutations are
 # synchronous/restored before the next await or capture; no input/image while invalid.
 var station: Dictionary=Supply.chapter(host.level.layout).stations.filter(func(s):return str(s.id).ends_with("_entry"))[0]
 var machine=host.level.healing_machinery;var runtime=host.earned_runtime
 var row: Dictionary=host.level.healing_stations.get(station.id,{})
 var root: Node3D=row.get("root") as Node3D;var target: MeshInstance3D=machine.use_target(station.id)
 if not is_instance_valid(root) or not is_instance_valid(target) or not machine.validate_station(station.id,true) or not machine.validate_book(host.state.earned_supply,true):return fail("Actual imported family/control/stock book positive precondition")
 var original_root: Transform3D=root.transform;var original_target_transform: Transform3D=target.transform
 var original_target_visible: bool=target.visible;var original_target_mesh: Mesh=target.mesh
 var original_row: Dictionary=row.duplicate();var original_nodes: Dictionary=row.nodes.duplicate();var original_colliders: Dictionary=row.colliders.duplicate()
 var original_stock_volume: Transform3D=row.nodes.StockVolume.transform
 var collision: CollisionShape3D=row.colliders.fixed_structure.node
 var original_shape: Shape3D=collision.shape
 var controls: Dictionary={};var evidence: Dictionary={}
 var baseline_snapshot: Dictionary=negative_probe_snapshot(row)
 var actual_checks: Dictionary=host._export_earned_checks()
 controls["baseline"] = machine.validate_station(station.id,true) and machine.validate_book(host.state.earned_supply,true) and actual_checks.get("earned_marker_ownership",false) and actual_checks.get("earned_fixed_machine_geometry",false)
 evidence["baseline"]={"before":baseline_snapshot,"during":negative_probe_snapshot(row),"restored":negative_probe_snapshot(row),"rejected":false}
 var before_probe=negative_probe_snapshot(row);target.visible=false;var during_probe=negative_probe_snapshot(row);controls["hidden_visible_control"] = not machine.validate_station(station.id,true) and machine.use_target(station.id)==null;target.visible=original_target_visible;evidence["hidden_visible_control"]={"before":before_probe,"during":during_probe,"restored":negative_probe_snapshot(row),"rejected":controls["hidden_visible_control"]}
 before_probe=negative_probe_snapshot(row);target.position.x+=.01;during_probe=negative_probe_snapshot(row);controls["misplaced_dial_face"] = not machine.validate_station(station.id,true) and machine.use_target(station.id)==null;target.transform=original_target_transform;evidence["misplaced_dial_face"]={"before":before_probe,"during":during_probe,"restored":negative_probe_snapshot(row),"rejected":controls["misplaced_dial_face"]}
 before_probe=negative_probe_snapshot(row);target.mesh=SphereMesh.new();during_probe=negative_probe_snapshot(row);controls["foreign_dial_mesh"] = not machine.validate_station(station.id,true) and machine.use_target(station.id)==null;target.mesh=original_target_mesh;evidence["foreign_dial_mesh"]={"before":before_probe,"during":during_probe,"restored":negative_probe_snapshot(row),"rejected":controls["foreign_dial_mesh"]}
 before_probe=negative_probe_snapshot(row);root.position.x+=.01;during_probe=negative_probe_snapshot(row);controls["misplaced_machine_root"] = not machine.validate_station(station.id,true);root.transform=original_root;evidence["misplaced_machine_root"]={"before":before_probe,"during":during_probe,"restored":negative_probe_snapshot(row),"rejected":controls["misplaced_machine_root"]}
 var old_family: String=row.family;before_probe=negative_probe_snapshot(row);row.family="foreign-family";during_probe=negative_probe_snapshot(row);controls["foreign_family_identity"] = not machine.validate_station(station.id,true);row.family=old_family;evidence["foreign_family_identity"]={"before":before_probe,"during":during_probe,"restored":negative_probe_snapshot(row),"rejected":controls["foreign_family_identity"]}
 var old_remaining: int=row.remaining;before_probe=negative_probe_snapshot(row);row.remaining=0 if old_remaining>0 else 1;during_probe=negative_probe_snapshot(row);controls["wrong_runtime_stock_book"] = not machine.validate_book(host.state.earned_supply,true) and not host._export_earned_checks().get("earned_fixed_machine_geometry",true);row.remaining=old_remaining;evidence["wrong_runtime_stock_book"]={"before":before_probe,"during":during_probe,"restored":negative_probe_snapshot(row),"rejected":controls["wrong_runtime_stock_book"]}
 before_probe=negative_probe_snapshot(row);row.nodes.StockVolume.position.x+=.01;during_probe=negative_probe_snapshot(row);controls["misplaced_stock_volume_mesh"] = not machine.validate_station(station.id,true);row.nodes.StockVolume.transform=original_stock_volume;evidence["misplaced_stock_volume_mesh"]={"before":before_probe,"during":during_probe,"restored":negative_probe_snapshot(row),"rejected":controls["misplaced_stock_volume_mesh"]}
 before_probe=negative_probe_snapshot(row);collision.shape=BoxShape3D.new();during_probe=negative_probe_snapshot(row);controls["substituted_visible_collision"] = not machine.validate_station(station.id,true);collision.shape=original_shape;evidence["substituted_visible_collision"]={"before":before_probe,"during":during_probe,"restored":negative_probe_snapshot(row),"rejected":controls["substituted_visible_collision"]}
 var restored: bool=root.transform==original_root and target.transform==original_target_transform and target.visible==original_target_visible and target.mesh==original_target_mesh and row.family==original_row.family and row.remaining==original_row.remaining and row.nodes==original_nodes and row.colliders==original_colliders and row.nodes.StockVolume.transform==original_stock_volume and collision.shape==original_shape
 var restored_checks: Dictionary=host._export_earned_checks()
 if controls.values().any(func(value):return not value) or not restored or not machine.validate_station(station.id,true) or not machine.validate_book(host.state.earned_supply,true) or not restored_checks.get("earned_marker_ownership",false) or not restored_checks.get("earned_fixed_machine_geometry",false):return fail("Current imported machinery family/control/front anchor/stock/mesh/collider negative contract failed")
 if not host._export_earned_negative_controls():return fail("Production marker ownership negatives")
 trace_event({"kind":"actual_imported_machine_mesh_stock_collider_negative_contract","station":station.id,"family":row.family,"front_anchor_world":v3(machine.station_world_point(station.id)),"dial_face_center_world":v3(station_control_center(target)),"controls":controls,"evidence":evidence,"same_root_instance":root.get_instance_id(),"same_control_instance":target.get_instance_id(),"exact_restoration":restored,"source_not_campaign_depletion":true})
 return true
func build_scene(index: int, role_loadout: bool=false) -> bool:
 if is_instance_valid(host):
  release_actions();host.music.stop();host.effects.stop();await WallClock.seconds(self,.1);host.free();host=null
  await process_frame;await process_frame
 chapter=index;host=CaptureHost.new();host.settings_path="user://context96_preferences.json";host.progress_path="user://context96_campaign.json";view.add_child(host)
 host.set_process_unhandled_input(false);host.music.stop();host.effects.stop();host.preferences.apply_bindings()
 host.state.new_campaign(1)
 # Select a fresh test level through the production transition API. Do not mutate
 # level_index or replace an existing/depleted earned-supply envelope in place.
 var completed_prefix: Array=[]
 for prior_level in range(index):
  host.state.complete_level();completed_prefix.append(host.state.level_index)
 if host.state.level_index!=index:return fail("Production chapter progression failed to select fixture level")
 if role_loadout:
  host.state.owned_weapons=[0,1,2,3,4,5]
  for index_weapon in range(1,6):host.state.ammo[index_weapon]=host.Player.WEAPONS[index_weapon].max_ammo
  report.arrangements.append({"kind":"explicit_range_fixture_loadout","not_earned":true,"chapter":chapter})
 host.state.mark_checkpoint("entry",Vector3.ZERO)
 if not host.state.from_dict(host.state.to_dict()):return fail("Production Campaign rejects arranged chapter entry")
 host.level=MainSource.Level.new();host.level.process_mode=Node.PROCESS_MODE_PAUSABLE;host.add_child(host.level)
 if not host.level.build(host,chapter):return fail("Production Level build")
 if not Supply.valid(host.state.earned_supply,host.state._resources(),host.level.layout,host.state.difficulty):return fail("Selected fresh fixture earned-supply state is not authoritative for built level")
 host._scene_level_index=chapter;host.player=MainSource.Player.new();host.level.add_child(host.player);host.player.configure(host)
 host.player.position=host.level.layout.world_position(host.level.layout.data.spawn)+Vector3.UP*.04
 for spec in host.level.layout.data.enemies:
  var actor=MainSource.Enemy.new();host.level.add_child(actor);actor.configure(host,spec);host.enemies.append(actor);actor.set_physics_process(false)
 host.playing=true;host.placement_pending=false;host.menu_scroll.hide();host.message="";host.message_time=0;host.reset_supply_sweep();host.earned_runtime.refresh(host)
 paused=false
 if paused or host.level.process_mode!=Node.PROCESS_MODE_PAUSABLE:return fail("Arranged gameplay must use production unpaused/PAUSABLE lifecycle")
 host.player.set_process_unhandled_input(false) # No real OS input is consumed by this fixture.
 await physics_frame;await physics_frame
 if host.player.camera.position!=Vector3(0,1.55,0) or host.player.camera.fov!=85:return fail("Production eye/FOV changed")
 var version=host.canvas.get_node_or_null("BuildVersion") as Label
 if BuildInfo.BUILD_ITERATION!=96 or version==null or version.text!=BuildInfo.DISPLAY_NAME:return fail("Actual HUD version must be96")
 var environment: WorldEnvironment=host.level.find_children("*","WorldEnvironment",false,false)[0]
 if environment.environment.ambient_light_energy!=0.0:return fail("Production local-light-only environment changed")
 if index!=int(case_contract.get("scene_chapter",-1)):return fail("Built production scene differs from per-job contract")
 trace_event({"kind":"production_scene_ready","scene_id":host.level.layout.data.id,"chapter_index":index,"level_id":host.level.layout.data.id,"version":BuildInfo.DISPLAY_NAME,"camera_eye":v3(host.player.camera.global_position),"fov":host.player.camera.fov,"fixture_only_arranged_start":true,"selected_level_transition":"new_campaign_then_complete_level","completed_prefix":completed_prefix,"fresh_selected_finite_state_valid":true,"checkpoint_envelope_valid":Supply.valid(host.state.checkpoint.earned_supply,host.state.checkpoint,host.level.layout,host.state.difficulty),"level_start_envelope_valid":Supply.valid(host.state.level_start.earned_supply,host.state.level_start,host.level.layout,host.state.difficulty)})
 return true
func capture(label: String, subject: String, phase: String) -> bool:
 var role_setup: Dictionary=case_contract.get("role_arrangement",{})
 var role_actor_id: String=str(role_setup.get("actor_id",""))
 for actor in host.enemies:
  if not is_instance_valid(actor):continue
  if not role_actor_id.is_empty() and actor.id==role_actor_id:actor_pose(actor)
  else:actor_pose(actor)
 if mode=="weapon-roles" and not active_role_arrangement.is_empty():
  var refreshed: Dictionary=await physics_call(func():return role_current_contact())
  if refreshed.is_empty():return fail("Current selected role lost its actual opaque SpriteHitQuery contact before frame")
  active_role_arrangement=refreshed.duplicate(true)
 host.hud._process(0)
 await process_frame;await RenderingServer.frame_post_draw
 var image=view.get_texture().get_image()
 if image.get_size()!=Vector2i(640,360):return fail("Actual640x360 required, no resizing")
 image.convert(Image.FORMAT_RGBA8)
 var encoded: PackedByteArray=image.save_png_to_buffer()
 if png_bytes+encoded.size()>3*1024*1024:return fail("Owned perjob PNG3MiB bound")
 if FileAccess.file_exists(output.path_join(label+".png")):return fail("No frame overwrite")
 var file=FileAccess.open(output.path_join(label+".png"),FileAccess.WRITE)
 if file==null:return fail("Owned PNG path")
 file.store_buffer(encoded);file.close();png_bytes+=encoded.size()
 var state: Dictionary=state_binding();trace_sequence+=1
 report.frames.append({"case_id":case_id,"frame_index":report.frames.size(),"trace_seq":trace_sequence,"label":label,"file":label+".png","subject":subject,"phase":phase,"scene_id":state.get("scene_id",""),"camera":var_to_str(host.player.camera.global_transform),"camera_position":v3(host.player.camera.global_position),"camera_forward":v3(-host.player.camera.global_basis.z),"foot":v3(host.player.position),"velocity":v3(host.player.velocity),"physics_tick":Engine.get_physics_frames(),"time_usec":Time.get_ticks_usec(),"PNG_sha256":sha(encoded),"RGBA_sha256":sha(image.get_data()),"bytes":encoded.size(),"resolution":[640,360],"version":BuildInfo.DISPLAY_NAME,"weapon":host.state.weapon,"reduced_effects":host.settings.reduced_damage_flashes,"fixture_sha256":case_contract.get("fixture_sha256",""),"producer_sha256":case_contract.get("producer_sha256",""),"capture_controller_sha256":case_contract.get("capture_controller_sha256",""),"case_schema_sha256":case_contract.get("case_schema_sha256",""),"source_manifest_sha256":case_contract.get("source_manifest_sha256",""),"state_json":state_binding_encoded(state),"state_sha256":sha(state_binding_encoded(state).to_utf8_buffer()),"state":state,"role_arrangement":active_role_arrangement.duplicate(true),"trace_event_count":report.events.size(),"trace_motion_count":report.motion.size()})
 return true
func move_towards(target: Vector3, maximum_ticks: int=120) -> bool:
 for tick in range(maximum_ticks):
  var delta: Vector3=target-host.player.position;delta.y=0
  if delta.length()<.30:release_actions();return true
  if not host.playing:return fail("Production scene stopped during actual movement")
  aim_world(host.player.camera.global_position+delta);Input.action_press("move_forward")
  await physics_frame
  trace_motion({"tick":Engine.get_physics_frames(),"foot":v3(host.player.position),"velocity":v3(host.player.velocity),"target":v3(target),"floor":host.player.is_on_floor(),"action":"move_forward"})
 release_actions();return fail("Bounded actual movement did not reach target; no teleport completion")
func moving_loop(loop: Dictionary, label: String) -> bool:
 var route: Array=loop.route
 for segment in range(route.size()-1):
  var a: Vector3=host.level.layout.world_position(route[segment]);var b: Vector3=host.level.layout.world_position(route[segment+1]);var direction: Vector3=b-a;direction.y=0
  if direction.length()<10:continue
  direction=direction.normalized();var middle: Vector3=(a+b)/2.0;var start: Vector3=foot_at(Vector2(middle.x-direction.x*3,middle.z-direction.z*3));var clear=true
  for sample in range(9):
   var p: Vector3=foot_at(Vector2(start.x+direction.x*sample,start.z+direction.z*sample))
   if not safe_foot(p) or absf(p.y-start.y)>.35:clear=false;break
  if not clear:continue
  if not await pose(start,start+direction*8+Vector3.UP*1.55,label+" authored segment start"):return false
  aim_world(host.player.camera.global_position+direction);Input.action_press("move_forward")
  var before: Vector3=host.player.position
  for shot in range(3):
   for tick in range(8):
    await physics_frame;trace_motion({"loop":loop.id,"tick":Engine.get_physics_frames(),"foot":v3(host.player.position),"velocity":v3(host.player.velocity),"action":"move_forward","floor":host.player.is_on_floor()})
   if host.player.position.distance_to(before)<.10:return fail("No actual displacement in moving clip")
   if not await capture(label+"-"+str(shot),loop.id,"real production Player physics; partial route only"):return false
  release_actions();return true
 return fail("No collision-supported authored moving segment "+str(loop.id))
func reservoir_view(station: Dictionary, label: String) -> bool:
 var machine=host.level.healing_machinery
 var row: Dictionary=host.level.healing_stations.get(station.id,{})
 if not await place_near_station(station,2.0,label):return false
 var target: MeshInstance3D=station_target(station)
 if not is_instance_valid(target):return fail("Actual visible DialFace control unavailable")
 var control_center: Vector3=station_control_center(target)
 var anchor: Vector3=machine.station_world_point(station.id)
 aim_world(control_center)
 var visible_eligible: Dictionary=await physics_call(func():return host.earned_runtime.nearest_station(host))
 if visible_eligible.get("id","")!=station.id:return fail("Actual supported player/control-facing view must retain production nearest-station anchor+LOS eligibility")
 if not machine.validate_station(station.id,true) or not machine.validate_book(host.state.earned_supply,true):return fail("Actual current family/stock/mesh/collider book before view")
 trace_event({"kind":"actual_visible_family_pose_before_frame","station":station.id,"chapter":row.chapter,"family":row.family,"root_local":v3(machine.root_point(station.id)),"front_anchor_world":v3(anchor),"dial_face_center_world":v3(control_center),"control_normal_world":v3(target.global_basis.z),"stock":row.remaining,"capacity":row.capacity,"mesh_names":row.nodes.keys(),"eligible_nearest_station":visible_eligible.id,"deep_station_validation":machine.validate_station(station.id,true),"finite_stock_book_validation":machine.validate_book(host.state.earned_supply,true)})
 return await capture(label,station.id,"actual supported player eye aimed at real imported DialFace; current anchor/mesh/stock validated")
func run_routes() -> bool:
 var stations: Array=Supply.chapter(host.level.layout).stations
 var station_roles={}
 for station in stations:
  for role in ["entry","blood","ivory","final"]:
   if str(station.id).ends_with("_"+role):station_roles[role]=station
 if stations.size()!=4 or host.level.layout.data.loops.size()!=2:return fail("Exact4reservoir/2loop chapter coverage")
 var expected_family=host.level.healing_machinery._placements.get(stations[0].id,{}).get("family","")
 if expected_family.is_empty() or station_roles.size()!=4:return fail("Current family/4-placement chapter binding")
 for station in stations:
  var rig: Dictionary=host.level.healing_stations.get(station.id,{})
  if rig.get("chapter","")!=host.level.layout.data.id or rig.get("family","")!=expected_family or not host.level.healing_machinery.validate_station(station.id,true):return fail("Wrong selected chapter/family/pose book: "+station.id)
 if not await reservoir_view(station_roles["entry"],"reservoir-entry"):return false
 if not await moving_loop(host.level.layout.data.loops[0],"loop-a-moving"):return false
 if chapter==0 and not await pause_trace():return false
 if not await reservoir_view(station_roles["blood"],"reservoir-blood"):return false
 if not await moving_loop(host.level.layout.data.loops[1],"loop-b-moving"):return false
 if not await reservoir_view(station_roles["ivory"],"reservoir-ivory"):return false
 if not await reservoir_view(station_roles["final"],"reservoir-final"):return false
 var exit_spec: Dictionary=host.level.layout.data.interactions.filter(func(x):return x.kind=="exit")[0]
 var warden=find_actor(exit_spec.requires_defeated[0])
 if warden==null or not frame_subject(warden):return fail("No actual exit-warden standing silhouette")
 warden.target=host.player;warden._begin_attack(host.player.global_position+Vector3.UP)
 if not await capture("exit-threat-tell",warden.id,"manual production committed windup; AI frozen"):return false
 if not frame_wall():return fail("No supported chapter wall frame")
 return await capture("wall-local-light",host.level.layout.data.id,"unchanged actual wall/practical/floor geometry")
func find_actor(id: String):
 for actor in host.enemies:
  if is_instance_valid(actor) and actor.id==id:return actor
 return null
func pause_trace() -> bool:
 # No extra PNG; real pause/resume and production cancel, not frozen-phase emulation.
 Input.action_press("move_forward")
 for tick in range(8):await physics_frame
 var before={"foot":v3(host.player.position),"velocity":v3(host.player.velocity),"momentum":var_to_str(host.player._ground_movement.momentum),"remaining":host.player._ground_movement._remaining,"tick":Engine.get_physics_frames()}
 if Vector2(host.player.velocity.x,host.player.velocity.z).length()<=.05:return fail("Pause trace needs actual nonzero motion")
 Input.action_release("move_forward")
 var mouse_before: int=Input.mouse_mode
 host.pause_game()
 var paused_image={"foot":v3(host.player.position),"velocity":v3(host.player.velocity),"momentum":var_to_str(host.player._ground_movement.momentum),"remaining":host.player._ground_movement._remaining,"tick":Engine.get_physics_frames()}
 if host.player.velocity!=Vector3.ZERO or host.player._ground_movement.momentum!=Vector2.ZERO or host.player._ground_movement._remaining!=0:return fail("Production pause did not reset motion/phase")
 var anchor: Vector3=host.player.position
 await WallClock.seconds(self,.12)
 if host.player.position!=anchor:return fail("Paused position drift")
 host.resume_game()
 for tick in range(8):await physics_frame
 if Vector2(host.player.position.x-anchor.x,host.player.position.z-anchor.z).length()>.00005:return fail("Stale motion revived after resume without input")
 var idle={"foot":v3(host.player.position),"velocity":v3(host.player.velocity),"tick":Engine.get_physics_frames()}
 Input.action_press("move_forward")
 for tick in range(4):await physics_frame
 var fresh={"foot":v3(host.player.position),"velocity":v3(host.player.velocity),"tick":Engine.get_physics_frames()}
 if Vector2(host.player.velocity.x,host.player.velocity.z).length()<=.05 or Input.mouse_mode!=mouse_before:return fail("Fresh acceleration/cursor boundary")
 release_actions();trace_event({"kind":"actual_pause_reset_idle_resume_fresh_accel_noPNG","before":before,"paused":paused_image,"resumed_no_input":idle,"fresh_input":fresh,"mouse_mode_unchanged":true})
 return true
func death(actor) -> bool:
 var before_hp: int=actor.hp
 await physics_call(func():actor.take_damage(actor.hp+10000,host.player);return true)
 if actor.hp!=0 or not actor.id in host.state.removed or not host.playing:return fail("Production death/drop failed "+actor.id)
 actor_pose(actor,.13)
 trace_event({"kind":"arranged_lethal_damage_production_callbacks_not_earned_combat","actor":actor.id,"before_hp":before_hp,"after_hp":actor.hp,"removed":host.state.removed.duplicate(),"supply":host.state.earned_supply.duplicate(true),"seals":host.state.seal_drops.duplicate(true)})
 return true
func walk_collect(point: Vector3, reason: String, key_id: String="") -> bool:
 if not await place_near(point,1.6,reason+" supported start"):return false
 if not key_id.is_empty():
  host.hud._process(0)
  var hint: Dictionary=host.interaction_display()
  if hint.get("kind","")!="key" or hint.get("id","")!=key_id or host.hud.view.binding!="" or not str(host.hud.view.prompt).begins_with("WALK OVER TO RECOVER"):return fail("Actual auto-key HUD must show walkover with NO E/use binding")
  trace_event({"kind":"actual_auto_key_HUD_hint","key":key_id,"prompt":host.hud.view.prompt,"binding":host.hud.view.binding})
 # Every result below is committed only by the natural Player physics sweep.
 var target: Vector3=foot_at(Vector2(point.x,point.z))
 return await move_towards(target)
func heal(station: Dictionary) -> bool:
 if not await place_near_station(station,1.8,"reservoir approach"):return false
 await physics_call(func():host.hurt_player(45);return true)
 await WallClock.seconds(self,.4) # Production damage-flash decay; no image manipulation.
 var before_health: int=host.state.health;var before_stock: int=host.state.earned_supply.healing_remaining[station.id]
 if before_health>=100:return fail("Arranged wound did not create missing health")
 if not await capture("reservoir-before",station.id,"actual missing health and real prompt"):return false
 await physics_call(func():
  var release=InputEventKey.new();release.physical_keycode=KEY_SPACE;release.pressed=false
  host.get_window().window_input.emit(release);host.player._unhandled_input(release)
  var press=InputEventKey.new();press.physical_keycode=KEY_SPACE;press.pressed=true
  host.get_window().window_input.emit(press);host.player._unhandled_input(press)
  return true)
 await physics_frame;await physics_frame
 var after_health: int=host.state.health;var after_stock: int=host.state.earned_supply.healing_remaining[station.id]
 if after_health<=before_health or before_stock-after_stock!=after_health-before_health:return fail("No finite production Space-edge transfer")
 trace_event({"kind":"synthetic_ownedWindow_Space_events_to_realPlayer_and_next_physics_tick_NOT_hardware","station":station.id,"health_before":before_health,"health_after":after_health,"stock_before":before_stock,"stock_after":after_stock})
 return await capture("reservoir-after",station.id,"actual Space transfer; finite stock/health HUD")
func drop_practical_snapshot(marker: Node3D, practical: OmniLight3D) -> Dictionary:
 var children: Array=[]
 for child in marker.get_children():children.append(child.get_instance_id())
 children.sort()
 return {"marker_instance":marker.get_instance_id(),"practical_instance":practical.get_instance_id(),
  "parent_is_marker":practical.get_parent()==marker,"children":children,"visible":practical.visible,
  "practical_source":str(practical.get_meta("practical_source","")),"source_role":str(practical.get_meta("source_role","")),
  "energy":practical.light_energy,"range":practical.omni_range,"shadow":practical.shadow_enabled,
  "local_transform":var_to_str(practical.transform),"drop_state":host.state.earned_supply.duplicate(true)}
func drop_registry_bindings(registry: Dictionary) -> Dictionary:
 var bindings: Dictionary={}
 for key in registry:
  var marker=registry[key]
  if not is_instance_valid(marker):return {}
  bindings[str(key)]=marker.get_instance_id()
 return bindings
func actual_drop_practical_negative_probe(grant_id: String) -> bool:
 var drops: Array=host.state.earned_supply.loot_drops.filter(func(d):return d.grant_id==grant_id)
 var marker: Node3D=host.earned_runtime._markers.get(grant_id) as Node3D
 if drops.size()!=1 or not is_instance_valid(marker):return fail("Real uncollected ordinary drop required for applicable practical controls")
 var practical: OmniLight3D=host.earned_runtime._drop_practicals.get(marker.get_instance_id()) as OmniLight3D
 if not is_instance_valid(practical) or practical.get_parent()!=marker:return fail("Actual registered drop practical required; no no-drop shortcut")
 var registry: Dictionary=host.earned_runtime._markers
 var order_before: Array=registry.keys()
 var bindings_before: Dictionary=drop_registry_bindings(registry)
 var applicable_count: int=0
 for value in registry.values():
  if is_instance_valid(value) and host.earned_runtime._drop_practicals.has(value.get_instance_id()):applicable_count+=1
 if applicable_count<1 or bindings_before.size()!=registry.size():return fail("Actual real-drop registration must exist")
 # Source helper probes its first registered practical. Retain EVERY real
 # binding; arrange only iteration so the actual newly dead carrier is first.
 # Static world grants also own practicals and are not a uniqueness failure.
 var probe_order: Dictionary={grant_id:marker}
 for key in registry:
  if key!=grant_id:probe_order[key]=registry[key]
 if drop_registry_bindings(probe_order)!=bindings_before:return fail("No registration additions/substitutions during probe selection")
 var before: Dictionary=drop_practical_snapshot(marker,practical)
 var positive_before: bool=host._export_earned_checks().get("earned_marker_ownership",false)
 host.earned_runtime._markers=probe_order
 var positive_selected: bool=host._export_earned_checks().get("earned_marker_ownership",false)
 var result: bool=host._export_earned_drop_practical_negative_controls()
 host.earned_runtime._markers=registry
 var after: Dictionary=drop_practical_snapshot(marker,practical)
 var positive_after: bool=host._export_earned_checks().get("earned_marker_ownership",false)
 var bindings_after: Dictionary=drop_registry_bindings(host.earned_runtime._markers)
 var order_after: Array=host.earned_runtime._markers.keys()
 trace_event({"kind":"actual_applicable_drop_practical_negative_controls","grant":grant_id,"applicable":true,
  "applicable_count":applicable_count,"method":"_export_earned_drop_practical_negative_controls",
  "checked_source_operations":["hidden","substituted","foreign","nested","restored"],
  "returned_conjunction_pass":result,"positive_before":positive_before,"positive_selected":positive_selected,"positive_after":positive_after,
  "before":before,"after":after,"no_drop_shortcut":false,
  "method_first_grant":str(probe_order.keys()[0]),"method_first_marker_instance":probe_order.values()[0].get_instance_id(),
  "registry_bindings_before":bindings_before,"registry_bindings_during":drop_registry_bindings(probe_order),"registry_bindings_after":bindings_after,
  "registry_order_before":order_before,"registry_order_after":order_after,
  "arranged_iteration_only_all_bindings_preserved":true})
 return result and positive_before and positive_selected and positive_after and before==after and bindings_before==bindings_after and order_before==order_after
func run_transactions() -> bool:
 var content: Dictionary=Supply.chapter(host.level.layout)
 var grant: Dictionary={}
 for candidate in content.grants:
  if candidate.kind=="ammo" and int(candidate.weapon)==1 and find_actor(candidate.carrier)!=null and find_actor(candidate.carrier).champion.is_empty():grant=candidate;break
 if grant.is_empty():return fail("Actual ordinary ammo carrier required")
 var carrier=find_actor(grant.carrier)
 if not frame_subject(carrier):return fail("No clear actual carrier portrait")
 if chapter==3:
  for support_tick in range(8):
   if host.player.is_on_floor():break
   await physics_frame
  var decoration: Array=world_decoration_bounds(true)
  var supported_view: Dictionary=await physics_call(func():
   var floor_y: float=host.level.layout.capsule_floor_support(Vector2(host.player.position.x,host.player.position.z),.32)
   return {"on_floor":host.player.is_on_floor(),"floor_y":floor_y,"root_minus_floor":host.player.position.y-floor_y,
    "eye":v3(host.player.camera.global_position),"foot":v3(host.player.position),
    "actual_body_and_drop_unobstructed":clear_actual_carrier_body_and_drop(carrier,host.player.camera.global_position,decoration)})
  if not supported_view.on_floor or not is_finite(supported_view.floor_y) or absf(supported_view.root_minus_floor+.025)>.02 or not supported_view.actual_body_and_drop_unobstructed:return fail("Real naturally supported carrier body/drop view must be unobstructed by actual world geometry")
  var occluders: Array=[]
  for bound in decoration:occluders.append({"instance_id":bound.instance_id,"node_path":bound.node_path})
  trace_event({"kind":"actual_supported_unobstructed_carrier_view","actor":carrier.id,"support_and_view":supported_view,
   "world_decor_mesh_bindings":occluders,"body_outline_ray_count":9,"actual_drop_plane_ray_count":1,
   "world_actor_yaw_lighting_unchanged":true})
 if not await capture("carrier-live",carrier.id,"authored living carrier/equipment identity"):return false
 if not await death(carrier):return false
 var drops: Array=host.state.earned_supply.loot_drops.filter(func(d):return d.grant_id==grant.id)
 if drops.size()!=1:return fail("Exactly one production supply drop")
 var point: Vector3=Vector3(drops[0].position[0],drops[0].position[1],drops[0].position[2])
 aim_off_center(point+Vector3.UP*.4)
 if not await capture("carrier-corpse-drop",grant.id,"actual finite corpse equipment"):return false
 if not await physics_call(func():return actual_drop_practical_negative_probe(grant.id)):return false
 var before_ammo: int=host.state.ammo[1]
 if not await walk_collect(point,"ordinary loot walkover"):return false
 if host.state.ammo[1]<=before_ammo:return fail("Walkover did not transfer actual ammo")
 trace_event({"kind":"production_walkover_ammo","grant":grant.id,"before":before_ammo,"after":host.state.ammo[1],"drop_state":host.state.earned_supply.duplicate(true)})
 if not await capture("carrier-collected",grant.id,"actual physical pickup and HUD inventory"):return false
 var station: Dictionary=content.stations.filter(func(s):return str(s.id).ends_with("_entry"))[0]
 if not await heal(station):return false
 for spec in host.level.layout.data.interactions.filter(func(s):return s.has("seal_bearer")):
  var actor=find_actor(spec.seal_bearer)
  if actor==null or not frame_subject(actor):return fail("Actual seal-bearer portrait required")
  actor.target=host.player;actor._begin_attack(host.player.global_position+Vector3.UP)
  if not await capture(spec.key+"-live",actor.id,"manual production windup; stable seal identity"):return false
  if not await death(actor):return false
  var drop: Dictionary=Seals.drop_for(host.state,actor.id)
  if drop.is_empty():return fail("Actual seal drop absent")
  var location: Vector3=Vector3(drop.position[0],drop.position[1],drop.position[2]);aim_off_center(location+Vector3.UP*.5)
  if not await capture(spec.key+"-corpse-drop",actor.id,"production seal release"):return false
  if not await walk_collect(location,"automatic "+spec.key+" seal sweep",spec.id):return false
  if not spec.key in host.state.keys or not spec.id in host.state.removed:return fail("Automatic seal was not actually collected")
  if not await capture(spec.key+"-collected",spec.id,"actual no-E walkover key and HUD"):return false
 var exit_spec: Dictionary=host.level.layout.data.interactions.filter(func(s):return s.kind=="exit")[0]
 var warden=find_actor(exit_spec.requires_defeated[0])
 if warden==null or not frame_subject(warden):return fail("Actual exitwarden required")
 warden.target=host.player;warden._begin_attack(host.player.global_position+Vector3.UP)
 if not await capture("exit-warden-live",warden.id,"production committed exit threat"):return false
 if not await death(warden):return false
 if Seals.exit_warden_required(host.state,warden.id):return fail("Defeated exit warden still required")
 if not await capture("exit-warden-defeated",warden.id,"actual exit condition released"):return false
 var door: Dictionary=host.level.layout.data.doors[-1]
 var body: StaticBody3D=host.level.doors.get(door.id) as StaticBody3D
 if not is_instance_valid(body):return fail("Fresh gate release requires an actual still-closed original body")
 var center: Vector3=host.level.layout.world_position(door.cell)+Vector3.UP*1.2
 var normal: Vector3=Vector3.FORWARD.rotated(Vector3.UP,deg_to_rad(float(door.yaw)))
 var query=PhysicsRayQueryParameters3D.create(center-normal,center+normal,1)
 var closed_hit: Dictionary=host.level.get_world_3d().direct_space_state.intersect_ray(query)
 var before_gate={"removed":door.id in host.state.removed,"dictionary_entry":host.level.doors.has(door.id),"body_instance":body.get_instance_id(),"collision_layer":body.collision_layer,"visible":body.visible,"closed_ray_hits_original_body":closed_hit.get("collider")==body}
 if before_gate.removed or not before_gate.dictionary_entry or body.collision_layer==0 or not before_gate.closed_ray_hits_original_body:return fail("Fresh closed gate precondition; never adopt an already-open state")
 var before_gate_state: Dictionary=state_binding()
 var unlocked: bool=await physics_call(func():return host.unlock_door(door.id))
 # Production open_door synchronously erases dictionary entry, then retires body
 # after its normal tween. Retain its OWN identity, do not index erased entry.
 var after_hit: Dictionary=host.level.get_world_3d().direct_space_state.intersect_ray(query)
 var body_valid: bool=is_instance_valid(body)
 var cover: Node3D=host.level.gate_presentations.get(door.id,{}).get("cover") as Node3D
 var body_cleared: bool=not body_valid or (body.collision_layer==0 and not body.visible)
 var cover_cleared: bool=is_instance_valid(cover) and not cover.is_visible_in_tree()
 var after_gate={"removed":door.id in host.state.removed,"dictionary_entry":host.level.doors.has(door.id),"original_body_valid":body_valid,"original_body_cleared":body_cleared,"collision_layer":body.collision_layer if body_valid else null,"visible":body.visible if body_valid else null,"cover_hidden":cover_cleared,"actual_aperture_ray_clear":after_hit.is_empty()}
 trace_event({"kind":"fresh_production_gate_release","door":door.id,"before":before_gate,"state_before":before_gate_state,"unlock_return":unlocked,"after":after_gate})
 if not unlocked or not after_gate.removed or after_gate.dictionary_entry or not body_cleared or not cover_cleared or not after_gate.actual_aperture_ray_clear:return fail("Production fresh gate state/collider/visual/aperture release not proved")
 var gate_point: Vector3=host.level.layout.world_position(door.cell)
 if not await place_near(gate_point,5.5,"released actual gate view"):return false
 return await capture("gate-released",door.id,"actual production gate transaction, not chapter completion")
func choose_crosshair_actor(distance: float, bin_index: int=-1) -> Dictionary:
 # Selection runs wholly inside one physics callback. No sweep/collection is
 # invoked for rejected candidates; selected relocation is explicit+reset.
 active_role_arrangement={}
 var previous: Vector3=host.player.position;var previous_rotation: Vector3=host.player.rotation;var previous_camera: Vector3=host.player.camera.rotation
 var decoration: Array=world_decoration_bounds();var candidates: Array=[]
 var role_setup: Dictionary=case_contract.get("role_arrangement",{})
 var arranged_actor=null;var arranged_original_world: Vector3=Vector3.ZERO
 if not role_setup.is_empty():
  if bin_index<0 or bin_index>2:return {}
  var role_actor=null
  for actor in host.enemies:
   if is_instance_valid(actor) and actor.id==role_setup.get("actor_id",""):role_actor=actor;break
  if not is_instance_valid(role_actor) or role_actor.hp<=0 or not role_actor.champion.is_empty():return {}
  var target_data: Array=role_setup.target_worker_world
  var player_data: Array=role_setup.player_candidates_world[bin_index]
  var target_world:=Vector3(float(target_data[0]),float(target_data[1]),float(target_data[2]))
  var player_world:=Vector3(float(player_data[0]),float(player_data[1]),float(player_data[2]))
  var original_world: Vector3=host.level.to_global(role_actor.position)
  arranged_actor=role_actor;arranged_original_world=original_world
  role_actor.position=host.level.to_local(target_world);role_actor.velocity=Vector3.ZERO
  var fixed_foot: Vector3=host.level.to_local(player_world)
  var support_ok: bool=safe_foot(fixed_foot)
  var actor_support_query:=PhysicsRayQueryParameters3D.create(target_world+Vector3.UP*.25,target_world-Vector3.UP*.35,1)
  actor_support_query.exclude=[role_actor.get_rid()]
  var actor_support_hit: Dictionary=host.level.get_world_3d().direct_space_state.intersect_ray(actor_support_query)
  var actor_supported: bool=not actor_support_hit.is_empty() and actor_support_hit.collider in host.level.floor_bodies
  if not support_ok or not actor_supported:
   role_actor.position=host.level.to_local(original_world);host.player.position=previous;host.player.rotation=previous_rotation;host.player.camera.rotation=previous_camera;host.reset_supply_sweep();return {}
  candidates.append({"actor":role_actor,"foot":fixed_foot,"cost":0.0,"distance":distance,
   "role_target_world":target_world,"role_player_world":player_world,"role_original_world":original_world,"role_candidate_index":bin_index,"role_supported":actor_supported})
 else:
  for actor in host.enemies:
   if not is_instance_valid(actor) or actor.hp<=0 or not actor.champion.is_empty():continue
   actor_pose(actor)
   for cell in host.level.layout.tiles:
    var foot: Vector3=foot_at((Vector2(cell)+Vector2(.5,.5))*4.0)
    var measured: float=foot.distance_to(actor.position)
    var error: float=absf(measured-distance)
    if error>maxf(1.0,distance*.15) or absf(foot.y-actor.position.y)>1.0:continue
    candidates.append({"actor":actor,"foot":foot,"cost":error,"distance":measured})
 candidates.sort_custom(func(a,b):return a.cost<b.cost)
 var attempts: int=0
 for item in candidates:
  if not safe_foot(item.foot):continue
  host.player.position=item.foot
  if item.has("role_target_world"):actor_pose(item.actor)
  else:actor_pose(item.actor)
  aim_world(item.actor.sprite.global_position)
  if not clear_subject_outline(item.actor,host.player.camera.global_position,decoration):continue
  attempts+=1
  if attempts>128:break
  var points: Array[Vector3]=host.SpriteHitQuery.candidate_points(item.actor,host.player.camera,host.player.camera.global_position)
  for point: Vector3 in points.slice(0,8):
   aim_world(point)
   if item.has("role_target_world"):actor_pose(item.actor)
   var origin: Vector3=host.player.camera.global_position;var direction: Vector3=-host.player.camera.global_basis.z
   var exclude: Array[RID]=[host.player.get_rid()]
   var full=host.SpriteHitQuery.cast(host.level.get_world_3d().direct_space_state,origin,origin+direction*(distance*1.3+5),host.player.camera,host.enemies,exclude,1|4)
   if full.is_empty() or full.get("collider")!=item.actor:continue
   var actual_range: float=origin.distance_to(full.position)
   if (distance<=float(host.Player.WEAPONS[weapon].range))!=(actual_range<=float(host.Player.WEAPONS[weapon].range)):continue
   host.player.cancel_actions();host.reset_supply_sweep()
   var role_trace: Dictionary={"actor_id":item.actor.id,"arrangement_id":role_setup.get("arrangement_id","authored-role"),
    "candidate_index":bin_index,"source_status":role_setup.get("status","original-contract-role"),
    "target_world":v3(host.level.to_global(item.actor.position)),"player_world":v3(host.level.to_global(host.player.position)),
    "actor_yaw_degrees":item.actor.rotation_degrees.y,"support_verified":host.player.is_on_floor() and safe_foot(host.player.position),
    "opaque_contact_verified":full.get("collider")==item.actor,"actual_crosshair_point":v3(full.position),
    "sprite_frame":int(full.get("sprite_frame",-1)),"sprite_pixel":v2i(full.get("sprite_pixel",Vector2i(-1,-1))),
    "frame_pixel":v2i(full.get("frame_pixel",Vector2i(-1,-1))),"requested_distance_m":distance,
    "current_query_distance_m":origin.distance_to(full.position),"visual_query":"current production SpriteHitQuery.cast; no forced sprite frame"}
   if item.has("role_target_world"):
    role_trace.merge({"source_scout_proposal_sha256":role_setup.get("source_scout_proposal_sha256",""),
     "original_world":v3(item.role_original_world),"candidate_index":item.role_candidate_index},true)
   active_role_arrangement=role_trace.duplicate(true)
   report.arrangements.append({"kind":"range_start_not_earned_or_travel","actor":item.actor.id,"preferred_distance":distance,"actual_foot_distance":item.distance,"foot":v3(item.foot),"crosshair_current_mask_verified":true,"role_arrangement":role_trace})
   return {"actor":item.actor,"actor_id":item.actor.id,"distance":origin.distance_to(full.position),"hitpoint":v3(full.position),"foot":v3(item.foot),"role_arrangement":role_trace}
 if is_instance_valid(arranged_actor):arranged_actor.position=host.level.to_local(arranged_original_world);arranged_actor.velocity=Vector3.ZERO
 host.player.position=previous;host.player.rotation=previous_rotation;host.player.camera.rotation=previous_camera;host.reset_supply_sweep()
 return {}
func role_current_contact() -> Dictionary:
 var role_setup: Dictionary=case_contract.get("role_arrangement",{})
 if active_role_arrangement.is_empty():return {}
 var actor=null
 for candidate in host.enemies:
  if is_instance_valid(candidate) and candidate.id==active_role_arrangement.get("actor_id",""):actor=candidate;break
 if not is_instance_valid(actor) or actor.hp<=0 or not actor._current_map():return {}
 if not role_setup.is_empty():
  if not actor.champion.is_empty() or actor.kind!="worker":return {}
  var expected: Array=role_setup.target_worker_world
  var expected_world:=Vector3(float(expected[0]),float(expected[1]),float(expected[2]))
  var actual_world: Vector3=host.level.to_global(actor.position)
  if actual_world.distance_to(expected_world)>.02:return {}
  var player_expected: Array=role_setup.player_candidates_world[int(active_role_arrangement.get("candidate_index",-1))]
  var expected_player:=Vector3(float(player_expected[0]),float(player_expected[1]),float(player_expected[2]))
  var player_world: Vector3=host.level.to_global(host.player.position)
  if Vector2(player_world.x,player_world.z).distance_to(Vector2(expected_player.x,expected_player.z))>.02:return {}
 if not host.player.is_on_floor() or not safe_foot(host.player.position):return {}
 var player_world: Vector3=host.level.to_global(host.player.position)
 var support_y: float=host.level.layout.capsule_floor_support(Vector2(host.player.position.x,host.player.position.z),.32)
 if not is_finite(support_y) or absf((host.player.position.y-support_y)+.025)>.02:return {}
 var origin: Vector3=host.player.camera.global_position;var direction: Vector3=-host.player.camera.global_basis.z
 var query_length: float=maxf(float(host.Player.WEAPONS[weapon].range),float(active_role_arrangement.get("requested_distance_m",1.0))*1.3+5.0)
 var exclude: Array[RID]=[host.player.get_rid()]
 var full: Dictionary=host.SpriteHitQuery.cast(host.level.get_world_3d().direct_space_state,origin,origin+direction*query_length,host.player.camera,host.enemies,exclude,1|4)
 if full.is_empty() or full.get("collider")!=actor or full.get("coverage","")!="visible_sprite":return {}
 var target_world: Vector3=host.level.to_global(actor.position)
 var role_trace: Dictionary=active_role_arrangement.duplicate(true)
 role_trace.merge({"target_world":v3(target_world),"player_world":v3(player_world),"actor_yaw_degrees":actor.rotation_degrees.y,
  "support_verified":true,"support_floor_y":support_y,"root_minus_floor":host.player.position.y-support_y,
  "opaque_contact_verified":true,"actual_crosshair_point":v3(full.position),
  "sprite_frame":int(full.get("sprite_frame",-1)),"sprite_pixel":v2i(full.get("sprite_pixel",Vector2i(-1,-1))),
  "frame_pixel":v2i(full.get("frame_pixel",Vector2i(-1,-1))),"current_query_distance_m":origin.distance_to(full.position),
  "visual_query":"current production SpriteHitQuery.cast; no forced sprite frame"},true)
 return role_trace

func role_fire_transaction(actor, bin_index: int, distance: float) -> Dictionary:
 var role_setup: Dictionary=case_contract.get("role_arrangement",{})
 var current: Dictionary=role_current_contact()
 if current.is_empty() or current!=active_role_arrangement:return {"accepted":false,"reason":"Current visual frame/opaque contact differs from captured frame"}
 var origin: Vector3=host.player.camera.global_position;var direction: Vector3=-host.player.camera.global_basis.z
 var aim: Dictionary=host.resolve_aim(origin,direction,host.Player.WEAPONS[weapon].range,false)
 if aim.get("actor_id","")!=actor.id or aim.get("contact",{}).is_empty():return {"accepted":false,"reason":"Actual current Player.fire aim contact absent"}
 var hp_before: int=actor.hp;var ammo_before: int=host.state.ammo[weapon];var sequence_before: int=host.state.shot_sequence[weapon]
 var accepted: bool=host.player.fire()
 var actual_aim: Dictionary=host.aim_observation.duplicate(true)
 var contact: Dictionary=actual_aim.get("contact",{})
 var shot_contact: Dictionary={"actor_id":actual_aim.get("actor_id",""),"coverage":contact.get("coverage",""),
  "sprite_frame":int(contact.get("sprite_frame",-1)),"sprite_pixel":v2i(contact.get("sprite_pixel",Vector2i(-1,-1))),
  "frame_pixel":v2i(contact.get("frame_pixel",Vector2i(-1,-1))),"position":v3(contact.get("position",Vector3.INF))}
 return {"accepted":accepted,"ammo_before":ammo_before,"ammo_after":host.state.ammo[weapon],
  "sequence_before":sequence_before,"sequence_after":host.state.shot_sequence[weapon],"hp_before":hp_before,"hp_after":actor.hp,
  "aimed_actor":actual_aim.get("actor_id",""),"target_actor":actor.id,"range":host.Player.WEAPONS[weapon].range,
  "distance":origin.distance_to(contact.get("position",Vector3.ZERO)),"shot_contact":shot_contact,
  "role_arrangement":active_role_arrangement.duplicate(true),"accepted_tick":Engine.get_physics_frames(),"requested_distance_m":distance}
func run_weapon_roles() -> bool:
 var distances: Array=case_contract.get("preferred_ranges_m",[])
 if distances.size()!=3:return fail("Three exact per-job weapon distances required")
 var selected_chapter: int=int(case_contract.get("scene_chapter",-1))
 if selected_chapter<0 or selected_chapter>7:return fail("Per-job weapon scene missing")
 var role_setup: Dictionary=case_contract.get("role_arrangement",{})
 for reduced: bool in [false,true]:
  for bin_index in range(3):
   # New Reliquary Worker role bins each start from a legitimate fresh selected-level
   # state: no inherited damage, clutch, cooldown, spent stock, or old Ossuary image.
   if not await build_scene(selected_chapter,true):return false
   host.state.weapon=weapon;host.settings.reduced_damage_flashes=reduced
   release_actions()
   var selected: Dictionary=await physics_call(func():return choose_crosshair_actor(distances[bin_index],bin_index))
   if selected.is_empty():return fail("No actual authored crosshair/LOS target at required range "+str(distances[bin_index]))
   # All selected feet are only arrangement seeds, including original roles.
   # Natural gravity/support must settle before any current-contact proof.
   var naturally_supported: bool=false
   for support_tick in range(8):
    var floor_y: float=host.level.layout.capsule_floor_support(Vector2(host.player.position.x,host.player.position.z),.32)
    if host.player.is_on_floor() and is_finite(floor_y) and absf((host.player.position.y-floor_y)+.025)<=.02:
     naturally_supported=true;break
    await physics_frame
   if not naturally_supported:
    trace_event({"kind":"role_selection_rejected_natural_support","selected":selected,"actual_position":v3(host.player.position),"is_on_floor":host.player.is_on_floor()})
    return fail("Selected role did not naturally settle on production capsule floor support")
   if not role_setup.is_empty() and weapon==1:
    # The declared Y is only an arrangement seed. Let normal Player physics
    # settle the capsule and re-query the actual current sprite before capture.
    var settled: bool=false
    for support_tick in range(8):
     var floor_y: float=host.level.layout.capsule_floor_support(Vector2(host.player.position.x,host.player.position.z),.32)
     if host.player.is_on_floor() and is_finite(floor_y) and absf((host.player.position.y-floor_y)+.025)<=.02:
      settled=true;break
     await physics_frame
    if not settled:return fail("Selected player seed did not naturally settle onto capsule floor support")
    var current_role: Dictionary=role_current_contact()
    if current_role.is_empty():return fail("No current opaque target contact from naturally supported player pose")
    active_role_arrangement=current_role.duplicate(true)
    selected["role_arrangement"]=current_role.duplicate(true)
    selected["foot"]=v3(host.player.position)
    selected["distance"]=float(current_role.get("current_query_distance_m",-1.0))
    var label: String=("reduced" if reduced else "normal")+"-range-"+str(bin_index)
    if not await capture(label,selected.actor_id,"fresh Reliquary Worker current pose/opaque texel; actual pre-fire frame; no forced frame or hardware claim"):return false
    selected["role_arrangement"]=active_role_arrangement.duplicate(true)
    var transaction: Dictionary=await physics_call(func():return role_fire_transaction(selected.actor,bin_index,distances[bin_index]))
    if not transaction.get("accepted",false) or transaction.get("reason","")!="":return fail("Actual current Worker fire rejected: "+str(transaction.get("reason","unknown")))
    if transaction.sequence_after!=transaction.sequence_before+1 or transaction.ammo_before-transaction.ammo_after!=1:return fail("Actual Reliquary Rivet ammo/sequence delta mismatch")
    if transaction.target_actor!=selected.actor_id or transaction.aimed_actor!=selected.actor_id or transaction.range!=140.0:return fail("Actual normal/reduced Reliquary Rivet contact/cap mismatch")
    if int(transaction.hp_after)>=int(transaction.hp_before):return fail("Actual current opaque Worker contact did not cause HP loss")
    transaction["weapon"]=weapon;transaction["bin"]=bin_index;transaction["reduced_effects"]=reduced
    trace_event({"kind":"actual_crosshair_fire_not_redirected_portrait","weapon":weapon,"bin":bin_index,"reduced_effects":reduced,"role_arrangement":transaction.role_arrangement,"transaction":transaction})
    active_role_arrangement={}
    await WallClock.seconds(self,float(host.Player.WEAPONS[weapon].interval)+.02)
    continue
   # Preserve the original five weapon roles but capture the actual current
   # pre-fire frame and bind Player.fire to that exact production query.
   await physics_frame;await physics_frame
   var current_role: Dictionary=await physics_call(func():return role_current_contact())
   if current_role.is_empty():return fail("No current opaque production contact for source weapon role")
   active_role_arrangement=current_role.duplicate(true)
   selected["role_arrangement"]=active_role_arrangement.duplicate(true)
   selected["foot"]=v3(host.player.position)
   selected["distance"]=float(current_role.get("current_query_distance_m",-1.0))
   var label: String=("reduced" if reduced else "normal")+"-range-"+str(bin_index)
   if not await capture(label,selected.actor_id,"actual source weapon pre-fire frame/current opaque SpriteHitQuery; no hardware claim"):return false
   selected["role_arrangement"]=active_role_arrangement.duplicate(true)
   var transaction: Dictionary=await physics_call(func():
    var current: Dictionary=role_current_contact()
    if current.is_empty() or current!=selected.get("role_arrangement",{}):return {"accepted":false,"reason":"Current visual query drifted from captured frame"}
    var origin: Vector3=host.player.camera.global_position;var direction: Vector3=-host.player.camera.global_basis.z
    var hp: int=selected.actor.hp;var ammo: int=host.state.ammo[weapon];var sequence: int=host.state.shot_sequence[weapon]
    var accepted: bool=host.player.fire()
    var actual: Dictionary=host.aim_observation.duplicate(true);var contact: Dictionary=actual.get("contact",{})
    var shot: Dictionary={"actor_id":actual.get("actor_id",""),"coverage":contact.get("coverage",""),
     "sprite_frame":int(contact.get("sprite_frame",-1)),"sprite_pixel":v2i(contact.get("sprite_pixel",Vector2i(-1,-1))),
     "frame_pixel":v2i(contact.get("frame_pixel",Vector2i(-1,-1))),"position":v3(contact.get("position",Vector3.INF))}
    return {"accepted":accepted,"ammo_before":ammo,"ammo_after":host.state.ammo[weapon],"sequence_before":sequence,
     "sequence_after":host.state.shot_sequence[weapon],"hp_before":hp,"aimed_actor":actual.get("actor_id",""),
     "target_actor":selected.actor_id,"range":host.Player.WEAPONS[weapon].range,
     "distance":origin.distance_to(contact.get("position",Vector3.ZERO)),"requested_distance_m":distances[bin_index],
     "role_arrangement":current.duplicate(true),"shot_contact":shot})
   if not transaction.get("accepted",false) or transaction.get("reason","")!="":return fail("Actual source weapon fire rejected: "+str(transaction.get("reason","unknown")))
   if transaction.sequence_after!=transaction.sequence_before+1 or transaction.ammo_before-transaction.ammo_after!=(0 if weapon==0 else 1):return fail("Actual accepted-fire transaction/counter mismatch")
   var should_contact: bool=selected.distance<=float(transaction.range)
   if should_contact and transaction.aimed_actor!=selected.actor_id:return fail("Actual crosshair changed before fire")
   if not should_contact and transaction.aimed_actor==selected.actor_id:return fail("Finite range incorrectly reaches distant target")
   if weapon==4:
    trace_event({"kind":"actual_projectile_fire_immediate","weapon":weapon,"bin":bin_index,"reduced_effects":reduced,
     "role_arrangement":transaction.role_arrangement,"transaction":transaction.duplicate(true)})
    transaction["immediate_fire_trace_seq"]=trace_sequence
   if weapon==4:await WallClock.seconds(self,minf(1.25,selected.distance/48.0))
   if weapon==4:await WallClock.seconds(self,minf(3.0,selected.distance/24.0+.2))
   if should_contact and selected.actor.hp>=int(transaction.hp_before):return fail("In-range accepted shot produced no actual target damage/contact")
   if not should_contact and selected.actor.hp!=int(transaction.hp_before):return fail("Out-of-range target HP changed")
   transaction.erase("hp_after");transaction["hp_after"]=selected.actor.hp;transaction.erase("reduced_effects");transaction["reduced_effects"]=reduced
   transaction["weapon"]=weapon;transaction["bin"]=bin_index
   trace_event({"kind":"actual_crosshair_fire_not_redirected_portrait","weapon":weapon,"bin":bin_index,"reduced_effects":reduced,
    "role_arrangement":transaction.role_arrangement,"transaction":transaction})
   active_role_arrangement={}
   await WallClock.seconds(self,float(host.Player.WEAPONS[weapon].interval)+.02)
 return true
func finish_context(success: bool) -> void:
 release_actions();paused=false
 if is_instance_valid(host):host.music.stop();host.effects.stop()
 await WallClock.seconds(self,.1)
 if is_instance_valid(host):host.free();host=null
 await process_frame;await process_frame
 if success:print("PASS source96 moving context mode="+mode+" chapter="+str(chapter)+" weapon="+str(weapon)+" frames="+str(report.frames.size()))
 call_deferred("quit",0 if success else 1)
func run() -> void:
 output=OS.get_environment("NC_CONTEXT_OUTPUT")
 if output.is_empty() or not DirAccess.dir_exists_absolute(output):fail("Explicit owned output root");await finish_context(false);return
 var seen: Dictionary={}
 for arg in OS.get_cmdline_user_args():
  if not arg.begins_with("--") or not "=" in arg:fail("Exact mode/chapter/weapon arguments");await finish_context(false);return
  var fields: PackedStringArray=arg.trim_prefix("--").split("=",true,1)
  if fields[0] in seen:fail("Duplicate context argument");await finish_context(false);return
  seen[fields[0]]=fields[1]
 mode=str(seen.get("mode",""))
 if mode not in ["routes","transactions","weapon-roles"] or seen.size()!=2:fail("Exact two argument mode contract");await finish_context(false);return
 if mode=="weapon-roles":
  if not str(seen.get("weapon","")).is_valid_int():fail("Weapon argument");await finish_context(false);return
  weapon=int(seen.weapon)
  if weapon<0 or weapon>5:fail("Weapon range");await finish_context(false);return
 else:
  if not str(seen.get("chapter","")).is_valid_int():fail("Chapter argument");await finish_context(false);return
  chapter=int(seen.chapter)
  if chapter<0 or chapter>7:fail("Chapter range");await finish_context(false);return
 case_id="weapon-"+str(weapon)+"-roles" if mode=="weapon-roles" else "chapter-"+str(chapter)+"-"+mode
 if not load_case_contract():await finish_context(false);return
 AudioServer.set_bus_mute(0,true);Engine.time_scale=1.0
 view=SubViewport.new();view.size=Vector2i(640,360);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 report.merge({"mode":mode,"case_id":case_id,"requested_chapter":chapter,"weapon":weapon,"BuildInfo":BuildInfo.DISPLAY_NAME,"fixture_controls":["only_capture_mouse_boundary_overridden","AI_physics_frozen;manual_production_pose_windup_death_disclosed","real_Player_physics_passive_sweeps_and_RenderingServer_postdraw","arranged_start_poses_reset_supply_sweep;not_full_loop_traversal","no_actor_world_geometry_or_lighting_edits;registered_control_negative_mutations_restored_before_images","normal_HUD_weapon_camera;no_hardware_or_fullcampaign_claim"]})
 var ok: bool=false
 if mode=="weapon-roles":ok=await run_weapon_roles()
 elif await build_scene(chapter):
  if mode=="routes":
   if not registered_target_negative_contract():ok=false
   else:ok=await run_routes()
  else:ok=await run_transactions()
 var expected_frames: int=12 if mode=="routes" else 14 if mode=="transactions" else 6
 var actual_labels: Array=[];for frame in report.frames:actual_labels.append(frame.get("label",""))
 ok=ok and not failed and report.frames.size()==expected_frames and actual_labels==case_contract.get("frame_labels",[])
 if actual_labels!=case_contract.get("frame_labels",[]):fail("Actual case-specific frame label sequence mismatch")
 report.merge({"capture_functional":ok,"expected_frames":expected_frames,"trace_sequence_final":trace_sequence,"actual_chapter":host.state.level_index if is_instance_valid(host) else -1,"chapter_id":host.level.layout.data.id if is_instance_valid(host) else "","png_bytes":png_bytes,"source_not_export_qualified":true,"case_contract_sha256":case_contract.get("case_schema_sha256",""),"source_manifest_sha256":case_contract.get("source_manifest_sha256",""),"fixture_sha256":case_contract.get("fixture_sha256",""),"producer_sha256":case_contract.get("producer_sha256",""),"capture_controller_sha256":case_contract.get("capture_controller_sha256",""),"reused_native_index_sha256":"b1a24c134a14821893dcbdc8333f1501f8e912a4f1e9126defe1552360fc1a3a","capture_axes_UNRUN":["pending_drop_reload_continue_in_world","full_capacity_world_refusal","full_earned_route_prefix_economy","human_hardware_input","sustained_performance"]})
 var file=FileAccess.open(output.path_join("context.json"),FileAccess.WRITE)
 if file!=null:file.store_string(JSON.stringify(report,"  ",true,true));file.close()
 await finish_context(ok)
