extends SceneTree

const Templates = preload("res://services/templates.gd")
const Character = preload("res://core/character.gd")
const Rig = preload("res://core/rig.gd")
const Store = preload("res://services/project_store.gd")
const Exporter = preload("res://exporters/package_exporter.gd")
const View = preload("res://runtime/shared/character_view.gd")

var passed := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS ", message)
	else:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var output := ProjectSettings.globalize_path("res://tests/output/adventurer_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(output)
	var doc := Templates.make("adventurer")
	check(doc.model.name == "蓝衣冒险家", "CC0 chibi adventurer remains available")
	check(doc.model.rig == Rig.BIPED and doc.model.parts.size() == 9, "nine individually editable biped parts")
	check(Character.validate(doc.model).is_empty(), "new character validates")
	check(doc.model.actions.size() == 8 and doc.images.size() == 11, "six rig motions and two authored facial variants load")
	check(Character.find_part(doc.model, "hair").parent == "head", "rear hair follows the head")
	check(Character.find_part(doc.model, "hand_r").parent == "arm_r", "hand follows its arm")
	var rest := Character.transforms(doc.model, {}, 0)
	var lowest := -INF
	for p in doc.model.parts:
		var image: Image = doc.images[p.asset]
		var bottom := Character.vec(p.pivot)
		for corner in [Vector2.ZERO, Vector2(image.get_width(), 0), Vector2(image.get_size()), Vector2(0, image.get_height())]:
			lowest = maxf(lowest, (rest[p.id] * (corner - bottom)).y)
	check(absf(lowest) < 0.01, "all parts share the author's feet origin")
	var wave := Character.find_action(doc.model, "wave")
	var before: Vector2 = rest.hand_r.origin
	var after: Vector2 = Character.transforms(doc.model, wave, 2).hand_r.origin
	check(before.distance_to(after) > 30, "preset wave moves the complete arm and hand chain")
	var waving := Character.transforms(doc.model, wave, 2)
	check(waving.hand_r.origin.x > waving.head.origin.x + 50, "waving hand clears the head silhouette")
	var jumping := Character.transforms(doc.model, Character.find_action(doc.model, "jump"), 3)
	check(jumping.hand_l.origin.y < jumping.arm_l.origin.y and jumping.hand_r.origin.y < jumping.arm_r.origin.y, "biped jump raises both hands above the shoulders")
	var face := Character.find_action(doc.model, "surprised")
	check(Character.pose(face, "head", 0).asset == "assets/head_surprised.png", "surprised uses the actual authored face")
	check(Character.pose(face, "head", 10).asset == "assets/head.png", "expression returns to the neutral face")
	doc.model.id = "sample_blue_adventurer"
	var sample := ProjectSettings.globalize_path("res://build/examples/blue-adventurer")
	check(doc.save_to(sample).is_empty(), "editable sample saves")
	var reopened := Store.new()
	check(reopened.open_file(sample.path_join("character.rigpop.json")).is_empty(), "editable sample reopens")
	check(reopened.images.size() == 11 and reopened.model.actions.size() == 8, "saved sample retains all motions and face textures")
	var exports := {}
	for target in ["Godot", "桌宠"]:
		var result := Exporter.export_package(doc, output, target)
		check(result.error.is_empty(), "new character exports to " + target)
		exports[target] = result
	var app: Control = load("res://editor/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.new_character("adventurer")
	check(app.doc.model.name == doc.model.name, "editor new-character command loads the new rig")
	if DisplayServer.get_name() != "headless":
		for dimensions in [Vector2i(960, 640), Vector2i(1280, 800), Vector2i(1920, 1080)]:
			root.size = dimensions
			await process_frame
			await RenderingServer.frame_post_draw
			var framed := Rect2(app.stage.origin() + app.stage.bounds.position * app.stage.zoom, app.stage.bounds.size * app.stage.zoom)
			check(Rect2(Vector2.ZERO, app.stage.size).encloses(framed), "new chibi fits workspace " + str(dimensions))
			root.get_texture().get_image().save_png(output.path_join("editor_%dx%d.png" % [dimensions.x, dimensions.y]))
		var viewport := SubViewport.new()
		viewport.size = Vector2i(320, 280)
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var view := View.new()
		view.position = Vector2(160, 252)
		view.model = doc.model
		view.textures = doc.textures
		viewport.add_child(view)
		for clip in doc.model.actions:
			view.action_id = clip.id
			var room := true
			for frame in int(clip.frames):
				view.frame = frame
				view.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				var image := viewport.get_texture().get_image()
				var used := image.get_used_rect()
				room = room and used.has_area() and used.position.x > 1 and used.position.y > 1 and used.end.x < 319 and used.end.y < 279
				image.save_png(output.path_join("%s_%02d.png" % [clip.id, frame]))
			check(room, "nonblank unclipped rendered frames: " + str(clip.id))
		viewport.queue_free()
	app.queue_free()
	await process_frame
	var report := {"passed": passed, "failures": failures, "output": output, "sample": sample, "exports": exports}
	var file := FileAccess.open("res://build/adventurer-verification.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("ADVENTURER_RESULT ", passed, " passed, ", failures.size(), " failed")
	print("ADVENTURER_OUTPUT ", output)
	quit(0 if failures.is_empty() else 1)
