extends RefCounted

## 骨骼模板（rig）：定义一套标准部位角色与它们的父子关系。
##
## 角色模型里每个部件都有 `role` 字段（head / arm_l / leg_r …）。预设动作只按
## role 记录关键帧，套用到具体角色时再映射成部件 id，因此同一 rig 下的角色共享
## 同一批动作；换个角色微调即可，不必从头摆姿势。PSD 导入也按 role 名称快速匹配。

const QUADRUPED := "rigpop.quadruped.v1"
const BIPED := "rigpop.biped.v1"

## role -> 中文名，用于界面与名称匹配提示。
const ROLE_NAMES := {
	"body": "身体", "head": "头部", "hair": "头发", "ear_l": "左耳", "ear_r": "右耳",
	"arm_l": "左臂", "arm_r": "右臂", "hand_l": "左手", "hand_r": "右手",
	"leg_l": "左腿", "leg_r": "右腿", "foot_l": "左脚", "foot_r": "右脚",
	"tail": "尾巴", "scarf": "围巾", "scarf_tail": "围巾飘带", "cape": "披风",
	"weapon": "武器", "face": "表情", "wing_l": "左翼", "wing_r": "右翼",
	"forearm_l": "左前臂", "forearm_r": "右前臂", "shin_l": "左小腿", "shin_r": "右小腿",
	"shirt": "上衣",
}

## 每个 rig 的部件顺序即从根到叶的层级；anchor 建议值用于 PSD 导入后的自动摆放。
const RIGS := {
	QUADRUPED: {
		"name": "四足 · 小兽",
		"parts": [
			{"role": "body", "parent": "", "anchor": [48, 74], "z": 1},
			{"role": "head", "parent": "body", "anchor": [48, 52], "z": 5},
			{"role": "ear_l", "parent": "head", "anchor": [30, 20], "z": 4},
			{"role": "ear_r", "parent": "head", "anchor": [66, 20], "z": 4},
			{"role": "arm_l", "parent": "body", "anchor": [32, 61], "z": 3},
			{"role": "arm_r", "parent": "body", "anchor": [64, 61], "z": 3},
			{"role": "leg_l", "parent": "body", "anchor": [40, 76], "z": 0},
			{"role": "leg_r", "parent": "body", "anchor": [56, 76], "z": 0},
			{"role": "tail", "parent": "body", "anchor": [58, 78], "z": -1},
			{"role": "scarf", "parent": "body", "anchor": [48, 55], "z": 2},
			{"role": "scarf_tail", "parent": "body", "anchor": [34, 56], "z": -2},
		],
	},
	BIPED: {
		"name": "人形",
		"parts": [
			{"role": "body", "parent": "", "anchor": [48, 60], "z": 1},
			{"role": "head", "parent": "body", "anchor": [48, 28], "z": 5},
			{"role": "hair", "parent": "head", "anchor": [48, 22], "z": 6},
			{"role": "arm_l", "parent": "body", "anchor": [32, 44], "z": 3},
			{"role": "arm_r", "parent": "body", "anchor": [64, 44], "z": 3},
			{"role": "hand_l", "parent": "arm_l", "anchor": [30, 62], "z": 4},
			{"role": "hand_r", "parent": "arm_r", "anchor": [66, 62], "z": 4},
			{"role": "leg_l", "parent": "body", "anchor": [41, 74], "z": 0},
			{"role": "leg_r", "parent": "body", "anchor": [55, 74], "z": 0},
			{"role": "foot_l", "parent": "leg_l", "anchor": [41, 86], "z": 1},
			{"role": "foot_r", "parent": "leg_r", "anchor": [55, 86], "z": 1},
			{"role": "cape", "parent": "body", "anchor": [48, 52], "z": -1},
			{"role": "forearm_l", "parent": "arm_l", "anchor": [29, 54], "z": 3},
			{"role": "forearm_r", "parent": "arm_r", "anchor": [67, 54], "z": 3},
			{"role": "shin_l", "parent": "leg_l", "anchor": [41, 80], "z": 0},
			{"role": "shin_r", "parent": "leg_r", "anchor": [55, 80], "z": 0},
			{"role": "face", "parent": "head", "anchor": [48, 28], "z": 6},
			{"role": "tail", "parent": "body", "anchor": [55, 66], "z": -2},
			{"role": "shirt", "parent": "body", "anchor": [48, 48], "z": 2},
			{"role": "scarf", "parent": "body", "anchor": [48, 40], "z": 4},
		],
	},
}

const SUPPORTED := [QUADRUPED, BIPED]

static func exists(rig: String) -> bool:
	return RIGS.has(rig)

static func rig_name(rig: String) -> String:
	return str(RIGS.get(rig, {}).get("name", "未知骨架"))

