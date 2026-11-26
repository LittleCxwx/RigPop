extends RefCounted

const Character = preload("res://core/character.gd")
const Rig = preload("res://core/rig.gd")
const Presets = preload("res://core/presets.gd")

static func save_clip(clip: Dictionary, model: Dictionary, directory: String) -> String:
	if clip.get("tracks", {}).is_empty(): return "当前动作没有关键帧"
	var mapped := Rig.role_map(model).values()
	for id in clip.get("tracks", {}):
		if id not in mapped: return "动作包含未匹配骨骼的部件，请先指定部位"
	for keys in clip.get("tracks", {}).values():
		for key in keys:
			if key.has("asset"): return "动作包含逐帧图片，请先复制角色工程；骨骼预设仅保存变换与可见性"
	if DirAccess.make_dir_recursive_absolute(directory) != OK: return "无法创建预设目录"
	var exported := Presets.extract(clip, model)
	exported.id = Character.uid("preset")
	var path := directory.path_join(str(exported.id) + ".json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return "无法写入预设目录"
	file.store_string(JSON.stringify(exported, "\t"))
	file.close()
	return ""

static func load_clips(directory: String, model: Dictionary) -> Array:
	var result := []
	if not DirAccess.dir_exists_absolute(directory): return result
	for filename in DirAccess.get_files_at(directory):
		if not filename.ends_with(".json"): continue
		var source := FileAccess.open(directory.path_join(filename), FileAccess.READ)
		if source == null or source.get_length() > 1024 * 1024: continue
		var parsed: Variant = JSON.parse_string(source.get_as_text())
		if not parsed is Dictionary or parsed.get("rig", "") != Rig.detect(model): continue
		if not parsed.get("tracks") is Dictionary: continue
		var usable := true
		for keys in parsed.tracks.values():
			if not keys is Array:
				usable = false
				break
			for key in keys:
				if not key is Dictionary or key.has("asset") or (key.has("position") and not Character.valid_vector(key.position)):
					usable = false
		if not usable: continue
		var applied := Presets.apply(parsed, model)
		var probe := model.duplicate(true)
		probe.actions = [applied]
		probe.bindings = []
		if not applied.tracks.is_empty() and Character.validate(probe).is_empty(): result.append(applied)
	return result
