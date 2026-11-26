extends GutTest

const PHYSICS_DELTA := 1.0 / 60.0

var _was_enabled: bool
var _fuel: FuelComponent


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_fuel = FuelComponent.new()
	_fuel.set_physics_process(false)
	add_child_autofree(_fuel)


func after_each() -> void:
	Contract.enabled = _was_enabled


func _step(frames: int) -> void:
	for i in frames:
		_fuel._physics_process(PHYSICS_DELTA)


func test_tank_starts_full() -> void:
	assert_eq(_fuel.fuel, _fuel.tank_size)


func test_draw_removes_and_returns_the_amount() -> void:
	assert_almost_eq(_fuel.draw(0.25), 0.25, 1e-9)
	assert_almost_eq(_fuel.fuel, 0.75, 1e-9)


func test_draw_on_low_tank_returns_only_what_is_left() -> void:
	_fuel.draw(0.75)
	assert_almost_eq(_fuel.draw(0.5), 0.25, 1e-9)
	assert_eq(_fuel.fuel, 0.0)
	assert_eq(_fuel.draw(0.5), 0.0)


func test_negative_draw_is_reported_and_removes_nothing() -> void:
	assert_eq(_fuel.draw(-0.1), 0.0)
	assert_push_error(
		"[Contract] Pre-condition broken: draw amount must not be negative"
	)
	assert_eq(_fuel.fuel, _fuel.tank_size)


func test_empty_tank_refills_in_refill_time() -> void:
	_fuel.draw(_fuel.tank_size)
	_step(1)
	_step(roundi(_fuel.refill_time / PHYSICS_DELTA / 2.0))
	assert_almost_eq(_fuel.fuel, _fuel.tank_size / 2.0, 1e-6)
	_step(roundi(_fuel.refill_time / PHYSICS_DELTA / 2.0))
	assert_almost_eq(_fuel.fuel, _fuel.tank_size, 1e-6)


func test_refill_never_exceeds_tank_size() -> void:
	_fuel.draw(0.01)
	_step(120)
	assert_eq(_fuel.fuel, _fuel.tank_size)


func test_no_refill_on_a_frame_with_boosting() -> void:
	_fuel.draw(0.5)
	_step(1)
	assert_almost_eq(_fuel.fuel, 0.5, 1e-9)


func test_boosting_on_empty_tank_blocks_refill() -> void:
	_fuel.draw(_fuel.tank_size)
	for i in 30:
		_fuel.draw(0.1)
		_step(1)
	assert_eq(_fuel.fuel, 0.0)


func test_zero_draw_does_not_block_refill() -> void:
	_fuel.draw(0.5)
	_step(1)
	_fuel.draw(0.0)
	_step(1)
	assert_gt(_fuel.fuel, 0.5)


func test_refill_waits_for_refill_delay() -> void:
	_fuel.refill_delay = 0.5
	_fuel.draw(0.5)
	_step(1)
	_step(roundi(0.5 / PHYSICS_DELTA) - 1)
	assert_almost_eq(_fuel.fuel, 0.5, 1e-9)
	_step(2)
	assert_gt(_fuel.fuel, 0.5)


func test_shrinking_tank_clamps_fuel() -> void:
	_fuel.tank_size = 0.4
	assert_eq(_fuel.fuel, 0.4)


func test_non_positive_settings_are_reported_and_ignored() -> void:
	for setting in ["tank_size", "burn_rate", "refill_time"]:
		var old_value: float = _fuel.get(setting)
		_fuel.set(setting, 0.0)
		assert_push_error(
			"[Contract] Pre-condition broken: %s must be positive" % setting
		)
		assert_eq(_fuel.get(setting), old_value, setting)


func test_negative_refill_delay_is_reported_and_ignored() -> void:
	var refill_delay := _fuel.refill_delay
	_fuel.refill_delay = -1.0
	assert_push_error(
		"[Contract] Pre-condition broken: refill_delay must not be negative"
	)
	assert_eq(_fuel.refill_delay, refill_delay)


func test_fuel_changed_emits_once_per_change() -> void:
	watch_signals(_fuel)
	_fuel.draw(0.25)
	assert_signal_emit_count(_fuel, "fuel_changed", 1)
	assert_signal_emitted_with_parameters(_fuel, "fuel_changed", [0.75])


func test_full_idle_tank_does_not_emit_fuel_changed() -> void:
	watch_signals(_fuel)
	_step(10)
	assert_signal_not_emitted(_fuel, "fuel_changed")
