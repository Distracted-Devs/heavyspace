class_name SettingsBinder
extends Node

@export_group("Components")
@export var player_input: PlayerInputComponent

var settings: GameSettings


func _ready() -> void:
	if settings == null:
		settings = get_node_or_null(^"/root/Settings") as GameSettings
	if not Contract.require(
		settings != null and player_input != null,
		"settings and player_input must be set",
	):
		return
	settings.changed.connect(apply)
	apply()


func apply() -> void:
	player_input.invert_pitch = settings.invert_pitch
	Contract.ensure(
		player_input.invert_pitch == settings.invert_pitch,
		"the player's pitch must follow the setting",
	)
