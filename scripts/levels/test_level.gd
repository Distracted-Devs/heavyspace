class_name TestLevel
extends Node3D

@export_group("Scenes")
@export var player: Player
@export var planet: Planet

@export_group("Player Position")
@export var player_position_offset: Vector3 = Vector3(0.0, 1.0, 100.0)


func _ready() -> void:
	var player_spawn_position: Vector3 = planet.global_position
	player_spawn_position.z += planet.radius + player_position_offset.z
	player_spawn_position.y += planet.radius + player_position_offset.y
	player.global_position = player_spawn_position
