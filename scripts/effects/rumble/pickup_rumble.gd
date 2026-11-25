class_name PickupRumble
extends RumbleSource

@export_group("Components")
@export var absorb_effect: AbsorbEffect:
	set(value):
		if absorb_effect != null:
			absorb_effect.absorbed.disconnect(_on_absorbed)
		absorb_effect = value
		if absorb_effect != null:
			absorb_effect.absorbed.connect(_on_absorbed)

@export_group("Rumble")
@export_range(0.0, 1.0, 0.01) var weak := 0.04:
	set(value):
		if motor_valid(value, "weak"):
			weak = value
@export_range(0.0, 1.0, 0.01) var strong := 0.07:
	set(value):
		if motor_valid(value, "strong"):
			strong = value
@export_range(0.01, 1.0, 0.01, "or_greater") var duration := 0.1:
	set(value):
		if positive(value, "duration"):
			duration = value
@export_range(0.1, 20.0, 0.1, "or_greater") var fade_power := 10.0:
	set(value):
		if positive(value, "fade_power"):
			fade_power = value


func _on_absorbed(_mass: float) -> void:
	if rumble != null:
		rumble.pulse(weak, strong, duration, fade_power)
