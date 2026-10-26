extends SceneTree
## Source-bound art service fixture. Real imports required for explicitly requested IDs.
const Layout=preload("res://scripts/level_data.gd")
const Art=preload("res://scripts/gate_art.gd")
var failures=0
func check(ok:bool,message:String)->void:
 if not ok:failures+=1;push_error(message)
func _initialize()->void:call_deferred("run")
func run()->void:
 var selection=OS.get_environment("GATE_TEST_MAP_INDEX")
 if selection not in ["","0","1","2","3","4","5","6","7"]:push_error("Explicit gate fixture map must be0..7");quit(1);return
 var map_index=int(selection) if not selection.is_empty() else 0
 var selected=Layout.new()
 check(selected.load_level(map_index),"Actual selected Layout loads")
 if failures>0:quit(1);return
 var spec:Dictionary=selected.data.doors[0]
 print("GATE_ART_SELECTED map_index=",map_index," map_id=",selected.data.id," door_id=",spec.id," origin=",selected.world_position(spec.cell)," yaw=",spec.yaw," width=",spec.size[0])
 for value in [null,"bad",[8.2,5], [8.2,5,true],[INF,5,.6],[8.3,5,.6]]:
  var invalid=spec.duplicate(true);invalid.size=value
  check(Art.create(invalid).rig==null,"Invalid dimensions rejected without resource side effects")
 var unknown=spec.duplicate(true);unknown.id="made_up"
 check(Art.create(unknown).rig==null,"No unknown/prototype fallback")
 check(Art.REGISTRY.size()==8,"Exactly eight explicit stable bindings")
 # Require the frozen production pair plus selected chapter, not unimplemented neighbors.
 var required_indices=[0,1]
 if not map_index in required_indices:required_indices.append(map_index)
 var specs={}
 for index in required_indices:
  var actual=Layout.new()
  check(actual.load_level(index),"Required actual source Layout loads")
  if not actual.data.is_empty():specs[actual.data.doors[0].id]=actual.data.doors[0]
 # Preserve explicitly requested extra resource preconditions; never infer all8 present.
 var requested=OS.get_environment("GATE_ART_REQUIRED_IDS")
 if not requested.is_empty():
  for id in requested.split(","):
   check(Art.REGISTRY.has(id),"Explicitly requested known stable ID")
   if specs.has(id):continue
   for index in range(8):
    var actual=Layout.new()
    if actual.load_level(index) and actual.data.doors[0].id==id:specs[id]=actual.data.doors[0];break
 for id in specs:
  var current:Dictionary=specs[id]
  var create_started=Time.get_ticks_usec()
  var result=Art.create(current)
  print("GATE_ART_CREATE id=",id," elapsed_usec=",Time.get_ticks_usec()-create_started)
  check(result.rig!=null and result.cover!=null and result.error.is_empty(),"Required actual imported threshold: "+id)
  if result.rig==null:continue
  var rig=result.rig;var cover=result.cover
  root.add_child(rig)
  check(cover.get_script()==null and cover.get_parent()==rig,"Independent unscripted native cover handle")
  check(rig.leaf.get_parent()==cover and rig.blood_latch.get_parent()==cover and rig.ivory_latch.get_parent()==cover,"Complete crossing leaf and both carriages under cover")
  check(rig.frame.get_parent()==rig and rig.released_closure.get_parent()==rig.frame,"Stationary frame/released geometry separate")
  var bp=rig.blood_latch.position;var ip=rig.ivory_latch.position
  for keys in [[false,false],[true,false],[false,true],[true,true]]:
   rig.hydrate(keys[0],keys[1],false)
   check(cover.visible and not rig.released_closure.visible,"All four closed states retain closure")
   check(rig.blood_latch.position==bp+Vector3(-1.35 if keys[0] else 0,0,0),"Absolute independent blood state")
   check(rig.ivory_latch.position==ip+Vector3(1.35 if keys[1] else 0,0,0),"Absolute independent ivory state")
   rig.present_keys(keys[0],keys[1])
   check(rig.blood_latch.position==bp+Vector3(-1.35 if keys[0] else 0,0,0),"Repeated refresh cannot accumulate")
  cover.hide() # Real Level-owned native operation before optional callback.
  check(not rig.leaf.is_visible_in_tree() and not rig.blood_latch.is_visible_in_tree() and not rig.ivory_latch.is_visible_in_tree(),"Native cover atomically clears every crossing component")
  rig.begin_open_visuals();rig.begin_open_visuals();rig.present_keys(false,false)
  check(not cover.visible and rig.released_closure.visible,"Open callback idempotent and keys cannot resurrect")
  # Qualification-only exact triangle-role check, not a per-Level-load validator.
  var usable_run=float(Art.REGISTRY[id].width)-.2
  var overlaps=stationary_aperture_overlaps(rig.frame,usable_run)
  check(overlaps.is_empty(),"Actual stationary art clears usable run after Coverhide: "+str(overlaps))
  var strap=MeshInstance3D.new();strap.name="NEGATIVE_MisgroupedOpaqueRearStrap"
  var strap_mesh=BoxMesh.new();strap_mesh.size=Vector3(usable_run-.5,.45,.08);strap.mesh=strap_mesh
  strap.material_override=StandardMaterial3D.new();strap.position=Vector3(0,2.5,-.75)
  rig.frame.add_child(strap)
  var negative=stationary_aperture_overlaps(rig.frame,usable_run)
  check(negative.any(func(row):return str(row.mesh).contains("NEGATIVE_MisgroupedOpaqueRearStrap")),"Rear strap UNDER Frame fails actual usable-aperture role audit")
  strap.free()
  check(stationary_aperture_overlaps(rig.frame,usable_run).is_empty(),"Negative control removed without suppressing actual audit")
  rig.present_removed();rig.present_keys(true,true)
  check(not cover.visible and rig.released_closure.visible,"Removed final pose no replay")
  rig.hydrate(false,false,true)
  check(not cover.visible and rig.released_closure.visible,"Cold removed reconstruction")
  rig.free()
 await process_frame
 print("GATE_ART failures=",failures)
 if failures==0:print("PASS actual threshold art service contracts")
 quit(0 if failures==0 else 1)

