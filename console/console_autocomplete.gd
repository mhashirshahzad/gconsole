extends RefCounted
class_name ConsoleAutocomplete

var console: Node

var suggestions: Array[String] = []
var current_suggest := 0
var suggesting := false

var suggestion_panel := PanelContainer.new()
var suggestion_list := VBoxContainer.new()


func _init(in_console: Node) -> void:
	console = in_console

func setup() -> void:
	suggestion_panel.visible = false
	suggestion_panel.z_index = 100
	suggestion_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	# Don't stretch.
	suggestion_panel.anchor_left = 0
	suggestion_panel.anchor_top = 0
	suggestion_panel.anchor_right = 0
	suggestion_panel.anchor_bottom = 0
	suggestion_panel.offset_left = 0
	suggestion_panel.offset_top = 0
	suggestion_panel.offset_right = 0
	suggestion_panel.offset_bottom = 0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.94)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = GConsoleTheme.color_of(GConsoleTheme.Level.MUTED)

	suggestion_panel.add_theme_stylebox_override("panel", style)

	suggestion_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	suggestion_panel.add_child(suggestion_list)

	# Child of the floating window.
	console.ui.console_window.add_child(suggestion_panel)
	
func build() -> Array[String]:
	var found: Array[String] = []
	var text : String = console.ui.line_edit.text

	if " " in text:
		var split : PackedStringArray = console.parse_line_input(text)

		if split.size() > 1:
			var command := split[0]
			var param := split[1]

			if console.commands.command_parameters.has(command):
				var params: PackedStringArray = console.commands.command_parameters[command]

				for option in params:
					if param.is_empty() or option.contains(param):
						found.append("%s %s" % [command, option])
	else:
		var names: Array[String] = []

		for command in console.commands.commands:
			if not console.commands.commands[command].hidden:
				names.append(command)

		for cvar in console.cvars.cvars:
			names.append(cvar)

		names.sort()
		names.reverse()

		var previous := 1000000

		for name in names:
			if text.is_empty() or name.contains(text):
				var idx := name.find(text)

				if idx <= previous:
					found.push_front(name)
				else:
					found.push_back(name)

				previous = idx

	return found


func refresh() -> void:
	suggestions = build()
	suggesting = false

	if suggestions.is_empty() or console.ui.line_edit.text.is_empty():
		suggestion_panel.hide()
		return

	current_suggest = 0

	for child in suggestion_list.get_children():
		child.queue_free()

	var shown := min(
		int(GConsoleSettings.get_value(GConsoleSettings.SUGGESTION_LIMIT)),
		suggestions.size()
	)

	for i in shown:
		var label := Label.new()
		label.text = suggestions[i]

		if i == current_suggest:
			label.add_theme_color_override(
				"font_color",
				GConsoleTheme.color_of(GConsoleTheme.Level.SUGGESTION)
			)
		else:
			label.add_theme_color_override(
				"font_color",
				GConsoleTheme.color_of(GConsoleTheme.Level.SUGGESTION_SELECTED)
			)

		suggestion_list.add_child(label)

	await RenderingServer.frame_post_draw

	suggestion_panel.reset_size()

	var input : LineEdit = console.ui.line_edit

	# Position relative to the Window.
	var pos : Vector2 = input.get_global_rect().position

	suggestion_panel.position = Vector2(
		pos.x,
		pos.y - suggestion_panel.size.y - 4
	)

	# Match input width.
	suggestion_panel.size.x = input.size.x

	suggestion_panel.show()


func cycle() -> void:
	if suggestions.is_empty():
		return

	current_suggest = (current_suggest + 1) % suggestions.size()

	var children := suggestion_list.get_children()

	for i in children.size():
		var label := children[i] as Label

		if i == current_suggest:
			label.add_theme_color_override(
				"font_color",
				GConsoleTheme.color_of(GConsoleTheme.Level.SUGGESTION)
			)

			console.ui.line_edit.text = suggestions[i]
			console.ui.line_edit.caret_column = console.ui.line_edit.text.length()
		else:
			label.add_theme_color_override(
				"font_color",
				GConsoleTheme.color_of(GConsoleTheme.Level.SUGGESTION_SELECTED)
			)

	suggesting = true

func accept() -> void:
	if suggestions.is_empty():
		return

	if current_suggest < 0 or current_suggest >= suggestions.size():
		return

	console.ui.line_edit.text = suggestions[current_suggest]
	console.ui.line_edit.caret_column = console.ui.line_edit.text.length()

	reset()

func reset() -> void:
	suggestions.clear()
	current_suggest = 0
	suggesting = false
	suggestion_panel.hide()
