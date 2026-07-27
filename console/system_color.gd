@tool
extends RichTextEffect
class_name GConsoleSystemColor

## Resolves [system_color color=ERROR]...[/system_color] against the themed
## palette.
##
## Takes a LEVEL NAME now ("ERROR", "SUGGESTION") rather than reaching into
## Console's constant map, which no longer exists - colours moved into
## console_settings.gd so they could be edited from Project Settings.

var bbcode : String = "system_color"


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var raw : Variant = char_fx.env.get("color")
	if raw == null:
		return false

	var name := str(raw).to_upper()
	# Tolerate the old CONSOLE_COLOR_ERROR spelling so existing bbcode in a
	# game's own strings keeps rendering after upgrading.
	name = name.trim_prefix("CONSOLE_COLOR_").trim_prefix("GCONSOLE_COLOR_")

	if not GConsoleTheme.Level.has(name):
		return false

	char_fx.color = GConsoleTheme.color_of(GConsoleTheme.Level[name])
	return true
