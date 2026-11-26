extends SceneTree

const Taskbar = preload("res://runtime/desktop/taskbar.gd")

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if condition: print("PASS ", message)
	else: failures.append(message); push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var pet: Node2D = load("res://runtime/desktop/pet.tscn").instantiate()
	root.add_child(pet)
	await process_frame
	check(pet.view != null, "real desktop scene loads saved character")
	if pet.view == null: quit(1); return
	check(root.transparent and root.transparent_bg and root.borderless, "transparent borderless native window configured")
	check(root.always_on_top, "native always-on-top applied")
	print("TRAY_ID ", pet.tray)
	if pet.tray >= 0:
		var handle := DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE)
		pet.tray_pressed(MOUSE_BUTTON_LEFT)
		check(pet.tray_hidden and not Taskbar.is_visible(handle), "tray left click hides pet")
		pet.tray_pressed(MOUSE_BUTTON_LEFT)
		check(not pet.tray_hidden and Taskbar.is_visible(handle), "tray left click restores pet")
		pet._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		check(pet.tray_hidden, "closing window hides to tray")
		pet.menu_command(5)
		check(Taskbar.is_visible(handle) and not pet.tray_hidden, "tray menu restores hidden pet")
		check(Taskbar.is_tool_window(handle), "Windows tool-window style applied successfully")
	pet.execute("wave")
	check(pet.action_id == "wave", "pet action command")
	pet.menu_command(1)
	check(pet.wander, "pet wander menu toggle")
	pet.menu_command(1)
	pet.menu_command(2)
	check(not root.always_on_top, "native topmost toggled off")
	if Taskbar.available():
		check(Taskbar.is_tool_window(pet.handle), "topmost toggle preserves tool-window style")
	pet.menu_command(2)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	pet._input(press)
	check(pet.dragging, "native drag starts")
	var drag_anchor: Vector2 = Vector2(root.position) + pet.view.position
	pet.view.scale = Vector2.ONE * 8
	pet.fit_window()
	check((Vector2(root.position) + pet.view.position).is_equal_approx(drag_anchor), "left drag keeps grab anchor when animated window bounds change")
	pet.view.scale = Vector2.ONE * 4
	pet.fit_window()
	press.pressed = false
	pet._input(press)
	check(not pet.dragging, "native drag releases")
	pet.set_process(false)
	pet.actions.configure(pet.doc.model)
	pet.router.bindings = [{"key": "MouseRight", "gesture": "tap", "command": "wave"}]
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	pet._input(press)
	check(pet.right_pending and not pet.menu.visible and not pet.router.held.has("MouseRight"), "right press waits for click or resize and bypasses bindings")
	press.pressed = false
	pet._input(press)
	check(pet.menu.visible and pet.actions.active.is_empty(), "right click opens menu without triggering bound game action")
	check(not pet.menu.is_embedded(), "desktop context menu uses native window outside silhouette passthrough")
	if Taskbar.available() and not pet.menu.is_native_menu():
		check(pet.watch_menu_clicks, "the native menu listens for outside clicks")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		if not pet.menu.is_native_menu():
			pet.menu.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://tests/output/desktop_menu.png"))
	check(pet.menu.get_item_index(3) >= 0, "context menu exposes pet exit")
	pet.menu.hide()
	await process_frame
	press.pressed = true
	pet._input(press)
	var anchor: Vector2 = Vector2(root.position) + pet.view.position
	var start_scale: int = int(pet.view.scale.x)
	pet.resize_from_pointer(pet.right_origin - Vector2i(0, 60))
	check(int(pet.view.scale.x) == mini(8, start_scale + 2) and pet.resizing, "right upward drag enlarges by integer pixel scale")
	check((Vector2(root.position) + pet.view.position).is_equal_approx(anchor), "resizing preserves character world anchor")
	pet.resize_from_pointer(pet.right_origin - Vector2i(0, 900))
	check(int(pet.view.scale.x) == 8, "resize clamps maximum scale")
	var art_fits := true
	for point in pet.artwork_points():
		art_fits = art_fits and Rect2(Vector2.ZERO, root.size).has_point(pet.view.position + point)
	check(art_fits, "enlarged artwork remains inside native window")
	press.pressed = false
	pet._input(press)
	check(not pet.menu.visible and not pet.right_pending and pet.actions.active.is_empty(), "right resize releases without opening menu or triggering action")
	press.pressed = true
	pet._input(press)
	pet.resize_from_pointer(pet.right_origin + Vector2i(0, 900))
	check(int(pet.view.scale.x) == 1, "right downward drag shrinks to minimum pixel scale")
	press.pressed = false
	pet._input(press)
	pet.view.scale = Vector2.ONE * 4
	pet.fit_window()
	pet.router.feed("A", true, pet.elapsed)
	pet._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(pet.router.held.is_empty(), "pet focus loss clears held keys")
	check(not pet.right_pending and not pet.resizing, "pet focus loss cancels resize state")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		check(img.get_pixel(0, 0).a < 0.01, "desktop background alpha transparent")
		check(img.get_used_rect().size != Vector2i.ZERO, "desktop character pixels rendered")
		img.save_png(ProjectSettings.globalize_path("res://tests/output/desktop_window.png"))
		check(root.get_flag(Window.FLAG_NO_FOCUS), "pet mode leaves keyboard focus with other apps")
		pet.configure_bindings()
		pet.router.feed("A", true, pet.elapsed)
		check(pet.router.movement(pet.elapsed - pet.BACKGROUND_MOVE_DELAY) == Vector2.ZERO, "ordinary typing does not start background movement")
		check(pet.router.movement(pet.elapsed) == Vector2.LEFT, "holding a movement key reaches the background movement threshold")
		pet.set_mode(pet.Mode.FOCUS)
		check(not root.get_flag(Window.FLAG_NO_FOCUS), "focus mode accepts keyboard focus")
		if Taskbar.available():
			check(Taskbar.is_tool_window(pet.handle), "focus-mode switch preserves tool-window style")
		check(pet.router.bindings.any(func(binding: Dictionary) -> bool:
			return binding.key == "A" and binding.gesture == "hold"), "focus mode includes WASD movement")
		pet.set_mode(pet.Mode.FIXED)
		check(root.get_flag(Window.FLAG_MOUSE_PASSTHROUGH), "fixed mode passes clicks through the entire pet window")
		check(pet.dock.visible and not pet.dock.is_embedded(), "fixed mode has a separate native icon")
		if Taskbar.available():
			var dock_handle := DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, pet.dock.get_window_id())
			check(Taskbar.is_tool_window(pet.handle) and Taskbar.is_tool_window(dock_handle), "pet and fixed icon both stay off the taskbar")
		pet.wander = true
		var locked_anchor: Vector2 = Vector2(root.position) + pet.view.position
		pet._process(0.15)
		check((Vector2(root.position) + pet.view.position).is_equal_approx(locked_anchor), "fixed mode pauses wandering")
		press.pressed = true
		pet._input(press)
		check(not pet.right_pending and not pet.dragging and not pet.menu.visible, "fixed mode ignores right button input on pet")
		pet.show_window(false)
		pet.open_menu(true)
		check(pet.tray_hidden and pet.dock.visible and pet.menu.visible, "fixed icon still opens menu while pet is hidden")
		pet.menu.hide()
		pet.menu_command(5)
		pet.set_mode(pet.Mode.PET)
		check(not pet.tray_hidden and not pet.dock.visible and not root.get_flag(Window.FLAG_MOUSE_PASSTHROUGH), "returning to pet mode restores normal mouse interaction")
	if pet.states.size() >= 4:
		check_oc_states(pet)
	print("DESKTOP_RESULT ", failures.size(), " failures")
	if failures.is_empty(): pet.menu_command(3)
	else: quit(1)

