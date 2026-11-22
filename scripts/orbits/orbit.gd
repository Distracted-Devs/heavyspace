class_name Orbit


static func position(
	orbit_radius: float,
	height: float,
	phase: float,
	angular_speed: float,
	time: float,
) -> Vector3:
	if not _valid(orbit_radius, height, phase, angular_speed, time):
		return Vector3.ZERO
	var angle := phase + angular_speed * time
	var result := Vector3(
		cos(angle) * orbit_radius,
		height,
		sin(angle) * orbit_radius,
	)
	Contract.ensure(
		(
			is_equal_approx(Vector2(result.x, result.z).length(), orbit_radius)
			and is_equal_approx(result.y, height)
		),
		"position must lie on the orbit circle at its height",
	)
	return result


static func velocity(
	orbit_radius: float,
	height: float,
	phase: float,
	angular_speed: float,
	time: float,
) -> Vector3:
	if not _valid(orbit_radius, height, phase, angular_speed, time):
		return Vector3.ZERO
	var angle := phase + angular_speed * time
	var speed := angular_speed * orbit_radius
	var result := Vector3(-sin(angle) * speed, 0.0, cos(angle) * speed)
	Contract.ensure(
		is_equal_approx(result.length(), absf(speed)),
		"velocity length must be |angular_speed| * orbit_radius",
	)
	return result


static func circular_angular_speed(
	parent_mass: float,
	orbit_radius: float,
	gravity_constant: float,
) -> float:
	if not Contract.require(parent_mass > 0.0, "parent_mass must be positive"):
		return 0.0
	if not Contract.require(
		gravity_constant > 0.0,
		"gravity_constant must be positive",
	):
		return 0.0
	if not _positive_radius(orbit_radius):
		return 0.0
	if not Contract.require(
		is_finite(parent_mass * orbit_radius * gravity_constant),
		"orbit inputs must be finite",
	):
		return 0.0
	var result := sqrt(gravity_constant * parent_mass / pow(orbit_radius, 3.0))
	Contract.ensure(result > 0.0, "circular angular speed must be positive")
	return result


static func _valid(
	orbit_radius: float,
	height: float,
	phase: float,
	angular_speed: float,
	time: float,
) -> bool:
	if not _positive_radius(orbit_radius):
		return false
	return Contract.require(
		(
			is_finite(orbit_radius) and is_finite(height) and is_finite(phase)
			and is_finite(angular_speed) and is_finite(time)
		),
		"orbit inputs must be finite",
	)


static func _positive_radius(orbit_radius: float) -> bool:
	return Contract.require(orbit_radius > 0.0, "orbit_radius must be positive")
