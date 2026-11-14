extends RefCounted

const ThemeKit = preload("res://editor/theme.gd")
const Icons = preload("res://editor/icons.gd")
const Stage = preload("res://editor/stage.gd")
const PixelCanvas = preload("res://editor/pixel_canvas.gd")
const Timeline = preload("res://editor/timeline.gd")

var app: Control

func _init(editor: Control) -> void:
	app = editor

func build() -> void:
	app.building = true
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	app.add_child(root)
	var top_panel := PanelContainer.new()
	top_panel.add_theme_stylebox_override("panel", ThemeKit.box(Color("263136"), 0))
	root.add_child(top_panel)
	var top := HBoxContainer.new()
	app.margin(top_panel, 12).add_child(top)
	var brand = app.label("RigPop", 23, Color("e7f1ec"))
	brand.custom_minimum_size.x = 130
	top.add_child(brand)
	app.title_label = app.label("", 14, Color("c2cfca"))
	app.title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(app.title_label)
	app.button(top, "打开", app.open_project, "open").tooltip_text = "打开可编辑角色工程"
	app.save_button = app.button(top, "保存", app.save_project, "save")
	app.save_button.tooltip_text = "保存工程  Ctrl+S"
	app.button(top, "导出", app.show_export, "export")
	# Enhanced tab bar with clear workspace modes
	var tabs_panel := PanelContainer.new()
	tabs_panel.add_theme_stylebox_override("panel", ThemeKit.box(ThemeKit.BG_ELEVATED, 0, Color.TRANSPARENT, 0))
	root.add_child(tabs_panel)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	app.margin(tabs_panel, 10).add_child(tabs)

	for i in 4:
		var b = app.button(tabs, ["角色与动作", "像素绘制", "游戏试演", "桌宠试演"][i], func() -> void: app.set_mode(i))
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(110, 36)
		b.add_theme_font_size_override("font_size", 13)
		app.mode_buttons.append(b)

	app.expand(tabs)

	# Undo/redo with clear visual separation
	var history_container := HBoxContainer.new()
	history_container.add_theme_constant_override("separation", 4)
	tabs.add_child(history_container)
	app.undo_button = app.tool_button(history_container, "undo", "撤销  Ctrl+Z", app.undo)
	app.redo_button = app.tool_button(history_container, "redo", "重做  Ctrl+Y", app.redo)
	# Main content area with refined spacing
	var middle := VBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 0)
	root.add_child(middle)

	app.body_split = HSplitContainer.new()
	app.body_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	app.body_split.split_offset = 220
	middle.add_child(app.body_split)
	build_library(app.body_split)
	app.work_split = HSplitContainer.new()
	app.work_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app.work_split.split_offset = 740
	app.body_split.add_child(app.work_split)
	# Central workspace with improved toolbar
	var work := VBoxContainer.new()
	work.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	work.add_theme_constant_override("separation", 0)
	app.work_split.add_child(work)

	var toolbar_panel := PanelContainer.new()
	toolbar_panel.add_theme_stylebox_override("panel", ThemeKit.box(ThemeKit.BG_ELEVATED, 0, Color.TRANSPARENT, 0))
	work.add_child(toolbar_panel)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 6)
	app.margin(toolbar_panel, 8).add_child(toolbar)

	# View controls grouped
	var view_group := HBoxContainer.new()
	view_group.add_theme_constant_override("separation", 4)
	toolbar.add_child(view_group)
	app.tool_button(view_group, "minus", "缩小画布", func() -> void: app.set_zoom(-1))
	app.tool_button(view_group, "new", "放大画布", func() -> void: app.set_zoom(1))
	app.tool_button(view_group, "fit", "适合画布", func() -> void: app.stage.pan = Vector2.ZERO; app.stage.auto_fit = true; app.update_canvas())

	# Display options grouped
	var display_group := HBoxContainer.new()
	display_group.add_theme_constant_override("separation", 4)
	toolbar.add_child(display_group)
	var bone_button = app.tool_button(display_group, "bone", "显示骨骼与枢轴", func() -> void: app.stage.bones = not app.stage.bones; app.stage.queue_redraw())
	bone_button.toggle_mode = true
	bone_button.button_pressed = true
	var onion_button = app.tool_button(display_group, "eye", "洋葱皮：上一帧", func() -> void: app.stage.onion = not app.stage.onion; app.update_canvas())
	onion_button.toggle_mode = true
	app.tool_button(display_group, "flip", "镜像预览", func() -> void: app.stage.view.mirrored = not app.stage.view.mirrored; app.stage.view.queue_redraw())

	app.expand(toolbar)

	app.canvas_label = app.label("", 12, ThemeKit.TEXT_SECONDARY)
	app.canvas_label.custom_minimum_size.x = 160
	toolbar.add_child(app.canvas_label)
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
	app.pixel.stroke_started.connect(app.begin_change)
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
	# Inspector panel with better hierarchy
	var right := PanelContainer.new()
	right.custom_minimum_size.x = 260
	right.add_theme_stylebox_override("panel", ThemeKit.box(ThemeKit.BG_ELEVATED, 0, Color.TRANSPARENT, 0))
	app.work_split.add_child(right)

	var inspector_scroll := ScrollContainer.new()
	inspector_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(inspector_scroll)
	var inset = app.margin(inspector_scroll, 14)
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app.inspector = VBoxContainer.new()
	app.inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app.inspector.add_theme_constant_override("separation", 12)
	inset.add_child(app.inspector)
	build_timeline(middle)
	var footer_panel := PanelContainer.new()
	build_footer(footer_panel, root)
	app.file_dialog = FileDialog.new()
	app.file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	app.file_dialog.size = Vector2i(780, 540)
	app.file_dialog.file_selected.connect(app.file_selected)
	app.file_dialog.dir_selected.connect(app.directory_selected)
	app.add_child(app.file_dialog)
	app.confirm = ConfirmationDialog.new()
	app.confirm.title = "未保存的修改"
	app.confirm.dialog_text = "当前角色有未保存修改。继续将丢弃这些修改。"
	app.confirm.ok_button_text = "丢弃并继续"
	app.confirm.cancel_button_text = "返回编辑"
	app.confirm.confirmed.connect(func() -> void:
		if app.pending_action.is_valid(): app.pending_action.call())
	app.add_child(app.confirm)
	app.building = false

