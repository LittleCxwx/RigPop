extends Control

const ThemeKit = preload("res://editor/theme.gd")

signal stroke_started
signal stroke_finished
signal image_changed
signal color_picked(color: Color)

var image: Image
var texture: ImageTexture
var tool := "pencil"
var color := Color("1d8569")
var drawing := false
var changed := false
var last := Vector2i(-1, -1)
var zoom := 10
var pan := Vector2.ZERO
var panning := false

func _ready() -> void:
	clip_contents = true
	mouse_default_cursor_shape = CURSOR_CROSS

func set_image(img: Image) -> void:
	image = img
	pan = Vector2.ZERO
	texture = ImageTexture.create_from_image(img) if img != null else null
	queue_redraw()

func origin() -> Vector2:
	return ((size - Vector2(image.get_size()) * zoom) / 2).floor() + pan if image != null else Vector2.ZERO

func _draw() -> void:
	# Refined canvas background
	draw_rect(Rect2(Vector2.ZERO, size), Color("2a2f33"))

	if image == null:
		return

	var start := origin()
	var cell := maxi(1, int(ceil(12.0 / zoom)))
	var first := Vector2i(((-start / zoom / cell).floor() * cell).max(Vector2.ZERO))
	var end := Vector2i((((size - start) / zoom / cell).ceil() * cell).min(Vector2(image.get_size())))

	# Enhanced checkerboard with better contrast
	for y in range(first.y, end.y, cell):
		for x in range(first.x, end.x, cell):
			var checker_color := Color("424a4f") if (x / cell + y / cell) % 2 == 0 else Color("373f44")
			draw_rect(Rect2(start + Vector2(x, y) * zoom, Vector2(mini(cell, image.get_width() - x), mini(cell, image.get_height() - y)) * zoom), checker_color)

	# Draw the image
	draw_texture_rect(texture, Rect2(start, Vector2(image.get_size()) * zoom), false)

	# Pixel grid at high zoom levels with subtle lines
	if zoom >= 8:
		var grid_color := Color(1, 1, 1, 0.08)
		for x in image.get_width() + 1:
			draw_line(start + Vector2(x * zoom, 0), start + Vector2(x * zoom, image.get_height() * zoom), grid_color, 1.0)
		for y in image.get_height() + 1:
			draw_line(start + Vector2(0, y * zoom), start + Vector2(image.get_width() * zoom, y * zoom), grid_color, 1.0)

	# Canvas border with accent color
	draw_rect(Rect2(start, Vector2(image.get_size()) * zoom), ThemeKit.ACCENT, false, 2.0)

func _gui_input(event: InputEvent) -> void:
	if image == null:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			panning = event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom = clampi(zoom + (1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1), 1, 32)
			queue_redraw()
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var pos := Vector2i(((event.position - origin()) / zoom).floor())
				if not inside(pos):
					return
				if tool == "picker":
					color_picked.emit(image.get_pixelv(pos))
					return
				stroke_started.emit()
				drawing = true
				changed = false
				last = pos
				if tool == "fill":
					flood(pos)
				else:
					paint(pos)
				refresh()
			elif drawing:
				drawing = false
				stroke_finished.emit()
	if event is InputEventMouseMotion and panning:
		pan += event.relative
		queue_redraw()
	if event is InputEventMouseMotion and drawing and tool != "fill":
		var pos := Vector2i(((event.position - origin()) / zoom).floor())
		if inside(pos):
			var steps := maxi(absi(pos.x - last.x), absi(pos.y - last.y))
			for step in range(steps + 1):
				paint(Vector2i(Vector2(last).lerp(Vector2(pos), float(step) / maxi(1, steps)).round()))
			last = pos
			refresh()

func inside(pos: Vector2i) -> bool:
	return Rect2i(Vector2i.ZERO, image.get_size()).has_point(pos)

func paint(pos: Vector2i) -> void:
	var ink := Color.TRANSPARENT if tool == "eraser" else color
	if image.get_pixelv(pos) != ink:
		image.set_pixelv(pos, ink)
		changed = true

func flood(pos: Vector2i) -> void:
	var target := image.get_pixelv(pos)
	if target.is_equal_approx(color):
		return
	var pending: Array[Vector2i] = [pos]
	while not pending.is_empty():
		var p: Vector2i = pending.pop_back()
		if not inside(p) or not image.get_pixelv(p).is_equal_approx(target):
			continue
		image.set_pixelv(p, color)
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			pending.append(p + offset)
	changed = true

func refresh() -> void:
	texture.update(image)
	image_changed.emit()
	queue_redraw()
