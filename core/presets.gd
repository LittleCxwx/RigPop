extends RefCounted

## 预设动作库：按骨骼模板记录的标准动作（走、跑、待机、招手……）。
##
## 关键帧按 role 而不是部件 id 记录，套到角色上时再映射，因此同一 rig 的所有角色
## 直接共享动作；换皮角色只改图片、不改姿势。数值可在应用后继续手工微调。

const Rig = preload("res://core/rig.gd")
const Character = preload("res://core/character.gd")

## 预设定义：id、名称、帧数、fps、是否叠加、说明，以及每个 role 的关键帧。
## 关键帧写成 [帧号, 位置x, 位置y, 旋转]，位置单位像素、旋转单位度。
const LIBRARY := {
	"idle": {
		"name": "待机", "frames": 8, "fps": 8, "overlay": false, "kind": "loop",
		"hint": "呼吸起伏与尾巴轻摆",
		"roles": {
			"body": [[0, 0, 0, 0], [2, 0, -1, 0], [4, 0, 0, 0], [6, 0, 1, 0]],
			"head": [[0, 0, 0, 0], [2, 0, -1, 0], [4, 0, 0, 0], [6, 0, 1, 0]],
			"ear_l": [[0, 0, 0, 0], [4, 0, -1, -3]],
			"ear_r": [[0, 0, 0, 0], [4, 0, -1, 3]],
			"tail": [[0, 0, 0, -6], [4, 0, 0, 6]],
			"scarf_tail": [[0, 0, 0, 4], [4, 0, 0, -4]],
			"arm_l": [[0, 0, 0, 0], [4, 0, 1, 0]],
			"arm_r": [[0, 0, 0, 0], [4, 0, 1, 0]],
		},
	},
	"walk": {
		"name": "行走", "frames": 8, "fps": 10, "overlay": false, "kind": "loop",
		"hint": "四足交替迈步、身体上下颠簸",
		"roles": {
			"body": [[0, 0, 0, 0], [2, 0, -2, 0], [4, 0, 0, 0], [6, 0, -2, 0]],
			"head": [[0, 0, 0, 0], [2, 0, 1, 0], [4, 0, 0, 0], [6, 0, 1, 0]],
			"leg_l": [[0, 0, 0, 26], [2, 0, 0, 0], [4, 0, 0, -26], [6, 0, 0, 0]],
			"leg_r": [[0, 0, 0, -26], [2, 0, 0, 0], [4, 0, 0, 26], [6, 0, 0, 0]],
			"arm_l": [[0, 0, 0, -28], [2, 0, 0, 0], [4, 0, 0, 28], [6, 0, 0, 0]],
			"arm_r": [[0, 0, 0, 28], [2, 0, 0, 0], [4, 0, 0, -28], [6, 0, 0, 0]],
			"ear_l": [[0, 0, 0, -4], [2, 0, 1, 0], [4, 0, 0, -4], [6, 0, 1, 0]],
			"ear_r": [[0, 0, 0, 4], [2, 0, 1, 0], [4, 0, 0, 4], [6, 0, 1, 0]],
			"tail": [[0, 0, 0, -14], [2, 0, -1, 0], [4, 0, 0, 14], [6, 0, -1, 0]],
			"scarf_tail": [[0, 0, 0, 16], [2, 0, 2, 0], [4, 0, 0, 16], [6, 0, 2, 0]],
		},
	},
	"run": {
		"name": "奔跑", "frames": 6, "fps": 14, "overlay": false, "kind": "loop",
		"hint": "更快、幅度更大的行走",
		"roles": {
			"body": [[0, 0, -1, -6], [1, 0, -4, 0], [2, 0, -1, 6], [3, 0, -1, 6], [4, 0, -4, 0], [5, 0, -1, -6]],
			"head": [[0, 0, 1, 4], [2, 0, 2, 0], [4, 0, 1, 4]],
			"leg_l": [[0, 0, 0, 44], [2, 0, 0, -44], [4, 0, 0, 44]],
			"leg_r": [[0, 0, 0, -44], [2, 0, 0, 44], [4, 0, 0, -44]],
			"arm_l": [[0, 0, 0, -46], [2, 0, 0, 46], [4, 0, 0, -46]],
			"arm_r": [[0, 0, 0, 46], [2, 0, 0, -46], [4, 0, 0, 46]],
			"tail": [[0, 0, -2, -24], [2, 0, -2, 24], [4, 0, -2, -24]],
			"scarf_tail": [[0, 6, -2, 28], [2, 4, 0, 10], [4, 6, -2, 28]],
		},
	},
	"wave": {
		"name": "招手", "frames": 8, "fps": 8, "overlay": true, "kind": "once",
		"hint": "抬起右手挥动，叠加在待机或行走上",
		"roles": {
			"arm_r": [[0, 0, 0, -120], [2, 0, -2, -150], [4, 0, 0, -120], [6, 0, -2, -145]],
			"head": [[0, 0, 0, 4], [4, 0, 0, -4]],
		},
	},
	"nod": {
		"name": "点头", "frames": 6, "fps": 8, "overlay": true, "kind": "once",
		"hint": "头部上下点头",
		"roles": {
			"head": [[0, 0, 0, 0], [1, 0, 3, 10], [2, 0, 0, 0], [3, 0, 3, 10], [4, 0, 0, 0]],
		},
	},
	"jump": {
		"name": "跳跃", "frames": 8, "fps": 10, "overlay": false, "kind": "once",
		"hint": "下蹲蓄力、起跳、落地",
		"roles": {
			"body": [[0, 0, 2, 0], [1, 0, 4, 0], [3, 0, -16, 0], [5, 0, -12, 0], [7, 0, 2, 0]],
			"head": [[0, 0, 1, 0], [1, 0, 2, 4], [3, 0, -2, -6], [5, 0, -1, 0], [7, 0, 1, 2]],
			"leg_l": [[0, 0, 0, -8], [3, 0, 0, 30], [5, 0, 0, 18], [7, 0, 0, -8]],
			"leg_r": [[0, 0, 0, 8], [3, 0, 0, -30], [5, 0, 0, -18], [7, 0, 0, 8]],
			"arm_l": [[0, 0, 0, 10], [3, 0, 0, -50], [5, 0, 0, -40], [7, 0, 0, 10]],
			"arm_r": [[0, 0, 0, -10], [3, 0, 0, 50], [5, 0, 0, 40], [7, 0, 0, -10]],
			"tail": [[0, 0, 0, 0], [3, 0, -2, -20], [5, 0, 0, 10], [7, 0, 0, 0]],
			"scarf_tail": [[0, 0, 2, 0], [3, 0, -6, 20], [5, 0, 0, 10], [7, 0, 2, 0]],
		},
	},
	"sit": {
		"name": "坐下", "frames": 8, "fps": 8, "overlay": false, "kind": "once",
		"hint": "身体下沉，尾巴收拢",
		"roles": {
			"body": [[0, 0, 0, 0], [4, 0, 2, 0], [7, 0, 2, 0]],
			"head": [[0, 0, 0, 0], [4, 0, 2, 0], [7, 0, 2, 0]],
			"leg_l": [[0, 0, 0, 0], [4, 0, 0, -20]],
			"leg_r": [[0, 0, 0, 0], [4, 0, 0, 20]],
			"tail": [[0, 0, 0, 0], [4, 0, 2, 30]],
		},
	},
	"sleep": {
		"name": "睡觉", "frames": 8, "fps": 4, "overlay": false, "kind": "loop",
		"hint": "缓慢呼吸、头部低垂",
		"roles": {
			"body": [[0, 0, 2, 0], [4, 0, 3, 0]],
			"head": [[0, 0, 3, 6], [4, 0, 4, 8]],
			"ear_l": [[0, 0, 1, 12], [4, 0, 1, 14]],
			"ear_r": [[0, 0, 1, -12], [4, 0, 1, -14]],
			"tail": [[0, 0, 2, 20], [4, 0, 2, 24]],
		},
	},
	"tail_wag": {
		"name": "摇尾巴", "frames": 8, "fps": 10, "overlay": true, "kind": "loop",
		"hint": "只影响尾巴的叠加动作",
		"roles": {
			"tail": [[0, 0, 0, -28], [2, 0, 0, 0], [4, 0, 0, 28], [6, 0, 0, 0]],
		},
	},
}


