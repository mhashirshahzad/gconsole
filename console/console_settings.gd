@tool
extends RefCounted
class_name GConsoleSettings

## Every tunable the plugin has, defined once.
##
## The editor plugin registers these into Project Settings and the runtime reads
## them back through the same list, which resolves the old
## "FIXME: These should be maintained in one place" - keys used to be duplicated
## between console.gd and console_plugin.gd and could silently drift apart.
##
## Everything lives under the "gconsole" category so it groups in the Project
## Settings tree instead of scattering.

const CATEGORY : String = "gconsole"

## Written to the PROJECT root, not the addon folder: these values belong to the
## game, so they travel in the game's repo rather than the plugin's.
const CONFIG_PATH : String = "res://gconsole.cfg"

# Keys <================================================================================================>
const THEME : String = "gconsole/display/theme"
const SCALE : String = "gconsole/display/scale"
const HEIGHT : String = "gconsole/display/height"
const CANVAS_LAYER : String = "gconsole/display/canvas_layer"
const FONT_SIZE : String = "gconsole/display/font_size"

const TABSTOP : String = "gconsole/behaviour/tabstop"
const PAUSE_WHEN_OPEN : String = "gconsole/behaviour/pause_when_open"
const HISTORY_LIMIT : String = "gconsole/behaviour/history_limit"
const SCROLLBACK_LIMIT : String = "gconsole/behaviour/scrollback_limit"
const ECHO_COMMANDS : String = "gconsole/behaviour/echo_commands"
const SUGGESTION_LIMIT : String = "gconsole/behaviour/suggestion_limit"

const COLOR_TEXT : String = "gconsole/colors/text"
const COLOR_COMMAND : String = "gconsole/colors/command"
const COLOR_ERROR : String = "gconsole/colors/error"
const COLOR_WARNING : String = "gconsole/colors/warning"
const COLOR_INFO : String = "gconsole/colors/info"
const COLOR_SUCCESS : String = "gconsole/colors/success"
const COLOR_DEBUG : String = "gconsole/colors/debug"
const COLOR_LITERAL : String = "gconsole/colors/literal"
const COLOR_MUTED : String = "gconsole/colors/muted"
const COLOR_SUGGESTION : String = "gconsole/colors/suggestion"
const COLOR_SUGGESTION_SELECTED : String = "gconsole/colors/suggestion_selected"


## key -> {default, type, hint, hint_string, doc}
##
## Order here is the order they appear in Project Settings.
static func definitions() -> Array[Dictionary]:
	return [
		# Display
		_def(THEME, "", TYPE_STRING, PROPERTY_HINT_FILE, "*.tres,*.theme",
			"Optional Theme resource applied to the console UI."),
		_def(SCALE, 1.0, TYPE_FLOAT, PROPERTY_HINT_RANGE, "0.1,10,0.1,or_greater",
			"Visual scale of the whole console."),
		_def(HEIGHT, 0.5, TYPE_FLOAT, PROPERTY_HINT_RANGE, "0.1,1,0.05",
			"Fraction of the screen the console covers when not full screen."),
		_def(CANVAS_LAYER, 3, TYPE_INT, PROPERTY_HINT_NONE, "",
			"CanvasLayer index. Raise it above your own HUD layers."),
		_def(FONT_SIZE, 0, TYPE_INT, PROPERTY_HINT_RANGE, "0,64,1",
			"Font size override. 0 uses the theme's own size."),

		# Behaviour
		_def(TABSTOP, 4, TYPE_INT, PROPERTY_HINT_RANGE, "0,8,1,or_greater",
			"Spaces a tab expands to in console output."),
		_def(PAUSE_WHEN_OPEN, false, TYPE_BOOL, PROPERTY_HINT_NONE, "",
			"Pause the game while the console is open."),
		_def(HISTORY_LIMIT, 100, TYPE_INT, PROPERTY_HINT_RANGE, "0,1000,1",
			"How many entered commands to remember across runs."),
		_def(SCROLLBACK_LIMIT, 500, TYPE_INT, PROPERTY_HINT_RANGE, "0,10000,50",
			"Maximum lines kept in the output buffer. 0 means unlimited."),
		_def(ECHO_COMMANDS, true, TYPE_BOOL, PROPERTY_HINT_NONE, "",
			"Print each command back above its result, like a real terminal."),
		_def(SUGGESTION_LIMIT, 8, TYPE_INT, PROPERTY_HINT_RANGE, "1,30,1",
			"How many autocomplete suggestions to show at once."),

		# Colors
		_def(COLOR_TEXT, Color("c7d8ec"), TYPE_COLOR, PROPERTY_HINT_COLOR_NO_ALPHA, "",
			"Default output colour."),
		_def(COLOR_COMMAND, Color("ffffff"), TYPE_COLOR, PROPERTY_HINT_COLOR_NO_ALPHA, "",
			"The echoed command line."),
		_def(COLOR_ERROR, Color("f08080"), TYPE_COLOR, PROPERTY_HINT_COLOR_NO_ALPHA, "",
			"Errors."),
		_def(COLOR_WARNING, Color("eedd82"), TYPE_COLOR, PROPERTY_HINT_COLOR_NO_ALPHA, "",
			"Warnings."),
		_def(COLOR_INFO, Color("add8e6"), TYPE_COLOR, PROPERTY_HINT_COLOR_NO_ALPHA, "",
			"Informational messages."),
		_def(COLOR_SUCCESS, Color("98fb98"), TYPE_COLOR, PROPERTY_HINT_COLOR_NO_ALPHA, "",
			"Success confirmations."),
		_def(COLOR_DEBUG, Color("9590c7"), TYPE_COLOR, PROPERTY_HINT_COLOR_NO_ALPHA, "",
			"Verbose debug output."),
		_def(COLOR_LITERAL, Color("98fb98"), TYPE_COLOR, PROPERTY_HINT_COLOR_NO_ALPHA, "",
			"Values echoed back, such as cvar contents."),
		_def(COLOR_MUTED, Color("5d4d5c"), TYPE_COLOR, PROPERTY_HINT_COLOR_NO_ALPHA, "",
			"De-emphasised text such as hints and counts."),
		_def(COLOR_SUGGESTION, Color("e8f281"), TYPE_COLOR, PROPERTY_HINT_COLOR_NO_ALPHA, "",
			"Autocomplete suggestions."),
		_def(COLOR_SUGGESTION_SELECTED, Color("ffffff"), TYPE_COLOR,
			PROPERTY_HINT_COLOR_NO_ALPHA, "",
			"The suggestion Tab will insert next."),
	]


