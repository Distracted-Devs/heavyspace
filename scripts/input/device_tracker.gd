class_name DeviceTracker
extends Node

signal device_changed(device: Device)

enum Device {
	KEYBOARD_MOUSE,
	CONTROLLER,
}

@export_range(0.0, 1.0, 0.01) var switch_deadzone := 0.2:
	set(value):
		if not Contract.require(
			value >= 0.0 and value <= 1.0,
			"switch_deadzone must be within [0, 1]",
		):
			return
		switch_deadzone = value

var device := Device.KEYBOARD_MOUSE:
	set(value):
		if value == device:
			return
		device = value
		device_changed.emit(value)


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_controller() -> bool:
	return device == Device.CONTROLLER


func _input(event: InputEvent) -> void:
	if (
		event is InputEventKey or event is InputEventMouseButton
		or event is InputEventMouseMotion
	):
		device = Device.KEYBOARD_MOUSE
	elif event is InputEventJoypadButton:
		device = Device.CONTROLLER
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if absf(motion.axis_value) >= switch_deadzone:
			device = Device.CONTROLLER
