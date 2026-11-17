extends RefCounted

const Icons = preload("res://editor/icons.gd")

## RigPop 界面设计令牌。
##
## 色板从品牌标记的主紫 #8D40BF 派生：把品牌色的色相保留、彩度压到极低，
## 得到一块"紫灰纸"底盘。界面只用一种底盘色，分隔靠 1 px 细线而不是给每个
## 控件加边框；信号色只留给"当前时刻"与"当前选中"这类真正需要一眼看到的东西。

# --- 底盘与墨色（品牌紫的低彩度派生） -----------------------------------
const PAPER := Color("f2eef8")      # 全部界面底色，紫灰纸
const PAPER_2 := Color("eae5f3")    # 悬停、次级分区
const SURFACE := Color("fdfcff")    # 输入框、弹层、下拉菜单
const INK := Color("211d28")        # 主文本、主按钮（略带紫的墨色）
const INK_2 := Color("565063")      # 次级文本、图标
const MUTED := Color("938ca0")      # 分区标题、说明
const FAINT := Color("b7b0c4")      # 禁用、极弱提示

# --- 细线与选中 ---------------------------------------------------------
const LINE := Color("e3ddec")
const LINE_2 := Color("d0c8dc")
const SELECT := Color("e8e1f3")

# --- 信号色（全屏唯一暖色，与紫互补，用在"此刻"） -----------------------
const SIGNAL := Color("b24a31")
const SIGNAL_DEEP := Color("8f3826")
const WARNING := Color("a8762a")

# --- 画布（唯一的深色区域，托住像素画） ---------------------------------
const CANVAS := Color("1e1c22")
const CANVAS_CHECK := Color("232129")
const CANVAS_LINE := Color("2f2b36")
const CANVAS_ANCHOR := Color("8c85a0")

# --- 兼容旧命名 ---------------------------------------------------------
const TEXT := INK_2
const TEXT_SECONDARY := MUTED
const ACCENT := SIGNAL
const ACCENT_HOVER := Color("c1573c")
const ACCENT_PRESSED := SIGNAL_DEEP
const BG_BASE := PAPER
const BG_ELEVATED := SURFACE
const BG_PANEL := PAPER
const BG_CANVAS := CANVAS
const BORDER_SUBTLE := LINE
const BORDER_DEFAULT := LINE
const BORDER_STRONG := LINE_2
const BORDER_FOCUS := INK
const SELECTION_BG := SELECT
const HOVER_BG := PAPER_2
const STATE_ERROR := SIGNAL
const STATE_WARNING := WARNING
const STATE_SUCCESS := Color("4a6b52")

# 字重阶梯：正文与控件 500、标题 600、分区小标题 600 + 字距。
# 层级主要靠字号与颜色区分，字重只做两级，避免整屏都是粗体。
const W_BODY := 500
const W_LABEL := 500
const W_TITLE := 600

static var _fonts := {}

static func font(weight: int = W_BODY, spacing: int = 0) -> FontVariation:
	var key := weight * 100 + spacing
	if not _fonts.has(key):
		var f := FontVariation.new()
		f.base_font = load("res://assets/NotoSansSC-VF.ttf")
		f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): float(weight)}
		f.spacing_glyph = spacing
		_fonts[key] = f
	return _fonts[key]

# --- StyleBox 工厂 ------------------------------------------------------

