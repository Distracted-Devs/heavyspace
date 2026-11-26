extends GutTest

var _was_enabled: bool
var _thruster: ThrusterComponent
var _fuel: FuelComponent
var _boost: MissingFuelBoostComponent


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_thruster = autofree(ThrusterComponent.new())
	_fuel = FuelComponent.new()
	_fuel.tank_size = 1.0
	_fuel.refill_time = 1000.0
	add_child_autofree(_fuel)
	_boost = MissingFuelBoostComponent.new()
	_boost.thruster = _thruster
	_boost.fuel = _fuel


func after_each() -> void:
	Contract.enabled = _was_enabled


func _start(bonus: float) -> void:
	_boost.bonus_per_missing = bonus
	add_child_autofree(_boost)


func test_a_full_tank_gives_no_boost() -> void:
	_start(1.0)
	assert_eq(_boost.boost(), 1.0)


func test_each_whole_tenth_missing_adds_its_share_of_the_bonus() -> void:
	_start(1.0)
	_fuel.draw(0.35)
	assert_almost_eq(_boost.missing(), 0.3, 1e-6)
	assert_almost_eq(_boost.boost(), 1.3, 1e-6)


func test_without_snapping_the_boost_follows_the_missing_fuel() -> void:
	_boost.snap_to_tenths = false
	_start(1.0)
	_fuel.draw(0.35)
	assert_almost_eq(_boost.boost(), 1.35, 1e-6)


func test_an_empty_tank_gives_the_whole_bonus() -> void:
	_start(2.0)
	_fuel.draw(1.0)
	assert_almost_eq(_boost.boost(), 3.0, 1e-6)


func test_no_bonus_gives_no_boost_even_when_empty() -> void:
	_start(0.0)
	_fuel.draw(1.0)
	assert_eq(_boost.boost(), 1.0)


func test_the_thruster_multiplier_follows_the_boost_each_frame() -> void:
	_start(1.0)
	_fuel.draw(0.55)
	await wait_physics_frames(2)
	assert_almost_eq(_thruster.thrust_multiplier, _boost.boost(), 1e-6)
	assert_almost_eq(_thruster.thrust_multiplier, 1.5, 1e-6)


func test_it_runs_before_the_thruster() -> void:
	var thruster_priority := _thruster.process_physics_priority
	assert_lt(_boost.process_physics_priority, thruster_priority)
	_boost.free()


func test_a_negative_bonus_is_reported_and_ignored() -> void:
	_start(1.0)
	var bonus_per_missing := _boost.bonus_per_missing
	_boost.bonus_per_missing = -1.0
	assert_push_error(
		"Pre-condition broken: bonus_per_missing must not be negative"
	)
	assert_eq(_boost.bonus_per_missing, bonus_per_missing)


func test_missing_references_are_reported_and_leave_it_inactive() -> void:
	_boost.thruster = null
	_start(1.0)
	assert_push_error(
		"[Contract] Pre-condition broken: thruster and fuel must be set"
	)
	await wait_physics_frames(2)
	assert_eq(_thruster.thrust_multiplier, 1.0)
