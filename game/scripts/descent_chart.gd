extends VBoxContainer

# Presentation only: receives a detached overview, never a Campaign or Main.
const VIEWS = ["intake", "foundry", "processional", "reliquary", "nursery", "ossuary", "inversion", "heart"]
# Explicit approved runtime mapping; stable chapter IDs remain unchanged.
# Three unqualified paintings retain their prior runtime assets.
const ART_FILES = ["intake.jpg", "foundry-pro-v2.jpg", "processional-pro-v2.jpg", "reliquary.jpg", "nursery.jpg", "ossuary-pro-v2.jpg", "inversion-pro-v2.jpg", "heart-pro-v2.jpg"]

static func art_path(index: int) -> String:
	if index < 0 or index >= ART_FILES.size(): return ""
	return "res://assets/art/descent/" + ART_FILES[index]


class Illustration extends Control:
	var rows: Array = []
	var textures: Dictionary = {}
	var phase: float = 0.0
	const STEP: float = 210.0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		set_process(false) # Motion is explicitly opt-in, never a flashing default.
		resized.connect(queue_redraw)

	func _process(delta: float) -> void:
		phase = fmod(phase + minf(delta, 0.1), TAU)
		queue_redraw()

	func point(index: int) -> Vector2:
		return Vector2(15.0, float(index) * STEP + 92.0)

	func _draw() -> void:
		var ink: Color = get_theme_color("font_color", "Label")
		var muted := Color(ink, 0.35)
		var warm := Color(0.92, 0.65, 0.32)
		var font: Font = get_theme_default_font()
		for index in rows.size():
			var row: Dictionary = rows[index]
			var current: bool = row.status == "CURRENT"
			var earned: bool = row.status != "UNREACHED"
			var center: Vector2 = point(index)
			if index + 1 < rows.size():
				draw_line(center, point(index + 1), warm if row.status == "CLEARED" else muted, 2.0, true)
			draw_circle(center, 5.0, warm if earned else muted)
			if current:
				draw_arc(center, 9.0 + sin(phase) * 1.5, 0.0, TAU, 32, warm, 1.5, true)
			var width: float = maxf(1.0, size.x - 38.0)
			var area := Rect2(34.0, index * STEP + 5.0, width, width * 9.0 / 16.0)
			draw_rect(area, Color(0.035, 0.045, 0.065))
			if textures.has(index):
				draw_texture_rect(textures[index], area, false)
			else:
				draw_string(font, area.position + Vector2(15, 35), "SEALED / UNCHARTED", HORIZONTAL_ALIGNMENT_LEFT, width - 20, 13, muted)
			draw_rect(area, warm if current else muted, false, 1.0)
			var text_y: float = maxf(area.end.y + 17.0, index * STEP + 176.0)
			draw_string(font, Vector2(34, text_y), "%02d  %s" % [index + 1, row.name], HORIZONTAL_ALIGNMENT_LEFT, width, 14, ink)
			draw_string(font, Vector2(34, text_y + 17), row.status, HORIZONTAL_ALIGNMENT_LEFT, width, 12, warm if earned else muted)

func configure(overview: Dictionary) -> void:
	assert(get_child_count() == 0)
	var motion := CheckButton.new()
	motion.text = "Animate descent illustration"
	motion.tooltip_text = "Optional gentle current-depth pulse. Off keeps the illustration still."
	add_child(motion)
	var art := Illustration.new()
	art.rows = overview.rows.duplicate(true)
	art.custom_minimum_size = Vector2(0, art.rows.size() * Illustration.STEP)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for row in art.rows:
		if row.status != "UNREACHED":
			art.textures[row.index] = load(art_path(row.index))
	add_child(art)
	motion.toggled.connect(func(enabled: bool):
		art.set_process(enabled)
		if not enabled:
			art.phase = 0.0
			art.queue_redraw())

