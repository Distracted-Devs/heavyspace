class_name TitleFraming
extends Resource

@export_range(0.5, 20.0, 0.01, "or_greater") var distance_radii := 2.67:
	set(value):
		var message := "distance_radii must be positive"
		if not Contract.require(value > 0.0, message):
			return
		distance_radii = value
@export_range(-89.0, 89.0, 0.5) var elevation_degrees := 28.0:
	set(value):
		if not Contract.require(
			value > -90.0 and value < 90.0,
			"elevation_degrees must be within (-90, 90)",
		):
			return
		elevation_degrees = value
@export var screen_point := Vector2(2.0 / 3.0, 2.0 / 3.0):
	set(value):
		if not Contract.require(
			value.x >= 0.0 and value.x <= 1.0
			and value.y >= 0.0 and value.y <= 1.0,
			"screen_point must be within [0, 1] on both axes",
		):
			return
		screen_point = value
