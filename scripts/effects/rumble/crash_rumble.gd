class_name CrashRumble
extends RumbleSource

const LIGHT_FADE := 1.0
const HEAVY_FADE := 2.0

@export_group("Components")
@export var lose_controller: LoseController:
	set(value):
		if lose_controller != null:
			lose_controller.lost_game.disconnect(_on_lost_game)
		lose_controller = value
		if lose_controller != null:
			lose_controller.lost_game.connect(_on_lost_game)

@export_group("Rumble")
@export_range(0.0, 1.0, 0.01) var level := 1.0:
	set(value):
		if motor_valid(value, "level"):
			level = value
@export_range(0.05, 5.0, 0.05, "or_greater") var duration := 0.8:
	set(value):
		if positive(value, "duration"):
			duration = value


func _on_lost_game(_other: Node3D) -> void:
	if rumble == null:
		return
	rumble.pulse(level, 0.0, duration, LIGHT_FADE)
	rumble.pulse(0.0, level, duration, HEAVY_FADE)
