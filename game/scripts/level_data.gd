extends RefCounted

const FILES = ["01_intake"]
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
	if cell.x >= 17 and cell.y <= 10:
		return clampf((cell.x - 17.0) / 3.0, 0.0, 2.0)
	if cell.x >= 20 and cell.y >= 10 and cell.y <= 18:
		return 2.0
	if cell.x >= 22 and cell.y >= 18:
		return clampf((24.0 - cell.y) / 3.0, 0.0, 2.0)
	return 0.0

func is_walkable(cell: Vector2i) -> bool:
	return tiles.has(cell)

func world_position(cell: Array) -> Vector3:
	return Vector3(cell[0] * data.cell_size, height_at(Vector2(cell[0], cell[1])), cell[1] * data.cell_size)
