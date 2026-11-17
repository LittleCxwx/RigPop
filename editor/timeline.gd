extends Control

const Character = preload("res://core/character.gd")
const ThemeKit = preload("res://editor/theme.gd")

signal frame_selected(frame: int)
signal track_selected(id: String)

const NAME_WIDTH := 140.0
const HEADER := 22.0
const ROW := 27.0

var model: Dictionary = {}
var clip: Dictionary = {}
var frame := 0
var selected := ""
var cell := 32.0
var row_height := ROW
var font: Font
var font_strong: Font
var font_micro: Font

func _ready() -> void:
	custom_minimum_size = Vector2(400, 120)
	font = ThemeKit.font(ThemeKit.W_BODY)
	font_strong = ThemeKit.font(ThemeKit.W_TITLE)
	font_micro = ThemeKit.font(ThemeKit.W_BODY)
	mouse_default_cursor_shape = CURSOR_POINTING_HAND
	clip_contents = true

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), ThemeKit.PAPER)
	if clip.is_empty() or font == null:
		return

	cell = minf(40.0, (size.x - NAME_WIDTH - 12.0) / maxi(8, int(clip.frames)))

	# 帧格：每帧一条极淡细线，每四帧略深，形成节拍而不变成表格。
	for f in int(clip.frames):
		var x := NAME_WIDTH + f * cell
		var beat := f % 4 == 0
		draw_line(Vector2(x, HEADER), Vector2(x, size.y), ThemeKit.LINE if beat else Color(ThemeKit.LINE, 0.5), 1.0)
		if cell >= 26 or f % 4 == 0:
			draw_string(font_micro, Vector2(x + 5, 15), str(f + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ThemeKit.MUTED)

	draw_line(Vector2(0, HEADER), Vector2(size.x, HEADER), ThemeKit.LINE, 1.0)
	draw_line(Vector2(NAME_WIDTH, 0), Vector2(NAME_WIDTH, size.y), ThemeKit.LINE, 1.0)

	var index := 0
	for p in model.get("parts", []):
		var y := HEADER + index * row_height
		var is_current: bool = p.id == selected
		if is_current:
			draw_rect(Rect2(0, y, size.x, row_height), ThemeKit.SELECT)
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(ThemeKit.LINE, 0.7), 1.0)
			draw_line(Vector2(0, y + row_height), Vector2(size.x, y + row_height), Color(ThemeKit.LINE, 0.7), 1.0)
		draw_string(font_strong if is_current else font, Vector2(12, y + 18), p.name,
			HORIZONTAL_ALIGNMENT_LEFT, NAME_WIDTH - 20, 12, ThemeKit.INK if is_current else ThemeKit.INK_2)

		for key in clip.get("tracks", {}).get(p.id, []):
			var center := Vector2(NAME_WIDTH + (float(key.frame) + 0.5) * cell, y + row_height / 2)
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -3.5), center + Vector2(3.5, 0),
				center + Vector2(0, 3.5), center + Vector2(-3.5, 0)]), ThemeKit.SIGNAL)
		index += 1

	# 播放头：一条 1 px 竖线加顶上一个小方块，安静但不能被忽略。
	var cursor := NAME_WIDTH + (frame + 0.5) * cell
	draw_line(Vector2(cursor, HEADER), Vector2(cursor, size.y), ThemeKit.SIGNAL, 1.0)
	draw_rect(Rect2(cursor - 3.0, HEADER - 1.0, 7.0, 5.0), ThemeKit.SIGNAL)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.position.x >= NAME_WIDTH:
			frame_selected.emit(clampi(int((event.position.x - NAME_WIDTH) / cell), 0, maxi(0, int(clip.get("frames", 1)) - 1)))
		var index := int((event.position.y - HEADER) / row_height)
		if event.position.y > HEADER and index >= 0 and index < model.get("parts", []).size():
			track_selected.emit(model.parts[index].id)
