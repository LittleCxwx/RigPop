extends Control
## 自绘确认卡片。
##
## 为什么不用 ConfirmationDialog：Godot 内嵌窗口的标题条与边框由引擎默认主题
## 绘制，项目主题改不动它，于是会出现"灰标题条 + 纯白按钮"的割裂感。这里用
## 一层暗幕 + 一张卡片自己画，皮肤完全跟随 ThemeKit。

signal confirmed
signal canceled

const ThemeKit = preload("res://editor/theme.gd")

var _title := Label.new()
var _message := Label.new()
var _ok := Button.new()
var _cancel := Button.new()
var _texts := ["未保存的修改", "当前角色有未保存的修改，继续操作会丢弃这些改动。", "丢弃并继续", "返回编辑"]

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	z_index = 100

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.13, 0.10, 0.17, 0.30)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size.x = 392
	card.add_theme_stylebox_override("panel", _card_style())
	center.add_child(card)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 22)
	pad.add_theme_constant_override("margin_right", 22)
	pad.add_theme_constant_override("margin_top", 18)
	pad.add_theme_constant_override("margin_bottom", 16)
	card.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	pad.add_child(col)

	_title.text = _texts[0]
	_title.add_theme_font_override("font", ThemeKit.font(ThemeKit.W_TITLE))
	_title.add_theme_font_size_override("font_size", 14)
	_title.add_theme_color_override("font_color", ThemeKit.INK)
	col.add_child(_title)

	_message.text = _texts[1]
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size.x = 348
	_message.add_theme_font_override("font", ThemeKit.font(ThemeKit.W_BODY))
	_message.add_theme_font_size_override("font_size", 13)
	_message.add_theme_color_override("font_color", ThemeKit.INK_2)
	col.add_child(_message)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 6
	col.add_child(spacer)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(row)

	_build_button(_cancel, _texts[3], row)
	_style_outline(_cancel)
	_build_button(_ok, _texts[2], row)
	_style_primary(_ok)

## 打开前可以替换文案，默认就是"未保存的修改"。
func setup(title: String, message: String, ok_text: String, cancel_text: String) -> void:
	_texts = [title, message, ok_text, cancel_text]
	_title.text = title
	_message.text = message
	_ok.text = ok_text
	_cancel.text = cancel_text

func open() -> void:
	visible = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_cancel.grab_focus()

func close() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible: return
	if event.is_action_pressed("ui_cancel"):
		_cancel_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_ok_pressed()
		get_viewport().set_input_as_handled()

func _build_button(b: Button, text: String, parent: Node) -> void:
	b.text = text
	b.custom_minimum_size = Vector2(96, 32)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", ThemeKit.font(ThemeKit.W_LABEL))
	parent.add_child(b)
	if b == _ok:
		b.pressed.connect(_ok_pressed)
	else:
		b.pressed.connect(_cancel_pressed)

func _ok_pressed() -> void:
	close()
	confirmed.emit()

func _cancel_pressed() -> void:
	close()
	canceled.emit()

func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = ThemeKit.SURFACE
	style.border_color = ThemeKit.LINE
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.13, 0.10, 0.17, 0.16)
	style.shadow_size = 22
	style.shadow_offset = Vector2(0, 8)
	style.anti_aliasing = true
	return style

func _style_primary(b: Button) -> void:
	var ink_text := Color("f6f3fb")
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, ink_text)
	b.add_theme_stylebox_override("normal", ThemeKit.flat(ThemeKit.INK, 3, Color.TRANSPARENT, 13, 5))
	b.add_theme_stylebox_override("hover", ThemeKit.flat(Color("342e40"), 3, Color.TRANSPARENT, 13, 5))
	b.add_theme_stylebox_override("pressed", ThemeKit.flat(Color("141019"), 3, Color.TRANSPARENT, 13, 5))

func _style_outline(b: Button) -> void:
	b.add_theme_stylebox_override("normal", ThemeKit.flat(ThemeKit.SURFACE, 3, ThemeKit.LINE_2, 11, 5))
	b.add_theme_stylebox_override("hover", ThemeKit.flat(ThemeKit.PAPER_2, 3, ThemeKit.LINE_2, 11, 5))
	b.add_theme_stylebox_override("pressed", ThemeKit.flat(ThemeKit.SELECT, 3, ThemeKit.LINE_2, 11, 5))
