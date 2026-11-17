extends SceneTree

const Character = preload("res://core/character.gd")
const Store = preload("res://services/project_store.gd")
const ThemeKit = preload("res://editor/theme.gd")
const Exporter = preload("res://exporters/package_exporter.gd")

var app: Control
var passed := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func expect(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS ", message)
	else:
		failures.append(message)
		push_error("FAIL " + message)

func click_at(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.global_position = position
		event.pressed = pressed
		root.push_input(event)
	await process_frame
	await process_frame

func stroke(point: Vector2i, color: Color) -> void:
	app.pixel.color = color
	await click_at(app.pixel.global_position + app.pixel.origin() + (Vector2(point) + Vector2(0.5, 0.5)) * app.pixel.zoom)

func image_at(action_id: String, frame: int) -> Image:
	var part: Dictionary = app.doc.model.parts[0]
	var pose := Character.pose(Character.find_action(app.doc.model, action_id), part.id, frame)
	return app.doc.images[str(pose.get("asset", part.asset))] as Image

func internal_controls(node: Node) -> Array[Control]:
	var result: Array[Control] = []
	if node is Control: result.append(node)
	for child in node.get_children(true): result.append_array(internal_controls(child))
	return result

func contrast(a: Color, b: Color) -> float:
	var first := a.srgb_to_linear().get_luminance()
	var second := b.srgb_to_linear().get_luminance()
	return (maxf(first, second) + 0.05) / (minf(first, second) + 0.05)

func _run() -> void:
	root.size = Vector2i(1280, 800)
	app = load("res://editor/main.tscn").instantiate()
	root.add_child(app)
	app.new_character("empty")
	app.add_part()
	var id: String = app.selected
	var part := Character.find_part(app.doc.model, id)
	part.position = [0, 0]
	part.pivot = [0, 0]
	app.doc.images[part.asset].fill(Color("263642"))
	app.doc.refresh_textures()
	app.set_mode(1)
	await process_frame
	await process_frame
	var original := image_at("idle", 0).get_data()
	app.seek(1)
	app.pixel.pan = Vector2(17, -11)
	await stroke(Vector2i(2, 2), Color("f18b80"))
	expect(image_at("idle", 1).get_pixel(2, 2).is_equal_approx(Color("f18b80")), "current frame accepts pixel stroke")
	expect(image_at("idle", 0).get_data() == original, "previous frame pixels preserved")
	expect(image_at("idle", 2).get_data() == original, "following held frame pixels preserved")
	expect(app.doc.images[Character.find_part(app.doc.model, id).asset].get_data() == original, "base image preserved")
	expect(app.pixel.pan == Vector2(17, -11), "frame isolation preserves drawing pan")
	var image_count: int = app.doc.images.size()
	await stroke(Vector2i(3, 3), Color("8ecfbe"))
	expect(app.doc.images.size() == image_count, "further strokes reuse isolated image")
	var undo_count: int = app.history.undo_stack.size()
	await stroke(Vector2i(3, 3), Color("8ecfbe"))
	expect(app.history.undo_stack.size() == undo_count and app.doc.images.size() == image_count, "unchanged stroke creates no history or image")
	app.undo()
	expect(image_at("idle", 1).get_pixel(2, 2).is_equal_approx(Color("f18b80")), "undo retains earlier stroke")
	expect(image_at("idle", 1).get_pixel(3, 3).is_equal_approx(Color("263642")), "undo removes only latest stroke")
	app.undo()
	expect(image_at("idle", 1).get_data() == original, "one undo restores first stroke and frame isolation together")
	app.redo()
	app.redo()
	expect(image_at("idle", 1).get_pixel(3, 3).is_equal_approx(Color("8ecfbe")), "redo restores isolated pixels")
	app.pixel.tool = "eraser"
	await stroke(Vector2i(2, 2), Color.WHITE)
	expect(image_at("idle", 1).get_pixel(2, 2).a == 0, "eraser edits current frame")
	expect(image_at("idle", 0).get_data() == original, "eraser preserves other frames")
	app.undo()
	app.seek(2)
	app.pixel.tool = "fill"
	await stroke(Vector2i(0, 0), Color("9296b0"))
	expect(image_at("idle", 2).get_pixel(15, 15).is_equal_approx(Color("9296b0")), "fill edits independent frame")
	expect(image_at("idle", 3).get_data() == original, "fill preserves following frame")
	app.undo()
	app.pixel.tool = "pencil"
	app.seek(1)
	app.duplicate_action()
	var duplicate_id: String = app.action_id
	app.seek(1)
	await stroke(Vector2i(2, 2), Color("e8bd78"))
	expect(image_at("idle", 1).get_pixel(2, 2).is_equal_approx(Color("f18b80")), "drawing duplicated action preserves original action")
	expect(image_at(duplicate_id, 1).get_pixel(2, 2).is_equal_approx(Color("e8bd78")), "duplicated action gets independent frame")
	app.action_id = "idle"
	app.seek(0)
	app.pixel_frame_edit = false
	await stroke(Vector2i(1, 1), Color("e8bd78"))
	expect(image_at("idle", 2).get_pixel(1, 1).is_equal_approx(Color("e8bd78")), "shared image mode intentionally updates shared frames")
	expect(image_at("idle", 1).get_pixel(1, 1).is_equal_approx(Color("263642")), "shared image edit preserves independent frame")
	app.pixel_frame_edit = true
	app.seek(2)
	app.blank_frame()
	expect(image_at("idle", 2).is_invisible(), "blank frame is transparent")
	expect(not image_at("idle", 3).is_invisible(), "blank frame preserves next exposure")
	app.undo()
	expect(not image_at("idle", 2).is_invisible(), "blank frame can be undone")
	app.copy_previous_frame()
	expect(image_at("idle", 2).get_data() == image_at("idle", 1).get_data(), "previous frame artwork can be copied into current frame")
	await stroke(Vector2i(2, 2), Color("9296b0"))
	expect(image_at("idle", 1).get_pixel(2, 2).is_equal_approx(Color("f18b80")), "copied frame can be redrawn without changing previous frame")
	app.undo()
	app.undo()
	app.seek(3)
	var wide := Image.create(48, 24, false, Image.FORMAT_RGBA8)
	wide.fill(Color.TRANSPARENT)
	wide.fill_rect(Rect2i(32, 4, 12, 12), Color("f18b80"))
	var output := ProjectSettings.globalize_path("res://tests/output/pixel_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(output)
	var path := output.path_join("wide.png")
	wide.save_png(path)
	app.replace_image(path, true)
	expect(image_at("idle", 3).get_data() == wide.get_data(), "frame can use entirely different artwork and dimensions")
	expect(image_at("idle", 4).get_size() == Vector2i(16, 16), "replacing artwork preserves next frame")
	expect(app.stage.hit_test(Vector2(40, 10)) == id, "hit testing uses enlarged frame artwork")
	expect(app.stage.hit_test(Vector2(2, 2)).is_empty(), "transparent swapped pixels do not hit old base artwork")
	expect(app.stage.bounds.has_point(Vector2(47, 23)), "framing includes enlarged frame artwork")
	var bounds: Rect2 = app.stage.bounds
	app.seek(4)
	expect(app.stage.bounds == bounds, "frame changes keep stable camera bounds")
	app.seek(3)
	for node in app.inspector.find_children("*", "Button", true, false):
		if node.text == "裁去透明边缘": expect(node.disabled, "frame mode guards shared pivot crop operation")
	app.resize_dialog()
	var resize: ConfirmationDialog
	for node in app.get_children():
		if node is ConfirmationDialog and node.title == "画布与最近邻重采样": resize = node
	var sizes: Array = resize.find_children("*", "SpinBox", true, false)
	sizes[0].value = 64
	sizes[1].value = 32
	resize.confirmed.emit()
	expect(image_at("idle", 3).get_size() == Vector2i(64, 32), "current frame canvas can grow")
	expect(image_at("idle", 4).get_size() == Vector2i(16, 16), "resizing preserves other frames")
	app.undo()
	app.set_mode(0)
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var rendered := root.get_texture().get_image()
		var at: Vector2 = app.stage.global_position + app.stage.origin() + Vector2(40.5, 10.5) * app.stage.zoom
		expect(rendered.get_pixelv(Vector2i(at)).is_equal_approx(Color("f18b80")), "rendered frame displays swapped pixels")
		rendered.save_png(output.path_join("swapped-frame.png"))
	expect(app.doc.save_to(output.path_join("project")).is_empty(), "independent frame project saves")
	var opened := Store.new()
	expect(opened.open_file(output.path_join("project/character.rigpop.json")).is_empty(), "independent frame project reopens")
	var opened_part: Dictionary = opened.model.parts[0]
	var opened_pose := Character.pose(Character.find_action(opened.model, "idle"), id, 3)
	expect(opened.images[opened_pose.asset].get_data() == wide.get_data(), "saved frame artwork round trips exactly")
	expect(opened.images[opened_part.asset].get_size() == Vector2i(16, 16), "save preserves distinct base artwork")
	var package := Exporter.export_package(app.doc, output, "Godot")
	expect(package.error.is_empty(), "different frame artwork exports to Godot package")
	app.new_character("traveler")
	app.set_mode(1)
	for resolution in [Vector2i(1280, 800), Vector2i(960, 640)]:
		root.size = resolution
		await process_frame
		await process_frame
		var picker: ColorPickerButton = app.inspector.find_children("*", "ColorPickerButton", true, false)[0]
		await click_at(picker.get_global_rect().get_center())
		var panel := picker.get_popup()
		expect(panel.visible, "mouse opens color picker at %s" % resolution)
		var background: StyleBoxFlat = panel.get_theme_stylebox("panel", "PopupPanel")
		expect(background.bg_color == ThemeKit.SURFACE, "color popup uses opaque light background")
		var count := 0
		for control in internal_controls(picker.get_picker()):
			if control is Button and control.text in ["RGB", "HSV", "Linear"]:
				var style: StyleBoxFlat = control.get_theme_stylebox("normal")
				expect(contrast(control.get_theme_color("font_color"), style.bg_color) >= 4.5, "readable color mode: " + control.text)
				count += 1
		expect(count == 3, "all color modes have readable styles")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tests/output/color-picker-%dx%d.png" % [resolution.x, resolution.y])
		panel.hide()
		await process_frame
	print("RESULT: %d passed, %d failed" % [passed, failures.size()])
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
