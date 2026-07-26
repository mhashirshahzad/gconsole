extends RefCounted
class_name ConsoleLevelUtils


static func load_level(console: Node, level_name: String) -> void:
	var scene_path := find_level("res://levels", level_name.to_lower())

	if scene_path.is_empty():
		console.push_error("No level found containing '%s'." % level_name)
		return

	console.get_tree().change_scene_to_file(scene_path)
	console.rich_label.append_text(
		"Opened level at scene path [system_color color=CONSOLE_COLOR_LITERAL]%s[/system_color]"
		% scene_path
	)


static func find_level(path: String, level_name: String) -> String:
	var dir := DirAccess.open(path)
	if dir == null:
		return ""

	dir.list_dir_begin()

	while true:
		var file_name := dir.get_next()

		if file_name.is_empty():
			break

		if file_name.begins_with("."):
			continue

		var full_path := path.path_join(file_name)

		if dir.current_is_dir():
			var result := find_level(full_path, level_name)
			if !result.is_empty():
				dir.list_dir_end()
				return result

		elif (file_name.ends_with(".tscn") or file_name.ends_with(".scn")) \
		and file_name.to_lower().contains(level_name):
			dir.list_dir_end()
			return full_path

	dir.list_dir_end()
	return ""


static func get_level_names(path: String = "res://levels") -> PackedStringArray:
	var levels := PackedStringArray()
	_collect_level_names(path, levels)
	levels.sort()
	return levels


static func _collect_level_names(path: String, levels: PackedStringArray) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()

	while true:
		var file_name := dir.get_next()

		if file_name.is_empty():
			break

		if file_name.begins_with("."):
			continue

		var full_path := path.path_join(file_name)

		if dir.current_is_dir():
			_collect_level_names(full_path, levels)
		elif file_name.ends_with("_level.tscn"):
			levels.append(file_name.get_basename())

	dir.list_dir_end()
