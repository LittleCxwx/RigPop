extends Control

const Character = preload("res://core/character.gd")
const ThemeKit = preload("res://editor/theme.gd")

signal frame_selected(frame: int)
signal track_selected(id: String)
var model: Dictionary = {}
var clip: Dictionary = {}
var frame := 0
var selected := ""
var cell := 32.0
var row_height := 30.0
var font: Font

func _ready() -> void:
	custom_minimum_size = Vector2(400, 120)
	font = get_theme_default_font()
	mouse_default_cursor_shape = CURSOR_POINTING_HAND
	clip_contents = true

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), ThemeKit.BG_BASE)
	if clip.is_empty() or font == null:
		return

	cell = minf(40.0, (size.x - 150) / maxi(8, int(clip.frames)))

	# Draw frame grid with subtle lines
	for f in int(clip.frames):
		var x := 150 + f * cell
		draw_line(Vector2(x, 0), Vector2(x, size.y), ThemeKit.BORDER_SUBTLE, 1.0)
		if cell > 16 or f % 4 == 0:
			draw_string(font, Vector2(x + 6, 19), str(f + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ThemeKit.TEXT_SECONDARY)

	# Draw header separator
	draw_line(Vector2(0, 28), Vector2(size.x, 28), ThemeKit.BORDER_DEFAULT, 1.0)

	var index := 0
	for p in model.get("parts", []):
		var y := 28 + index * row_height

		# Highlight selected track
		if p.id == selected:
			draw_rect(Rect2(0, y, size.x, row_height), ThemeKit.SELECTION_BG)

		# Draw part name with better typography
		draw_string(font, Vector2(12, y + 20), p.name, HORIZONTAL_ALIGNMENT_LEFT, 130, 12, ThemeKit.TEXT)

		# Draw row separator
		draw_line(Vector2(0, y + row_height), Vector2(size.x, y + row_height), ThemeKit.BORDER_SUBTLE, 1.0)

		# Draw keyframes as refined diamonds
		for key in clip.get("tracks", {}).get(p.id, []):
			var center := Vector2(150 + (float(key.frame) + 0.5) * cell, y + row_height / 2)
			var diamond := PackedVector2Array([
				center + Vector2(0, -5),
				center + Vector2(5, 0),
				center + Vector2(0, 5),
				center + Vector2(-5, 0)
			])
			draw_colored_polygon(diamond, ThemeKit.ACCENT)
			# Add subtle outline for better visibility
			draw_polyline(diamond + PackedVector2Array([center + Vector2(0, -5)]), ThemeKit.ACCENT_PRESSED, 1.0, true)

		index += 1

	# Draw playhead with more prominent styling
	var cursor := 150 + (frame + 0.5) * cell
	draw_line(Vector2(cursor, 0), Vector2(cursor, size.y), Color("e55934"), 2.5)
	var playhead_triangle := PackedVector2Array([
		Vector2(cursor - 6, 0),
		Vector2(cursor + 6, 0),
		Vector2(cursor, 9)
	])
	draw_colored_polygon(playhead_triangle, Color("e55934"))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.position.x >= 150:
			frame_selected.emit(clampi(int((event.position.x - 150) / cell), 0, maxi(0, int(clip.get("frames", 1)) - 1)))
		var index := int((event.position.y - 28) / row_height)
		if event.position.y > 28 and index >= 0 and index < model.get("parts", []).size():
			track_selected.emit(model.parts[index].id)
