extends VBoxContainer

# Presentation only: receives a detached overview, never a Campaign or Main.
const VIEWS = ["intake", "foundry", "processional", "reliquary", "nursery", "ossuary", "inversion", "heart"]

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
			art.textures[row.index] = load("res://assets/art/descent/" + VIEWS[row.index] + ".jpg")
	add_child(art)
	motion.toggled.connect(func(enabled: bool):
		art.set_process(enabled)
		if not enabled:
			art.phase = 0.0
			art.queue_redraw())
