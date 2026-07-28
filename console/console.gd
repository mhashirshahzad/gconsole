extends Node

# ─── Settings ───────────────────────────────────────────────────────────────
# Keys, defaults and colours all live in console_settings.gd. They used to be
# duplicated here AND in console_plugin.gd behind a "should be maintained in one
# place" FIXME - that duplication is what let the two lists drift apart.

const SINGLETON_NAME := &"GConsole"

# ─── Signals ──────────────────────────────────────────────────────────────
signal console_opened()
signal console_closed()
signal console_unknown_command(command: String)
signal console_cvar_changed(cvar_name: String, value: Variant)

# ─── Public Properties ──────────────────────────────────────────────────
var enabled : bool = true
var enable_on_release_build : bool = false : set = set_enable_on_release_build
var pause_enabled : bool = false
var font_size : int = 0 : set = set_font_size
var console_scale : float = 1.0 : set = set_console_scale
var console_full_screen : bool = false
var tab_string : String = "    "
## Lines kept in the output buffer. 0 means unlimited.
var scrollback_limit : int = 500
## Print each command back above its result, the way a terminal does.
var echo_commands : bool = true
## Every line printed this session, so scrollback can be re-rendered after a
## trim without losing what came before.
var _scrollback : PackedStringArray = []



# ─── Subsystems ──────────────────────────────────────────────────────────
var executor: ConsoleExecutor
var history: ConsoleHistory
var commands: ConsoleCommands
var cvars: ConsoleCVars
var autocomplete: ConsoleAutocomplete
var ui : ConsoleUI
var input: ConsoleInput
# ─── Internal ──────────────────────────────────────────────────────────
var was_paused_already : bool = false

# ─── Inner Classes (used by subsystems) ────────────────────────────────
class ConsoleCommand:
	var function : Callable
	var arguments : PackedStringArray
	var required : int
	var description : String
	var hidden : bool

	func _init(in_function : Callable, in_arguments : PackedStringArray, in_required : int = 0, in_description : String = ""):
		function = in_function
		arguments = in_arguments
		required = in_required
		description = in_description
		hidden = false

class ConsoleCvar:
	var name : String
	var description : String
	var type : int
	var save : bool
	var value : Variant
	var object : Object
	var property : String

	func _init(in_name : String, in_type : int, in_description : String = "", in_save : bool = false):
		name = in_name
		type = in_type
		description = in_description
		save = in_save
		value = null
		object = null
		property = ""

	func is_reference() -> bool:
		return object != null

	func is_alive() -> bool:
		return object == null or is_instance_valid(object)

	func get_value() -> Variant:
		if object != null:
			return object.get_indexed(property)
		return value

	func set_value(new_value : Variant) -> void:
		if object != null:
			object.set_indexed(property, new_value)
		else:
			value = new_value

# ─── Lifecycle ──────────────────────────────────────────────────────────
func _enter_tree() -> void:
	history = ConsoleHistory.new(self)
	cvars = ConsoleCVars.new(self)
	commands = ConsoleCommands.new(self)
	autocomplete = ConsoleAutocomplete.new(self)
	executor = ConsoleExecutor.new(self)
	
	# DONT CHANGE THE ORDER!
	ui = ConsoleUI.new(self)
	add_child(ui)
	input = ConsoleInput.new(self, ui)
	add_child(input)
	
	ui.setup()
	
	# take input from window and pass it to ConsoleInput
	ui.console_window.window_input.connect(func(event):
		input.input(event)
	)
	
	history.load_history()
	cvars.load_from_file()

	# A checked-in gconsole.cfg wins over Project Settings, so a teammate who
	# pulls the file gets its values without opening the settings dialog.
	GConsoleSettings.load_project_config()

	tab_string = " ".repeat(int(GConsoleSettings.get_value(GConsoleSettings.TABSTOP)))
	pause_enabled = bool(GConsoleSettings.get_value(GConsoleSettings.PAUSE_WHEN_OPEN))
	scrollback_limit = int(GConsoleSettings.get_value(GConsoleSettings.SCROLLBACK_LIMIT))
	echo_commands = bool(GConsoleSettings.get_value(GConsoleSettings.ECHO_COMMANDS))

	commands.register_builtins()
	process_mode = PROCESS_MODE_ALWAYS

func _exit_tree() -> void:
	history.save()
	cvars.save_to_file()


# ─── Settings Helpers ──────────────────────────────────────────────────
func _get_console_scale_setting() -> float:
	return float(GConsoleSettings.get_value(GConsoleSettings.SCALE))


# ─── Console Control ──────────────────────────────────────────────────
func toggle_console() -> void:
	var console_window := ui.console_window
	var was_visible := console_window.visible
	if enabled:
		console_window.visible = !console_window.visible
	else:
		console_window.visible = false

	if console_window.visible:
		was_paused_already = get_tree().paused
		get_tree().paused = was_paused_already or pause_enabled
		ui.line_edit.grab_focus()
		console_opened.emit()
	else:
		ui.scroll_to_bottom()
		autocomplete.reset()
		if pause_enabled and not was_paused_already:
			get_tree().paused = false
		console_closed.emit()

func is_visible() -> bool:
	return ui.console_window.visible

func disable() -> void:
	enabled = false
	toggle_console()

