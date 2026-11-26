extends RefCounted

const Windows = preload("res://runtime/desktop/taskbar.gd")
const SPECIAL_KEYS := {
	KEY_ESCAPE: 0x1b, KEY_TAB: 0x09, KEY_BACKSPACE: 0x08, KEY_ENTER: 0x0d,
	KEY_INSERT: 0x2d, KEY_DELETE: 0x2e, KEY_HOME: 0x24, KEY_END: 0x23,
	KEY_LEFT: 0x25, KEY_UP: 0x26, KEY_RIGHT: 0x27, KEY_DOWN: 0x28,
	KEY_PAGEUP: 0x21, KEY_PAGEDOWN: 0x22, KEY_PAUSE: 0x13,
	KEY_PRINT: 0x2c, KEY_CAPSLOCK: 0x14, KEY_NUMLOCK: 0x90, KEY_SCROLLLOCK: 0x91,
	KEY_SHIFT: 0x10, KEY_CTRL: 0x11, KEY_ALT: 0x12, KEY_MENU: 0x5d,
	KEY_KP_MULTIPLY: 0x6a, KEY_KP_ADD: 0x6b, KEY_KP_SUBTRACT: 0x6d,
	KEY_KP_PERIOD: 0x6e, KEY_KP_DIVIDE: 0x6f,
}

var handle := 0
var watched := {}
var pressed := {}
var suspended := true

func configure(window_handle: int, bindings: Array) -> void:
	handle = window_handle
	watched.clear()
	reset()
	if not Windows.available(): return
	for binding in bindings:
		if watched.has(binding.key): continue
		var key := OS.find_keycode_from_string(binding.key)
		var virtual_key := to_virtual_key(key)
		if virtual_key != 0:
			watched[binding.key] = virtual_key

func reset() -> void:
	pressed.clear()
	suspended = true

func poll(router: RefCounted, now: float, accept_input: bool = true) -> Array[String]:
	var commands: Array[String] = []
	if watched.is_empty(): return commands
	var shortcut := (Windows.key_down(handle, 0x11) or Windows.key_down(handle, 0x12)
		or Windows.key_down(handle, 0x5b) or Windows.key_down(handle, 0x5c))
	for name in watched:
		var down := Windows.key_down(handle, watched[name])
		if accept_input and not suspended and down != pressed.get(name, false):
			if down and not shortcut:
				commands.append_array(router.feed(name, true, now))
			elif not down:
				commands.append_array(router.feed(name, false, now))
		pressed[name] = down
	suspended = false
	return commands

func to_virtual_key(key: Key) -> int:
	if key >= KEY_F1 and key <= KEY_F24: return 0x70 + key - KEY_F1
	if key >= KEY_KP_0 and key <= KEY_KP_9: return 0x60 + key - KEY_KP_0
	if key >= KEY_SPACE and key < KEY_SPECIAL:
		return Windows.printable_virtual_key(handle, key)
	return int(SPECIAL_KEYS.get(key, 0))
