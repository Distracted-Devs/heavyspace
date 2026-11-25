extends GutTest

const STEP := 1.0 / 60.0

var _was_enabled: bool
var _body: RigidBody3D
var _input: InputComponent
var _fuel: FuelComponent
var _thruster: ThrusterComponent
var _meter: EngineMeterComponent


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_body = FakeBody.make()
	_body.mass = 2.0
	_input = InputComponent.new()
	_fuel = FuelComponent.new()
	_fuel.set_physics_process(false)
	_thruster = ThrusterComponent.new()
	_thruster.body = _body
	_thruster.flight_input = _input
	_thruster.back_thrust_force = 300.0
	_thruster.set_physics_process(false)
	_meter = EngineMeterComponent.new()
	_meter.body = _body
	_meter.flight_input = _input
	_meter.fuel = _fuel
	_meter.thruster = _thruster
	_meter.set_physics_process(false)
	for child in [_input, _fuel, _thruster, _meter]:
		_body.add_child(child)
	add_child_autofree(_body)


func after_each() -> void:
	Contract.enabled = _was_enabled


func _run(seconds: float) -> void:
	for step in roundi(seconds / STEP):
		_meter.update(STEP)


func test_boost_is_the_thrust_intent() -> void:
	_input.thrust_intent = Vector3(0.0, 0.0, -0.5)
	assert_almost_eq(_meter.boost(), 0.5, 1e-6)


func test_no_boost_without_fuel() -> void:
	_input.thrust_intent = Vector3.FORWARD
	_fuel.draw(_fuel.tank_size)
	assert_eq(_meter.boost(), 0.0)


func test_no_boost_once_flight_has_stopped() -> void:
	_input.thrust_intent = Vector3.FORWARD
	_body.freeze = true
	assert_eq(_meter.boost(), 0.0)


func test_strength_is_force_over_the_reference() -> void:
	assert_almost_eq(_meter.strength(), 2.0, 1e-6)
	_thruster.thrust_multiplier = 2.0
	assert_almost_eq(_meter.strength(), 4.0, 1e-6)
	_input.thrust_intent = Vector3.FORWARD
	assert_almost_eq(_meter.scaled_boost(), 2.0, 1e-6)


func test_thrust_acceleration_settles_on_the_engines_own() -> void:
	_input.thrust_intent = Vector3.FORWARD
	_run(2.0)
	assert_almost_eq(_meter.thrust_acceleration, 150.0, 0.5)


func test_thrust_acceleration_drops_to_zero_off_the_boost() -> void:
	_input.thrust_intent = Vector3.FORWARD
	_run(2.0)
	_input.thrust_intent = Vector3.ZERO
	_run(2.0)
	assert_eq(_meter.thrust_acceleration, 0.0)


func test_bad_settings_are_reported_and_ignored() -> void:
	_meter.reference_force = 0.0
	assert_push_error("reference_force must be positive")
	_meter.max_strength = 0.5
	assert_push_error("max_strength must be at least 1")
	_meter.accel_smoothing = 0.0
	assert_push_error("accel_smoothing must be positive")
	assert_eq(_meter.reference_force, 150.0)


func test_a_missing_component_is_reported() -> void:
	_meter.thruster = null
	_meter.update(STEP)
	assert_push_error("body, flight_input, fuel and thruster must be set")
