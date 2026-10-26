extends RefCounted
# DRAFT ONLY. New visible bone deck beneath the unchanged GLB ARCH, not an AABB collider.
const ARCH_SHA256 = "3e3b213231d2ad5d6d1fb248d26dd0441665ae9b90e15199908f469cbbdcaa1d"
const CUT = Rect2(20.0,66.0,12.0,12.0)
const XS = [20.0,22.0,24.5,27.5,32.0]
const ZS = [66.0,70.225,71.425,72.0,74.0,76.0,76.575,77.775,78.0]

static func enabled(data: Dictionary) -> bool:
 return data.get("id","") == "ossuary" and data.get("floor_revision",0) == 3 and data.get("terrain_patch",{}).get("recipe","") == "ossuary_marrow_v3"

# Every entry has exactly one triangle, material class and walkability flag.
# Render/native collision consume ALL entries. CPU floor queries consume walkable entries.
static func build(layout) -> Array:
 var faces: Array = []
 var size: float = layout.data.cell_size
 for cell in layout.tiles:
  var corners: Array[Vector3] = []
  for offset in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]:
   var p = Vector2(cell)+offset
   corners.append(Vector3(p.x*size,layout.height_at(p),p.y*size))
  for ids in [[0,1,2],[0,2,3]]:
   var tri: Array[Vector3] = [corners[ids[0]],corners[ids[1]],corners[ids[2]]]
   if enabled(layout.data):
    for polygon in _outside(tri): _fan(faces,polygon,"bank",true)
   else: _fan(faces,tri,"bank",true)
 if not enabled(layout.data): return faces
 # Local top surfaces. Adjacent differing heights receive genuine vertical cut walls.
 var cells: Array = []
 for ix in range(XS.size()-1):
  for iz in range(ZS.size()-1):
   var x0: float = XS[ix]; var x1: float = XS[ix+1]
   var z0: float = ZS[iz]; var z1: float = ZS[iz+1]
   var kind = _kind((x0+x1)*0.5,(z0+z1)*0.5)
   var quad: Array[Vector3] = []
   for xz in [Vector2(x0,z0),Vector2(x1,z0),Vector2(x1,z1),Vector2(x0,z1)]:
    quad.append(Vector3(xz.x,_height(kind,xz.y),xz.y))
   _fan(faces,quad,"bone" if kind in ["deck","north","south"] else "marrow" if kind == "bed" else "bank",true)
   cells.append({"ix":ix,"iz":iz,"q":quad,"kind":kind})
   if kind == "deck":
    # Bed below span plus deck underside: no buried bank floor at y5.
    if z0 >= 72.0 and z1 <= 76.0: _quad(faces,x0,z0,x1,z1,1.0,"marrow",true)
    _quad(faces,x0,z0,x1,z1,5.0,"bone",false,true)
 for c in cells:
  for neighbor in cells:
   if neighbor.ix == c.ix+1 and neighbor.iz == c.iz:
    _join(faces,c.q[1],c.q[2],neighbor.q[0],neighbor.q[3])
   if neighbor.iz == c.iz+1 and neighbor.ix == c.ix:
    _join(faces,c.q[3],c.q[2],neighbor.q[0],neighbor.q[1])
 # Actual under-bank cut faces at the span ends; do not leave an open void under banks.
 for z in [72.0,76.0]:
  _fan(faces,[Vector3(24.5,1.0,z),Vector3(27.5,1.0,z),Vector3(27.5,5.0,z),Vector3(24.5,5.0,z)],"bank",false)
 # Close thin deck side fascia at its actual .30 thickness, not to trench bottom.
 for x in [24.5,27.5]:
  _fan(faces,[Vector3(x,5.0,71.425),Vector3(x,5.3,71.425),Vector3(x,5.3,76.575),Vector3(x,5.0,76.575)],"bone",false)
 # The clipped western bank has a real cut face beside the escape ramp.
 for iz in range(ZS.size()-1):
  var z0: float = ZS[iz]; var z1: float = ZS[iz+1]
  if z0 < 76:
   _fan(faces,[Vector3(20,5,z0),Vector3(20,5,z1),Vector3(20,_height("escape",z1),z1),Vector3(20,_height("escape",z0),z0)],"bank",false)
 _box(faces,Vector3(19.9,5,66.3),Vector3(20.1,6,76),"bone")
 _box(faces,Vector3(21.9,5,66.3),Vector3(22.1,6,72),"bone")
 # Bank-end walls, leaving the escape spillway continuous at its north mouth.
 _fan(faces,[Vector3(32,1.0,72),Vector3(32,5,72),Vector3(32,5,76),Vector3(32,1.0,76)],"bank",false)
 # Visible narrow parapets: omit approach and spillway openings. No passage-blocking box.
 for z in [72.0,76.0]:
  _box(faces,Vector3(22,5,z-.10),Vector3(24.5,6.0,z+.10),"bone")
  _box(faces,Vector3(27.5,5,z-.10),Vector3(32,6.0,z+.10),"bone")
 _box(faces,Vector3(31.9,5,72),Vector3(32.1,6,76),"bone")
 for x in [24.5,27.5]:
  _box(faces,Vector3(x-.075,5.3,72.2),Vector3(x+.075,6.3,75.8),"bone")
 # Short abutments link the existing corner pads and the new deck to bank foundations.
 for x in [24.06,27.94]:
  for z in [71.77,76.23]:
   _box(faces,Vector3(x-.22,1.0,z-.45),Vector3(x+.22,5.0,z+.45),"bone")
 # Narrow bearing tongues join the new central deck to the EXISTING corner pads.
 for z in [71.77,76.23]:
  _box(faces,Vector3(24.30,5.05,z-.12),Vector3(24.50,5.25,z+.12),"bone")
  _box(faces,Vector3(27.50,5.05,z-.12),Vector3(27.70,5.25,z+.12),"bone")
 return faces

