extends GutTest

var _was_enabled: bool
var _input: InputComponent
var _fuel: FuelComponent
var _particles: GPUParticles3D
var _effect: ThrustEffect


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_input = add_child_autofree(InputComponent.new())
	_input.set_physics_process(false)
	_fuel = add_child_autofree(FuelComponent.new())
	_fuel.set_physics_process(false)
	_particles = add_child_autofree(GPUParticles3D.new())
	_particles.emitting = false
	_effect = ThrustEffect.new()
	_effect.flight_input = _input
	_effect.fuel = _fuel
	_effect.particles = _particles
	_effect.set_process(false)
	add_child_autofree(_effect)


func after_each() -> void:
	Contract.enabled = _was_enabled


func test_emits_while_thrusting_with_fuel() -> void:
	_input.thrust_intent = Vector3(0.0, 0.0, -1.0)
	_effect.refresh()
	assert_true(_particles.emitting)


func test_stops_when_thrust_is_released() -> void:
	_input.thrust_intent = Vector3(0.0, 0.0, -1.0)
	_effect.refresh()
	_input.thrust_intent = Vector3.ZERO
	_effect.refresh()
	assert_false(_particles.emitting)


func test_thrust_below_the_threshold_does_not_emit() -> void:
	_input.thrust_intent = Vector3(0.0, 0.0, -_effect.threshold * 0.5)
	_effect.refresh()
	assert_false(_particles.emitting)


func test_empty_tank_does_not_emit() -> void:
	_fuel.draw(_fuel.fuel)
	_input.thrust_intent = Vector3(0.0, 0.0, -1.0)
	_effect.refresh()
	assert_false(_particles.emitting)


func test_missing_components_are_reported() -> void:
	_effect.particles = null
	_effect.refresh()
	assert_push_error(
		"[Contract] Pre-condition broken: "
		+ "flight_input, fuel and particles must be set"
	)


func test_threshold_outside_zero_to_one_is_reported_and_ignored() -> void:
	_effect.threshold = 1.0
	assert_push_error(
		"[Contract] Pre-condition broken: threshold must be within [0, 1)"
	)
	assert_eq(_effect.threshold, 0.05)
