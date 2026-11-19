class_name PlayerInputComponent
extends InputComponent


func _update_intent(_delta: float) -> void:
	thrust_intent = Vector3(
		0.0,
		0.0,
		-Input.get_action_strength("back_thruster"),
	)
	rotation_intent = Vector3(
		0.0,
		Input.get_axis("turn_right", "turn_left"),
		Input.get_axis("roll_right", "roll_left"),
	)
