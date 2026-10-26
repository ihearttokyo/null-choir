extends RefCounted

const OssuarySurfaces = preload("res://scripts/ossuary_surfaces_v3.gd")
var _surface_cache: Array = []
var _surface_bins: Dictionary = {}

const RevisionOneFloors = preload("res://scripts/floors_v1.gd")
const OriginalFloors = preload("res://scripts/floors_v0.gd")
const Schema = preload("res://scripts/level_schema.gd")
const FILES = ["01_intake", "02_foundry", "03_processional", "04_reliquary", "05_nursery", "06_ossuary", "07_inversion", "08_heart"]
var data: Dictionary = {}
var tiles: Dictionary = {}
var load_error: String = ""

func load_level(index: int) -> bool:
	load_error = ""
	_surface_cache.clear()
	_surface_bins.clear()
	if index < 0 or index >= FILES.size():
		load_error = "level index "+str(index)+": expected 0.."+str(FILES.size()-1)
		return false
	var path: String = "res://data/"+FILES[index]+".json"
	var file = FileAccess.open(path,FileAccess.READ)
	if file == null:
		load_error = path+": cannot open level source ("+error_string(FileAccess.get_open_error())+")"
		return false
	var content: String = file.get_as_text()
	file.close()
	var parser = JSON.new()
	if parser.parse(content) != OK:
		load_error = path+": JSON line "+str(parser.get_error_line())+": "+parser.get_error_message()
		return false
	var validation: String = Schema.validate(parser.data,_art_exists)
	if not validation.is_empty():
		load_error = path+": "+validation
		return false
	if OssuarySurfaces.enabled(parser.data):
		var arch_error: String = OssuarySurfaces.validate_arch_resource()
		if not arch_error.is_empty():
			load_error = path+": "+arch_error
			return false
	var expanded: Dictionary = {}
	for rect in parser.data.rects:
		for x in range(rect[0], rect[2] + 1):
			for z in range(rect[1], rect[3] + 1):
				expanded[Vector2i(x,z)] = true
	data = parser.data
	tiles = expanded
	return true

func _art_exists(id: String) -> bool:
	return ResourceLoader.exists("res://assets/art/world/"+id+".glb")

func height_at(cell: Vector2) -> float:
	for region in data.elevations:
		var r = region.rect
		if cell.x < r[0] or cell.y < r[1] or cell.x > r[2] or cell.y > r[3]: continue
		if region.has("axis"):
			return clampf((cell[int(region.axis)]-region.start)/(region.end-region.start),0.0,1.0)*region.height
		return region.height
	return 0.0

func roof_height(cell: Vector2i) -> float:
	for region in data.ceilings:
		var r = region.rect
		if cell.x >= r[0] and cell.y >= r[1] and cell.x <= r[2] and cell.y <= r[3]: return region.height
	return 6.0

func is_walkable(cell: Vector2i) -> bool:
	return tiles.has(cell)

func surface_faces() -> Array:
	if _surface_cache.is_empty():
		_surface_cache = OssuarySurfaces.build(self)
		_surface_bins.clear()
		for index in range(_surface_cache.size()):
			var t: Array = _surface_cache[index].triangle
			var low=Vector2(minf(t[0].x,minf(t[1].x,t[2].x)),minf(t[0].z,minf(t[1].z,t[2].z)))
			var high=Vector2(maxf(t[0].x,maxf(t[1].x,t[2].x)),maxf(t[0].z,maxf(t[1].z,t[2].z)))
			_surface_cache[index].bounds_xz=Rect2(low,high-low)
			for x in range(floori(low.x/4.0),floori(high.x/4.0)+1):
				for z in range(floori(low.y/4.0),floori(high.y/4.0)+1):
					var key=Vector2i(x,z)
					if not _surface_bins.has(key):_surface_bins[key]=[]
					_surface_bins[key].append(index)
	return _surface_cache

