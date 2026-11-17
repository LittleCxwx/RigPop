extends Control

const Character = preload("res://core/character.gd")
const Store = preload("res://services/project_store.gd")
const Templates = preload("res://services/templates.gd")
const History = preload("res://core/history.gd")
const ThemeKit = preload("res://editor/theme.gd")
const Icons = preload("res://editor/icons.gd")
const InspectorPanel = preload("res://editor/inspector_panel.gd")
const WorkspaceLayout = preload("res://editor/workspace_layout.gd")
const Exporter = preload("res://exporters/package_exporter.gd")

var doc: RefCounted
var history := History.new()
var selected := "head"
var action_id := "idle"
var frame := 0
var playing := false
var clock := 0.0
var playback_rate := 1.0
var mode := 0
var key_edit := false
var before: Dictionary = {}
var stored_dirty := true
var data_root := ""
var desktop_pid := -1
var tree: Tree
var inspector: VBoxContainer
var inspector_panel: RefCounted
var stage: Control
var pixel: Control
var timeline: Control
var stage_stack: Control
var game_container: SubViewportContainer
var game_world: Node2D
var game_viewport: SubViewport
var mode_buttons: Array[Button] = []
var action_picker: OptionButton
var library_picker: OptionButton
var status: Label
var title_label: Label
var dirty_dot: Panel
var frame_label: Label
var canvas_label: Label
var play_button: Button
var save_button: Button
var undo_button: Button
var redo_button: Button
var work_split: HBoxContainer
var body_split: HBoxContainer
var timeline_scroll: ScrollContainer
var file_dialog: FileDialog
var confirm
var pending_action: Callable
var file_purpose := ""
var export_kind := ""
var building := false
var recent_paths: Array[String] = []

func _ready() -> void:
	if OS.has_feature("desktop_host"):
		get_tree().change_scene_to_file.call_deferred("res://runtime/desktop/pet.tscn")
		return
	theme = ThemeKit.make()
	inspector_panel = InspectorPanel.new(self)
	get_tree().auto_accept_quit = false
	data_root = (OS.get_executable_path().get_base_dir() if not OS.has_feature("editor") else ProjectSettings.globalize_path("res://")).path_join("portable_data")
	var data_error := DirAccess.make_dir_recursive_absolute(data_root)
	doc = Templates.make()
	var recent_data = JSON.parse_string(FileAccess.get_file_as_string(data_root.path_join("recent.json"))) if FileAccess.file_exists(data_root.path_join("recent.json")) else null
	if recent_data is Array:
		for item in recent_data:
			if item is String and FileAccess.file_exists(item) and recent_paths.size() < 12: recent_paths.append(item)
	if not recent_paths.is_empty() and not "--verify-install" in OS.get_cmdline_user_args():
		var last := Store.new()
		if last.open_file(recent_paths[0]).is_empty(): doc = last
	# 启动时的内容就是基线：默认模板或刚打开的文件都还没有"改动"。
	# 脏标记只由 fingerprint 与基线比较得出，所以撤销回原状会自动变回已保存。
	doc.saved_fingerprint = doc.fingerprint()
	build_ui()
	refresh_all()
	confirm.canceled.connect(refresh_library)
	if "--verify-install" in OS.get_cmdline_user_args(): verify_install.call_deferred()
	if data_error != OK:
		notify("便携目录不可写，请使用另存为选择可写目录", true)
	resized.connect(responsive)
	responsive()

func label(text: String, font_size: int = 13, color: Color = ThemeKit.INK_2) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	resize_label(l)
	return l

