extends GutTest

var _was_enabled: bool
var _body: RigidBody3D
var _mass: MassComponent


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_body = RigidBody3D.new()
	_mass = MassComponent.new()
	_mass.body = _body
	_mass.starting_mass = 2.5
	_body.add_child(_mass)
	add_child_autofree(_body)


func after_each() -> void:
	Contract.enabled = _was_enabled


func test_body_mass_starts_at_starting_mass() -> void:
	assert_eq(_mass.current_mass, 2.5)
	assert_eq(_body.mass, 2.5)


func test_current_mass_keeps_body_mass_in_sync() -> void:
	_mass.current_mass = 3.5
	assert_eq(_body.mass, 3.5)


func test_non_positive_current_mass_is_reported_and_ignored() -> void:
	_mass.current_mass = 0.0
	assert_push_error(
		"[Contract] Pre-condition broken: current_mass must be positive"
	)
	assert_eq(_mass.current_mass, 2.5)
	assert_eq(_body.mass, 2.5)


func test_each_accepted_set_emits_mass_changed_once() -> void:
	watch_signals(_mass)
	_mass.current_mass = 4.0
	assert_signal_emit_count(_mass, "mass_changed", 1)
	assert_signal_emitted_with_parameters(_mass, "mass_changed", [4.0])


func test_rejected_set_does_not_emit_mass_changed() -> void:
	watch_signals(_mass)
	_mass.current_mass = -1.0
	assert_push_error(
		"[Contract] Pre-condition broken: current_mass must be positive"
	)
	assert_signal_not_emitted(_mass, "mass_changed")


func test_a_run_starts_at_starting_mass_times_start_multiplier() -> void:
	var body := RigidBody3D.new()
	var mass := MassComponent.new()
	mass.body = body
	mass.starting_mass = 2.0
	mass.start_multiplier = 1.5
	body.add_child(mass)
	add_child_autofree(body)
	assert_eq(mass.current_mass, 3.0)
	assert_eq(body.mass, 3.0)
	assert_eq(mass.starting_mass, 2.0)


func test_non_positive_start_multiplier_is_reported_and_ignored() -> void:
	_mass.start_multiplier = 0.0
	assert_push_error(
		"[Contract] Pre-condition broken: start_multiplier must be positive"
	)
	assert_eq(_mass.start_multiplier, 1.0)