# Painted, generic world geography; only completed chapter art may decorate markers.
# This is presentation-only and never loads unreached chapter illustrations.
class IntermissionRoute extends Control:
	var rows: Array = []
	var textures: Dictionary = {}
	var backdrop: Texture2D
	const POINTS = [Vector2(35, 68), Vector2(100, 101), Vector2(176, 133), Vector2(250, 167), Vector2(345, 201), Vector2(292, 246), Vector2(207, 287), Vector2(346, 324)]

	func configure(overview: Dictionary) -> void:
		rows = overview.rows.duplicate(true)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		backdrop = load("res://assets/art/descent/worldmap-v1.jpg")
		for row in rows:
			if row.status == "CLEARED":
				textures[row.index] = load(load("res://scripts/descent_chart.gd").art_path(row.index))
		queue_redraw()

	func point(index: int) -> Vector2:
		return POINTS[index]

	func label_position(index: int) -> Vector2:
		var center := point(index)
		return center + Vector2(-119 if center.x >= 320 else 21, -2)

	func _draw() -> void:
		var font := get_theme_default_font()
		var gold := Color(1.0, 0.77, 0.43)
		var ivory := Color(0.96, 0.92, 0.79)
		var faded := Color(0.65, 0.61, 0.55)
		if backdrop != null:
			draw_texture_rect(backdrop, Rect2(Vector2.ZERO, size), false)
		# Legible ink over the painting, with a quieter right-hand menu margin.
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.025, 0.24))
		draw_rect(Rect2(420, 0, 220, size.y), Color(0.015, 0.012, 0.02, 0.72))
		draw_string_outline(font, Vector2(18, 25), "THE DESCENT", HORIZONTAL_ALIGNMENT_LEFT, 390, 18, 4, Color.BLACK)
		draw_string(font, Vector2(18, 25), "THE DESCENT", HORIZONTAL_ALIGNMENT_LEFT, 390, 18, ivory)
		for index in range(rows.size() - 1):
			var earned: bool = rows[index].status == "CLEARED"
			draw_line(point(index), point(index + 1), Color(0.02, 0.015, 0.025, 0.9), 5, true)
			draw_line(point(index), point(index + 1), gold if earned else Color(faded, 0.65), 1.5, true)
		for row in rows:
			var center := point(row.index)
			var current: bool = row.status == "CURRENT"
			var cleared: bool = row.status == "CLEARED"
			var ink: Color = gold if current or cleared else faded
			draw_circle(center, 14, Color(0.025, 0.02, 0.03, 0.95))
			if textures.has(row.index):
				# Small architectural medallions, never rectangular chapter cards.
				var polygon := PackedVector2Array()
				var uv := PackedVector2Array()
				for corner in range(6):
					var direction := Vector2.from_angle(float(corner) * TAU / 6.0)
					polygon.append(center + direction * 11)
					uv.append(Vector2(0.5, 0.5) + direction * 0.5)
				draw_polygon(polygon, PackedColorArray([Color.WHITE]), uv, textures[row.index])
			else:
				# A shut gate reveals no future level-specific artwork.
				for offset in [-5, 0, 5]:
					draw_line(center + Vector2(offset, -7), center + Vector2(offset, 7), ink, 1)
				draw_line(center + Vector2(-7, -7), center + Vector2(7, -7), ink, 1)
			draw_arc(center, 14, 0, TAU, 32, ink, 1.5, true)
			if current:
				draw_arc(center, 18, 0, TAU, 32, gold, 2, true)
			var caption: String = row.name.trim_prefix("The ") if row.status != "UNREACHED" else "Sealed"
			var label := label_position(row.index)
			draw_string_outline(font, label, "%02d %s" % [row.index + 1, caption], HORIZONTAL_ALIGNMENT_LEFT, 100, 11, 4, Color.BLACK)
			draw_string(font, label, "%02d %s" % [row.index + 1, caption], HORIZONTAL_ALIGNMENT_LEFT, 100, 11, ivory if current or cleared else faded)
			var status: String = "YOU ARE HERE" if current else ("Restored" if cleared else "Uncharted")
			draw_string_outline(font, label + Vector2(0, 13), status, HORIZONTAL_ALIGNMENT_LEFT, 100, 9, 4, Color.BLACK)
			draw_string(font, label + Vector2(0, 13), status, HORIZONTAL_ALIGNMENT_LEFT, 100, 9, ink)
