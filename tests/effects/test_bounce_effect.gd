extends GutTest

const HZ := 2.0
const DISTANCE := 8.0
const BASE := Vector2(100.0, 50.0)

var _was_enabled: bool
var _target: Control
var _bounce: BounceEffect


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_target = add_child_autofree(Control.new())
	_bounce = BounceEffect.new()
	_bounce.target = _target
	_bounce.hz = HZ
	_bounce.distance = DISTANCE
	_bounce.base_position = BASE
	_bounce.set_process(false)
	add_child_autofree(_bounce)


func after_each() -> void:
	Contract.enabled = _was_enabled


func test_it_starts_at_the_base() -> void:
	_bounce.advance(0.0)
	assert_eq(_target.position, BASE)


func test_it_reaches_its_distance_half_a_period_in() -> void:
	_bounce.advance(0.5 / HZ)
	assert_almost_eq(
		_target.position,
		BASE + Vector2.UP * DISTANCE,
		Vector2.ONE * 1.0e-4,
	)


func test_it_is_back_at_the_base_each_period() -> void:
	_bounce.advance(1.0 / HZ)
	assert_almost_eq(_target.position, BASE, Vector2.ONE * 1.0e-4)


func test_it_only_moves_along_its_direction() -> void:
	_bounce.direction = Vector2.RIGHT
	for step in 20:
		_bounce.advance(0.03)
		var offset := _target.position - BASE
		assert_almost_eq(offset.y, 0.0, 1.0e-5)
		assert_between(offset.x, 0.0, DISTANCE + 1.0e-5)


func test_a_new_base_moves_the_bounce_with_it() -> void:
	_bounce.base_position = Vector2(10.0, 10.0)
	_bounce.advance(0.5 / HZ)
	assert_almost_eq(
		_target.position,
		Vector2(10.0, 10.0 - DISTANCE),
		Vector2.ONE * 1.0e-4,
	)


func test_turning_it_off_puts_it_back_at_the_base() -> void:
	_bounce.advance(0.5 / HZ)
	_bounce.active = false
	assert_eq(_target.position, BASE)
	_bounce.advance(0.2)
	assert_eq(_target.position, BASE)


func test_bad_values_are_reported_and_ignored() -> void:
	_bounce.hz = -1.0
	_bounce.distance = -1.0
	_bounce.direction = Vector2.ZERO
	assert_push_error("[Contract] Pre-condition broken: hz must be positive")
	assert_push_error(
		"[Contract] Pre-condition broken: distance must not be negative"
	)
	assert_push_error(
		"[Contract] Pre-condition broken: direction must not be zero"
	)
	assert_eq(_bounce.direction, Vector2.UP)
