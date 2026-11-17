extends SceneTree

const Character = preload("res://core/character.gd")

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

func find_item(id: String) -> TreeItem:
	var item: TreeItem = app.tree.get_root().get_first_child()
	while item != null:
		if str(item.get_metadata(0)) == id: return item
		item = item.get_next_in_tree()
	return null

func click_part(id: String) -> void:
	var item := find_item(id)
	expect(item != null, "part appears in hierarchy: " + id)
	if item == null: return
	app.tree.scroll_to_item(item)
	await process_frame
	var area: Rect2 = app.tree.get_item_area_rect(item)
	print("CLICK PART ", id)
	await click_at(app.tree.global_position + area.position + Vector2(60, area.size.y / 2))
	expect(app.selected == id, "mouse selects part: " + id)
	expect(str(app.tree.get_selected().get_metadata(0)) == id, "hierarchy selection agrees: " + id)
	expect(app.stage.selected == id and app.timeline.selected == id, "canvas and timeline agree: " + id)
	expect(not app.building, "selection completes refresh: " + id)

func find_button(tip: String) -> Button:
	for node in app.find_children("*", "Button", true, false):
		if node.tooltip_text == tip: return node as Button
	return null

func _run() -> void:
	root.size = Vector2i(1280, 800)
	app = load("res://editor/main.tscn").instantiate()
	root.add_child(app)
	app.new_character("traveler")
	await process_frame
	await process_frame
	var add_button := find_button("添加空白部件")
	expect(add_button != null, "left rail add button exists")
	if "--add-first" in OS.get_cmdline_user_args():
		print("CLICK ADD FIRST")
		await click_at(add_button.get_global_rect().get_center())
		expect(app.doc.model.parts.size() == 8, "mouse adds part to existing character")
	else:
		var fingerprint: String = app.doc.fingerprint()
		await click_part("arm_l")
		await click_part("head")
		expect(app.doc.fingerprint() == fingerprint and app.history.undo_stack.is_empty(), "selection does not edit character or history")
		var names: Array = app.inspector.find_children("*", "LineEdit", false, false)
		var part_name: LineEdit = names[1]
		part_name.grab_focus()
		part_name.text = "Head renamed before selection"
		await click_part("arm_r")
		expect(Character.find_part(app.doc.model, "head").name == "Head renamed before selection", "pending name edit committed before switching parts")
		for i in 12:
			await click_part(["head", "arm_l", "arm_r"][i % 3])
		await click_part("head")
		print("CLICK ADD")
		await click_at(add_button.get_global_rect().get_center())
		expect(app.doc.model.parts.size() == 8, "mouse adds part to existing character")
	var added := Character.find_part(app.doc.model, app.selected)
	expect(not added.is_empty() and added.parent == "head", "new part selected and attached to previous selection")
	expect(find_item(app.selected) != null, "new part appears in hierarchy")
	expect(str(app.tree.get_selected().get_metadata(0)) == app.selected, "added part selected in hierarchy")
	var added_id: String = app.selected
	print("CLICK ADD CHILD")
	await click_at(add_button.get_global_rect().get_center())
	expect(app.doc.model.parts.size() == 9, "repeated mouse add creates another part")
	expect(Character.find_part(app.doc.model, app.selected).parent == added_id, "repeated add attaches to selected new part")
	expect(Character.validate(app.doc.model).is_empty(), "repeated add preserves valid hierarchy")
	app.undo()
	expect(app.doc.model.parts.size() == 8, "undo repeated add")
	app.undo()
	expect(app.doc.model.parts.size() == 7, "added part can be undone")
	app.redo()
	expect(app.doc.model.parts.size() == 8, "added part can be redone")
	app.new_character("empty")
	await process_frame
	await process_frame
	print("CLICK ADD TO EMPTY")
	await click_at(add_button.get_global_rect().get_center())
	expect(app.doc.model.parts.size() == 1, "mouse adds first part to empty character")
	expect(Character.validate(app.doc.model).is_empty(), "added parts leave valid character")
	app.new_character("empty")
	await process_frame
	await process_frame
	var empty_add: Button
	for node in app.inspector.find_children("*", "Button", true, false):
		if node.text == "添加部件": empty_add = node as Button
	expect(empty_add != null, "empty inspector add button exists")
	if empty_add != null:
		print("CLICK EMPTY INSPECTOR ADD")
		await click_at(empty_add.get_global_rect().get_center())
		expect(app.doc.model.parts.size() == 1, "inspector mouse add creates first part")
		expect(Character.validate(app.doc.model).is_empty(), "inspector add preserves valid character")
	if DisplayServer.get_name() != "headless":
		app.new_character("traveler")
		await process_frame
		await click_part("head")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/output/part-interaction-editor.png")
	print("RESULT: %d passed, %d failed" % [passed, failures.size()])
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
