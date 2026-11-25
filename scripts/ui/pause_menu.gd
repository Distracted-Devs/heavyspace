class_name PauseMenu
extends CanvasLayer

signal quit_requested

@export_group("Components")
@export var pause_controller: PauseController
@export var header: Label
@export var view: ControlsView
@export var resume_button: Button
@export var restart_button: Button
@export var options_button: Button
@export var quit_button: Button
@export var controls_panel: Control
@export var options_panel: Control
@export var options_list: OptionsList
@export var options_back_button: Button

@export_group("Quit")
@export var quit_on_request := true
@export_file("*.tscn") var title_scene := "res://scenes/title/title_screen.tscn"

var devices: DeviceTracker


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _enter_tree() -> void:
	if devices == null:
		devices = InputDevice
	view.devices = devices
	if not devices.device_changed.is_connected(_on_device_changed):
		devices.device_changed.connect(_on_device_changed)


func _exit_tree() -> void:
	if (
		is_instance_valid(devices)
		and devices.device_changed.is_connected(_on_device_changed)
	):
		devices.device_changed.disconnect(_on_device_changed)


func _ready() -> void:
	visible = false
	_name_device(devices.device)
	if not Contract.require(
		pause_controller != null,
		"pause_controller must be set",
	):
		return
	pause_controller.paused_changed.connect(_on_paused_changed)
	resume_button.pressed.connect(pause_controller.set_paused.bind(false))
	restart_button.pressed.connect(pause_controller.restart)
	options_button.pressed.connect(show_options)
	options_back_button.pressed.connect(show_controls)
	quit_button.pressed.connect(_on_quit)
	show_controls()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var button := event as InputEventJoypadButton
	var pad_b := (
		button and button.pressed and button.button_index == JOY_BUTTON_B
	)
	if (
		options_panel.visible
		and (pad_b or event.is_action_pressed(&"ui_cancel"))
	):
		show_controls()
		options_button.grab_focus()
		get_viewport().set_input_as_handled()
	elif pad_b:
		pause_controller.set_paused(false)
		get_viewport().set_input_as_handled()


func show_options() -> void:
	controls_panel.visible = false
	options_panel.visible = true
	options_list.first_button().grab_focus()
	_check_one_panel()


func show_controls() -> void:
	options_panel.visible = false
	controls_panel.visible = true
	_check_one_panel()


func _on_paused_changed(paused: bool) -> void:
	visible = paused
	if paused:
		show_controls()
		resume_button.grab_focus()


func _on_device_changed(device: DeviceTracker.Device) -> void:
	_name_device(device)


func _name_device(device: DeviceTracker.Device) -> void:
	header.text = (
		"// CONTROLS : CONTROLLER"
		if device == DeviceTracker.Device.CONTROLLER
		else "// CONTROLS : KEYBOARD & MOUSE"
	)


func _check_one_panel() -> void:
	Contract.invariant(
		controls_panel.visible != options_panel.visible,
		"exactly one panel must show",
	)


func _on_quit() -> void:
	quit_requested.emit()
	if not quit_on_request:
		return
	pause_controller.set_paused(false)
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(title_scene)
