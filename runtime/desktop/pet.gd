extends Node2D

const Store = preload("res://services/project_store.gd")
const View = preload("res://runtime/shared/character_view.gd")
const Character = preload("res://core/character.gd")
const Router = preload("res://core/input_router.gd")

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
	menu = PopupMenu.new()
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
	if not Character.find_action(doc.model, command).is_empty():
		action_id = command
		action_clock = 0

func _process(delta: float) -> void:
	if view == null: return
	elapsed += delta
	action_clock += delta
	for command in router.advance(elapsed): execute(command)
	var window := get_window()
	var moving := router.movement()
	if dragging:
		window.position = DisplayServer.mouse_get_position() - drag_offset
		window_position = Vector2(window.position)
	elif not menu.visible:
		if wander and moving == Vector2.ZERO: moving.x = direction
		window_position += moving * 90 * delta
		var screen := DisplayServer.screen_get_usable_rect(window.current_screen)
		window_position.x = clampf(window_position.x, screen.position.x - 90, screen.end.x - window.size.x + 90)
		window_position.y = clampf(window_position.y, screen.position.y - 90, screen.end.y - window.size.y + 60)
		window.position = Vector2i(window_position.round())
		if window.position.x <= screen.position.x - 90 or window.position.x + window.size.x >= screen.end.x + 90: direction *= -1
	if moving.x != 0: view.mirrored = moving.x < 0
	if action_id in ["idle", "walk"]: action_id = "walk" if moving != Vector2.ZERO else "idle"
	var clip := Character.find_action(doc.model, action_id)
	if action_clock * float(clip.get("fps", 8)) >= int(clip.get("frames", 8)) and action_id not in ["idle", "walk"]:
		action_id = "walk" if wander else "idle"
		action_clock = 0
		clip = Character.find_action(doc.model, action_id)
	view.action_id = action_id
	view.frame = int(action_clock * float(clip.get("fps", 8))) % maxi(1, int(clip.get("frames", 8)))
	view.queue_redraw()
	update_mouse_region()

func update_mouse_region() -> void:
	var clip := Character.find_action(doc.model, action_id)
	var transforms := Character.transforms(doc.model, clip, view.frame)
	var points := PackedVector2Array()
	for p in doc.model.parts:
		if not p.visible or not transforms.has(p.id): continue
		var asset := str(Character.pose(clip, p.id, view.frame).get("asset", p.asset))
		if not doc.images.has(asset): continue
		var used: Rect2i = doc.images[asset].get_used_rect()
		for corner in [Vector2(used.position), Vector2(used.end.x, used.position.y), Vector2(used.end), Vector2(used.position.x, used.end.y)]:
			var pos: Vector2 = transforms[p.id] * (corner - Character.vec(p.pivot))
			if view.mirrored: pos.x = -pos.x
			points.append(view.position + pos * view.scale)
	if points.size() >= 3:
		DisplayServer.window_set_mouse_passthrough(Geometry2D.convex_hull(points))

func _input(event: InputEvent) -> void:
	if view == null: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if dragging:
				drag_offset = DisplayServer.mouse_get_position() - get_window().position
				execute("wave")
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			menu.position = DisplayServer.mouse_get_position()
			menu.popup()
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			for command in router.feed("MouseLeft" if event.button_index == MOUSE_BUTTON_LEFT else "MouseRight", event.pressed, elapsed): execute(command)
	if event is InputEventKey and not event.echo:
		if event.pressed and event.keycode == KEY_ESCAPE: get_tree().quit()
		for command in router.feed(OS.get_keycode_string(event.keycode), event.pressed, elapsed): execute(command)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		router.clear()
		dragging = false
