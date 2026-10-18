extends RefCounted

const VERSION = 1
const TERRAIN_VERSION = 2
const SAVE_PATH = "user://campaign.json"
const Layout = preload("res://scripts/level_data.gd")
const Enemy = preload("res://scripts/enemy.gd")

var floor_revision: int = 0
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
# Missing legacy components use authored yaw / level camera pitch on reconstruction.
var yaw: Variant = null
var pitch: Variant = null
var checkpoint: Dictionary = {}
var level_start: Dictionary = {}
# null is legacy/unknown; [] is an authoritative empty living set.
var actors: Variant = null
var level_load_error: String = ""

func new_campaign(mode: int) -> void:
	level_load_error = ""
	difficulty = clampi(mode, 0, 2)
	level_index = 0
	_label_floor()
	health = 100
	armor = 0
	ammo = [0, 90, 0, 0, 0, 0]
	owned_weapons = [0, 1]
	weapon = 1
	keys = []
	discoveries = []
	removed = []
	explored = []
	actors = null
	yaw = null
	pitch = null
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
		var document = to_dict()
		for field in ["actors","yaw","pitch"]: document.erase(field)
		document.merge(checkpoint,true)
		var candidate = get_script().new()
		if not candidate.from_dict(document): return
		_apply_resources(checkpoint)

func restore_level_start() -> void:
	if not level_start.is_empty():
		var document = to_dict()
		for field in ["actors","yaw","pitch"]: document.erase(field)
		document.merge(level_start,true)
		document.checkpoint = level_start.duplicate(true)
		var candidate = get_script().new()
		if not candidate.from_dict(document): return
		_apply_resources(level_start)
		checkpoint = level_start.duplicate(true)

func complete_level() -> void:
	level_index = mini(8, level_index + 1)
	_label_floor()
	keys = []
	removed = []
	explored = []
	actors = null
	yaw = null
	pitch = null
	mark_checkpoint("entry", Vector3.ZERO)

func _label_floor() -> void:
	floor_revision = 0
	if level_index < 8:
		var layout = Layout.new()
		if layout.load_level(level_index): floor_revision = layout.floor_revision()

func _resources() -> Dictionary:
	var data = {"health": health, "armor": armor, "ammo": ammo.duplicate(),
		"owned_weapons": owned_weapons.duplicate(), "weapon": weapon,
		"keys": keys.duplicate(), "removed": removed.duplicate(),
		"checkpoint_id": checkpoint_id, "position": [position.x, position.y, position.z]}
	if floor_revision > 0: data["floor_revision"] = floor_revision
	if actors != null: data["actors"] = actors.duplicate(true)
	if yaw != null: data["yaw"] = yaw
	if pitch != null: data["pitch"] = pitch
	return data

func to_dict() -> Dictionary:
	var data = _resources()
	data.merge({"version": TERRAIN_VERSION if floor_revision > 0 else VERSION, "difficulty": difficulty, "level_index": level_index,
		"discoveries": discoveries.duplicate(), "explored": explored.duplicate(true), "checkpoint": checkpoint.duplicate(true),
		"level_start": level_start.duplicate(true)})
	return data

func from_dict(data: Dictionary) -> bool:
	level_load_error = ""
	# Validate everything before changing live state. Saves are an untrusted boundary.
	if not _integer(data.get("version"), VERSION, TERRAIN_VERSION) or not _integer(data.get("difficulty"), 0, 2):
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
	var snapshots = [data,saved_checkpoint,saved_start]
	var revision: int = 0
	if int(data.version) == VERSION:
		if snapshots.any(func(snapshot): return snapshot.has("floor_revision")): return false
	else:
		for snapshot in snapshots:
			if not _integer(snapshot.get("floor_revision"),1,1): return false
		revision = int(data.floor_revision)
		if snapshots.any(func(snapshot): return int(snapshot.floor_revision) != revision): return false
	var layout = Layout.new()
	if int(data.level_index) < 8 and not layout.load_level(int(data.level_index)):
		level_load_error = layout.load_error
		return false
	var current_revision: int = layout.floor_revision()
	if revision > current_revision: return false
	var old_layout = layout.original_floor(int(data.level_index)) if revision < current_revision else layout
	for snapshot in snapshots:
		if not _valid_actor_resources(snapshot,old_layout,int(data.difficulty)): return false
	if revision < current_revision:
		data = data.duplicate(true)
		for snapshot in [data,data.checkpoint,data.level_start]:
			snapshot.position = _shift_floor(snapshot.position,old_layout,layout,true)
			if snapshot.has("actors"):
				for actor in snapshot.actors:
					actor.position = _shift_floor(actor.position,old_layout,layout,false)
			snapshot["floor_revision"] = current_revision
			if not _valid_resources(snapshot) or not _valid_actor_resources(snapshot,layout,int(data.difficulty)): return false
		saved_checkpoint = data.checkpoint
		saved_start = data.level_start
	floor_revision = current_revision
	difficulty = int(data.difficulty)
	level_index = int(data.level_index)
	discoveries = clues.map(func(value): return int(value))
	explored = normalized
	checkpoint = _normalized_resources(saved_checkpoint)
	level_start = _normalized_resources(saved_start)
	_apply_resources(data)
	return true

