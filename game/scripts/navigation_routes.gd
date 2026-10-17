extends Node3D

# Geometry/path owner only. The actor retains native movement, AI and collision.
# Official API: docs.godotengine.org/en/stable/classes/class_navigationserver3d.html
signal readiness_changed(profile: String, revision: int, ready: bool)

const CELL_SIZE := .15
const CELL_HEIGHT := .05
const MAX_PROFILES := 8
const MAX_TILES := 4096
const MAX_SOURCE_COORDINATES := 1500000
const MAX_VOXEL_COLUMNS := 4000000
const SYNC_TIMEOUT_US := 2000000
const ENDPOINT_TOLERANCE := .25
const MAX_QUERIES_PER_TICK := 40
var revision := 0
var _level: Node3D
var _group: StringName
var _roles: Dictionary = {}
var _source: NavigationMeshSourceGeometryData3D
var _pending: Array[String] = []
var _baking: Dictionary = {}
var _dirty := false
var _query_tick := -1
var _queries := 0

# profiles: role -> {radius, height, hover}; hover is the maximum feet offset.
# All coordinates are global; attach this node directly to the current Level.
func configure(level: Node3D, profiles: Dictionary) -> bool:
	teardown()
	if not is_instance_valid(level) or level.is_queued_for_deletion() or not level.is_inside_tree() or get_parent() != level or profiles.is_empty() or profiles.size() > MAX_PROFILES: return false
	if level.layout.tiles.is_empty() or level.layout.tiles.size() > MAX_TILES: return false
	for role in profiles:
		if not role is String or role.is_empty() or not profiles[role] is Dictionary: return false
		var p: Dictionary = profiles[role]
		for key in ["radius","height","hover"]:
			if not (p.get(key) is float or p.get(key) is int) or not is_finite(float(p[key])): return false
		if p.radius <= 0 or p.radius > 4 or p.height < p.radius*2 or p.height > 12 or p.hover < 0 or p.hover > 4: return false
	_level = level
	if not _current_owner():
		_level = null
		return false
	_group = StringName("navigation_owner_"+str(get_instance_id()))
	_level.add_to_group(_group)
	for role in profiles:
		var map := NavigationServer3D.map_create()
		NavigationServer3D.map_set_cell_size(map,CELL_SIZE)
		NavigationServer3D.map_set_cell_height(map,CELL_HEIGHT)
		NavigationServer3D.map_set_active(map,true)
		var region := NavigationServer3D.region_create()
		# Keep initial/replacement geometry publication ordered; map updates stay async.
		NavigationServer3D.region_set_use_async_iterations(region,false)
		NavigationServer3D.region_set_map(region,map)
		NavigationServer3D.region_set_navigation_layers(region,1)
		NavigationServer3D.region_set_use_edge_connections(region,false)
		_roles[role] = {"profile":profiles[role].duplicate(),"map":map,"region":region,"mesh":null,"ready":false,"sync":false,"version":0,"sync_started_us":0,"witness":Vector3.ZERO}
	var configured_revision := revision+1
	invalidate_doors()
	if not _current_owner() or revision != configured_revision: return false
	set_process(true)
	set_physics_process(true)
	return true

func _current_owner() -> bool:
	return not is_queued_for_deletion() and is_instance_valid(_level) and not _level.is_queued_for_deletion() and _level.is_inside_tree() and get_parent() == _level and is_instance_valid(_level.game) and not _level.game.is_queued_for_deletion() and _level.game.level == _level

func is_ready(profile: String) -> bool:
	return _current_owner() and not _dirty and _roles.has(profile) and _roles[profile].ready

func invalidate_doors() -> void:
	if not _current_owner() or _dirty: return
	revision += 1
	_dirty = true
	_pending.clear()
	for role in _roles:
		var entry: Dictionary = _roles[role]
		entry.ready = false
		entry.sync = false
		NavigationServer3D.region_set_enabled(entry.region,false)
	for role in _roles.keys():
		var notified_revision := revision
		readiness_changed.emit(role,notified_revision,false)
		if not _current_owner() or revision != notified_revision: return

func _process(_delta: float) -> void:
	if not _current_owner():
		teardown()
		return
	if _baking.is_empty():
		if _dirty:
			_parse_geometry()
			return
		if _pending.is_empty(): return
		var next_role: String = _pending.pop_front()
		# One role/source job at a time; publication always requires a later tick.
		_baking = {"role":next_role,"revision":revision,"mesh":_mesh_for(_roles[next_role].profile),"source":_source}
		NavigationServer3D.bake_from_source_geometry_data_async(_baking.mesh,_baking.source)
		return
	if NavigationServer3D.is_baking_navigation_mesh(_baking.mesh): return
	var completed: Dictionary = _baking
	_baking = {}
	if _dirty or completed.revision != revision: return
	var entry: Dictionary = _roles[completed.role]
	var mesh: NavigationMesh = completed.mesh
	entry.mesh = mesh
	entry.version = NavigationServer3D.map_get_iteration_id(entry.map)
	entry.sync_started_us = Time.get_ticks_usec()
	entry.sync = mesh.get_polygon_count() > 0
	NavigationServer3D.region_set_transform(entry.region,_level.global_transform)
	NavigationServer3D.region_set_navigation_mesh(entry.region,mesh)
	NavigationServer3D.region_set_enabled(entry.region,entry.sync)
	if entry.sync:
		var vertices: PackedVector3Array = mesh.get_vertices()
		var polygon: PackedInt32Array = mesh.get_polygon(0)
		var witness := Vector3.ZERO
		for index in polygon: witness += vertices[index]
		entry.witness = _level.global_transform*(witness/polygon.size())

