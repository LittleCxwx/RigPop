extends RefCounted

const FORMAT_VERSION := 1
const API_VERSION := 1

static func uid(prefix: String) -> String:
	return "%s_%08x%08x" % [prefix, randi(), randi()]

static func part(id: String, title: String, parent: String, xy: Array, pivot: Array, z: int) -> Dictionary:
	return {"id": id, "name": title, "parent": parent, "position": xy, "pivot": pivot,
		"rotation": 0.0, "z": z, "visible": true, "asset": "assets/%s.png" % id}

static func joint(id: String, title: String, parent: String, xy: Array) -> Dictionary:
	var result := part(id, title, parent, xy, [0, 0], 0)
	result.kind = "joint"
	return result

static func reparent(model: Dictionary, id: String, parent: String) -> bool:
	var p := find_part(model, id)
	if p.is_empty() or id == parent or (not parent.is_empty() and find_part(model, parent).is_empty()): return false
	var ancestor := parent
	while not ancestor.is_empty():
		if ancestor == id: return false
		ancestor = str(find_part(model, ancestor).get("parent", ""))
	var world := transforms(model, {}, 0)
	var parent_world: Transform2D = world.get(parent, Transform2D.IDENTITY)
	var local: Transform2D = parent_world.affine_inverse() * world[id]
	p.parent = parent
	p.position = [local.origin.x, local.origin.y]
	p.rotation = rad_to_deg(local.get_rotation())
	return true

static func empty(title: String) -> Dictionary:
	return {"format_version": FORMAT_VERSION, "id": uid("character"), "name": title,
		"rig": "", "parts": [], "actions": [], "palette": ["263642", "f3f5ef", "8ecfbe", "4a9f91", "f18b80", "bcca82", "e8bd78", "9296b0"],
		"bindings": [{"key": "A", "gesture": "hold", "command": "move_left"},
			{"key": "D", "gesture": "hold", "command": "move_right"},
			{"key": "W", "gesture": "hold", "command": "move_up"},
			{"key": "S", "gesture": "hold", "command": "move_down"},
			{"key": "Space", "gesture": "tap", "command": "wave"}],
		"game": {"speed": 115.0, "collision_radius": 9.0},
		"desktop": {"scale": 4, "always_on_top": true, "wander": false}, "modules": {}}

static func action(id: String, title: String, count: int = 8) -> Dictionary:
	return {"id": id, "name": title, "frames": count, "fps": 8.0, "loop": true,
		"overlay": false, "priority": 0, "conflict": "replace", "lock_movement": false, "tracks": {}}

static func find_part(model: Dictionary, id: String) -> Dictionary:
	for p in model.get("parts", []):
		if p is Dictionary and p.get("id", "") == id:
			return p
	return {}

static func find_action(model: Dictionary, id: String) -> Dictionary:
	for clip in model.get("actions", []):
		if clip.id == id:
			return clip
	return {}

static func vec(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))

static func pose(clip: Dictionary, id: String, frame: int) -> Dictionary:
	var result := {"position": [0, 0], "rotation": 0.0}
	var best := -1
	for key in clip.get("tracks", {}).get(id, []):
		if int(key.frame) <= frame and int(key.frame) > best:
			best = int(key.frame)
			result = key.duplicate(true)
	return result

static func set_key(clip: Dictionary, id: String, frame: int, value: Dictionary) -> void:
	if not clip.tracks.has(id):
		clip.tracks[id] = []
	var keys: Array = clip.tracks[id]
	for i in range(keys.size() - 1, -1, -1):
		if int(keys[i].frame) == frame:
			keys.remove_at(i)
	var key := value.duplicate(true)
	key.frame = frame
	keys.append(key)
	keys.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.frame) < int(b.frame))

static func layered_pose(clip: Dictionary, id: String, frame: int, overlay: Dictionary = {}, overlay_frame: int = 0, layers: Array = []) -> Dictionary:
	var result := pose(clip, id, frame)
	if not overlay.get("tracks", {}).get(id, []).is_empty(): result = pose(overlay, id, overlay_frame)
	for layer in layers:
		if layer.clip.get("tracks", {}).get(id, []).is_empty(): continue
		var sampled := pose(layer.clip, id, int(layer.frame))
		if layer.get("merge_pose", false):
			if sampled.has("frame"): result.merge(sampled, true)
		else:
			result = sampled
	return result

