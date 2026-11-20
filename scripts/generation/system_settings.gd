class_name SystemSettings
extends Resource

@export var level_seed := 0
@export var mass_law := MassLaw.new()

@export_group("Hierarchy")
@export var root_radius := 200.0
@export var max_depth := 3
@export var ratio_min := 0.1
@export var ratio_max := 0.25
@export var children_min := 2
@export var children_max := 4
@export var shell_gap := 0.3

@export_group("Pickups")
@export var pickups_per_body := 100
@export var pickup_ratio_min := 0.005
@export var pickup_ratio_max := 0.03
@export var min_pickup_radius := 0.05
@export var belt_gap := 0.25
@export var belt_width := 0.75

@export_group("Orbits")
@export_range(0.0, 90.0) var system_tilt_degrees := 30.0
@export_range(0.0, 90.0) var max_inclination_degrees := 4.0
@export_range(0.0, 90.0) var belt_inclination_degrees := 2.0
@export var speed_min := 0.2
@export var speed_max := 1.0


func is_valid() -> bool:
	return (
		Contract.require(root_radius > 0.0, "root_radius must be positive")
		and Contract.require(max_depth >= 0, "max_depth must not be negative")
		and Contract.require(
			0.0 < ratio_min and ratio_min <= ratio_max and ratio_max < 0.5,
			"size ratios must satisfy 0 < min <= max < 0.5",
		)
		and Contract.require(
			1 <= children_min and children_min <= children_max,
			"child counts must satisfy 1 <= min <= max",
		)
		and Contract.require(shell_gap >= 0.0, "shell_gap must not be negative")
		and Contract.require(
			pickups_per_body >= 0,
			"pickups_per_body must not be negative",
		)
		and Contract.require(
			(
				0.0 < pickup_ratio_min and pickup_ratio_min <= pickup_ratio_max
				and pickup_ratio_max < 0.5
			),
			"pickup ratios must satisfy 0 < min <= max < 0.5",
		)
		and Contract.require(
			belt_gap >= 0.0 and belt_width > 0.0,
			"belt_gap must not be negative and belt_width must be positive",
		)
		and Contract.require(
			0.0 < speed_min and speed_min <= speed_max,
			"orbit speeds must satisfy 0 < min <= max",
		)
		and Contract.require(
			(
				_is_angle(system_tilt_degrees)
				and _is_angle(max_inclination_degrees)
				and _is_angle(belt_inclination_degrees)
			),
			"tilt and inclination angles must be within [0, 90]",
		)
		and Contract.require(mass_law != null, "mass_law must be set")
	)


func _is_angle(degrees: float) -> bool:
	return degrees >= 0.0 and degrees <= 90.0