# Qualification-only: actual side walls are .28m thick. Source opening run is8/12m,
# not the8.2/12.2m blocker including wall overlap. Audit positive-area triangle
# intrusion into x=(-run/2+.14,run/2-.14), y=(0,5), on BOTH sides at any depth.
# This is visual obstruction/role evidence, not a change to capsule/nav clearance.
func stationary_aperture_overlaps(frame:Node3D,run:float)->Array:
 var failures_found:Array=[]
 _audit_stationary(frame,Transform3D.IDENTITY,Rect2(Vector2(-run*.5+.14,0),Vector2(run-.28,5)),failures_found)
 return failures_found
func _audit_stationary(node:Node3D,parent_transform:Transform3D,aperture:Rect2,rows:Array)->void:
 if not node.visible:return
 var transform=parent_transform*node.transform
 if node is MeshInstance3D and node.mesh!=null:
  for surface in range(node.mesh.get_surface_count()):
   var material=node.get_active_material(surface)
   if not material is BaseMaterial3D or material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:continue
   var arrays=node.mesh.surface_get_arrays(surface)
   var vertices=arrays[Mesh.ARRAY_VERTEX];var indices=arrays[Mesh.ARRAY_INDEX]
   var count=indices.size() if indices!=null and indices.size()>0 else vertices.size()
   for triangle in range(0,count-2,3):
    var polygon:Array[Vector2]=[]
    var points3=[]
    for offset in range(3):
     var index=indices[triangle+offset] if indices!=null and indices.size()>0 else triangle+offset
     var point:Vector3=transform*vertices[index]
     polygon.append(Vector2(point.x,point.y));points3.append([point.x,point.y,point.z])
    for plane in [[0,aperture.position.x,true],[0,aperture.end.x,false],[1,aperture.position.y,true],[1,aperture.end.y,false]]:
     polygon=_clip(polygon,plane[0],plane[1],plane[2])
    if _area(polygon)>.0000001:
     rows.append({"mesh":str(node.get_path()),"surface":surface,"triangle":triangle/3,"clipped_area":_area(polygon),"triangle_points":points3})
     break # One exact offending triangle per material is enough; bounded diagnostics.
 for child in node.get_children():_audit_stationary(child,transform,aperture,rows)
func _clip(points:Array[Vector2],axis:int,bound:float,minimum:bool)->Array[Vector2]:
 var result:Array[Vector2]=[]
 if points.is_empty():return result
 var previous=points[-1]
 var was_inside=previous[axis]>=bound if minimum else previous[axis]<=bound
 for current in points:
  var inside=current[axis]>=bound if minimum else current[axis]<=bound
  if inside!=was_inside:
   var fraction=(bound-previous[axis])/(current[axis]-previous[axis])
   result.append(previous.lerp(current,fraction))
  if inside:result.append(current)
  previous=current;was_inside=inside
 return result
func _area(points:Array[Vector2])->float:
 var twice=0.0
 for i in range(points.size()):twice+=points[i].cross(points[(i+1)%points.size()])
 return absf(twice)*.5
