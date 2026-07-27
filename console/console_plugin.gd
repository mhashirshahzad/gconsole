@tool
extends EditorPlugin

## Registers the GConsole autoload and its project settings.
##
## Setting definitions live in console_settings.gd, not here. They used to be
## duplicated across both files behind a "these should be maintained in one
## place" FIXME, which is exactly how the two lists drifted apart.

const SINGLETON_NAME : StringName = &"GConsole"


## Resolved from this script's own location rather than hardcoded, so the plugin
## works wherever it is mounted - addons/gconsole, addons/console, a submodule
## path, anywhere.
func _autoload_path() -> String:
	return get_script().resource_path.get_base_dir().path_join("console.gd")


func _enable_plugin() -> void:
	GConsoleSettings.register()

	# Generated on first enable, like Godot does with default_bus_layout.tres,
	# so the console's setup is committed with the game and every teammate gets
	# it from a checkout. Never overwrites an existing file.
	if GConsoleSettings.write_project_config():
		print("GConsole: created %s" % GConsoleSettings.CONFIG_PATH)

	add_autoload_singleton(SINGLETON_NAME, _autoload_path())
	print("GConsole plugin enabled.")


func _disable_plugin() -> void:
	remove_autoload_singleton(SINGLETON_NAME)
	# Settings are deliberately left in place: removing them would discard the
	# user's tuning the moment the plugin is toggled off for a moment.
	print("GConsole plugin disabled.")
