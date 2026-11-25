class_name TitleMenu
extends CanvasLayer

signal start_pressed
signal exit_pressed

@export_group("Components")
@export var main_page: Control
@export var options_page: Control
@export var start_button: Button
@export var options_button: Button
@export var exit_button: Button
@export var options_list: OptionsList
@export var back_button: Button


func _ready() -> void:
	start_button.pressed.connect(start_pressed.emit)
	exit_button.pressed.connect(exit_pressed.emit)
	options_button.pressed.connect(show_options)
	back_button.pressed.connect(show_main)
	show_main()
	start_button.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if options_page.visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		show_main()


func show_main() -> void:
	var from_options := options_page.visible
	options_page.visible = false
	main_page.visible = true
	if from_options:
		options_button.grab_focus()
	_check_one_page()


func show_options() -> void:
	main_page.visible = false
	options_page.visible = true
	options_list.first_button().grab_focus()
	_check_one_page()


func _check_one_page() -> void:
	Contract.invariant(
		main_page.visible != options_page.visible,
		"exactly one page must show",
	)
