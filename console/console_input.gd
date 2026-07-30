extends Node
class_name ConsoleInput

var console: GConsole
var ui: ConsoleUI


func _init(in_console: Node, console_ui: ConsoleUI) -> void:
	console = in_console
	ui = console_ui



func input(event: InputEvent) -> void:
	if event is InputEventKey:
		_handle_key_input(event)
	elif event is InputEventMouseButton and ui.console_window.visible:
		_handle_mouse_input(event)


func _handle_key_input(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return

	# Toggle console.
	if event.physical_keycode == KEY_QUOTELEFT:
		console.toggle_console()
		console.get_viewport().set_input_as_handled()
		return

	# Ignore the rest if the console isn't visible.
	if not ui.console_window.visible:
		return

	# Close console.
	if event.physical_keycode == KEY_ESCAPE:
		console.toggle_console()
		console.get_viewport().set_input_as_handled()
		return

	# Ctrl+C
	if event.physical_keycode == KEY_C and event.is_command_or_control_pressed():
		ui.line_edit.clear()
		console.history.reset()
		console.autocomplete.reset()
		console.get_viewport().set_input_as_handled()
		return

	match event.physical_keycode:
		KEY_UP:
			console.history.up()
			console.autocomplete.reset()
			console.get_viewport().set_input_as_handled()

		KEY_DOWN:
			console.history.down()
			console.autocomplete.reset()
			console.get_viewport().set_input_as_handled()

		KEY_PAGEUP:
			var scroll := ui.rich_label.get_v_scroll_bar()
			scroll.value -= scroll.page * 0.9
			console.get_viewport().set_input_as_handled()

		KEY_PAGEDOWN:
			var scroll := ui.rich_label.get_v_scroll_bar()
			scroll.value += scroll.page * 0.9
			console.get_viewport().set_input_as_handled()

		KEY_TAB:
			console.autocomplete.cycle()

			# Prevent the LineEdit from moving focus.
			ui.line_edit.accept_event()

			console.get_viewport().set_input_as_handled()
		
		KEY_RIGHT:
			if console.autocomplete.suggestion_panel.visible:
				console.autocomplete.accept()
				get_viewport().set_input_as_handled()
			
func _handle_mouse_input(event: InputEventMouseButton) -> void:
	if not event.is_command_or_control_pressed():
		return

	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			console.font_size = mini(128, console.font_size + 2)
			console.get_viewport().set_input_as_handled()

		MOUSE_BUTTON_WHEEL_DOWN:
			console.font_size = maxi(8, console.font_size - 2)
			console.get_viewport().set_input_as_handled()


func on_text_entered(new_text: String) -> void:
	if not new_text.strip_edges().is_empty():
		pass
		# console.print_command(new_text)

	console.executor.execute(new_text)


func on_text_changed(_new_text: String) -> void:
	console.autocomplete.reset()
	console.autocomplete.refresh()