static func _def(key: String, default: Variant, type: int, hint: int,
		hint_string: String, doc: String) -> Dictionary:
	return {
		"key": key, "default": default, "type": type,
		"hint": hint, "hint_string": hint_string, "doc": doc,
	}


# Runtime access <======================================================================================>

## Reads a setting, falling back to the declared default.
##
## ProjectSettings.get_setting() does not reliably return a registered default in
## every Godot version, so the default is looked up here rather than trusted.
static func get_value(key: String) -> Variant:
	var fallback : Variant = default_for(key)
	if ProjectSettings.has_setting(key):
		var value : Variant = ProjectSettings.get_setting(key)
		if value != null:
			return value
	return fallback


static func default_for(key: String) -> Variant:
	for entry in definitions():
		if entry["key"] == key:
			return entry["default"]
	return null


static func get_color(key: String) -> Color:
	var value : Variant = get_value(key)
	return value if value is Color else Color.WHITE


# Editor registration <=================================================================================>

static func register() -> void:
	for entry in definitions():
		var key : String = entry["key"]
		if not ProjectSettings.has_setting(key):
			ProjectSettings.set_setting(key, entry["default"])
		ProjectSettings.add_property_info({
			"name": key,
			"type": entry["type"],
			"hint": entry["hint"],
			"hint_string": entry["hint_string"],
		})
		ProjectSettings.set_initial_value(key, entry["default"])
		ProjectSettings.set_as_basic(key, true)
	ProjectSettings.save()


static func unregister() -> void:
	for entry in definitions():
		if ProjectSettings.has_setting(entry["key"]):
			ProjectSettings.set_setting(entry["key"], null)
	ProjectSettings.save()


# Project-side config file <============================================================================>

## Writes res://gconsole.cfg from the current settings, the way Godot generates
## default_bus_layout.tres. It lives in the game's repo so every teammate gets
## the same console setup from a checkout, and it is deliberately NOT inside the
## addon: these values describe the game, not the plugin.
##
## Only written when missing, so it never clobbers hand-edited values.
static func write_project_config(force: bool = false) -> bool:
	if not force and FileAccess.file_exists(CONFIG_PATH):
		return false

	var config := ConfigFile.new()
	for entry in definitions():
		var key : String = entry["key"]
		var parts : PackedStringArray = key.split("/")
		# "gconsole/colors/error" -> section "colors", key "error"
		var section : String = parts[1] if parts.size() > 2 else "general"
		var leaf : String = parts[parts.size() - 1]
		config.set_value(section, leaf, get_value(key))

	var err := config.save(CONFIG_PATH)
	if err != OK:
		push_error("GConsole: could not write %s (%s)"
			% [CONFIG_PATH, error_string(err)])
		return false
	return true


## Applies a checked-in gconsole.cfg over the in-memory settings, so a teammate
## who pulls the file gets its values without opening Project Settings.
static func load_project_config() -> bool:
	if not FileAccess.file_exists(CONFIG_PATH):
		return false
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return false
	for entry in definitions():
		var key : String = entry["key"]
		var parts : PackedStringArray = key.split("/")
		var section : String = parts[1] if parts.size() > 2 else "general"
		var leaf : String = parts[parts.size() - 1]
		if config.has_section_key(section, leaf):
			ProjectSettings.set_setting(key, config.get_value(section, leaf))
	return true
