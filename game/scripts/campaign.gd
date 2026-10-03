extends RefCounted

const VERSION = 1
const SAVE_PATH = "user://campaign.json"

var difficulty: int = 1
var level_index: int = 0
var health: int = 100
var armor: int = 0
var ammo: Array = [0, 90, 0, 0, 0, 0]
var owned_weapons: Array = [0, 1]
var weapon: int = 1
var keys: Array = []
var discoveries: Array = []
var removed: Array = []
var explored: Array = []
var checkpoint_id: String = "entry"
var position: Vector3 = Vector3.ZERO
var checkpoint: Dictionary = {}
var level_start: Dictionary = {}

func new_campaign(mode: int) -> void:
	difficulty = clampi(mode, 0, 2)
	level_index = 0
	health = 100
	armor = 0
	ammo = [0, 90, 0, 0, 0, 0]
	owned_weapons = [0, 1]
	weapon = 1
	keys = []
	discoveries = []
	removed = []
	explored = []
	mark_checkpoint("entry", Vector3.ZERO)

func damage(amount: int) -> void:
	amount = maxi(0, amount)
	var absorbed = mini(armor, amount / 3)
	armor -= absorbed
	health = maxi(0, health - (amount - absorbed))

func discover(index: int) -> void:
	if index >= 0 and index < 8 and not index in discoveries:
		discoveries.append(index)
		discoveries.sort()

func mark_checkpoint(id: String, location: Vector3) -> void:
	checkpoint_id = id
	position = location
	checkpoint = _resources()
	if id == "entry": level_start = checkpoint.duplicate(true)

func restore_checkpoint() -> void:
	if not checkpoint.is_empty():
		_apply_resources(checkpoint)

func restore_level_start() -> void:
	if not level_start.is_empty():
		_apply_resources(level_start)
		checkpoint = level_start.duplicate(true)

func complete_level() -> void:
	level_index = mini(8, level_index + 1)
	keys = []
	removed = []
	explored = []
	mark_checkpoint("entry", Vector3.ZERO)

func _resources() -> Dictionary:
	return {"health": health, "armor": armor, "ammo": ammo.duplicate(),
		"owned_weapons": owned_weapons.duplicate(), "weapon": weapon,
		"keys": keys.duplicate(), "removed": removed.duplicate(),
		"checkpoint_id": checkpoint_id, "position": [position.x, position.y, position.z]}

func to_dict() -> Dictionary:
	var data = _resources()
	data.merge({"version": VERSION, "difficulty": difficulty, "level_index": level_index,
		"discoveries": discoveries.duplicate(), "explored": explored.duplicate(true), "checkpoint": checkpoint.duplicate(true),
		"level_start": level_start.duplicate(true)})
	return data

func from_dict(data: Dictionary) -> bool:
	# Validate everything before changing live state. Saves are an untrusted boundary.
	if not _integer(data.get("version"), VERSION, VERSION) or not _integer(data.get("difficulty"), 0, 2):
		return false
	if not _integer(data.get("level_index"), 0, 8) or not _valid_resources(data):
		return false
	var cells = data.get("explored",[])
	if not cells is Array or cells.size() > 4096: return false
	var normalized: Array = []
	for cell in cells:
		if not cell is Array or cell.size() != 2 or not _integers(cell,0,255,2): return false
		var point = [int(cell[0]),int(cell[1])]
		if point in normalized: return false
		normalized.append(point)
	var clues = data.get("discoveries")
	if not _integers(clues, 0, 7, 8) or not _unique(clues.map(func(value): return int(value))):
		return false
	var saved_checkpoint = data.get("checkpoint")
	if not saved_checkpoint is Dictionary or not _valid_resources(saved_checkpoint):
		return false
	var saved_start = data.get("level_start")
	if not saved_start is Dictionary or not _valid_resources(saved_start):
		return false
	difficulty = int(data.difficulty)
	level_index = int(data.level_index)
	discoveries = clues.map(func(value): return int(value))
	explored = normalized
	checkpoint = _normalized_resources(saved_checkpoint)
	level_start = _normalized_resources(saved_start)
	_apply_resources(data)
	return true

func _normalized_resources(data: Dictionary) -> Dictionary:
	var result = data.duplicate(true)
	var point = Vector3(data.position[0],data.position[1],data.position[2])
	result.position = [point.x,point.y,point.z]
	for field in ["health", "armor", "weapon"]:
		result[field] = int(result[field])
	for field in ["ammo", "owned_weapons"]:
		result[field] = result[field].map(func(value): return int(value))
	return result

func _apply_resources(data: Dictionary) -> void:
	health = int(data.health)
	armor = int(data.armor)
	ammo = data.ammo.map(func(value): return int(value))
	owned_weapons = data.owned_weapons.map(func(value): return int(value))
	weapon = int(data.weapon)
	keys = data.keys.duplicate()
	removed = data.removed.duplicate()
	checkpoint_id = data.checkpoint_id
	position = Vector3(data.position[0], data.position[1], data.position[2])

func _valid_resources(data: Dictionary) -> bool:
	if not _integer(data.get("health"), 0, 200) or not _integer(data.get("armor"), 0, 200):
		return false
	if not _integers(data.get("ammo"), 0, 9999, 6) or data.ammo.size() != 6:
		return false
	var weapons = data.get("owned_weapons")
	if not _integers(weapons, 0, 5, 6):
		return false
	weapons = weapons.map(func(value): return int(value))
	if not _unique(weapons) or not 0 in weapons:
		return false
	if not _integer(data.get("weapon"), 0, 5) or not int(data.weapon) in weapons:
		return false
	if not _strings(data.get("keys"), 8) or not _strings(data.get("removed"), 1024):
		return false
	if not data.get("checkpoint_id") is String or data.checkpoint_id.length() > 128:
		return false
	var pos = data.get("position")
	if not pos is Array or pos.size() != 3:
		return false
	for component in pos:
		if not (component is float or component is int) or not is_finite(float(component)) or absf(component) > 100000:
			return false
	return true

func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floor(value) and value >= low and value <= high

func _integers(value: Variant, low: int, high: int, limit: int) -> bool:
	if not value is Array or value.size() > limit:
		return false
	for element in value:
		if not _integer(element, low, high):
			return false
	return true

func _unique(value: Array) -> bool:
	var seen = {}
	for item in value:
		if seen.has(item):
			return false
		seen[item] = true
	return true

func _strings(value: Variant, limit: int) -> bool:
	if not value is Array or value.size() > limit:
		return false
	for item in value:
		if not item is String or item.length() > 128:
			return false
	return _unique(value)

func save_progress(path: String = SAVE_PATH) -> Error:
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(to_dict()))
	file.flush()
	var error = file.get_error()
	file.close()
	if error != OK:
		return error
	return DirAccess.rename_absolute(path + ".tmp", path)

func load_progress(path: String = SAVE_PATH) -> bool:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 1048576:
		return false
	var parser = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return false
	var data = parser.data
	return data is Dictionary and from_dict(data)
