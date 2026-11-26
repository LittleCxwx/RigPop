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
	var error: String = copy.save_to(staging.path_join(data_relative), target == "工程")
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
		for filename in ["RigPopPet.exe", "RigPopPet.pck", "rigpop_windows.dll", "platform/windows/bin/rigpop_windows.dll"]:
			if not FileAccess.file_exists(host_root.path_join(filename)):
				return {"error": "缺少预构建桌宠宿主 " + filename + "。请先执行 tools/build.ps1。工程仍完整保留。", "path": staging}
			if DirAccess.make_dir_recursive_absolute(staging.path_join(filename).get_base_dir()) != OK:
				return {"error": "桌宠宿主目录创建失败", "path": staging}
			if DirAccess.copy_absolute(host_root.path_join(filename), staging.path_join(filename)) != OK:
				return {"error": "桌宠宿主复制失败", "path": staging}
	var application_version := str(ProjectSettings.get_setting("application/config/version"))
	var manifest := {"package_format_version": 1, "runtime_api_version": 1, "application_version": application_version, "godot_version": "4.7.2", "id": doc.model.id,
		"name": doc.model.name, "target": target, "character": character_relative, "actions": doc.model.actions,
		"entry_scene": data_relative + "/character.tscn" if target == "Godot" else "", "entry_executable": "RigPopPet.exe" if target == "桌宠" else "",
		"commands": ["move_left", "move_right", "move_up", "move_down"],
		"coordinates": {"unit": "pixel", "origin": "feet", "positive_y": "down"},
		"limitations": ["No combat ability handlers", "No PSD parser", "No secondary motion solver"],
		"required_modules": ["rigpop.shared.v1"], "runtime_sources": SOURCE_FILES if target == "Godot" else []}
	error = write(staging.path_join("manifest.json"), JSON.stringify(manifest, "\t"))
	if not error.is_empty(): return {"error": error, "path": staging}
	var readme := "# " + str(doc.model.name) + "\n\nRigPop %s / runtime API 1 / Godot 4.7.2\n\n" % application_version
	if target == "Godot":
		readme += "打开 project.godot 运行试演。manifest.json 的 entry_scene 是可实例化入口。\n\n合入现有项目时，只需复制 addons/rigpop_runtime/ 与 characters/ 至目标根目录，保持相对结构。共用运行目录只安装一次；重复导入前检查 manifest 中的 API 版本。将 characters/<角色ID>/character.tscn 拖入地图，地图摆放与角色创作数据独立。根目录 preview.* 与 project.godot 只供独立演示，不需要复制或覆盖用户场景。\n\n运行节点提供 configure(model, textures)、load_character(path)、execute(action_id)、clear_input()。移动由键鼠绑定执行，叠加动作只覆盖其定义的部件轨道。可用动作见 manifest.json。\n"
	elif target == "桌宠":
		readme += "双击 RigPopPet.exe，需保留同目录 RigPopPet.pck、rigpop_windows.dll、platform/ 与 character/。桌宠不占 Windows 主任务栏按钮。\n\n- 桌宠模式：按住 WASD 约 0.2 秒移动角色，短按可以正常打字。前台应用照常接收按键。左键拖动，右键点按开菜单，按住右键上下拖动调整 1～8 倍倍率。\n- 聚焦模式：桌宠获得键盘焦点，WASD 立即移动角色，按 Esc 返回桌宠模式。点回桌宠可重新获得焦点。\n- 固定模式：锁住角色位置和倍率，鼠标可穿过角色。点击屏幕左下角的紫色 R 猫头打开菜单，切换模式、隐藏或恢复桌宠。\n"
		readme += "\n一次性动作完整播放后恢复当前状态，期间的桌宠按键不会排队。持续状态在按下配置的切换键时切换。状态姿势、移动限制和专属动作可在 RigPop 编辑器的「桌宠试演 → 状态与动作」中设置。\n"
	else:
		readme += "在 RigPop 中打开 character/character.rigpop.json。PNG 与 JSON 必须一同搬移。\n"
	if doc.model.get("modules", {}).get("rigpop.art", {}).get("source", "") == "Kenney Toon Characters / Female adventurer":
		readme += "\n角色美术：Kenney Toon Characters / Female adventurer（CC0-1.0），https://kenney.nl/assets/toon-characters 。来源和授权见 licenses/Kenney-CC0.txt。\n"
		error = write(staging.path_join("licenses/Kenney-CC0.txt"), FileAccess.get_file_as_string("res://licenses/Kenney-CC0.txt"))
		if not error.is_empty(): return {"error": error, "path": staging}
	if doc.model.get("modules", {}).get("rigpop.art", {}).get("source", "") == "Tyson Tan / Chibi Kiki II":
		readme += "\n角色美术：Tyson Tan / Chibi Kiki II（Krita 吉祥物，CC BY-SA 4.0），https://krita.org/en/about/mascot/ 。本角色为完整立绘的位移、旋转动画，未拆分四肢骨骼。改编图片与角色动画数据继续按 CC BY-SA 4.0 授权，见 licenses/Kiki-Attribution.txt 与 CC-BY-SA-4.0.txt。\n"
		for filename in ["Kiki-Attribution.txt", "CC-BY-SA-4.0.txt"]:
			error = write(staging.path_join("licenses/" + filename), FileAccess.get_file_as_string("res://licenses/" + filename))
			if not error.is_empty(): return {"error": error, "path": staging}
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
