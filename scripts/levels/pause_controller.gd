class_name PauseController
extends Node

signal paused_changed(paused: bool)
signal restarting

@export var reload_on_restart := true
@export var lose_controller: LoseController

var paused: bool:
	get:
		return get_tree().paused


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		set_paused(not paused)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart") and _crashed():
		get_viewport().set_input_as_handled()
		restart()


func restart() -> void:
	set_paused(false)
	restarting.emit()
	if reload_on_restart:
		get_tree().reload_current_scene()


func set_paused(value: bool) -> void:
	if value == paused:
		return
	get_tree().paused = value
	paused_changed.emit(value)


func _crashed() -> bool:
	return lose_controller != null and lose_controller.lost
