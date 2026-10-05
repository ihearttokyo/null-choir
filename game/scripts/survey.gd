extends Node2D

# Native editable instrument derived from inspected source/art/references/survey-02.png.
const IVORY = Color(0.9,0.85,0.72)
const COPPER = Color(0.5,0.31,0.17)
const AMBER = Color(0.98,0.65,0.25)
var game: Node
var _level: Node
var _last_cell = Vector2i(-1,-1)
var heading: Label
var legend: Label

func _ready() -> void:
	hide()
	for entry in [[Vector2(52,39),""],[Vector2(52,288),"G GATE   S SEAL   R RECORD   C RECOVERY   > DESCENT  /  M CLOSE"]]:
		var label = Label.new()
		label.position = entry[0]
		label.text = entry[1]
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size",11 if entry[1].is_empty() else 9)
		label.add_theme_color_override("font_color",IVORY)
		add_child(label)
		if entry[1].is_empty(): heading = label
		else: legend = label

func toggle() -> void:
	if not game.playing: return
	visible = not visible
	if visible: queue_redraw()

func _physics_process(_delta: float) -> void:
	if not game.playing or not is_instance_valid(game.level):
		hide()
		return
	reveal()
	if visible: queue_redraw()

func reveal() -> void:
	if not game.playing or not is_instance_valid(game.level) or game.level.is_queued_for_deletion(): return
	if _level != game.level:
		_level = game.level
		_last_cell = Vector2i(-1,-1)
	var layout = game.level.layout
	var cell = Vector2i((Vector2(game.player.position.x,game.player.position.z)/layout.data.cell_size).floor())
	if cell == _last_cell or not layout.is_walkable(cell): return
	_last_cell = cell
	# At most25 native rays only when entering a new cell; never reveal through cover.
	var space = game.get_world_3d().direct_space_state
	for x in range(cell.x-2,cell.x+3):
		for z in range(cell.y-2,cell.y+3):
			var point = Vector2i(x,z)
			var saved = [x,z]
			if not layout.is_walkable(point) or saved in game.state.explored: continue
			var destination = layout.world_position([x+0.5,z+0.5])+Vector3.UP*1.55
			var ray = PhysicsRayQueryParameters3D.create(game.player.camera.global_position,destination,1)
			if point == cell or space.intersect_ray(ray).is_empty(): game.state.explored.append(saved)

func draw_state() -> Dictionary:
	if not is_instance_valid(game.level) or game.player == null: return {}
	var cells: Array[Vector2i] = []
	for point in game.state.explored:
		var cell = Vector2i(point[0],point[1])
		if game.level.layout.is_walkable(cell): cells.append(cell)
	var icons: Array = []
	for spec in game.level.layout.data.interactions+game.level.layout.data.doors:
		var cell = Vector2i(spec.cell[0],spec.cell[1])
		if not cell in cells or spec.id in game.state.removed: continue
		var symbol = "G" if spec.has("size") else {"key":"S","story":"R","checkpoint":"C","exit":">"}.get(spec.kind,"")
		if not symbol.is_empty(): icons.append({"cell":cell,"symbol":symbol})
	return {"cells":cells,"icons":icons,"player":Vector2(game.player.position.x,game.player.position.z)/game.level.layout.data.cell_size,"yaw":game.player.rotation.y}

func _draw() -> void:
	var view = draw_state()
	if view.is_empty(): return
	var layout = game.level.layout
	heading.text = "SURVEY / "+layout.data.title+"   //   EXPLORED ROUTES ONLY"
	legend.text = "G GATE   S SEAL   R RECORD   C RECOVERY   > DESCENT  /  "+game.preferences.binding_text("survey")+" CLOSE"
	draw_rect(Rect2(40,32,560,276),Color(0.015,0.018,0.021,0.96))
	draw_rect(Rect2(40,32,560,276),COPPER,false,2)
	draw_rect(Rect2(44,36,552,268),IVORY.darkened(0.55),false,1)
	for corner in [Vector2(40,32),Vector2(600,32),Vector2(40,308),Vector2(600,308)]:
		draw_circle(corner,3,COPPER)
	var low = Vector2(INF,INF)
	var high = Vector2(-INF,-INF)
	for cell in layout.tiles:
		low = low.min(Vector2(cell))
		high = high.max(Vector2(cell)+Vector2.ONE)
	var scale_map = minf(516/(high.x-low.x),216/(high.y-low.y))
	var origin = Vector2(320,174)-(high+low)*0.5*scale_map
	for cell in view.cells:
		var point = origin+Vector2(cell)*scale_map
		draw_rect(Rect2(point,Vector2.ONE*scale_map),Color(AMBER,0.18))
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if layout.is_walkable(cell+direction): continue
			var a = point+Vector2(scale_map if direction.x > 0 else 0,scale_map if direction.y > 0 else 0)
			draw_line(a,a+Vector2(0,scale_map) if direction.x else a+Vector2(scale_map,0),IVORY,1)
	var font = ThemeDB.fallback_font
	for icon in view.icons:
		draw_string(font,origin+(Vector2(icon.cell)+Vector2(0.5,0.5))*scale_map+Vector2(-3,3),icon.symbol,HORIZONTAL_ALIGNMENT_LEFT,-1,9,AMBER)
	var center = origin+view.player*scale_map
	var forward = Vector2(-sin(view.yaw),-cos(view.yaw))
	var side = Vector2(-forward.y,forward.x)
	draw_colored_polygon(PackedVector2Array([center+forward*5,center-forward*3+side*3,center-forward*3-side*3]),IVORY)
