class_name PauseOverlay
extends CanvasLayer

@export_group("Components")
@export var pause_controller: PauseController


func _ready() -> void:
	visible = false
	pause_controller.paused_changed.connect(_on_paused_changed)


func _on_paused_changed(paused: bool) -> void:
	visible = paused