func _shift_floor(values: Array, old_layout, layout, player: bool) -> Array:
	var point = Vector3(values[0],values[1],values[2])
	if player and point == Vector3.ZERO: return values.duplicate()
	var cell = Vector2(point.x,point.z)/float(old_layout.data.cell_size)
	# Preserve invalid/outside player poses for Main's existing native recovery path.
	if player and not old_layout.is_walkable(Vector2i(cell.floor())): return values.duplicate()
	point.y += layout.world_position([cell.x,cell.y]).y-old_layout.world_position([cell.x,cell.y]).y
	return [point.x,point.y,point.z]

func _normalized_resources(data: Dictionary) -> Dictionary:
	var result = data.duplicate(true)
	if result.has("floor_revision"): result.floor_revision = int(result.floor_revision)
	var point = Vector3(data.position[0],data.position[1],data.position[2])
	result.position = [point.x,point.y,point.z]
	if result.has("yaw"): result.yaw = Enemy.canonical_yaw(result.yaw)
	if result.has("pitch"): result.pitch = _native_pitch(float(result.pitch))
	for field in ["health", "armor", "weapon"]:
		result[field] = int(result[field])
	for field in ["ammo", "owned_weapons"]:
		result[field] = result[field].map(func(value): return int(value))
	if result.has("actors"):
		for actor in result.actors:
			actor.hp = int(actor.hp)
			var location = Vector3(actor.position[0],actor.position[1],actor.position[2])
			actor.position = [location.x,location.y,location.z]
			actor.yaw = Enemy.canonical_yaw(actor.yaw)
	return result

# Native camera precision also removes JSON parser last-bit drift; validation precedes this.
func _native_pitch(value: float) -> float:
	return clampf(Vector3(value,0,0).x,-1.35,1.35)

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
	yaw = Enemy.canonical_yaw(data.yaw) if data.has("yaw") else null
	pitch = _native_pitch(float(data.pitch)) if data.has("pitch") else null
	actors = _normalized_resources(data).actors if data.has("actors") else null

static func actor_specs(layout) -> Dictionary:
	var specs = {}
	for authored in layout.data.enemies:
		var spec: Dictionary = authored.duplicate(true)
		spec["encounter"] = ""
		spec["owner"] = ""
		for group in layout.data.get("encounters",[]):
			if spec.id in group.enemy_ids:
				spec.encounter = group.id
				break
		specs[spec.id] = spec
		if spec.kind == "summoner":
			for number in range(1,7):
				var id: String = spec.id+"_add_"+str(number)
				specs[id] = {"id":id,"kind":"crawler","cell":spec.cell.duplicate(),"yaw":spec.yaw,"encounter":"","owner":spec.id,"birth":number}
	return specs

