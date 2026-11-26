extends RefCounted

const Character = preload("res://core/character.gd")
const Store = preload("res://services/project_store.gd")
const Presets = preload("res://core/presets.gd")
const Rig = preload("res://core/rig.gd")
const DesktopStates = preload("res://core/desktop_states.gd")
const INK := "#303447"
const PAPER := "#f5f1ea"
const ORIGIN := Vector2i(50, 102)

# Each image is cropped independently around a shared canvas. The anchor stays
# at the corresponding joint when the image is redrawn or replaced in the editor.
static func make() -> RefCounted:
	var doc := Store.new()
	doc.model = Character.empty("三头身 OC 底模")
	var model: Dictionary = doc.model
	model.rig = Rig.BIPED
	model.desktop.scale = 2
	model.palette = ["303447", "f5f1ea", "d9d4e3", "f1b4a8", "9779ce", "655493", "b6cfc9", "e5b777"]
	model.modules["rigpop.art"] = {"texture_filter": "linear"}
	model.modules["rigpop.rig"] = {"motion_scale": 1.0}
	var anchors := {"": ORIGIN}
	add_layer(doc, anchors, "body", "", Vector2i(50, 63), Rect2i(37, 34, 26, 33), 4,
		path("M48 36H52L54 40Q61 41 61 46L57 60Q56 64 50 64Q44 64 43 60L39 46Q39 41 46 40Z", PAPER))
	add_layer(doc, anchors, "head", "body", Vector2i(50, 36), Rect2i(31, 3, 38, 37), 15,
		path("M33 21C33 10 40 5 50 5C60 5 67 10 67 21C67 31 60 37 50 37C40 37 33 31 33 21Z", PAPER))
	add_layer(doc, anchors, "face", "head", Vector2i(50, 23), Rect2i(36, 16, 28, 19), 16,
		'<path d="M42 21v3m16-3v3m-11 4q3 3 6 0" fill="none" stroke="%s" stroke-width="1.7" stroke-linecap="round"/>' % INK)
	for suffix in ["l", "r"]:
		var sign_x := -1 if suffix == "l" else 1
		var x := func(offset: int) -> int: return 50 + sign_x * offset
		var shoulder := Vector2i(x.call(10), 45)
		var elbow := Vector2i(x.call(16), 56)
		var wrist := Vector2i(x.call(20), 66)
		var hip := Vector2i(x.call(5), 61)
		var knee := Vector2i(x.call(7), 77)
		var ankle := Vector2i(x.call(9), 93)
		add_limb(doc, anchors, "arm_" + suffix, "body", shoulder, elbow, 2, 8)
		add_limb(doc, anchors, "forearm_" + suffix, "arm_" + suffix, elbow, wrist, 3, 7)
		add_layer(doc, anchors, "hand_" + suffix, "forearm_" + suffix, wrist,
			Rect2i(wrist - Vector2i(5, 3), Vector2i(10, 12)), 5,
			'<ellipse cx="%d" cy="69" rx="3.5" ry="4" fill="%s" stroke="%s" stroke-width="2"/>' % [wrist.x, PAPER, INK])
		add_limb(doc, anchors, "leg_" + suffix, "body", hip, knee, 2, 9)
		add_limb(doc, anchors, "shin_" + suffix, "leg_" + suffix, knee, ankle, 3, 8)
		add_layer(doc, anchors, "foot_" + suffix, "shin_" + suffix, ankle,
			Rect2i(ankle - Vector2i(9, 3), Vector2i(18, 12)), 5,
			'<ellipse cx="%d" cy="96" rx="5.5" ry="3.8" fill="%s" stroke="%s" stroke-width="2"/>' % [ankle.x + sign_x * 2, PAPER, INK])
	add_layer(doc, anchors, "tail", "body", Vector2i(55, 60), Rect2i(51, 40, 41, 34), 0,
		path("M55 59C66 71 79 62 78 48C78 43 85 43 86 48C91 68 69 81 54 65Z", "#ad90d8"), false)
	add_layer(doc, anchors, "shirt", "body", Vector2i(50, 54), Rect2i(35, 38, 30, 29), 6,
		path("M45 41Q50 47 55 41L62 45L62 50L57 51L56 63H44L43 51L38 50L38 45Z", "#9779ce") +
		'<path d="M50 47v15m3-9h2" stroke="#655493" stroke-width="1.2" stroke-linecap="round"/>', false)
	add_layer(doc, anchors, "hair", "head", Vector2i(50, 15), Rect2i(31, 1, 38, 26), 17,
		path("M33 19C33 8 41 3 51 3C62 3 68 10 66 22C63 21 58 17 56 13C53 17 47 20 42 21L43 16Q39 20 33 23Z", "#d9d4e3"), false)
	add_layer(doc, anchors, "scarf", "body", Vector2i(50, 41), Rect2i(38, 35, 27, 23), 12,
		path("M42 36Q50 41 58 36L60 41L57 44L62 52L58 55L52 45Q45 46 40 41Z", "#e5a494"), false)

	for preset in ["idle", "walk", "run", "wave", "jump", "tail_wag"]:
		var clip := Presets.apply(Presets.build(preset, Rig.BIPED), model)
		model.actions.append(clip)
	var wave := Character.find_action(model, "wave")
	for frame in [0, 2, 4, 6]:
		Character.set_key(wave, "forearm_r", frame, {"rotation": -28 if frame % 4 == 0 else -55})
	var jump := Character.find_action(model, "jump")
	for id in ["shin_l", "shin_r"]:
		Character.set_key(jump, id, 1, {"rotation": 12 if id == "shin_l" else -12})
		Character.set_key(jump, id, 3, {"rotation": -25 if id == "shin_l" else 25})
		Character.set_key(jump, id, 7, {"rotation": 0})
	var happy := Character.action("happy", "开心", 8)
	happy.loop = false
	happy.overlay = true
	var face: Dictionary = Character.find_part(model, "face")
	var happy_face := "assets/face_happy.png"
	doc.images[happy_face] = render(Rect2i(36, 16, 28, 19),
		'<path d="M40 24q2-4 4 0m12 0q2-4 4 0m-13 3h6q-3 6-6 0z" fill="none" stroke="%s" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>' % INK)
	Character.set_key(happy, face.id, 0, {"asset": happy_face})
	model.actions.append(happy)
	add_states(doc, jump)
	model.bindings.back().command = "jump"
	model.bindings.append({"key": "H", "gesture": "tap", "command": "happy"})
	doc.refresh_textures()
	return doc

