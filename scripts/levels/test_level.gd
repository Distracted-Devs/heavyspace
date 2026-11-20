class_name TestLevel
extends Node3D


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("warp_out") and OS.is_debug_build():
		print("[Debug] Warp out pressed")