func _valid_actor_resources(data: Dictionary, layout, mode: int, allow_missing_adds: bool = false) -> bool:
	if not data.has("actors"): return true
	var records = data.actors
	if not records is Array: return false
	if layout.data.is_empty(): return records.is_empty() and data.removed.is_empty()
	var specs = actor_specs(layout)
	var owners = layout.data.enemies.filter(func(spec): return spec.kind == "summoner")
	if records.size() > layout.data.enemies.size()+mini(4,owners.size()*2): return false
	var allowed_removals = {}
	for field in ["enemies","pickups","interactions","doors"]:
		for spec in layout.data[field]: allowed_removals[spec.id] = true
	for group in layout.data.get("encounters",[]): allowed_removals["encounter:"+group.id] = true
	for owner in owners:
		for number in range(1,7):
			allowed_removals[owner.id+"_add_"+str(number)] = true
			allowed_removals["summon:"+owner.id+":"+str(number)] = true
	for id in data.removed:
		if not allowed_removals.has(id): return false
	var living = {}
	var per_owner = {}
	var total_adds: int = 0
	for record in records:
		if not record is Dictionary or record.size() != 5: return false
		for field in ["id","hp","position","yaw","alerted"]:
			if not record.has(field): return false
		if not record.id is String or not specs.has(record.id) or living.has(record.id) or record.id in data.removed: return false
		var spec: Dictionary = specs[record.id]
		if not _integer(record.hp,1,Enemy.health_cap(spec.kind,mode)) or not record.alerted is bool: return false
		if not spec.encounter.is_empty() and not "encounter:"+spec.encounter in data.removed and record.alerted: return false
		if not _valid_actor_pose(record,spec,layout): return false
		living[record.id] = true
		if not spec.owner.is_empty():
			total_adds += 1
			per_owner[spec.owner] = per_owner.get(spec.owner,0)+1
			if per_owner[spec.owner] > 2 or total_adds > 4: return false
	for authored in layout.data.enemies:
		if not authored.id in data.removed and not living.has(authored.id): return false
	for owner in owners:
		var gap: bool = false
		for number in range(1,7):
			var born: bool = "summon:"+owner.id+":"+str(number) in data.removed
			var id: String = owner.id+"_add_"+str(number)
			var dead: bool = id in data.removed
			if not born:
				gap = true
				if dead or living.has(id): return false
			else:
				if gap: return false
				var encounter: String = specs[owner.id].encounter
				if not encounter.is_empty() and not "encounter:"+encounter in data.removed: return false
				if not dead and not living.has(id) and not allow_missing_adds: return false
	return true

func _valid_actor_pose(record: Dictionary, spec: Dictionary, layout) -> bool:
	var values = record.position
	if not values is Array or values.size() != 3: return false
	for value in values:
		if not (value is int or value is float) or not is_finite(float(value)): return false
	if not (record.yaw is int or record.yaw is float) or not is_finite(float(record.yaw)) or record.yaw < -PI or record.yaw >= PI: return false
	var point = Vector3(values[0],values[1],values[2])
	if not point.is_finite(): return false
	var cell = Vector2(point.x,point.z)/float(layout.data.cell_size)
	# Test bounds before converting an untrusted coordinate to a native tile integer.
	var inside: bool = false
	for rect in layout.data.rects:
		if cell.x >= rect[0] and cell.y >= rect[1] and cell.x < rect[2]+1 and cell.y < rect[3]+1:
			inside = true
			break
	if not inside or not layout.is_walkable(Vector2i(cell.floor())): return false
	var floor_point: Vector3 = layout.world_position([cell.x,cell.y])
	# Moving/falling actors can be above their support, not necessarily at spawn height.
	if point.y < floor_point.y-0.08: return false
	for offset in [Vector2.ZERO,Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
		var sample: Vector2 = cell+offset*Enemy.capsule_radius(spec.kind)/float(layout.data.cell_size)
		var ceiling: float = layout.world_position([sample.x,sample.y]).y+layout.roof_height(Vector2i(sample.floor()))
		if point.y+Enemy.capsule_height(spec.kind)+0.03 >= ceiling: return false
	return true

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
	for field in ["yaw","pitch"]:
		if not data.has(field): continue
		var value = data[field]
		if not (value is int or value is float) or not is_finite(float(value)): return false
		if field == "pitch" and absf(value) > 1.35: return false
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
	var serialized = JSON.stringify(to_dict(),"",true,true)
	if serialized.to_utf8_buffer().size() > 1048576: return ERR_INVALID_DATA
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(serialized)
	file.flush()
	var error = file.get_error()
	file.close()
	if error != OK:
		return error
	return DirAccess.rename_absolute(path + ".tmp", path)

func load_progress(path: String = SAVE_PATH) -> bool:
	level_load_error = ""
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 1048576:
		return false
	var parser = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return false
	var data = parser.data
	return data is Dictionary and from_dict(data)
