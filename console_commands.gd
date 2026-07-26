extends RefCounted
class_name ConsoleCommands

var console: Node
var commands: Dictionary[String, Console.ConsoleCommand] = {}
var command_parameters: Dictionary[String, PackedStringArray] = {}

func _init(in_console: Node) -> void:
	console = in_console

func add_command(command_name: String, function: Callable, arguments = [], required: int = 0, description: String = "") -> void:
	var param_array: PackedStringArray
	if arguments is int:
		var arg_count := arguments as int
		for i in range(arg_count):
			param_array.append("arg_" + str(i + 1))
	elif arguments is Array:
		var arg_array := arguments as Array
		for arg in arg_array:
			param_array.append(str(arg))
	else:
		param_array = PackedStringArray()
	commands[command_name] = Console.ConsoleCommand.new(function, param_array, required, description)

func add_hidden_command(command_name: String, function: Callable, arguments = [], required: int = 0) -> void:
	add_command(command_name, function, arguments, required)
	commands[command_name].hidden = true

func remove_command(command_name: String) -> void:
	commands.erase(command_name)
	command_parameters.erase(command_name)

func add_command_autocomplete_list(command_name: String, param_list: PackedStringArray) -> void:
	command_parameters[command_name] = param_list

func register_builtins() -> void:
	add_command("quit", _quit, 0, 0, "Quits the game.")
	add_command("exit", _quit, 0, 0, "Quits the game.")
	add_command("clear", _clear, 0, 0, "Clears the text on the console.")
	add_command("delete_history", _delete_history, 0, 0, "Deletes the history of previously entered commands.")
	add_command("help", _help, 0, 0, "Displays instructions.")
	add_command("commands_list", _commands_list, 0, 0, "Lists all commands.")
	add_command("commands", _commands, 0, 0, "Lists commands.")
	add_command("cvars", _cvars, 0, 0, "Lists console variables.")
	add_command("calc", _calculate, ["expression"], 1, "Evaluate math.")
	add_command("echo", _echo, ["string"], 1, "Print text.")
	add_command("echo_warning", _echo_warning, ["string"], 1)
	add_command("echo_info", _echo_info, ["string"], 1)
	add_command("echo_error", _echo_error, ["string"], 1)
	add_command("pause", _pause, 0, 0)
	add_command("unpause", _unpause, 0, 0)
	add_command("exec", _exec, 1, 1)

# ─── Built‑in implementations ──────────────────────────────────────────

func _quit() -> void:
	# Uncomment to enable quit functionality
	# get_tree().quit()
	pass

func _clear() -> void:
	console.rich_label.clear()

func _delete_history() -> void:
	console.history.clear()

