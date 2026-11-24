class_name PauseMenu
extends CanvasLayer

signal quit_requested

@export_group("Components")
@export var pause_controller: PauseController
@export var header: Label
@export var view: ControlsView
@export var resume_button: Button
@export var restart_button: Button
@export var quit_button: Button

@export_group("Quit")
@export var quit_on_request := true

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
	quit_button.pressed.connect(_on_quit)


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventJoypadButton
	if (
		visible and button and button.pressed
		and button.button_index == JOY_BUTTON_B
	):
		pause_controller.set_paused(false)
		get_viewport().set_input_as_handled()


func _on_paused_changed(paused: bool) -> void:
	visible = paused
	if paused:
		resume_button.grab_focus()


func _on_device_changed(device: DeviceTracker.Device) -> void:
	_name_device(device)


func _name_device(device: DeviceTracker.Device) -> void:
	header.text = (
		"// CONTROLS : CONTROLLER"
		if device == DeviceTracker.Device.CONTROLLER
		else "// CONTROLS : KEYBOARD & MOUSE"
	)


func _on_quit() -> void:
	quit_requested.emit()
	if quit_on_request:
		get_tree().quit()
