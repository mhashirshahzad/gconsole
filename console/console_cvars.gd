extends RefCounted
class_name ConsoleCVars

var console: Node
var cvars: Dictionary[String, GConsole.ConsoleCvar] = {}
var pending_values: Dictionary[String, Variant] = {}

func _init(in_console: Node) -> void:
	console = in_console

func add_cvar(cvar_name: String, default_value: Variant, description: String = "", save: bool = false) -> void:
	var cvar := GConsole.ConsoleCvar.new(cvar_name, typeof(default_value), description, save)
	cvar.value = default_value
	cvars[cvar_name] = cvar
	_apply_pending(cvar)

func add_cvar_reference(cvar_name: String, object: Object, property: String, description: String = "", save: bool = false) -> void:
	if not is_instance_valid(object):
		console.print_error('Cannot register cvar "%s": invalid object.' % cvar_name)
		return
	var cvar := GConsole.ConsoleCvar.new(cvar_name, typeof(object.get_indexed(property)), description, save)
	cvar.object = object
	cvar.property = property
	cvars[cvar_name] = cvar
	_apply_pending(cvar)

func remove_cvar(cvar_name: String) -> void:
	cvars.erase(cvar_name)

func get_cvar(cvar_name: String) -> Variant:
	if cvars.has(cvar_name):
		var cvar := cvars[cvar_name]
		if cvar.is_alive():
			return cvar.get_value()
	return null

func set_cvar(cvar_name: String, value: Variant) -> void:
	if cvars.has(cvar_name):
		var cvar := cvars[cvar_name]
		if cvar.is_alive():
			cvar.set_value(value)
			console.console_cvar_changed.emit(cvar_name, value)

func handle_cvar(cvar_name: String, arguments: PackedStringArray) -> void:
	if not cvars.has(cvar_name):
		return
	var cvar := cvars[cvar_name]
	if not cvar.is_alive():
		console.print_error('Variable "%s" references a freed object.' % cvar.name)
		return
	if arguments.is_empty():
		_print_value(cvar)
		if cvar.description:
			console.print_line("%s%s" % [console.tab_string, cvar.description])
		return
	var raw_value := " ".join(arguments)
	var result := _coerce_string_to_type(raw_value, cvar.type)
	if not result[0]:
		console.print_error('Invalid value "%s" for variable "%s" (expected %s).' % [raw_value, cvar.name, type_string(cvar.type)])
		return
	cvar.set_value(result[1])
	console.console_cvar_changed.emit(cvar.name, result[1])
	_print_value(cvar)

func _print_value(cvar: GConsole.ConsoleCvar) -> void:
	console.print_line('%s = [system_color color=CONSOLE_COLOR_LITERAL]%s[/system_color]' % [cvar.name, str(cvar.get_value())])

func _coerce_string_to_type(string_value: String, type: int) -> Array:
	match type:
		TYPE_BOOL:
			var lower := string_value.strip_edges().to_lower()
			if lower in ["1", "true", "yes", "on"]:
				return [true, true]
			if lower in ["0", "false", "no", "off"]:
				return [true, false]
			return [false, null]
		TYPE_INT:
			var int_string := string_value.strip_edges()
			if int_string.is_valid_int():
				return [true, int_string.to_int()]
			return [false, null]
		TYPE_FLOAT:
			var float_string := string_value.strip_edges()
			if float_string.is_valid_float():
				return [true, float_string.to_float()]
			return [false, null]
		TYPE_STRING:
			return [true, string_value]
		TYPE_STRING_NAME:
			return [true, StringName(string_value)]
		_:
			var parsed := str_to_var(string_value)
			if parsed != null and typeof(parsed) == type:
				return [true, parsed]
			return [false, null]

func _apply_pending(cvar: GConsole.ConsoleCvar) -> void:
	if cvar.save and pending_values.has(cvar.name):
		var saved_value : Variant = pending_values[cvar.name]
		if typeof(saved_value) != cvar.type:
			saved_value = type_convert(saved_value, cvar.type)
		cvar.set_value(saved_value)
		pending_values.erase(cvar.name)

func load_from_file() -> void:
	var file := FileAccess.open("user://console_cvars.txt", FileAccess.READ)
	if not file:
		return
	while not file.eof_reached():
		var line := file.get_line()
		if line.is_empty():
			continue
		var split := line.split(" ", true, 1)
		if split.size() == 2:
			pending_values[split[0]] = str_to_var(split[1])

func save_to_file() -> void:
	var file := FileAccess.open("user://console_cvars.txt", FileAccess.WRITE)
	if not file:
		return
	for cvar_name in cvars:
		var cvar := cvars[cvar_name]
		if cvar.save and cvar.is_alive():
			file.store_line("%s %s" % [cvar_name, var_to_str(cvar.get_value())])
	for pending_name in pending_values:
		if not cvars.has(pending_name):
			file.store_line("%s %s" % [pending_name, var_to_str(pending_values[pending_name])])