func _query_hits_patch(center:Vector2,radius:float=0.0)->bool:
	var rect:Rect2=OssuarySurfaces.CUT
	var nearest=Vector2(clampf(center.x,rect.position.x,rect.end.x),clampf(center.y,rect.position.y,rect.end.y))
	return center.distance_squared_to(nearest)<=radius*radius

func _surface_candidates(center:Vector2,radius:float)->Array:
	surface_faces()
	var indices:Dictionary={}
	for x in range(floori((center.x-radius)/4.0),floori((center.x+radius)/4.0)+1):
		for z in range(floori((center.y-radius)/4.0),floori((center.y+radius)/4.0)+1):
			for index in _surface_bins.get(Vector2i(x,z),[]):indices[index]=true
	var result:Array=[]
	for index in indices:
		var face:Dictionary=_surface_cache[index]
		var rect:Rect2=face.bounds_xz
		var nearest=Vector2(clampf(center.x,rect.position.x,rect.end.x),clampf(center.y,rect.position.y,rect.end.y))
		if center.distance_squared_to(nearest)<=radius*radius:result.append(face)
	return result

func _surface_height(point: Vector2, reference_y: float = INF) -> float:
	var result: float = -INF
	for face in _surface_candidates(point,0.0):
		if not face.walkable: continue
		var t: Array = face.triangle
		var a = Vector2(t[0].x,t[0].z)
		var b = Vector2(t[1].x,t[1].z)
		var c = Vector2(t[2].x,t[2].z)
		var determinant: float = (b-a).cross(c-a)
		if absf(determinant) < 0.0000000001: continue
		var u: float = (point-a).cross(c-a)/determinant
		var v: float = (b-a).cross(point-a)/determinant
		if u >= -0.0000001 and v >= -0.0000001 and u+v <= 1.0000001:
			var y: float = t[0].y+u*(t[1].y-t[0].y)+v*(t[2].y-t[0].y)
			if y <= reference_y+0.003: result = maxf(result,y)
	return result

func world_position(cell: Array) -> Vector3:
	if OssuarySurfaces.enabled(data) and _query_hits_patch(Vector2(cell[0],cell[1])*float(data.cell_size)):
		var point = Vector2(cell[0],cell[1])*float(data.cell_size)
		return Vector3(point.x,_surface_height(point),point.y)
	var point = Vector2(cell[0],cell[1])
	var tile = point.floor()
	var uv = point-tile
	var a = height_at(tile)
	var b = height_at(tile+Vector2.RIGHT) if uv.y <= uv.x else 0.0
	var c = height_at(tile+Vector2.ONE)
	var d = 0.0 if uv.y <= uv.x else height_at(tile+Vector2.DOWN)
	# Match the two actual floor triangles, including elevation-boundary cells.
	var height = a+(b-a)*uv.x+(c-b)*uv.y if uv.y <= uv.x else a+(c-d)*uv.x+(d-a)*uv.y
	return Vector3(point.x*data.cell_size,height,point.y*data.cell_size)

# Minimum actor foot Y supported by the lower capsule sphere over actual floor triangles.
func capsule_floor_support(center: Vector2, radius: float) -> float:
	var support: float = -INF
	if OssuarySurfaces.enabled(data) and _query_hits_patch(center,radius):
		for face in _surface_candidates(center,radius):
			if not face.walkable: continue
			var t: Array = face.triangle
			var shift = Vector3(center.x,0,center.y)
			support = maxf(support,_capsule_triangle_support(radius,t[0]-shift,t[1]-shift,t[2]-shift))
		return support
	var size: float = data.cell_size
	var low = (center-Vector2.ONE*radius)/size
	var high = (center+Vector2.ONE*radius)/size
	# Scan bounded authored tiles, not an unbounded range if a map uses tiny cells.
	for tile in tiles:
		if tile.x+1 < low.x or tile.x > high.x or tile.y+1 < low.y or tile.y > high.y: continue
		var corners: Array[Vector3] = []
		for offset in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]:
			var cell = Vector2(tile)+offset
			corners.append(Vector3(cell.x*size-center.x,height_at(cell),cell.y*size-center.y))
		# Same diagonal and corners as Level._build_geometry; no floor outside walkable tiles.
		for indices in [[0,1,2],[0,2,3]]:
			support = maxf(support,_capsule_triangle_support(radius,corners[indices[0]],corners[indices[1]],corners[indices[2]]))
	return support

