extends RefCounted

const Character = preload("res://core/character.gd")
const ThemeKit = preload("res://editor/theme.gd")

var app: Control

func _init(editor: Control) -> void:
	app = editor

func render() -> void:
	if app.inspector == null: return
	for child in app.inspector.get_children():
		app.inspector.remove_child(child)
		child.queue_free()

	# Character section with improved hierarchy
	var character_header := HBoxContainer.new()
	app.inspector.add_child(character_header)
	app.heading(character_header, "角色")
	app.expand(character_header)

	app.name_field(app.inspector, app.doc.model.name, func(text: String) -> void:
		app.edit("重命名角色", func() -> void: app.doc.model.name = text)
		app.refresh_library())

	app.inspector.add_child(HSeparator.new())
	if app.mode == 2:
		game_inspector()
		return
	if app.mode == 3:
		desktop_inspector()
		return
	var p := Character.find_part(app.doc.model, app.selected)
	if p.is_empty():
		app.heading(app.inspector, "尚无部件")
		app.button(app.inspector, "添加部件", app.add_part, "new")
		return
	if app.mode == 1:
		pixel_inspector(p)
		return
	# Enhanced part inspector with clearer sections
	var part_header := HBoxContainer.new()
	app.inspector.add_child(part_header)
	app.heading(part_header, "部件 · " + p.name)
	app.expand(part_header)

	app.name_field(app.inspector, p.name, func(text: String) -> void:
		app.edit("重命名部件", func() -> void: p.name = text)
		app.rebuild_tree())

	# Parent selection
	app.heading(app.inspector, "父节点")
	var parent_picker := OptionButton.new()
	parent_picker.custom_minimum_size.y = 32
	parent_picker.add_item("无父节点")
	parent_picker.set_item_metadata(0, "")
	for candidate in app.doc.model.parts:
		if candidate.id == app.selected: continue
		parent_picker.add_item(candidate.name)
		parent_picker.set_item_metadata(parent_picker.item_count - 1, candidate.id)
		if candidate.id == p.parent: parent_picker.select(parent_picker.item_count - 1)
	parent_picker.item_selected.connect(func(i: int) -> void:
		var old: String = p.parent
		app.begin_change()
		p.parent = parent_picker.get_item_metadata(i)
		if not Character.validate(app.doc.model).is_empty():
			p.parent = old
			app.notify("无法挂接到自己的子节点", true)
		app.commit_change("修改父节点")
		app.rebuild_tree())
	app.inspector.add_child(parent_picker)

	# Transform section with visual grouping
	app.inspector.add_child(HSeparator.new())
	var transform_label := HBoxContainer.new()
	app.inspector.add_child(transform_label)
	app.heading(transform_label, "变换" if not app.key_edit else "关键帧变换")
	app.expand(transform_label)

	var clip := Character.find_action(app.doc.model, app.action_id)
	var pose := Character.pose(clip, p.id, app.frame)
	for axis in 2:
		var value := float(pose.position[axis] if app.key_edit else p.position[axis])
		app.number_field(app.inspector, ["位置 X / px", "位置 Y / px"][axis], value, -2048, 2048, 1, func(v: float) -> void:
			app.edit("修改位置", func() -> void:
				if app.key_edit:
					var updated := Character.pose(clip, p.id, app.frame)
					updated.position[axis] = v
					Character.set_key(clip, p.id, app.frame, updated)
				else: p.position[axis] = v))
	app.number_field(app.inspector, "旋转 / °", float(pose.rotation if app.key_edit else p.rotation), -360, 360, 1, func(v: float) -> void:
		app.edit("修改旋转", func() -> void:
			if app.key_edit:
				var updated := Character.pose(clip, p.id, app.frame)
				updated.rotation = v
				Character.set_key(clip, p.id, app.frame, updated)
			else: p.rotation = v))
	for axis in 2:
		app.number_field(app.inspector, ["枢轴 X / px", "枢轴 Y / px"][axis], float(p.pivot[axis]), -1024, 1024, 1, func(v: float) -> void:
			app.edit("修改枢轴", func() -> void: p.pivot[axis] = v))
	app.number_field(app.inspector, "绘制层级", float(p.z), -100, 100, 1, func(v: float) -> void:
		app.edit("修改层级", func() -> void: p.z = int(v)))
	app.check_field(app.inspector, "部件可见", bool(p.visible), func(v: bool) -> void:
		app.edit("切换可见性", func() -> void: p.visible = v)
		app.rebuild_tree())
	# Part actions with clear button styling
	app.inspector.add_child(HSeparator.new())
	app.button(app.inspector, "替换部件图片", app.choose_replacement, "open")
	if app.key_edit:
		app.button(app.inspector, "删除当前关键帧", app.remove_key, "trash")

	app.inspector.add_child(HSeparator.new())

	if not clip.is_empty():
		# Action properties section
		var action_header := HBoxContainer.new()
		app.inspector.add_child(action_header)
		app.heading(action_header, "动作 · " + clip.name)
		app.expand(action_header)
		app.name_field(app.inspector, clip.name, func(text: String) -> void:
			app.edit("重命名动作", func() -> void: clip.name = text)
			app.refresh_all())
		app.number_field(app.inspector, "帧率 / fps", float(clip.fps), 1, 60, 1, func(v: float) -> void:
			app.edit("修改帧率", func() -> void: clip.fps = v))
		app.number_field(app.inspector, "动作帧数", float(clip.frames), 1, 240, 1, func(v: float) -> void:
			app.edit("修改动作长度", func() -> void:
				clip.frames = int(v)
				for keys in clip.tracks.values():
					for i in range(keys.size() - 1, -1, -1):
						if int(keys[i].frame) >= int(v): keys.remove_at(i)
				app.frame = mini(app.frame, int(v) - 1)))
		app.check_field(app.inspector, "循环播放", bool(clip.loop), func(v: bool) -> void: app.edit("修改循环", func() -> void: clip.loop = v))
		app.check_field(app.inspector, "叠加动作（仅含轨道）", bool(clip.overlay), func(v: bool) -> void: app.edit("修改动作类型", func() -> void: clip.overlay = v))