static func roles(rig: String) -> Array:
	var result := []
	for part in RIGS.get(rig, {}).get("parts", []):
		result.append(str(part.role))
	return result

static func default_parent(rig: String, role: String) -> String:
	for part in RIGS.get(rig, {}).get("parts", []):
		if part.role == role:
			return str(part.parent)
	return ""

static func anchor(rig: String, role: String) -> Array:
	for part in RIGS.get(rig, {}).get("parts", []):
		if part.role == role:
			return part.get("anchor", [48, 72])
	return [48, 72]

## 角色使用哪套骨架；模型未声明时按已有 role 推断。
static func detect(model: Dictionary) -> String:
	var declared := str(model.get("rig", ""))
	if exists(declared):
		return declared
	if model.has("rig"):
		return ""
	var found := {}
	for part in model.get("parts", []):
		if part is Dictionary and part.has("role"):
			found[str(part.role)] = true
	if found.is_empty():
		return ""
	if found.has("leg_l") and not found.has("hand_l"):
		return QUADRUPED
	return BIPED

## 部件 id -> role 的映射；旧工程没有 role 时按 id 兜底。
static func role_map(model: Dictionary) -> Dictionary:
	var result := {}
	for part in model.get("parts", []):
		if not part is Dictionary:
			continue
		var role := str(part.get("role", ""))
		if not part.has("role"):
			role = str(part.get("id", ""))
		if role.is_empty(): continue
		result[role] = str(part.get("id", ""))
	return result

## 为模型补全 role：已有保留，缺失的按 id 或名称推断。
static func assign_roles(model: Dictionary) -> int:
	var rig := detect(model)
	var added := 0
	for part in model.get("parts", []):
		if not part is Dictionary:
			continue
		if not str(part.get("role", "")).is_empty():
			continue
		var role := guess_role(str(part.get("id", "")), str(part.get("name", "")))
		if role.is_empty() and not rig.is_empty():
			role = guess_role(str(part.get("id", "")), str(part.get("name", "")), roles(rig))
		if not role.is_empty():
			part.role = role
			added += 1
	return added

const NAME_HINTS := {
	"body": ["body", "torso", "身体", "躯干", "身"],
	"head": ["head", "face", "脸", "头"],
	"hair": ["hair", "发型", "头发", "前发", "后发"],
	"ear": ["ear", "耳"],
	"arm": ["arm", "手", "臂", "arm_l", "arm_r"],
	"forearm": ["forearm", "前臂", "小臂"],
	"hand": ["hand", "掌", "拳"],
	"leg": ["leg", "腿", "足", "脚", "boot", "靴"],
	"shin": ["shin", "calf", "小腿"],
	"foot": ["foot", "feet", "鞋", "靴"],
	"tail": ["tail", "尾"],
	"scarf": ["scarf", "围巾", "领巾"],
	"scarf_tail": ["scarf_tail", "飘带", "围巾尾"],
	"cape": ["cape", "cloak", "披风", "斗篷", "披肩"],
	"weapon": ["weapon", "sword", "武器", "剑"],
	"wing": ["wing", "翼", "翅膀"],
	"face": ["expression", "face", "表情"],
	"shirt": ["shirt", "上衣"],
}

const LEFT_HINTS := ["_l", "left", "左", "_l.", "l_"]
const RIGHT_HINTS := ["_r", "right", "右", "_r.", "r_"]

## 由部件 id 与显示名称猜一个标准 role；带左右的关键词会补 _l / _r。
static func guess_role(id: String, title: String = "", allowed: Array = []) -> String:
	var hay := (id + " " + title).to_lower()
	for exact in ROLE_NAMES:
		if id.to_lower() == exact and (allowed.is_empty() or exact in allowed):
			return exact
	var best := ""
	var best_score := 0
	for role in NAME_HINTS:
		for hint in NAME_HINTS[role]:
			if hay.contains(hint.to_lower()):
				if hint.length() > best_score:
					best = role
					best_score = hint.length()
	if best.is_empty():
		return ""
	var sided := ["arm", "forearm", "hand", "leg", "shin", "foot", "ear", "wing"]
	if best in sided:
		var side := ""
		var lower := id.to_lower() + " " + title.to_lower()
		var has_left := false
		var has_right := false
		for hint in LEFT_HINTS:
			if lower.contains(hint):
				has_left = true
		for hint in RIGHT_HINTS:
			if lower.contains(hint):
				has_right = true
		if has_left and not has_right:
			side = "_l"
		elif has_right and not has_left:
			side = "_r"
		if side.is_empty():
			# 无明确左右时按名称顺序稳定分配，稍后由用户确认。
			return ""
		best += side
	if not allowed.is_empty() and not best in allowed:
		return ""
	return best

static func role_title(role: String) -> String:
	return str(ROLE_NAMES.get(role, role))
