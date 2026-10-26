extends SceneTree
# Read-only native bake diagnostic. Dumps polygon edge collisions without changing
# mesh, navigation settings, collision, endpoints, or publication behavior.
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
 var result: Dictionary = {"cell_size":routes.CELL_SIZE,"cell_height":routes.CELL_HEIGHT,"merge_scale":ProjectSettings.get_setting("navigation/3d/merge_rasterizer_cell_scale"),"roles":{}}
 for role in ["worker", "crawler"]:
  assert(routes.is_ready(role))
  var mesh: NavigationMesh = routes._roles[role].mesh
  var vertices: Array = []
  for v in mesh.get_vertices(): vertices.append([v.x, v.y, v.z])
  var polygons: Array = []
  for index in mesh.get_polygon_count(): polygons.append(Array(mesh.get_polygon(index)))
  result.roles[role] = {"vertices":vertices,"polygons":polygons,"map_cell_size":NavigationServer3D.map_get_cell_size(routes._roles[role].map),"map_cell_height":NavigationServer3D.map_get_cell_height(routes._roles[role].map),"map_merge_scale":NavigationServer3D.map_get_merge_rasterizer_cell_scale(routes._roles[role].map)}
 var path = "user://intake_nav_edge_diagnostic.json"
 var file = FileAccess.open(path, FileAccess.WRITE)
 assert(file != null)
 file.store_string(JSON.stringify(result))
 file.close()
 print("NAV_EDGE_DIAGNOSTIC=", ProjectSettings.globalize_path(path))
 host.level = null
 level.free()
 host.free()
 await physics_frame
 quit(0)
