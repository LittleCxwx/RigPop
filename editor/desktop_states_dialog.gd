extends ConfirmationDialog

signal applied(states: Array)

const DesktopStates = preload("res://core/desktop_states.gd")
const Character = preload("res://core/character.gd")
const Icons = preload("res://editor/icons.gd")
const ThemeKit = preload("res://editor/theme.gd")

var model: Dictionary
var states: Array
var current := 0
var state_list := ItemList.new()
var fields := VBoxContainer.new()
var remove_state := Button.new()
var error := Label.new()

func setup(data: Dictionary) -> void:
	model = data
	states = DesktopStates.read(model)
	title = "桌宠状态与动作"
	ok_button_text = "应用"
	cancel_button_text = "取消"
	dialog_hide_on_ok = false
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	add_child(content)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	content.add_child(body)
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 160
	body.add_child(sidebar)
	var tools := HBoxContainer.new()
	sidebar.add_child(tools)
	var title_label := label("状态")
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(title_label)
	var add_state := icon_button("new", "新增状态")
	tools.add_child(add_state)
	remove_state.icon = Icons.get_icon("trash", 16)
	remove_state.tooltip_text = "删除状态"
	tools.add_child(remove_state)
	state_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	state_list.add_theme_stylebox_override("panel", ThemeKit.flat(ThemeKit.PAPER, 3, ThemeKit.LINE, 6, 7))
	state_list.add_theme_stylebox_override("selected", ThemeKit.flat(ThemeKit.SELECT, 3))
	state_list.add_theme_stylebox_override("selected_focus", ThemeKit.flat(ThemeKit.SELECT, 3, ThemeKit.LINE_2))
	state_list.add_theme_color_override("font_selected_color", ThemeKit.INK)
	state_list.add_theme_constant_override("v_separation", 8)
	sidebar.add_child(state_list)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.add_theme_constant_override("separation", 9)
	scroll.add_child(fields)
	error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error.add_theme_color_override("font_color", ThemeKit.WARNING)
	content.add_child(error)
	state_list.item_selected.connect(func(index: int) -> void:
		current = index
		show_fields())
	add_state.pressed.connect(func() -> void:
		states.append(DesktopStates.state("新状态"))
		current = states.size() - 1
		refresh_states()
		show_fields())
	remove_state.pressed.connect(func() -> void:
		if states.size() <= 1: return
		states.remove_at(current)
		current = mini(current, states.size() - 1)
		refresh_states()
		show_fields())
	confirmed.connect(save)
	canceled.connect(queue_free)
	refresh_states()
	show_fields()

func refresh_states() -> void:
	state_list.clear()
	for i in states.size():
		var suffix := "  ·  启动" if i == 0 else ""
		var key := str(states[i].key).strip_edges()
		var prefix := key + "   " if not key.is_empty() else ""
		state_list.add_item(prefix + str(states[i].name) + suffix)
	state_list.select(current)
	remove_state.disabled = states.size() <= 1

