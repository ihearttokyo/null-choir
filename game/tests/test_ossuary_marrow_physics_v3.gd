extends SceneTree
const StaticSelectedLevel = preload("res://tests/fixtures/static_selected_level.gd")
# DRAFT arranged world physics + real actor-profile navigation. No spawned enemies/earned play.
const Level=preload("res://scripts/level.gd")
const Campaign=preload("res://scripts/campaign.gd")
class Host extends Node:
 var state=Campaign.new()
 var level
var host
var failures=0
func check(ok:bool,label:String)->bool:
 if not ok:failures+=1;push_error(label)
 return ok
func _initialize()->void:call_deferred("run")
func ray_y(x:float,z:float,top:float,bottom:float)->float:
 var hit=host.level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,top,z),Vector3(x,bottom,z),1))
 return hit.position.y if not hit.is_empty() else -INF
func run()->void:
 host=Host.new();root.add_child(host);host.state=StaticSelectedLevel.fresh_selected(5,1)
 host.level=Level.new();host.add_child(host.level)
 if check(host.level.build(host,5),"Build unchanged production Level with explicit V3 surface recipe"):
  await physics_frame;await physics_frame
  check(absf(ray_y(26,74,7,4)-5.3)<.003,"Native new visible deck top5.3")
  check(absf(ray_y(23,74,5,0)-1.0)<.003,"Native exposed trench has actual lower bed1.0 and no old bank5")
  check(absf(ray_y(26,74,4.9,0)-1.0)<.003,"Native real bed exists beneath thin deck")
  check(absf(ray_y(21,66,7,4)-5)<.003,"Native escape top joins bank")
  check(absf(ray_y(21,75,4,0)-1.0)<.003,"Native escape bottom joins bed")
  check(host.level.get_node_or_null("LandmarkBase_ossuary_rib_bridge")==null,"No whole-arch blocking box")
  for spec in host.level.layout.data.scenery.slice(0,4):
   var xz=Vector2(spec.cell[0]*4,spec.cell[1]*4)
   var models=host.level.get_children().filter(func(node):return node is Node3D and node.scene_file_path=="res://assets/art/world/drain_altar.glb" and Vector2(node.position.x,node.position.z).distance_to(xz)<.001)
   check(models.size()==1 and absf(models[0].position.y-5.0)<.000001,"Actual original altar model root remains world5")
   var bodies=host.level.get_children().filter(func(node):return node is StaticBody3D and Vector2(node.position.x,node.position.z).distance_to(xz)<.001 and absf(node.position.y-5.15)<.000001)
   check(bodies.size()==1,"Actual original altar solid centre remains world5.15")
  var routes=host.level.get_node("NavigationRoutes")
  var deadline=Time.get_ticks_msec()+30000
  while (not routes.is_ready("worker") or not routes.is_ready("crawler")) and Time.get_ticks_msec()<deadline:await physics_frame
  for role in ["worker","crawler"]:
   check(routes.is_ready(role),"Actual unchanged "+role+" profile ready")
   for cells in [[[6.5,17.5],[6.5,19.5]],[[5.25,18.75],[5.25,16.5]]]:
    for reverse in [false,true]:
     var pair=cells.duplicate(true)
     if reverse:pair.reverse()
     var a=host.level.layout.world_position(pair[0]);var b=host.level.layout.world_position(pair[1])
     check(not routes.route(a,b,role,.25).is_empty(),"Native bidirectional exact .25 endpoint bridge/escape route "+role)
     await physics_frame
 host.level=null;host.free();await physics_frame;await process_frame
 print("OSSUARY_MARROW_PHYSICS failures=",failures," arranged=true earned_campaign=false")
 if failures==0:print("PASS Ossuary marrow physical surfaces and actor-profile routes")
 quit(0 if failures==0 else 1)
