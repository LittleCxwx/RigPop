extends Control

const Router = preload("res://core/input_router.gd")
const ThemeKit = preload("res://editor/theme.gd")
const Character = preload("res://core/character.gd")
const GESTURES := ["hold", "tap", "long", "double"]
const MOUSE_KEYS := ["MouseLeft", "MouseRight", "MouseMiddle"]

var app: Control
var bindings: Array = []
var commands: Array[String] = ["move_left", "move_right", "move_up", "move_down"]
var rows: VBoxContainer
var warning: Label
var capture: Dictionary = {}
var capture_button: Button
var card: PanelContainer

func setup(editor: Control) -> void:
	app = editor
	bindings = app.doc.model.bindings.duplicate(true)
	for clip in app.doc.model.actions: commands.append(clip.id)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 110
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.13, 0.10, 0.17, 0.30)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", ThemeKit.flat(ThemeKit.SURFACE, 8, ThemeKit.LINE, 0, 0))
	add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	app.inset(card, 20, 20, 18, 16).add_child(col)
	var title := HBoxContainer.new()
	col.add_child(title)
	title.add_child(app.label("控制绑定", 16, ThemeKit.INK))
	app.expand(title)
	app.tool_button(title, "new", "添加绑定", add_binding)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	col.add_child(header)
	for i in 4:
		var caption: Label = app.label(["设备", "按键", "触发", "动作"][i], 11, ThemeKit.MUTED)
		caption.custom_minimum_size.x = [80, 126, 92, 170][i]
		if i == 3: caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(caption)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 7)
	scroll.add_child(rows)
	warning = app.label("", 12, ThemeKit.SIGNAL)
	warning.custom_minimum_size = Vector2(0, 32)
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(warning)
	col.add_child(HSeparator.new())
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 8)
	col.add_child(footer)
	var cancel: Button = app.outline_button(footer, "取消", close)
	app.primary_button(footer, "应用绑定", apply)
	resized.connect(fit)
	fit()
	render()
	cancel.grab_focus()
	app.game_world.clear_input()
	app.game_world.enabled = false

func fit() -> void:
	if card == null: return
	card.size = Vector2(minf(680, size.x - 40), minf(460, size.y - 48))
	card.position = ((size - card.size) * 0.5).round()

func selector(parent: Node, titles: Array, width: float) -> OptionButton:
	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(width, 32)
	picker.fit_to_longest_item = false
	for title in titles: picker.add_item(title)
	parent.add_child(picker)
	return picker

func render() -> void:
	end_capture()
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	for binding in bindings:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		rows.add_child(row)
		var mouse: bool = binding.key in MOUSE_KEYS
		var device := selector(row, ["键盘", "鼠标"], 80)
		device.select(1 if mouse else 0)
		device.item_selected.connect(func(i: int) -> void:
			binding.key = "MouseLeft" if i == 1 else "E"
			render.call_deferred())
		if mouse:
			var key := selector(row, ["左键", "右键", "中键"], 126)
			key.tooltip_text = "桌宠右键用于菜单与缩放；游戏中可触发动作绑定"
			key.select(MOUSE_KEYS.find(binding.key))
			key.item_selected.connect(func(i: int) -> void: binding.key = MOUSE_KEYS[i])
		else:
			var key: Button = app.outline_button(row, binding.key, func() -> void: pass)
			key.custom_minimum_size.x = 126
			key.tooltip_text = "点击后按下键盘按键；Esc 取消"
			key.pressed.connect(func() -> void:
				end_capture()
				capture = binding
				capture_button = key
				key.text = "按下按键…")
		var gesture := selector(row, ["持续移动", "点按", "长按", "双击"], 92)
		gesture.select(maxi(0, GESTURES.find(binding.gesture)))
		gesture.item_selected.connect(func(i: int) -> void: binding.gesture = GESTURES[i])
		var titles := []
		for id in commands:
			titles.append({"move_left": "向左移动", "move_right": "向右移动", "move_up": "向上移动", "move_down": "向下移动"}.get(id, Character.find_action(app.doc.model, id).get("name", id)))
		var command := selector(row, titles, 170)
		command.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		command.select(maxi(0, commands.find(binding.command)))
		command.item_selected.connect(func(i: int) -> void:
			binding.command = commands[i]
			binding.gesture = "hold" if binding.command.begins_with("move_") else "tap"
			render.call_deferred())
		app.tool_button(row, "trash", "移除此绑定", func() -> void:
			bindings.erase(binding)
			render.call_deferred())

func add_binding() -> void:
	var command := "idle" if commands.has("idle") else commands[0]
	bindings.append({"key": "E", "gesture": "hold" if command.begins_with("move_") else "tap", "command": command})
	render.call_deferred()

func end_capture() -> void:
	if is_instance_valid(capture_button) and not capture.is_empty(): capture_button.text = capture.key
	capture = {}
	capture_button = null

func _input(event: InputEvent) -> void:
	if not event is InputEventKey: return
	if not capture.is_empty():
		if event.pressed and not event.echo:
			if event.keycode != KEY_ESCAPE:
				var key := Router.key_from_event(event)
				if not key.is_empty(): capture.key = key
			end_capture()
		get_viewport().set_input_as_handled()
	elif event.is_pressed() and event.keycode == KEY_ESCAPE:
		close.call_deferred()
		get_viewport().set_input_as_handled()

func apply() -> void:
	end_capture()
	var error := Router.binding_error(bindings)
	for binding in bindings:
		if not commands.has(binding.command): error = "绑定动作已不存在"
	if not error.is_empty():
		warning.text = error
		return
	app.edit("修改控制绑定", func() -> void: app.doc.model.bindings = bindings.duplicate(true))
	app.game_world.configure(app.doc.model, app.doc.textures)
	app.rebuild_inspector.call_deferred()
	close()

func close() -> void:
	app.bindings_dialog = null
	queue_free()
