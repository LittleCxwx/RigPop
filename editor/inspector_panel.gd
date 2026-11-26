extends RefCounted

const Character = preload("res://core/character.gd")
const Rig = preload("res://core/rig.gd")
const ThemeKit = preload("res://editor/theme.gd")

var app: Control

func _init(editor: Control) -> void:
	app = editor

func render() -> void:
	if app.inspector == null: return
	for child in app.inspector.get_children():
		app.inspector.remove_child(child)
		child.queue_free()

	section("角色")
	app.name_field(app.inspector, app.doc.model.name, func(text: String) -> void:
		app.edit("重命名角色", func() -> void: app.doc.model.name = text)
		app.refresh_library())
	if app.mode == 0:
		var rig_picker := OptionButton.new()
		rig_picker.add_item("自由结构")
		rig_picker.set_item_metadata(0, "")
		for rig in Rig.SUPPORTED:
			rig_picker.add_item(Rig.rig_name(rig))
			rig_picker.set_item_metadata(rig_picker.item_count - 1, rig)
			if Rig.detect(app.doc.model) == rig: rig_picker.select(rig_picker.item_count - 1)
		rig_picker.item_selected.connect(func(i: int) -> void: app.set_rig(str(rig_picker.get_item_metadata(i))))
		app.inspector.add_child(rig_picker)

	if app.mode == 2:
		game_inspector()
		return
	if app.mode == 3:
		desktop_inspector()
		return
	var p := Character.find_part(app.doc.model, app.selected)
	if p.is_empty():
		rule()
		section("尚无部件")
		app.action_row(app.inspector, "添加部件", "new", app.add_part)
		return
	if app.mode == 1 and p.get("kind", "part") != "joint":
		pixel_inspector(p)
		return
	part_inspector(p)

func part_inspector(p: Dictionary) -> void:
	rule()
	var joint: bool = p.get("kind", "part") == "joint"
	section(("关节 · " if joint else "部件 · ") + p.name)
	app.name_field(app.inspector, p.name, func(text: String) -> void:
		app.edit("重命名部件", func() -> void: p.name = text)
		app.rebuild_tree())
	var rig := Rig.detect(app.doc.model)
	if not rig.is_empty():
		var role_picker := OptionButton.new()
		role_picker.add_item("普通部件 · 不参与动作匹配")
		role_picker.set_item_metadata(0, "")
		role_picker.fit_to_longest_item = false
		for role in Rig.roles(rig):
			role_picker.add_item(Rig.role_title(role))
			role_picker.set_item_metadata(role_picker.item_count - 1, role)
			if p.get("role", "") == role: role_picker.select(role_picker.item_count - 1)
		role_picker.item_selected.connect(func(i: int) -> void: app.set_part_role(str(p.id), str(role_picker.get_item_metadata(i))))
		app.inspector.add_child(role_picker)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	app.inspector.add_child(row)
	var caption = app.label("父节点", 13, ThemeKit.INK_2)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.custom_minimum_size.x = 0
	row.add_child(caption)
	var parent_picker := OptionButton.new()
	parent_picker.custom_minimum_size = Vector2(136, 26)
	parent_picker.fit_to_longest_item = false
	parent_picker.add_item("无父节点")
	parent_picker.set_item_metadata(0, "")
	for candidate in app.doc.model.parts:
		if candidate.id == app.selected: continue
		parent_picker.add_item(("关节 · " if candidate.get("kind", "part") == "joint" else "") + candidate.name)
		parent_picker.set_item_metadata(parent_picker.item_count - 1, candidate.id)
		if candidate.id == p.parent: parent_picker.select(parent_picker.item_count - 1)
	parent_picker.item_selected.connect(func(i: int) -> void:
		app.begin_change()
		if not Character.reparent(app.doc.model, p.id, str(parent_picker.get_item_metadata(i))):
			app.notify("无法挂接到自己的子节点", true)
		app.commit_change("修改父节点")
		app.rebuild_tree()
		app.rebuild_inspector.call_deferred())
	row.add_child(parent_picker)

	section("变换" if not app.key_edit else "关键帧变换")
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
		if joint: break
		app.number_field(app.inspector, ["枢轴 X / px", "枢轴 Y / px"][axis], float(p.pivot[axis]), -1024, 1024, 1, func(v: float) -> void:
			app.edit("修改枢轴", func() -> void: p.pivot[axis] = v))
	if not joint:
		app.number_field(app.inspector, "绘制层级", float(p.z), -100, 100, 1, func(v: float) -> void:
			app.edit("修改层级", func() -> void: p.z = int(v)))
	app.check_field(app.inspector, "部件可见", bool(p.visible), func(v: bool) -> void:
		app.edit("切换可见性", func() -> void: p.visible = v)
		app.rebuild_tree())

	app.gap(app.inspector, 4)
	if joint: app.action_row(app.inspector, "添加子关节", "bone", app.add_joint)
	else: app.action_row(app.inspector, "替换部件图片", "image", app.choose_replacement)
	if app.key_edit:
		app.action_row(app.inspector, "删除当前关键帧", "trash", app.remove_key)

	if not clip.is_empty():
		rule()
		section("动作 · " + clip.name)
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
		app.number_field(app.inspector, "动作优先级", float(clip.get("priority", 0)), -100, 100, 1, func(v: float) -> void:
			app.edit("修改动作优先级", func() -> void: clip.priority = int(v)))
		var conflict := OptionButton.new()
		conflict.add_item("冲突时替换低 / 同优先级动作")
		conflict.add_item("冲突时放弃本次动作")
		conflict.fit_to_longest_item = false
		conflict.custom_minimum_size.y = 28
		conflict.select(1 if clip.get("conflict", "replace") == "reject" else 0)
		conflict.item_selected.connect(func(i: int) -> void:
			app.edit("修改动作冲突规则", func() -> void: clip.conflict = ["replace", "reject"][i]))
		app.inspector.add_child(conflict)
		app.check_field(app.inspector, "播放时禁止移动", bool(clip.get("lock_movement", false)), func(v: bool) -> void:
			app.edit("修改动作移动限制", func() -> void: clip.lock_movement = v))
		app.action_row(app.inspector, "存为骨骼预设", "save", app.save_action_as_preset)