## 开了省略号的 Label 最小宽度只有 1 px，改完文本必须同步最小宽度，
## 否则它会被容器压成一条竖线（顶栏文档名踩过这个坑）。
func resize_label(l: Label, cap: float = 240.0) -> void:
	var size: int = l.get_theme_font_size("font_size")
	if size <= 0: size = 13
	var f: Font = theme.default_font
	if l.has_theme_font_override("font") and l.get_theme_font("font") != null:
		f = l.get_theme_font("font")
	l.custom_minimum_size.x = minf(cap, f.get_string_size(
			l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 8)

## 分区小标题：11 px、600 字重、加一点字距，只靠这点差异建立层级。
func heading(parent: Node, text: String) -> Label:
	var l := label(text, 11, ThemeKit.MUTED)
	l.add_theme_font_override("font", ThemeKit.font(ThemeKit.W_TITLE, 1))
	l.custom_minimum_size.x = 0
	parent.add_child(l)
	return l

func button(parent: Node, text: String, callback: Callable, icon: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 30
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", ThemeKit.font(ThemeKit.W_LABEL))
	if not icon.is_empty():
		b.icon = Icons.get_icon(icon, 17)
	b.pressed.connect(func() -> void:
		flush_field()
		callback.call())
	parent.add_child(b)
	return b

func tool_button(parent: Node, icon: String, tip: String, callback: Callable) -> Button:
	var b := button(parent, "", callback, icon)
	b.custom_minimum_size = Vector2(28, 28)
	b.tooltip_text = tip
	return b

## 实心主按钮：全屏只有它用墨色底，一眼知道"下一步点这个"。
func primary_button(parent: Node, text: String, callback: Callable) -> Button:
	var b := button(parent, text, callback)
	style_primary(b)
	return b

## 把任意按钮改成实心主按钮的样子（对话框确认键复用同一套皮肤）。
func style_primary(b: Button) -> void:
	var ink_text := Color("f6f3fb")
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, ink_text)
	b.add_theme_stylebox_override("normal", ThemeKit.flat(ThemeKit.INK, 3, Color.TRANSPARENT, 13, 5))
	b.add_theme_stylebox_override("hover", ThemeKit.flat(Color("342e40"), 3, Color.TRANSPARENT, 13, 5))
	b.add_theme_stylebox_override("pressed", ThemeKit.flat(Color("141019"), 3, Color.TRANSPARENT, 13, 5))
	b.add_theme_stylebox_override("disabled", ThemeKit.flat(ThemeKit.LINE_2, 3, Color.TRANSPARENT, 13, 5))

## 对话框与列表里的描边按钮：有明确边界，避免在纸色底上糊成一片。
func outline_button(parent: Node, text: String, callback: Callable, icon: String = "") -> Button:
	var b := button(parent, text, callback, icon)
	b.custom_minimum_size.y = 32
	style_outline(b)
	return b

## 把任意按钮改成描边按钮的样子。
func style_outline(b: Button) -> void:
	b.add_theme_stylebox_override("normal", ThemeKit.flat(ThemeKit.SURFACE, 3, ThemeKit.LINE, 11, 5))
	b.add_theme_stylebox_override("hover", ThemeKit.flat(ThemeKit.SURFACE, 3, ThemeKit.LINE_2, 11, 5))
	b.add_theme_stylebox_override("pressed", ThemeKit.flat(ThemeKit.PAPER_2, 3, ThemeKit.LINE_2, 11, 5))

## 侧栏里的"行为行"：左对齐、带图标，看起来像可点的列表项而不是按钮。
func action_row(parent: Node, text: String, icon: String, callback: Callable) -> Button:
	var b := button(parent, text, callback, icon)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size.y = 30
	return b

## 顶栏模式页签：无边框，选中态只留一条 1.5 号的底线。
func tab_button(parent: Node, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 47)
	b.add_theme_font_override("font", ThemeKit.font(ThemeKit.W_BODY))
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", ThemeKit.MUTED)
	b.add_theme_color_override("font_hover_color", ThemeKit.INK_2)
	b.add_theme_color_override("font_pressed_color", ThemeKit.INK)
	b.add_theme_color_override("font_hover_pressed_color", ThemeKit.INK)
	b.add_theme_stylebox_override("normal", tab_box(Color.TRANSPARENT))
	b.add_theme_stylebox_override("hover", tab_box(ThemeKit.LINE_2))
	b.add_theme_stylebox_override("pressed", tab_box(ThemeKit.INK))
	b.add_theme_stylebox_override("hover_pressed", tab_box(ThemeKit.INK))
	b.pressed.connect(func() -> void:
		flush_field()
		callback.call())
	parent.add_child(b)
	return b

func tab_box(line: Color) -> StyleBoxFlat:
	var s := ThemeKit.flat(Color.TRANSPARENT, 0, Color.TRANSPARENT, 13, 0)
	s.border_width_bottom = 2
	s.border_color = line
	return s

func expand(parent: Node) -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(c)
	return c

func gap(parent: Node, height: int = 10) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = height
	parent.add_child(c)
	return c

func margin(parent: Node, amount: int = 12) -> MarginContainer:
	return inset(parent, amount, amount, amount, amount)

func inset(parent: Node, left: int, right: int, top: int, bottom: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", left)
	m.add_theme_constant_override("margin_right", right)
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_bottom", bottom)
	parent.add_child(m)
	return m

## 1 px 竖线，用来分组而不加边框。
func rule_v(height: int = 16) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(1, height)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_theme_stylebox_override("panel", ThemeKit.flat(ThemeKit.LINE))
	return p

## 未保存小圆点：状态只用一个点表示，不写进标题。
func mark_dot(size: int = 5, color: Color = ThemeKit.SIGNAL) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(size, size)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_theme_stylebox_override("panel", ThemeKit.flat(color, int(size / 2.0)))
	return p


func build_ui() -> void:
	WorkspaceLayout.new(self).build()

func responsive() -> void:
	if not is_instance_valid(timeline_scroll): return
	timeline_scroll.custom_minimum_size.y = 116 if size.y < 720 else 148
	update_canvas.call_deferred()

func refresh_all() -> void:
	building = true
	if Character.find_part(doc.model, selected).is_empty():
		selected = str(doc.model.parts[0].id) if not doc.model.parts.is_empty() else ""
	if Character.find_action(doc.model, action_id).is_empty():
		action_id = str(doc.model.actions[0].id) if not doc.model.actions.is_empty() else ""
	action_picker.clear()
	for c in doc.model.actions:
		action_picker.add_item(c.name)
		if c.id == action_id: action_picker.select(action_picker.item_count - 1)
	rebuild_tree()
	refresh_library()
	rebuild_inspector()
	update_canvas()
	stored_dirty = doc.dirty()
	update_title()
	building = false

func rebuild_tree() -> void:
	var old := building
	building = true
	tree.clear()
	var root := tree.create_item()
	var pending: Array = doc.model.parts.duplicate()
	var items := {"": root}
	for _pass in pending.size() + 1:
		for i in range(pending.size() - 1, -1, -1):
			var p: Dictionary = pending[i]
			if not items.has(p.parent): continue
			var item := tree.create_item(items[p.parent])
			item.set_text(0, p.name)
			item.set_metadata(0, p.id)
			item.set_custom_color(0, ThemeKit.INK if p.visible else ThemeKit.MUTED)
			items[p.id] = item
			if p.id == selected: item.select(0)
			pending.remove_at(i)
	building = old
	tree.ensure_cursor_is_visible.call_deferred()

func refresh_library() -> void:
	library_picker.clear()
	library_picker.add_item(doc.model.name)
	library_picker.set_item_metadata(0, "")
	var listed := {doc.path: true}
	for path in recent_paths:
		if listed.has(path.get_base_dir()): continue
		var metadata = JSON.parse_string(FileAccess.get_file_as_string(path))
		if metadata is Dictionary:
			library_picker.add_item(str(metadata.get("name", path.get_base_dir().get_file())))
			library_picker.set_item_metadata(library_picker.item_count - 1, path)
			listed[path.get_base_dir()] = true
	var dir := DirAccess.open(data_root)
	if dir == null: return
	for folder in dir.get_directories():
		var path := data_root.path_join(folder).path_join("character.rigpop.json")
		if FileAccess.file_exists(path) and not listed.has(path.get_base_dir()):
			var data = JSON.parse_string(FileAccess.get_file_as_string(path))
			if data is Dictionary:
				library_picker.add_item(str(data.get("name", folder)))
				library_picker.set_item_metadata(library_picker.item_count - 1, path)

func select_part(id: String) -> void:
	selected = id
	rebuild_tree()
	rebuild_inspector()
	update_canvas()

func set_mode(value: int) -> void:
	mode = value
	playing = false
	if game_world != null:
		game_world.configure(doc.model, doc.textures)
		game_world.enabled = mode == 2
		game_world.clear_input()
	update_canvas()
	rebuild_inspector()

func update_canvas() -> void:
	if stage.view == null: return
	stage.visible = mode in [0, 3]
	pixel.visible = mode == 1
	game_container.visible = mode == 2
	for i in 4: mode_buttons[i].button_pressed = mode == i
	stage.selected = selected
	stage.update_view(doc.model, doc.textures, action_id, frame)
	var p := Character.find_part(doc.model, selected)
	if not p.is_empty():
		var asset := current_asset(p)
		if doc.images.has(asset):
			if pixel.image != doc.images[asset]: pixel.set_image(doc.images[asset])
			var img: Image = doc.images[asset]
			canvas_label.text = "%s × %s px  ·  %s%%" % [img.get_width(), img.get_height(), (pixel.zoom if mode == 1 else stage.zoom) * 100]
	else:
		pixel.set_image(null)
		canvas_label.text = ""
	timeline.model = doc.model
	timeline.clip = Character.find_action(doc.model, action_id)
	timeline.frame = frame
	timeline.selected = selected
	timeline.custom_minimum_size.y = 22 + doc.model.parts.size() * 27
	var strip := maxi(400, 152 + int(timeline.clip.get("frames", 8)) * 24)
	# 帧数少时也让轨道铺满可视宽度，避免轨道带在半路截断。
	if timeline_scroll != null:
		strip = maxi(strip, int(timeline_scroll.size.x))
	timeline.custom_minimum_size.x = strip
	timeline.queue_redraw()
	frame_label.text = "%02d / %02d" % [frame + 1, int(timeline.clip.get("frames", 1))]
	play_button.icon = Icons.get_icon("pause" if playing else "play", 17)

func current_asset(p: Dictionary) -> String:
	return str(Character.pose(Character.find_action(doc.model, action_id), p.id, frame).get("asset", p.asset))

func seek(value: int) -> void:
	playing = false
	frame = value
	clock = float(frame) / maxf(1, float(Character.find_action(doc.model, action_id).get("fps", 8)))
	update_canvas()
	rebuild_inspector()

func toggle_play() -> void:
	playing = not playing
	clock = float(frame) / maxf(1, float(Character.find_action(doc.model, action_id).get("fps", 8)))
	update_canvas()

func _process(delta: float) -> void:
	if doc == null: return
	if playing:
		var clip := Character.find_action(doc.model, action_id)
		if not clip.is_empty():
			clock += delta * playback_rate
			var next := int(clock * float(clip.fps))
			if next >= int(clip.frames) and not clip.loop:
				playing = false
				next = int(clip.frames) - 1
			else: next %= int(clip.frames)
			if next != frame:
				frame = next
				update_canvas()
	if game_world != null:
		game_world.enabled = mode == 2 and game_container.has_focus()

func begin_change() -> void:
	before = doc.snapshot()

func commit_change(text: String) -> void:
	if before.is_empty(): return
	if hash(before) != hash(doc.snapshot()):
		history.push(before, text)
	before = {}
	stored_dirty = doc.dirty()
	update_title()
	update_canvas()

func edit(text: String, callback: Callable) -> void:
	begin_change()
	callback.call()
	commit_change(text)

func update_title() -> void:
	title_label.text = doc.model.name
	resize_label(title_label, 200.0)
	if dirty_dot != null: dirty_dot.visible = stored_dirty
	get_window().title = "RigPop · %s%s" % [doc.model.name, " *" if stored_dirty else ""]
	undo_button.disabled = history.undo_stack.is_empty()
	redo_button.disabled = history.redo_stack.is_empty()

func undo() -> void:
	var state := history.undo(doc.snapshot())
	if not state.is_empty():
		doc.restore(state)
		refresh_all()
		notify("已撤销")

func redo() -> void:
	var state := history.redo(doc.snapshot())
	if not state.is_empty():
		doc.restore(state)
		refresh_all()
		notify("已重做")

func drag_part(id: String, offset: Vector2) -> void:
	var p := Character.find_part(doc.model, id)
	if key_edit:
		var clip := Character.find_action(doc.model, action_id)
		var pose := Character.pose(clip, id, frame)
		pose.position = [pose.position[0] + offset.x, pose.position[1] + offset.y]
		Character.set_key(clip, id, frame, pose)
	else:
		p.position = [p.position[0] + offset.x, p.position[1] + offset.y]
	update_canvas()

func insert_key() -> void:
	if selected.is_empty(): return
	var clip := Character.find_action(doc.model, action_id)
	if clip.is_empty(): return
	edit("插入关键帧", func() -> void: Character.set_key(clip, selected, frame, Character.pose(clip, selected, frame)))
	notify("已在第 %d 帧插入关键帧" % (frame + 1))

func set_zoom(amount: int) -> void:
	if mode == 1: pixel.zoom = clampi(pixel.zoom + amount, 1, 32); pixel.queue_redraw()
	else:
		stage.auto_fit = false
		stage.zoom = clampi(stage.zoom + amount, 1, 20)
	update_canvas()

func notify(text: String, error: bool = false) -> void:
	status.text = text
	status.tooltip_text = text
	status.add_theme_color_override("font_color", ThemeKit.SIGNAL if error else ThemeKit.MUTED)
	if error:
		var dialog := AcceptDialog.new()
		dialog.title = "操作未完成"
		dialog.dialog_text = text
		add_child(dialog)
		dialog.popup_centered(Vector2i(460, 160))
		dialog.confirmed.connect(dialog.queue_free)
		dialog.canceled.connect(dialog.queue_free)

func guard(callback: Callable) -> void:
	if doc.dirty():
		pending_action = callback
		confirm.open()
	else: callback.call()

func save_project() -> void:
	flush_field()
	var directory: String = doc.path if not doc.path.is_empty() else data_root.path_join(doc.model.id)
	var error: String = doc.save_to(directory)
	if not error.is_empty(): notify(error, true); return
	stored_dirty = false
	remember_project()
	update_title()
	refresh_library()
	notify("已保存  ·  " + directory)

func open_project() -> void:
	file_purpose = "open"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = PackedStringArray(["*.json ; RigPop 工程"])
	file_dialog.title = "打开角色工程"
	file_dialog.current_dir = data_root
	file_dialog.popup_centered()

func load_project(path: String) -> void:
	var next := Store.new()
	var error := next.open_file(path)
	if not error.is_empty(): notify(error, true); return
	doc = next
	remember_project()
	history = History.new()
	frame = 0
	playing = false
	refresh_all()
	if mode == 2: game_world.configure(doc.model, doc.textures)
	notify("已打开  ·  " + path)

func file_selected(path: String) -> void:
	if file_purpose == "open": guard(func() -> void: load_project(path))
	elif file_purpose == "image": accept_image(path)
	elif file_purpose == "replace": replace_image(path)

func show_new() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "新建角色"
	dialog.min_size = Vector2i(360, 160)
	var col := VBoxContainer.new()
	dialog.add_child(col)
	outline_button(col, "薄荷旅人 · 分部件人形", func() -> void: dialog.hide(); guard(func() -> void: new_character("traveler")))
	outline_button(col, "果冻团子 · 非人形", func() -> void: dialog.hide(); guard(func() -> void: new_character("slime")))
	outline_button(col, "空白角色", func() -> void: dialog.hide(); guard(func() -> void: new_character("empty")))
	add_child(dialog)
	dialog.popup_centered()
	dialog.canceled.connect(dialog.queue_free)
	dialog.confirmed.connect(dialog.queue_free)

func new_character(kind: String) -> void:
	doc = Templates.make("traveler" if kind == "empty" else kind)
	if kind == "empty":
		doc.model = Character.empty("未命名角色")
		doc.model.actions = [Character.action("idle", "待机")]
		for binding in doc.model.bindings:
			if binding.command == "wave": binding.command = "idle"
		doc.images.clear()
		doc.refresh_textures()
	history = History.new()
	frame = 0
	action_id = "idle"
	refresh_all()
	if mode == 2: game_world.configure(doc.model, doc.textures)

func duplicate_character() -> void:
	doc.model.id = Character.uid("character")
	doc.model.name += " 副本"
	doc.path = ""
	doc.saved_fingerprint = ""
	history = History.new()
	refresh_all()
	notify("已建立独立副本")

func add_part() -> void:
	var id := Character.uid("part")
	edit("添加部件", func() -> void:
		var p := Character.part(id, "新部件", selected, [0, 0], [8, 8], 6)
		doc.model.parts.append(p)
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color.TRANSPARENT)
		doc.images[p.asset] = img
		doc.refresh_textures())
	select_part(id)

func delete_part() -> void:
	var p := Character.find_part(doc.model, selected)
	if p.is_empty(): return
	edit("删除部件", func() -> void:
		for child in doc.model.parts:
			if child.parent == selected: child.parent = p.parent
		doc.model.parts.erase(p)
		for clip in doc.model.actions: clip.tracks.erase(selected))
	refresh_all()

func add_action() -> void:
	var clip := Character.action(Character.uid("action"), "新动作")
	edit("新增动作", func() -> void: doc.model.actions.append(clip))
	action_id = clip.id
	frame = 0
	refresh_all()

func duplicate_action() -> void:
	var clip := Character.find_action(doc.model, action_id).duplicate(true)
	if clip.is_empty(): return
	clip.id = Character.uid("action")
	clip.name += " 副本"
	edit("复制动作", func() -> void: doc.model.actions.append(clip))
	action_id = clip.id
	refresh_all()

func delete_action() -> void:
	if doc.model.actions.size() <= 1:
		notify("至少保留一个动作")
		return
	edit("删除动作", func() -> void:
		doc.model.actions.erase(Character.find_action(doc.model, action_id))
		for i in range(doc.model.bindings.size() - 1, -1, -1):
			if doc.model.bindings[i].command == action_id: doc.model.bindings.remove_at(i))
	frame = 0
	refresh_all()

func import_image() -> void:
	file_purpose = "image"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp ; 图片或规则图集"])
	file_dialog.title = "导入美术素材"
	file_dialog.popup_centered()

func accept_image(path: String) -> void:
	var img := Image.load_from_file(path)
	if img == null or img.is_empty(): notify("图片无法读取", true); return
	if img.get_width() > 4096 or img.get_height() > 4096: notify("图片不能超过 4096 × 4096 像素", true); return
	img.convert(Image.FORMAT_RGBA8)
	var dialog := ConfirmationDialog.new()
	dialog.title = "导入预览 · " + path.get_file()
	dialog.ok_button_text = "导入为部件"
	var col := VBoxContainer.new()
	dialog.add_child(col)
	var preview := TextureRect.new()
	preview.texture = ImageTexture.create_from_image(img)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(340, 180)
	col.add_child(preview)
	col.add_child(label("%d × %d px" % [img.get_width(), img.get_height()], 12, ThemeKit.MUTED))
	var row := HBoxContainer.new()
	col.add_child(row)
	row.add_child(label("图集列数"))
	var cols := SpinBox.new()
	cols.min_value = 1; cols.max_value = 64; cols.value = 1
	row.add_child(cols)
	row.add_child(label("行数"))
	var rows := SpinBox.new()
	rows.min_value = 1; rows.max_value = 64; rows.value = 1
	row.add_child(rows)
	dialog.confirmed.connect(func() -> void:
		var count := int(cols.value) * int(rows.value)
		if count > 240 or img.get_width() % int(cols.value) != 0 or img.get_height() % int(rows.value) != 0:
			notify("图集尺寸必须整除行列数，最多 240 帧", true); return
		begin_change()
		var id := Character.uid("part")
		var frame_size := Vector2i(img.get_width() / int(cols.value), img.get_height() / int(rows.value))
		var p := Character.part(id, path.get_basename().get_file(), "", [0, 0], [frame_size.x / 2, frame_size.y], 5)
		doc.model.parts.append(p)
		var clip := Character.action(Character.uid("action"), p.name, count)
		for i in count:
			var asset := "assets/%s_%03d.png" % [id, i]
			doc.images[asset] = img.get_region(Rect2i(Vector2i(i % int(cols.value), i / int(cols.value)) * frame_size, frame_size))
			if i == 0: p.asset = asset
			if count > 1: Character.set_key(clip, id, i, {"asset": asset, "position": [0, 0], "rotation": 0})
		if count > 1:
			doc.model.actions.append(clip)
			action_id = clip.id
			frame = 0
		doc.refresh_textures()
		commit_change("导入图片")
		selected = id
		refresh_all()
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(400, 320))

func show_export() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "导出角色"
	var col := VBoxContainer.new()
	dialog.add_child(col)
	for target in ["Godot", "桌宠", "工程"]:
		outline_button(col, {"Godot": "Godot 角色包", "桌宠": "Windows 桌宠包", "工程": "可编辑工程副本"}[target], func() -> void:
			dialog.hide()
			export_kind = target
			file_purpose = "export"
			file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
			file_dialog.filters = PackedStringArray()
			file_dialog.title = "选择导出父目录"
			file_dialog.popup_centered(), "export")
	add_child(dialog)
	dialog.popup_centered(Vector2i(350, 180))
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)

