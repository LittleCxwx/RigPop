extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://manifest.json"))
	if not manifest is Dictionary:
		push_error("Missing export manifest"); quit(1); return
	var scene: PackedScene = load("res://" + str(manifest.entry_scene))
	if scene == null:
		push_error("Cannot load exported character entry"); quit(1); return
	var actor: CharacterBody2D = scene.instantiate()
	actor.position = Vector2(120, 160)
	root.add_child(actor)
	await process_frame
	await process_frame
	if actor.model.get("id", "") != manifest.id or actor.view.textures.is_empty() or actor.position != Vector2(120, 160):
		push_error("Exported entry did not load its independent character data"); quit(1); return
	actor.execute("wave")
	if actor.overlay_id != "wave":
		push_error("Exported action interface failed"); quit(1); return
	var Character = load("res://addons/rigpop_runtime/core/character.gd")
	var blink: Dictionary = Character.find_action(actor.model, "blink")
	if not blink.is_empty():
		blink.conflict = "replace"
		if not actor.execute("blink") or actor.view.layers.size() != 2:
			push_error("Exported independent actions do not combine"); quit(1); return
	var joints: Array = actor.model.parts.filter(func(p: Dictionary) -> bool: return p.get("kind", "part") == "joint")
	if not joints.is_empty():
		var transforms: Dictionary = Character.transforms(actor.model, {}, 0)
		if joints.size() < 3 or not transforms.has(joints.back().id):
			push_error("Exported multi-joint chain incomplete"); quit(1); return
		var parent: Dictionary = joints[0]
		var before: Vector2 = transforms[joints.back().id].origin
		parent.rotation += 30
		if before.is_equal_approx(Character.transforms(actor.model, {}, 0)[joints.back().id].origin):
			push_error("Exported joint parent rotation does not propagate"); quit(1); return
	print("EXPORTED_ENTRY_PASS: instantiated, positioned, textures loaded, overlay command executed")
	actor.queue_free()
	await process_frame
	quit()
