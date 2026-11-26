extends Node2D

## 桌宠宿主：把角色画在一个无边框、透明、置顶的窗口里。
##
const Store = preload("res://services/project_store.gd")
const View = preload("res://runtime/shared/character_view.gd")
const Character = preload("res://core/character.gd")
const DesktopStates = preload("res://core/desktop_states.gd")
const Router = preload("res://core/input_router.gd")
const ActionPlayer = preload("res://core/action_player.gd")
const Taskbar = preload("res://runtime/desktop/taskbar.gd")
const Keyboard = preload("res://runtime/desktop/keyboard.gd")
const APP_ICON = preload("res://assets/rigpop-icon.png")
const MARK = preload("res://assets/rigpop-mark.png")
const MENU_FONT = preload("res://assets/NotoSansSC-VF.ttf")

enum Mode { PET, FOCUS, FIXED }
const MODE_MENU_START := 10
const BACKGROUND_MOVE_DELAY := 0.2

var doc: RefCounted
var view: Node2D
var menu: PopupMenu
var tray := -1
var dragging := false
var drag_offset := Vector2i.ZERO
var elapsed := 0.0
var action_id := "idle"
var states: Array = []
var state_index := 0
var state_started := 0.0
var watch_menu_clicks := false
var menu_left_down := false
var wander := false
var direction := 1.0
var router := Router.new()
var window_position := Vector2.ZERO
var actions := ActionPlayer.new()
var right_pending := false
var resizing := false
var right_origin := Vector2i.ZERO
var right_scale := 1
var tray_hidden := false
var mode := Mode.PET
var dock: Window
var handle := 0
var foreground_before_focus := 0
var keyboard := Keyboard.new()


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
	handle = DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE)
	Taskbar.hide_from_taskbar(handle)
	get_tree().auto_accept_quit = false
	window.min_size = Vector2i(1, 1)
	window.size = Vector2i(384, 384)
	window.borderless = true
	window.transparent = true
	window.transparent_bg = true
	window.set_flag(Window.FLAG_NO_FOCUS, true)
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
	states = DesktopStates.read(doc.model)
	configure_bindings()
	actions.configure(doc.model)
	build_menu()
	add_child(menu)
	fit_window()
	update_mouse_region()
	_setup_tray.call_deferred()


func build_menu() -> void:
	menu = PopupMenu.new()
	# 轮廓穿透不能排除菜单项，菜单使用原生窗口。
	menu.force_native = true
	var font := FontVariation.new()
	font.base_font = MENU_FONT
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 500.0}
	var menu_theme := Theme.new()
	menu_theme.default_font = font
	menu_theme.default_font_size = 15
	menu.theme = menu_theme
	for label in ["桌宠模式", "聚焦模式", "固定模式"]:
		menu.add_radio_check_item(label, MODE_MENU_START + menu.item_count)
	menu.set_item_checked(0, true)
	menu.add_separator()
	menu.add_item("招手", 0)
	menu.add_check_item("自由漫游", 1)
	menu.set_item_checked(menu.get_item_index(1), wander)
	menu.add_check_item("窗口置顶", 2)
	menu.set_item_checked(menu.get_item_index(2), get_window().always_on_top)
	menu.add_separator()
	menu.add_item("显示桌宠", 5)
	menu.add_item("隐藏到托盘", 4)
	menu.add_separator()
	menu.add_item("退出桌宠", 3)
	menu.set_item_disabled(menu.get_item_index(0), Character.find_action(doc.model, "wave").is_empty())
	menu.id_pressed.connect(menu_command)
	menu.popup_hide.connect(stop_menu_watch)


## 托盘图标：点左键唤回/隐藏窗口，右键弹出同一套菜单。
func _setup_tray() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_STATUS_INDICATOR):
		tray = DisplayServer.create_status_indicator(APP_ICON, "RigPop Pet · " + str(doc.model.name), tray_pressed)
	refresh_menu()


