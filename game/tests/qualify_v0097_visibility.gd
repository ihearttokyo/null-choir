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
var weapon: int = -1
var png_bytes: int = 0
var failed: bool = false
var report = {"status":"CAPTURED_PENDING_INDEPENDENT_REVIEW","resolution":[640,360],"arranged":true,"earned_combat":false,"hardware_input":false,"performance_claim":false,"frames":[],"events":[],"motion":[],"arrangements":[]}
class HiddenDrawPump extends Node:
 func _process(_delta: float) -> void:
  # macOS suppresses automatic drawing for a hidden window. Render only this
  # new test instance without showing/raising it; cadence is NOT a FPS sample.
  RenderingServer.force_draw(false)
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
func _initialize() -> void:
 root.hide() # New test window remains hidden; no app activation or OS capture.
 call_deferred("run")
func sha(bytes: PackedByteArray) -> String:
 var h=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(bytes);return h.finish().hex_encode()
func v3(point: Vector3) -> Array: return [point.x,point.y,point.z]
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
func actor_pose(actor, delta: float = 0.0) -> void:
 # Production visual selection executes, but its inactive return fences AI/motion.
 var active: bool = actor.active; actor.active = false; actor._physics_process(delta); actor.active = active
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
func world_decoration_bounds() -> Array:
 var result: Array = []
 for model: Node in host.level.get_children():
  if not model.scene_file_path.begins_with("res://assets/art/world/"): continue
  var meshes: Array = model.find_children("*","MeshInstance3D",true,false)
  if model is MeshInstance3D: meshes.append(model)
  for mesh: MeshInstance3D in meshes:
   if mesh.is_visible_in_tree() and mesh.mesh != null:
    result.append({"inverse":mesh.global_transform.affine_inverse(),"box":mesh.get_aabb()})
 return result
func frame_subject(actor) -> bool:
 var target: Vector3 = actor.sprite.global_position
 if is_instance_valid(actor.champion_identity): target = (target+actor.champion_identity.global_position)/2.0
 var best := INF; var selected := Vector3.INF
 var frame_height: float = actor.sprite.texture.get_height()/float(actor.sprite.vframes)*actor.sprite.pixel_size
 var preferred_distance: float = clampf(frame_height*1.55,7.0,12.0)
 var outline_check: bool = (chapter==1 and actor.id=="foundry_enemy_03") or (chapter==6 and actor.id=="inversion_enemy_26")
 var decoration: Array = world_decoration_bounds() if outline_check else []
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
  if outline_check and not clear_subject_outline(actor,foot+Vector3.UP*1.55,decoration): continue
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
func place_near(point: Vector3, distance: float, reason: String) -> bool:
 for direction: Vector2 in [Vector2(1,0),Vector2(-1,0),Vector2(0,1),Vector2(0,-1),Vector2(.707,.707),Vector2(-.707,.707),Vector2(.707,-.707),Vector2(-.707,-.707)]:
  var foot: Vector3=foot_at(Vector2(point.x,point.z)+direction*distance)
  if not safe_foot(foot) or absf(foot.y-point.y)>.65:continue
  if not host.level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(foot+Vector3.UP*1.55,point+Vector3.UP*.55,1)).is_empty():continue
  return await pose(foot,point+Vector3.UP*.55,reason)
 return fail("No real supported LOS approach: "+reason)
func build_scene(index: int, role_loadout: bool=false) -> bool:
 if is_instance_valid(host):
  release_actions();host.music.stop();host.effects.stop();await WallClock.seconds(self,.1);host.free();host=null
  await process_frame;await process_frame
 chapter=index;host=CaptureHost.new();host.settings_path="user://context96_preferences.json";host.progress_path="user://context96_campaign.json";view.add_child(host)
 host.set_process_unhandled_input(false);host.music.stop();host.effects.stop();host.preferences.apply_bindings()
 host.state.new_campaign(1);host.state.level_index=chapter;host.state._label_floor();host.state._reset_earned_supply()
 if role_loadout:
  host.state.owned_weapons=[0,1,2,3,4,5]
  for index_weapon in range(1,6):host.state.ammo[index_weapon]=host.Player.WEAPONS[index_weapon].max_ammo
  report.arrangements.append({"kind":"explicit_range_fixture_loadout","not_earned":true,"chapter":chapter})
 host.state.mark_checkpoint("entry",Vector3.ZERO)
 if not host.state.from_dict(host.state.to_dict()):return fail("Production Campaign rejects arranged chapter entry")
 host.level=MainSource.Level.new();host.add_child(host.level)
 if not host.level.build(host,chapter):return fail("Production Level build")
 host._scene_level_index=chapter;host.player=MainSource.Player.new();host.level.add_child(host.player);host.player.configure(host)
 host.player.position=host.level.layout.world_position(host.level.layout.data.spawn)+Vector3.UP*.04
 for spec in host.level.layout.data.enemies:
  var actor=MainSource.Enemy.new();host.level.add_child(actor);actor.configure(host,spec);host.enemies.append(actor);actor.set_physics_process(false)
 host.playing=true;host.placement_pending=false;host.menu_scroll.hide();host.message="";host.message_time=0;host.reset_supply_sweep();host.earned_runtime.refresh(host)
 host.player.set_process_unhandled_input(false) # No real OS input is consumed by this fixture.
 paused=false # Main.show_title starts paused; explicit arranged gameplay resumes it.
 print("97 phase: arranged chapter built and unpaused ",chapter)
 await physics_frame;await physics_frame
 if host.player.camera.position!=Vector3(0,1.55,0) or host.player.camera.fov!=85:return fail("Production eye/FOV changed")
 var version=host.canvas.get_node_or_null("BuildVersion") as Label
 if BuildInfo.BUILD_ITERATION!=97 or version==null or version.text!=BuildInfo.DISPLAY_NAME:return fail("Actual HUD version must be97")
 var environment: WorldEnvironment=host.level.find_children("*","WorldEnvironment",false,false)[0]
 if environment.environment.ambient_light_energy!=0.0:return fail("Production local-light-only environment changed")
 return true