func pixel_inspector(p: Dictionary) -> void:
	rule()
	section("像素 · " + p.name)

	var scope := HBoxContainer.new()
	scope.add_theme_constant_override("separation", 4)
	app.inspector.add_child(scope)
	var group := ButtonGroup.new()
	for i in 2:
		var option: Button = app.button(scope, ["当前帧", "共用图片"][i], func() -> void:
			app.pixel_frame_edit = i == 0
			app.rebuild_inspector.call_deferred())
		option.toggle_mode = true
		option.button_group = group
		option.button_pressed = app.pixel_frame_edit == (i == 0)
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.tooltip_text = ["只修改当前帧的像素", "修改使用这张图片的所有帧"][i]

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 4)
	app.inspector.add_child(tools)
	for id in ["pencil", "eraser", "fill", "picker"]:
		var b: Button = app.tool_button(tools, id, {"pencil": "铅笔", "eraser": "橡皮", "fill": "填充", "picker": "取色"}[id], func() -> void:
			app.pixel.tool = id
			render())
		b.toggle_mode = true
		b.button_pressed = app.pixel.tool == id
		b.custom_minimum_size = Vector2(32, 30)

	var picker := ColorPickerButton.new()
	picker.color = app.pixel.color
	picker.custom_minimum_size.y = 30
	picker.edit_alpha = true
	picker.color_changed.connect(func(c: Color) -> void: app.pixel.color = c)
	app.inspector.add_child(picker)
	ThemeKit.style_color_picker(picker.get_picker())

	section("色板")
	var palette := HFlowContainer.new()
	palette.add_theme_constant_override("h_separation", 4)
	palette.add_theme_constant_override("v_separation", 4)
	app.inspector.add_child(palette)
	for hex in app.doc.model.palette:
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(24, 24)
		swatch.focus_mode = Control.FOCUS_NONE
		swatch.tooltip_text = "#" + hex
		swatch.add_theme_stylebox_override("normal", ThemeKit.flat(Color(hex), 3))
		swatch.add_theme_stylebox_override("hover", ThemeKit.flat(Color(hex), 3, ThemeKit.INK))
		swatch.add_theme_stylebox_override("pressed", ThemeKit.flat(Color(hex), 3, ThemeKit.INK))
		swatch.pressed.connect(func() -> void:
			app.pixel.color = Color(hex)
			render())
		palette.add_child(swatch)
	app.action_row(app.inspector, "加入色板", "new", func() -> void:
		app.edit("添加色板颜色", func() -> void:
			var hex: String = app.pixel.color.to_html()
			if not app.doc.model.palette.has(hex): app.doc.model.palette.append(hex))
		render())

	rule()
	section("图片操作")
	app.action_row(app.inspector, "当前帧独立换图", "copy", app.isolate_frame)
	var previous: Button = app.action_row(app.inspector, "复制上一帧图片", "copy", app.copy_previous_frame)
	previous.disabled = app.frame == 0
	app.action_row(app.inspector, "新建空白帧", "new", app.blank_frame)
	app.action_row(app.inspector, "导入当前帧图片", "image", app.choose_frame_replacement)
	var crop: Button = app.action_row(app.inspector, "裁去透明边缘", "fit", app.crop_image)
	crop.disabled = app.pixel_frame_edit or app.current_asset(p) != str(p.asset)
	crop.tooltip_text = "基础图片裁边会同步枢轴；逐帧图片请使用画布调整"
	app.action_row(app.inspector, "调整画布 / 重采样", "flip", app.resize_dialog)

	rule()
	section("当前颜色")
	var swatch_row := HBoxContainer.new()
	swatch_row.add_theme_constant_override("separation", 8)
	app.inspector.add_child(swatch_row)
	var chip := Panel.new()
	chip.custom_minimum_size = Vector2(18, 18)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_theme_stylebox_override("panel", ThemeKit.flat(app.pixel.color, 3, ThemeKit.LINE_2))
	swatch_row.add_child(chip)
	var hex_label = app.label("#" + app.pixel.color.to_html().to_upper(), 12, ThemeKit.INK_2)
	hex_label.custom_minimum_size.x = 0
	swatch_row.add_child(hex_label)

