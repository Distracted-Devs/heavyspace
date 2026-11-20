class_name WarpOutDebug
extends Node


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("warp_out") and OS.is_debug_build():
		print("[Debug] Warp out pressed")
