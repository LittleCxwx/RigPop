extends ConfirmationDialog

signal import_requested(entries: Array, rig: String)

const Rig = preload("res://core/rig.gd")
const Mapper = preload("res://services/psd_mapper.gd")
const ThemeKit = preload("res://editor/theme.gd")

var entries: Array = []
var rig := Rig.QUADRUPED
var rows := VBoxContainer.new()
var error_label := Label.new()
var preview := TextureRect.new()
var selected_layers: Array[CheckBox] = []

func setup(reader: RefCounted, path: String) -> void:
	title = "PSD 骨骼匹配 · " + path.get_file()
	ok_button_text = "导入角色"
	cancel_button_text = "取消"
	dialog_hide_on_ok = false
	entries = Mapper.assign(reader.layers, rig)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var dimensions := Label.new()
	dimensions.text = "%d × %d px  ·  %d 图层" % [reader.width, reader.height, entries.size()]
	dimensions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(dimensions)
	var picker := OptionButton.new()
	for key in Rig.SUPPORTED:
		picker.add_item(Rig.rig_name(key))
		picker.set_item_metadata(picker.item_count - 1, key)
	header.add_child(picker)
	picker.item_selected.connect(func(index: int) -> void:
		rig = str(picker.get_item_metadata(index))
		entries = Mapper.assign(entries, rig)
		rebuild())
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	content.add_child(body)
	preview.custom_minimum_size = Vector2(160, 240)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.add_child(preview)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(430, 300)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	scroll.add_child(rows)
	if not reader.warnings.is_empty():
		var report := TextEdit.new()
		report.editable = false
		report.text = "\n".join(reader.warnings)
		report.custom_minimum_size = Vector2(0, 72)
		report.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		report.add_theme_color_override("font_readonly_color", ThemeKit.WARNING)
		content.add_child(report)
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label.add_theme_color_override("font_color", ThemeKit.WARNING)
	content.add_child(error_label)
	confirmed.connect(confirm_mapping)
	canceled.connect(queue_free)
	rebuild()

func rebuild() -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	selected_layers.clear()
	for entry in entries:
		var row := HBoxContainer.new()
		rows.add_child(row)
		var check := CheckBox.new()
		check.button_pressed = bool(entry.get("include", true))
		check.tooltip_text = "导入此图层"
		check.toggled.connect(func(value: bool) -> void:
			entry.include = value
			update_preview())
		row.add_child(check)
		selected_layers.append(check)
		var thumb := TextureRect.new()
		thumb.texture = ImageTexture.create_from_image(entry.image)
		thumb.custom_minimum_size = Vector2(30, 30)
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(thumb)
		var title_label := Label.new()
		title_label.text = str(entry.name)
		title_label.tooltip_text = str(entry.get("group", "")) + "/" + str(entry.name) + "\n" + str(entry.get("note", ""))
		title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title_label)
		var visible_check := CheckBox.new()
		visible_check.button_pressed = bool(entry.get("visible", true))
		visible_check.tooltip_text = "部件可见"
		visible_check.toggled.connect(func(value: bool) -> void:
			entry.visible = value
			update_preview())
		row.add_child(visible_check)
		var role_picker := OptionButton.new()
		role_picker.custom_minimum_size.x = 118
		role_picker.fit_to_longest_item = false
		role_picker.add_item("普通部件")
		role_picker.set_item_metadata(0, "")
		for role in Rig.roles(rig):
			role_picker.add_item(Rig.role_title(role))
			role_picker.set_item_metadata(role_picker.item_count - 1, role)
			if role == str(entry.get("role", "")): role_picker.select(role_picker.item_count - 1)
		role_picker.item_selected.connect(func(index: int) -> void:
			entry.role = str(role_picker.get_item_metadata(index))
			entry.match = "手动")
		role_picker.tooltip_text = str(entry.get("match", "未匹配"))
		row.add_child(role_picker)
	update_preview()

func update_preview() -> void:
	var bounds := Rect2i()
	for entry in entries:
		var rect := Rect2i(entry.position, entry.size)
		bounds = rect if bounds.size == Vector2i.ZERO else bounds.merge(rect)
	if bounds.size == Vector2i.ZERO: return
	var factor := minf(1.0, 512.0 / maxf(bounds.size.x, bounds.size.y))
	var canvas_size := Vector2i((Vector2(bounds.size) * factor).ceil()).max(Vector2i.ONE)
	var image := Image.create_empty(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for entry in entries:
		if not entry.get("include", true) or not entry.get("visible", true): continue
		var thumbnail: Image = entry.image.duplicate()
		var size := Vector2i((Vector2(entry.size) * factor).ceil()).max(Vector2i.ONE)
		thumbnail.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
		image.blend_rect(thumbnail, Rect2i(Vector2i.ZERO, size), Vector2i(Vector2(entry.position - bounds.position) * factor))
	preview.texture = ImageTexture.create_from_image(image)

func confirm_mapping() -> void:
	var chosen: Array = []
	var used := {}
	for entry in entries:
		if not entry.get("include", true): continue
		var role := str(entry.get("role", ""))
		if not role.is_empty() and used.has(role):
			error_label.text = "骨骼部位重复：" + Rig.role_title(role)
			return
		used[role] = true
		chosen.append(entry.duplicate())
	if chosen.is_empty():
		error_label.text = "至少选择一个图层"
		return
	import_requested.emit(chosen, rig)
	queue_free()
