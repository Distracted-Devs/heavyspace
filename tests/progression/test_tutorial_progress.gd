extends GutTest

const Part := TutorialProgress.Part

var _was_enabled: bool
var _tutorial: TutorialProgress


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_tutorial = TutorialProgress.new()


func after_each() -> void:
	Contract.enabled = _was_enabled


func test_a_new_session_starts_with_the_controls() -> void:
	assert_eq(_tutorial.next_part(), Part.CONTROLS)
	assert_false(_tutorial.is_done(Part.CONTROLS))
	assert_false(_tutorial.is_done(Part.OBJECTIVE))


func test_the_objective_follows_the_controls() -> void:
	_tutorial.finish(Part.CONTROLS)
	assert_eq(_tutorial.next_part(), Part.OBJECTIVE)
	_tutorial.finish(Part.OBJECTIVE)
	assert_eq(_tutorial.next_part(), Part.NONE)


func test_finishing_twice_changes_nothing() -> void:
	_tutorial.finish(Part.CONTROLS)
	_tutorial.finish(Part.CONTROLS)
	assert_true(_tutorial.is_done(Part.CONTROLS))
	assert_eq(_tutorial.next_part(), Part.OBJECTIVE)


func test_reset_starts_again() -> void:
	_tutorial.finish(Part.CONTROLS)
	_tutorial.finish(Part.OBJECTIVE)
	_tutorial.reset()
	assert_eq(_tutorial.next_part(), Part.CONTROLS)


func test_none_is_never_done_and_cannot_be_finished() -> void:
	assert_false(_tutorial.is_done(Part.NONE))
	_tutorial.finish(Part.NONE)
	assert_push_error(
		"[Contract] Pre-condition broken: only controls or objective can finish"
	)
	assert_eq(_tutorial.next_part(), Part.CONTROLS)


func test_the_autoload_holds_the_sessions_tutorial() -> void:
	var run_progress := get_tree().root.get_node("RunProgress")
	assert_true(run_progress.tutorial is TutorialProgress)
