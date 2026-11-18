extends SceneTree

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
	pet.execute("wave")
	check(pet.action_id == "wave", "pet action command")
	pet.menu_command(1)
	check(pet.wander, "pet wander menu toggle")
	pet.menu_command(1)
	pet.menu_command(2)
	check(not root.always_on_top, "native topmost toggled off")
	pet.menu_command(2)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	pet._input(press)
	check(pet.dragging, "native drag starts")
	var drag_anchor: Vector2 = Vector2(root.position) + pet.view.position
	pet.view.scale = Vector2.ONE * 8
	pet.fit_window()
	pet._process(0)
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
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
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
	for point in pet.artwork_points():
		check(Rect2(Vector2.ZERO, root.size).has_point(pet.view.position + point), "enlarged artwork remains inside native window")
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
	print("DESKTOP_RESULT ", failures.size(), " failures")
	if failures.is_empty(): pet.menu_command(3)
	else: quit(1)
