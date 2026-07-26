extends Node

# ─── Settings Keys ──────────────────────────────────────────────────────────
const SINGLETON_NAME := &"Console"
const CONSOLE_THEME : String = "console/theme"
const CONSOLE_SCALE : String = "console/scale"
const CONSOLE_HEIGHT : String = "console/height"
const CONSOLE_COLOR_WARNING : String = "console/color_warning"
const CONSOLE_COLOR_ERROR : String = "console/color_error"
const CONSOLE_COLOR_INFO : String = "console/color_info"
const CONSOLE_COLOR_LITERAL : String = "console/color_literal"
const CONSOLE_TABSTOP : String = "console/tabstop"
const CONSOLE_CANVAS_LAYER : String = "console/canvas_layer"

# ─── Default Colors ────────────────────────────────────────────────────────
const color_dictionary : Dictionary[String, Color] = {
	CONSOLE_COLOR_ERROR: Color.LIGHT_CORAL,
	CONSOLE_COLOR_INFO: Color.LIGHT_BLUE,
	CONSOLE_COLOR_LITERAL: Color.PALE_GREEN,
	CONSOLE_COLOR_WARNING: Color.LIGHT_GOLDENROD
}

# ─── Signals ──────────────────────────────────────────────────────────────
signal console_opened()
signal console_closed()
signal console_unknown_command(command: String)
signal console_cvar_changed(cvar_name: String, value: Variant)

# ─── Public Properties ──────────────────────────────────────────────────
var enabled : bool = true
var enable_on_release_build : bool = false : set = set_enable_on_release_build
var pause_enabled : bool = false
var font_size : int = 0 : set = _set_font_size
var console_scale : float = 1.0 : set = set_console_scale
var console_full_screen : bool = false
var tab_string : String = "    "

# ─── UI Components (Exposed for customization) ─────────────────────────
var canvas_layer := CanvasLayer.new()
var v_box_container := VBoxContainer.new()
var panel := Panel.new()
var rich_label := RichTextLabel.new()
var line_edit := LineEdit.new()

# ─── Subsystems ──────────────────────────────────────────────────────────
var executor: ConsoleExecutor
var history: ConsoleHistory
var commands: ConsoleCommands
var cvars: ConsoleCVars
var autocomplete: ConsoleAutocomplete

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

	history.load_history()
	cvars.load_from_file()

	if ProjectSettings.has_setting(CONSOLE_THEME):
		var theme: Resource = load(ProjectSettings.get_setting(CONSOLE_THEME))
		if theme:
			v_box_container.theme = theme

	if ProjectSettings.has_setting(CONSOLE_TABSTOP):
		tab_string = ""
		var tab_count: int = ProjectSettings.get_setting(CONSOLE_TABSTOP)
		for i in range(tab_count):
			tab_string += " "

	_setup_ui()
	commands.register_builtins()
	process_mode = PROCESS_MODE_ALWAYS

func _exit_tree() -> void:
	history.save()
	cvars.save_to_file()

# ─── UI Setup ──────────────────────────────────────────────────────────
func _setup_ui() -> void:
	canvas_layer.layer = ProjectSettings.get_setting(CONSOLE_CANVAS_LAYER, 3)
	add_child(canvas_layer)

	console_scale = _get_console_scale_setting()

	v_box_container.offset_bottom = 0
	v_box_container.offset_left = 0
	v_box_container.offset_right = 0
	v_box_container.offset_top = 0
	canvas_layer.add_child(v_box_container)

	panel.size_flags_vertical = Control.SIZE_EXPAND
	v_box_container.add_child(panel)

	rich_label.selection_enabled = true
	rich_label.context_menu_enabled = true
	rich_label.bbcode_enabled = true
	rich_label.scroll_following = true
	rich_label.anchor_right = 1.0
	rich_label.anchor_bottom = 1.0
	rich_label.install_effect(preload("system_color.gd").new())
	panel.add_child(rich_label)

	rich_label.append_text("Development console.\n")

	line_edit.anchor_right = 1.0
	line_edit.placeholder_text = 'Enter "help" for instructions'

	if font_size > 0:
		line_edit.add_theme_font_size_override("font_size", font_size)

	autocomplete.setup()

	v_box_container.add_child(line_edit)

	line_edit.text_submitted.connect(_on_text_entered)
	line_edit.text_changed.connect(_on_line_edit_text_changed)

	v_box_container.visible = false

# ─── Settings Helpers ──────────────────────────────────────────────────
func _get_console_scale_setting() -> float:
	if ProjectSettings.has_setting(CONSOLE_SCALE):
		return ProjectSettings.get_setting(CONSOLE_SCALE)
	return 1.0

func set_console_scale(scale : float) -> void:
	console_scale = scale
	v_box_container.scale = Vector2(console_scale, console_scale)
	v_box_container.anchor_right = _get_console_width()
	v_box_container.anchor_bottom = _get_console_height()

func _get_console_height() -> float:
	if console_full_screen:
		return 1.0 / console_scale
	if ProjectSettings.has_setting(CONSOLE_HEIGHT):
		return ProjectSettings.get_setting(CONSOLE_HEIGHT) / console_scale
	return 0.5 / console_scale

func _get_console_width() -> float:
	return 1.0 / console_scale

