extends SceneTree

static func version_error(version: String, tag: String) -> String:
	var semver := RegEx.create_from_string(r"^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$")
	if semver.search(version) == null:
		return "Set a semantic application version in project.godot [application] config/version."
	if tag != "v" + version:
		return "Release tag '%s' does not match application version '%s'. Expected tag: v%s. Update project.godot and commit it before creating the tag. Re-running the old tag uses the old source version." % [tag, version, version]
	return ""

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] != "--tag":
		push_error("Expected -- --tag <release tag>")
		quit(1)
		return
	var config := ConfigFile.new()
	if config.load("res://project.godot") != OK:
		push_error("Cannot read project.godot")
		quit(1)
		return
	var version := str(config.get_value("application", "config/version", ""))
	var error := version_error(version, args[1])
	if not error.is_empty():
		push_error(error)
		quit(1)
		return
	print("RELEASE_VERSION_PASS: ", args[1], " matches project.godot ", version)
	quit()