static func names() -> Array:
	return LIBRARY.keys()


static func describe(preset: String) -> Dictionary:
	return LIBRARY.get(preset, {})


## 把预设展开成可写进角色的动作（关键帧仍按 role 记录，直到套用）。
const BIPED_OVERRIDES := {
	"walk": {
		"arm_l": [[0, 0, 0, -8], [2, 0, 0, 0], [4, 0, 0, 8], [6, 0, 0, 0]],
		"arm_r": [[0, 0, 0, -8], [2, 0, 0, 0], [4, 0, 0, 8], [6, 0, 0, 0]],
		"leg_l": [[0, -1, -2, -5], [2, 0, 0, 0], [4, 0, 0, 0], [6, 0, 0, 0]],
		"leg_r": [[0, 0, 0, 0], [2, 0, 0, 0], [4, 1, -2, 5], [6, 0, 0, 0]],
	},
	"run": {
		"body": [[0, 0, 0, -2], [1, 0, -3, 0], [2, 0, 0, 2], [3, 0, 0, 2], [4, 0, -3, 0], [5, 0, 0, -2]],
		"arm_l": [[0, 0, 0, -16], [1, 0, 0, 0], [2, 0, 0, 16], [3, 0, 0, 16], [4, 0, 0, 0], [5, 0, 0, -16]],
		"arm_r": [[0, 0, 0, -16], [1, 0, 0, 0], [2, 0, 0, 16], [3, 0, 0, 16], [4, 0, 0, 0], [5, 0, 0, -16]],
		"leg_l": [[0, -1, -4, -10], [1, 0, 0, 0], [2, 0, 0, 0], [3, 0, 0, 0], [4, 0, 0, 0], [5, -1, -2, -6]],
		"leg_r": [[0, 0, 0, 0], [1, 0, 0, 0], [2, 1, -4, 10], [3, 1, -2, 6], [4, 0, 0, 0], [5, 0, 0, 0]],
	},
	"wave": {
		"arm_r": [[0, 0, 0, -100], [2, 0, 0, -120], [4, 0, 0, -100], [6, 0, 0, -118]],
	},
	"jump": {
		"arm_l": [[0, 0, 0, -8], [1, 0, 0, -12], [3, 0, 0, 125], [5, 0, 0, 105], [7, 0, 0, -8]],
		"arm_r": [[0, 0, 0, 8], [1, 0, 0, 12], [3, 0, 0, -125], [5, 0, 0, -105], [7, 0, 0, 8]],
	},
}

