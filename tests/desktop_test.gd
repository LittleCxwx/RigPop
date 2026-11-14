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
	press.pressed = false
	pet._input(press)
	check(not pet.dragging, "native drag releases")
	pet.router.feed("A", true, pet.elapsed)
	pet._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(pet.router.held.is_empty(), "pet focus loss clears held keys")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		check(img.get_pixel(0, 0).a < 0.01, "desktop background alpha transparent")
		check(img.get_used_rect().size != Vector2i.ZERO, "desktop character pixels rendered")
		img.save_png(ProjectSettings.globalize_path("res://tests/output/desktop_window.png"))
	print("DESKTOP_RESULT ", failures.size(), " failures")
	pet.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
