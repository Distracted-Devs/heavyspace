extends Node3D


func _ready() -> void:
	pass


func _process(delta: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	var direction = Vector3.ZERO

	if Input.is_action_pressed("roll_right"):
		print("roll right not implemented")

	if Input.is_action_pressed("roll_left"):
		print("roll left not implemented")

	if Input.is_action_pressed("bottom_thruster"):
		print("bottom thruster not implemented")

	if Input.is_action_pressed("top_thruster"):
		print("top thruster not implemented")

	if Input.is_action_pressed("back_thruster"):
		print("back thruster not implemented")
