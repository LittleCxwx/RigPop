extends RefCounted

const ThemeKit = preload("res://editor/theme.gd")
const Icons = preload("res://editor/icons.gd")
const ConfirmBox = preload("res://editor/confirm_box.gd")
const Stage = preload("res://editor/stage.gd")
const PixelCanvas = preload("res://editor/pixel_canvas.gd")
const Timeline = preload("res://editor/timeline.gd")

const RAIL_WIDTH := 196
const INSPECTOR_WIDTH := 268
const MODE_TITLES := ["角色与动作", "像素绘制", "游戏试演", "桌宠试演"]

var app: Control

func _init(editor: Control) -> void:
	app = editor

func build() -> void:
	app.building = true
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	app.add_child(root)

	build_topbar(root)

	var middle := VBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 0)
	root.add_child(middle)

	app.body_split = HBoxContainer.new()
	app.body_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	app.body_split.add_theme_constant_override("separation", 0)
	middle.add_child(app.body_split)

	build_library(app.body_split)

	app.work_split = HBoxContainer.new()
	app.work_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app.work_split.add_theme_constant_override("separation", 0)
	app.body_split.add_child(app.work_split)

	build_workspace(app.work_split)
	build_inspector(app.work_split)
	build_timeline(middle)
	build_footer(root)
	build_dialogs()
	app.building = false

# --- 顶栏：品牌、模式页签、文档名与全局动作全部收在一行 -------------------

func build_topbar(root: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	var style := ThemeKit.flat(ThemeKit.PAPER)
	style.border_width_bottom = 1
	style.border_color = ThemeKit.LINE
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size.y = 48
	root.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	app.inset(panel, 14, 10, 0, 0).add_child(row)

	var brand := HBoxContainer.new()
	brand.add_theme_constant_override("separation", 8)
	brand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(brand)
	# 品牌标记：作者自己的像素图标，按 2 倍资源 + 双线性缩到 26×24。
	var mark := TextureRect.new()
	mark.texture = load("res://assets/rigpop-mark.png")
	mark.custom_minimum_size = Vector2(26, 24)
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_SCALE
	mark.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brand.add_child(mark)
	var wordmark = app.label("RigPop", 16, ThemeKit.INK)
	wordmark.add_theme_font_override("font", ThemeKit.font(ThemeKit.W_TITLE))
	app.resize_label(wordmark, 120.0)
	wordmark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brand.add_child(wordmark)

	hspace(row, 20)
	for i in MODE_TITLES.size():
		app.mode_buttons.append(app.tab_button(row, MODE_TITLES[i], func() -> void: app.set_mode(i)))

	app.expand(row)

	var doc := HBoxContainer.new()
	doc.add_theme_constant_override("separation", 7)
	doc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(doc)
	app.title_label = app.label("", 13, ThemeKit.INK_2)
	app.title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	doc.add_child(app.title_label)
	app.dirty_dot = app.mark_dot()
	doc.add_child(app.dirty_dot)

	hspace(row, 16)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 2)
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(actions)
	var open = app.button(actions, "打开", app.open_project)
	open.tooltip_text = "打开可编辑角色工程"
	var export = app.button(actions, "导出", app.show_export)
	export.tooltip_text = "导出 Godot 角色包、桌宠包或工程副本"
	hspace(actions, 6)
	app.save_button = app.primary_button(actions, "保存", app.save_project)
	app.save_button.tooltip_text = "保存工程  Ctrl+S"
	for child in actions.get_children():
		if child is Button:
			child.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	divider(row)
	app.undo_button = app.tool_button(row, "undo", "撤销  Ctrl+Z", app.undo)
	app.redo_button = app.tool_button(row, "redo", "重做  Ctrl+Y", app.redo)
	for child in [app.undo_button, app.redo_button]:
		child.size_flags_vertical = Control.SIZE_SHRINK_CENTER

# --- 左栏：角色库、部件层级、导入入口 -----------------------------------

func build_library(parent: Node) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = RAIL_WIDTH
	var style := ThemeKit.flat(ThemeKit.PAPER)
	style.border_width_right = 1
	style.border_color = ThemeKit.LINE
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	var inset = app.inset(panel, 12, 10, 14, 10)
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inset.add_child(col)

	app.heading(col, "角色库")
	app.library_picker = OptionButton.new()
	app.library_picker.custom_minimum_size = Vector2(0, 28)
	app.library_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app.library_picker.tooltip_text = "切换最近打开的角色工程"
	app.library_picker.item_selected.connect(func(i: int) -> void:
		var path: String = app.library_picker.get_item_metadata(i)
		if not path.is_empty(): app.guard(func() -> void: app.load_project(path)))
	col.add_child(app.library_picker)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	col.add_child(row)
	var fresh = app.outline_button(row, "新建", app.show_new)
	fresh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app.tool_button(row, "copy", "复制当前角色", app.duplicate_character)

	app.gap(col, 8)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 2)
	col.add_child(header)
	app.heading(header, "部件")
	app.expand(header)
	small_tool(header, "new", "添加空白部件", app.add_part)
	small_tool(header, "bone", "添加关节", app.add_joint)
	small_tool(header, "trash", "删除选中部件（可撤销）", app.delete_part)

	app.tree = Tree.new()
	app.tree.custom_minimum_size.y = 120
	app.tree.hide_root = true
	app.tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	app.tree.item_selected.connect(func() -> void:
		if app.building: return
		var item: TreeItem = app.tree.get_selected()
		if item != null:
			# Selection rebuilds the tree; wait until Godot finishes using the clicked item.
			app.select_part.call_deferred(str(item.get_metadata(0))))
	col.add_child(app.tree)

	col.add_child(HSeparator.new())
	app.action_row(col, "导入图片 / 图集", "image", app.import_image)
	app.action_row(col, "控制绑定", "keys", app.show_controls)

