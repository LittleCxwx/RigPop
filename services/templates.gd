extends RefCounted

const Character = preload("res://core/character.gd")
const Store = preload("res://services/project_store.gd")
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

static func make(kind: String = "traveler") -> RefCounted:
	var doc := Store.new()
	doc.model = Character.empty("薄荷旅人" if kind == "traveler" else "果冻团子")
	var m: Dictionary = doc.model
	if kind == "slime":
		var source := (load("res://assets/slime.png") as Texture2D).get_image().get_region(Rect2i(0, 0, 64, 64))
		var face := source.get_region(Rect2i(23, 37, 17, 15))
		source.fill_rect(Rect2i(23, 37, 17, 15), Color.TRANSPARENT)
		m.parts = [Character.part("body", "胶质身体", "", [0, 0], [32, 52], 0), Character.part("face", "表情", "body", [-9, -15], [0, 0], 1)]
		doc.images = {"assets/body.png": source, "assets/face.png": face}
	else:
		m.parts = [Character.part("body", "外套", "", [0, -12], [7, 10], 0),
			Character.part("head", "头部", "body", [0, -11], [9, 12], 3),
			Character.part("arm_l", "左手", "body", [-7, -7], [3, 2], -1),
			Character.part("arm_r", "右手", "body", [7, -7], [2, 2], 4),
			Character.part("leg_l", "左靴", "body", [-4, 0], [3, 0], -1),
			Character.part("leg_r", "右靴", "body", [4, 0], [3, 0], 1),
			Character.part("scarf", "珊瑚围巾", "body", [1, -10], [4, 1], 5)]
		doc.images["assets/head.png"] = sprite(["......oooooo......", "....oommmmmm oo...".replace(" ", "m"), "...ommmmmmmmmo....", "..ommmmmmmmmmmo...", "..ommmmmmmmmmmmo..", ".ommmmmmmmmmmmmo..", ".omggggggggggggo..", ".ooowwwwwwwwwooo..", "..owwowwwwowwo....", "..owwowwwwowwo....", "..owwwwppwwwwo....", "...owwwwwwwwo.....", "....oowwwwoo......", "......oooo........"])
		doc.images["assets/body.png"] = sprite(["...oooooooo...", "..ommmwwmmmo..", ".ommmmwwmmmmo.", ".ommmmwwmmmmo.", ".ogmmmwwmmmgo.", ".ogmmmwwmmmgo.", ".ogmmmwwmmmgo.", ".ogggmwwmgggo.", "..ogggwwgggo..", "..oggggggggo..", "...oooooooo..."])
		var arm := sprite(["..ooo..", ".ommmo.", ".ommmo.", ".ogggo.", ".ogggo.", ".owwwo.", ".owwwo.", "..ooo.."])
		doc.images["assets/arm_l.png"] = arm
		doc.images["assets/arm_r.png"] = arm.duplicate()
		var boot := sprite([".ooooo..", ".ossso..", ".ossso..", ".ossso..", ".odd do..".replace(" ", "d"), "odddddo.", "oddddddo", "oooooooo"])
		doc.images["assets/leg_l.png"] = boot
		doc.images["assets/leg_r.png"] = boot.duplicate()
		doc.images["assets/scarf.png"] = sprite(["oooooooooo", "oppppppppo", ".oopp p oo.".replace(" ", "p"), "...oppo...", "...opppo..", "....oppo..", "....oyyo..", ".....oo..."])
	var idle := Character.action("idle", "待机", 8)
	var walk := Character.action("walk", "行走", 8)
	var wave := Character.action("wave", "招手", 8)
	wave.overlay = true
	var main_id := "body"
	for f in [0, 2, 4, 6]:
		Character.set_key(idle, main_id, f, {"position": [0, [0, -1, 0, 0][f / 2]], "rotation": 0})
		Character.set_key(walk, main_id, f, {"position": [0, [0, -2, 0, -2][f / 2]], "rotation": 0})
		if kind == "traveler":
			for id in ["leg_l", "leg_r"]:
				Character.set_key(walk, id, f, {"position": [0, 0], "rotation": [22, 0, -22, 0][f / 2] * (1 if id == "leg_l" else -1)})
			for id in ["arm_l", "arm_r"]:
				Character.set_key(walk, id, f, {"position": [0, 0], "rotation": [-25, 0, 25, 0][f / 2] * (1 if id == "arm_l" else -1)})
			Character.set_key(wave, "arm_r", f, {"position": [0, 0], "rotation": [-125, -155, -125, -145][f / 2]})
		else:
			Character.set_key(wave, "body", f, {"position": [[0, -3, 3, 0][f / 2], -4], "rotation": [-8, 0, 8, 0][f / 2]})
	m.actions = [idle, walk, wave]
	doc.refresh_textures()
	return doc
