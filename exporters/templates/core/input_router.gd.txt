extends RefCounted

var bindings: Array = []
var held := {}
var pending := {}
var long_fired := {}
var hold_threshold := 0.3
var double_threshold := 0.25

static func key_from_event(event: InputEvent) -> String:
	if event is InputEventKey and not event.echo:
		var code: Key = event.keycode if event.keycode != KEY_NONE else event.physical_keycode
		return OS.get_keycode_string(code) if code != KEY_NONE else ""
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT: return "MouseLeft"
			MOUSE_BUTTON_RIGHT: return "MouseRight"
			MOUSE_BUTTON_MIDDLE: return "MouseMiddle"
	return ""

static func binding_error(bindings: Array) -> String:
	var seen := {}
	for b in bindings:
		var key := str(b.get("key", ""))
		var gesture := str(b.get("gesture", ""))
		var command := str(b.get("command", ""))
		if key.is_empty() or (key not in ["MouseLeft", "MouseRight", "MouseMiddle"] and OS.find_keycode_from_string(key) == KEY_NONE):
			return "请选择有效按键"
		if gesture not in ["hold", "tap", "long", "double"]: return "请选择触发方式"
		if seen.has(key + "/" + gesture): return "同一按键与触发方式只能绑定一次"
		if command.begins_with("move_") != (gesture == "hold"):
			return "移动使用持续触发；动作使用点按、长按或双击"
		seen[key + "/" + gesture] = true
	return ""

func clear() -> void:
	held.clear()
	pending.clear()
	long_fired.clear()

func feed(key: String, pressed: bool, now: float) -> Array[String]:
	var commands: Array[String] = []
	if pressed:
		if held.has(key):
			return commands
		held[key] = now
		long_fired.erase(key)
		for b in bindings:
			if b.key == key and b.gesture == "press":
				commands.append(b.command)
		if pending.has(key) and now - float(pending[key]) <= double_threshold:
			for b in bindings:
				if b.key == key and b.gesture == "double":
					commands.append(b.command)
			pending.erase(key)
			long_fired[key] = true
	else:
		if not held.has(key):
			return commands
		var duration: float = now - float(held[key])
		held.erase(key)
		if long_fired.has(key) or duration >= hold_threshold:
			return commands
		var has_double := false
		for b in bindings:
			if b.key == key and b.gesture == "double":
				has_double = true
		if has_double:
			pending[key] = now
		else:
			for b in bindings:
				if b.key == key and b.gesture == "tap":
					commands.append(b.command)
	return commands

func advance(now: float) -> Array[String]:
	var commands: Array[String] = []
	for key in pending.keys():
		if now - float(pending[key]) > double_threshold:
			for b in bindings:
				if b.key == key and b.gesture == "tap":
					commands.append(b.command)
			pending.erase(key)
	for key in held:
		if now - float(held[key]) >= hold_threshold and not long_fired.has(key):
			for b in bindings:
				if b.key == key and b.gesture == "long":
					commands.append(b.command)
			long_fired[key] = true
	return commands

func movement(held_before: float = INF) -> Vector2:
	var result := Vector2.ZERO
	for b in bindings:
		if b.gesture != "hold" or not held.has(b.key) or float(held[b.key]) > held_before:
			continue
		match b.command:
			"move_left": result.x -= 1
			"move_right": result.x += 1
			"move_up": result.y -= 1
			"move_down": result.y += 1
	return result.limit_length()