func directory_selected(directory: String) -> void:
	if file_purpose == "save_as":
		var error: String = doc.save_to(directory)
		if not error.is_empty(): notify(error, true); return
		stored_dirty = false
		remember_project()
		update_title()
		refresh_library()
		notify("已另存为  ·  " + directory)
		return
	if file_purpose != "export": return
	var result: Dictionary = Exporter.export_package(doc, directory, export_kind)
	if not result.error.is_empty(): notify(result.error, true)
	else: notify("导出完成  ·  " + result.path)

func launch_desktop() -> void:
	var temporary := data_root.path_join("preview")
	var original_path: String = doc.path
	var original_fingerprint: String = doc.saved_fingerprint
	var error: String = doc.save_to(temporary)
	doc.path = original_path
	doc.saved_fingerprint = original_fingerprint
	if not error.is_empty(): notify(error, true); return
	var engine := OS.get_executable_path()
	var args := PackedStringArray()
	if not OS.has_feature("editor"):
		engine = OS.get_executable_path().get_base_dir().path_join("hosts/RigPopPet.exe")
		if not FileAccess.file_exists(engine): notify("桌宠宿主缺失，请运行构建脚本生成 hosts/RigPopPet.exe", true); return
	else:
		args.append_array(["--path", ProjectSettings.globalize_path("res://"), "res://runtime/desktop/pet.tscn"])
	args.append_array(["--", "--character", temporary.path_join("character.rigpop.json")])
	desktop_pid = OS.create_process(engine, args)
	notify("桌宠试演已启动" if desktop_pid > 0 else "桌宠进程启动失败", desktop_pid <= 0)

