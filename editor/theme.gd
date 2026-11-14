extends RefCounted

# Core semantic colors
const INK := Color("1a2329")
const TEXT := Color("2d3842")
const TEXT_SECONDARY := Color("6b7784")
const MUTED := Color("8a95a0")
const ACCENT := Color("1d8569")
const ACCENT_HOVER := Color("23a07d")
const ACCENT_PRESSED := Color("166b54")

# Background colors
const BG_BASE := Color("fafbfc")
const BG_ELEVATED := Color("ffffff")
const BG_CANVAS := Color("292e32")
const BG_PANEL := Color("f3f5f6")

# Border colors
const BORDER_SUBTLE := Color("e1e5e9")
const BORDER_DEFAULT := Color("d1d7dd")
const BORDER_STRONG := Color("b8c1ca")
const BORDER_FOCUS := Color("1d8569")

# State colors
const STATE_ERROR := Color("c94a3a")
const STATE_WARNING := Color("db8b2b")
const STATE_SUCCESS := Color("1d8569")

# UI feedback colors
const SELECTION_BG := Color("e3f2ed")
const HOVER_BG := Color("eff3f5")

static func box(color: Color, radius: int = 4, border: Color = Color.TRANSPARENT, padding: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_border_width_all(1 if border.a > 0 else 0)
	s.border_color = border
	s.content_margin_left = padding
	s.content_margin_right = padding
	s.content_margin_top = padding * 0.6
	s.content_margin_bottom = padding * 0.6
	return s

static func make() -> Theme:
	var t := Theme.new()
	var font := FontVariation.new()
	font.base_font = load("res://assets/NotoSansSC-VF.ttf")
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 500.0}
	t.default_font = font
	t.default_font_size = 14

	# Base text colors
	for type in ["Label", "Button", "LineEdit", "Tree", "ItemList", "SpinBox", "CheckBox", "OptionButton", "PopupMenu"]:
		t.set_color("font_color", type, TEXT)

	# Button states
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", ACCENT_PRESSED)
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_stylebox("normal", "Button", box(BG_ELEVATED, 5, BORDER_DEFAULT, 10))
	t.set_stylebox("hover", "Button", box(SELECTION_BG, 5, ACCENT, 10))
	t.set_stylebox("pressed", "Button", box(Color("d0e8df"), 5, ACCENT_PRESSED, 10))
	t.set_stylebox("disabled", "Button", box(HOVER_BG, 5, BORDER_SUBTLE, 10))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), 5, BORDER_FOCUS, 10))

	# Input fields
	for type in ["LineEdit", "OptionButton", "SpinBox"]:
		t.set_stylebox("normal", type, box(BG_ELEVATED, 4, BORDER_DEFAULT, 10))
		t.set_stylebox("focus", type, box(BG_ELEVATED, 4, BORDER_FOCUS, 10))
		t.set_color("font_color", type, TEXT)
		t.set_color("font_placeholder_color", type, TEXT_SECONDARY)

	# Panels
	t.set_stylebox("panel", "PanelContainer", box(BG_PANEL, 0, Color.TRANSPARENT, 0))

	# Tree
	t.set_stylebox("bg", "Tree", box(BG_ELEVATED, 0, Color.TRANSPARENT, 0))
	t.set_stylebox("panel", "Tree", box(BG_ELEVATED, 0, Color.TRANSPARENT, 0))
	t.set_stylebox("selected", "Tree", box(SELECTION_BG, 4, Color.TRANSPARENT, 8))
	t.set_stylebox("selected_focus", "Tree", box(SELECTION_BG, 4, BORDER_FOCUS, 8))
	t.set_color("font_selected_color", "Tree", ACCENT_PRESSED)
	t.set_color("font_color", "Tree", TEXT)
	t.set_constant("v_separation", "Tree", 4)
	t.set_constant("h_separation", "Tree", 6)

	# Popups & Dialogs
	t.set_stylebox("panel", "PopupMenu", box(BG_ELEVATED, 6, BORDER_STRONG, 4))
	t.set_stylebox("hover", "PopupMenu", box(HOVER_BG, 4, Color.TRANSPARENT, 8))
	t.set_stylebox("panel", "AcceptDialog", box(BG_BASE, 8, BORDER_STRONG, 0))
	t.set_constant("margin_left", "AcceptDialog", 20)
	t.set_constant("margin_right", "AcceptDialog", 20)
	t.set_constant("margin_top", "AcceptDialog", 16)
	t.set_constant("margin_bottom", "AcceptDialog", 16)

	# Separators
	t.set_stylebox("separator", "HSeparator", make_separator())
	t.set_constant("separation", "HSeparator", 12)

	# Container spacing
	t.set_constant("separation", "HBoxContainer", 8)
	t.set_constant("separation", "VBoxContainer", 10)

	return t

static func make_separator() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = BORDER_SUBTLE
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s