static func _kind(x: float,z: float) -> String:
 if x >= 20 and x < 22 and z <= 76: return "escape"
 if x >= 24.5 and x <= 27.5:
  if z >= 71.425 and z <= 76.575: return "deck"
  if z >= 70.225 and z < 71.425: return "north"
  if z > 76.575 and z <= 77.775: return "south"
 if z >= 72 and z <= 76: return "bed"
 return "bank"

static func _height(kind: String,z: float) -> float:
 if kind == "deck": return 5.3
 if kind == "bed": return 1.0
 if kind == "escape": return 5.0-clampf((z-66.0)/8.0,0,1)*4.0
 if kind == "north": return 5.0+(z-70.225)*0.25
 if kind == "south": return 5.3-(z-76.575)*0.25
 return 5.0

static func _join(faces: Array,a: Vector3,b: Vector3,c: Vector3,d: Vector3) -> void:
 if a.distance_squared_to(c)+b.distance_squared_to(d) < 0.00000001: return
 # Deck edges are open above bed; do not make a bank wall through the hollow underneath.
 if minf(a.y,c.y) < 2.0 and maxf(a.y,c.y) > 5.2: return
 _fan(faces,[a,b,d,c],"bank",false)

static func _quad(faces: Array,x0: float,z0: float,x1: float,z1: float,y: float,mat: String,walk: bool,reverse: bool=false) -> void:
 var q = [Vector3(x0,y,z0),Vector3(x1,y,z0),Vector3(x1,y,z1),Vector3(x0,y,z1)]
 if reverse: q.reverse()
 _fan(faces,q,mat,walk)

static func _box(faces: Array,a: Vector3,b: Vector3,mat: String) -> void:
 var p = [Vector3(a.x,a.y,a.z),Vector3(b.x,a.y,a.z),Vector3(b.x,a.y,b.z),Vector3(a.x,a.y,b.z),Vector3(a.x,b.y,a.z),Vector3(b.x,b.y,a.z),Vector3(b.x,b.y,b.z),Vector3(a.x,b.y,b.z)]
 for ids in [[0,3,2,1],[4,5,6,7],[0,1,5,4],[1,2,6,5],[2,3,7,6],[3,0,4,7]]:
  _fan(faces,[p[ids[0]],p[ids[1]],p[ids[2]],p[ids[3]]],mat,false)