func show_fields() -> void:
	for child in fields.get_children():
		fields.remove_child(child)
		child.queue_free()
	var state: Dictionary = states[current]
	var name_entry := LineEdit.new()
	name_entry.text = state.name
	name_entry.max_length = 30
	name_entry.text_changed.connect(func(value: String) -> void:
		state.name = value
		refresh_states())
	field("状态名称", name_entry)
	var key_entry := LineEdit.new()
	key_entry.text = state.key
	key_entry.max_length = 24
	key_entry.placeholder_text = "例如 2、F6，留空可禁用"
	key_entry.text_changed.connect(func(value: String) -> void:
		state.key = value
		refresh_states())
	field("切换键", key_entry)
	var pose := action_picker("沿用当前动作", state.clip)
	pose.item_selected.connect(func(index: int) -> void: state.clip = pose.get_item_metadata(index))
	field("状态姿势", pose)
	var overlay := CheckBox.new()
	overlay.text = "叠加到待机、移动和动作上"
	overlay.button_pressed = state.overlay
	overlay.toggled.connect(func(value: bool) -> void: state.overlay = value)
	field("姿势效果", overlay)
	var locked := CheckBox.new()
	locked.text = "禁止键盘移动和自由漫游"
	locked.button_pressed = state.lock_movement
	locked.toggled.connect(func(value: bool) -> void: state.lock_movement = value)
	field("位置", locked)
	var lock_jump := CheckBox.new()
	lock_jump.text = "禁止跳跃"
	lock_jump.button_pressed = state.lock_jump
	lock_jump.toggled.connect(func(value: bool) -> void: state.lock_jump = value)
	field("跳跃", lock_jump)
	fields.add_child(HSeparator.new())
	var header := HBoxContainer.new()
	fields.add_child(header)
	var caption := label("动作替换")
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(caption)
	var add := icon_button("new", "添加动作替换")
	header.add_child(add)
	var mappings := VBoxContainer.new()
	fields.add_child(mappings)
	for action in state.variants:
		add_mapping(mappings, state, str(action), str(state.variants[action]))
	add.disabled = model.actions.size() < 2
	add.pressed.connect(func() -> void: add_mapping(mappings, state))

func add_mapping(parent: VBoxContainer, state: Dictionary, original: String = "", replacement: String = "") -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var source := action_picker("原动作", original)
	var target := action_picker("替换成", replacement)
	row.add_child(source)
	row.add_child(label("→"))
	row.add_child(target)
	var remove := icon_button("trash", "删除这条替换")
	row.add_child(remove)
	var current_key := [original]
	var changed := func(_index: int) -> void:
		var from := str(source.get_selected_metadata())
		var to := str(target.get_selected_metadata())
		if not from.is_empty() and from != current_key[0] and state.variants.has(from):
			error.text = "这个原动作已经有一条替换。"
			select_action(source, str(current_key[0]))
			return
		error.text = ""
		state.variants.erase(current_key[0])
		current_key[0] = ""
		if not from.is_empty() and not to.is_empty() and from != to:
			state.variants[from] = to
			current_key[0] = from
	source.item_selected.connect(changed)
	target.item_selected.connect(changed)
	remove.pressed.connect(func() -> void:
		state.variants.erase(current_key[0])
		row.queue_free())

func action_picker(empty_label: String, action_id: String) -> OptionButton:
	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.fit_to_longest_item = false
	picker.add_item(empty_label)
	picker.set_item_metadata(0, "")
	for clip in model.actions:
		picker.add_item(str(clip.name))
		picker.set_item_metadata(picker.item_count - 1, clip.id)
	select_action(picker, action_id)
	return picker

func select_action(picker: OptionButton, action_id: String) -> void:
	picker.select(0)
	for i in range(1, picker.item_count):
		if picker.get_item_metadata(i) == action_id:
			picker.select(i)
			return

func field(text: String, value: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	fields.add_child(row)
	var caption := label(text)
	caption.custom_minimum_size.x = 76
	row.add_child(caption)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value)

func icon_button(icon_id: String, hint: String) -> Button:
	var button := Button.new()
	button.icon = Icons.get_icon(icon_id, 16)
	button.tooltip_text = hint
	return button

func label(text: String) -> Label:
	var result := Label.new()
	result.text = text
	return result

func save() -> void:
	for state in states:
		state.name = str(state.name).strip_edges()
		if str(state.name).is_empty():
			error.text = "请填写每个状态的名称。"
			return
		variants_cleanup(state)
	error.text = DesktopStates.key_error(states, model.bindings)
	if not error.text.is_empty(): return
	applied.emit(states.duplicate(true))
	hide()
	queue_free()

func variants_cleanup(state: Dictionary) -> void:
	if Character.find_action(model, state.clip).is_empty(): state.clip = ""
	for action in state.variants.keys():
		if Character.find_action(model, str(action)).is_empty() or Character.find_action(model, str(state.variants[action])).is_empty():
			state.variants.erase(action)