func _capsule_triangle_support(radius: float, a: Vector3, b: Vector3, c: Vector3) -> float:
	var normal = (b-a).cross(c-a)
	var gradient = Vector2(-normal.x,-normal.z)/normal.y
	var optimum = radius*gradient/sqrt(1.0+gradient.length_squared())
	var vertices = [a,b,c]
	var positive: bool = false
	var negative: bool = false
	for i in range(3):
		var start = Vector2(vertices[i].x,vertices[i].z)
		var end = Vector2(vertices[(i+1)%3].x,vertices[(i+1)%3].z)
		var side = (end-start).cross(optimum-start)
		positive = positive or side > 0.0
		negative = negative or side < -0.0
	var support: float = -INF
	if not (positive and negative):
		support = a.y+gradient.dot(optimum-Vector2(a.x,a.z))-radius+sqrt(maxf(0.0,radius*radius-optimum.length_squared()))
	for i in range(3):
		var start: Vector3 = vertices[i]
		var end: Vector3 = vertices[(i+1)%3]
		var offset = Vector2(start.x,start.z)
		var edge = Vector2(end.x-start.x,end.z-start.z)
		var length = edge.length()
		var direction = edge/length
		var along = -offset.dot(direction)
		var perpendicular = offset.cross(direction)
		var perpendicular_sq = perpendicular*perpendicular
		if perpendicular_sq > radius*radius: continue
		var reach = sqrt(maxf(0.0,radius*radius-perpendicular_sq))
		var low = maxf(-reach,-along)
		var high = minf(reach,length-along)
		if low > high: continue
		var slope = (end.y-start.y)/length
		var u = clampf(reach*slope/sqrt(1.0+slope*slope),low,high)
		var point = offset+direction*(along+u)
		var height = start.y+slope*(along+u)-radius+sqrt(maxf(0.0,radius*radius-point.length_squared()))
		support = maxf(support,height)
	return support

func floor_revision() -> int:
	return int(data.get("floor_revision",0))

func original_floor(index: int):
	var original = get_script().new()
	original.data = data.duplicate(true)
	original._erase_v3_metadata()
	original.data.merge(OriginalFloors.LEVELS[index].duplicate(true),true)
	original.data.floor_revision = 0
	for rect in original.data.rects:
		for x in range(rect[0],rect[2]+1):
			for z in range(rect[1],rect[3]+1):
				original.tiles[Vector2i(x,z)] = true
	return original

# Resolve the actual saved terrain, never treat revision one as the v0 floor.
func floor_at_revision(index: int, revision: int):
	if revision == floor_revision(): return self
	if revision == 0: return original_floor(index)
	if revision == 2 and index == 5:
		var file = FileAccess.open("res://data/floors/revision2/ossuary.json",FileAccess.READ)
		if file == null: return null
		var frozen = JSON.parse_string(file.get_as_text())
		file.close()
		if not frozen is Dictionary or frozen.get("id") != "ossuary" or frozen.get("floor_revision") != 2 or frozen.has("terrain_patch"): return null
		var old = get_script().new()
		old.data = frozen
		for rect in old.data.rects:
			for x in range(rect[0],rect[2]+1):
				for z in range(rect[1],rect[3]+1): old.tiles[Vector2i(x,z)] = true
		return old
	if index < 0 or index >= FILES.size() or revision != 1: return null
	var terrain: Dictionary
	if index == 0: terrain = RevisionOneFloors.INTAKE
	elif index == 1: terrain = RevisionOneFloors.FOUNDRY
	else:
		# Other authored revision-one baselines are immutable terrain-only JSON.
		# Load lazily for save migration; never infer v1 from the altered v2 floor.
		var path: String = "res://data/floors/revision1/"+FILES[index].substr(3)+".json"
		var file = FileAccess.open(path,FileAccess.READ)
		if file == null: return null
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if not parsed is Dictionary or parsed.get("floor_revision") != 1 or parsed.get("cell_size") != data.cell_size: return null
		for field in ["rects","elevations","ceilings"]:
			if not parsed.get(field) is Array: return null
		terrain = parsed
	var prior = get_script().new()
	prior.data = data.duplicate(true)
	prior._erase_v3_metadata()
	prior.data.merge(terrain.duplicate(true),true)
	for rect in prior.data.rects:
		for x in range(rect[0],rect[2]+1):
			for z in range(rect[1],rect[3]+1): prior.tiles[Vector2i(x,z)] = true
	return prior

