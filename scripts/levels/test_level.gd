class_name TestLevel
extends Node3D

@export_group("Scenes")
@export var player: Player
@export var planet: Planet

func _ready() -> void:
	var player_spawn_position: Vector3 = planet.global_position
	player_spawn_position.z += planet.radius + 50.0
	player.global_position = player_spawn_position 
