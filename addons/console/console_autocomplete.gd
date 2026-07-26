extends RefCounted
class_name ConsoleAutocomplete

var console: Node
var suggestions: Array = []
var current_suggest := 0
var suggesting := false
var suggestion_panel := PanelContainer.new()
var suggestion_list := VBoxContainer.new()

func _init(in_console: Node) -> void:
	console = in_console

func setup() -> void:
	suggestion_panel.anchor_right = 1.0
	suggestion_panel.visible = false
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.3, 0.3, 0.3)
	suggestion_panel.add_theme_stylebox_override("panel", style)
	
	suggestion_list.size_flags_horizontal = Control.SIZE_EXPAND
	suggestion_panel.add_child(suggestion_list)
	console.v_box_container.add_child(suggestion_panel)

func build() -> Array:
	var found := []
	var text : String = console.line_edit.text
	
	if " " in text:
		var split: PackedStringArray = console.parse_line_input(text)
		if split.size() > 1:
			var command := split[0]
			var param := split[1]
			if console.commands.command_parameters.has(command):
				var param_list: PackedStringArray = console.commands.command_parameters[command]
				for option in param_list:
					if param in option or param.is_empty():
						found.append("%s %s" % [command, option])
	else:
		var names: Array = []
		for command in console.commands.commands:
			if not console.commands.commands[command].hidden:
				names.append(str(command))
		for cvar in console.cvars.cvars:
			names.append(str(cvar))
		names.sort()
		names.reverse()
		var previous := 0
		for name in names:
			if text.is_empty() or name.contains(text):
				var index: int = name.find(text)
				if index <= previous:
					found.push_front(name)
				else:
					found.push_back(name)
				previous = index
	return found

func refresh() -> void:
	suggestions = build()
	suggesting = false
	
	if suggestions.is_empty() or console.line_edit.text.is_empty():
		suggestion_panel.visible = false
		return
	
	current_suggest = 0
	suggestion_panel.visible = true
	
	# Clear old suggestions
	for child in suggestion_list.get_children():
		suggestion_list.remove_child(child)
		child.queue_free()
	
	# Add new suggestions
	for i in range(min(8, suggestions.size())):
		var label := Label.new()
		label.text = suggestions[i]
		label.add_theme_color_override("font_color", Color.WHITE)
		if i == current_suggest:
			label.add_theme_color_override("font_color", Color.YELLOW)
		suggestion_list.add_child(label)
	
	# Position the panel
	suggestion_panel.offset_top = -suggestion_panel.get_combined_minimum_size().y - 5

func cycle() -> void:
	if suggestions.is_empty():
		return
	
	current_suggest = (current_suggest + 1) % suggestions.size()
	
	# Update highlighted suggestion
	var children := suggestion_list.get_children()
	for i in range(children.size()):
		var label := children[i] as Label
		if i == current_suggest:
			label.add_theme_color_override("font_color", Color.YELLOW)
			if i < suggestions.size():
				console.line_edit.text = suggestions[i]
				console.line_edit.caret_column = console.line_edit.text.length()
		else:
			label.add_theme_color_override("font_color", Color.WHITE)
	
	suggesting = true

func reset() -> void:
	suggestions.clear()
	current_suggest = 0
	suggesting = false
	suggestion_panel.visible = false