# Pure, conservative geometry validation. Never grants progress or performs recovery.
# Caller supplies this snapshot's already-validated removed IDs. Only known open doors skip collision.
func migration_capsule_clearance(point: Vector3,radius: float,height: float,capsule_foot_offset: float = 0.0,removed: Array = [],floor_penetration: float = 0.0) -> bool:
	if not OssuarySurfaces.enabled(data): return false
	if not point.is_finite() or not is_finite(radius) or not is_finite(height) or radius <= 0 or height < radius*2 or not is_finite(capsule_foot_offset): return false
	if not is_finite(floor_penetration) or floor_penetration < 0 or floor_penetration > .08: return false
	var physical_foot_y=point.y+capsule_foot_offset
	var support = capsule_floor_support_at_y(Vector2(point.x,point.z),radius,physical_foot_y,floor_penetration)
	if not is_finite(support) or physical_foot_y < support-floor_penetration-0.003: return false
	var a=point+Vector3.UP*(capsule_foot_offset+radius)
	var b=point+Vector3.UP*(capsule_foot_offset+height-radius)
	for face in _surface_candidates(Vector2(point.x,point.z),radius):
		if OssuarySurfaces.segment_triangle_distance(a,b,face.triangle) < radius-0.003:
			# Only an actual contributing WALKABLE support face gets the caller's existing
			# signed-floor trust. Rails/walls/undersides/roofs/doors never use this allowance.
			var floor_contact=false
			if face.walkable and floor_penetration > 0:
				var t:Array=face.triangle
				var shift=Vector3(point.x,0,point.z)
				var face_support=_capsule_triangle_support(radius,t[0]-shift,t[1]-shift,t[2]-shift)
				floor_contact=is_finite(face_support) and face_support >= physical_foot_y-.003 and face_support <= support+.003 and physical_foot_y >= face_support-floor_penetration-.003
			if not floor_contact:return false
	# Room roofs remain anchored to the original bank mesh, not the patch/deck height.
	var size:float=data.cell_size
	var reach=radius+0.14
	for x in range(floori((point.x-reach)/size),floori((point.x+reach)/size)+1):
		for z in range(floori((point.z-reach)/size),floori((point.z+reach)/size)+1):
			var nearest=Vector2(clampf(point.x,x*size,(x+1)*size),clampf(point.z,z*size,(z+1)*size))
			if nearest.distance_to(Vector2(point.x,point.z)) > reach: continue
			var tile=Vector2i(x,z)
			if not is_walkable(tile): return false
			var corners:Array[Vector3]=[]
			for offset in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]:
				var p=Vector2(tile)+offset
				corners.append(Vector3(p.x*size,height_at(p)+roof_height(tile),p.y*size))
			for ids in [[0,2,1],[0,3,2]]:
				if OssuarySurfaces.segment_triangle_distance(a,b,[corners[ids[0]],corners[ids[1]],corners[ids[2]]]) < radius-0.003:return false
	for group in ["heroes","scenery","doors"]:
		for spec in data[group]:
			if group == "doors" and spec.id in removed:continue
			var anchor=world_position(spec.cell)+Vector3.UP*spec.get("height",0.0)
			var dimensions:Array=spec.get("base",spec.get("solid",spec.get("size",[])))
			if not dimensions.is_empty():
				var d=Vector3(dimensions[0],dimensions[1],dimensions[2])
				if group == "heroes" and spec.get("round",false):
					var horizontal=maxf(Vector2(a.x-anchor.x,a.z-anchor.z).length()-d.x/2,0)
					var vertical=maxf(maxf(anchor.y-b.y,a.y-(anchor.y+d.y)),0)
					if horizontal*horizontal+vertical*vertical < (radius-0.003)*(radius-0.003):return false
				elif _capsule_box_overlap(a,b,radius,anchor+Vector3.UP*d.y/2,d,deg_to_rad(spec.get("yaw",0))):return false
			for support_spec in spec.get("supports",[]):
				var scales:Array=spec.get("scale",[1,1,1])
				var scale3=Vector3(scales[0],scales[1],scales[2])
				var d=Vector3(support_spec.size[0],support_spec.size[1],support_spec.size[2])*scale3
				var offset=Vector3(support_spec.offset[0],support_spec.offset[1],support_spec.offset[2])*scale3
				var yaw=deg_to_rad(spec.get("yaw",0))
				if _capsule_box_overlap(a,b,radius,anchor+offset.rotated(Vector3.UP,yaw)+Vector3.UP*d.y/2,d,yaw):return false
	return true