func tray_pressed(mouse_button: int = MOUSE_BUTTON_LEFT, _position: Vector2i = Vector2i.ZERO) -> void:
	if mode == Mode.FIXED: return
	if mouse_button == MOUSE_BUTTON_LEFT:
		show_window(tray_hidden)
	elif mouse_button == MOUSE_BUTTON_RIGHT:
		open_menu()


func show_window(show_it: bool) -> void:
	if not show_it and mode != Mode.FIXED and tray < 0: return
	if tray_hidden == not show_it: return
	if not Taskbar.set_visible(handle, show_it): return
	tray_hidden = not show_it
	clear_interaction()
	refresh_menu()
	if show_it and mode == Mode.FOCUS:
		activate_pet.call_deferred()


func refresh_menu() -> void:
	for i in 3:
		menu.set_item_checked(menu.get_item_index(MODE_MENU_START + i), mode == i)
	menu.set_item_disabled(menu.get_item_index(1), mode == Mode.FIXED)
	menu.set_item_disabled(menu.get_item_index(4), tray_hidden or (tray < 0 and mode != Mode.FIXED) or not Taskbar.available())
	menu.set_item_disabled(menu.get_item_index(5), not tray_hidden)


func open_menu(from_dock: bool = false) -> void:
	if mode == Mode.FIXED and not from_dock: return
	clear_interaction()
	if mode != Mode.FOCUS:
		remember_foreground()
	var parent: Node = dock if from_dock else self
	if menu.get_parent() != parent: menu.reparent(parent)
	menu.position = DisplayServer.mouse_get_position()
	menu.popup()
	if menu.visible and not menu.is_native_menu():
		var menu_handle := DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, menu.get_window_id())
		watch_menu_clicks = Taskbar.watch_menu(handle, menu_handle)
		menu_left_down = Taskbar.key_down(handle, 0x01)


func stop_menu_watch() -> void:
	if watch_menu_clicks: Taskbar.watch_menu(handle, 0)
	watch_menu_clicks = false


func close_menu_on_outside_click() -> void:
	if not menu.visible or menu.is_native_menu(): return
	if watch_menu_clicks:
		if Taskbar.clicked_outside_menu(handle): menu.hide()
	else:
		var left_down := Taskbar.key_down(handle, 0x01)
		if left_down and not menu_left_down:
			if not Rect2i(menu.position, menu.size).has_point(DisplayServer.mouse_get_position()):
				menu.hide()
		menu_left_down = left_down


func remember_foreground() -> void:
	var foreground := Taskbar.other_foreground(handle)
	if foreground != 0: foreground_before_focus = foreground


func activate_pet() -> void:
	if mode != Mode.FOCUS or tray_hidden: return
	if not Taskbar.activate(handle): get_window().grab_focus()


func set_mode(next: Mode) -> void:
	if mode == next:
		if mode == Mode.FOCUS: activate_pet()
		return
	var was_focused := mode == Mode.FOCUS
	if next == Mode.FOCUS: remember_foreground()
	mode = next
	clear_interaction()
	configure_bindings()
	get_window().set_flag(Window.FLAG_NO_FOCUS, mode != Mode.FOCUS)
	get_window().set_flag(Window.FLAG_MOUSE_PASSTHROUGH, mode == Mode.FIXED)
	if mode == Mode.FIXED:
		show_dock()
	elif dock != null:
		dock.hide()
		if tray_hidden: show_window(true)
	if mode == Mode.FOCUS:
		if tray_hidden: show_window(true)
		activate_pet.call_deferred()
	elif was_focused:
		Taskbar.restore_foreground(handle, foreground_before_focus)
	refresh_menu()
	update_mouse_region()