func stop_desktop() -> void:
	if desktop_pid > 0 and OS.is_process_running(desktop_pid): OS.kill(desktop_pid)
	desktop_pid = -1
	notify("桌宠试演已停止")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and doc != null:
		guard(func() -> void: stop_desktop(); get_tree().quit())

func _shortcut_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed:
		match event.keycode:
			KEY_S:
				if event.shift_pressed: save_as()
				else: save_project()
				get_viewport().set_input_as_handled()
			KEY_Z: undo(); get_viewport().set_input_as_handled()
			KEY_Y: redo(); get_viewport().set_input_as_handled()

func flush_field() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit: focus.release_focus()

func remember_project() -> void:
	if doc.path.is_empty(): return
	var path: String = doc.path.path_join("character.rigpop.json")
	recent_paths.erase(path)
	recent_paths.push_front(path)
	if recent_paths.size() > 12: recent_paths.resize(12)
	var file := FileAccess.open(data_root.path_join("recent.json.tmp"), FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify(recent_paths, "\t"))
	file.close()
	DirAccess.rename_absolute(data_root.path_join("recent.json.tmp"), data_root.path_join("recent.json"))

func save_as() -> void:
	flush_field()
	file_purpose = "save_as"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	file_dialog.filters = PackedStringArray()
	file_dialog.title = "另存为 · 选择空目录"
	file_dialog.popup_centered()

