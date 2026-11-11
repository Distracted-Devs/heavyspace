class_name AsteroidMission
extends Mission
## An asteroid the player has to reach. solid_body is what the ship collides
## with; detect_area is slightly larger and completes the mission when the
## ship gets close enough.

@export var solid_body: StaticBody3D
@export var detect_area: Area3D


func _ready() -> void:
	if detect_area:
		detect_area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _is_player_ship(body):
		complete()  # Spawns the completion effect.
		queue_free()
