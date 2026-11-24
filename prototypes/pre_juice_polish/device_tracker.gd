extends Node

## Prototype device tracker: like PlayerInputComponent.active_device, but it
## keeps running while the game is paused or in the shop, so every prompt
## follows the device used last.

signal device_changed(device: int)

@export var deadzone := 0.2

var device: int = PlayerInputComponent.Device.KEYBOARD_MOUSE


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if (
		event is InputEventKey or event is InputEventMouseButton
		or event is InputEventMouseMotion
	):
		_set_device(PlayerInputComponent.Device.KEYBOARD_MOUSE)
	elif event is InputEventJoypadButton:
		_set_device(PlayerInputComponent.Device.CONTROLLER)
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) >= deadzone:
			_set_device(PlayerInputComponent.Device.CONTROLLER)


func _set_device(value: int) -> void:
	if value == device:
		return
	device = value
	device_changed.emit(value)