static func _fan(faces: Array,polygon: Array,mat: String,walk: bool) -> void:
 for i in range(1,polygon.size()-1):
  var tri: Array[Vector3] = [polygon[0],polygon[i],polygon[i+1]]
  if (tri[1]-tri[0]).cross(tri[2]-tri[0]).length_squared() > 0.000000000001:
   faces.append({"triangle":tri,"material":mat,"walkable":walk})

# Disjoint outside strips: preserve original sloped triangle interpolation exactly.
static func _outside(triangle: Array[Vector3]) -> Array:
 var remaining: Array = triangle
 var result: Array = []
 for plane in [[0,20.0,true],[0,32.0,false],[2,66.0,true],[2,78.0,false]]:
  var outside = _clip(remaining,plane[0],plane[1],plane[2])
  if outside.size() >= 3: result.append(outside)
  remaining = _clip(remaining,plane[0],plane[1],not plane[2])
  if remaining.is_empty(): break
 return result

static func _clip(poly: Array,axis: int,bound: float,less: bool) -> Array:
 var result: Array = []
 if poly.is_empty(): return result
 var prev: Vector3 = poly[-1]
 var pin: bool = prev[axis] <= bound if less else prev[axis] >= bound
 for curr: Vector3 in poly:
  var cin: bool = curr[axis] <= bound if less else curr[axis] >= bound
  if cin != pin:
   result.append(prev.lerp(curr,(bound-prev[axis])/(curr[axis]-prev[axis])))
  if cin: result.append(curr)
  prev=curr;pin=cin
 return result

# Exact Euclidean finite segment/triangle distance for migration capsule clearance.
static func segment_triangle_distance(a: Vector3,b: Vector3,t: Array) -> float:
 var n: Vector3 = (t[1]-t[0]).cross(t[2]-t[0])
 var denominator = n.dot(b-a)
 if absf(denominator) > 0.0000000001:
  var u: float = n.dot(t[0]-a)/denominator
  if u >= 0 and u <= 1:
   var hit: Vector3 = a+(b-a)*u
   if _closest_triangle(hit,t).distance_squared_to(hit) < 0.0000000001: return 0.0
 var distance = minf(a.distance_to(_closest_triangle(a,t)),b.distance_to(_closest_triangle(b,t)))
 for i in range(3):
  var pair = Geometry3D.get_closest_points_between_segments(a,b,t[i],t[(i+1)%3])
  distance = minf(distance,pair[0].distance_to(pair[1]))
 return distance

static func _closest_triangle(p: Vector3,t: Array) -> Vector3:
 var a: Vector3=t[0];var b: Vector3=t[1];var c: Vector3=t[2]
 var ab=b-a;var ac=c-a;var ap=p-a
 var d1=ab.dot(ap);var d2=ac.dot(ap)
 if d1 <= 0 and d2 <= 0:return a
 var bp=p-b;var d3=ab.dot(bp);var d4=ac.dot(bp)
 if d3 >= 0 and d4 <= d3:return b
 var vc=d1*d4-d3*d2
 if vc <= 0 and d1 >= 0 and d3 <= 0:return a+ab*(d1/(d1-d3))
 var cp=p-c;var d5=ab.dot(cp);var d6=ac.dot(cp)
 if d6 >= 0 and d5 <= d6:return c
 var vb=d5*d2-d1*d6
 if vb <= 0 and d2 >= 0 and d6 <= 0:return a+ac*(d2/(d2-d6))
 var va=d3*d6-d5*d4
 if va <= 0 and d4-d3 >= 0 and d5-d6 >= 0:return b+(c-b)*((d4-d3)/((d4-d3)+(d5-d6)))
 var inverse=1.0/(va+vb+vc)
 return a+ab*(vb*inverse)+ac*(vc*inverse)

