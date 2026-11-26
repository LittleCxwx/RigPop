extends RefCounted

## PSD / 分层素材 → 角色的自动装配。
##
## 输入是语义不明的图层列表（名称 + 裁边后的图片 + 原画布位置），输出是
## 带 `role` 的部件草案。匹配顺序：名称关键词 → 图层组 → 相对位置回退，
## 用户可以在导入对话框里改任何一项，所以这里只需要"大体猜对"。

const Rig = preload("res://core/rig.gd")
const Character = preload("res://core/character.gd")

## 图层角色的优先级：先匹配具体的（手、脚、尾巴），再匹配大的（身体、头）。
const PRIORITY := ["scarf_tail", "scarf", "cape", "hair", "tail", "hand_l", "hand_r",
	"foot_l", "foot_r", "arm_l", "arm_r", "leg_l", "leg_r", "ear_l", "ear_r",
	"wing_l", "wing_r", "weapon", "face", "head", "body"]


## 把图层草案映射到 rig 的 role。
## layers 每项：{"name", "group", "position": Vector2i, "size": Vector2i, "image": Image}
## 返回同长度数组，每项补充 role（未匹配为空）与 match（名称/组名/位置/手动）。
static func assign(layers: Array, rig: String) -> Array:
	var result := []
	var allowed := Rig.roles(rig)
	var used := {}
	for original in layers:
		var layer: Dictionary = original.duplicate()
		var role := Rig.guess_role(str(layer.get("name", "")), str(layer.get("group", "")), allowed)
		var source_label := "名称"
		if role.is_empty():
			role = Rig.guess_role(str(layer.get("group", "")), "", allowed)
			source_label = "图层组"
		if role.is_empty():
			var positional := by_position(layer, layers, allowed)
			if not positional.is_empty():
				role = positional
				source_label = "位置"
		if not role.is_empty() and used.has(role):
			# 同名角色只保留面积最大的一张，其余留给用户处理
			if area(layer) > area(used[role]):
				used[role].role = ""
				used[role].match = "重名未分配"
				used[role] = layer
				layer.role = role
				layer.match = source_label
			else:
				layer.role = ""
				layer.match = "重名未分配"
		else:
			layer.role = role
			layer.match = source_label if not role.is_empty() else "未匹配"
			if not role.is_empty():
				used[role] = layer
		result.append(layer)
	return result


static func area(layer: Dictionary) -> int:
	var size: Vector2i = layer.get("size", Vector2i.ONE)
	return size.x * size.y


## 没有名称线索时，用图层在画布里的相对位置猜：上部偏中的是头、下方左右是腿。
static func by_position(layer: Dictionary, all: Array, allowed: Array) -> String:
	var position: Vector2i = layer.get("position", Vector2i.ZERO)
	var size: Vector2i = layer.get("size", Vector2i.ONE)
	var center := Vector2(position) + Vector2(size) * 0.5
	var box := Rect2i()
	for other in all:
		var p: Vector2i = other.get("position", Vector2i.ZERO)
		var s: Vector2i = other.get("size", Vector2i.ONE)
		var r := Rect2i(p, s)
		box = r if box.size == Vector2i.ZERO else box.merge(r)
	if box.size == Vector2i.ZERO:
		return ""
	var nx := (center.x - box.position.x) / maxf(1.0, box.size.x)
	var ny := (center.y - box.position.y) / maxf(1.0, box.size.y)
	var area_ratio := float(size.x * size.y) / maxf(1.0, float(box.size.x * box.size.y))
	if area_ratio > 0.42:
		return "body" if "body" in allowed else ""
	if area_ratio > 0.2 and ny < 0.55:
		return "head" if "head" in allowed else ""
	if ny > 0.62 and nx < 0.44:
		return first(allowed, ["leg_l", "foot_l", "arm_l"])
	if ny > 0.62 and nx > 0.56:
		return first(allowed, ["leg_r", "foot_r", "arm_r"])
	if ny < 0.6 and nx < 0.32:
		return first(allowed, ["arm_l", "hand_l", "ear_l", "wing_l"])
	if ny < 0.6 and nx > 0.68:
		return first(allowed, ["arm_r", "hand_r", "ear_r", "wing_r"])
	return ""


static func first(allowed: Array, candidates: Array) -> String:
	for candidate in candidates:
		if candidate in allowed:
			return candidate
	return ""


## Anchors are chosen in source coordinates. Parent offsets and pivots cancel so
## every layer retains its original PSD position regardless of canvas size.
static func build_model(entries: Array, rig: String, title: String, _origin_y: float = 0.0) -> Dictionary:
	var model: Dictionary = Character.empty(title)
	model.rig = rig
	model.parts = []
	var anchors := {}
	var ids := {}
	var bounds := Rect2()
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var position := Vector2(entry.position)
		var size := Vector2(entry.size)
		var rect := Rect2(position, size)
		bounds = rect if i == 0 else bounds.merge(rect)
		var role := str(entry.get("role", ""))
		var fraction := Vector2(0.5, 0.5)
		if role == "body": fraction = Vector2(0.5, 0.8)
		elif role == "head": fraction = Vector2(0.5, 0.85)
		elif role.begins_with("arm") or role.begins_with("leg") or role.begins_with("hand") or role.begins_with("foot"): fraction = Vector2(0.5, 0.1)
		elif role.begins_with("ear"): fraction = Vector2(0.5, 0.9)
		elif role == "tail": fraction = Vector2(0.25, 0.85)
		var id := "psd_" + str(entry.get("key", str(i))).replace("/", "_")
		entry.part_id = id
		anchors[id] = position + size * fraction
		if not role.is_empty(): ids[role] = id
	var origin := Vector2(bounds.get_center().x, bounds.end.y)
	for entry in entries:
		var role := str(entry.get("role", ""))
		var id := str(entry.part_id)
		var parent_role := Rig.default_parent(rig, role)
		while not parent_role.is_empty() and not ids.has(parent_role):
			parent_role = Rig.default_parent(rig, parent_role)
		var parent := str(ids.get(parent_role, ""))
		var anchor: Vector2 = anchors[id]
		var relative: Vector2 = anchor - anchors.get(parent, origin)
		var pivot: Vector2 = anchor - Vector2(entry.position)
		model.parts.append({
			"id": id, "role": role, "name": str(entry.name), "parent": parent,
			"position": [relative.x, relative.y],
			"pivot": [pivot.x, pivot.y], "rotation": 0.0,
			"z": int(entry.get("z", model.parts.size())), "visible": bool(entry.get("visible", true)),
			"asset": "assets/%s.png" % id,
		})
	model.modules["rigpop.rig"] = {"motion_scale": bounds.size.y / 88.0}
	return model
