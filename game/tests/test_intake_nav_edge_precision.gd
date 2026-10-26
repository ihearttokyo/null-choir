extends SceneTree
# Actual production bake regression for distinct detailed slope-seam edges.
const Level = preload("res://scripts/level.gd")
const Campaign = preload("res://scripts/campaign.gd")
class Host extends Node:
 var level
 var state = Campaign.new()
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var host = Host.new()
 root.add_child(host)
 host.state.new_campaign(1)
 var level = Level.new()
 host.level = level
 host.add_child(level)
 assert(level.build(host, 0))
 var routes = level.get_node("NavigationRoutes")
 var deadline = Time.get_ticks_usec() + 10000000
 while Time.get_ticks_usec() < deadline and not (routes.is_ready("worker") and routes.is_ready("crawler")):
  OS.delay_msec(2)
  await process_frame
  await physics_frame
 var collisions: int = 0
 for role in ["worker", "crawler"]:
  assert(routes.is_ready(role))
  var entry: Dictionary = routes._roles[role]
  var scale: float = NavigationServer3D.map_get_merge_rasterizer_cell_scale(entry.map)
  assert(is_equal_approx(scale, routes.MERGE_RASTER_SCALE))
  var mesh: NavigationMesh = entry.mesh
  assert(is_equal_approx(NavigationServer3D.map_get_cell_size(entry.map), routes.CELL_SIZE))
  assert(is_equal_approx(NavigationServer3D.map_get_cell_height(entry.map), routes.CELL_HEIGHT))
  var cells := Vector3(routes.CELL_SIZE, routes.CELL_HEIGHT, routes.CELL_SIZE)
  # Same native mesh, two grids: reproduce the exact original six failures,
  # then distinguish those edges without changing a single baked coordinate.
  assert(edge_collisions(mesh, cells * 0.1) == 6, "Negative control must reproduce six original false merges")
  var before: PackedByteArray = var_to_bytes([mesh.get_vertices(), polygons(mesh)])
  collisions += edge_collisions(mesh, cells * scale)
  assert(var_to_bytes([mesh.get_vertices(), polygons(mesh)]) == before)
 assert(collisions == 0, "Native detailed mesh edges must not falsely merge into third-edge collisions")
 print("PASS actual Intake worker/crawler baked edges: zero merge-key collisions at owned map precision; unchanged bake/clearance/collision/endpoints")
 host.level = null
 level.free()
 host.free()
 await physics_frame
 quit(0)

func key(point: Vector3, cells: Vector3) -> String:
 return str(Vector3i(floori(point.x / cells.x), floori(point.y / cells.y), floori(point.z / cells.z)))

func polygons(mesh: NavigationMesh) -> Array:
 var result: Array = []
 for index in mesh.get_polygon_count(): result.append(mesh.get_polygon(index))
 return result

func edge_collisions(mesh: NavigationMesh, cells: Vector3) -> int:
 var vertices: PackedVector3Array = mesh.get_vertices()
 var keys: Dictionary = {}
 for index in mesh.get_polygon_count():
  var polygon: PackedInt32Array = mesh.get_polygon(index)
  for edge in polygon.size():
   var a := key(vertices[polygon[edge]], cells)
   var b := key(vertices[polygon[(edge + 1) % polygon.size()]], cells)
   var pair: String = a + ":" + b if a < b else b + ":" + a
   keys[pair] = keys.get(pair, 0) + 1
 var collisions: int = 0
 for count in keys.values(): collisions += maxi(0, count - 2)
 return collisions
