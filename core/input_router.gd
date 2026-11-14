extends RefCounted

var bindings: Array = []
var held := {}
var pending := {}
var long_fired := {}
var hold_threshold := 0.3
var double_threshold := 0.25

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

func movement() -> Vector2:
	var result := Vector2.ZERO
	for b in bindings:
		if b.gesture != "hold" or not held.has(b.key):
			continue
		match b.command:
			"move_left": result.x -= 1
			"move_right": result.x += 1
			"move_up": result.y -= 1
			"move_down": result.y += 1
	return result.limit_length()