func game_inspector() -> void:
	rule()
	section("游戏场景")
	app.number_field(app.inspector, "显示倍率", float(app.doc.model.game.get("visual_scale", 2.0)), 0.1, 8, 0.05, func(v: float) -> void:
		app.edit("修改游戏显示倍率", func() -> void: app.doc.model.game.visual_scale = v)
		app.game_world.configure(app.doc.model, app.doc.textures))
	app.number_field(app.inspector, "移动 / px·s", float(app.doc.model.game.speed), 10, 600, 1, func(v: float) -> void:
		app.edit("修改移动速度", func() -> void: app.doc.model.game.speed = v)
		app.game_world.configure(app.doc.model, app.doc.textures))
	app.number_field(app.inspector, "碰撞半径 / px", float(app.doc.model.game.collision_radius), 2, 40, 1, func(v: float) -> void:
		app.edit("修改碰撞半径", func() -> void: app.doc.model.game.collision_radius = v)
		app.game_world.configure(app.doc.model, app.doc.textures))
	app.gap(app.inspector, 4)
	app.action_row(app.inspector, "操控角色", "play", func() -> void: app.game_container.grab_focus())
	app.action_row(app.inspector, "复位场景", "back", func() -> void: app.game_world.reset_world())
	app.action_row(app.inspector, "控制绑定", "keys", app.show_controls)

	rule()
	section("当前绑定")
	for binding in app.doc.model.bindings:
		var line = app.label("%s　·　%s" % [binding.key, binding.command], 12, ThemeKit.INK_2)
		line.custom_minimum_size.x = 0
		app.inspector.add_child(line)

func desktop_inspector() -> void:
	rule()
	section("桌宠窗口")
	app.number_field(app.inspector, "像素倍率", float(app.doc.model.desktop.scale), 1, 8, 1, func(v: float) -> void:
		app.edit("修改桌宠倍率", func() -> void: app.doc.model.desktop.scale = int(v)))
	app.check_field(app.inspector, "窗口置顶", bool(app.doc.model.desktop.always_on_top), func(v: bool) -> void:
		app.edit("修改置顶", func() -> void: app.doc.model.desktop.always_on_top = v))
	app.check_field(app.inspector, "自由漫游", bool(app.doc.model.desktop.wander), func(v: bool) -> void:
		app.edit("修改漫游", func() -> void: app.doc.model.desktop.wander = v))
	app.gap(app.inspector, 4)
	app.desktop_start_button = app.action_row(app.inspector, "启动独立桌宠", "play", app.launch_desktop)
	app.desktop_stop_button = app.action_row(app.inspector, "停止试演", "pause", app.stop_desktop)
	app.update_desktop_buttons()
	app.action_row(app.inspector, "控制绑定", "keys", app.show_controls)
	app.action_row(app.inspector, "状态与动作", "key", app.show_desktop_states)

# --- 排版小工具 ---------------------------------------------------------

func section(title: String) -> void:
	app.gap(app.inspector, 8)
	app.heading(app.inspector, title)

## 分区之间的细线：上下各留白，避免把界面切成一条条表格。
func rule() -> void:
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_top", 10)
	wrap.add_theme_constant_override("margin_bottom", 8)
	wrap.add_child(HSeparator.new())
	app.inspector.add_child(wrap)