func snap(label: String, actor) -> void:
 print("97 phase: capture ",label)
 await warm_draws(3)
 var picture: Image = view.get_texture().get_image()
 if picture.get_size()!=Vector2i(640,360): fail("Expected actual640x360");return
 var bytes: PackedByteArray = picture.save_png_to_buffer()
 var path: String = output.path_join(label+".png")
 if FileAccess.file_exists(path): fail("No overwrite");return
 var f=FileAccess.open(path,FileAccess.WRITE);f.store_buffer(bytes);f.close()
 var camera=host.player.camera
 var center: Vector3=actor.sprite.global_position
 var width: float=actor.sprite.texture.get_width()/float(actor.sprite.hframes)*actor.sprite.pixel_size
 var height: float=actor.sprite.texture.get_height()/float(actor.sprite.vframes)*actor.sprite.pixel_size
 var corners: Array=[]
 for x in [-.5,.5]:
  for y in [-.5,.5]:
   var pixel: Vector2=camera.unproject_position(center+camera.global_basis.x*width*x+Vector3.UP*height*y)
   corners.append([pixel.x,pixel.y])
 report.frames.append({"chapter":chapter,"file":label+".png","sha256":sha(bytes),"actor":actor.id,"role":actor.kind,"actor_position":v3(actor.position),"player_foot":v3(host.player.position),"camera":var_to_str(camera.global_transform),"sprite_corners":corners,"light_energy":actor.get_node("CarriedPractical").light_energy,"sprite_visible":actor.sprite.visible,"reduced_effects":host.settings.reduced_damage_flashes,"physics_tick":Engine.get_physics_frames()})

func finish97() -> void:
 if is_instance_valid(host):host.music.stop();host.effects.stop()
 await WallClock.seconds(self,.12)
 if is_instance_valid(host):host.free();host=null
 await process_frame;await process_frame
 report["failed"]=failed
 report["status"]="FAILED_NO_QUALIFICATION" if failed else "CAPTURED_PENDING_INDEPENDENT_REVIEW"
 report["rendering_method"]=RenderingServer.get_current_rendering_method()
 report["rendering_driver"]=RenderingServer.get_current_rendering_driver_name()
 var f=FileAccess.open(output.path_join("result.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify(report,"  "));f.close()
 quit(1 if failed else 0)

func warm_draws(count: int=3) -> void:
 for frame_index in range(count):
  await process_frame
  await RenderingServer.frame_post_draw

func ordinary_lights(energy: float) -> int:
 var count=0
 for actor in host.enemies:
  var light=actor.get_node_or_null("CarriedPractical")
  if light!=null and light.get_meta("source_role","")=="ordinary_threat":
   light.light_energy=energy;count+=1
 return count

func measure_lights(subject) -> void:
 var light_count=ordinary_lights(.65)
 for variant in ["all_current", "ordinary_off", "all_current_repeat"]:
  ordinary_lights(0.0 if variant=="ordinary_off" else .65)
  await warm_draws(8)
  var samples=[]
  for sample_index in range(20):
   await warm_draws(1)
   samples.append({"cpu_render_ms":RenderingServer.viewport_get_measured_render_time_cpu(view.get_viewport_rid()),"gpu_render_ms":RenderingServer.viewport_get_measured_render_time_gpu(view.get_viewport_rid())})
  report.events.append({"kind":"aggregate_light_cost_offscreen_not_FPS","chapter":chapter,"variant":variant,"ordinary_lights":light_count,"samples":samples})
 ordinary_lights(.65)

func frame_near(actor) -> bool:
 for distance in [3.8,4.6,5.2]:
  for angle_index in range(32):
   var angle: float=TAU*float(angle_index)/32.0
   var direction=Vector2(cos(angle),sin(angle))
   var foot: Vector3=foot_at(Vector2(actor.position.x,actor.position.z)+direction*distance)
   if not safe_foot(foot) or absf(foot.y-actor.position.y)>1.5:continue
   if not host.level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(foot+Vector3.UP*1.55,actor.sprite.global_position,1)).is_empty():continue
   host.player.position=foot;host.player.velocity=Vector3.ZERO;host.reset_supply_sweep();aim_world(actor.sprite.global_position)
   report.arrangements.append({"kind":"near_supported_LOS","chapter":chapter,"actor":actor.id,"distance":distance,"foot":v3(foot)})
   return true
 return false

func frame_occluded(actor) -> bool:
 for cell in host.level.layout.tiles:
  var foot: Vector3=foot_at((Vector2(cell)+Vector2(.5,.5))*4.0)
  var distance: float=foot.distance_to(actor.position)
  if distance<4.0 or distance>40.0 or absf(foot.y-actor.position.y)>8.0 or not safe_foot(foot):continue
  var hit=host.level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(foot+Vector3.UP*1.55,actor.sprite.global_position,1))
  if hit.is_empty():continue
  host.player.position=foot;host.reset_supply_sweep();aim_world(actor.sprite.global_position)
  report.arrangements.append({"kind":"occluded_real_wall_ray","chapter":chapter,"wall_hit":v3(hit.position),"player_foot":v3(foot),"actor":actor.id})
  return true
 return false

