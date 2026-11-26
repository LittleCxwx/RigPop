extends RefCounted

const Character = preload("res://core/character.gd")
const MODULE := "rigpop.desktop_states"
const COMMAND_PREFIX := "state:"
const FALLBACK_MOVEMENT := {"A": "move_left", "D": "move_right", "W": "move_up", "S": "move_down"}
const ACTION_LIMIT := 5.0

static func state(title: String = "原始", key: String = "", clip: String = "",
		overlay: bool = true, locked: bool = false, variants: Dictionary = {}, lock_jump: bool = false) -> Dictionary:
	return {"name": title, "key": key, "clip": clip, "overlay": overlay,
		"lock_movement": locked, "lock_jump": lock_jump, "variants": variants.duplicate()}

static func read(model: Dictionary) -> Array:
	var module = model.get("modules", {}).get(MODULE, {})
	var source = module.get("states", []) if module is Dictionary else []
	var items := []
	if source is Array:
		for item in source:
			if not item is Dictionary: continue
			var variants = item.get("variants", {})
			var clip := str(item.get("clip", ""))
			items.append(state(str(item.get("name", "状态")), str(item.get("key", "")), clip,
				bool(item.get("overlay", true)), bool(item.get("lock_movement", false)),
				variants if variants is Dictionary else {}, bool(item.get("lock_jump", clip == "seated"))))
	return [state()] if items.is_empty() else items

static func resolve(model: Dictionary, selected: Dictionary, action: String) -> String:
	var replacement := str(selected.get("variants", {}).get(action, ""))
	return replacement if not Character.find_action(model, replacement).is_empty() else action

static func is_jump(action: String) -> bool:
	return action == "jump" or action.begins_with("jump_")

static func key_error(items: Array, bindings: Array) -> String:
	var used := FALLBACK_MOVEMENT.duplicate()
	for binding in bindings:
		used[str(binding.key).to_upper()] = true
	for item in items:
		var key := str(item.key).strip_edges()
		if key.is_empty(): continue
		var code := OS.find_keycode_from_string(key)
		if code == KEY_NONE or code in [KEY_ESCAPE, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
			return "「%s」的切换键无效，请输入单个键名，例如 2 或 F6。" % item.name
		item.key = OS.get_keycode_string(code)
		var canonical := str(item.key).to_upper()
		if used.has(canonical):
			return "切换键 %s 已占用，请为「%s」换一个键。" % [item.key, item.name]
		used[canonical] = true
	return ""

static func pose_frame(clip: Dictionary, elapsed: float) -> int:
	var count := maxi(1, int(clip.get("frames", 1)))
	return int(elapsed * float(clip.get("fps", 8))) % count if clip.get("loop", false) else count - 1
