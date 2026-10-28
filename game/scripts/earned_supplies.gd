extends RefCounted
## Finite primitive state; no Node/Object deserialization and no random rewards.
const REGISTRY_PATH = "res://data/earned_supplies.json"
const REGISTRY_SHA = "c79fada58cccd0faf3926074d3dbad7f51b4e7e8c0521e95a04ac07891388d49"
const CAPS = [0,180,32,240,24,120]
static var _registry: Dictionary = {}

static func registry() -> Dictionary:
	if not _registry.is_empty(): return _registry
	if FileAccess.get_sha256(REGISTRY_PATH) != REGISTRY_SHA: return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY_PATH))
	if not parsed is Dictionary or parsed.get("schema") != "null-choir-earned-supplies-registry-v1": return {}
	if parsed.get("revision") != 1 or parsed.get("legacy_pickup_count") != 145 or parsed.get("chapters",{}).size() != 8: return {}
	_registry = parsed
	return _registry

static func chapter(layout) -> Dictionary:
	if layout.data.is_empty(): return {"revision":1,"grants":[],"stations":[],"legacy_pickups":[]}
	return registry().get("chapters",{}).get(layout.data.id,{})

static func amount(grant: Dictionary, difficulty: int) -> int:
	return int(grant.quantities[difficulty])

