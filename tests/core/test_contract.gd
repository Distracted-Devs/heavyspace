extends GutTest

var _was_enabled: bool


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true


func after_each() -> void:
	Contract.enabled = _was_enabled


func test_passing_checks_return_true_and_report_nothing() -> void:
	assert_true(Contract.require(true, "unused"))
	assert_true(Contract.ensure(true, "unused"))
	assert_true(Contract.invariant(true, "unused"))
	assert_push_error_count(0)


func test_broken_require_reports_one_pre_condition_error() -> void:
	assert_false(Contract.require(false, "amount must be positive"))
	assert_push_error(
		"[Contract] Pre-condition broken: amount must be positive"
	)
	assert_push_error_count(1, "exactly one error should be reported")


func test_broken_ensure_reports_one_post_condition_error() -> void:
	assert_false(Contract.ensure(false, "mass must increase"))
	assert_push_error("[Contract] Post-condition broken: mass must increase")
	assert_push_error_count(1, "exactly one error should be reported")


func test_broken_invariant_reports_one_invariant_error() -> void:
	assert_false(Contract.invariant(false, "mass below minimum"))
	assert_push_error("[Contract] Invariant broken: mass below minimum")
	assert_push_error_count(1, "exactly one error should be reported")


func test_disabled_checks_return_true_and_report_nothing() -> void:
	Contract.enabled = false
	assert_true(Contract.require(false, "unused"))
	assert_true(Contract.ensure(false, "unused"))
	assert_true(Contract.invariant(false, "unused"))
	assert_push_error_count(0)