func verify_install() -> void:
	var destination := data_root.path_join("verification_%d" % Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(destination)
	var errors: Array = []
	var saved := doc.save_to(destination.path_join("editable")) as String
	if not saved.is_empty(): errors.append(saved)
	var readback := Store.new()
	var read_error := readback.open_file(destination.path_join("editable/character.rigpop.json"))
	if not read_error.is_empty(): errors.append(read_error)
	var outputs := {}
	for kind in ["Godot", "桌宠", "工程"]:
		var result: Dictionary = Exporter.export_package(doc, destination, kind)
		outputs[kind] = result
		if not result.error.is_empty(): errors.append(result.error)
	Exporter.write(destination.path_join("verification.json"), JSON.stringify({"errors": errors, "outputs": outputs}, "\t"))
	print("RIGPOP_VERIFY ", JSON.stringify({"errors": errors, "path": destination}))
	get_tree().quit(0 if errors.is_empty() else 1)

func name_field(parent: Node, value: String, callback: Callable) -> void:
	var field := LineEdit.new()
	field.text = value
	field.custom_minimum_size.y = 28
	field.add_theme_font_override("font", ThemeKit.font(ThemeKit.W_BODY))
	field.focus_exited.connect(func() -> void:
		var text := field.text.strip_edges()
		if not text.is_empty() and text != value: callback.call(text))
	field.text_submitted.connect(func(_text: String) -> void: field.release_focus())
	parent.add_child(field)

func number_field(parent: Node, title: String, value: float, minimum: float, maximum: float, step: float, callback: Callable) -> SpinBox:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var l := label(title, 13, ThemeKit.INK_2)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 0
	row.add_child(l)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.value = value
	spin.custom_minimum_size = Vector2(96, 26)
	spin.get_line_edit().add_theme_font_override("font", ThemeKit.font(ThemeKit.W_BODY))
	spin.value_changed.connect(callback)
	row.add_child(spin)
	return spin

func check_field(parent: Node, title: String, value: bool, callback: Callable) -> CheckBox:
	var check := CheckBox.new()
	check.text = title
	check.button_pressed = value
	check.custom_minimum_size.y = 26
	check.add_theme_font_override("font", ThemeKit.font(ThemeKit.W_BODY))
	check.toggled.connect(callback)
	parent.add_child(check)
	return check

func remove_key() -> void:
	var clip := Character.find_action(doc.model, action_id)
	edit("删除关键帧", func() -> void:
		var keys: Array = clip.get("tracks", {}).get(selected, [])
		for i in range(keys.size() - 1, -1, -1):
			if int(keys[i].frame) == frame: keys.remove_at(i))
	rebuild_inspector()

func choose_replacement() -> void:
	file_purpose = "replace"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp ; 部件图片"])
	file_dialog.title = "替换当前部件图片"
	file_dialog.popup_centered()

func replace_image(path: String) -> void:
	var img := Image.load_from_file(path)
	if img == null or img.is_empty() or img.get_width() > 4096 or img.get_height() > 4096:
		notify("图片无法读取或尺寸超过 4096 像素", true); return
	img.convert(Image.FORMAT_RGBA8)
	var p := Character.find_part(doc.model, selected)
	if p.is_empty(): return
	edit("替换部件图片", func() -> void:
		var asset := "assets/%s.png" % Character.uid("image")
		doc.images[asset] = img
		if key_edit:
			var clip := Character.find_action(doc.model, action_id)
			var pose := Character.pose(clip, selected, frame)
			pose.asset = asset
			Character.set_key(clip, selected, frame, pose)
		else: p.asset = asset
		doc.refresh_textures())
	update_canvas()

func isolate_frame() -> void:
	var p := Character.find_part(doc.model, selected)
	if p.is_empty(): return
	edit("独立帧图片", func() -> void:
		var asset := "assets/%s.png" % Character.uid("frame")
		doc.images[asset] = doc.images[current_asset(p)].duplicate()
		var clip := Character.find_action(doc.model, action_id)
		var pose := Character.pose(clip, selected, frame)
		pose.asset = asset
		Character.set_key(clip, selected, frame, pose)
		doc.refresh_textures())
	notify("当前帧已使用独立图片")

func crop_image() -> void:
	var p := Character.find_part(doc.model, selected)
	if p.is_empty(): return
	var asset := current_asset(p)
	if asset != p.asset:
		notify("姿势换图请先调整画布；透明裁边当前仅用于绑定图片", true); return
	var img: Image = doc.images[asset]
	var used := img.get_used_rect()
	if used.size == Vector2i.ZERO: notify("图片完全透明，无可裁内容"); return
	edit("透明裁边", func() -> void:
		doc.images[asset] = img.get_region(used)
		p.pivot = [float(p.pivot[0]) - used.position.x, float(p.pivot[1]) - used.position.y]
		doc.refresh_textures())
	update_canvas()

func resize_dialog() -> void:
	var p := Character.find_part(doc.model, selected)
	if p.is_empty(): return
	var asset := current_asset(p)
	var img: Image = doc.images[asset]
	var dialog := ConfirmationDialog.new()
	dialog.title = "画布与最近邻重采样"
	var col := VBoxContainer.new()
	dialog.add_child(col)
	var w := number_field(col, "宽 / px", img.get_width(), 1, 512, 1, func(_v: float) -> void: pass)
	var h := number_field(col, "高 / px", img.get_height(), 1, 512, 1, func(_v: float) -> void: pass)
	var resample := check_field(col, "重采样像素（否则只改变画布）", false, func(_v: bool) -> void: pass)
	dialog.confirmed.connect(func() -> void:
		edit("调整图片尺寸", func() -> void:
			var next := img.duplicate() as Image
			if resample.button_pressed:
				next.resize(int(w.value), int(h.value), Image.INTERPOLATE_NEAREST)
				if asset == p.asset:
					p.pivot = [float(p.pivot[0]) * w.value / img.get_width(), float(p.pivot[1]) * h.value / img.get_height()]
			else:
				next = Image.create(int(w.value), int(h.value), false, Image.FORMAT_RGBA8)
				next.fill(Color.TRANSPARENT)
				next.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
			doc.images[asset] = next
			doc.refresh_textures())
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(350, 180))

func show_controls() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "键鼠与手势绑定"
	dialog.ok_button_text = "应用绑定"
	var col := VBoxContainer.new()
	dialog.add_child(col)
	var rows := VBoxContainer.new()
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(550, 290)
	scroll.add_child(rows)
	col.add_child(scroll)
	var bindings: Array = doc.model.bindings.duplicate(true)
	var commands := ["move_left", "move_right", "move_up", "move_down"]
	for clip in doc.model.actions: commands.append(clip.id)
	var render := func() -> void:
		for child in rows.get_children():
			rows.remove_child(child); child.queue_free()
		for b in bindings:
			if b.get("removed", false): continue
			var row := HBoxContainer.new()
			rows.add_child(row)
			var key := LineEdit.new()
			key.text = b.key
			key.custom_minimum_size.x = 100
			key.tooltip_text = "Godot 键名，或 MouseLeft / MouseRight"
			key.text_changed.connect(func(text: String) -> void: b.key = text.strip_edges())
			row.add_child(key)
			var gesture := OptionButton.new()
			for title in ["持续移动", "点按", "长按", "双击"]: gesture.add_item(title)
			gesture.select(["hold", "tap", "long", "double"].find(b.gesture))
			gesture.item_selected.connect(func(i: int) -> void: b.gesture = ["hold", "tap", "long", "double"][i])
			row.add_child(gesture)
			var command := OptionButton.new()
			command.custom_minimum_size.x = 170
			for id in commands:
				var clip := Character.find_action(doc.model, id)
				command.add_item(clip.get("name", id))
			command.select(maxi(0, commands.find(b.command)))
			command.item_selected.connect(func(i: int) -> void: b.command = commands[i])
			row.add_child(command)
			tool_button(row, "trash", "移除此绑定", func() -> void: row.hide(); b["removed"] = true)
	render.call()
	outline_button(col, "添加绑定", func() -> void:
		bindings.append({"key": "E", "gesture": "tap", "command": "idle"})
		render.call(), "new")
	var warning := label("", 12, ThemeKit.SIGNAL)
	col.add_child(warning)
	dialog.dialog_hide_on_ok = false
	dialog.confirmed.connect(func() -> void:
		var next: Array = []
		var seen := {}
		for b in bindings:
			if b.get("removed", false): continue
			if b.key.is_empty() or (not b.key in ["MouseLeft", "MouseRight"] and OS.find_keycode_from_string(b.key) == KEY_NONE):
				warning.text = "无法识别按键：" + b.key; return
			if seen.has(b.key + "/" + b.gesture): warning.text = "同一按键与手势只能绑定一个命令"; return
			if (b.command.begins_with("move_") and b.gesture != "hold") or (not b.command.begins_with("move_") and b.gesture == "hold"):
				warning.text = "持续移动用于方向命令；动作使用点按、长按或双击"; return
			seen[b.key + "/" + b.gesture] = true
			next.append(b)
		edit("修改控制绑定", func() -> void: doc.model.bindings = next)
		game_world.configure(doc.model, doc.textures)
		rebuild_inspector()
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(580, 400))


func rebuild_inspector() -> void:
	if inspector_panel != null: inspector_panel.render()