static func build(preset: String, rig: String = "") -> Dictionary:
	var spec: Dictionary = LIBRARY.get(preset, {}).duplicate(true)
	if spec.is_empty():
		return {}
	if rig == Rig.BIPED and BIPED_OVERRIDES.has(preset):
		for role in BIPED_OVERRIDES[preset]:
			spec.roles[role] = BIPED_OVERRIDES[preset][role]
	if Rig.exists(rig):
		for role in spec.roles.keys():
			if not role in Rig.roles(rig): spec.roles.erase(role)
	var clip := Character.action(preset, str(spec.name), int(spec.frames))
	clip.fps = float(spec.fps)
	clip.overlay = bool(spec.overlay)
	clip.loop = str(spec.get("kind", "loop")) == "loop"
	clip.preset = preset
	for role in spec.roles:
		var keys := []
		for row in spec.roles[role]:
			keys.append({"frame": int(row[0]), "position": [float(row[1]), float(row[2])], "rotation": float(row[3])})
		clip.tracks["role:" + str(role)] = keys
	return clip


## 把一份按 role 记录的动作套到具体角色上；返回新的角色动作字典。
## missing 收集角色缺少的 role，便于界面提示"该动作有 2 个部位未匹配"。
static func apply(clip: Dictionary, model: Dictionary, names_by_role: Dictionary = {}) -> Dictionary:
	var result := clip.duplicate(true)
	var tracks := {}
	var roles := Rig.role_map(model)
	var motion_scale := float(model.get("modules", {}).get("rigpop.rig", {}).get("motion_scale", 1.0))
	var missing: Array[String] = []
	for key in clip.get("tracks", {}):
		var role := str(key)
		if role.begins_with("role:"):
			role = role.substr(5)
		if roles.has(role):
			tracks[roles[role]] = clip.tracks[key].duplicate(true)
			for sample in tracks[roles[role]]:
				if sample.has("position"):
					sample.position = [sample.position[0] * motion_scale, sample.position[1] * motion_scale]
		else:
			missing.append(role)
	result.tracks = tracks
	if names_by_role.has("clip"):
		result.name = names_by_role.clip
	if not missing.is_empty():
		result.missing_roles = missing
	return result


## 把角色现有动作导出成按 role 记录的预设（用于"存为模板动作"）。
static func extract(clip: Dictionary, model: Dictionary) -> Dictionary:
	var role_of := {}
	for role in Rig.role_map(model):
		role_of[Rig.role_map(model)[role]] = role
	var by_role := {}
	for part_id in clip.get("tracks", {}):
		var role := str(part_id)
		role = role_of.get(part_id, role)
		var keys := []
		for key in clip.tracks[part_id]:
			var row := {"frame": int(key.frame)}
			if key.has("position"):
				row.position = key.position.duplicate()
			if key.has("rotation"):
				row.rotation = float(key.rotation)
			for extra in ["asset", "visible"]:
				if key.has(extra):
					row[extra] = key[extra]
			keys.append(row)
		by_role["role:" + str(role)] = keys
	var result := clip.duplicate(true)
	result.tracks = by_role
	result.rig = Rig.detect(model)
	var motion_scale := float(model.get("modules", {}).get("rigpop.rig", {}).get("motion_scale", 1.0))
	for keys in by_role.values():
		for row in keys:
			if row.has("position"):
				row.position = [row.position[0] / maxf(0.001, motion_scale), row.position[1] / maxf(0.001, motion_scale)]
	return result


## 某个 rig 有哪些预设动作可用。
static func for_rig(rig: String) -> Array:
	var allowed := {}
	for role in Rig.roles(rig):
		for preset in LIBRARY:
			if LIBRARY[preset].roles.has(role):
				allowed[preset] = true
	var result := []
	for preset in LIBRARY:
		if allowed.has(preset):
			result.append(preset)
	return result