func _help() -> void:
	console.rich_label.append_text("	Built in commands:
		[system_color color=CONSOLE_COLOR_LITERAL]calc[/system_color]: Calculates a given expression
		[system_color color=CONSOLE_COLOR_LITERAL]clear[/system_color]: Clears the registry view
		[system_color color=CONSOLE_COLOR_LITERAL]commands[/system_color]: Shows a reduced list of all the currently registered commands
		[system_color color=CONSOLE_COLOR_LITERAL]commands_list[/system_color]: Shows a detailed list of all the currently registered commands
		[system_color color=CONSOLE_COLOR_LITERAL]cvars[/system_color]: Lists all console variables and their values
		[system_color color=CONSOLE_COLOR_LITERAL]delete_history[/system_color]: Deletes the commands history
		[system_color color=CONSOLE_COLOR_LITERAL]echo[/system_color]: Prints a given string to the console
		[system_color color=CONSOLE_COLOR_LITERAL]echo_error[/system_color]: Prints a given string as an error to the console
		[system_color color=CONSOLE_COLOR_LITERAL]echo_info[/system_color]: Prints a given string as info to the console
		[system_color color=CONSOLE_COLOR_LITERAL]echo_warning[/system_color]: Prints a given string as warning to the console
		[system_color color=CONSOLE_COLOR_LITERAL]pause[/system_color]: Pauses node processing
		[system_color color=CONSOLE_COLOR_LITERAL]unpause[/system_color]: Unpauses node processing
		[system_color color=CONSOLE_COLOR_LITERAL]quit[/system_color]: Quits the game

	Controls:
		[system_color color=CONSOLE_COLOR_INFO]Up[/system_color] and [system_color color=CONSOLE_COLOR_INFO]Down[/system_color] arrow keys to navigate commands history
		[system_color color=CONSOLE_COLOR_INFO]PageUp[/system_color] and [system_color color=CONSOLE_COLOR_INFO]PageDown[/system_color] to scroll registry
		[[system_color color=CONSOLE_COLOR_INFO]Ctrl[/system_color] + [system_color color=CONSOLE_COLOR_INFO]~[/system_color]] to change console size between half screen and full screen
		[[system_color color=CONSOLE_COLOR_INFO]Ctrl[/system_color] + [system_color color=CONSOLE_COLOR_INFO]Mouse Wheel[/system_color]] up/down to change console font size
		[system_color color=CONSOLE_COLOR_INFO]~[/system_color] or [system_color color=CONSOLE_COLOR_INFO]Esc[/system_color] key to close the console
		[system_color color=CONSOLE_COLOR_INFO]Tab[/system_color] key to autocomplete, [system_color color=CONSOLE_COLOR_INFO]Tab[/system_color] again to cycle between matching suggestions\n\n")

func _commands() -> void:
	var list: Array = []
	for command in commands:
		if not commands[command].hidden:
			list.append(str(command))
	list.sort()
	console.rich_label.append_text("	")
	console.rich_label.append_text(str(list) + "\n\n")

func _commands_list() -> void:
	var list: Array = []
	for command in commands:
		if not commands[command].hidden:
			list.append(str(command))
	list.sort()
	for command in list:
		var cmd: Console.ConsoleCommand = commands[command]
		var args := ""
		for i in range(cmd.arguments.size()):
			if i < cmd.required:
				args += "  [system_color color=CONSOLE_COLOR_ERROR]<" + cmd.arguments[i] + ">[/system_color]"
			else:
				args += "  [system_color color=CONSOLE_COLOR_INFO]<" + cmd.arguments[i] + ">[/system_color]"
		console.rich_label.append_text("	[system_color color=CONSOLE_COLOR_LITERAL]%s[/system_color]%s:   %s\n" % [command, args, cmd.description])
	console.rich_label.append_text("\n")

func _cvars() -> void:
	var names: Array = console.cvars.cvars.keys()
	names.sort()
	for cvar_name in names:
		var cvar: Console.ConsoleCvar = console.cvars.cvars[cvar_name]
		var value_string := "<invalid>"
		if cvar.is_alive():
			value_string = str(cvar.get_value())
		console.rich_label.append_text("	[system_color color=CONSOLE_COLOR_LITERAL]%s[/system_color] = [system_color color=CONSOLE_COLOR_INFO]%s[/system_color]   %s\n" % [cvar_name, value_string, cvar.description])
	console.rich_label.append_text("\n")

func _calculate(expression: String) -> void:
	var expr := Expression.new()
	var error := expr.parse(expression)
	if error != OK:
		console.print_error("%s" % expr.get_error_text())
		return
	var result := expr.execute()
	if not expr.has_execute_failed():
		console.print_line(str(result))
	else:
		console.print_error("%s" % expr.get_error_text())

func _echo(text: String) -> void:
	console.print_line(text)

func _echo_warning(text: String) -> void:
	console.print_warning(text)

func _echo_info(text: String) -> void:
	console.print_info(text)

func _echo_error(text: String) -> void:
	console.print_error(text)

func _pause() -> void:
	# Uncomment to enable pause functionality
	# get_tree().paused = true
	pass

func _unpause() -> void:
	# Uncomment to enable unpause functionality
	# get_tree().paused = false
	pass

func _exec(filename: String) -> void:
	var path := "user://%s.txt" % [filename]
	var script := FileAccess.open(path, FileAccess.READ)
	if script:
		while not script.eof_reached():
			console._on_text_entered(script.get_line())
	else:
		console.print_error("File %s not found." % [path])
