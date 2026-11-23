extends GutTest

const TOLERANCE := Vector3.ONE * 1e-4

var _was_enabled: bool
var _body: RigidBody3D
var _mass: MassComponent
var _momentum: MomentumComponent


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_body = FakeBody.make()
	_mass = MassComponent.new()
	_mass.body = _body
	_mass.starting_mass = 2.0
	_momentum = MomentumComponent.new()
	_momentum.body = _body
	_momentum.mass_component = _mass
	_body.add_child(_mass)
	_body.add_child(_momentum)
	add_child_autofree(_body)


func after_each() -> void:
	Contract.enabled = _was_enabled


func test_gaining_mass_conserves_momentum() -> void:
	var velocity := Vector3(3.0, -1.0, 2.0)
	_body.linear_velocity = velocity
	_mass.current_mass = 5.0
	assert_almost_eq(_body.linear_velocity * 5.0, velocity * 2.0, TOLERANCE)


func test_losing_mass_speeds_the_ship_up() -> void:
	_body.linear_velocity = Vector3.FORWARD
	_mass.current_mass = 0.5
	assert_almost_eq(_body.linear_velocity, Vector3.FORWARD * 4.0, TOLERANCE)


func test_successive_changes_use_the_last_mass() -> void:
	_body.linear_velocity = Vector3.RIGHT * 6.0
	_mass.current_mass = 3.0
	_mass.current_mass = 4.0
	assert_almost_eq(_body.linear_velocity, Vector3.RIGHT * 3.0, TOLERANCE)


func test_switched_off_leaves_the_velocity_but_tracks_the_mass() -> void:
	_body.linear_velocity = Vector3.RIGHT
	_momentum.conserve_momentum = false
	_mass.current_mass = 4.0
	assert_eq(_body.linear_velocity, Vector3.RIGHT)
	_momentum.conserve_momentum = true
	_mass.current_mass = 8.0
	assert_almost_eq(_body.linear_velocity, Vector3.RIGHT * 0.5, TOLERANCE)


func test_a_frozen_body_is_left_alone_but_tracks_the_mass() -> void:
	_body.linear_velocity = Vector3.RIGHT
	_body.freeze = true
	_mass.current_mass = 4.0
	assert_eq(_body.linear_velocity, Vector3.RIGHT)
	_body.freeze = false
	_mass.current_mass = 8.0
	assert_almost_eq(_body.linear_velocity, Vector3.RIGHT * 0.5, TOLERANCE)


func test_missing_components_are_reported() -> void:
	var lonely := MomentumComponent.new()
	add_child_autofree(lonely)
	assert_push_error(
		"[Contract] Pre-condition broken: body and mass_component must be set"
	)


func test_a_zero_exponent_leaves_the_velocity_alone() -> void:
	_momentum.momentum_exponent = 0.0
	_body.linear_velocity = Vector3.RIGHT * 3.0
	_mass.current_mass = 8.0
	assert_almost_eq(_body.linear_velocity, Vector3.RIGHT * 3.0, TOLERANCE)


func test_the_exponent_scales_how_much_mass_slows_the_ship() -> void:
	_momentum.momentum_exponent = 0.5
	_body.linear_velocity = Vector3.BACK * 4.0
	_mass.current_mass = 8.0
	assert_almost_eq(_body.linear_velocity, Vector3.BACK * 2.0, TOLERANCE)


func test_negative_exponent_is_reported_and_ignored() -> void:
	_momentum.momentum_exponent = -1.0
	assert_push_error("momentum_exponent must not be negative")
	assert_eq(_momentum.momentum_exponent, 1.0)
