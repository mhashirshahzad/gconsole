extends RefCounted
class_name ConsoleLevelUtils

## Finds and loads level scenes by filename suffix.
##
## A level is any scene under the configured directory whose name ends in the
## configured prefix, e.g. _level.tscn or _level.scn — so adding a level is just
## saving a file with the right name. Both are editable under
## GConsole > level_utils in Project Settings.

static var _level_paths: Dictionary = {}
static var _initialized := false

## Optional hook a host game can install to take over loading — to fade, save,
## close menus, whatever it needs. Receives the resolved res:// path.
##
## Without it the scene is swapped directly, so the plugin still works standalone
## in a project that has no transition system. With it, the game keeps its
## polish and does not need a second, competing level command.
##
##     ConsoleLevelUtils.loader = func(path: String) -> void:
##         UIManager.change_level(path)
static var loader : Callable = Callable()


## `console` is LAST because the command is registered with
## `Callable(...).bind(console)`, and bind() APPENDS its arguments. With the
## console first the level name arrived where the Node was expected, and every
## call died with "Cannot convert argument 1 from String to Object".
static func load_level(level_name: String, console: Node) -> void:
	_ensure_initialized()

	var path := resolve(level_name)
	if path.is_empty():
		# print_error, not push_error: push_error is a global GDScript function,
		# not a method on the console Node, so calling it here crashed instead
		# of reporting the unknown level. Known levels are listed so a typo is
		# self-correcting.
		console.print_error("Unknown level: %s. Known: %s"
			% [level_name, ", ".join(get_level_names())])
		return

	console.print_info("Loading %s" % path)

	if loader.is_valid():
		loader.call(path)
		return
	console.get_tree().change_scene_to_file(path)


## Resolves a level by any reasonable spelling: "tutorial", "tutorial_level" and
## "tutorial_level.scn" all find the same scene. Returns "" when unknown.
static func resolve(level_name: String) -> String:
	_ensure_initialized()
	return _level_paths.get(_normalise(level_name), "")


static func has_level(level_name: String) -> bool:
	return not resolve(level_name).is_empty()


## Short names for autocomplete, e.g. ["test", "tutorial"].
static func get_level_names() -> PackedStringArray:
	_ensure_initialized()
	var names := PackedStringArray(_level_paths.keys())
	names.sort()
	return names


## Call after changing the settings, or after adding a level at runtime.
static func reload() -> void:
	_initialized = false
	_level_paths.clear()
	_ensure_initialized()


# Settings are read here rather than in _init(): this class is only ever used
# statically, so _init() never runs and the configured values were silently
# ignored in favour of the defaults.
static func levels_dir() -> String:
	return str(GConsoleSettings.get_value(GConsoleSettings.LEVELS_DIR))


static func levels_prefix() -> String:
	return str(GConsoleSettings.get_value(GConsoleSettings.LEVELS_PREFIX))


static func _normalise(level_name: String) -> String:
	var key := level_name.strip_edges().to_lower()
	# Exported builds rename scenes to .remap, so strip that before the
	# extension or nothing resolves outside the editor.
	key = key.trim_suffix(".remap").trim_suffix(".tscn").trim_suffix(".scn")
	return key.trim_suffix(levels_prefix())


static func _ensure_initialized() -> void:
	if _initialized:
		return
	_level_paths.clear()
	_scan_directory(levels_dir())
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
			continue

		var real := file.trim_suffix(".remap")
		if _is_level_scene(real):
			# Keyed by short name only. Storing both spellings would duplicate
			# every level in autocomplete; resolve() normalises the INPUT
			# instead, so "tutorial_level" still finds "tutorial".
			_level_paths[_normalise(real)] = path.path_join(real)
	dir.list_dir_end()


static func _is_level_scene(file_name: String) -> bool:
	var pfx := levels_prefix()
	return file_name.ends_with(pfx + ".tscn") or file_name.ends_with(pfx + ".scn")
