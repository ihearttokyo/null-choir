extends SceneTree

const Schema = preload("res://scripts/level_schema.gd")
var failures: int = 0
var cases: int = 0

# SIMULATED call observation only; each value comes from actual production height_at.
class CountingLayout:
	extends "res://scripts/level_data.gd"
	var queries: Array[Vector2] = []
	func height_at(cell: Vector2) -> float:
		queries.append(cell)
		return super.height_at(cell)

func expect(ok: bool, label: String) -> bool:
	if not ok:
		failures += 1
		push_error(label)
	return ok

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var layout = CountingLayout.new()
	layout.data = {"cell_size":4,"elevations":[]}
	for cell in [[.75,.25],[.25,.75],[.5,.5]]:
		layout.queries.clear()
		layout.world_position(cell)
		# Baseline fails here with four actual queries, without depending on a new API.
		if not expect(layout.queries.size() == 3,"INTENDED RED: production world_position must read exactly three corners: "+str(cell)):
			quit(1)
			return
		check_case(layout,cell)
	for index in range(8):
		layout = CountingLayout.new()
		if not expect(layout.load_level(index),"Actual map must parse: "+layout.load_error): continue
		for scale in [4,3.7]:
			layout.data.cell_size = scale
			if not expect(Schema.validate(layout.data,layout._art_exists).is_empty(),"Scale must stay in actual schema domain"): continue
			check_map(layout)
		# Campaign migration also calls world_position on immutable original-floor layouts.
		layout.data.cell_size = 4
		var legacy = layout.original_floor(index)
		sample(legacy,legacy.data.spawn)
		for cell in [[NAN,0],[INF,0],[0,-INF],[NAN,NAN],[1e30,-1e30]]:
			check_case(layout,cell)
	print("PASS world_position three corners: exact old-reference/native query parity cases="+str(cases)+"; counter observation simulated" if failures == 0 else "FAIL three corners count="+str(failures))
	quit(0 if failures == 0 else 1)

# Literal old method, including all four calls and the original arithmetic/rounding order.
func old_world_position(layout, cell: Array) -> Vector3:
	var point = Vector2(cell[0],cell[1])
	var tile = point.floor()
	var uv = point-tile
	var a = layout.height_at(tile)
	var b = layout.height_at(tile+Vector2.RIGHT)
	var c = layout.height_at(tile+Vector2.ONE)
	var d = layout.height_at(tile+Vector2.DOWN)
	var height = a+(b-a)*uv.x+(c-b)*uv.y if uv.y <= uv.x else a+(c-d)*uv.x+(d-a)*uv.y
	return Vector3(point.x*layout.data.cell_size,height,point.y*layout.data.cell_size)

func check_case(layout, cell: Array) -> void:
	layout.queries.clear()
	var reference: Vector3 = old_world_position(layout,cell)
	if not expect(layout.queries.size() == 4,"Literal reference must retain four queries"): return
	var ordered: Array = layout.queries.duplicate()
	var point = Vector2(cell[0],cell[1])
	var uv = point-point.floor()
	ordered.remove_at(3 if uv.y <= uv.x else 1)
	layout.queries.clear()
	var actual: Vector3 = layout.world_position(cell)
	cases += 1
	if not expect(layout.queries.size() == 3,"Exactly three queries case "+str(cases)): return
	for index in range(3):
		expect(var_to_bytes(layout.queries[index]) == var_to_bytes(ordered[index]),"Same remaining native query coordinates/order case "+str(cases))
	# Bytes require exact representation, including signed zero and direct-input NaN payloads.
	expect(var_to_bytes(actual) == var_to_bytes(reference),"Exact represented Vector3, no tolerance, case "+str(cases))

func neighbor(value: float, direction: int) -> float:
	var bytes := PackedByteArray()
	bytes.resize(4)
	bytes.encode_float(0,value)
	var rounded: float = bytes.decode_float(0)
	var bits: int = bytes.decode_u32(0)
	if rounded == 0: bits = 1 if direction > 0 else 0x80000001
	else: bits += direction*(1 if rounded > 0 else -1)
	bytes.encode_u32(0,bits)
	return bytes.decode_float(0)

func sample(layout, cell: Array) -> void:
	check_case(layout,cell)
	var point = Vector2(cell[0],cell[1])
	for axis in [0,1]:
		for direction in [-1,1]:
			var adjacent: Vector2 = point
			adjacent[axis] = neighbor(point[axis],direction)
			check_case(layout,[adjacent.x,adjacent.y])

func check_rect(layout, rect: Array, floor_tiles: bool) -> void:
	var low = Vector2(rect[0],rect[1])
	var high = Vector2(rect[2],rect[3])+(Vector2.ONE if floor_tiles else Vector2.ZERO)
	var center: Vector2 = low.lerp(high,.5)
	for point in [low,Vector2(high.x,low.y),high,Vector2(low.x,high.y),center]:
		sample(layout,[point.x,point.y])
	if not floor_tiles:
		for point in [Vector2(center.x,low.y),Vector2(center.x,high.y),Vector2(low.x,center.y),Vector2(high.x,center.y)]:
			sample(layout,[point.x,point.y])
	for offset in [Vector2(.75,.25),Vector2(.25,.75)]:
		var point: Vector2 = center.floor()+offset
		check_case(layout,[point.x,point.y])

func check_map(layout) -> void:
	sample(layout,layout.data.spawn)
	for spec in layout.data.pickups: sample(layout,spec.cell)
	for spec in layout.data.interactions:
		if spec.kind == "checkpoint": sample(layout,spec.cell)
	for rect in layout.data.rects: check_rect(layout,rect,true)
	for region in layout.data.elevations:
		check_rect(layout,region.rect,false)
		if region.has("axis"):
			var point = Vector2((region.rect[0]+region.rect[2])*.5,(region.rect[1]+region.rect[3])*.5)
			for boundary in [region.start,region.end]:
				point[int(region.axis)] = boundary
				sample(layout,[point.x,point.y])
