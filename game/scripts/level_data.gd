extends RefCounted

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
	var b = height_at(tile+Vector2.RIGHT)
	var c = height_at(tile+Vector2.ONE)
	var d = height_at(tile+Vector2.DOWN)
	# Match the two actual floor triangles, including elevation-boundary cells.
	var height = a+(b-a)*uv.x+(c-b)*uv.y if uv.y <= uv.x else a+(c-d)*uv.x+(d-a)*uv.y
	return Vector3(point.x*data.cell_size,height,point.y*data.cell_size)

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
