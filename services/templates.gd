extends RefCounted

## 内置模板：Kiki 兽人立绘、蓝衣冒险家、灵犀与基础结构。
##
## 灵犀的美术由 `tools/art/make_cat.py` 生成，部件与骨骼锚点写在
## `assets/templates/lingxi/` 里；打开模板后再套用预设动作库，
## 得到一套可直接改图、微调姿势的角色。

const Character = preload("res://core/character.gd")
const Store = preload("res://services/project_store.gd")
const Presets = preload("res://core/presets.gd")
const Rig = preload("res://core/rig.gd")
const OcTemplate = preload("res://services/oc_template.gd")

const LINGXI_TEMPLATE := "res://assets/templates/lingxi/character.rigpop.json"
const ADVENTURER_TEMPLATE := "res://assets/templates/adventurer/character.rigpop.json"
const KIKI_TEMPLATE := "res://assets/templates/kiki/character.rigpop.json"

## 灵犀模板默认带上的动作，顺序即时间轴顺序。
const LINGXI_ACTIONS := ["idle", "walk", "run", "wave", "nod", "jump", "sit", "sleep", "tail_wag"]

const PALETTE := {".": "00000000", "o": "263642", "w": "eff4ed", "s": "a5b7bd", "m": "8ecfbe", "g": "4a9f91", "d": "316d6e", "p": "f18b80", "y": "e8bd78"}

