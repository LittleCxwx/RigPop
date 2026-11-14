extends Control

const Character = preload("res://core/character.gd")
const View = preload("res://runtime/shared/character_view.gd")
const ThemeKit = preload("res://editor/theme.gd")

signal part_selected(id: String)
signal drag_started
signal part_dragged(id: String, offset: Vector2)
signal drag_finished

var view: Node2D
var ghost: Node2D
var selected := ""
var zoom := 7
var pan := Vector2.ZERO
var bones := true
var checker := true
var onion := false
var dragging := false
var panning := false
var drag_origin := Vector2.ZERO
var last_offset := Vector2.ZERO
var bounds := Rect2(-20, -40, 40, 48)
var auto_fit := true

func _ready() -> void:
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	ghost = View.new()
	ghost.modulate = Color(0.4, 0.75, 0.65, 0.25)
	add_child(ghost)
	view = View.new()
	add_child(view)
	resized.connect(queue_redraw)

func origin() -> Vector2:
	return (size * 0.5 - bounds.get_center() * zoom).round() + pan

func update_view(model: Dictionary, textures: Dictionary, action: String, frame: int) -> void:
	var transforms := Character.transforms(model, {}, 0)
	var first := true
	for p in model.get("parts", []):
		if not transforms.has(p.id) or not textures.has(p.asset): continue
		var tex: Texture2D = textures[p.asset]
		for point in [Vector2.ZERO, Vector2(tex.get_width(), 0), tex.get_size(), Vector2(0, tex.get_height())]:
			var pos: Vector2 = transforms[p.id] * (point - Character.vec(p.pivot))
			if first:
				bounds = Rect2(pos, Vector2.ZERO)
				first = false
			else: bounds = bounds.expand(pos)
	if auto_fit:
		zoom = clampi(int(minf((size.x - 64) / maxf(1, bounds.size.x), (size.y - 64) / maxf(1, bounds.size.y))), 1, 8)
	view.model = model
	view.textures = textures
	view.action_id = action
	view.frame = frame
	view.position = origin()
	view.scale = Vector2(zoom, zoom)
	view.queue_redraw()
	ghost.model = model
	ghost.textures = textures
	ghost.action_id = action
	ghost.frame = maxi(0, frame - 1)
	ghost.position = view.position
	ghost.scale = view.scale
	ghost.visible = onion
	ghost.queue_redraw()
	queue_redraw()

func _draw() -> void:
	# Refined canvas background with better contrast
	draw_rect(Rect2(Vector2.ZERO, size), Color("2a2f33"))

	# Subtle checkerboard pattern
	if checker:
		for y in range(0, int(size.y), 24):
			for x in range(0, int(size.x), 24):
				if (x / 24 + y / 24) % 2 == 0:
					draw_rect(Rect2(x, y, 24, 24), Color("2f3538"))

	var o := origin()

	# Draw grid axes with refined colors
	draw_line(Vector2(0, o.y), Vector2(size.x, o.y), Color("454d52"), 1.5)
	draw_line(Vector2(o.x, 0), Vector2(o.x, size.y), Color("3d4549"), 1.5)

	if view == null:
		return

	view.position = o
	ghost.position = o
	var transforms := Character.transforms(view.model, Character.find_action(view.model, view.action_id), view.frame)

	# Draw bone connections with improved visibility
	for p in view.model.get("parts", []):
		if not transforms.has(p.id):
			continue
		var t: Transform2D = transforms[p.id]
		var pos: Vector2 = o + t.origin * zoom

		if bones:
			# Draw parent connection line
			if transforms.has(p.parent):
				var parent_pos := o + transforms[p.parent].origin * zoom
				draw_line(parent_pos, pos, ThemeKit.ACCENT.lightened(0.2), 2.0, true)

			# Draw joint point with better styling
			draw_circle(pos, 4, ThemeKit.ACCENT)
			draw_circle(pos, 4, ThemeKit.ACCENT_PRESSED, false, 1.5)

		# Enhanced selection highlight
		if p.id == selected and view.textures.has(p.asset):
			var tex: Texture2D = view.textures[p.asset]
			var corners := PackedVector2Array()
			for point in [Vector2.ZERO, Vector2(tex.get_width(), 0), tex.get_size(), Vector2(0, tex.get_height()), Vector2.ZERO]:
				corners.append(o + (t * (point - Character.vec(p.pivot))) * zoom)

			# Draw selection bounds with accent color
			draw_polyline(corners, ThemeKit.ACCENT, 2.0, true)

			# Draw pivot crosshair with warm accent
			var pivot_color := Color("f5a962")
			draw_line(pos - Vector2(6, 0), pos + Vector2(6, 0), pivot_color, 2.5)
			draw_line(pos - Vector2(0, 6), pos + Vector2(0, 6), pivot_color, 2.5)
			draw_circle(pos, 2, pivot_color)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			auto_fit = false
			zoom = clampi(zoom + (1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1), 1, 20)
			view.scale = Vector2(zoom, zoom)
			ghost.scale = view.scale
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			panning = event.pressed
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var hit := hit_test((event.position - origin()) / zoom)
				if not hit.is_empty():
					selected = hit
					part_selected.emit(hit)
					dragging = true
					drag_origin = event.position
					last_offset = Vector2.ZERO
					drag_started.emit()
			elif dragging:
				dragging = false
				drag_finished.emit()
	if event is InputEventMouseMotion:
		if panning:
			pan += event.relative
			queue_redraw()
		if dragging:
			var offset: Vector2 = ((event.position - drag_origin) / zoom).round()
			if offset != last_offset:
				part_dragged.emit(selected, offset - last_offset)
				last_offset = offset

func hit_test(pos: Vector2) -> String:
	var transforms := Character.transforms(view.model, Character.find_action(view.model, view.action_id), view.frame)
	var parts: Array = view.model.get("parts", []).duplicate()
	parts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.z) > int(b.z))
	for p in parts:
		if not p.visible or not transforms.has(p.id) or not view.textures.has(p.asset):
			continue
		var local: Vector2 = transforms[p.id].affine_inverse() * pos + Character.vec(p.pivot)
		var img: Image = view.textures[p.asset].get_image()
		if Rect2(Vector2.ZERO, img.get_size()).has_point(local) and img.get_pixelv(Vector2i(local)).a > 0.1:
			return p.id
	return ""
