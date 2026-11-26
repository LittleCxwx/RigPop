extends RefCounted

## The shipped psd-tools process owns decoding; the editor only consumes PNG/JSON.
var width := 0
var height := 0
var layers: Array[Dictionary] = []
var warnings: PackedStringArray = []

func load_file(path: String) -> String:
	layers.clear()
	warnings.clear()
	var root := ProjectSettings.globalize_path("res://build") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()
	var helper := root.path_join("helpers/psd/RigPopPsd/RigPopPsd.exe")
	if not FileAccess.file_exists(helper):
		return "缺少 PSD 导入组件，请运行 tools/build_psd_helper.ps1 或使用完整便携包"
	if not FileAccess.file_exists(path): return "PSD 文件不存在"
	var cache := OS.get_cache_dir().path_join("RigPop/psd_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	if DirAccess.make_dir_recursive_absolute(cache) != OK: return "无法创建 PSD 临时目录"
	var output: Array = []
	var code := OS.execute(helper, PackedStringArray([path, cache]), output, true, false)
	var result: Variant = JSON.parse_string(FileAccess.get_file_as_string(cache.path_join("manifest.json"))) if FileAccess.file_exists(cache.path_join("manifest.json")) else null
	var error := "PSD 导入组件运行失败（%d）" % code
	if result is Dictionary and result.get("version") == 1:
		error = str(result.get("error", ""))
		if code != 0 and error.is_empty(): error = "PSD 导入组件异常退出"
		if error.is_empty():
			width = int(result.width)
			height = int(result.height)
			warnings = PackedStringArray(result.get("warnings", []))
			for entry in result.get("layers", []):
				var filename := str(entry.get("image", ""))
				if filename != filename.get_file() or not filename.ends_with(".png"):
					error = "PSD 导入组件返回了无效的图片路径"
					break
				var image := Image.load_from_file(cache.path_join(filename))
				if image == null:
					error = "PSD 图层图片无法读取"
					break
				entry.image = image
				entry.position = Vector2i(int(entry.position[0]), int(entry.position[1]))
				entry.size = image.get_size()
				layers.append(entry)
	# Only remove files in the unique directory created by this invocation.
	for filename in DirAccess.get_files_at(cache):
		DirAccess.remove_absolute(cache.path_join(filename))
	DirAccess.remove_absolute(cache)
	if not error.is_empty(): layers.clear()
	return error