func pixel_inspector(p: Dictionary) -> void:
	# Pixel editor section with better tool organization
	var pixel_header := HBoxContainer.new()
	app.inspector.add_child(pixel_header)
	app.heading(pixel_header, "像素 · " + p.name)
	app.expand(pixel_header)

	# Tool palette with clearer grouping
	app.heading(app.inspector, "工具")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	app.inspector.add_child(row)

	for id in ["pencil", "eraser", "fill", "picker"]:
		var b: Button = app.tool_button(row, id, {"pencil": "铅笔", "eraser": "橡皮", "fill": "填充", "picker": "取色"}[id], func() -> void: app.pixel.tool = id; render())
		b.toggle_mode = true
		b.button_pressed = app.pixel.tool == id
		b.custom_minimum_size = Vector2(38, 38)

	# Color picker with better spacing
	app.heading(app.inspector, "颜色")
	var picker := ColorPickerButton.new()
	picker.color = app.pixel.color
	picker.custom_minimum_size.y = 40
	picker.color_changed.connect(func(c: Color) -> void: app.pixel.color = c)
	app.inspector.add_child(picker)

	# Palette with improved layout
	app.heading(app.inspector, "色板")
	var palette := HFlowContainer.new()
	palette.add_theme_constant_override("h_separation", 6)
	palette.add_theme_constant_override("v_separation", 6)
	app.inspector.add_child(palette)
	for hex in app.doc.model.palette:
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(28, 28)
		swatch.tooltip_text = "#" + hex
		swatch.add_theme_stylebox_override("normal", ThemeKit.box(Color(hex), 4, Color.TRANSPARENT, 0))
		swatch.add_theme_stylebox_override("hover", ThemeKit.box(Color(hex), 4, ThemeKit.ACCENT, 0))
		swatch.add_theme_stylebox_override("pressed", ThemeKit.box(Color(hex).darkened(0.1), 4, ThemeKit.ACCENT_PRESSED, 0))
		swatch.pressed.connect(func() -> void: app.pixel.color = Color(hex); render())
		palette.add_child(swatch)

	app.button(app.inspector, "加入色板", func() -> void:
		app.edit("添加色板颜色", func() -> void:
			var hex: String = app.pixel.color.to_html()
			if not app.doc.model.palette.has(hex): app.doc.model.palette.append(hex))
		render(), "new")

	# Image operations section
	app.inspector.add_child(HSeparator.new())
	app.heading(app.inspector, "图片操作")
	app.button(app.inspector, "当前帧独立换图", app.isolate_frame, "copy")
	app.button(app.inspector, "裁去透明边缘", app.crop_image)
	app.button(app.inspector, "调整画布 / 重采样", app.resize_dialog)
	app.button(app.inspector, "替换图片", app.choose_replacement, "open")

	app.inspector.add_child(HSeparator.new())
	app.heading(app.inspector, "当前颜色：#" + app.pixel.color.to_html().to_upper())

func game_inspector() -> void:
	app.heading(app.inspector, "游戏场景")
	app.number_field(app.inspector, "移动 / px/s", float(app.doc.model.game.speed), 10, 600, 1, func(v: float) -> void:
		app.edit("修改移动速度", func() -> void: app.doc.model.game.speed = v)
		app.game_world.configure(app.doc.model, app.doc.textures))
	app.number_field(app.inspector, "碰撞半径 / px", float(app.doc.model.game.collision_radius), 2, 40, 1, func(v: float) -> void:
		app.edit("修改碰撞半径", func() -> void: app.doc.model.game.collision_radius = v)
		app.game_world.configure(app.doc.model, app.doc.textures))
	app.button(app.inspector, "操控角色", func() -> void: app.game_container.grab_focus())
	app.button(app.inspector, "复位场景", func() -> void: app.game_world.reset_world())
	app.button(app.inspector, "控制绑定", app.show_controls)
	app.inspector.add_child(HSeparator.new())
	app.heading(app.inspector, "当前绑定")
	for binding in app.doc.model.bindings:
		app.heading(app.inspector, "%s  ·  %s" % [binding.key, binding.command])

func desktop_inspector() -> void:
	app.heading(app.inspector, "桌宠窗口")
	app.number_field(app.inspector, "像素倍率", float(app.doc.model.desktop.scale), 1, 8, 1, func(v: float) -> void:
		app.edit("修改桌宠倍率", func() -> void: app.doc.model.desktop.scale = int(v)))
	app.check_field(app.inspector, "窗口置顶", bool(app.doc.model.desktop.always_on_top), func(v: bool) -> void:
		app.edit("修改置顶", func() -> void: app.doc.model.desktop.always_on_top = v))
	app.check_field(app.inspector, "自由漫游", bool(app.doc.model.desktop.wander), func(v: bool) -> void:
		app.edit("修改漫游", func() -> void: app.doc.model.desktop.wander = v))
	app.button(app.inspector, "启动独立桌宠", app.launch_desktop, "play")
	app.button(app.inspector, "停止试演", app.stop_desktop, "pause")
	app.button(app.inspector, "控制绑定", app.show_controls)
	app.inspector.add_child(HSeparator.new())
	app.heading(app.inspector, "透明窗口 · 拖动 · 右键菜单")
	app.heading(app.inspector, "全局快捷键：暂不支持")
	app.heading(app.inspector, "整窗点击穿透：暂不支持")
