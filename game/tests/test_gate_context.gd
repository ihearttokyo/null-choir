extends SceneTree
## Actual STATIC Level art/physics, no Main/Player/enemy/audio/input; arranged camera only.
const LevelSource=preload("res://scripts/level.gd")
const GateArt=preload("res://scripts/gate_art.gd")
const Layout=preload("res://scripts/level_data.gd")
const Campaign=preload("res://scripts/campaign.gd")
class Host extends Node:
 var state=Campaign.new()
 var level
var failures=0
var report={"scope":"Actual STATIC selected Level native640x360; no Main/player/enemies/audio/physicalinput/FPS/earnedcampaign","checks":[],"views":[]}
func check(ok:bool,message:String):
 report.checks.append({"passed":ok,"message":message})
 if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func triangles(node:Node)->Array:
 var result=[]
 var meshes=[]
 if node is MeshInstance3D:meshes.append(node)
 meshes.append_array(node.find_children("*","MeshInstance3D",true,false))
 for mesh in meshes:
  var faces=mesh.mesh.get_faces()
  for i in range(0,faces.size(),3):result.append([mesh.global_transform*faces[i],mesh.global_transform*faces[i+1],mesh.global_transform*faces[i+2]])
 return result
func segment_mesh(from:Vector3,to:Vector3,faces:Array)->Array:
 var hits=[]
 for t in faces:
  var hit=Geometry3D.segment_intersects_triangle(from,to,t[0],t[1],t[2])
  if hit!=null:hits.append(hit)
 return hits
func triangle_box(t:Array)->AABB:return AABB(t[0],Vector3.ZERO).expand(t[1]).expand(t[2]).grow(.000001)
func triangle_overlap(a:Array,b:Array)->Variant:
 for tri in [[a,b],[b,a]]:
  for i in range(3):
   var hit=Geometry3D.segment_intersects_triangle(tri[0][i],tri[0][(i+1)%3],tri[1][0],tri[1][1],tri[1][2])
   if hit!=null:return hit
 return null
func vault_intersections(frame_faces:Array,vault_faces:Array)->Array:
 var cells={};var cell_size=.5
 for index in range(vault_faces.size()):
  var box=triangle_box(vault_faces[index]);var lo=Vector3i((box.position/cell_size).floor());var hi=Vector3i((box.end/cell_size).floor())
  for x in range(lo.x,hi.x+1):
   for y in range(lo.y,hi.y+1):
    for z in range(lo.z,hi.z+1):
     var key=Vector3i(x,y,z)
     if not cells.has(key):cells[key]=[]
     cells[key].append(index)
 var hits=[]
 for t in frame_faces:
  var box=triangle_box(t);var lo=Vector3i((box.position/cell_size).floor());var hi=Vector3i((box.end/cell_size).floor());var seen={}
  for x in range(lo.x,hi.x+1):
   for y in range(lo.y,hi.y+1):
    for z in range(lo.z,hi.z+1):
     for index in cells.get(Vector3i(x,y,z),[]):
      if seen.has(index):continue
      seen[index]=true
      var other=vault_faces[index]
      if box.intersects(triangle_box(other)):
       var hit=triangle_overlap(t,other)
       if hit!=null:
        hits.append([hit.x,hit.y,hit.z])
        if hits.size()>=3:return hits
 return hits
