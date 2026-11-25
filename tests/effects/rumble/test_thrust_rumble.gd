extends RumbleFixture


func _thrust() -> ThrustRumble:
	var thrust: ThrustRumble = _add(ThrustRumble.new())
	thrust.engine_meter = _meter()
	return thrust


func test_thrust_rumbles_the_light_motor_by_acceleration() -> void:
	var thrust := _thrust()
	thrust.engine_meter.thrust_acceleration = 77.5
	thrust.update()
	assert_almost_eq(_mixer.weak(), thrust.max_weak * 0.5, 1e-5)
	assert_eq(_mixer.strong(), 0.0)
	thrust.engine_meter.thrust_acceleration = 1000.0
	thrust.update()
	assert_almost_eq(_mixer.weak(), thrust.max_weak, 1e-5)


func test_thrust_rumble_stops_with_the_boost() -> void:
	var thrust := _thrust()
	thrust.engine_meter.thrust_acceleration = 150.0
	thrust.update()
	thrust.engine_meter.thrust_acceleration = 0.0
	thrust.update()
	assert_eq(_mixer.weak(), 0.0)


func test_thrust_rumble_stops_once_flight_has_stopped() -> void:
	var thrust := _thrust()
	thrust.engine_meter.thrust_acceleration = 150.0
	thrust.update()
	thrust.engine_meter.body.freeze = true
	thrust.update()
	assert_eq(_mixer.weak(), 0.0)


func test_a_missing_meter_is_reported() -> void:
	var thrust: ThrustRumble = _add(ThrustRumble.new())
	thrust.update()
	assert_push_error("engine_meter must be set")


func test_bad_settings_are_reported_and_ignored() -> void:
	var thrust: ThrustRumble = _add(ThrustRumble.new())
	thrust.max_weak = 1.5
	assert_push_error("max_weak must be within [0, 1]")
	thrust.max_accel = 1.0
	assert_push_error("max_accel must be above min_accel")
	assert_eq(thrust.max_weak, 0.35)
