extends Node2D

const Character = preload("res://core/character.gd")

var model: Dictionary = {}
var textures: Dictionary = {}
var action_id := "idle"
var frame := 0
var overlay_id := ""
var overlay_frame := 0
var layers: Array = []
var mirrored := false
var playing := false
var clock := 0.0

func _process(delta: float) -> void:
	if playing:
		clock += delta
		var clip := Character.find_action(model, action_id)
		if not clip.is_empty():
			frame = int(clock * float(clip.fps))
			frame = frame % int(clip.frames) if clip.loop else mini(frame, int(clip.frames) - 1)
		queue_redraw()

func _draw() -> void:
	var clip := Character.find_action(model, action_id)
	var overlay := Character.find_action(model, overlay_id)
	var transforms := Character.transforms(model, clip, frame, overlay, overlay_frame, layers)
	var parts: Array = model.get("parts", []).duplicate()
	parts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.z) < int(b.z))
	for p in parts:
		var pose := Character.layered_pose(clip, p.id, frame, overlay, overlay_frame, layers)
		var asset: String = str(pose.get("asset", p.asset))
		if not p.visible or not pose.get("visible", true) or not textures.has(asset) or not transforms.has(p.id):
			continue
		var t: Transform2D = transforms[p.id]
		if mirrored:
			t = Transform2D(Vector2(-1, 0), Vector2(0, 1), Vector2.ZERO) * t
		draw_set_transform_matrix(t)
		draw_texture(textures[asset], -Character.vec(p.pivot))
	draw_set_transform_matrix(Transform2D.IDENTITY)