static func grant_map(content: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for grant in content.get("grants",[]): result[grant.id] = grant
	return result

static func fresh(layout) -> Dictionary:
	var content := chapter(layout)
	if content.is_empty(): return {}
	var stations: Dictionary = {}
	for station in content.stations: stations[station.id] = int(station.capacity)
	return {"version":1,"revision":int(content.revision),"loot_drops":[],"loot_claimed":[],"healing_remaining":stations}

static func integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value==floor(value) and value>=low and value<=high

static func exact_keys(value: Variant, keys: Array) -> bool:
	if not value is Dictionary or value.size()!=keys.size(): return false
	for key in keys:
		if not value.has(key): return false
	return true

static func position_valid(values: Variant, layout, removed: Array) -> bool:
	if not values is Array or values.size()!=3: return false
	for value in values:
		if not (value is int or value is float) or not is_finite(float(value)) or absf(value)>100000: return false
	if layout.data.is_empty(): return false
	var point := Vector3(values[0],values[1],values[2])
	var cell := Vector2(point.x,point.z)/float(layout.data.cell_size)
	var inside: bool = false
	for rect in layout.data.rects:
		if cell.x>=rect[0] and cell.y>=rect[1] and cell.x<rect[2]+1 and cell.y<rect[3]+1: inside=true
	if not inside or not layout.is_walkable(Vector2i(cell.floor())): return false
	var support: Vector3 = layout.surface_position_at_y([cell.x,cell.y],point.y)
	if not support.is_finite() or point.y<support.y+.12 or point.y>support.y+.50: return false
	# V3's pure clearance API is ONLY defined for the Ossuary patch. Other
	# chapters retain explicit bank-floor bounds; runtime checks actual solids.
	if layout.OssuarySurfaces.enabled(layout.data):
		return layout.migration_capsule_clearance(point-Vector3.UP*.20,.08,.25,0.0,removed,.08)
	var size: float = layout.data.cell_size
	var tile := Vector2i(cell.floor())
	for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
		if layout.is_walkable(tile+offset): continue
		var edge_distance: float = (cell.x-tile.x if offset.x<0 else tile.x+1-cell.x) if offset.x!=0 else (cell.y-tile.y if offset.y<0 else tile.y+1-cell.y)
		if edge_distance*size<.21: return false
	return point.y+.25<support.y+layout.roof_height(tile)

static func valid_removed(removed: Array, layout) -> bool:
	var allowed: Dictionary = {}
	for group in ["enemies","pickups","interactions","doors"]:
		for row in layout.data.get(group,[]): allowed[row.id]=true
	for old in chapter(layout).get("legacy_pickups",[]): allowed[old.id]=true
	for encounter in layout.data.get("encounters",[]): allowed["encounter:"+encounter.id]=true
	for actor in layout.data.get("enemies",[]):
		if actor.kind!="summoner": continue
		for number in range(1,7):
			allowed[actor.id+"_add_"+str(number)]=true
			allowed["summon:"+actor.id+":"+str(number)]=true
	if removed.size()>1024: return false
	var seen: Dictionary = {}
	for id in removed:
		if not id is String or not allowed.has(id) or seen.has(id): return false
		seen[id]=true
	return true

static func valid(value: Variant, snapshot: Dictionary, layout, difficulty: int) -> bool:
	if not integer(difficulty,0,2) or not valid_removed(snapshot.removed,layout): return false
	var content := chapter(layout)
	if content.is_empty() or not exact_keys(value,["version","revision","loot_drops","loot_claimed","healing_remaining"]): return false
	if not integer(value.version,1,1) or not integer(value.revision,1,1): return false
	var grants := grant_map(content)
	if not value.loot_drops is Array or not value.loot_claimed is Array: return false
	if value.loot_drops.size()>grants.size() or value.loot_claimed.size()>grants.size(): return false
	var claimed: Dictionary = {}
	for id in value.loot_claimed:
		if not id is String or not grants.has(id) or claimed.has(id): return false
		var grant: Dictionary = grants[id]
		if not grant.carrier in snapshot.removed and not grant.legacy_alias in snapshot.removed: return false
		if grant.kind=="unlock" and not int(grant.weapon) in snapshot.owned_weapons: return false
		claimed[id]=true
	var pending: Dictionary = {}
	for drop in value.loot_drops:
		if not exact_keys(drop,["grant_id","position","remaining"]) or not drop.grant_id is String: return false
		if not grants.has(drop.grant_id) or pending.has(drop.grant_id) or claimed.has(drop.grant_id): return false
		var grant: Dictionary = grants[drop.grant_id]
		if not grant.carrier in snapshot.removed or grant.legacy_alias in snapshot.removed: return false
		if not integer(drop.remaining,1,amount(grant,difficulty)) or not position_valid(drop.position,layout,snapshot.removed): return false
		pending[drop.grant_id]=true
	for id in grants:
		var grant: Dictionary = grants[id]
		if grant.carrier in snapshot.removed and not pending.has(id) and not claimed.has(id): return false
		# A legacy alias consumes ALL its linked unlock/ammo entitlements, even
		# when the new authored carrier lives. No general living-drop exception.
		if grant.legacy_alias in snapshot.removed and not claimed.has(id): return false
	if not value.healing_remaining is Dictionary or value.healing_remaining.size()!=content.stations.size(): return false
	for station in content.stations:
		var legacy_spent: int = 0
		for old in content.legacy_pickups:
			if old.id in station.aliases and old.id in snapshot.removed: legacy_spent+=int(old.amount)
		if not integer(value.healing_remaining.get(station.id),0,int(station.capacity)-legacy_spent): return false
	return true

static func recovery_position(grant: Dictionary, layout) -> Array:
	var point: Vector3 = layout.world_position(grant.recovery_cell)+Vector3.UP*.20
	return [point.x,point.y,point.z]

static func migrate(snapshot: Dictionary, layout, difficulty: int) -> Dictionary:
	if snapshot.has("earned_supply"):
		return snapshot.earned_supply.duplicate(true) if valid(snapshot.earned_supply,snapshot,layout,difficulty) else {}
	var value := fresh(layout)
	if value.is_empty() or not valid_removed(snapshot.removed,layout): return {}
	var content := chapter(layout)
	for grant in content.grants:
		if grant.legacy_alias in snapshot.removed:
			value.loot_claimed.append(grant.id)
		elif grant.carrier in snapshot.removed:
			value.loot_drops.append({"grant_id":grant.id,"position":recovery_position(grant,layout),"remaining":amount(grant,difficulty)})
	for station in content.stations:
		for alias in station.aliases:
			if not alias in snapshot.removed: continue
			for old in content.legacy_pickups:
				if old.id==alias: value.healing_remaining[station.id]-=int(old.amount)
	return value if valid(value,snapshot,layout,difficulty) else {}

static func defeated(snapshot: Dictionary, layout, difficulty: int, carrier: String, physical_position: Vector3) -> Dictionary:
	# Caller has committed actor defeat. Work on a private copy, publish once.
	if not carrier in snapshot.removed or not snapshot.has("earned_supply"): return {}
	var value: Dictionary = snapshot.earned_supply.duplicate(true)
	var content := chapter(layout)
	for grant in content.grants:
		if grant.carrier!=carrier: continue # Summoned IDs have no registry grants.
		if grant.id in value.loot_claimed or value.loot_drops.any(func(row): return row.grant_id==grant.id): continue
		var cell := Vector2(physical_position.x,physical_position.z)/float(layout.data.cell_size)
		var support: Vector3 = layout.surface_position_at_y([cell.x,cell.y],physical_position.y+.08)+Vector3.UP*.20
		var point: Array = [support.x,support.y,support.z]
		if not position_valid(point,layout,snapshot.removed): point=recovery_position(grant,layout)
		if not position_valid(point,layout,snapshot.removed): return {}
		value.loot_drops.append({"grant_id":grant.id,"position":point,"remaining":amount(grant,difficulty)})
	return value if valid(value,snapshot,layout,difficulty) else {}

static func collect(snapshot: Dictionary, layout, difficulty: int, id: String) -> Dictionary:
	if not valid(snapshot.get("earned_supply"),snapshot,layout,difficulty): return {}
	var next := snapshot.duplicate(true)
	var grants := grant_map(chapter(layout))
	if not grants.has(id): return {}
	var grant: Dictionary = grants[id]
	var drops: Array = next.earned_supply.loot_drops
	var index: int = -1
	for i in range(drops.size()):
		if drops[i].grant_id==id: index=i;break
	if index<0: return {}
	var transferred: int = 0
	match grant.kind:
		"unlock":
			if not int(grant.weapon) in next.owned_weapons:
				next.owned_weapons.append(int(grant.weapon)); next.owned_weapons.sort()
				next.weapon=int(grant.weapon) # Preserve existing newly-acquired auto-equip.
			transferred=int(drops[index].remaining) # Redundant unlock is finite too.
		"ammo":
			transferred=mini(int(drops[index].remaining),maxi(0,CAPS[int(grant.weapon)]-int(next.ammo[int(grant.weapon)])))
			next.ammo[int(grant.weapon)]+=transferred
		"armor":
			transferred=mini(int(drops[index].remaining),maxi(0,200-int(next.armor)))
			next.armor+=transferred
	if transferred==0: return {} # Full cap leaves authoritative drop unchanged.
	drops[index].remaining-=transferred
	if drops[index].remaining==0:
		drops.remove_at(index); next.earned_supply.loot_claimed.append(id)
	return next if valid(next.earned_supply,next,layout,difficulty) else {}

static func heal(snapshot: Dictionary, layout, difficulty: int, station_id: String) -> Dictionary:
	if not valid(snapshot.get("earned_supply"),snapshot,layout,difficulty): return {}
	var next := snapshot.duplicate(true)
	if not next.earned_supply.healing_remaining.has(station_id): return {}
	var units: int = mini(maxi(0,100-int(next.health)),int(next.earned_supply.healing_remaining[station_id]))
	if units==0: return {}
	next.health+=units
	next.earned_supply.healing_remaining[station_id]-=units
	return next