func _capsule_box_overlap(a:Vector3,b:Vector3,radius:float,center:Vector3,size:Vector3,yaw:float)->bool:
	var p=(a-center).rotated(Vector3.UP,-yaw)
	var q=(b-center).rotated(Vector3.UP,-yaw)
	var half=size/2
	var dx=maxf(absf(p.x)-half.x,0)
	var dz=maxf(absf(p.z)-half.z,0)
	var dy=maxf(maxf(-half.y-q.y,p.y-half.y),0)
	return dx*dx+dy*dy+dz*dz < (radius-0.003)*(radius-0.003)

# Height hint is mandatory for a physically existing actor below the deck. Default authored
# world_position/capsule_floor_support intentionally select the upper route for placement.
func surface_position_at_y(cell: Array,reference_y: float) -> Vector3:
	if not OssuarySurfaces.enabled(data) or not _query_hits_patch(Vector2(cell[0],cell[1])*float(data.cell_size)): return world_position(cell)
	var xz=Vector2(cell[0],cell[1])*float(data.cell_size)
	return Vector3(xz.x,_surface_height(xz,reference_y),xz.y)

func capsule_floor_support_at_y(center:Vector2,radius:float,reference_y:float,floor_penetration:float=0.0)->float:
	if not OssuarySurfaces.enabled(data) or not _query_hits_patch(center,radius):return capsule_floor_support(center,radius)
	var support:float=-INF
	for face in _surface_candidates(center,radius):
		if not face.walkable:continue
		var t:Array=face.triangle
		var shift=Vector3(center.x,0,center.y)
		var y=_capsule_triangle_support(radius,t[0]-shift,t[1]-shift,t[2]-shift)
		if y <= reference_y+floor_penetration+0.003:support=maxf(support,y)
	return support

func _erase_v3_metadata() -> void:
	if not data.has("terrain_patch"):return
	data.erase("terrain_patch")
	for hero in data.get("heroes",[]):
		if hero.get("id","") == "ossuary_rib_bridge":hero.erase("height")

# Caller may localize the NEW V3 guard while retaining all old validation outside.
# Bounds include the .10m bank-parapet extensions, not a generic obstacle exclusion.
func migration_patch_overlap(center:Vector2,radius:float)->bool:
	if not OssuarySurfaces.enabled(data) or not center.is_finite() or not is_finite(radius) or radius<0:return false
	var changed=Rect2(19.9,66.0,12.2,12.0)
	var closest=Vector2(clampf(center.x,changed.position.x,changed.end.x),clampf(center.y,changed.position.y,changed.end.y))
	return center.distance_squared_to(closest)<=radius*radius
