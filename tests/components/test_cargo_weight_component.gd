extends GutTest

var _was_enabled: bool
var _body: RigidBody3D
var _mass: MassComponent
var _cargo: CargoComponent
var _weight: CargoWeightComponent


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_body = FakeBody.make()
	_mass = MassComponent.new()
	_mass.body = _body
	_body.add_child(_mass)
	_cargo = CargoComponent.new()
	_cargo.tank_size = 10.0
	_body.add_child(_cargo)
	_weight = CargoWeightComponent.new()
	_weight.body = _body
	_weight.mass_component = _mass
	_weight.cargo = _cargo
	_weight.cargo_weight = 0.1
	_body.add_child(_weight)
	add_child_autofree(_body)


func after_each() -> void:
	Contract.enabled = _was_enabled


func test_an_empty_cargo_weighs_nothing() -> void:
	assert_almost_eq(_body.mass, 1.0, 1e-9)


func test_cargo_adds_its_weight_to_the_body() -> void:
	_cargo.add(10.0)
	assert_almost_eq(_weight.handling_mass(), 2.0, 1e-9)
	assert_almost_eq(_body.mass, 2.0, 1e-9)


func test_exponent_zero_ignores_the_cargo() -> void:
	_weight.mass_exponent = 0.0
	_cargo.add(10.0)
	assert_almost_eq(_body.mass, 1.0, 1e-9)


func test_exponent_two_makes_the_cargo_matter_more() -> void:
	_weight.mass_exponent = 2.0
	_cargo.add(10.0)
	assert_almost_eq(_body.mass, 4.0, 1e-9)


func test_picking_up_cargo_keeps_momentum() -> void:
	_body.linear_velocity = Vector3(10.0, 0.0, 0.0)
	_cargo.add(10.0)
	assert_almost_eq(_body.linear_velocity.x, 5.0, 1e-6)
	assert_almost_eq(_body.mass * _body.linear_velocity.x, 10.0, 1e-6)


func test_momentum_also_scales_the_gravity_drift() -> void:
	var receiver := GravityReceiverComponent.new()
	receiver.body = _body
	receiver.set_physics_process(false)
	_body.add_child(receiver)
	_weight.gravity_receiver = receiver
	receiver.drift = Vector3(0.0, 4.0, 0.0)
	_cargo.add(10.0)
	assert_almost_eq(receiver.drift.y, 2.0, 1e-6)


func test_without_momentum_the_velocity_is_left_alone() -> void:
	_weight.conserve_momentum = false
	_body.linear_velocity = Vector3(10.0, 0.0, 0.0)
	_cargo.add(10.0)
	assert_almost_eq(_body.linear_velocity.x, 10.0, 1e-6)


func test_a_frozen_body_keeps_its_velocity() -> void:
	_body.freeze = true
	_body.linear_velocity = Vector3(10.0, 0.0, 0.0)
	_cargo.add(10.0)
	assert_almost_eq(_body.mass, 2.0, 1e-9)
	assert_almost_eq(_body.linear_velocity.x, 10.0, 1e-6)


func test_a_core_mass_change_keeps_the_cargo_weight() -> void:
	_cargo.add(10.0)
	_mass.current_mass = 2.0
	assert_almost_eq(_body.mass, 3.0, 1e-9)


func test_thrust_accelerates_a_loaded_ship_less() -> void:
	_cargo.add(10.0)
	_body.apply_central_force(Vector3(0.0, 0.0, -10.0))
	await wait_physics_frames(2)
	var loaded := _body.linear_velocity.length()
	_cargo.empty()
	_body.linear_velocity = Vector3.ZERO
	_body.apply_central_force(Vector3(0.0, 0.0, -10.0))
	await wait_physics_frames(2)
	assert_almost_eq(loaded * 2.0, _body.linear_velocity.length(), 1e-3)


func test_missing_components_are_reported() -> void:
	var weight := CargoWeightComponent.new()
	add_child_autofree(weight)
	assert_push_error("body, mass_component and cargo must be set")


func test_bad_settings_are_reported_and_ignored() -> void:
	var cargo_weight := _weight.cargo_weight
	_weight.cargo_weight = -1.0
	assert_push_error("cargo_weight must not be negative")
	var mass_exponent := _weight.mass_exponent
	_weight.mass_exponent = -1.0
	assert_push_error("mass_exponent must not be negative")
	assert_eq(_weight.cargo_weight, cargo_weight)
	assert_eq(_weight.mass_exponent, mass_exponent)
