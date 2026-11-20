class_name GeneratedLevel
extends Node3D

@export_group("Components")
@export var player: Player
@export var streamer: SystemStreamer
@export var spawner: PlayerSpawner


func _ready() -> void:
	player.size_component.mass_law = streamer.settings.mass_law
	player.size_component.apply_mass(player.mass_component.current_mass)
	if streamer.start():
		spawner.spawn()
