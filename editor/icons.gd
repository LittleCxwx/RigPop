extends RefCounted

# Lucide paths, ISC license. Rasterized once for native Godot controls.
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
	"key": '<path d="m12 3 9 9-9 9-9-9zM9 12h6M12 9v6"/>',
	"minus": '<path d="M5 12h14"/>',
	"fit": '<path d="M8 3H3v5M16 3h5v5M21 16v5h-5M3 16v5h5"/>',
	"flip": '<path d="M12 3v18M8 7v10H2zM16 7v10h6z"/>',
	"eye": '<path d="M2 12c5-10 15-10 20 0-5 10-15 10-20 0z"/><circle cx="12" cy="12" r="3"/>',
	"bone": '<path d="m8 8 8 8M5 3a3 3 0 0 0-2 5 3 3 0 0 0 5 2l6 6a3 3 0 0 0 2 5 3 3 0 0 0 5-5 3 3 0 0 0-5-2l-6-6a3 3 0 0 0-5-5z"/>'
}
static var cache := {}

static func get_icon(id: String) -> Texture2D:
	if not cache.has(id):
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#53646b" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">%s</svg>' % PATHS.get(id, PATHS.new)
		var img := Image.new()
		img.load_svg_from_string(svg)
		cache[id] = ImageTexture.create_from_image(img)
	return cache[id]
