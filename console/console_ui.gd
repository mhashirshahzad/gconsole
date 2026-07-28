extends Node
class_name ConsoleUI

var console: Node

var console_window := Window.new()
var margin_container := MarginContainer.new()
var v_box_container := VBoxContainer.new()
var rich_label := RichTextLabel.new()
var line_edit := LineEdit.new()


func _init(owner: Node) -> void:
	console = owner


func setup() -> void:
	
	console_window.title = "GConsole"
	console_window.handle_input_locally = false
	console_window.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_KEYBOARD_FOCUS
	console_window.size = Vector2i(600, 480)
	
	
	add_child(console_window)
	
	console.console_scale = console._get_console_scale_setting()

	# Margin.
	margin_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin_container.add_theme_constant_override("margin_left", 8)
	margin_container.add_theme_constant_override("margin_top", 8)
	margin_container.add_theme_constant_override("margin_right", 8)
	margin_container.add_theme_constant_override("margin_bottom", 8)
	console_window.add_child(margin_container)

	# Layout.
	GConsoleTheme.apply_to(v_box_container)
	v_box_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v_box_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin_container.add_child(v_box_container)

	# Output.
	rich_label.selection_enabled = true
	rich_label.context_menu_enabled = true
	rich_label.bbcode_enabled = true
	rich_label.scroll_following = true
	rich_label.fit_content = false
	rich_label.install_effect(GConsoleSystemColor.new())

	rich_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rich_label.size_flags_vertical = Control.SIZE_EXPAND_FILL

	if console.font_size > 0:
		rich_label.add_theme_font_size_override(
			"normal_font_size",
			console.font_size
		)

	v_box_container.add_child(rich_label)
	rich_label.append_text("Development console.\n")

	# Input.
	line_edit.placeholder_text = 'Enter "help" for instructions'
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if console.font_size > 0:
		line_edit.add_theme_font_size_override(
			"font_size",
			console.font_size
		)

	v_box_container.add_child(line_edit)

	console.autocomplete.setup()

	line_edit.text_submitted.connect(console.input.on_text_entered)
	line_edit.text_changed.connect(console.input.on_text_changed)
	
	rich_label.focus_mode = Control.FOCUS_NONE
	line_edit.focus_next = NodePath()
	line_edit.focus_previous = NodePath()

	console_window.visible = false


func set_console_scale(scale: float) -> void:
	v_box_container.scale = Vector2(scale, scale)
	v_box_container.anchor_right = get_console_width()
	v_box_container.anchor_bottom = get_console_height()


func set_font_size(value: int) -> void:
	console.font_size = value

	if value > 0:
		line_edit.add_theme_font_size_override("font_size", value)

		for override in [
			"normal_font_size",
			"bold_font_size",
			"bold_italics_font_size",
			"italics_font_size",
			"mono_font_size"
		]:
			rich_label.add_theme_font_size_override(override, value)
	else:
		line_edit.remove_theme_font_size_override("font_size")

		for override in [
			"normal_font_size",
			"bold_font_size",
			"bold_italics_font_size",
			"italics_font_size",
			"mono_font_size"
		]:
			rich_label.remove_theme_font_size_override(override)


func get_console_height() -> float:
	if console.console_full_screen:
		return 1.0 / console.console_scale

	return float(
		GConsoleSettings.get_value(GConsoleSettings.HEIGHT)
	) / console.console_scale


func get_console_width() -> float:
	return 1.0 / console.console_scale


func scroll_to_bottom() -> void:
	var scroll := rich_label.get_v_scroll_bar()
	scroll.value = scroll.max_value - scroll.page


func show_console() -> void:
	console_window.visible = true
	line_edit.grab_focus()


func hide_console() -> void:
	console_window.visible = false


func toggle() -> void:
	console_window.visible = !console_window.visible

	if console_window.visible:
		line_edit.grab_focus()


func append_text(text: String) -> void:
	rich_label.append_text(text)


func append_line(text: String) -> void:
	rich_label.append_text(text + "\n")


func clear() -> void:
	rich_label.clear()


func _on_line_edit_text_changed(_new_text: String) -> void:
	console.autocomplete.reset()
	console.autocomplete.refresh()
	
