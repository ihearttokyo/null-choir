extends RefCounted
## Sole threshold-art resolver. Missing/invalid resources return no rig; Level retains fallback.
const Visual=preload("gate_visual.gd")
const REGISTRY={
 "containment_gate":{"scene":"intake","width":8.2},
 "foundry_gate":{"scene":"foundry","width":8.2},
 "processional_gate":{"scene":"processional","width":8.2},
 "reliquary_index_gate":{"scene":"reliquary","width":12.2},
 "nursery_growth_gate":{"scene":"nursery","width":12.2},
 "ossuary_transfer_gate":{"scene":"ossuary","width":12.2},
 "inversion_alignment_gate":{"scene":"inversion","width":12.2},
 "heart_final_gate":{"scene":"heart","width":12.2}}
static func create(spec:Dictionary)->Dictionary:
 var id=spec.get("id","")
 if not id is String or not REGISTRY.has(id):return _error("Unknown stable threshold ID")
 var sizes=spec.get("size",[])
 if not sizes is Array or sizes.size()!=3:return _error("Exact existing dimensions required")
 var expected=[REGISTRY[id].width,5.0,.6]
 for i in range(3):
  if not (sizes[i] is float or sizes[i] is int) or not is_finite(float(sizes[i])) or float(sizes[i])!=expected[i]:return _error("Exact existing dimensions required")
 if spec.get("requires",[])!=["blood","ivory"]:return _error("Both existing keys required")
 var path="res://assets/art/thresholds-v3/"+REGISTRY[id].scene+"_threshold.glb"
 if not ResourceLoader.exists(path,"PackedScene"):return _error("Threshold art unavailable: "+id)
 var packed=ResourceLoader.load(path,"PackedScene")
 if not packed is PackedScene:return _error("Threshold not normally imported")
 var imported=packed.instantiate()
 var problem=_scan(imported)
 if not problem.is_empty():imported.free();return _error(problem)
 var frame=_unique(imported,"StationaryFrame");var leaf=_unique(imported,"MovingLeaf")
 var blood=_unique(imported,"BloodLatch");var ivory=_unique(imported,"IvoryLatch")
 var released=_unique(imported,"ReleasedClosure")
 if frame==null or leaf==null or blood==null or ivory==null or released==null:
  imported.free();return _error("Required unique authored roles absent")
 if frame.get_parent()!=leaf.get_parent() or blood.get_parent()!=frame or ivory.get_parent()!=frame or released.get_parent()!=frame:
  imported.free();return _error("Authored role grouping differs")
 if not _grouped(imported,frame,leaf):
  imported.free();return _error("Mesh outside complete stationary/closure roles")
 var ancestor=frame.get_parent()
 while ancestor!=null:
  if ancestor is Node3D and not ancestor.transform.is_equal_approx(Transform3D.IDENTITY):
   imported.free();return _error("Unexpected authored root transform")
  if ancestor==imported:break
  ancestor=ancestor.get_parent()
 if not leaf.transform.is_equal_approx(Transform3D.IDENTITY) or not frame.transform.is_equal_approx(Transform3D.IDENTITY):
  imported.free();return _error("Unexpected component normalization")
 var shell=_shell(leaf)
 if shell==null:imported.free();return _error("Actual authored closure mesh absent")
 var width:float=REGISTRY[id].width
 var bounds=shell.transform*shell.mesh.get_aabb()
 if not bounds.position.is_equal_approx(Vector3(-width*.5,0,-.3)) or not bounds.size.is_equal_approx(Vector3(width,5,.6)):
  imported.free();return _error("Actual closure normalized bounds differ")
 if not _has_texture(shell) or not _sampled_coverage(shell,width):imported.free();return _error("Opaque textured closure missing")
 var released_bounds=_bounds(released,Transform3D.IDENTITY)
 if released_bounds.is_empty() or released_bounds.box.position.y<=5.0:
  imported.free();return _error("Released closure must be actual geometry above aperture")
 var rig=Visual.new();rig.name="Threshold_"+id
 var cover=Node3D.new();cover.name="ApertureCover";rig.add_child(cover)
 # Clear imported scene ownership before removing/reparenting authored nodes.
 _owner_tree(frame,null);_owner_tree(leaf,null)
 frame.get_parent().remove_child(frame);leaf.get_parent().remove_child(leaf)
 rig.add_child(frame);cover.add_child(leaf)
 frame.remove_child(blood);frame.remove_child(ivory)
 cover.add_child(blood);cover.add_child(ivory)
 imported.free()
 _owner_tree(frame,rig);_owner_tree(cover,rig)
 rig.configure({"frame":frame,"cover":cover,"leaf":leaf,"blood":blood,"ivory":ivory,"released":released})
 rig.set_meta("resource_path",path)
 return {"rig":rig,"cover":cover,"error":""}