# --- 中央画布：一条 34 px 工具带 + 深色舞台 ------------------------------

func build_workspace(parent: Node) -> void:
	var work := VBoxContainer.new()
	work.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	work.add_theme_constant_override("separation", 0)
	parent.add_child(work)

	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", ThemeKit.flat(ThemeKit.PAPER))
	bar.custom_minimum_size.y = 34
	work.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	app.inset(bar, 7, 10, 0, 0).add_child(row)

	app.tool_button(row, "minus", "缩小画布", func() -> void: app.set_zoom(-1))
	app.tool_button(row, "new", "放大画布", func() -> void: app.set_zoom(1))
	app.tool_button(row, "fit", "适合画布", func() -> void:
		app.stage.pan = Vector2.ZERO
		app.stage.auto_fit = true
		app.update_canvas())

	divider(row)

	var bones = app.tool_button(row, "bone", "显示骨骼与枢轴", func() -> void:
		app.stage.bones = not app.stage.bones
		app.stage.queue_redraw())
	bones.toggle_mode = true
	bones.button_pressed = true
	var onion = app.tool_button(row, "eye", "洋葱皮：叠加显示上一帧", func() -> void:
		app.stage.onion = not app.stage.onion
		app.update_canvas())
	onion.toggle_mode = true
	app.tool_button(row, "flip", "镜像预览", func() -> void:
		app.stage.view.mirrored = not app.stage.view.mirrored
		app.stage.view.queue_redraw())

	app.expand(row)

	app.canvas_label = app.label("", 11, ThemeKit.MUTED)
	app.canvas_label.custom_minimum_size.x = 0
	app.canvas_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	app.canvas_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(app.canvas_label)

	for child in row.get_children():
		if child is Button:
			child.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	app.stage_stack = Control.new()
	app.stage_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	app.stage_stack.custom_minimum_size = Vector2(240, 160)
	work.add_child(app.stage_stack)

	app.stage = Stage.new()
	app.stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.stage_stack.add_child(app.stage)
	app.stage.part_selected.connect(app.select_part)
	app.stage.drag_started.connect(func() -> void: app.playing = false; app.begin_change())
	app.stage.part_dragged.connect(app.drag_part)
	app.stage.drag_finished.connect(func() -> void: app.commit_change("移动部件"); app.rebuild_inspector())

	app.pixel = PixelCanvas.new()
	app.pixel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.stage_stack.add_child(app.pixel)
	app.pixel.stroke_started.connect(app.begin_pixel_stroke)
	app.pixel.stroke_finished.connect(func() -> void: app.commit_change("像素笔画"); app.doc.refresh_textures(); app.update_canvas())
	app.pixel.image_changed.connect(func() -> void: app.doc.refresh_textures(); app.stored_dirty = true)
	app.pixel.color_picked.connect(func(c: Color) -> void: app.pixel.color = c; app.rebuild_inspector())

	app.game_container = SubViewportContainer.new()
	app.game_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.game_container.stretch = true
	app.game_container.focus_mode = Control.FOCUS_ALL
	app.game_container.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			app.game_container.grab_focus())
	app.stage_stack.add_child(app.game_container)

	app.game_viewport = SubViewport.new()
	app.game_viewport.size = Vector2i(640, 400)
	app.game_viewport.handle_input_locally = true
	app.game_container.add_child(app.game_viewport)
	app.game_world = load("res://runtime/game/world.tscn").instantiate()
	app.game_viewport.add_child(app.game_world)

# --- 右栏：属性检查器 ---------------------------------------------------

func build_inspector(parent: Node) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = INSPECTOR_WIDTH
	var style := ThemeKit.flat(ThemeKit.PAPER)
	style.border_width_left = 1
	style.border_color = ThemeKit.LINE
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var inset = app.inset(scroll, 14, 12, 14, 18)
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app.inspector = VBoxContainer.new()
	app.inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app.inspector.add_theme_constant_override("separation", 4)
	inset.add_child(app.inspector)

# --- 时间轴：播放、动作、关键帧三段，不要一排等重按钮 --------------------

