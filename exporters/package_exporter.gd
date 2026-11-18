extends RefCounted

const Character = preload("res://core/character.gd")
const Store = preload("res://services/project_store.gd")
const SOURCE_FILES := ["core/character.gd", "core/input_router.gd", "core/action_player.gd", "services/project_store.gd", "runtime/shared/character_view.gd", "runtime/game/controller.gd", "runtime/game/character.tscn", "runtime/game/world.gd", "runtime/game/world.tscn"]

static func write(path: String, text: String) -> String:
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK: return "无法创建导出目录"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return "无法写入：" + path
	file.store_string(text)
	return ""

static func export_package(doc: RefCounted, directory: String, target: String) -> Dictionary:
	var errors := Character.validate(doc.model)
	if not errors.is_empty(): return {"error": "\n".join(errors), "path": ""}
	var basename := "RigPop_%s_%s_%d" % [doc.model.id, {"Godot": "godot", "桌宠": "pet", "工程": "project"}.get(target, "project"), Time.get_unix_time_from_system()]
	var output := directory.path_join(basename)
	if DirAccess.dir_exists_absolute(output): return {"error": "目标已存在，请稍后再导出", "path": output}
	var staging := output + ".staging"
	var copy := Store.new()
	copy.restore(doc.snapshot())
	var data_relative: String = "characters/" + str(doc.model.id) if target == "Godot" else "character"
	var character_relative := data_relative + "/character.rigpop.json"
	var error: String = copy.save_to(staging.path_join(data_relative))
	if not error.is_empty(): return {"error": error, "path": staging}
	if target == "Godot":
		for path in SOURCE_FILES:
			# Plain-text templates are shipped alongside the compiled editor runtime.
			var source_path: String = "res://exporters/templates/" + path + ".txt"
			var source := FileAccess.get_file_as_string(source_path)
			if source.is_empty(): return {"error": "导出源模板缺失：" + path, "path": staging}
			source = source.replace("res://core/", "res://addons/rigpop_runtime/core/").replace("res://services/", "res://addons/rigpop_runtime/services/").replace("res://runtime/", "res://addons/rigpop_runtime/runtime/")
			error = write(staging.path_join("addons/rigpop_runtime/" + path), source)
			if not error.is_empty(): return {"error": error, "path": staging}
		error = write(staging.path_join(data_relative + "/character.tscn"), '[gd_scene load_steps=3 format=3]\n[ext_resource type="Script" path="res://addons/rigpop_runtime/runtime/game/controller.gd" id="1"]\n[sub_resource type="CircleShape2D" id="shape"]\nradius = %s\n[node name="RigPopCharacter" type="CharacterBody2D"]\nscript = ExtResource("1")\ncharacter_file = "res://%s"\n[node name="Collision" type="CollisionShape2D" parent="."]\nshape = SubResource("shape")\n' % [doc.model.game.collision_radius, character_relative])
		if not error.is_empty(): return {"error": error, "path": staging}
		# The generated preview extends the scene script without replacing user scenes later.
		error = write(staging.path_join("preview.gd"), 'extends "res://addons/rigpop_runtime/runtime/game/world.gd"\nfunc _ready() -> void:\n\t$Character.load_character("res://%s")\n\tenabled = true\n' % character_relative)
		if not error.is_empty(): return {"error": error, "path": staging}
		error = write(staging.path_join("preview.tscn"), '[gd_scene load_steps=3 format=3]\n[ext_resource type="PackedScene" path="res://addons/rigpop_runtime/runtime/game/world.tscn" id="1"]\n[ext_resource type="Script" path="res://preview.gd" id="2"]\n[node name="Preview" instance=ExtResource("1")]\nscript = ExtResource("2")\n')
		if not error.is_empty(): return {"error": error, "path": staging}
		error = write(staging.path_join("project.godot"), 'config_version=5\n[application]\nconfig/name="RigPop Character Preview"\nrun/main_scene="res://preview.tscn"\n[display]\nwindow/size/viewport_width=960\nwindow/size/viewport_height=640\n[rendering]\nrenderer/rendering_method="gl_compatibility"\ntextures/canvas_textures/default_texture_filter=0\n')
		if not error.is_empty(): return {"error": error, "path": staging}
	elif target == "桌宠":
		var host_root := OS.get_executable_path().get_base_dir().path_join("hosts") if not OS.has_feature("editor") else ProjectSettings.globalize_path("res://build/hosts")
		for filename in ["RigPopPet.exe", "RigPopPet.pck"]:
			if not FileAccess.file_exists(host_root.path_join(filename)):
				return {"error": "缺少预构建桌宠宿主 " + filename + "。请先执行 tools/build.ps1。工程仍完整保留。", "path": staging}
			if DirAccess.copy_absolute(host_root.path_join(filename), staging.path_join(filename)) != OK:
				return {"error": "桌宠宿主复制失败", "path": staging}
	var manifest := {"package_format_version": 1, "runtime_api_version": 1, "application_version": "0.1.0", "godot_version": "4.7.2", "id": doc.model.id,
		"name": doc.model.name, "target": target, "character": character_relative, "actions": doc.model.actions,
		"entry_scene": data_relative + "/character.tscn" if target == "Godot" else "", "entry_executable": "RigPopPet.exe" if target == "桌宠" else "",
		"commands": ["move_left", "move_right", "move_up", "move_down"],
		"coordinates": {"unit": "pixel", "origin": "feet", "positive_y": "down"},
		"limitations": ["No global hotkeys", "No combat ability handlers", "No PSD parser", "No secondary motion solver"],
		"required_modules": ["rigpop.shared.v1"], "runtime_sources": SOURCE_FILES if target == "Godot" else []}
	error = write(staging.path_join("manifest.json"), JSON.stringify(manifest, "\t"))
	if not error.is_empty(): return {"error": error, "path": staging}
	var readme := "# " + str(doc.model.name) + "\n\nRigPop 0.1.0 / runtime API 1 / Godot 4.7.2\n\n"
	if target == "Godot":
		readme += "打开 project.godot 运行试演。manifest.json 的 entry_scene 是可实例化入口。\n\n合入现有项目时，只需复制 addons/rigpop_runtime/ 与 characters/ 至目标根目录，保持相对结构。共用运行目录只安装一次；重复导入前检查 manifest 中的 API 版本。将 characters/<角色ID>/character.tscn 拖入地图，地图摆放与角色创作数据独立。根目录 preview.* 与 project.godot 只供独立演示，不需要复制或覆盖用户场景。\n\n运行节点提供 configure(model, textures)、load_character(path)、execute(action_id)、clear_input()。移动由键鼠绑定执行，叠加动作只覆盖其定义的部件轨道。可用动作见 manifest.json。\n"
	elif target == "桌宠":
		readme += "双击 RigPopPet.exe，需保留同目录 RigPopPet.pck 与 character/。左键拖动移动；右键点按松开打开漫游、置顶与退出菜单，右键向上拖动放大、向下拖动缩小（1～8 倍整数像素）。桌宠右键不触发动作绑定，游戏中仍可使用右键绑定。窗口获得焦点时 Escape 退出。透明区域按角色轮廓的凸包穿透；不提供整窗穿透与全局热键。\n"
	else:
		readme += "在 RigPop 中打开 character/character.rigpop.json。PNG 与 JSON 必须一同搬移。\n"
	error = write(staging.path_join("README.md"), readme)
	if not error.is_empty(): return {"error": error, "path": staging}
	var check := Store.new()
	if target in ["桌宠", "Godot"]:
		for filename in ["Godot-MIT.txt", "Godot-COPYRIGHT.txt", "Noto-OFL.txt", "Lucide.txt"]:
			var license_text := FileAccess.get_file_as_string("res://licenses/" + filename)
			if not license_text.is_empty():
				error = write(staging.path_join("licenses/" + filename), license_text)
				if not error.is_empty(): return {"error": error, "path": staging}
	error = check.open_file(staging.path_join(character_relative))
	if not error.is_empty(): return {"error": "导出回读失败：" + error, "path": staging}
	var publish_error := DirAccess.rename_absolute(staging, output)
	# Windows scanners can briefly keep a newly copied executable open.
	for attempt in 10:
		if publish_error == OK: break
		OS.delay_msec(50)
		publish_error = DirAccess.rename_absolute(staging, output)
	if publish_error != OK: return {"error": "发布目录重命名失败（%d），暂存数据仍保留：%s" % [publish_error, staging], "path": staging}
	return {"error": "", "path": output}
