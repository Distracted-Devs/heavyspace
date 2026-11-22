class_name TierLayout
extends RefCounted

var plane := Basis.IDENTITY
var radius := PackedFloat64Array()
var mass := PackedFloat64Array()
var orbit_radius := PackedFloat64Array()
var height := PackedFloat64Array()
var phase := PackedFloat64Array()
var angular_speed := PackedFloat64Array()


func size() -> int:
	return radius.size()


func append(
	child_radius: float,
	child_mass: float,
	child_orbit_radius: float,
	child_height: float,
	child_phase: float,
	child_angular_speed: float,
) -> void:
	radius.append(child_radius)
	mass.append(child_mass)
	orbit_radius.append(child_orbit_radius)
	height.append(child_height)
	phase.append(child_phase)
	angular_speed.append(child_angular_speed)
	var count := size()
	Contract.invariant(
		(
			mass.size() == count and orbit_radius.size() == count
			and height.size() == count and phase.size() == count
			and angular_speed.size() == count
		),
		"layout arrays must have the same length",
	)
