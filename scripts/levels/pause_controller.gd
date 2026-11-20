class_name PauseController
extends Node

signal paused_changed(paused: bool)

var paused: bool:
	get:
		return get_tree().paused


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		set_paused(not paused)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart"):
		set_paused(false)
		get_tree().reload_current_scene()


func set_paused(value: bool) -> void:
	if value == paused:
		return
	get_tree().paused = value
	paused_changed.emit(value)
