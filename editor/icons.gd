extends RefCounted

## 图标：Lucide 路径（ISC 许可），按实际显示尺寸一次性栅格化。
## 全部图标共用 24 的视图框与同一线宽策略，避免粗细不一。

const PATHS := {
	"new": '<path d="M12 5v14M5 12h14"/>',
	"open": '<path d="M3 20h16l3-12H10L8 5H3z"/>',
	"save": '<path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h12l4 4v12a2 2 0 0 1-2 2zM7 3v6h10V3M7 21v-8h10v8"/>',
	"undo": '<path d="M3 10h10a7 7 0 0 1 0 14M3 10l5-5M3 10l5 5" transform="translate(0 -3)"/>',
	"redo": '<path d="M21 10H11a7 7 0 0 0 0 14M21 10l-5-5M21 10l-5 5" transform="translate(0 -3)"/>',
	"play": '<path d="m8 4 12 8-12 8z"/>',
	"pause": '<path d="M7 4v16M17 4v16"/>',
	"back": '<path d="M5 4v16M19 4 7 12l12 8z"/>',
	"copy": '<rect x="8" y="8" width="13" height="13" rx="2"/><path d="M16 8V3H3v13h5"/>',
	"trash": '<path d="M3 6h18M9 6V3h6v3M5 6l1 15h12l1-15M10 10v7M14 10v7"/>',
	"export": '<path d="M12 16V3m-5 5 5-5 5 5M4 15v6h16v-6"/>',
	"pencil": '<path d="m16 3 5 5L8 21H3v-5zM14 5l5 5"/>',
	"eraser": '<path d="m15 3 7 7-11 11H5l-4-4zM8 10l7 7M11 21h12"/>',
	"fill": '<path d="m8 3 10 10-8 8L2 13l8-8M5 14h12M20 14c0 0-3 4-3 6a3 3 0 0 0 6 0c0-2-3-6-3-6"/>',
	"picker": '<path d="m16 3 5 5M4 20l-1 1 1-5L16 4l4 4L8 20z"/>',
	"key": '<path d="m12 3 9 9-9 9-9-9z"/>',
	"keyplus": '<path d="m12 3 9 9-9 9-9-9zM8 12h8M12 8v8"/>',
	"minus": '<path d="M5 12h14"/>',
	"fit": '<path d="M8 3H3v5M16 3h5v5M21 16v5h-5M3 16v5h5"/>',
	"flip": '<path d="M12 3v18M8 7v10H2zM16 7v10h6z"/>',
	"eye": '<path d="M2 12c5-10 15-10 20 0-5 10-15 10-20 0z"/><circle cx="12" cy="12" r="2.8"/>',
	"bone": '<path d="m8 8 8 8M5 3a3 3 0 0 0-2 5 3 3 0 0 0 5 2l6 6a3 3 0 0 0 2 5 3 3 0 0 0 5-5 3 3 0 0 0-5-2l-6-6a3 3 0 0 0-5-5z"/>',
	"image": '<rect x="3" y="4" width="18" height="16" rx="2"/><circle cx="8.5" cy="9.5" r="1.5"/><path d="m4 17 5-5 4 4 3-3 4 4"/>',
	"keys": '<rect x="2" y="6" width="20" height="12" rx="2"/><path d="M6 10h1M10 10h1M14 10h1M18 10h1M8 14h8"/>',
	"chevron_down": '<path d="m6 9 6 6 6-6"/>',
}

static var cache := {}

# 默认描边色与主题二级墨色一致；写成常量以便作为默认参数。
const ICON_INK := Color("57524a")
const ICON_MUTED := Color("948c7f")

static func _raster(key: String, svg: String) -> Texture2D:
	if cache.has(key):
		return cache[key]
	var img := Image.new()
	var tex: Texture2D
	if img.load_svg_from_string(svg) == OK:
		tex = ImageTexture.create_from_image(img)
	else:
		tex = PlaceholderTexture2D.new()
	cache[key] = tex
	return tex

## 线宽按尺寸反算，保证任何尺寸下笔画都约为 1.5 px。
static func get_icon(id: String, size: int = 18, color: Color = ICON_INK) -> Texture2D:
	var body: String = PATHS.get(id, PATHS["new"])
	var stroke := snappedf(1.5 * 24.0 / float(size), 0.1)
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 24 24" fill="none" stroke="#%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round">%s</svg>' % [
		size, size, color.to_html(false), str(stroke), body]
	return _raster("%s|%d|%s" % [id, size, color.to_html(false)], svg)

static func chevron_down(color: Color = ICON_MUTED, size: int = 10) -> Texture2D:
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 24 24" fill="none" stroke="#%s" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg>' % [
		size, size, color.to_html(false)]
	return _raster("chev|%d|%s" % [size, color.to_html(false)], svg)

## 数值框右侧的上下微调箭头，两张小尖角上下叠放。
static func updown() -> Texture2D:
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="9" height="16" viewBox="0 0 9 16" fill="none" stroke="#938ca0" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"><path d="m1.4 5.4 3.1-3.1 3.1 3.1"/><path d="m1.4 10.6 3.1 3.1 3.1-3.1"/></svg>'
	return _raster("updown", svg)

static func check_box(checked: bool, disabled: bool = false) -> Texture2D:
	var fill := "#201e1b" if checked else "#fffdf8"
	var border := "#201e1b" if checked else "#cec5b6"
	var mark := ""
	if checked:
		mark = '<path d="m4 8 2.6 2.6L12 5" stroke="#f4f1eb" stroke-width="1.9" fill="none" stroke-linecap="round" stroke-linejoin="round"/>'
	if disabled:
		fill = "#ede9e1" if not checked else "#b9b1a4"
		border = "#e2dbd0"
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="15" height="15" viewBox="0 0 15 15"><rect x="0.7" y="0.7" width="13.6" height="13.6" rx="3" fill="%s" stroke="%s" stroke-width="1.1"/>%s</svg>' % [
		fill, border, mark]
	return _raster("box|%s|%s" % [str(checked), str(disabled)], svg)

## 品牌标记不使用绘制图标：顶栏直接用作者提供的 `assets/rigpop-mark.png`。
