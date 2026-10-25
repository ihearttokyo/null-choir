extends RefCounted

const RevisionOneFloors = preload("res://scripts/floors_v1.gd")
const OriginalFloors = preload("res://scripts/floors_v0.gd")
const Schema = preload("res://scripts/level_schema.gd")
const FILES = ["01_intake", "02_foundry", "03_processional", "04_reliquary", "05_nursery", "06_ossuary", "07_inversion", "08_heart"]
var data: Dictionary = {}
var tiles: Dictionary = {}
var load_error: String = ""

func load_level(index: int) -> bool:
	load_error = ""
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

func world_position(cell: Array) -> Vector3:
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
	original.data.merge(OriginalFloors.LEVELS[index].duplicate(true),true)
	for rect in original.data.rects:
		for x in range(rect[0],rect[2]+1):
			for z in range(rect[1],rect[3]+1):
				original.tiles[Vector2i(x,z)] = true
	return original

# Resolve the actual saved terrain, never treat revision one as the v0 floor.
func floor_at_revision(index: int, revision: int):
	if revision == floor_revision(): return self
	if revision == 0: return original_floor(index)
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
	prior.data.merge(terrain.duplicate(true),true)
	for rect in prior.data.rects:
		for x in range(rect[0],rect[2]+1):
			for z in range(rect[1],rect[3]+1): prior.tiles[Vector2i(x,z)] = true
	return prior