func run():
 var output=OS.get_environment("NULL_CHOIR_THRESHOLD_OUTPUT")
 var view=SubViewport.new();view.size=Vector2i(640,360);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 var selection=OS.get_environment("GATE_TEST_MAP_INDEX")
 if selection not in ["","0","1","2","3","4","5","6","7"]:push_error("Explicit gate fixture map must be0..7");quit(1);return
 var map_index=int(selection) if not selection.is_empty() else 0
 report["map_index"]=map_index
 var required_indices=[0,1]
 if not map_index in required_indices:required_indices.append(map_index)
 for required_index in required_indices:
  var required=Layout.new()
  check(required.load_level(required_index),"Actual required Layout loads")
  if required.data.is_empty():continue
  var imported=GateArt.create(required.data.doors[0])
  check(imported.get("rig") is Node3D and imported.get("cover") is Node3D,"Required actual production resource: "+str(required.data.id))
  if imported.get("rig") is Node:imported.rig.free()
 if failures>0:view.free();quit(1);return
 var host=Host.new();view.add_child(host);host.state.new_campaign(1)
 for step in range(map_index):host.state.complete_level()
 var level=LevelSource.new();host.add_child(level);host.level=level
 if not level.build(host,map_index):
  check(false,"Actual current selected Level builds all static geometry/scenery/environment")
  level.free();host.free();view.free();quit(1);return
 # No navigation acceptance here; prevent unrelated asynchronous role bakes in a static-art fixture.
 var navigation=level.get_node_or_null("NavigationRoutes")
 if navigation!=null:navigation.set_process(false);navigation.set_physics_process(false)
 var data=level.layout.data;var spec:Dictionary=data.doors[0];var bottom:Vector3=level.layout.world_position(spec.cell)
 var gate_basis=Basis(Vector3.UP,deg_to_rad(float(spec.yaw)))
 var run_width=float(spec.size[0])-.2
 host.state.mark_checkpoint("entry",level.layout.world_position(data.spawn))
 report["map_id"]=data.id;report["door_id"]=spec.id;report["door_origin"]=str(bottom)
 report["door_yaw_degrees"]=spec.yaw;report["door_width"]=spec.size[0];report["usable_run_width"]=run_width-.28
 var body:StaticBody3D=level.doors[spec.id];var original_shape=body.get_child(1).shape if body.get_child(0) is MeshInstance3D else body.get_child(0).shape
 var original_transform=body.transform
 var presentation:Dictionary=level.gate_presentations.get(spec.id,{})
 check(presentation.get("rig") is Node3D,"Actual Level consumes registered runtime GateArt service")
 if not presentation.get("rig") is Node3D:level.free();host.free();view.free();quit(1);return
 var rig=presentation.rig;var cover=presentation.cover;await physics_frame;await physics_frame
 var world=level.get_world_3d().direct_space_state
 var original_rid=body.get_rid()
 var anchor_hits=[];var frame_faces=triangles(rig.frame)
 for side in [-1,1]:
  for height in [.75,2.55,4.45]:
   var from=floor_at_offset(level.layout,bottom,gate_basis,Vector2(side*(run_width*.5-.3),0))+Vector3.UP*height;var to=floor_at_offset(level.layout,bottom,gate_basis,Vector2(side*(run_width*.5+.4),0))+Vector3.UP*height
   var query=PhysicsRayQueryParameters3D.create(from,to,1);query.exclude=[original_rid]
   var hit=world.intersect_ray(query)
   check(not hit.is_empty(),"Actual wall return collision at modeled anchor height")
   var actual_wall=false
   if not hit.is_empty():
    for shape in hit.collider.get_children():
     if shape is CollisionShape3D and shape.shape is BoxShape3D and absf((shape.shape.size.x if absf(gate_basis.x.x)>.5 else shape.shape.size.z)-.28)<.0001 and shape.shape.size.y>5:actual_wall=true
   check(actual_wall,"Anchor ray contacts actual .28m Level sidewall, not scenery/floor")
   var art_hits=segment_mesh(from,to,frame_faces)
   check(not art_hits.is_empty(),"Actual imported anchor mesh bridges into same wall return interval")
   anchor_hits.append({"side":side,"height":height,"wall_hit":str(hit.get("position")),"actual_wall":actual_wall,"frame_surface_hits":art_hits.size(),"scope":"Wall seated support, NOT outboard floor contact"})
 report.anchor_contacts=anchor_hits
 # Floors have native bodies; roofs in this Level are rendered mesh only, so measure actual roof triangles.
 var roof_faces=[]
 for child in level.get_children():
  if child is MeshInstance3D and str(child.name).begins_with("Ceiling"):roof_faces.append_array(triangles(child))
 var roof_hits=[]
 var actual_roof_max_y=-INF
 for triangle in roof_faces:
  for vertex in triangle:actual_roof_max_y=maxf(actual_roof_max_y,vertex.y)
 check(is_finite(actual_roof_max_y),"Actual selected rendered ceiling has a finite geometry envelope")
 for x in [-run_width*.375,0.0,run_width*.375]:
  var p=floor_at_offset(level.layout,bottom,gate_basis,Vector2(x,0))+Vector3.UP*5.5
  # Keep the strict conservative crown start; only the endpoint derives from
  # actual selected ceiling triangles (Reliquary8m and taller chapters included).
  var endpoint=Vector3(p.x,maxf(p.y,actual_roof_max_y)+.01,p.z)
  var hits=segment_mesh(p,endpoint,roof_faces)
  check(not hits.is_empty(),"Actual rendered Level roof lies above conservative crown sample")
  roof_hits.append({"local_x":x,"actual_roof_hits":str(hits),"probe_y":p.y,"endpoint_y":endpoint.y,"actual_ceiling_max_y":actual_roof_max_y,"native_roof_collision":false})
 report.roof_samples=roof_hits
 var floor_query=PhysicsRayQueryParameters3D.create(bottom+Vector3.UP,bottom-Vector3.UP,1);floor_query.exclude=[original_rid]
 var floor_hit=world.intersect_ray(floor_query)
 check(not floor_hit.is_empty() and floor_hit.collider in level.floor_bodies,"Door origin has actual Level-owned native floor support")
 report.door_floor_hit=str(floor_hit.get("position"))
 # Existing vault is one metre along gate normal; exact native mesh intersections, not whole-AABB guess.
 var nearby_vault=null;var nearest_distance=INF
 for child in level.get_children():
  if child is Node3D and child.scene_file_path.ends_with("/vault_span.glb"):
   var distance=Vector2(child.position.x-bottom.x,child.position.z-bottom.z).length()
   if distance<nearest_distance:nearest_distance=distance;nearby_vault=child
 check(nearby_vault!=null,"Actual nearest imported vault_span identified, without inventing an Intake1m offset")
 if map_index==0:check(nearest_distance<1.1,"Original Intake known1m vault remains the selected witness")
 report["nearest_vault_distance"]=nearest_distance
 if nearby_vault!=null:
  var vault_faces=triangles(nearby_vault);var intersections=vault_intersections(frame_faces,vault_faces)
  report.nearby_vault={"position":str(nearby_vault.global_position),"yaw":nearby_vault.rotation.y,"normal_offset":(gate_basis.inverse()*(nearby_vault.global_position-bottom)).z,"frame_triangles":frame_faces.size(),"vault_triangles":vault_faces.size(),"noncoplanar_intersections_up_to3":intersections,"coplanar_contact_not_certified":true}
  print("VAULT_CONTEXT ",JSON.stringify(report.nearby_vault))
 var camera=Camera3D.new();camera.fov=85;camera.near=.08;view.add_child(camera)
 var sheet=Image.create(1920,1080,false,Image.FORMAT_RGBA8);sheet.fill(Color.BLACK)
 var cases=[{"name":"none-front","keys":[]},{"name":"blood-front","keys":["blood"]},{"name":"ivory-front","keys":["ivory"]},{"name":"both-front","keys":["blood","ivory"]},{"name":"both-back","keys":["blood","ivory"]},{"name":"both-oblique","keys":["blood","ivory"]},{"name":"open-front","keys":["blood","ivory"]}]
 var index=0
 for item in cases:
  host.state.keys=item.keys
  # Independent arranged seal states: reset authored native light colors before real production refresh.
  for light_spec in data.lights:
   if light_spec.has("id") and level.machine_lights.has(light_spec.id):level.machine_lights[light_spec.id].light_color=Color(light_spec.color[0],light_spec.color[1],light_spec.color[2])
  level.refresh_machine_lights();level.refresh_gate_presentations()
  var offset=Vector2(3,4.8) if item.name=="both-oblique" else Vector2(0,-4.8 if item.name=="both-back" else 4.8)
  var foot:Vector3=floor_at_offset(level.layout,bottom,gate_basis,offset);camera.position=foot+Vector3.UP*1.55;camera.look_at(bottom+Vector3.UP*2.5)
  if item.name=="open-front":
   level.open_door(spec.id);check(body.collision_layer==0 and not cover.visible and rig.released_closure.visible,"Existing actual Level.open_door atomically clears native cover and shows released closure")
   await physics_frame
   var capsule=CapsuleShape3D.new();capsule.radius=.32;capsule.height=1.65;var clearance=[]
   for z_offset in [-3.0,-1.0,0.0,1.0,3.0]:
    var transformed=bottom+gate_basis*Vector3(0,0,z_offset);var xz_point=Vector2(transformed.x,transformed.z);var support:float=level.layout.capsule_floor_support(xz_point,.32)
    var query=PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.transform=Transform3D(Basis.IDENTITY,Vector3(xz_point.x,support+.85,xz_point.y));query.collision_mask=1
    var hits=world.intersect_shape(query,8)
    check(hits.is_empty(),"Actual WORLD central crossing fits unchanged production .32/1.65 capsule after gate open")
    clearance.append({"gate_local_normal_offset":z_offset,"world_xz":[xz_point.x,xz_point.y],"support":support,"overlaps":hits.size()})
   report.actual_open_capsule_crossing=clearance
  else:check(body.transform==original_transform and body.collision_layer==1,"Four-state/back/oblique static presentation leaves actual collider untouched")
  await process_frame;await RenderingServer.frame_post_draw
  var pixels=view.get_texture().get_image();pixels.convert(Image.FORMAT_RGBA8);pixels.save_png(output.path_join(item.name+".png"));sheet.blit_rect(pixels,Rect2i(0,0,640,360),Vector2i((index%3)*640,(index/3)*360))
  report.views.append({"file":item.name+".png","camera":str(camera.position),"eye_height":1.55,"fov":85,"resolution":[640,360],"lighting":"Actual unchanged Level environment + authored lights; no fixture lights","arranged_keys":item.keys});index+=1
 sheet.save_png(output.path_join("context-contact-sheet.png"))
 var released_faces=triangles(rig.released_closure)
 var released_min_y=INF
 for triangle in released_faces:
  for vertex in triangle:released_min_y=minf(released_min_y,vertex.y-bottom.y)
 check(released_min_y>5.0,"Actual runtime ReleasedClosure geometry remains completely above old aperture")
 report.runtime_released_min_local_y=released_min_y
 report.primary_presenter="Actual game/scripts/gate_art.gd and gate_visual.gd, not legacy prototypewrapper"
 report.failures=failures;report.physics_scope="Native floor/wall/body/capsule queries; actual roof mesh triangles (no roof collider). No traversal/nav/campaign proof."
 var file=FileAccess.open(output.path_join("context-report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
 level.queue_free();host.queue_free();camera.queue_free();await process_frame;await process_frame;view.queue_free();await process_frame;await process_frame
 if failures==0:print("PASS production selected actualSTATICLevel640x360/anchors/roof/floor/vault/capsule; no gameplay/quality/FPSclaim")
 quit(0 if failures==0 else 1)

func floor_at_offset(layout,bottom:Vector3,gate_basis:Basis,local_xz:Vector2)->Vector3:
 var point=bottom+gate_basis*Vector3(local_xz.x,0,local_xz.y)
 var cell_size=float(layout.data.cell_size)
 return layout.world_position([point.x/cell_size,point.z/cell_size])