func show_dock() -> void:
	if dock == null:
		dock = Window.new()
		dock.hide()
		dock.title = "RigPop 固定模式"
		dock.force_native = true
		dock.borderless = true
		dock.transparent = true
		dock.transparent_bg = true
		dock.always_on_top = true
		dock.unresizable = true
		dock.set_flag(Window.FLAG_NO_FOCUS, true)
		add_child(dock)
		var button := TextureButton.new()
		button.texture_normal = MARK
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.tooltip_text = "RigPop · 桌宠菜单"
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		dock.add_child(button)
		button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.pressed.connect(open_menu.bind(true))
	const DOCK_SIZE := Vector2i(40, 40)
	var screen := DisplayServer.screen_get_usable_rect(get_window().current_screen)
	dock.size = DOCK_SIZE
	dock.position = Vector2i(screen.position.x + 12, screen.end.y - DOCK_SIZE.y - 12)
	dock.show()
	Taskbar.hide_from_taskbar(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, dock.get_window_id()))


func configure_bindings() -> void:
	router.bindings = []
	var bound_movement := {}
	for binding in doc.model.bindings:
		if binding.gesture == "hold":
			if mode == Mode.FIXED: continue
			bound_movement[str(binding.key).to_upper()] = true
		router.bindings.append(binding)
	if mode != Mode.FIXED:
		for key in DesktopStates.FALLBACK_MOVEMENT:
			if not bound_movement.has(key):
				router.bindings.append({"key": key, "gesture": "hold", "command": DesktopStates.FALLBACK_MOVEMENT[key]})
	var used := {}
	for binding in router.bindings:
		used[str(binding.key).to_upper()] = true
	for i in states.size():
		var code := OS.find_keycode_from_string(str(states[i].key))
		if code == KEY_NONE or code == KEY_ESCAPE: continue
		var key := OS.get_keycode_string(code)
		if used.has(key.to_upper()): continue
		used[key.to_upper()] = true
		router.bindings.append({"key": key, "gesture": "press", "command": DesktopStates.COMMAND_PREFIX + str(i)})
	keyboard.configure(handle, router.bindings if mode != Mode.FOCUS else [])


func clear_interaction() -> void:
	router.clear()
	keyboard.reset()
	dragging = false
	right_pending = false
	resizing = false


func menu_command(id: int) -> void:
	match id:
		0: execute("wave")
		1:
			if mode == Mode.FIXED: return
			wander = not wander
			menu.set_item_checked(menu.get_item_index(1), wander)
		2:
			get_window().always_on_top = not get_window().always_on_top
			menu.set_item_checked(menu.get_item_index(2), get_window().always_on_top)
		3: get_tree().quit()
		4: show_window(false)
		5: show_window(true)
		MODE_MENU_START, MODE_MENU_START + 1, MODE_MENU_START + 2:
			set_mode.call_deferred((id - MODE_MENU_START) as Mode)


func execute(command: String) -> void:
	if not actions.active.is_empty(): return
	if command.begins_with(DesktopStates.COMMAND_PREFIX):
		var next := command.trim_prefix(DesktopStates.COMMAND_PREFIX).to_int()
		if next >= 0 and next < states.size() and next != state_index:
			var was_locked: bool = states[state_index].lock_movement
			state_index = next
			state_started = elapsed
			if was_locked or states[state_index].lock_movement: router.clear()
		return
	var selected: Dictionary = states[state_index]
	var resolved := DesktopStates.resolve(doc.model, selected, command)
	if selected.lock_jump and (DesktopStates.is_jump(command) or DesktopStates.is_jump(resolved)): return
	if actions.play(resolved, DesktopStates.ACTION_LIMIT):
		action_id = resolved
		router.clear()


