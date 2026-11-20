class_name LoseOverlay
extends CanvasLayer

@export_group("Components")
@export var lose_controller: LoseController


func _ready() -> void:
	visible = false
	lose_controller.lost_game.connect(_on_lost_game)


func _on_lost_game(_other: Node3D) -> void:
	visible = true