func build_footer(panel: PanelContainer, root: VBoxContainer) -> void:
	panel.add_theme_stylebox_override("panel", ThemeKit.box(ThemeKit.BG_PANEL, 0, Color.TRANSPARENT, 0))
	root.add_child(panel)
	var row := HBoxContainer.new()
	app.margin(panel, 8).add_child(row)
	app.status = app.label("就绪", 11, ThemeKit.TEXT_SECONDARY)
	app.status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(app.status)
	var version_info = app.label("v0.1.0  ·  Godot 4.7.2  ·  便携模式", 11, ThemeKit.MUTED)
	row.add_child(version_info)

func build_library(parent: Node) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 180
	panel.add_theme_stylebox_override("panel", ThemeKit.box(ThemeKit.BG_ELEVATED, 0, Color.TRANSPARENT, 0))
	parent.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	var inset = app.margin(scroll, 12)
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inset.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inset.add_child(col)

	app.heading(col, "角色库")
	app.library_picker = OptionButton.new()
	app.library_picker.custom_minimum_size.y = 34
	app.library_picker.item_selected.connect(func(i: int) -> void:
		var path: String = app.library_picker.get_item_metadata(i)
		if not path.is_empty(): app.guard(func() -> void: app.load_project(path)))
	col.add_child(app.library_picker)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)
	app.button(row, "新建", app.show_new, "new").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app.tool_button(row, "copy", "复制当前角色", app.duplicate_character)

	col.add_child(HSeparator.new())

	var header := HBoxContainer.new()
	col.add_child(header)
	app.heading(header, "部件")
	app.expand(header)
	var part_actions := HBoxContainer.new()
	part_actions.add_theme_constant_override("separation", 4)
	header.add_child(part_actions)
	app.tool_button(part_actions, "new", "添加空白部件", app.add_part)
	app.tool_button(part_actions, "trash", "删除选中部件（可撤销）", app.delete_part)

	app.tree = Tree.new()
	app.tree.custom_minimum_size.y = 150
	app.tree.hide_root = true
	app.tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	app.tree.item_selected.connect(func() -> void:
		if not app.building and app.tree.get_selected() != null: app.select_part(str(app.tree.get_selected().get_metadata(0))))
	col.add_child(app.tree)

	app.button(col, "导入图片 / 图集", app.import_image, "open")
	app.button(col, "控制绑定", app.show_controls)

func build_timeline(parent: Node) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeKit.box(ThemeKit.BG_ELEVATED, 0, Color.TRANSPARENT, 0))
	parent.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	panel.add_child(col)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	app.margin(col, 8).add_child(row)

	# Playback controls grouped
	var playback := HBoxContainer.new()
	playback.add_theme_constant_override("separation", 4)
	row.add_child(playback)
	app.tool_button(playback, "back", "返回首帧", func() -> void: app.seek(0))
	app.play_button = app.tool_button(playback, "play", "播放 / 暂停", app.toggle_play)

	app.action_picker = OptionButton.new()
	app.action_picker.custom_minimum_size = Vector2(130, 32)
	app.action_picker.item_selected.connect(func(i: int) -> void:
		app.action_id = app.doc.model.actions[i].id; app.seek(0); app.rebuild_inspector())
	row.add_child(app.action_picker)

	# Action management grouped
	var action_group := HBoxContainer.new()
	action_group.add_theme_constant_override("separation", 4)
	row.add_child(action_group)
	app.tool_button(action_group, "new", "新增动作", app.add_action)
	app.tool_button(action_group, "copy", "复制动作", app.duplicate_action)
	app.tool_button(action_group, "trash", "删除动作（可撤销）", app.delete_action)

	var rate := OptionButton.new()
	rate.custom_minimum_size.y = 32
	for text in ["0.5×", "1×", "2×"]: rate.add_item(text)
	rate.select(1)
	rate.item_selected.connect(func(i: int) -> void: app.playback_rate = [0.5, 1.0, 2.0][i])
	row.add_child(rate)

	# Keyframe controls grouped
	var key_group := HBoxContainer.new()
	key_group.add_theme_constant_override("separation", 4)
	row.add_child(key_group)
	var key_toggle = app.button(key_group, "关键帧", func() -> void: app.key_edit = not app.key_edit; app.rebuild_inspector(), "key")
	key_toggle.toggle_mode = true
	key_toggle.tooltip_text = "开启后，拖动与属性修改写入当前帧；关闭时编辑绑定姿势"
	app.tool_button(key_group, "key", "插入当前部件关键帧", app.insert_key)

	app.expand(row)

	app.frame_label = app.label("01 / 08", 12, ThemeKit.TEXT_SECONDARY)
	app.frame_label.custom_minimum_size.x = 60
	row.add_child(app.frame_label)

	app.timeline_scroll = ScrollContainer.new()
	app.timeline_scroll.custom_minimum_size.y = 160
	app.timeline_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	col.add_child(app.timeline_scroll)
	app.timeline = Timeline.new()
	app.timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app.timeline.frame_selected.connect(app.seek)
	app.timeline.track_selected.connect(app.select_part)
	app.timeline_scroll.add_child(app.timeline)
