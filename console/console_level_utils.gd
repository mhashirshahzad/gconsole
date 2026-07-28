extends RefCounted
class_name ConsoleLevelUtils

static var levels_dir : String = "res://levels"
static var levels_pfx : String = "_level"

static var _level_paths: Dictionary = {}
static var _initialized := false

func _init() -> void:
	levels_pfx = GConsoleSettings.get_value(GConsoleSettings.LEVELS_PREFIX)
	levels_dir = GConsoleSettings.get_value(GConsoleSettings.LEVELS_DIR)
	
static func load_level(console: Node, level_name: String) -> void:
	_ensure_initialized()

	var key := level_name.to_lower()

	if not _level_paths.has(key):
		console.push_error("Unknown level: %s" % level_name)
		return

	var scene_path: String = _level_paths[key]

	console.print_line(
		"Opened level [system_color color=CONSOLE_COLOR_LITERAL]%s[/system_color]\n"
		% scene_path
	)

	console.get_tree().change_scene_to_file(scene_path)


static func get_level_names() -> PackedStringArray:
	_ensure_initialized()

	var names := PackedStringArray(_level_paths.keys())
	names.sort()
	return names


static func _ensure_initialized() -> void:
	if _initialized:
		return

	_level_paths.clear()
	_scan_directory(levels_dir)
	_initialized = true


static func _scan_directory(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()

	while true:
		var file := dir.get_next()

		if file.is_empty():
			break

		if file.begins_with("."):
			continue

		var full_path := path.path_join(file)

		if dir.current_is_dir():
			_scan_directory(full_path)
		elif _is_level_scene(file):
			_level_paths[file.get_basename().to_lower()] = full_path

	dir.list_dir_end()


static func _is_level_scene(file_name: String) -> bool:
	return (
		file_name.ends_with(levels_pfx + ".tscn")
		or file_name.ends_with(levels_pfx + ".scn")
	)
