extends SceneTree

const Templates = preload("res://services/templates.gd")
const Character = preload("res://core/character.gd")
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
	var output := ProjectSettings.globalize_path("res://tests/output/kiki_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(output)
	var doc := Templates.make("kiki")
	check(doc.model.name.begins_with("Kiki"), "Kiki template loads its illustration")
	check(Character.validate(doc.model).is_empty(), "Kiki character validates")
	check(doc.model.rig.is_empty() and doc.model.parts.size() == 1, "full illustration does not pretend to have separate limbs")
	check(doc.model.actions.size() == 6, "six authored illustration motions load")
	check(doc.model.modules["rigpop.art"].license == "CC-BY-SA-4.0", "art source and license retained")
	var art: Image = doc.images["assets/body.png"]
	check(art.get_size() == Vector2i(200, 240) and art.get_pixel(0, 0).a == 0, "native alpha and expected runtime dimensions")
	var invalid: Dictionary = doc.model.duplicate(true)
	invalid.game.visual_scale = "bad"
	check(not Character.validate(invalid).is_empty(), "invalid game display scale rejected")
	invalid.game.visual_scale = 0
	check(not Character.validate(invalid).is_empty(), "zero game display scale rejected")
	invalid.game.visual_scale = 9
	check(not Character.validate(invalid).is_empty(), "excessive game display scale rejected")
	doc.model.id = "sample_kiki"
	var sample := ProjectSettings.globalize_path("res://build/examples/kiki")
	check(doc.save_to(sample).is_empty(), "editable Kiki sample saves")
	var reopened := Store.new()
	check(reopened.open_file(sample.path_join("character.rigpop.json")).is_empty(), "saved Kiki reopens")
	check(reopened.model.actions.size() == 6 and reopened.model.modules["rigpop.art"].texture_filter == "linear", "save retains motions, credits and sampling")
	var exports := {}
	for target in ["Godot", "桌宠", "工程"]:
		var result := Exporter.export_package(doc, output, target)
		check(result.error.is_empty(), "Kiki exports to " + target)
		if result.error.is_empty():
			if target == "桌宠":
				check(FileAccess.file_exists(result.path.path_join("platform/windows/bin/rigpop_windows.dll")), "export includes the native library at the descriptor path")
			check(FileAccess.get_file_as_string(result.path.path_join("licenses/Kiki-Attribution.txt")).contains("Tyson Tan"), "export retains author attribution: " + target)
			check(FileAccess.get_file_as_string(result.path.path_join("licenses/CC-BY-SA-4.0.txt")).contains("ShareAlike"), "export includes artwork license: " + target)
		exports[target] = result
	var app: Control = load("res://editor/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	check(app.doc.model.name == "三头身 OC 底模", "editor opens with the editable OC base")
	app.new_character("kiki")
	check(app.doc.model.name.begins_with("Kiki"), "editor can still switch to Kiki")
	if DisplayServer.get_name() != "headless":
		for dimensions in [Vector2i(960, 640), Vector2i(1280, 800), Vector2i(1920, 1080)]:
			root.size = dimensions
			await process_frame
			await RenderingServer.frame_post_draw
			var framed := Rect2(app.stage.origin() + app.stage.bounds.position * app.stage.zoom, app.stage.bounds.size * app.stage.zoom)
			check(Rect2(Vector2.ZERO, app.stage.size).encloses(framed), "full artwork fits workspace " + str(dimensions))
			root.get_texture().get_image().save_png(output.path_join("editor_%dx%d.png" % [dimensions.x, dimensions.y]))
		var viewport := SubViewport.new()
		viewport.size = Vector2i(320, 320)
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var view := View.new()
		view.position = Vector2(160, 290)
		view.model = doc.model
		view.textures = doc.textures
		viewport.add_child(view)
		for clip in doc.model.actions:
			view.action_id = clip.id
			var room := true
			var hashes := {}
			for frame in int(clip.frames):
				view.frame = frame
				view.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				var image := viewport.get_texture().get_image()
				var used := image.get_used_rect()
				room = room and used.has_area() and used.position.x > 1 and used.position.y > 1 and used.end.x < 319 and used.end.y < 319
				hashes[hash(image.get_data())] = true
				image.save_png(output.path_join("%s_%02d.png" % [clip.id, frame]))
			check(room, "nonblank unclipped rendered motion: " + str(clip.id))
			check(hashes.size() > 5, "rendered motion changes across frames: " + str(clip.id))
		check(view.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "HD illustration renders with smooth sampling")
		var pixel := Templates.make("traveler")
		view.model = pixel.model
		view.textures = pixel.textures
		view.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		check(view.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "switching to pixel art restores nearest sampling")
		viewport.queue_free()
		root.size = Vector2i(1280, 800)
		app.set_mode(2)
		await process_frame
		await RenderingServer.frame_post_draw
		check(app.game_world.player.view.scale.is_equal_approx(Vector2.ONE * 0.75), "game preview applies character display scale")
		app.game_world.player.set_physics_process(false)
		root.get_texture().get_image().save_png(output.path_join("game_1280x800.png"))
	app.queue_free()
	await process_frame
	var report := {"passed": passed, "failures": failures, "output": output, "sample": sample, "exports": exports}
	var file := FileAccess.open("res://build/kiki-verification.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("KIKI_RESULT ", passed, " passed, ", failures.size(), " failed")
	print("KIKI_OUTPUT ", output)
	quit(0 if failures.is_empty() else 1)