func check_oc_states(pet: Node2D) -> void:
	pet.set_process(false)
	pet.set_mode(pet.Mode.FOCUS)
	pet.wander = false
	pet.actions.configure(pet.doc.model)
	var key := InputEventKey.new()
	key.keycode = KEY_2
	key.pressed = true
	pet._input(key)
	check(pet.state_index == 1, "state key switches on key-down")
	key.pressed = false
	pet._input(key)
	pet._process(1.2)
	check(pet.state_index == 1 and pet.view.layers[0].clip.id == "happy", "happy pose is persistent")
	pet.execute("jump")
	pet._process(0.3)
	var clock: float = pet.actions.active[0].clock
	pet.execute("jump")
	pet.execute("state:2")
	check(pet.action_id == "jump_happy" and pet.actions.active[0].clock == clock and pet.state_index == 1,
		"repeated jump and state changes cannot interrupt a one-shot")
	key.keycode = KEY_A
	key.pressed = true
	pet._input(key)
	pet._process(0.6)
	check(pet.actions.active.is_empty() and pet.state_index == 1 and not pet.router.held.has("A")
		and pet.view.layers[0].clip.id == "happy", "action restores happy and discards keys pressed during playback")
	key.pressed = false
	pet._input(key)
	pet.execute("state:2")
	pet.execute("jump")
	check(pet.action_id == "jump_angry", "angry uses a different jump")
	pet._process(1.0)
	pet.execute("state:3")
	var seated_anchor: Vector2 = Vector2(root.position) + pet.view.position
	key.pressed = true
	pet._input(key)
	pet.wander = true
	pet._process(0.7)
	check((Vector2(root.position) + pet.view.position).is_equal_approx(seated_anchor) and pet.view.action_id == "seated",
		"sitting keeps its pose and blocks WASD and wandering")
	key.keycode = KEY_SPACE
	pet._input(key)
	key.pressed = false
	pet._input(key)
	pet.execute("jump_happy")
	check(pet.actions.active.is_empty() and pet.view.action_id == "seated", "sitting blocks Space and direct jump variants")
	pet.wander = false
	pet.execute("state:0")
	check(pet.router.held.is_empty(), "standing clears movement that was held while seated")
	var long_clip: Dictionary = pet.doc.model.actions.filter(func(clip: Dictionary) -> bool: return clip.id == "jump")[0]
	long_clip.frames = 80
	long_clip.fps = 8
	pet.execute("jump")
	check(not pet.actions.active.is_empty(), "standing re-enables jumping")
	pet._process(4.9)
	check(not pet.actions.active.is_empty() and pet.view.frame > 70, "long one-shot plays through its frames within the five-second cap")
	pet._process(0.1)
	check(pet.actions.active.is_empty(), "long one-shot releases input by five seconds")