func _process(delta: float) -> void:
	if view == null: return
	close_menu_on_outside_click()
	if tray_hidden: return
	elapsed += delta
	var accepting_input: bool = actions.active.is_empty()
	actions.advance(delta)
	if mode != Mode.FOCUS and not menu.visible:
		for command in keyboard.poll(router, elapsed, accepting_input): execute(command)
	if accepting_input:
		for command in router.advance(elapsed): execute(command)
	var window := get_window()
	var move_cutoff := elapsed - BACKGROUND_MOVE_DELAY if mode == Mode.PET else INF
	var movement_locked: bool = not actions.active.is_empty() or states[state_index].lock_movement
	var moving: Vector2 = Vector2.ZERO if movement_locked else router.movement(move_cutoff)
	if right_pending: resize_from_pointer(DisplayServer.mouse_get_position())
	if dragging:
		window.position = DisplayServer.mouse_get_position() - drag_offset - Vector2i(view.position.round())
		window_position = Vector2(window.position)
	elif not menu.visible and not right_pending and mode != Mode.FIXED:
		if wander and moving == Vector2.ZERO and not movement_locked: moving.x = direction
	if moving != Vector2.ZERO and not dragging and not right_pending and not menu.visible:
		window_position += moving * 90 * delta
		var screen := DisplayServer.screen_get_usable_rect(window.current_screen)
		window_position.x = clampf(window_position.x, screen.position.x - 90, screen.end.x - window.size.x + 90)
		window_position.y = clampf(window_position.y, screen.position.y - 90, screen.end.y - window.size.y + 60)
		window.position = Vector2i(window_position.round())
		if window.position.x <= screen.position.x - 90 or window.position.x + window.size.x >= screen.end.x + 90: direction *= -1
	if moving.x != 0: view.mirrored = moving.x < 0
	update_pose(moving)
	fit_window()
	view.queue_redraw()
	update_mouse_region()


func update_pose(moving: Vector2) -> void:
	var selected: Dictionary = states[state_index]
	var state_clip := Character.find_action(doc.model, selected.clip)
	var primary := actions.primary()
	var use_state_pose: bool = primary.is_empty() and not selected.overlay and not state_clip.is_empty() and moving == Vector2.ZERO
	var base_id := DesktopStates.resolve(doc.model, selected, "walk" if moving != Vector2.ZERO else "idle")
	var clip := Character.find_action(doc.model, base_id)
	if not primary.is_empty():
		clip = primary.clip
	elif use_state_pose:
		clip = state_clip
	if clip.is_empty() and not doc.model.actions.is_empty():
		clip = doc.model.actions[0]
	base_id = str(clip.get("id", base_id))
	view.action_id = base_id
	view.layers = actions.layers()
	if selected.overlay and not state_clip.is_empty():
		view.layers.push_front({"clip": state_clip, "merge_pose": true,
			"frame": DesktopStates.pose_frame(state_clip, elapsed - state_started)})
	action_id = str(actions.active.back().clip.id) if not actions.active.is_empty() else base_id
	var clock: float = float(primary.clock) if not primary.is_empty() else elapsed
	view.frame = (DesktopStates.pose_frame(clip, elapsed - state_started) if use_state_pose
		else int(clock * float(clip.get("fps", 8))) % maxi(1, int(clip.get("frames", 8))))


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
	if mode == Mode.FIXED: return
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
		open_menu()
	update_mouse_region()


func _input(event: InputEvent) -> void:
	if view == null or tray_hidden or mode == Mode.FIXED or menu.visible: return
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
		if mode != Mode.FOCUS: return
		if event.pressed and event.keycode == KEY_ESCAPE:
			set_mode(Mode.PET)
			return
	var key := Router.key_from_event(event)
	if not key.is_empty() and actions.active.is_empty():
		for command in router.feed(key, event.pressed, elapsed): execute(command)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		clear_interaction()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		# 关窗不退出，改为缩回托盘，避免误点就把桌宠关掉。
		if tray >= 0: show_window(false)
		else: get_tree().quit()

func _exit_tree() -> void:
	stop_menu_watch()
	if tray >= 0:
		DisplayServer.delete_status_indicator(tray)
		tray = -1
