extends Node3D


func _process(_delta: float) -> void:
	if Input.is_physical_key_pressed(KEY_R):
		get_tree().reload_current_scene()
	pass
