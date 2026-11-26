extends RefCounted

## Small in-process Win32 adapter. Avoids cross-process synchronous window messages.
const EXTENSION := "res://platform/windows/rigpop_windows.gdextension"
static var extension: Resource

static func available() -> bool:
	if OS.get_name() != "Windows" or DisplayServer.get_name() == "headless": return false
	if ClassDB.class_exists("RigPopWindows"): return true
	if extension == null and ResourceLoader.exists(EXTENSION):
		extension = load(EXTENSION)
	return ClassDB.class_exists("RigPopWindows")

static func _operate(handle: int, command: int, value: int = 0) -> int:
	if not available(): return 0
	return int(ClassDB.class_call_static("RigPopWindows", "operate", handle, command, value))

static func hide_from_taskbar(handle: int) -> bool:
	return _operate(handle, 0) == 1

static func set_visible(handle: int, visible: bool) -> bool:
	return _operate(handle, 1, int(visible)) == 1

static func is_visible(handle: int) -> bool:
	return _operate(handle, 3) == 1

static func is_tool_window(handle: int) -> bool:
	var style := _operate(handle, 2)
	return (style & 0x80) != 0 and (style & 0x40000) == 0

static func other_foreground(handle: int) -> int:
	return _operate(handle, 4)

static func activate(handle: int) -> bool:
	return _operate(handle, 5) == 1

static func restore_foreground(handle: int, previous: int) -> void:
	if previous != 0: _operate(handle, 6, previous)

static func key_down(handle: int, virtual_key: int) -> bool:
	return _operate(handle, 7, virtual_key) == 1

static func printable_virtual_key(handle: int, key: int) -> int:
	return _operate(handle, 8, key)

static func watch_menu(handle: int, menu_handle: int) -> bool:
	return _operate(handle, 9, menu_handle) == 1

static func clicked_outside_menu(handle: int) -> bool:
	return _operate(handle, 10) == 1
