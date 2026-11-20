class_name BodySpec
extends RefCounted

var path := PackedInt32Array()
var depth := 0
var is_pickup := false
var radius := 1.0
var mass := 1.0
var child_count := 0
var pickup_count := 0
var belt_inner := 0.0
var belt_outer := 0.0
var system_radius := 1.0
var orbit_radius := 0.0
var angular_speed := 0.0
var phase := 0.0
var orbit_u := Vector3.RIGHT
var orbit_v := Vector3.FORWARD
var system_normal := Vector3.UP
var linear_speed := 0.0


func orbit_normal() -> Vector3:
	return orbit_u.cross(orbit_v)


func key() -> String:
	return ",".join(Array(path).map(str))


func orbit_offset(time: float) -> Vector3:
	var angle := phase + angular_speed * time
	return orbit_radius * (cos(angle) * orbit_u + sin(angle) * orbit_v)


func orbit_velocity(time: float) -> Vector3:
	var angle := phase + angular_speed * time
	return (
		orbit_radius * angular_speed
		* (-sin(angle) * orbit_u + cos(angle) * orbit_v)
	)
