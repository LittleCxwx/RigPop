extends RefCounted

const Character = preload("res://core/character.gd")

var model: Dictionary = {}
var images: Dictionary = {}
var textures: Dictionary = {}
var path := ""
var saved_fingerprint := ""

func snapshot() -> Dictionary:
	var art := {}
	for key in images:
		art[key] = images[key].save_png_to_buffer()
	return {"model": model.duplicate(true), "art": art}

func restore(state: Dictionary) -> void:
	model = state.model.duplicate(true)
	images.clear()
	for key in state.art:
		var img := Image.new()
		img.load_png_from_buffer(state.art[key])
		images[key] = img
	refresh_textures()

func refresh_textures() -> void:
	textures.clear()
	for key in images:
		textures[key] = ImageTexture.create_from_image(images[key])

func fingerprint() -> String:
	var parts := JSON.stringify(model)
	for key in images:
		parts += str(key) + str(hash(images[key].get_data()))
	return parts.sha256_text()

func dirty() -> bool:
	return fingerprint() != saved_fingerprint

func save_to(directory: String) -> String:
	var errors := Character.validate(model)
	if not errors.is_empty():
		return "\n".join(errors)
	var target := directory.path_join("character.rigpop.json")
	if FileAccess.file_exists(target):
		var existing = JSON.parse_string(FileAccess.get_file_as_string(target))
		if not existing is Dictionary or str(existing.get("id", "")) != str(model.id):
			return "此目录包含其他角色或损坏工程，请选择空目录"
	var asset_dir := directory.path_join("assets")
	if DirAccess.make_dir_recursive_absolute(asset_dir) != OK:
		return "无法创建目录：" + directory
	# Content-addressed files make the JSON rename the transaction commit point.
	var disk_model := model.duplicate(true)
	var mapping := {}
	var required := {}
	for p in model.parts: required[p.asset] = true
	for clip in model.actions:
		for keys in clip.tracks.values():
			for key in keys:
				if key.has("asset"): required[key.asset] = true
	for key in required:
		if not images.has(key): return "缺少素材：" + str(key)
	for key in images:
		if not required.has(key): continue
		var bytes: PackedByteArray = images[key].save_png_to_buffer()
		var relative := "assets/%s_%s.png" % [str(key).sha256_text().left(8), bytes.hex_encode().sha256_text().left(20)]
		var f := FileAccess.open(directory.path_join(relative), FileAccess.WRITE)
		if f == null:
			return "素材写入失败：" + relative
		f.store_buffer(bytes)
		f.close()
		mapping[key] = relative
	for p in disk_model.parts:
		if mapping.has(p.asset):
			p.asset = mapping[p.asset]
	for clip in disk_model.actions:
		for keys in clip.tracks.values():
			for key in keys:
				if key.has("asset") and mapping.has(key.asset):
					key.asset = mapping[key.asset]
	var file := FileAccess.open(target + ".tmp", FileAccess.WRITE)
	if file == null:
		return "目录不可写：" + directory
	file.store_string(JSON.stringify(disk_model, "\t"))
	file.close()
	if FileAccess.file_exists(target):
		if DirAccess.copy_absolute(target, target + ".bak") != OK:
			return "无法建立恢复备份"
	if DirAccess.rename_absolute(target + ".tmp", target) != OK:
		return "无法完成工程写入，原数据与备份仍保留"
	path = directory
	saved_fingerprint = fingerprint()
	return ""

func open_file(file_path: String) -> String:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(file_path)) != OK:
		return "工程 JSON 无法解析：" + parser.get_error_message()
	if not parser.data is Dictionary:
		return "工程根节点必须为对象"
	var errors := Character.validate(parser.data)
	if not errors.is_empty():
		return "\n".join(errors)
	var next_images := {}
	var assets: Array = []
	for p in parser.data.parts:
		assets.append(p.asset)
	for clip in parser.data.actions:
		for keys in clip.tracks.values():
			for key in keys:
				if key.has("asset"):
					assets.append(key.asset)
	for relative in assets:
		if not Character.safe_path(str(relative)):
			return "素材路径越界"
		var source_path: String = file_path.get_base_dir().path_join(relative)
		var img: Image
		if source_path.begins_with("res://") and ResourceLoader.exists(source_path, "Texture2D"):
			img = (load(source_path) as Texture2D).get_image()
		else:
			img = Image.load_from_file(source_path)
		if img == null or img.is_empty():
			return "素材缺失：" + str(relative)
		if img.get_width() > 4096 or img.get_height() > 4096:
			return "素材超过 4096 像素上限"
		img.convert(Image.FORMAT_RGBA8)
		next_images[relative] = img
	model = parser.data
	images = next_images
	path = file_path.get_base_dir()
	refresh_textures()
	saved_fingerprint = fingerprint()
	return ""