func _mesh_for(profile: Dictionary) -> NavigationMesh:
	var mesh := NavigationMesh.new()
	mesh.cell_size = CELL_SIZE
	mesh.cell_height = CELL_HEIGHT
	# Recast rounds clearance upwards; .42 radius becomes .45, never smaller.
	mesh.agent_radius = ceilf((float(profile.radius)+.001)/CELL_SIZE)*CELL_SIZE
	mesh.agent_height = ceilf((float(profile.height)+float(profile.hover)+.03)/CELL_HEIGHT)*CELL_HEIGHT
	mesh.agent_max_climb = .2
	mesh.agent_max_slope = 28
	mesh.filter_ledge_spans = true
	mesh.filter_walkable_low_height_spans = true
	mesh.edge_max_error = .1
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	mesh.geometry_source_group_name = _group
	return mesh

func _parse_geometry() -> void:
	_source = NavigationMeshSourceGeometryData3D.new()
	var parser_mesh := _mesh_for(_roles.values()[0].profile)
	# _process runs on the main thread. Unique group contains only this Level.
	NavigationServer3D.parse_source_geometry_data(parser_mesh,_source,_level)
	# Roofs have no native collider. Reuse the exact Level clockwise triangle recipe.
	var layout = _level.layout
	var size: float = layout.data.cell_size
	var roofs := PackedVector3Array()
	for cell in layout.tiles:
		var corners: Array[Vector3] = []
		for offset in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]:
			var point: Vector2 = Vector2(cell)+offset
			corners.append(Vector3(point.x*size,layout.height_at(point)+layout.roof_height(cell),point.y*size))
		for index in [0,2,1,0,3,2]: roofs.append(corners[index])
	_source.add_faces(roofs,_level.global_transform)
	var bounds := _source.get_bounds()
	if not _source.has_data() or _source.get_vertices().size() > MAX_SOURCE_COORDINATES or not bounds.position.is_finite() or not bounds.size.is_finite() or bounds.size.y > 64 or ceilf(bounds.size.x/CELL_SIZE)*ceilf(bounds.size.z/CELL_SIZE) > MAX_VOXEL_COLUMNS:
		push_warning("Navigation source exceeds the per-level geometry budget")
		teardown()
		return
	if not _current_owner():
		teardown()
		return
	_dirty = false
	for role in _roles: _pending.append(role)

func _physics_process(_delta: float) -> void:
	if not _current_owner():
		teardown()
		return
	var notified_revision := revision
	for role in _roles.keys():
		var entry: Dictionary = _roles[role]
		if not entry.sync: continue
		var version: int = NavigationServer3D.map_get_iteration_id(entry.map)
		# A first nonzero iteration alone is not mesh-publication evidence.
		if version != entry.version and version > 0 and NavigationServer3D.map_get_regions(entry.map).has(entry.region) and NavigationServer3D.map_get_closest_point_owner(entry.map,entry.witness) == entry.region and NavigationServer3D.map_get_closest_point(entry.map,entry.witness).distance_to(entry.witness) < .01 and not NavigationServer3D.map_get_path(entry.map,entry.witness,entry.witness,true,1).is_empty():
			entry.sync = false
			entry.ready = true
			readiness_changed.emit(role,notified_revision,true)
			if not _current_owner() or revision != notified_revision or _dirty: return
		elif Time.get_ticks_usec()-entry.sync_started_us >= SYNC_TIMEOUT_US:
			entry.sync = false
			NavigationServer3D.region_set_enabled(entry.region,false)
			push_warning("Navigation synchronization timed out for "+role)

# Inputs/outputs are world floor anchors, not actor hover positions. AI owns feet Y.
# Empty means not ready, invalid endpoint, or unreachable: never a fallback search.
func route(start: Vector3, goal: Vector3, profile: String, goal_tolerance: float = ENDPOINT_TOLERANCE) -> PackedVector3Array:
	if not start.is_finite() or not goal.is_finite() or not is_finite(goal_tolerance) or goal_tolerance < ENDPOINT_TOLERANCE or goal_tolerance > 6 or not is_ready(profile): return PackedVector3Array()
	var tick: int = Engine.get_physics_frames()
	if tick != _query_tick:
		_query_tick = tick
		_queries = 0
	if _queries >= MAX_QUERIES_PER_TICK: return PackedVector3Array()
	_queries += 1
	var entry: Dictionary = _roles[profile]
	var closest_start: Vector3 = NavigationServer3D.map_get_closest_point(entry.map,start)
	var closest_goal: Vector3 = NavigationServer3D.map_get_closest_point(entry.map,goal)
	if closest_start.distance_to(start) > ENDPOINT_TOLERANCE or closest_goal.distance_to(goal) > goal_tolerance: return PackedVector3Array()
	var path := NavigationServer3D.map_get_path(entry.map,closest_start,closest_goal,true,1)
	if path.is_empty() or path[-1].distance_to(closest_goal) > .01: return PackedVector3Array()
	for index in range(path.size()): path[index] += Vector3.UP*.03
	return path

func teardown() -> void:
	set_process(false)
	set_physics_process(false)
	_dirty = false
	_pending.clear()
	_baking.clear()
	for entry in _roles.values():
		NavigationServer3D.region_set_map(entry.region,RID())
		NavigationServer3D.free_rid(entry.region)
		NavigationServer3D.map_set_active(entry.map,false)
		NavigationServer3D.free_rid(entry.map)
	_roles.clear()
	_source = null
	if is_instance_valid(_level) and not _group.is_empty(): _level.remove_from_group(_group)
	_level = null
	_group = &""

func _exit_tree() -> void:
	teardown()
