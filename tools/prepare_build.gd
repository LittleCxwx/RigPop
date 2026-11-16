extends SceneTree


func _init() -> void:
	var config := ConfigFile.new()
	if config.load("res://project.godot") != OK:
		fail("Cannot read project.godot")
		return
	var version := str(config.get_value("application", "config/version", ""))
	var semver := RegEx.create_from_string(r"^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$")
	if semver.search(version) == null:
		fail("Set a semantic application version in project.godot")
		return
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		if args.size() != 2 or args[0] != "--icon":
			fail("Expected -- --icon <PNG or ICO path>")
			return
		var source := args[1].simplify_path()
		var extension := source.get_extension().to_lower()
		if not FileAccess.file_exists(source) or extension not in ["png", "ico"]:
			fail("The application icon must be an existing PNG or ICO file")
			return
		if extension == "png":
			var image := Image.load_from_file(source)
			if image == null or image.is_empty():
				fail("Cannot decode the PNG icon")
				return
			if image.get_width() != image.get_height() or image.get_width() < 16:
				fail("Use a square PNG icon, at least 16 x 16 pixels (256 x 256 recommended)")
				return
		else:
			var icon := FileAccess.open(source, FileAccess.READ)
			if icon == null or icon.get_length() < 6 or icon.get_16() != 0 or icon.get_16() != 1 or icon.get_16() == 0:
				fail("Invalid ICO header")
				return
		var destination := "res://assets/rigpop-icon." + extension
		var absolute_destination := ProjectSettings.globalize_path(destination).simplify_path()
		if source.to_lower() != absolute_destination.to_lower():
			if DirAccess.copy_absolute(source, absolute_destination) != OK:
				fail("Cannot copy the icon into assets/")
				return
		var setting := "config/icon" if extension == "png" else "config/windows_native_icon"
		var other_setting := "config/windows_native_icon" if extension == "png" else "config/icon"
		config.set_value("application", setting, destination)
		if config.has_section_key("application", other_setting):
			config.erase_section_key("application", other_setting)
		if config.save("res://project.godot") != OK:
			fail("Cannot save the project icon setting")
			return
		print("Application icon: ", destination)
	var metadata := FileAccess.open("res://build/build_info.json", FileAccess.WRITE)
	if metadata == null:
		fail("Cannot write build/build_info.json")
		return
	metadata.store_string(JSON.stringify({
		"version": version,
		"engine": Engine.get_version_info().string,
		"platform": "windows-x86_64",
		"configuration": "release",
	}, "\t"))
	print("Prepared RigPop ", version)
	quit()


func fail(message: String) -> void:
	push_error(message)
	quit(1)