static func flat(color: Color, radius: int = 3, border: Color = Color.TRANSPARENT,
		pad_h: float = 0, pad_v: float = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.anti_aliasing = true
	if border.a > 0.0:
		s.set_border_width_all(1)
		s.border_color = border
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	return s

## 兼容旧调用：`box(底色, 圆角, 边框, 内边距)`。
static func box(color: Color, radius: int = 3, border: Color = Color.TRANSPARENT, padding: int = 10) -> StyleBoxFlat:
	var s := flat(color, radius, border, padding, roundi(padding * 0.6))
	return s

static func make() -> Theme:
	var t := Theme.new()
	t.default_font = font(W_BODY)
	t.default_font_size = 13

	for type in ["Label", "Button", "LineEdit", "Tree", "ItemList", "SpinBox",
			"CheckBox", "OptionButton", "PopupMenu", "MenuButton", "LinkButton"]:
		t.set_color("font_color", type, INK_2)
	t.set_color("font_color", "Label", INK_2)

	# --- 按钮：默认无边框，悬停给一层薄底色 -----------------------------
	t.set_font("font", "Button", font(W_LABEL))
	t.set_font_size("font_size", "Button", 13)
	t.set_color("font_color", "Button", INK_2)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_focus_color", "Button", INK)
	t.set_color("font_hover_pressed_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", FAINT)
	t.set_stylebox("normal", "Button", flat(Color.TRANSPARENT, 3, Color.TRANSPARENT, 10, 5))
	t.set_stylebox("hover", "Button", flat(PAPER_2, 3, Color.TRANSPARENT, 10, 5))
	t.set_stylebox("pressed", "Button", flat(Color("e0daea"), 3, Color.TRANSPARENT, 10, 5))
	t.set_stylebox("disabled", "Button", flat(Color.TRANSPARENT, 3, Color.TRANSPARENT, 10, 5))
	t.set_stylebox("focus", "Button", flat(Color.TRANSPARENT, 3, LINE_2, 10, 5))

	# --- 输入框 ---------------------------------------------------------
	for type in ["LineEdit", "OptionButton", "SpinBox"]:
		t.set_font("font", type, font(W_BODY))
		t.set_font_size("font_size", type, 13)
		t.set_color("font_color", type, INK)
		t.set_color("font_placeholder_color", type, FAINT)
		t.set_color("font_uneditable_color", type, MUTED)
		t.set_color("caret_color", type, INK)
		t.set_color("selection_color", type, SELECT)
		t.set_stylebox("normal", type, flat(SURFACE, 3, LINE, 8, 4))
		t.set_stylebox("focus", type, flat(SURFACE, 3, INK, 8, 4))
		t.set_stylebox("read_only", type, flat(PAPER_2, 3, LINE, 8, 4))

	t.set_stylebox("hover", "OptionButton", flat(SURFACE, 3, LINE_2, 8, 4))
	t.set_stylebox("pressed", "OptionButton", flat(PAPER_2, 3, LINE_2, 8, 4))
	t.set_stylebox("disabled", "OptionButton", flat(PAPER_2, 3, LINE, 8, 4))
	t.set_color("font_hover_color", "OptionButton", INK)
	t.set_color("font_pressed_color", "OptionButton", INK)
	t.set_icon("arrow", "OptionButton", Icons.chevron_down())
	t.set_constant("arrow_margin", "OptionButton", 7)
	t.set_icon("updown", "SpinBox", Icons.updown())

	# --- 复选框 ---------------------------------------------------------
	t.set_icon("checked", "CheckBox", Icons.check_box(true))
	t.set_icon("unchecked", "CheckBox", Icons.check_box(false))
	t.set_icon("checked_disabled", "CheckBox", Icons.check_box(true, true))
	t.set_icon("unchecked_disabled", "CheckBox", Icons.check_box(false, true))
	t.set_constant("h_separation", "CheckBox", 8)
	t.set_color("font_color", "CheckBox", INK_2)
	t.set_stylebox("normal", "CheckBox", flat(Color.TRANSPARENT, 3, Color.TRANSPARENT, 0, 3))
	t.set_stylebox("hover", "CheckBox", flat(Color.TRANSPARENT, 3, Color.TRANSPARENT, 0, 3))
	t.set_stylebox("pressed", "CheckBox", flat(Color.TRANSPARENT, 3, Color.TRANSPARENT, 0, 3))

	# --- 面板 -----------------------------------------------------------
	t.set_stylebox("panel", "PanelContainer", flat(PAPER))
	t.set_stylebox("panel", "Panel", flat(PAPER))

	# --- 树（部件层级） -------------------------------------------------
	t.set_stylebox("bg", "Tree", flat(Color.TRANSPARENT))
	t.set_stylebox("panel", "Tree", flat(Color.TRANSPARENT))
	t.set_stylebox("focus", "Tree", flat(Color.TRANSPARENT))
	# 选中条不加内边距：否则文字会在选中瞬间横向跳动。
	t.set_stylebox("selected", "Tree", flat(SELECT, 3))
	t.set_stylebox("selected_focus", "Tree", flat(SELECT, 3))
	t.set_color("font_color", "Tree", INK_2)
	t.set_color("font_selected_color", "Tree", INK)
	t.set_color("guide_color", "Tree", LINE)
	t.set_color("relationship_line_color", "Tree", LINE)
	t.set_color("drop_position_color", "Tree", SIGNAL)
	t.set_constant("v_separation", "Tree", 7)
	t.set_constant("h_separation", "Tree", 6)
	t.set_constant("item_margin", "Tree", 0)
	t.set_font("font", "Tree", font(W_BODY))
	t.set_font_size("font_size", "Tree", 13)

	# --- 滚动条：细、无轨道 ---------------------------------------------
	for type in ["VScrollBar", "HScrollBar"]:
		var scroll := flat(Color.TRANSPARENT, 0, Color.TRANSPARENT, 3, 3)
		t.set_stylebox("scroll", type, scroll)
		t.set_stylebox("grabber", type, flat(Color("d6cfe0"), 3))
		t.set_stylebox("grabber_highlight", type, flat(Color("c3bbcd"), 3))
		t.set_stylebox("grabber_pressed", type, flat(Color("b1a9bb"), 3))
		t.set_constant("minimum_grab_thickness", type, 16)

	# --- 弹层 -----------------------------------------------------------
	t.set_stylebox("panel", "PopupMenu", flat(SURFACE, 4, LINE_2, 5, 5))
	t.set_stylebox("hover", "PopupMenu", flat(SELECT, 3, Color.TRANSPARENT, 6, 4))
	t.set_color("font_color", "PopupMenu", INK_2)
	t.set_color("font_hover_color", "PopupMenu", INK)
	t.set_color("font_separator_color", "PopupMenu", MUTED)
	t.set_stylebox("separator", "PopupMenu", flat(LINE))
	t.set_constant("v_separation", "PopupMenu", 6)
	t.set_constant("item_start_padding", "PopupMenu", 8)
	t.set_constant("item_end_padding", "PopupMenu", 8)

	t.set_stylebox("panel", "AcceptDialog", flat(SURFACE, 0, Color.TRANSPARENT, 0, 0))
	t.set_constant("margin_left", "AcceptDialog", 18)
	t.set_constant("margin_right", "AcceptDialog", 18)
	t.set_constant("margin_top", "AcceptDialog", 10)
	t.set_constant("margin_bottom", "AcceptDialog", 12)
	t.set_constant("buttons_separation", "AcceptDialog", 8)
	t.set_font("font", "AcceptDialog", font(W_BODY))
	t.set_font_size("font_size", "AcceptDialog", 13)
	t.set_color("font_color", "AcceptDialog", INK_2)

	t.set_stylebox("panel", "TooltipPanel", flat(SURFACE, 3, LINE_2, 7, 5))
	t.set_font("font", "TooltipLabel", font(W_BODY))
	t.set_font_size("font_size", "TooltipLabel", 12)
	t.set_color("font_color", "TooltipLabel", INK_2)

	# --- 分隔与间距 -----------------------------------------------------
	t.set_stylebox("separator", "HSeparator", flat(LINE))
	t.set_constant("separation", "HSeparator", 0)
	t.set_stylebox("separator", "VSeparator", flat(LINE))
	t.set_constant("separation", "VSeparator", 0)

	t.set_constant("separation", "HBoxContainer", 8)
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HFlowContainer", 6)

	return t

static func make_separator() -> StyleBoxFlat:
	return flat(LINE)
