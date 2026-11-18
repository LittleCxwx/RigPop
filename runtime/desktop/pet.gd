extends Node2D

const Store = preload("res://services/project_store.gd")
const View = preload("res://runtime/shared/character_view.gd")
const Character = preload("res://core/character.gd")
const Router = preload("res://core/input_router.gd")
const ActionPlayer = preload("res://core/action_player.gd")

var doc: RefCounted
var view: Node2D
var menu: PopupMenu
var dragging := false
var drag_offset := Vector2i.ZERO
var elapsed := 0.0
var action_clock := 0.0
var action_id := "idle"
var wander := false
var direction := 1.0
var router := Router.new()
var window_position := Vector2.ZERO
var actions := ActionPlayer.new()
var right_pending := false
var resizing := false
var right_origin := Vector2i.ZERO
var right_scale := 1

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var path := OS.get_executable_path().get_base_dir().path_join("character/character.rigpop.json")
	for i in range(args.size() - 1):
		if args[i] == "--character": path = args[i + 1]
	doc = Store.new()
	var error: String = doc.open_file(path)
	if not error.is_empty():
		push_error(error)
		get_tree().quit(1)
		return
	var window := get_window()
	window.min_size = Vector2i(1, 1)
	window.size = Vector2i(384, 384)
	window.borderless = true
	window.transparent = true
	window.transparent_bg = true
	window.always_on_top = bool(doc.model.desktop.always_on_top)
	window.title = "RigPop Pet · " + str(doc.model.name)
	get_viewport().transparent_bg = true
	RenderingServer.set_default_clear_color(Color.TRANSPARENT)
	var screen := DisplayServer.screen_get_usable_rect()
	window.position = screen.position + screen.size - window.size - Vector2i(60, 30)
	window_position = Vector2(window.position)
	view = View.new()
	view.model = doc.model
	view.textures = doc.textures
	view.scale = Vector2.ONE * int(doc.model.desktop.scale)
	view.position = Vector2(192, 300)
	add_child(view)
	wander = bool(doc.model.desktop.wander)
	router.bindings = doc.model.bindings
	actions.configure(doc.model)
	menu = PopupMenu.new()
	# The pet's silhouette passthrough must not exclude context-menu items.
	menu.force_native = true
	var font := FontVariation.new()
	font.base_font = load("res://assets/NotoSansSC-VF.ttf")
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 500.0}
	var menu_theme := Theme.new()
	menu_theme.default_font = font
	menu_theme.default_font_size = 15
	menu.theme = menu_theme
	menu.add_item("招手", 0)
	menu.add_check_item("自由漫游", 1)
	menu.set_item_checked(1, wander)
	menu.add_check_item("窗口置顶", 2)
	menu.set_item_checked(2, window.always_on_top)
	menu.add_separator()
	menu.add_item("退出桌宠", 3)
	menu.id_pressed.connect(menu_command)
	add_child(menu)
	fit_window()

func menu_command(id: int) -> void:
	match id:
		0: execute("wave")
		1:
			wander = not wander
			menu.set_item_checked(1, wander)
		2:
			get_window().always_on_top = not get_window().always_on_top
			menu.set_item_checked(2, get_window().always_on_top)
		3: get_tree().quit()

func execute(command: String) -> void:
	if actions.play(command):
		action_id = command
		action_clock = 0

func _process(delta: float) -> void:
	if view == null: return
	elapsed += delta
	action_clock += delta
	actions.advance(delta)
	for command in router.advance(elapsed): execute(command)
	var window := get_window()
	var moving := router.movement()
	if actions.blocks_movement(): moving = Vector2.ZERO
	if right_pending: resize_from_pointer(DisplayServer.mouse_get_position())
	if dragging:
		window.position = DisplayServer.mouse_get_position() - drag_offset - Vector2i(view.position.round())
		window_position = Vector2(window.position)
	elif not menu.visible and not right_pending:
		if wander and moving == Vector2.ZERO and not actions.blocks_movement(): moving.x = direction
		window_position += moving * 90 * delta
		var screen := DisplayServer.screen_get_usable_rect(window.current_screen)
		window_position.x = clampf(window_position.x, screen.position.x - 90, screen.end.x - window.size.x + 90)
		window_position.y = clampf(window_position.y, screen.position.y - 90, screen.end.y - window.size.y + 60)
		window.position = Vector2i(window_position.round())
		if window.position.x <= screen.position.x - 90 or window.position.x + window.size.x >= screen.end.x + 90: direction *= -1
	if moving.x != 0: view.mirrored = moving.x < 0
	var primary := actions.primary()
	var base_id: String = str(primary.clip.id) if not primary.is_empty() else ("walk" if moving != Vector2.ZERO else "idle")
	var clip := Character.find_action(doc.model, base_id)
	if clip.is_empty() and not doc.model.actions.is_empty():
		clip = doc.model.actions[0]
		base_id = clip.id
	view.action_id = base_id
	view.layers = actions.layers()
	action_id = str(actions.active.back().clip.id) if not actions.active.is_empty() else base_id
	var clock: float = float(primary.clock) if not primary.is_empty() else elapsed
	view.frame = int(clock * float(clip.get("fps", 8))) % maxi(1, int(clip.get("frames", 8)))
	fit_window()
	view.queue_redraw()
	update_mouse_region()

