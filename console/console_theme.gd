@tool
extends RefCounted
class_name GConsoleTheme

## Resolves semantic colours and applies the user's Theme resource.
##
## Callers ask for a MEANING ("this is a warning") rather than a colour, so
## retheming the console never means hunting down hardcoded Color values.

enum Level {
	TEXT,                  ## default output
	COMMAND,               ## the echoed command line
	ERROR,
	WARNING,
	INFO,
	SUCCESS,
	DEBUG,
	LITERAL,               ## values echoed back, e.g. cvar contents
	MUTED,                 ## hints, counts, de-emphasised text
	SUGGESTION,            ## autocomplete entry
	SUGGESTION_SELECTED,   ## the entry Tab will insert next
}

const _KEYS : Dictionary = {
	Level.TEXT: GConsoleSettings.COLOR_TEXT,
	Level.COMMAND: GConsoleSettings.COLOR_COMMAND,
	Level.ERROR: GConsoleSettings.COLOR_ERROR,
	Level.WARNING: GConsoleSettings.COLOR_WARNING,
	Level.INFO: GConsoleSettings.COLOR_INFO,
	Level.SUCCESS: GConsoleSettings.COLOR_SUCCESS,
	Level.DEBUG: GConsoleSettings.COLOR_DEBUG,
	Level.LITERAL: GConsoleSettings.COLOR_LITERAL,
	Level.MUTED: GConsoleSettings.COLOR_MUTED,
	Level.SUGGESTION: GConsoleSettings.COLOR_SUGGESTION,
	Level.SUGGESTION_SELECTED: GConsoleSettings.COLOR_SUGGESTION_SELECTED,
}


static func color_of(level: Level) -> Color:
	return GConsoleSettings.get_color(_KEYS.get(level, GConsoleSettings.COLOR_TEXT))


## Wraps text in a bbcode colour tag for the rich text output.
static func wrap(text: String, level: Level) -> String:
	return "[color=#%s]%s[/color]" % [color_of(level).to_html(false), text]


## Loads the user's Theme resource, if one is configured. Returns null when the
## setting is empty or the path no longer resolves, so a deleted theme degrades
## to Godot's default instead of erroring on every launch.
static func load_theme() -> Theme:
	var path : String = str(GConsoleSettings.get_value(GConsoleSettings.THEME))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Theme


static func apply_to(control: Control) -> void:
	if control == null:
		return
	var theme := load_theme()
	if theme != null:
		control.theme = theme
