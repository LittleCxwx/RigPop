extends SceneTree

const Character = preload("res://core/character.gd")
const ActionPlayer = preload("res://core/action_player.gd")
const Router = preload("res://core/input_router.gd")
const Store = preload("res://services/project_store.gd")
const Exporter = preload("res://exporters/package_exporter.gd")

var app: Control
var passed := 0
var failures: Array[String] = []
var output := ""

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS ", message)
	else:
		failures.append(message)
		push_error(message)

func mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event)

func click(point: Vector2) -> void:
	mouse(point, true)
	mouse(point, false)
	await process_frame
	await process_frame

func drag(start: Vector2, finish: Vector2) -> void:
	mouse(start, true)
	var motion := InputEventMouseMotion.new()
	motion.position = finish
	motion.global_position = finish
	motion.relative = finish - start
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion)
	mouse(finish, false)
	await process_frame
	await process_frame

func screenshot(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))

func run() -> void:
	output = ProjectSettings.globalize_path("res://tests/output/animation_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 800)
	app = load("res://editor/main.tscn").instantiate()
	root.add_child(app)
	app.new_character("traveler")
	await process_frame
	await process_frame
	var model: Dictionary = app.doc.model
	var blink := Character.action("blink", "Blink", 4)
	blink.overlay = true
	Character.set_key(blink, "head", 0, {"position": [0, 0], "rotation": 12})
	model.actions.append(blink)
	var slash: Dictionary = Character.find_action(model, "wave").duplicate(true)
	slash.id = "slash"
	slash.name = "Slash"
	slash.priority = 10
	model.actions.append(slash)
	var player := ActionPlayer.new()
	player.configure(model)
	expect(player.play("wave") and player.play("blink") and player.active.size() == 2, "disjoint arm and head actions coexist")
	player.advance(0.2)
	var walk := Character.find_action(model, "walk")
	var base := Character.transforms(model, walk, 2)
	var mixed := Character.transforms(model, walk, 2, {}, 0, player.layers())
	expect(base.leg_l == mixed.leg_l and base.leg_r == mixed.leg_r, "combined upper-body actions preserve walking legs")
	expect(base.head != mixed.head and base.arm_r != mixed.arm_r, "both concurrent upper-body tracks render")
	expect(player.play("slash") and player.active.size() == 2, "higher priority arm action replaces arm while retaining head")
	expect(not player.play("wave") and player.active.size() == 2, "lower priority conflicting action is refused atomically")
	blink.conflict = "reject"
	expect(not player.play("blink"), "reject conflict policy preserves existing action")
	player.advance(10)
	expect(player.active.is_empty(), "independent action clocks finish and clear")
	player.play("slash")
	expect(not player.play("idle"), "low-priority full-body action cannot interrupt stronger arm action")
	slash.priority = 0
	player.configure(model)
	player.play("wave")
	expect(player.play("idle") and player.active.size() == 1 and player.layers().is_empty(), "full-body replacement clears conflicting overlays")
	var character: CharacterBody2D = app.game_world.player
	character.set_physics_process(false)
	character.configure(model, app.doc.textures)
	character.enabled = true
	character.router.feed("D", true, 0)
	character.execute("wave")
	character._physics_process(0.1)
	expect(character.velocity.x > 0 and character.view.action_id == "walk" and character.view.layers.size() == 1, "runtime walks and waves with independent playback")
	slash.lock_movement = true
	character.configure(model, app.doc.textures)
	character.enabled = true
	character.router.feed("D", true, character.elapsed)
	character.execute("slash")
	character._physics_process(0.1)
	expect(character.velocity == Vector2.ZERO and character.router.held.has("D"), "movement lock pauses movement without losing held direction")
	character._physics_process(10)
	expect(character.velocity.x > 0, "held movement resumes when locking action ends")
	character.router.clear()
	character.router.bindings = [{"key": "MouseRight", "gesture": "tap", "command": "wave"}, {"key": "MouseMiddle", "gesture": "tap", "command": "blink"}]
	for index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		for pressed in [true, false]:
			var event := InputEventMouseButton.new()
			event.button_index = index
			event.pressed = pressed
			character._input(event)
	expect(character.actions.active.size() == 2, "game right and middle mouse bindings both execute")
	character.enabled = false

	app.show_controls()
	await process_frame
	await process_frame
	var dialog: Control = app.bindings_dialog
	expect(dialog != null and dialog is Control, "bindings use themed in-app modal")
	var row: HBoxContainer = dialog.rows.get_child(0)
	var capture_button: Button = row.get_child(1)
	await click(capture_button.get_global_rect().get_center())
	var key := InputEventKey.new()
	key.keycode = KEY_F6
	key.pressed = true
	root.push_input(key)
	key.pressed = false
	root.push_input(key)
	expect(dialog.bindings[0].key == "F6" and capture_button.text == "F6", "keyboard button captures actual key without typing")
	var device: OptionButton = row.get_child(0)
	device.select(1)
	device.item_selected.emit(1)
	await process_frame
	await process_frame
	row = dialog.rows.get_child(0)
	var mouse_picker: OptionButton = row.get_child(1)
	mouse_picker.select(2)
	mouse_picker.item_selected.emit(2)
	expect(dialog.bindings[0].key == "MouseMiddle" and mouse_picker.item_count == 3, "mouse device exposes left right middle selector")
	for resolution in [Vector2i(960, 640), Vector2i(1280, 800), Vector2i(1920, 1080)]:
		root.size = resolution
		await process_frame
		await process_frame
		expect(Rect2(Vector2.ZERO, root.size).encloses(dialog.card.get_global_rect()), "bindings fit viewport %s" % resolution)
		for child in row.get_children():
			expect(dialog.card.get_global_rect().encloses(child.get_global_rect()), "binding column remains within modal %s" % resolution)
		await screenshot("bindings_%dx%d" % [resolution.x, resolution.y])
	var before: String = app.doc.fingerprint()
	dialog.bindings.append(dialog.bindings[0].duplicate(true))
	dialog.apply()
	expect(not dialog.warning.text.is_empty() and app.doc.fingerprint() == before, "duplicate binding rejected without modifying document")
	dialog.bindings.pop_back()
	dialog.apply()
	await process_frame
	expect(app.doc.model.bindings[0].key == "MouseMiddle", "binding apply persists selected mouse input")
	app.undo()
	expect(app.doc.model.bindings[0].key == "A", "binding apply is one undoable edit")
	root.size = Vector2i(1280, 800)
	await process_frame

	app.action_id = "idle"
	app.seek(0)
	var clip := Character.find_action(app.doc.model, "idle")
	var id: String = app.doc.model.parts[0].id
	clip.tracks[id] = []
	Character.set_key(clip, id, 0, {"position": [1, 0], "rotation": 0, "asset": app.doc.model.parts[0].asset})
	Character.set_key(clip, id, 4, {"position": [9, 0], "rotation": 30})
	app.update_canvas()
	await process_frame
	await process_frame
	var timeline: Control = app.timeline
	var origin: Vector2 = timeline.global_position
	await drag(origin + Vector2(140 + timeline.cell * 1.5, 10), origin + Vector2(140 + timeline.cell * 6.5, 10))
	expect(app.frame == 6 and not timeline.scrubbing, "timeline header drag continuously scrubs and releases")
	var history_count: int = app.history.undo_stack.size()
	await drag(origin + Vector2(140 + timeline.cell * 0.5, 35.5), origin + Vector2(140 + timeline.cell * 4.5, 35.5))
	expect(Character.pose(clip, id, 4).position == [1, 0] and Character.pose(clip, id, 0).position == [9, 0], "dragging onto occupied key swaps complete poses")
	expect(Character.pose(clip, id, 4).has("asset"), "keyframe move retains texture swaps")
	expect(app.history.undo_stack.size() == history_count + 1, "entire keyframe drag is one history operation")
	app.undo()
	clip = Character.find_action(app.doc.model, "idle")
	expect(Character.pose(clip, id, 0).position == [1, 0], "keyframe move undo restores both keys")
	app.redo()
	clip = Character.find_action(app.doc.model, "idle")
	expect(Character.pose(clip, id, 4).position == [1, 0], "keyframe move redo restores swap")
	await screenshot("timeline")

	app.key_edit = false
	app.selected = ""
	app.add_joint()
	var shoulder: String = app.selected
	app.add_joint()
	var elbow: String = app.selected
	app.add_joint()
	var wrist: String = app.selected
	model = app.doc.model
	var shoulder_part := Character.find_part(model, shoulder)
	shoulder_part.position = [28, -20]
	Character.find_part(model, elbow).position = [10, 0]
	Character.find_part(model, wrist).position = [10, 0]
	var hand: Dictionary = Character.find_part(model, "arm_r")
	var previous_world: Transform2D = Character.transforms(model, {}, 0).arm_r
	expect(Character.reparent(model, "arm_r", wrist), "sprite can bind to terminal joint")
	expect(previous_world.is_equal_approx(Character.transforms(model, {}, 0).arm_r), "binding to joint preserves world placement")
	shoulder_part.rotation = 90
	var transforms := Character.transforms(model, {}, 0)
	expect(transforms[wrist].origin.is_equal_approx(Vector2(28, 0)), "shoulder rotation moves elbow and wrist together")
	var cycle_before := model.duplicate(true)
	expect(not Character.reparent(model, shoulder, wrist) and model == cycle_before, "joint cycles refused without mutation")
	app.action_id = "idle"
	app.seek(0)
	app.selected = elbow
	var local_before: Vector2 = Character.vec(Character.find_part(model, elbow).position)
	app.drag_part(elbow, Vector2(0, 3))
	expect(Character.vec(Character.find_part(model, elbow).position).is_equal_approx(local_before + Vector2(3, 0)), "dragging under rotated joint converts world displacement to local coordinates")
	Character.set_key(Character.find_action(model, "idle"), shoulder, 0, {"position": [0, 0], "rotation": 30})
	app.refresh_all()
	await process_frame
	expect(app.stage.hit_test(Character.transforms(model, Character.find_action(model, "idle"), 0)[wrist].origin) == wrist, "transparent joint is selectable by canvas handle")
	var descendant_action := Character.action("chain", "Chain")
	descendant_action.overlay = true
	Character.set_key(descendant_action, shoulder, 0, {"rotation": 10})
	model.actions.append(descendant_action)
	player.configure(model)
	player.play("chain")
	expect(player.affected_parts(descendant_action).has("arm_r"), "joint action conflict mask includes descendant sprites")
	Character.find_action(model, "wave").conflict = "reject"
	expect(not player.play("wave"), "joint and descendant sprite actions conflict")
	expect(Character.validate(model).is_empty(), "multi-joint character with action rules validates")
	await screenshot("joint_chain")
	var saved := app.doc.save_to(output.path_join("editable")) as String
	var reopened := Store.new()
	expect(saved.is_empty() and reopened.open_file(output.path_join("editable/character.rigpop.json")).is_empty(), "joint chain saves and reopens with complete assets")
	expect(Character.find_part(reopened.model, wrist).parent == elbow and Character.find_part(reopened.model, shoulder).kind == "joint", "reopened chain retains joint identity and hierarchy")
	var exported := Exporter.export_package(app.doc, output, "Godot")
	expect(exported.error.is_empty() and FileAccess.file_exists(str(exported.path).path_join("addons/rigpop_runtime/core/action_player.gd")), "export includes action compositor and joint data")
	var world_before := Character.transforms(model, {}, 0)
	app.selected = elbow
	app.delete_part()
	expect(Character.find_part(app.doc.model, wrist).parent == shoulder, "deleting joint reparents surviving child")
	expect(world_before[wrist].is_equal_approx(Character.transforms(app.doc.model, {}, 0)[wrist]), "deleting intermediate joint preserves child bind pose")
	app.undo()
	expect(not Character.find_part(app.doc.model, elbow).is_empty(), "joint deletion is undoable")
	if "--native-preview" in OS.get_cmdline_user_args():
		app.set_mode(3)
		app.launch_desktop()
		var pid: int = app.desktop_pid
		expect(pid > 0 and OS.is_process_running(pid), "preview starts managed native process")
		app.launch_desktop()
		expect(app.desktop_pid == pid and app.desktop_start_button.disabled and not app.desktop_stop_button.disabled, "repeated launch retains one managed pet and correct controls")
		app.stop_desktop()
		expect(app.desktop_pid == -1 and not app.desktop_start_button.disabled and app.desktop_stop_button.disabled, "preview stop resets controls")
	Exporter.write(output.path_join("report.json"), JSON.stringify({"passed": passed, "failures": failures, "godot_export": exported.path}, "\t"))
	print("ANIMATION_RESULT: %d passed, %d failed. %s" % [passed, failures.size(), output])
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