func _set_font_size(value: int) -> void:
	font_size = value
	if value > 0:
		line_edit.add_theme_font_size_override("font_size", font_size)
		rich_label.add_theme_font_size_override("normal_font_size", font_size)
		rich_label.add_theme_font_size_override("bold_font_size", font_size)
		rich_label.add_theme_font_size_override("bold_italics_font_size", font_size)
		rich_label.add_theme_font_size_override("italics_font_size", font_size)
		rich_label.add_theme_font_size_override("mono_font_size", font_size)
	else:
		line_edit.remove_theme_font_size_override("font_size")
		var overrides: PackedStringArray = ["normal_font_size", "bold_font_size", "bold_italics_font_size", "italics_font_size", "mono_font_size"]
		for override_name in overrides:
			rich_label.remove_theme_font_size_override(override_name)

# ─── Console Control ──────────────────────────────────────────────────
func toggle_console() -> void:
	var was_visible := v_box_container.visible
	if enabled:
		v_box_container.visible = !v_box_container.visible
	else:
		v_box_container.visible = false

	if v_box_container.visible:
		was_paused_already = get_tree().paused
		get_tree().paused = was_paused_already or pause_enabled
		line_edit.grab_focus()
		console_opened.emit()
	else:
		scroll_to_bottom()
		autocomplete.reset()
		if pause_enabled and not was_paused_already:
			get_tree().paused = false
		console_closed.emit()

func toggle_size() -> void:
	console_full_screen = !console_full_screen
	v_box_container.anchor_bottom = _get_console_height()

func is_visible() -> bool:
	return v_box_container.visible

func disable() -> void:
	enabled = false
	toggle_console()

func enable() -> void:
	enabled = true

func set_enable_on_release_build(enable : bool) -> void:
	enable_on_release_build = enable
	if not enable_on_release_build and not OS.is_debug_build():
		disable()

func scroll_to_bottom() -> void:
	var scroll := rich_label.get_v_scroll_bar()
	scroll.value = scroll.max_value - scroll.page

# ─── Input Handling ──────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		_handle_key_input(event as InputEventKey)
	elif event is InputEventMouseButton and v_box_container.visible:
		_handle_mouse_input(event as InputEventMouseButton)

func _handle_key_input(event: InputEventKey) -> void:
	if event.physical_keycode == KEY_QUOTELEFT:
		if event.pressed:
			if event.is_command_or_control_pressed():
				if v_box_container.visible:
					toggle_size()
				else:
					toggle_console()
					toggle_size()
			else:
				toggle_console()
				toggle_size()
			get_viewport().set_input_as_handled()
		return

	if event.get_physical_keycode_with_modifiers() == KEY_ESCAPE and v_box_container.visible:
		if event.pressed:
			toggle_console()
			get_viewport().set_input_as_handled()
		return

	if not v_box_container.visible or not event.pressed:
		return

	var keycode := event.get_physical_keycode_with_modifiers()
	match keycode:
		KEY_CTRL + KEY_C:
			line_edit.text = ""
			line_edit.caret_column = 0
			history.reset()
			autocomplete.reset()
			get_viewport().set_input_as_handled()
		KEY_UP:
			history.up()
			autocomplete.reset()
			get_viewport().set_input_as_handled()
		KEY_DOWN:
			history.down()
			autocomplete.reset()
			get_viewport().set_input_as_handled()
		KEY_PAGEUP:
			var scroll := rich_label.get_v_scroll_bar()
			scroll.value = scroll.value - (scroll.page - scroll.page * 0.1)
			get_viewport().set_input_as_handled()
		KEY_PAGEDOWN:
			var scroll := rich_label.get_v_scroll_bar()
			scroll.value = scroll.value + (scroll.page - scroll.page * 0.1)
			get_viewport().set_input_as_handled()
		KEY_TAB:
			autocomplete.cycle()
			get_viewport().set_input_as_handled()

func _handle_mouse_input(event: InputEventMouseButton) -> void:
	if event.is_command_or_control_pressed():
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				font_size = mini(128, font_size + 2)
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN:
				font_size = maxi(8, font_size - 2)
				get_viewport().set_input_as_handled()

# ─── Text Processing ──────────────────────────────────────────────────
func _on_text_entered(new_text: String) -> void:
	executor.execute(new_text)

func _on_line_edit_text_changed(new_text: String) -> void:
	autocomplete.reset()
	autocomplete.refresh()

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
	if not rich_label:
		call_deferred("print_line", text)
	else:
		rich_label.append_text(text as String)
		rich_label.append_text("\n")
		if print_godot:
			print_rich((text as String).dedent())

func print_error(text: Variant, print_godot := false) -> void:
	if not text is String:
		text = str(text)
	print_line('%s[system_color color=CONSOLE_COLOR_ERROR]ERROR:[/system_color] %s' % [tab_string, text], print_godot)

func print_info(text: Variant, print_godot := false) -> void:
	if not text is String:
		text = str(text)
	print_line('%s[system_color color=CONSOLE_COLOR_INFO]INFO:[/system_color] %s' % [tab_string, text], print_godot)

func print_warning(text: Variant, print_godot := false) -> void:
	if not text is String:
		text = str(text)
	print_line('%s[system_color color=CONSOLE_COLOR_WARNING]WARNING:[/system_color] %s' % [tab_string, text], print_godot)

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