static func add_states(doc: RefCounted, jump: Dictionary) -> void:
	var model: Dictionary = doc.model
	var angry := Character.action("angry", "生气", 8)
	angry.loop = false
	angry.overlay = true
	var art := "assets/face_angry.png"
	doc.images[art] = render(Rect2i(36, 16, 28, 19),
		'<path d="M40 20l4 2m16-2l-4 2m-13 1v2m14-2v2m-10 5q3-3 6 0" fill="none" stroke="%s" stroke-width="1.7" stroke-linecap="round"/>' % INK)
	Character.set_key(angry, "face", 0, {"asset": art})
	model.actions.append(angry)
	for info in [["jump_happy", "开心跳跃", -23, -16], ["jump_angry", "生气跳跃", -12, -6]]:
		var variant := jump.duplicate(true)
		variant.id = info[0]
		variant.name = info[1]
		Character.set_key(variant, "body", 3, {"position": [0, info[2]]})
		Character.set_key(variant, "body", 5, {"position": [0, info[3]]})
		model.actions.append(variant)
	var seated := Character.action("seated", "坐下姿势", 8)
	seated.loop = false
	Character.set_key(seated, "body", 0, {"position": [0, 18]})
	for side in ["l", "r"]:
		var sign_x := 1 if side == "l" else -1
		Character.set_key(seated, "leg_" + side, 0, {"rotation": 65 * sign_x})
		Character.set_key(seated, "shin_" + side, 0, {"rotation": -45 * sign_x})
		Character.set_key(seated, "foot_" + side, 0, {"rotation": -20 * sign_x})
	model.actions.append(seated)
	model.modules[DesktopStates.MODULE] = {"states": [
		DesktopStates.state("原始", "1"),
		DesktopStates.state("开心", "2", "happy", true, false, {"jump": "jump_happy"}),
		DesktopStates.state("生气", "3", "angry", true, false, {"jump": "jump_angry"}),
		DesktopStates.state("坐下", "4", "seated", false, true, {}, true),
	]}

static func add_limb(doc: RefCounted, anchors: Dictionary, id: String, parent: String,
		anchor: Vector2i, end: Vector2i, z: int, width: int) -> void:
	var box := Rect2i(anchor.min(end), (anchor - end).abs()).grow(7)
	var line := '<path d="M%d %dL%d %d" fill="none" stroke-linecap="round"' % [anchor.x, anchor.y, end.x, end.y]
	add_layer(doc, anchors, id, parent, anchor, box, z,
		line + ' stroke="%s" stroke-width="%d"/>' % [INK, width] +
		line + ' stroke="%s" stroke-width="%d"/>' % [PAPER, width - 4])

static func add_layer(doc: RefCounted, anchors: Dictionary, id: String, parent: String,
		anchor: Vector2i, box: Rect2i, z: int, art: String, visible: bool = true) -> void:
	var offset: Vector2i = anchor - anchors[parent]
	var pivot := anchor - box.position
	var part := Character.part(id, Rig.role_title(id), parent, [offset.x, offset.y], [pivot.x, pivot.y], z)
	part.role = id
	part.visible = visible
	doc.model.parts.append(part)
	doc.images[part.asset] = render(box, art)
	anchors[id] = anchor

static func path(data: String, fill: String) -> String:
	return '<path d="%s" fill="%s" stroke="%s" stroke-width="2" stroke-linejoin="round"/>' % [data, fill, INK]

static func render(box: Rect2i, art: String) -> Image:
	var img := Image.new()
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="%d %d %d %d">%s</svg>'
	var error := img.load_svg_from_string(svg % [box.size.x, box.size.y, box.position.x, box.position.y, box.size.x, box.size.y, art])
	assert(error == OK)
	return img