static func transforms(model: Dictionary, clip: Dictionary, frame: int, overlay: Dictionary = {}, overlay_frame: int = 0, layers: Array = []) -> Dictionary:
	var result := {}
	var pending: Array = model.get("parts", []).duplicate()
	for _pass in range(pending.size() + 1):
		for i in range(pending.size() - 1, -1, -1):
			var p: Dictionary = pending[i]
			if not str(p.parent).is_empty() and not result.has(p.parent):
				continue
			var sampled := layered_pose(clip, p.id, frame, overlay, overlay_frame, layers)
			var local := Transform2D(deg_to_rad(float(p.rotation) + float(sampled.get("rotation", 0))), vec(p.position) + vec(sampled.get("position", [0, 0])))
			result[p.id] = result.get(p.parent, Transform2D.IDENTITY) * local
			pending.remove_at(i)
	return result

static func validate(model: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if int(model.get("format_version", 0)) != FORMAT_VERSION:
		errors.append("不支持的工程格式版本：%s" % model.get("format_version", "缺失"))
	if not safe_id(str(model.get("id", ""))) or str(model.get("name", "")).strip_edges().is_empty():
		errors.append("角色缺少 ID 或名称")
	if not model.get("id") is String or not model.get("name") is String: errors.append("角色 ID 与名称必须为文本")
	if not model.get("parts") is Array or not model.get("actions") is Array:
		errors.append("parts 和 actions 必须为数组")
		return errors
	if not model.get("bindings") is Array or not model.get("game") is Dictionary or not model.get("desktop") is Dictionary or not model.get("palette") is Array:
		errors.append("缺少控制、模式配置或色板")
		return errors
	if model.has("rig") and (not model.rig is String or model.rig.length() > 64):
		errors.append("骨骼模板标识无效")
	if not model.game.get("speed") is float and not model.game.get("speed") is int:
		errors.append("游戏移动速度无效")
	if not model.game.get("collision_radius") is float and not model.game.get("collision_radius") is int:
		errors.append("游戏碰撞半径无效")
	if not model.desktop.has_all(["scale", "always_on_top", "wander"]):
		errors.append("桌宠配置字段缺失")
	elif not numeric(model.desktop.scale) or float(model.desktop.scale) < 1 or float(model.desktop.scale) > 8 or not model.desktop.always_on_top is bool or not model.desktop.wander is bool:
		errors.append("桌宠配置参数无效")
	if numeric(model.game.get("speed")) and (float(model.game.speed) < 0 or float(model.game.speed) > 4096): errors.append("移动速度超出范围")
	if numeric(model.game.get("collision_radius")) and (float(model.game.collision_radius) < 1 or float(model.game.collision_radius) > 256): errors.append("碰撞半径超出范围")
	if model.game.has("visual_scale"):
		if not numeric(model.game.visual_scale): errors.append("游戏显示倍率无效")
		elif float(model.game.visual_scale) < 0.1 or float(model.game.visual_scale) > 8: errors.append("游戏显示倍率超出范围")
	for color in model.palette:
		if not color is String or not color.length() in [6, 8] or not color.is_valid_hex_number(false): errors.append("色板颜色无效")
	if model.parts.size() > 256 or model.actions.size() > 256:
		errors.append("角色部件或动作过多")
	var ids := {}
	for p in model.parts:
		if not p is Dictionary or not p.has_all(["id", "name", "parent", "position", "pivot", "rotation", "z", "visible", "asset"]):
			errors.append("部件字段不完整")
			continue
		if ids.has(p.id):
			errors.append("部件 ID 重复：%s" % p.id)
		if not p.id is String or not safe_id(str(p.id)) or not p.name is String or not p.parent is String or not p.visible is bool or not numeric(p.rotation) or not numeric(p.z): errors.append("部件字段类型无效")
		if p.has("kind") and p.kind not in ["part", "joint"]: errors.append("部件类型无效")
		if p.has("role") and (not p.role is String or p.role.length() > 64):
			errors.append("部件骨骼角色无效：%s" % p.id)
		if p.has("role") and p.role is String and not p.role.is_empty() and not safe_id(str(p.role)):
			errors.append("部件骨骼角色只能使用字母、数字、下划线与连字符：%s" % p.id)
		ids[p.id] = true
		for field in ["position", "pivot"]:
			if not valid_vector(p[field]):
				errors.append("部件坐标无效：%s" % p.id)
		if not safe_path(str(p.asset)):
			errors.append("素材路径必须为安全相对路径")
	for p in model.parts:
		if not p is Dictionary or not p.has_all(["id", "parent"]):
			continue
		var seen := {p.id: true}
		var parent: String = str(p.parent)
		while not parent.is_empty():
			if seen.has(parent) or not ids.has(parent):
				errors.append("部件层级存在循环或缺少父节点：%s" % p.id)
				break
			seen[parent] = true
			parent = str(find_part(model, parent).get("parent", ""))
	var action_ids := {}
	for clip in model.actions:
		if not clip is Dictionary or not clip.has_all(["id", "name", "frames", "fps", "loop", "overlay", "tracks"]):
			errors.append("动作字段不完整")
			continue
		if not numeric(clip.frames) or not numeric(clip.fps) or not clip.name is String or not clip.id is String or not clip.loop is bool or not clip.overlay is bool:
			errors.append("动作字段类型无效")
			continue
		if action_ids.has(clip.id) or int(clip.frames) < 1 or int(clip.frames) > 240 or float(clip.fps) <= 0 or float(clip.fps) > 120:
			errors.append("动作 ID、长度或帧率无效")
		action_ids[clip.id] = true
		if clip.has("priority") and (not numeric(clip.priority) or float(clip.priority) < -100 or float(clip.priority) > 100): errors.append("动作优先级无效")
		if clip.get("conflict", "replace") not in ["replace", "reject"]: errors.append("动作冲突规则无效")
		if not clip.get("lock_movement", false) is bool: errors.append("动作移动锁定无效")
		if not clip.tracks is Dictionary:
			errors.append("动作轨道必须为对象")
			continue
		for id in clip.tracks:
			if not ids.has(id):
				errors.append("动作引用不存在的部件：%s" % id)
			if not clip.tracks[id] is Array:
				errors.append("动作关键帧必须为数组")
				continue
			var frames := {}
			for key in clip.tracks[id]:
				if not key is Dictionary or not key.has("frame"):
					errors.append("关键帧字段无效")
					continue
				if not numeric(key.frame):
					errors.append("关键帧编号必须为数值")
					continue
				if int(key.frame) < 0 or int(key.frame) >= int(clip.frames) or frames.has(int(key.frame)):
					errors.append("关键帧超出动作长度或重复")
				frames[int(key.frame)] = true
				if key.has("position") and not valid_vector(key.position): errors.append("关键帧位置无效")
				if key.has("rotation") and not numeric(key.rotation): errors.append("关键帧旋转无效")
				if key.has("visible") and not key.visible is bool: errors.append("关键帧可见性无效")
				if key.has("asset") and not safe_path(str(key.asset)): errors.append("关键帧图片路径越界")
	for b in model.bindings:
		if not b is Dictionary or not b.has_all(["key", "gesture", "command"]):
			errors.append("控制绑定字段不完整")
			continue
		if not b.key is String or not b.gesture is String or not b.command is String:
			errors.append("控制绑定字段类型无效")
			continue
		if not b.gesture in ["tap", "hold", "long", "double"]: errors.append("不支持的输入手势")
		if not b.command in ["move_left", "move_right", "move_up", "move_down"] and not action_ids.has(b.command):
			errors.append("控制引用不存在的动作：" + str(b.command))
	return errors

static func valid_vector(value: Variant) -> bool:
	if not value is Array or value.size() != 2: return false
	return numeric(value[0]) and numeric(value[1])

static func numeric(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func safe_id(id: String) -> bool:
	if id.is_empty() or id.length() > 128: return false
	for ch in id:
		if not ch.to_lower() in "abcdefghijklmnopqrstuvwxyz0123456789_-": return false
	return true

static func safe_path(path: String) -> bool:
	return not path.is_empty() and not path.is_absolute_path() and not path.contains("..") and not path.contains(":") and not path.contains("\\") and path.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"]