func run() -> void:
 output=OS.get_environment("NC97_OUTPUT")
 if output.is_empty() or not DirAccess.dir_exists_absolute(output):push_error("Explicit output required");quit(1);return
 var draw_pump=HiddenDrawPump.new();draw_pump.process_mode=Node.PROCESS_MODE_ALWAYS;root.add_child(draw_pump)
 report["schema"]="null-choir-v097-ordinary-threat-native-context-v1"
 report["hidden_manual_draw"]=true
 view=SubViewport.new();view.size=Vector2i(640,360);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(),true)
 var selection=OS.get_environment("NC97_CHAPTER")
 var indices=range(8) if selection.is_empty() else [int(selection)]
 report["required_chapters"]=Array(indices);report["completed_chapters"]=[]
 for chapter_index in indices:
  print("97 phase: chapter ",chapter_index)
  if not await build_scene(chapter_index):await finish97();return
  host.player.set_physics_process(false)
  # All actual production bodies/lights remain present; only selected actors'
  # AI is admitted for the explicitly arranged short motion observations.
  for actor in host.enemies:actor.set_physics_process(false)
  for role in ["worker","crawler","caster","brute"]:
   var subject
   for actor in host.enemies:
    var practical=actor.get_node_or_null("CarriedPractical")
    if actor.kind==role and actor.active and practical!=null and practical.get_meta("source_role","")=="ordinary_threat":
     subject=actor;break
   if subject==null:continue
   if not await physics_call(func():return frame_subject(subject)):
    fail("No supported LOS view "+str(chapter_index)+" "+role);await finish97();return
   aim_world(subject.sprite.global_position);actor_pose(subject)
   var prefix="chapter-%d-%s"%[chapter_index,role]
   var midfoot: Vector3=host.player.position
   ordinary_lights(0.0);await warm_draws()
   await snap(prefix+"-mid-off-control",subject)
   ordinary_lights(.65);await warm_draws()
   await snap(prefix+"-mid-current",subject)
   subject.sprite.hide();await warm_draws()
   await snap(prefix+"-mid-hidden-control",subject)
   subject.sprite.show();host.settings.reduced_damage_flashes=true;await warm_draws()
   await snap(prefix+"-mid-reduced",subject)
   host.settings.reduced_damage_flashes=false
   if not await physics_call(func():return frame_near(subject)):
    fail("No actual supported near view "+prefix);await finish97();return
   actor_pose(subject);await warm_draws()
   await snap(prefix+"-near-current",subject)
   host.player.position=midfoot;host.reset_supply_sweep();aim_world(subject.sprite.global_position)
   if role=="worker":
    await measure_lights(subject)
    if not await physics_call(func():return frame_occluded(subject)):
     fail("No real occluded negative "+prefix);await finish97();return
    await warm_draws();await snap(prefix+"-occluded-present",subject)
    subject.sprite.hide();await warm_draws();await snap(prefix+"-occluded-hidden",subject)
    subject.sprite.show();host.player.position=midfoot;host.reset_supply_sweep();aim_world(subject.sprite.global_position)
   subject.alerted=true;subject.target=host.player;subject.set_physics_process(true)
   var start: Vector3=subject.position
   for tick in range(36):
    await physics_frame
    aim_world(subject.sprite.global_position)
    report.motion.append({"chapter":chapter_index,"role":role,"actor":subject.id,"tick":tick,"actor_position":v3(subject.position),"speed":subject.speed,"rush_time":subject._rush_time,"telegraph":subject.telegraph_time,"recovery":subject.recovery_time})
    if tick in [0,11,23,35]:await snap(prefix+"-motion-%02d"%tick,subject)
   subject.set_physics_process(false)
   report.events.append({"kind":"actual_AI_short_approach_not_earned_combat","chapter":chapter_index,"role":role,"actor":subject.id,"start":v3(start),"end":v3(subject.position)})
  await warm_draws()
  report.completed_chapters.append(chapter_index)
 if report.completed_chapters!=report.required_chapters:fail("Incomplete requested chapter capture")
 await finish97()
