extends RefCounted

const FILES = ["01_intake", "02_foundry", "03_processional"]
var data: Dictionary = {}
var tiles: Dictionary = {}

func load_level(index: int) -> bool:
	if index < 0 or index >= FILES.size():
		return false
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string("res://data/" + FILES[index] + ".json")) != OK:
		return false
	data = parser.data
	tiles.clear()
	for rect in data.rects:
		for x in range(rect[0], rect[2] + 1):
			for z in range(rect[1], rect[3] + 1):
				tiles[Vector2i(x,z)] = true
	return true

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
	return Vector3(cell[0] * data.cell_size, height_at(Vector2(cell[0], cell[1])), cell[1] * data.cell_size)