static func sprite(rows: Array) -> Image:
	var width := 1
	for row in rows: width = maxi(width, str(row).length())
	var img := Image.create(width, rows.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for y in rows.size():
		for x in str(rows[y]).length():
			img.set_pixel(x, y, Color(str(PALETTE.get(str(rows[y])[x], "00000000"))))
	return img

static func make(kind: String = "kiki") -> RefCounted:
	if kind == "oc":
		return OcTemplate.make()
	if kind == "kiki":
		var kiki := Store.new()
		var error: String = kiki.open_file(KIKI_TEMPLATE)
		if not error.is_empty():
			push_error(error)
			return make_biped()
		kiki.model.id = Character.uid("character")
		kiki.path = ""
		return kiki
	if kind == "adventurer":
		return make_adventurer()
	if kind == "lingxi":
		return make_lingxi()
	if kind == "traveler": return make_biped()
	if kind == "empty":
		var empty := Store.new()
		empty.model = Character.empty("未命名角色")
		empty.model.actions = [Character.action("idle", "待机")]
		return empty
	var doc := Store.new()
	doc.model = Character.empty("果冻团子")
	var m: Dictionary = doc.model
	m.rig = ""
	var source := (load("res://assets/slime.png") as Texture2D).get_image().get_region(Rect2i(0, 0, 64, 64))
	var face := source.get_region(Rect2i(23, 37, 17, 15))
	source.fill_rect(Rect2i(23, 37, 17, 15), Color.TRANSPARENT)
	m.parts = [Character.part("body", "胶质身体", "", [0, 0], [32, 52], 0), Character.part("face", "表情", "body", [-9, -15], [0, 0], 1)]
	m.parts[0].role = "body"
	m.parts[1].role = "face"
	doc.images = {"assets/body.png": source, "assets/face.png": face}
	var idle := Character.action("idle", "待机", 8)
	var wave := Character.action("wave", "招手", 8)
	wave.overlay = true
	for f in [0, 2, 4, 6]:
		Character.set_key(idle, "body", f, {"position": [0, [0, -1, 0, 0][f / 2]], "rotation": 0})
		Character.set_key(wave, "body", f, {"position": [[0, -3, 3, 0][f / 2], -4], "rotation": [-8, 0, 8, 0][f / 2]})
	m.actions = [idle, wave]
	doc.refresh_textures()
	return doc

static func make_adventurer() -> RefCounted:
	var doc := Store.new()
	var error: String = doc.open_file(ADVENTURER_TEMPLATE)
	if not error.is_empty():
		push_error(error)
		return make_biped()
	doc.model.id = Character.uid("character")
	doc.model.actions = []
	for preset in ["idle", "walk", "run", "wave", "nod", "jump"]:
		var clip := apply_preset(doc.model, preset)
		if not clip.is_empty(): doc.model.actions.append(clip)
	for expression in ["focus", "surprised"]:
		var asset := "assets/head_%s.png" % expression
		var source := ADVENTURER_TEMPLATE.get_base_dir().path_join(asset)
		doc.images[asset] = (load(source) as Texture2D).get_image()
		var clip := Character.action(expression, "专注" if expression == "focus" else "惊讶", 12)
		clip.overlay = true
		clip.loop = false
		Character.set_key(clip, "head", 0, {"asset": asset})
		Character.set_key(clip, "head", 10, {"asset": "assets/head.png"})
		doc.model.actions.append(clip)
	doc.path = ""
	doc.refresh_textures()
	return doc

## 灵犀模板：读取生成好的部件，套上预设动作。
static func make_lingxi() -> RefCounted:
	var doc := Store.new()
	var error: String = doc.open_file(LINGXI_TEMPLATE)
	if not error.is_empty():
		# 模板丢失时退回空白角色，避免编辑器打不开。
		doc = Store.new()
		doc.model = Character.empty("灵犀")
		return doc
	doc.model.id = Character.uid("character")
	doc.model.name = "灵犀"
	doc.model.rig = Rig.detect(doc.model)
	Rig.assign_roles(doc.model)
	doc.model.actions = []
	for preset in LINGXI_ACTIONS:
		var clip := apply_preset(doc.model, preset)
		if not clip.is_empty():
			doc.model.actions.append(clip)
	if doc.model.actions.is_empty():
		doc.model.actions = [Character.action("idle", "待机", 8)]
	doc.model.bindings = [
		{"key": "A", "gesture": "hold", "command": "move_left"},
		{"key": "D", "gesture": "hold", "command": "move_right"},
		{"key": "W", "gesture": "hold", "command": "move_up"},
		{"key": "S", "gesture": "hold", "command": "move_down"},
		{"key": "Space", "gesture": "tap", "command": "wave"},
	]
	doc.path = ""
	doc.refresh_textures()
	return doc

## 按当前骨骼套一个预设动作，返回可直接加入 model.actions 的动作。
static func apply_preset(model: Dictionary, preset: String) -> Dictionary:
	var template := Presets.build(preset, Rig.detect(model))
	if template.is_empty():
		return {}
	var clip := Presets.apply(template, model)
	if clip.tracks.is_empty():
		return {}
	clip.name = str(template.get("name", preset))
	return clip

## Retain the compact humanoid as an additional editable rig example.
static func make_biped() -> RefCounted:
	var doc := Store.new()
	doc.model = Character.empty("人形基础")
	var m: Dictionary = doc.model
	m.rig = Rig.BIPED
	m.parts = [Character.part("body", "外套", "", [0, -12], [7, 10], 0),
		Character.part("head", "头部", "body", [0, -11], [9, 12], 3),
		Character.part("arm_l", "左手", "body", [-7, -7], [3, 2], -1),
		Character.part("arm_r", "右手", "body", [7, -7], [2, 2], 4),
		Character.part("leg_l", "左靴", "body", [-4, 0], [3, 0], -1),
		Character.part("leg_r", "右靴", "body", [4, 0], [3, 0], 1),
		Character.part("scarf", "围巾", "body", [1, -10], [4, 1], 5)]
	for part in m.parts: part.role = part.id
	doc.images["assets/head.png"] = sprite(["......oooooo......", "....oommmmmmoo....", "...ommmmmmmmmo....", "..ommmmmmmmmmmo...", "..ommmmmmmmmmmmo..", ".ommmmmmmmmmmmmo..", ".omggggggggggggo..", ".ooowwwwwwwwwooo..", "..owwowwwwowwo....", "..owwowwwwowwo....", "..owwwwppwwwwo....", "...owwwwwwwwo.....", "....oowwwwoo......", "......oooo........"])
	doc.images["assets/body.png"] = sprite(["...oooooooo...", "..ommmwwmmmo..", ".ommmmwwmmmmo.", ".ommmmwwmmmmo.", ".ogmmmwwmmmgo.", ".ogmmmwwmmmgo.", ".ogmmmwwmmmgo.", ".ogggmwwmgggo.", "..ogggwwgggo..", "..oggggggggo..", "...oooooooo..."])
	var arm := sprite(["..ooo..", ".ommmo.", ".ommmo.", ".ogggo.", ".ogggo.", ".owwwo.", ".owwwo.", "..ooo.."])
	doc.images["assets/arm_l.png"] = arm
	doc.images["assets/arm_r.png"] = arm.duplicate()
	var boot := sprite([".ooooo..", ".ossso..", ".ossso..", ".ossso..", ".oddddo..", "odddddo.", "oddddddo", "oooooooo"])
	doc.images["assets/leg_l.png"] = boot
	doc.images["assets/leg_r.png"] = boot.duplicate()
	doc.images["assets/scarf.png"] = sprite(["oooooooooo", "oppppppppo", ".ooppppoo.", "...oppo...", "...opppo..", "....oppo..", "....oyyo..", ".....oo..."])
	var idle := Character.action("idle", "待机", 8)
	var walk := Character.action("walk", "行走", 8)
	var wave := Character.action("wave", "招手", 8)
	wave.overlay = true
	for f in [0, 2, 4, 6]:
		Character.set_key(idle, "body", f, {"position": [0, [0, -1, 0, 0][f / 2]], "rotation": 0})
		Character.set_key(walk, "body", f, {"position": [0, [0, -2, 0, -2][f / 2]], "rotation": 0})
		for id in ["leg_l", "leg_r"]:
			Character.set_key(walk, id, f, {"position": [0, 0], "rotation": [22, 0, -22, 0][f / 2] * (1 if id == "leg_l" else -1)})
		for id in ["arm_l", "arm_r"]:
			Character.set_key(walk, id, f, {"position": [0, 0], "rotation": [-25, 0, 25, 0][f / 2] * (1 if id == "arm_l" else -1)})
		Character.set_key(wave, "arm_r", f, {"position": [0, 0], "rotation": [-125, -155, -125, -145][f / 2]})
	m.actions = [idle, walk, wave]
	doc.refresh_textures()
	return doc
