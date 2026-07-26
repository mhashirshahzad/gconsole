extends RefCounted
class_name ConsoleExecutor

var console: Node

func _init(in_console: Node) -> void:
	console = in_console

func execute(new_text: String) -> void:
	console.scroll_to_bottom()
	console.autocomplete.reset()

	console.line_edit.clear()
	if console.line_edit.has_method(&"edit"):
		console.line_edit.call_deferred(&"edit")

	if new_text.strip_edges().is_empty():
		return

	console.history.add(new_text)
	console.print_line("[i]> " + new_text + "[/i]")

	var split : PackedStringArray = console.parse_line_input(new_text)
	var command := split[0]

	if console.commands.commands.has(command):
		_execute_command(command, split.slice(1))
		return

	if console.cvars.cvars.has(command):
		console.cvars.handle_cvar(command, split.slice(1))
		return

	console.console_unknown_command.emit(command)
	console.print_error("Unknown command or variable.")

func _execute_command(command: String, arguments: PackedStringArray) -> void:
	var cmd: Console.ConsoleCommand = console.commands.commands[command]

	if command == "calc":
		cmd.function.callv(["".join(arguments)])
		return

	if arguments.size() < cmd.required:
		console.print_error("Too few arguments! Required < %d >" % cmd.required)
		return

	if arguments.size() > cmd.arguments.size():
		arguments.resize(cmd.arguments.size())

	while arguments.size() < cmd.arguments.size():
		arguments.append("")

	cmd.function.callv(arguments)
