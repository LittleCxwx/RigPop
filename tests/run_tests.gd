extends SceneTree

const Character = preload("res://core/character.gd")
const Templates = preload("res://services/templates.gd")
const Store = preload("res://services/project_store.gd")
const History = preload("res://core/history.gd")
const Router = preload("res://core/input_router.gd")
const Exporter = preload("res://exporters/package_exporter.gd")
var passed := 0
var failures: Array[String] = []
var report := {}
var output := ""

func _initialize() -> void:
	_run.call_deferred()

func expect(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS ", message)
	else:
		failures.append(message)
		push_error("FAIL " + message)

func _run() -> void:
	output = ProjectSettings.globalize_path("res://tests/output/run_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(output)
	var doc := Templates.make()
	expect(Character.validate(doc.model).is_empty(), "human template valid")
	var slime := Templates.make("slime")
	expect(Character.validate(slime.model).is_empty(), "nonhuman template valid")
	expect(slime.model.parts.size() == 2, "nonhuman has no mandatory limbs")
	var bad: Dictionary = doc.model.duplicate(true)
	bad.parts[0].parent = "head"
	expect(not Character.validate(bad).is_empty(), "cyclic hierarchy rejected")
	bad = doc.model.duplicate(true)
	bad.parts[0].asset = "../escape.png"
	expect(not Character.validate(bad).is_empty(), "traversal asset rejected")
	bad = doc.model.duplicate(true)
	bad.id = "../escape"
	expect(not Character.validate(bad).is_empty(), "unsafe character identifier rejected")
	bad = doc.model.duplicate(true)
	bad.parts[0].position = ["x", null]
	expect(not Character.validate(bad).is_empty(), "invalid coordinates rejected")
	bad = doc.model.duplicate(true)
	bad.format_version = 900
	expect(not Character.validate(bad).is_empty(), "future format rejected")
	var clip := Character.find_action(doc.model, "walk")
	expect(Character.pose(clip, "leg_l", 1).rotation == 22, "held key sampling")
	expect(Character.pose(clip, "leg_l", 4).rotation == -22, "exact frame sampling")
	Character.set_key(clip, "head", 1, {"position": [3, 2], "rotation": 0})
	Character.set_key(clip, "head", 1, {"position": [4, 2], "rotation": 0})
	expect(clip.tracks.head.size() == 1, "same frame key replaced")
	var base := Character.transforms(doc.model, clip, 4)
	var overlay := Character.transforms(doc.model, clip, 4, Character.find_action(doc.model, "wave"), 2)
	expect(base.leg_l == overlay.leg_l, "overlay preserves locomotion legs")
	expect(base.arm_r != overlay.arm_r, "overlay affects only keyed arm")
	doc.model.modules["example.unavailable"] = {"future": [1, 2, 3]}
	expect(doc.save_to(output.path_join("project")).is_empty(), "project save")
	expect(not doc.dirty(), "saved state clean")
	var opened := Store.new()
	expect(opened.open_file(output.path_join("project/character.rigpop.json")).is_empty(), "project reopen")
	expect(opened.model.modules["example.unavailable"].future.size() == 3 and int(opened.model.modules["example.unavailable"].future[1]) == 2, "unknown modules preserved")
	var all_assets := true
	for p in opened.model.parts: all_assets = all_assets and opened.images.has(p.asset)
	expect(all_assets, "all referenced assets reopened")
	var left: Dictionary = Character.find_part(opened.model, "arm_l")
	var right: Dictionary = Character.find_part(opened.model, "arm_r")
	expect(left.asset != right.asset, "identical pixels retain independent editable asset identities")
	var reopened_part := Character.find_part(opened.model, "head")
	expect(opened.images[reopened_part.asset].get_data() == doc.images["assets/head.png"].get_data(), "pixel data round trip exact")
	var saved: Dictionary = doc.snapshot()
	doc.model.name = "Changed"
	expect(doc.dirty(), "edit sets dirty")
	var history := History.new()
	history.push(saved, "rename")
	doc.restore(history.undo(doc.snapshot()))
	expect(not doc.dirty(), "undo returns clean saved state")
	doc.restore(history.redo(doc.snapshot()))
	expect(doc.model.name == "Changed", "redo restores edit")
	expect(doc.save_to(output.path_join("project")).is_empty(), "transaction updates existing project")
	expect(FileAccess.file_exists(output.path_join("project/character.rigpop.json.bak")), "previous save retained as backup")
	var different := Templates.make("slime")
	expect(not different.save_to(output.path_join("project")).is_empty(), "save refuses to overwrite different character")
	var fingerprint: String = opened.fingerprint()
	Exporter.write(output.path_join("broken.json"), '{"format_version":900}')
	expect(not opened.open_file(output.path_join("broken.json")).is_empty(), "bad project rejected")
	expect(opened.fingerprint() == fingerprint, "failed open preserves active document")
	var router := Router.new()
	router.bindings = [{"key": "E", "gesture": "tap", "command": "tap"}, {"key": "E", "gesture": "double", "command": "double"}, {"key": "E", "gesture": "long", "command": "long"}, {"key": "A", "gesture": "hold", "command": "move_left"}]
	expect(router.feed("E", true, 0).is_empty(), "press does not prematurely tap")
	expect(router.feed("E", false, 0.1).is_empty(), "tap waits for double window")
	expect(router.feed("E", true, 0.2) == ["double"], "double wins over tap")
	router.feed("E", false, 0.25)
	expect(router.advance(0.8).is_empty(), "double emits no later tap")
	router.clear()
	router.feed("E", true, 1)
	expect(router.advance(1.4) == ["long"], "long press threshold")
	expect(router.advance(1.8).is_empty(), "long fires once")
	expect(router.feed("E", false, 1.9).is_empty(), "long release does not tap")
	router.feed("A", true, 2)
	expect(router.movement() == Vector2.LEFT, "held direction mapped")
	router.clear()
	expect(router.movement() == Vector2.ZERO, "focus clear releases direction")
	router.feed("E", true, 3)
	router.feed("E", false, 3.05)
	expect(router.advance(3.4) == ["tap"], "single tap after window")
	var bundle := Exporter.export_package(doc, output, "Godot")
	expect(bundle.error.is_empty(), "Godot package exported and read back")
	var export_manifest = JSON.parse_string(FileAccess.get_file_as_string(str(bundle.path).path_join("manifest.json")))
	var application_version := str(ProjectSettings.get_setting("application/config/version"))
	expect(export_manifest is Dictionary and export_manifest.get("application_version", "") == application_version, "export manifest uses configured application version")
	expect(FileAccess.get_file_as_string(str(bundle.path).path_join("README.md")).contains("RigPop " + application_version + " /"), "export readme uses configured application version")
	report.godot_package = bundle.path
	expect(FileAccess.file_exists(str(bundle.path).path_join("characters/%s/character.tscn" % doc.model.id)), "instantiable character scene exported")
	var portable := Exporter.export_package(doc, output, "工程")
	expect(portable.error.is_empty(), "editable project copy exported")
	var pet := Exporter.export_package(doc, output, "桌宠")
	if not pet.error.is_empty(): print("PET_EXPORT_ERROR ", pet.error)
	if FileAccess.file_exists("res://build/hosts/RigPopPet.exe"):
		expect(pet.error.is_empty(), "desktop package exported with host")
		report.pet_package = pet.path
	else:
		expect(not pet.error.is_empty(), "missing desktop host reported")
	var app: Control = load("res://editor/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	expect(app.stage.view != null, "editor initialized")
	var coordinates := TextServerManager.get_primary_interface().font_get_variation_coordinates(app.theme.default_font.get_rids()[0])
	expect(int(coordinates.get(2003265652, 0)) == 500, "bundled variable font uses readable weight")
	app.new_character("empty")
	expect(Character.validate(app.doc.model).is_empty(), "empty structure valid")
	app.add_part()
	expect(app.doc.model.parts.size() == 1, "add part")
	app.undo()
	expect(app.doc.model.parts.is_empty(), "undo add part")
	app.redo()
	expect(app.doc.model.parts.size() == 1, "redo add part")
	app.new_character("traveler")
	var sheet := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("8ecfbe"))
	sheet.fill_rect(Rect2i(8, 0, 8, 8), Color("f18b80"))
	var sheet_path := output.path_join("sheet.png")
	sheet.save_png(sheet_path)
	app.accept_image(sheet_path)
	var import_dialog: ConfirmationDialog
	for child in app.get_children():
		if child is ConfirmationDialog and child.title.begins_with("导入预览"): import_dialog = child
	var grid_fields := import_dialog.find_children("*", "SpinBox", true, false)
	grid_fields[0].value = 2
	grid_fields[1].value = 2
	import_dialog.confirmed.emit()
	expect(app.doc.model.parts.size() == 8, "sheet import adds one reusable part")
	expect(Character.find_action(app.doc.model, app.action_id).frames == 4, "sheet creates four ordered texture keys")
	app.undo()
	expect(app.doc.model.parts.size() == 7, "sheet import undone atomically")
	app.new_character("traveler")
	app.selected = "head"
	app.begin_change()
	app.drag_part("head", Vector2(3, -2))
	app.commit_change("drag")
	expect(Character.vec(Character.find_part(app.doc.model, "head").position) == Vector2(3, -13), "stage drag changes bind pose")
	app.undo()
	expect(Character.find_part(app.doc.model, "head").position == [0, -11], "whole drag undo")
	app.key_edit = true
	app.frame = 3
	app.begin_change()
	app.drag_part("head", Vector2(2, -1))
	app.commit_change("key drag")
	expect(Character.vec(Character.pose(Character.find_action(app.doc.model, "idle"), "head", 3).position) == Vector2(2, -1), "key mode drag creates key")
	expect(Character.find_part(app.doc.model, "head").position == [0, -11], "key mode leaves bind pose unchanged")
	app.key_edit = false
	app.set_mode(1)
	await process_frame
	app.select_part("head")
	app.pixel.tool = "pencil"
	app.pixel.color = Color("ff0077")
	var pixel_pos: Vector2 = app.pixel.origin() + Vector2(7.5, 8.5) * app.pixel.zoom
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = pixel_pos
	press.pressed = true
	var old_color: Color = app.pixel.image.get_pixel(7, 8)
	app.pixel._gui_input(press)
	press.pressed = false
	app.pixel._gui_input(press)
	expect(app.pixel.image.get_pixel(7, 8).is_equal_approx(Color("ff0077")), "pixel stroke applied")
	app.undo()
	expect(app.pixel.image.get_pixel(7, 8).is_equal_approx(old_color), "stroke undone atomically")
	app.select_part("head")
	app.isolate_frame()
	var head := Character.find_part(app.doc.model, "head")
	expect(app.current_asset(head) != head.asset, "independent frame asset created")
	app.doc.images[app.current_asset(head)].set_pixel(1, 1, Color.RED)
	expect(not app.doc.images[head.asset].get_pixel(1, 1).is_equal_approx(Color.RED), "frame edit leaves base asset intact")
	app.new_character("traveler")
	app.set_mode(2)
	await process_frame
	var world: Node2D = app.game_world
	app.game_container.grab_focus()
	world.enabled = true
	world.player.enabled = true
	world.player.position = Vector2(166, 180)
	world.player.router.feed("W", true, 0)
	for i in 30:
		world.enabled = true
		world.player.enabled = true
		world.player.router.feed("W", true, 0)
		await physics_frame
	expect(world.player.position.y >= 160, "game obstacle blocks movement")
	expect(world.player.position.y < 180, "game input actually moves character")
	world.player.router.feed("D", true, 0)
	world.clear_input()
	expect(world.player.router.movement() == Vector2.ZERO, "game focus state cleared")
	app.new_character("traveler")
	app.set_mode(0)
	app.seek(0)
	for resolution in [Vector2i(960, 640), Vector2i(1280, 800), Vector2i(1920, 1080)]:
		root.size = resolution
		await process_frame
		await process_frame
		app.responsive()
		await process_frame
		expect(app.stage.size.x >= 240 and app.stage.size.y >= 160, "usable canvas at %s" % resolution)
		expect(app.inspector.get_global_rect().position.x >= app.stage.get_global_rect().end.x, "inspector does not overlap canvas at %s" % resolution)
		var visual_bounds: Rect2 = Rect2(app.stage.origin() + app.stage.bounds.position * app.stage.zoom, app.stage.bounds.size * app.stage.zoom)
		expect(visual_bounds.position.y >= 0 and visual_bounds.end.y <= app.stage.size.y, "whole character framed at %s" % resolution)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("editor_%dx%d.png" % [resolution.x, resolution.y]))
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1280, 800)
		for workspace in [1, 2, 3]:
			app.set_mode(workspace)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("workspace_%d.png" % workspace))
	app.set_mode(0)
	for dpi in [{"size": Vector2i(1280, 800), "scale": 1.25}, {"size": Vector2i(1920, 1080), "scale": 1.5}]:
		root.size = dpi.size
		root.content_scale_factor = dpi.scale
		await process_frame
		await process_frame
		app.responsive()
		await process_frame
		expect(app.stage.size.x >= 240 and app.stage.size.y >= 160, "usable canvas at DPI %s" % dpi.scale)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("dpi_%d.png" % int(float(dpi.scale) * 100)))
	root.content_scale_factor = 1
	report.passed = passed
	report.failures = failures
	report.output = output
	Exporter.write(output.path_join("report.json"), JSON.stringify(report, "\t"))
	Exporter.write(ProjectSettings.globalize_path("res://tests/output/latest.json"), JSON.stringify(report, "\t"))
	print("RESULT: %d passed, %d failed. %s" % [passed, failures.size(), output])
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