func artwork_points() -> PackedVector2Array:
	var clip := Character.find_action(doc.model, view.action_id)
	var transforms := Character.transforms(doc.model, clip, view.frame, {}, 0, view.layers)
	var points := PackedVector2Array()
	for p in doc.model.parts:
		var pose := Character.layered_pose(clip, p.id, view.frame, {}, 0, view.layers)
		if not p.visible or not pose.get("visible", true) or not transforms.has(p.id): continue
		var asset := str(pose.get("asset", p.asset))
		if not doc.images.has(asset): continue
		var used: Rect2i = doc.images[asset].get_used_rect()
		if used.size == Vector2i.ZERO: continue
		for corner in [Vector2(used.position), Vector2(used.end.x, used.position.y), Vector2(used.end), Vector2(used.position.x, used.end.y)]:
			var pos: Vector2 = transforms[p.id] * (corner - Character.vec(p.pivot))
			if view.mirrored: pos.x = -pos.x
			points.append(pos * view.scale)
	return points

func fit_window() -> void:
	var points := artwork_points()
	if points.is_empty(): return
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points: bounds = bounds.expand(point)
	bounds = bounds.grow(24)
	var previous := get_window().position
	var origin := Vector2(previous) + view.position
	view.position = -bounds.position.floor()
	get_window().size = Vector2i(bounds.size.ceil()).max(Vector2i(64, 64))
	get_window().position = Vector2i((origin - view.position).round())
	window_position += Vector2(get_window().position - previous)

func update_mouse_region() -> void:
	if dragging or right_pending:
		DisplayServer.window_set_mouse_passthrough(PackedVector2Array())
		return
	var points := artwork_points()
	for i in points.size(): points[i] += view.position
	if points.size() >= 3:
		DisplayServer.window_set_mouse_passthrough(Geometry2D.convex_hull(points))
	else:
		DisplayServer.window_set_mouse_passthrough(PackedVector2Array())

func resize_from_pointer(pointer: Vector2i) -> void:
	if not right_pending: return
	if pointer.distance_to(right_origin) > 6: resizing = true
	if not resizing: return
	var next := clampi(right_scale + roundi(float(right_origin.y - pointer.y) / 30.0), 1, 8)
	if int(view.scale.x) != next:
		view.scale = Vector2.ONE * next
		fit_window()

func finish_right() -> void:
	if not right_pending: return
	var clicked := not resizing
	right_pending = false
	resizing = false
	if clicked:
		router.clear()
		menu.position = DisplayServer.mouse_get_position()
		menu.popup()
	update_mouse_region()

func _input(event: InputEvent) -> void:
	if view == null: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if dragging:
				drag_offset = DisplayServer.mouse_get_position() - get_window().position - Vector2i(view.position.round())
			update_mouse_region()
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				right_pending = true
				resizing = false
				right_origin = DisplayServer.mouse_get_position()
				right_scale = int(view.scale.x)
			else: finish_right()
			update_mouse_region()
			return
	if event is InputEventKey and not event.echo:
		if event.pressed and event.keycode == KEY_ESCAPE: get_tree().quit()
	var key := Router.key_from_event(event)
	if not key.is_empty() and not menu.visible:
		for command in router.feed(key, event.pressed, elapsed): execute(command)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		router.clear()
		dragging = false
		right_pending = false
		resizing = false