static func _error(message:String)->Dictionary:return {"rig":null,"cover":null,"error":message}
static func _unique(root:Node,key:String)->Node3D:
 var found=[]
 _named(root,key,found)
 return found[0] as Node3D if found.size()==1 else null
static func _named(node:Node,key:String,found:Array)->void:
 if str(node.name)==key:found.append(node)
 for child in node.get_children():_named(child,key,found)
static func _shell(node:Node)->MeshInstance3D:
 if node is MeshInstance3D and str(node.name)=="MovingLeaf_Visual" and node.mesh!=null:return node
 for child in node.get_children():
  var found=_shell(child)
  if found!=null:return found
 return null
static func _has_texture(node:MeshInstance3D)->bool:
 var textured=false
 for i in range(node.mesh.get_surface_count()):
  var material=node.get_active_material(i)
  if not material is BaseMaterial3D or material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:return false
  if material.albedo_texture!=null:textured=true
 return textured
static func _scan(node:Node)->String:
 if node.get_script()!=null:return "Imported art must not contain scripts"
 if not node is Node3D or node is CollisionObject3D or node is CollisionShape3D or node is NavigationRegion3D or node is Camera3D or node is Light3D:return "Candidate contains non-mesh presentation ownership"
 if node is MeshInstance3D:
  if node.mesh==null or node.mesh.get_surface_count()==0:return "Empty editable mesh"
  for i in range(node.mesh.get_surface_count()):
   if node.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX].size()==0:return "Empty vertex surface"
   if node.get_active_material(i)==null:return "Missing authored material"
 for child in node.get_children():
  var error=_scan(child)
  if not error.is_empty():return error
 return ""

static func _owner_tree(node:Node,owner_node:Node)->void:
 node.owner=owner_node
 for child in node.get_children():_owner_tree(child,owner_node)

static func _bounds(node:Node3D,parent_transform:Transform3D)->Dictionary:
 var transform=parent_transform*node.transform
 var result={}
 if node is MeshInstance3D and node.mesh!=null:result={"box":transform*node.mesh.get_aabb()}
 for child in node.get_children():
  var bounds=_bounds(child,transform)
  if not bounds.is_empty():result={"box":bounds.box if result.is_empty() else result.box.merge(bounds.box)}
 return result

# Triangle evidence complements bounds: samples must lie on actual opaque closure geometry.
# Not an exhaustive raster/shot-space proof; asset qualification still owns full intended-use coverage.
static func _sampled_coverage(shell:MeshInstance3D,width:float)->bool:
 var points:Array[Vector2]=[]
 for y in range(5):
  for x in range(7):points.append(Vector2(lerpf(-width*.5+.01,width*.5-.01,float(x)/6),lerpf(.01,4.99,float(y)/4)))
 var found=[]
 found.resize(points.size());found.fill(false)
 for surface in range(shell.mesh.get_surface_count()):
  var arrays=shell.mesh.surface_get_arrays(surface)
  var vertices=arrays[Mesh.ARRAY_VERTEX];var indices=arrays[Mesh.ARRAY_INDEX]
  var count=indices.size() if indices!=null and indices.size()>0 else vertices.size()
  for triangle in range(0,count-2,3):
   var xy:Array[Vector2]=[]
   for offset in range(3):
    var index=indices[triangle+offset] if indices!=null and indices.size()>0 else triangle+offset
    var vertex:Vector3=shell.transform*vertices[index]
    xy.append(Vector2(vertex.x,vertex.y))
   var area=(xy[1]-xy[0]).cross(xy[2]-xy[0])
   if absf(area)<.0000001:continue
   for i in range(points.size()):
    if found[i]:continue
    var b=(points[i]-xy[0]).cross(xy[2]-xy[0])/area
    var c=(xy[1]-xy[0]).cross(points[i]-xy[0])/area
    if b>=-.000001 and c>=-.000001 and b+c<=1.000001:found[i]=true
 return found.all(func(value):return value)

# Structural grouping only; test_gate_art audits actual stationary triangles against
# the usable aperture. Frame ancestry alone is NOT proof of open visual clearance.
static func _grouped(node:Node,frame:Node,leaf:Node)->bool:
 if node is MeshInstance3D and not (node==frame or frame.is_ancestor_of(node) or node==leaf or leaf.is_ancestor_of(node)):return false
 for child in node.get_children():
  if not _grouped(child,frame,leaf):return false
 return true
