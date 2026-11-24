class_name PlayerInputComponent
extends InputComponent

@export_group("Pitch")
@export var invert_pitch := false

@export_group("Look")
@export var mouse_sensitivity := 0.003
@export var capture_mouse := true

var look_intent := Vector2.ZERO
var mouse_look := Vector2.ZERO

var _pending_mouse_look := Vector2.ZERO


func _ready() -> void:
	_capture_mouse()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif what == NOTIFICATION_UNPAUSED:
		_capture_mouse()


func _capture_mouse() -> void:
	if capture_mouse:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


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
