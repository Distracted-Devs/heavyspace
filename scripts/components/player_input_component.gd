class_name PlayerInputComponent
extends InputComponent

signal device_changed(device: Device)

enum Device {
	KEYBOARD_MOUSE,
	CONTROLLER,
}

@export_group("Pitch")
@export var invert_pitch := false

@export_group("Look")
@export var mouse_sensitivity := 0.003
@export var capture_mouse := true

@export_group("Device")
@export var device_switch_deadzone := 0.2

var look_intent := Vector2.ZERO
var mouse_look := Vector2.ZERO
var active_device := Device.KEYBOARD_MOUSE:
	set(value):
		if value == active_device:
			return
		active_device = value
		device_changed.emit(value)

var _pending_mouse_look := Vector2.ZERO


func _ready() -> void:
	if capture_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if (
		event is InputEventKey or event is InputEventMouseButton
		or event is InputEventMouseMotion
	):
		active_device = Device.KEYBOARD_MOUSE
	elif event is InputEventJoypadButton:
		active_device = Device.CONTROLLER
	elif event is InputEventJoypadMotion:
		var stick := event as InputEventJoypadMotion
		if absf(stick.axis_value) >= device_switch_deadzone:
			active_device = Device.CONTROLLER


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion:
		_pending_mouse_look += motion.relative * mouse_sensitivity


func _update_intent(_delta: float) -> void:
	var pitch := Input.get_axis("pitch_down", "pitch_up")
	thrust_intent = Vector3(
		0.0,
		0.0,
		-Input.get_action_strength("back_thruster"),
	)
	rotation_intent = Vector3(
		-pitch if invert_pitch else pitch,
		Input.get_axis("turn_right", "turn_left"),
		Input.get_axis("roll_right", "roll_left"),
	)
	look_intent = Input.get_vector(
		"look_left",
		"look_right",
		"look_up",
		"look_down",
	)
	mouse_look = _pending_mouse_look
	_pending_mouse_look = Vector2.ZERO
	Contract.ensure(
		Intent.is_within_unit(Vector3(look_intent.x, look_intent.y, 0.0)),
		"look intent axes must be within [-1, 1]",
	)
	Contract.ensure(mouse_look.is_finite(), "mouse look must be finite")