func build_timeline(parent: Node) -> void:
	var panel := PanelContainer.new()
	var style := ThemeKit.flat(ThemeKit.PAPER)
	style.border_width_top = 1
	style.border_color = ThemeKit.LINE
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	panel.add_child(col)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 2)
	app.inset(col, 7, 10, 0, 0).add_child(bar)

	app.tool_button(bar, "back", "返回首帧", func() -> void: app.seek(0))
	app.play_button = app.tool_button(bar, "play", "播放 / 暂停", app.toggle_play)

	divider(bar)

	app.action_picker = OptionButton.new()
	app.action_picker.custom_minimum_size = Vector2(108, 26)
	app.action_picker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	app.action_picker.item_selected.connect(func(i: int) -> void:
		app.action_id = app.doc.model.actions[i].id
		app.seek(0)
		app.rebuild_inspector())
	bar.add_child(app.action_picker)

	divider(bar)

	small_tool(bar, "new", "新增动作", app.add_action)
	small_tool(bar, "copy", "复制动作", app.duplicate_action)
	small_tool(bar, "trash", "删除动作（可撤销）", app.delete_action)

	divider(bar)

	var rate := OptionButton.new()
	rate.custom_minimum_size = Vector2(58, 26)
	rate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for text in ["0.5×", "1×", "2×"]: rate.add_item(text)
	rate.select(1)
	rate.tooltip_text = "播放速率"
	rate.item_selected.connect(func(i: int) -> void: app.playback_rate = [0.5, 1.0, 2.0][i])
	bar.add_child(rate)

	divider(bar)

	var key_toggle = app.button(bar, "关键帧", func() -> void:
		app.key_edit = not app.key_edit
		app.rebuild_inspector())
	key_toggle.toggle_mode = true
	key_toggle.custom_minimum_size.y = 26
	key_toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	key_toggle.tooltip_text = "开启后，拖动与属性修改写入当前帧；关闭时编辑绑定姿势"
	key_toggle.add_theme_stylebox_override("pressed", key_box(ThemeKit.SELECT, ThemeKit.INK_2))
	key_toggle.add_theme_stylebox_override("hover_pressed", key_box(ThemeKit.SELECT, ThemeKit.INK))
	key_toggle.add_theme_color_override("font_pressed_color", ThemeKit.INK)
	app.tool_button(bar, "keyplus", "插入当前部件关键帧", app.insert_key)

	for child in bar.get_children():
		if child is Button:
			child.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	app.expand(bar)

	app.frame_label = app.label("01 / 08", 12, ThemeKit.MUTED)
	app.frame_label.custom_minimum_size.x = 0
	app.frame_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	app.frame_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(app.frame_label)

	app.timeline_scroll = ScrollContainer.new()
	app.timeline_scroll.custom_minimum_size.y = 148
	app.timeline_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	col.add_child(app.timeline_scroll)
	app.timeline = Timeline.new()
	app.timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app.timeline.frame_selected.connect(app.seek)
	app.timeline.track_selected.connect(app.select_part)
	app.timeline.key_moved.connect(app.move_key)
	app.timeline_scroll.add_child(app.timeline)

func build_footer(root: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	var style := ThemeKit.flat(ThemeKit.PAPER)
	style.border_width_top = 1
	style.border_color = ThemeKit.LINE
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size.y = 26
	root.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	app.inset(panel, 12, 12, 0, 0).add_child(row)
	app.status = app.label("就绪", 11, ThemeKit.MUTED)
	app.status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app.status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(app.status)
	var version = app.label("v%s  ·  Godot 4.7.2  ·  便携模式" % ProjectSettings.get_setting("application/config/version"), 11, ThemeKit.MUTED)
	version.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(version)

func build_dialogs() -> void:
	app.file_dialog = FileDialog.new()
	app.file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	app.file_dialog.size = Vector2i(780, 540)
	app.file_dialog.file_selected.connect(app.file_selected)
	app.file_dialog.dir_selected.connect(app.directory_selected)
	app.add_child(app.file_dialog)
	app.confirm = ConfirmBox.new()
	app.confirm.setup("未保存的修改", "当前角色有未保存的修改，继续操作会丢弃这些改动。", "丢弃并继续", "返回编辑")
	app.confirm.confirmed.connect(func() -> void:
		if app.pending_action.is_valid(): app.pending_action.call())
	app.add_child(app.confirm)

# --- 小工具 -------------------------------------------------------------

func hspace(parent: Node, width: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size.x = width
	parent.add_child(c)
	return c

## 分组竖线：1 px 线两侧各留 7 px，替代给每个按钮描边。
func divider(parent: Node) -> void:
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_left", 7)
	wrap.add_theme_constant_override("margin_right", 7)
	wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wrap.add_child(app.rule_v(14))
	parent.add_child(wrap)

## 栏内的小号图标按钮（标题行、时间轴动作行）。
func small_tool(parent: Node, icon: String, tip: String, callback: Callable) -> Button:
	var b = app.tool_button(parent, icon, tip, callback)
	b.custom_minimum_size = Vector2(22, 22)
	b.icon = Icons.get_icon(icon, 14, ThemeKit.INK_2)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b

func key_box(fill: Color, line: Color) -> StyleBoxFlat:
	var s := ThemeKit.flat(fill, 3, line, 10, 3)
	return s
