extends GutTest

var _was_enabled: bool


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true


func after_each() -> void:
	Contract.enabled = _was_enabled


func test_it_starts_and_ends_the_squash_at_full_length() -> void:
	assert_almost_eq(AbsorbSquash.along(0.0, 0.2, 0.3, 2.0), 1.0, 1e-6)
	assert_almost_eq(AbsorbSquash.along(0.2, 0.2, 0.3, 2.0), 1.0, 1e-6)


func test_it_is_flattest_halfway_through_the_anticipation() -> void:
	assert_almost_eq(AbsorbSquash.along(0.1, 0.2, 0.3, 2.0), 0.7, 1e-6)


func test_it_stretches_to_full_at_the_end() -> void:
	assert_almost_eq(AbsorbSquash.along(1.0, 0.2, 0.3, 2.0), 3.0, 1e-6)
	assert_almost_eq(AbsorbSquash.along(0.6, 0.2, 0.3, 2.0), 1.5, 1e-6)


func test_no_anticipation_goes_straight_to_the_stretch() -> void:
	assert_almost_eq(AbsorbSquash.along(0.5, 0.0, 0.3, 2.0), 1.5, 1e-6)


func test_bad_inputs_are_reported() -> void:
	AbsorbSquash.along(1.5, 0.2, 0.3, 2.0)
	assert_push_error("t must be within [0, 1]")
	AbsorbSquash.along(0.5, 1.0, 0.3, 2.0)
	assert_push_error("anticipation must be within [0, 1)")
	AbsorbSquash.along(0.5, 0.2, 1.0, 2.0)
	assert_push_error("squash must be within [0, 1)")
	AbsorbSquash.along(0.5, 0.2, 0.3, -1.0)
	assert_push_error("stretch must not be negative")
