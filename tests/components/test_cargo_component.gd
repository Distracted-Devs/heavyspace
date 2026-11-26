extends GutTest

var _was_enabled: bool
var _cargo: CargoComponent


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_cargo = CargoComponent.new()
	add_child_autofree(_cargo)
	watch_signals(_cargo)


func after_each() -> void:
	Contract.enabled = _was_enabled


func test_starts_empty_with_its_tanks_full_capacity() -> void:
	assert_eq(_cargo.capacity(), _cargo.tank_size * _cargo.tanks)
	assert_eq(_cargo.stored, 0.0)


func test_add_returns_what_fits_and_clamps_at_capacity() -> void:
	assert_almost_eq(_cargo.add(3.0), 3.0, 1e-9)
	assert_almost_eq(_cargo.add(3.0), 2.0, 1e-9)
	assert_almost_eq(_cargo.stored, 5.0, 1e-9)
	assert_eq(_cargo.add(1.0), 0.0)
	assert_true(_cargo.is_full())


func test_tanks_fill_in_order() -> void:
	_cargo.tanks = 3
	_cargo.add(7.5)
	assert_eq(_cargo.full_tanks(), 1)
	assert_almost_eq(_cargo.fill_of(0), 1.0, 1e-9)
	assert_almost_eq(_cargo.fill_of(1), 0.5, 1e-9)
	assert_eq(_cargo.fill_of(2), 0.0)
	assert_false(_cargo.is_full())


func test_every_tank_full_counts_as_full() -> void:
	_cargo.tanks = 2
	_cargo.add(10.0)
	assert_eq(_cargo.full_tanks(), 2)
	assert_true(_cargo.is_full())


func test_changed_is_emitted_with_the_new_amount() -> void:
	_cargo.add(2.0)
	assert_signal_emitted_with_parameters(_cargo, "changed", [2.0])


func test_adding_nothing_emits_nothing() -> void:
	_cargo.add(0.0)
	assert_signal_not_emitted(_cargo, "changed")


func test_empty_clears_the_cargo() -> void:
	_cargo.add(4.0)
	_cargo.empty()
	assert_eq(_cargo.stored, 0.0)


func test_fewer_tanks_clamp_what_is_stored() -> void:
	_cargo.tanks = 2
	_cargo.add(8.0)
	_cargo.tanks = 1
	assert_almost_eq(_cargo.stored, 5.0, 1e-9)


func test_negative_amount_is_reported_and_adds_nothing() -> void:
	assert_eq(_cargo.add(-1.0), 0.0)
	assert_push_error("amount must not be negative")
	assert_eq(_cargo.stored, 0.0)


func test_tank_out_of_range_is_reported() -> void:
	assert_eq(_cargo.fill_of(1), 0.0)
	assert_push_error("tank must be within [0, tanks)")


func test_bad_settings_are_reported_and_ignored() -> void:
	var capacity := _cargo.capacity()
	_cargo.tank_size = 0.0
	assert_push_error("tank_size must be positive")
	_cargo.tanks = 0
	assert_push_error("tanks must be at least 1")
	assert_eq(_cargo.capacity(), capacity)
