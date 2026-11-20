class_name PlayerInputComponent
extends InputComponent

@export_group("Pitch")
@export var invert_pitch := false


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
