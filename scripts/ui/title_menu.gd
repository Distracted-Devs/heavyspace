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
@export var vibration_button: Button
@export var invert_pitch_button: Button
@export var back_button: Button

@export_group("Test pulse")
@export_range(0.0, 1.0, 0.01) var pulse_weak := 0.3
@export_range(0.0, 1.0, 0.01) var pulse_strong := 0.5
@export_range(0.01, 1.0, 0.01) var pulse_time := 0.15

var settings: GameSettings
var rumble: RumbleMixer


func _ready() -> void:
	if settings == null:
		settings = get_node_or_null(^"/root/Settings") as GameSettings
	if rumble == null:
		rumble = get_node_or_null(^"/root/Rumble") as RumbleMixer
	if not Contract.require(settings != null, "settings must be set"):
		return
	start_button.pressed.connect(start_pressed.emit)
	exit_button.pressed.connect(exit_pressed.emit)
	options_button.pressed.connect(show_options)
	back_button.pressed.connect(show_main)
	vibration_button.pressed.connect(toggle_vibration)
	invert_pitch_button.pressed.connect(toggle_invert_pitch)
	_relabel()
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
	vibration_button.grab_focus()
	_check_one_page()


func toggle_vibration() -> void:
	settings.vibration = not settings.vibration
	if settings.vibration and rumble != null:
		rumble.pulse(pulse_weak, pulse_strong, pulse_time)
	_relabel()


func toggle_invert_pitch() -> void:
	settings.invert_pitch = not settings.invert_pitch
	_relabel()


func _relabel() -> void:
	vibration_button.text = "VIBRATION: %s" % _on_off(settings.vibration)
	invert_pitch_button.text = "INVERT PITCH: %s" % _on_off(
		settings.invert_pitch
	)


func _on_off(value: bool) -> String:
	return "ON" if value else "OFF"


func _check_one_page() -> void:
	Contract.invariant(
		main_page.visible != options_page.visible,
		"exactly one page must show",
	)
