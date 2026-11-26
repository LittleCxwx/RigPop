extends SceneTree

const Character = preload("res://core/character.gd")
const Templates = preload("res://services/templates.gd")
const Reader = preload("res://services/psd_reader.gd")
const Mapper = preload("res://services/psd_mapper.gd")
const Rig = preload("res://core/rig.gd")
const Presets = preload("res://core/presets.gd")
const PresetStore = preload("res://services/preset_store.gd")
const Store = preload("res://services/project_store.gd")
const Exporter = preload("res://exporters/package_exporter.gd")
var failures: Array[String] = []
var passed := 0

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
	var output := ProjectSettings.globalize_path("res://tests/output/rig_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(output)
	var cat := Templates.make("lingxi")
	check(cat.model.parts.size() == 11 and cat.model.actions.size() == 9, "default character has all rig parts and presets")
	check(Character.validate(cat.model).is_empty(), "cat template validates")
	check(cat.save_to(output.path_join("lingxi")).is_empty(), "animated cat fixture saved")
	check(Rig.detect(Templates.make("slime").model).is_empty(), "freeform slime is not inferred as a humanoid")
	check(Rig.guess_role("左臂") == "arm_l" and Rig.guess_role("右脚") == "leg_r", "Chinese names map to stable sides")
	check(Rig.guess_role("foot_l") == "foot_l", "exact canonical roles take priority over partial names")
	var unassigned: Dictionary = Templates.make("traveler").model
	unassigned.parts[0].role = ""
	check(not Rig.role_map(unassigned).has("body"), "explicitly unassigned part does not fall back to its ID")
	var reader := Reader.new()
	var source := ProjectSettings.globalize_path("res://tests/output/psd/case_1.psd")
	var error := reader.load_file(source)
	check(error.is_empty(), "bundled helper decodes PSD: " + error)
	if not error.is_empty(): quit(1); return
	check(reader.layers.size() == 4 and reader.layers[0].group == "角色", "reader preserves layers and group names")
	var entries := Mapper.assign(reader.layers, Rig.BIPED)
	check(not reader.layers[0].has("role"), "automatic matching does not mutate decoder output")
	entries[3].role = ""
	var model := Mapper.build_model(entries, Rig.BIPED, "Imported")
	model.actions = [Character.action("idle", "待机", 8)]
	model.bindings = []
	check(Character.validate(model).is_empty(), "partial rig with ordinary decoration has no dangling parents")
	check(not model.parts[3].visible, "hidden PSD layers remain hidden")
	var transforms := Character.transforms(model, {}, 0)
	var reference := Vector2.INF
	var aligned := true
	for i in entries.size():
		var p: Dictionary = model.parts[i]
		var drawn: Vector2 = transforms[p.id] * -Character.vec(p.pivot)
		var offset := drawn - Vector2(entries[i].position)
		if i == 0: reference = offset
		else: aligned = aligned and offset.is_equal_approx(reference)
	check(aligned, "all source layer positions preserved at non-template canvas size")
	var isolated := [entries[1].duplicate()]
	var sparse := Mapper.build_model(isolated, Rig.BIPED, "Head only")
	sparse.actions = [Character.action("idle", "待机")]
	sparse.bindings = []
	check(Character.validate(sparse).is_empty() and sparse.parts[0].parent.is_empty(), "missing parent resolves to character origin")
	var app: Control = load("res://editor/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.new_character("lingxi")
	if DisplayServer.get_name() != "headless":
		for size in [Vector2i(960, 640), Vector2i(1280, 800), Vector2i(1920, 1080)]:
			root.size = size
			await process_frame
			await RenderingServer.frame_post_draw
			var framed := Rect2(app.stage.origin() + app.stage.bounds.position * app.stage.zoom, app.stage.bounds.size * app.stage.zoom)
			check(Rect2(Vector2.ZERO, app.stage.size).encloses(framed), "large character fits resized workspace " + str(size))
			root.get_texture().get_image().save_png(output.path_join("lingxi_%dx%d.png" % [size.x, size.y]))
	var old_id: String = app.doc.model.id
	app.apply_psd(source, reader, entries, Rig.BIPED)
	check(app.doc.model.parts.size() == 4 and app.doc.model.rig == Rig.BIPED, "editor imports selected rig and every chosen layer")
	check(app.doc.model.bindings[0].command == "move_left", "PSD import retains movement commands")
	check(app.doc.sources.size() == 1 and app.doc.path.is_empty(), "PSD source retained in new editable project")
	var imported: Dictionary = app.doc.snapshot()
	app.undo()
	check(app.doc.model.id == old_id and app.doc.sources.is_empty(), "PSD import undone as one operation")
	app.redo()
	check(app.doc.model.id == imported.model.id and app.doc.sources.size() == 1, "PSD import redo restores artwork and source")
	check(app.doc.save_to(output.path_join("editable")).is_empty(), "editable imported character saves with PSD source")
	var opened := Store.new()
	check(opened.open_file(output.path_join("editable/character.rigpop.json")).is_empty() and opened.sources.size() == 1, "imported source and artwork reopen together")
	var exported := Exporter.export_package(app.doc, output, "Godot")
	check(exported.error.is_empty(), "imported character exports to independent Godot project")
	check(not DirAccess.dir_exists_absolute(str(exported.path).path_join("characters/%s/sources" % app.doc.model.id)), "runtime export excludes original PSD")
	var action := Character.find_action(app.doc.model, "walk")
	check(PresetStore.save_clip(action, app.doc.model, output.path_join("presets")).is_empty(), "custom motion saved as role preset")
	var reused := PresetStore.load_clips(output.path_join("presets"), Templates.make("traveler").model)
	check(reused.size() == 1 and reused[0].tracks.has("arm_l"), "custom preset retargets to different part IDs")
	var invalid := action.duplicate(true)
	invalid.tracks.values()[0][0].asset = "assets/external.png"
	check(not PresetStore.save_clip(invalid, app.doc.model, output.path_join("presets")).is_empty(), "texture-dependent action cannot become broken shared preset")
	var dialog := preload("res://editor/psd_import_dialog.gd").new()
	dialog.setup(reader, source)
	app.add_child(dialog)
	dialog.popup_centered(Vector2i(660, 480))
	await process_frame
	var pickers := dialog.find_children("*", "OptionButton", true, false)
	var rig_picker: OptionButton = pickers[0]
	rig_picker.select(1)
	rig_picker.item_selected.emit(1)
	check(dialog.rig == Rig.BIPED and dialog.entries.size() == 4, "rig selection updates dialog state used by confirmation")
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(960, 640)
		await process_frame
		dialog.popup_centered(Vector2i(660, 480))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("psd_mapping.png"))
	for entry in dialog.entries: entry.role = "body"
	dialog.confirm_mapping()
	check(not dialog.error_label.text.is_empty(), "duplicate role mapping keeps dialog open with error")
	dialog.queue_free()
	app.queue_free()
	await process_frame
	print("RIG_IMPORT_RESULT ", passed, " passed, ", failures.size(), " failed")
	print("RIG_IMPORT_OUTPUT ", output)
	quit(0 if failures.is_empty() else 1)
