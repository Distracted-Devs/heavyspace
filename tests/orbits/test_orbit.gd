extends GutTest

const EPSILON := 1.0e-4

var _was_enabled: bool


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true


func after_each() -> void:
	Contract.enabled = _was_enabled


func _distance_from_axis(point: Vector3) -> float:
	return Vector2(point.x, point.z).length()


func _angle_of(point: Vector3) -> float:
	return atan2(point.z, point.x)


func test_position_lies_on_the_orbit_circle_at_its_height() -> void:
	for time in [0.0, 1.5, 37.0, 1000.0]:
		var point := Orbit.position(80.0, 4.0, 0.3, 0.2, time)
		assert_almost_eq(_distance_from_axis(point), 80.0, EPSILON)
		assert_almost_eq(point.y, 4.0, EPSILON)


func test_position_starts_at_its_phase() -> void:
	var point := Orbit.position(10.0, 0.0, 1.2, 0.5, 0.0)
	assert_almost_eq(_angle_of(point), 1.2, EPSILON)


func test_position_angle_advances_with_angular_speed() -> void:
	var point := Orbit.position(10.0, 0.0, 0.1, 0.25, 2.0)
	assert_almost_eq(_angle_of(point), 0.1 + 0.25 * 2.0, EPSILON)


func test_position_repeats_every_period() -> void:
	var speed := 0.4
	var period := TAU / speed
	var start := Orbit.position(30.0, -2.0, 0.7, speed, 5.0)
	var later := Orbit.position(30.0, -2.0, 0.7, speed, 5.0 + period)
	assert_almost_eq(later.distance_to(start), 0.0, 1.0e-3)


func test_negative_angular_speed_orbits_the_other_way() -> void:
	var prograde := Orbit.position(10.0, 0.0, 0.0, 0.5, 1.0)
	var retrograde := Orbit.position(10.0, 0.0, 0.0, -0.5, 1.0)
	assert_almost_eq(_angle_of(prograde), 0.5, EPSILON)
	assert_almost_eq(_angle_of(retrograde), -0.5, EPSILON)


func test_velocity_is_flat_and_perpendicular_to_the_offset() -> void:
	for speed in [0.3, -0.3]:
		var point := Orbit.position(50.0, 3.0, 0.9, speed, 12.0)
		var velocity := Orbit.velocity(50.0, 3.0, 0.9, speed, 12.0)
		var offset := Vector3(point.x, 0.0, point.z)
		assert_almost_eq(velocity.y, 0.0, EPSILON)
		assert_almost_eq(velocity.dot(offset), 0.0, 1.0e-3)


func test_velocity_length_is_angular_speed_times_radius() -> void:
	var velocity := Orbit.velocity(50.0, 3.0, 0.9, -0.3, 12.0)
	assert_almost_eq(velocity.length(), 0.3 * 50.0, EPSILON)


func test_velocity_is_the_time_derivative_of_position() -> void:
	var step := 1.0e-2
	for speed in [0.3, -0.3]:
		var before := Orbit.position(50.0, 3.0, 0.9, speed, 12.0 - step)
		var after := Orbit.position(50.0, 3.0, 0.9, speed, 12.0 + step)
		var estimate := (after - before) / (2.0 * step)
		var velocity := Orbit.velocity(50.0, 3.0, 0.9, speed, 12.0)
		assert_almost_eq(estimate.distance_to(velocity), 0.0, 1.0e-3)


func test_circular_angular_speed_balances_inverse_square_gravity() -> void:
	var mass := 1.0e7
	var radius := 9000.0
	var gravity := 10.0
	var omega := Orbit.circular_angular_speed(mass, radius, gravity)
	assert_gt(omega, 0.0)
	var centripetal := omega * omega * radius
	var pull := gravity * mass / (radius * radius)
	assert_almost_eq(centripetal / pull, 1.0, EPSILON)


func test_circular_orbit_is_slower_further_out() -> void:
	var inner := Orbit.circular_angular_speed(1.0e4, 80.0, 10.0)
	var outer := Orbit.circular_angular_speed(1.0e4, 130.0, 10.0)
	assert_gt(inner, outer)


func test_non_positive_orbit_radius_is_reported() -> void:
	assert_eq(Orbit.position(0.0, 0.0, 0.0, 1.0, 0.0), Vector3.ZERO)
	assert_push_error(
		"[Contract] Pre-condition broken: orbit_radius must be positive"
	)
	assert_eq(Orbit.velocity(-1.0, 0.0, 0.0, 1.0, 0.0), Vector3.ZERO)
	assert_push_error(
		"[Contract] Pre-condition broken: orbit_radius must be positive"
	)


func test_non_finite_input_is_reported() -> void:
	assert_eq(Orbit.position(10.0, 0.0, 0.0, INF, 0.0), Vector3.ZERO)
	assert_push_error(
		"[Contract] Pre-condition broken: orbit inputs must be finite"
	)
	assert_eq(Orbit.velocity(10.0, NAN, 0.0, 1.0, 0.0), Vector3.ZERO)
	assert_push_error(
		"[Contract] Pre-condition broken: orbit inputs must be finite"
	)


func test_circular_angular_speed_requires_positive_inputs() -> void:
	assert_eq(Orbit.circular_angular_speed(0.0, 10.0, 10.0), 0.0)
	assert_push_error(
		"[Contract] Pre-condition broken: parent_mass must be positive"
	)
	assert_eq(Orbit.circular_angular_speed(1.0, 10.0, 0.0), 0.0)
	assert_push_error(
		"[Contract] Pre-condition broken: gravity_constant must be positive"
	)
	assert_eq(Orbit.circular_angular_speed(1.0, 0.0, 10.0), 0.0)
	assert_push_error(
		"[Contract] Pre-condition broken: orbit_radius must be positive"
	)
