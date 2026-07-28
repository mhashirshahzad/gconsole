extends RefCounted
class_name ConsoleHistory

const HISTORY_FILE := "user://console_history.txt"
const MAX_HISTORY_LINES := 100

var console: Node
var history: PackedStringArray = []
var history_index := 0

func _init(in_console: Node) -> void:
	console = in_console

func load_history() -> void:
	var file := FileAccess.open(HISTORY_FILE, FileAccess.READ)
	if file == null:
		return
	while not file.eof_reached():
		var line := file.get_line()
		if not line.is_empty():
			add(line)

func save() -> void:
	var file := FileAccess.open(HISTORY_FILE, FileAccess.WRITE)
	if file == null:
		return
	var start := maxi(0, history.size() - MAX_HISTORY_LINES)
	for i in range(start, history.size()):
		file.store_line(history[i])

func clear() -> void:
	history.clear()
	history_index = 0
	DirAccess.remove_absolute(HISTORY_FILE)

func add(text: String) -> void:
	if history.is_empty() or history[history.size() - 1] != text:
		history.append(text)
	history_index = history.size()

func up() -> void:
	if history_index <= 0:
		return
	history_index -= 1
	console.ui.line_edit.text = history[history_index]
	console.ui.line_edit.caret_column = console.ui.line_edit.text.length()

func down() -> void:
	if history_index >= history.size():
		return
	history_index += 1
	if history_index < history.size():
		console.ui.line_edit.text = history[history_index]
		console.ui.line_edit.caret_column = console.ui.line_edit.text.length()
	else:
		console.ui.line_edit.text = ""

func reset() -> void:
	history_index = history.size()