func enable() -> void:
	enabled = true

func set_enable_on_release_build(enable : bool) -> void:
	enable_on_release_build = enable
	if not enable_on_release_build and not OS.is_debug_build():
		disable()


func _input(event: InputEvent) -> void:
	input.input(event)



# ─── Text Processing ──────────────────────────────────────────────────
func _on_text_entered(new_text: String) -> void:
	# Echoed before execution so the transcript reads in the order things
	# happened: the command, then whatever it printed.
	if not new_text.strip_edges().is_empty():
		print_command(new_text)
	executor.execute(new_text)



func parse_line_input(text: String) -> PackedStringArray:
	var out_array := PackedStringArray()
	var in_quotes := false
	var escaped := false
	var token := ""
	for c in text:
		if c == '\\':
			escaped = true
			continue
		if escaped:
			match c:
				'n': token += '\n'
				't': token += '\t'
				'r': token += '\r'
				'a': token += '\a'
				'b': token += '\b'
				'f': token += '\f'
				_: token += c
			escaped = false
			continue
		if c == '"':
			in_quotes = !in_quotes
			continue
		if (c == ' ' or c == '\t') and not in_quotes:
			out_array.push_back(token)
			token = ""
			continue
		token += c
	out_array.push_back(token)
	return out_array

# ─── Printing ──────────────────────────────────────────────────────────
func print_line(text: Variant, print_godot := false) -> void:
	if not text is String:
		text = str(text)
	if not ui.rich_label:
		call_deferred("print_line", text)
	else:
		ui.rich_label.append_text(text as String)
		ui.rich_label.append_text("\n")
		_scrollback.append(text as String)
		_trim_scrollback()
		if print_godot:
			print_rich((text as String).dedent())

func print_error(text: Variant, print_godot := false) -> void:
	_print_level(text, GConsoleTheme.Level.ERROR, "ERROR", print_godot)

func print_warning(text: Variant, print_godot := false) -> void:
	_print_level(text, GConsoleTheme.Level.WARNING, "WARNING", print_godot)

func print_info(text: Variant, print_godot := false) -> void:
	_print_level(text, GConsoleTheme.Level.INFO, "INFO", print_godot)

func print_success(text: Variant, print_godot := false) -> void:
	_print_level(text, GConsoleTheme.Level.SUCCESS, "OK", print_godot)

func print_debug_line(text: Variant, print_godot := false) -> void:
	_print_level(text, GConsoleTheme.Level.DEBUG, "DEBUG", print_godot)

## Echoes a command the way a terminal does, so scrollback reads as a
## transcript of what was run rather than a wall of bare results.
func print_command(text: String) -> void:
	if not echo_commands:
		return
	print_line("%s %s" % [
		GConsoleTheme.wrap(">", GConsoleTheme.Level.MUTED),
		GConsoleTheme.wrap(text, GConsoleTheme.Level.COMMAND),
	])

## Colours come from GConsoleTheme, so retheming never means editing this file.
func _print_level(text: Variant, level: GConsoleTheme.Level, tag: String,
		print_godot: bool) -> void:
	if not text is String:
		text = str(text)
	print_line("%s%s %s" % [
		tab_string, GConsoleTheme.wrap(tag + ":", level), text
	], print_godot)

## Drops the oldest lines once the buffer exceeds scrollback_limit. Without this
## a long session grows the RichTextLabel without bound.
func _trim_scrollback() -> void:
	if scrollback_limit <= 0 or _scrollback.size() <= scrollback_limit:
		return
	var keep := _scrollback.slice(_scrollback.size() - scrollback_limit)
	_scrollback = PackedStringArray(keep)
	ui.rich_label.clear()
	for line in _scrollback:
		ui.rich_label.append_text(line + "\n")

# ─── Forwarding methods for external registration ────────────────────
func add_command(command_name: String, function: Callable, arguments: Array = [], required: int = 0, description: String = "") -> void:
	commands.add_command(command_name, function, arguments, required, description)

func add_hidden_command(command_name: String, function: Callable, arguments: Array = [], required: int = 0) -> void:
	commands.add_hidden_command(command_name, function, arguments, required)

func remove_command(command_name: String) -> void:
	commands.remove_command(command_name)

func add_cvar(cvar_name: String, default_value: Variant, description: String = "", save: bool = false) -> void:
	cvars.add_cvar(cvar_name, default_value, description, save)

func add_cvar_reference(cvar_name: String, object: Object, property: String, description: String = "", save: bool = false) -> void:
	cvars.add_cvar_reference(cvar_name, object, property, description, save)

func remove_cvar(cvar_name: String) -> void:
	cvars.remove_cvar(cvar_name)

func get_cvar(cvar_name: String) -> Variant:
	return cvars.get_cvar(cvar_name)

func set_cvar(cvar_name: String, value: Variant) -> void:
	cvars.set_cvar(cvar_name, value)

func add_command_autocomplete_list(command_name: String, param_list: PackedStringArray) -> void:
	commands.add_command_autocomplete_list(command_name, param_list)
	
	
func set_font_size(value:int) -> void:
	font_size = value
	if ui:
		ui.set_font_size(value)

func set_console_scale(value:float) -> void:
	console_scale = value
	if ui:
		ui.set_console_scale(value)
