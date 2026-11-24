class_name SkillNode
extends Resource

@export var id: StringName
@export var title := ""
@export var effect: SkillEffect
@export_range(0.0, 10.0, 0.01, "or_greater") var step := 0.2:
	set(value):
		if not Contract.require(value >= 0.0, "step must not be negative"):
			return
		step = value
@export_range(0.01, 1000.0, 0.01, "or_greater") var cost := 10.0:
	set(value):
		if not Contract.require(value > 0.0, "cost must be positive"):
			return
		cost = value
@export_range(1, 20, 1, "or_greater") var max_buys := 1:
	set(value):
		if not Contract.require(value >= 1, "max_buys must be at least 1"):
			return
		max_buys = value
@export_range(0, 100, 1, "or_greater") var required_level := 0:
	set(value):
		var message := "required_level must not be negative"
		if not Contract.require(value >= 0, message):
			return
		required_level = value
@export var grid := Vector2.ZERO


func is_valid() -> bool:
	return id != &"" and effect != null
