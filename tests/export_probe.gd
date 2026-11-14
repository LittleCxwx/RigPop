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
	print("EXPORTED_ENTRY_PASS: instantiated, positioned, textures loaded, overlay command executed")
	actor.queue_free()
	await process_frame
	quit()