# Pack-safe semantic guard. ARCH_SHA256 binds AUTHORING raw GLB, not an imported SCN's bytes.
# Standard exports can omit raw GLB. ResourceLoader resolves .glb.import to the packed scene.
# Fail closed for missing/wrong resources or changed arch geometry; never accept an empty hash.
static func validate_arch_resource() -> String:
 var resource = ResourceLoader.load("res://assets/art/world/ossuary_rib_bridge.glb")
 if not resource is PackedScene:return "rib arch: imported PackedScene unavailable"
 var root = resource.instantiate()
 if not root is Node3D:
  if root != null:root.free()
  return "rib arch: imported root must be Node3D"
 var pending:Array=[{"node":root,"transform":Transform3D.IDENTITY}]
 var triangles:Array=[]
 var mesh_count=0
 var node_count=0
 var bounds:AABB
 var error=""
 while not pending.is_empty() and error.is_empty():
  node_count+=1
  if node_count>32:error="rib arch: excessive imported hierarchy";break
  var item:Dictionary=pending.pop_back()
  var node:Node=item.node
  var pose:Transform3D=item.transform
  if node is CollisionObject3D or node is Camera3D or node is Light3D:
   error="rib arch: unexpected collision/camera/light in imported art";break
  if node is MeshInstance3D:
   mesh_count+=1
   if node.mesh==null or mesh_count>6:error="rib arch: invalid mesh count";break
   var box: AABB=pose*node.mesh.get_aabb()
   bounds=box if mesh_count==1 else bounds.merge(box)
   for surface in range(node.mesh.get_surface_count()):
    if node.mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES:error="rib arch: non-triangle surface";break
    var arrays:Array=node.mesh.surface_get_arrays(surface)
    if arrays.size()!=Mesh.ARRAY_MAX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array:error="rib arch: missing CPU vertex payload";break
    if arrays[Mesh.ARRAY_INDEX]!=null and not arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:error="rib arch: malformed index payload";break
    var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
    var indices:PackedInt32Array=PackedInt32Array() if arrays[Mesh.ARRAY_INDEX]==null else arrays[Mesh.ARRAY_INDEX]
    var count=vertices.size() if indices.is_empty() else indices.size()
    if count%3!=0 or triangles.size()+count/3>50000:error="rib arch: invalid or excessive triangle payload";break
    for i in range(0,count,3):
     var tri:Array[Vector3]=[]
     for j in range(3):
      var index=i+j if indices.is_empty() else indices[i+j]
      if index<0 or index>=vertices.size():error="rib arch: invalid triangle index";break
      var vertex:Vector3=pose*vertices[index]
      if not vertex.is_finite():error="rib arch: nonfinite vertex";break
      tri.append(vertex)
     if not error.is_empty():break
     triangles.append(tri)
  for child in node.get_children():
   if not child is Node3D:error="rib arch: unexpected imported node type";break
   pending.append({"node":child,"transform":pose*child.transform})
 root.free()
 if not error.is_empty():return error
 if mesh_count!=6:return "rib arch: expected six authored material meshes"
 if bounds.position.distance_to(Vector3(-2.320493,0,-2.575))>.01 or bounds.end.distance_to(Vector3(2.320493,7.001492,2.654563))>.01:return "rib arch: imported bounds differ from authored geometry"
 var centre_min:float=INF
 var centre_max:float=-INF
 var pads=[false,false,false,false]
 for t in triangles:
  var y=_triangle_y_at(Vector2.ZERO,t)
  if is_finite(y):centre_min=minf(centre_min,y);centre_max=maxf(centre_max,y)
  for i in range(4):
   var x=-1.94 if i<2 else 1.94
   var z=-2.23 if i%2==0 else 2.23
   var pad_y=_triangle_y_at(Vector2(x,z),t)
   if is_finite(pad_y) and absf(pad_y-.30)<.002:pads[i]=true
 if centre_min<6.25 or centre_min>6.35 or centre_max<6.65:return "rib arch: hollow centre/overhead ribs differ from authored geometry"
 if not pads.all(func(value):return value):return "rib arch: four separate corner pads missing"
 return ""

static func _triangle_y_at(point:Vector2,t:Array)->float:
 var a=Vector2(t[0].x,t[0].z);var b=Vector2(t[1].x,t[1].z);var c=Vector2(t[2].x,t[2].z)
 var d=(b-a).cross(c-a)
 if absf(d)<0.0000000001:return INF
 var u=(point-a).cross(c-a)/d;var v=(b-a).cross(point-a)/d
 if u<-.0000001 or v<-.0000001 or u+v>1.0000001:return INF
 return t[0].y+u*(t[1].y-t[0].y)+v*(t[2].y-t[0].y)
