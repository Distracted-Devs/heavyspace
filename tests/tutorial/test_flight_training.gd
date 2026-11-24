extends GutTest

const HOLD_TIME := 0.5
const GAP := 0.4
const MOUSE_DISTANCE := 100.0
const FRAME := 0.05

var _was_enabled: bool
var _training: FlightTraining


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_training = FlightTraining.new()
	_training.steps = [
		_step("PITCH", [&"pitch_up", &"pitch_down"], false),
		_step("LOOK", [&"look_up"], true),
	]
	_training.hold_time = HOLD_TIME
	_training.step_gap = GAP
	_training.mouse_distance = MOUSE_DISTANCE
	_training.set_process(false)
	add_child_autofree(_training)
	watch_signals(_training)


func after_each() -> void:
	for action: StringName in [&"pitch_up", &"pitch_down", &"look_up"]:
		Input.action_release(action)
	Contract.enabled = _was_enabled


func _step(
	title: String,
	actions: Array[StringName],
	mouse: bool,
) -> TrainingStep:
	var step := TrainingStep.new()
	step.title = title
	step.actions = actions
	step.counts_mouse_motion = mouse
	return step


func _run(seconds: float) -> void:
	for frame in roundi(seconds / FRAME):
		_training.advance(FRAME)


func _finish_first_step() -> void:
	Input.action_press(&"pitch_down")
	_run(HOLD_TIME + FRAME)
	Input.action_release(&"pitch_down")
	_run(GAP + FRAME)


func test_start_begins_the_first_step() -> void:
	_training.start()
	assert_true(_training.running)
	assert_eq(_training.index, 0)
	assert_eq(_training.progress, 0.0)
	assert_eq(_training.current_step().title, "PITCH")
	assert_signal_emitted_with_parameters(_training, "step_started", [0])


func test_holding_any_of_the_actions_fills_the_step() -> void:
	_training.start()
	Input.action_press(&"pitch_down")
	_run(HOLD_TIME * 0.5)
	assert_almost_eq(_training.progress, 0.5, 1.0e-4)
	_run(HOLD_TIME)
	assert_eq(_training.progress, 1.0)
	assert_signal_emit_count(_training, "step_completed", 1)


func test_a_light_touch_does_not_count() -> void:
	_training.start()
	Input.action_press(&"pitch_up", 0.1)
	_run(HOLD_TIME * 2.0)
	assert_eq(_training.progress, 0.0)


func test_the_next_step_starts_after_the_gap() -> void:
	_training.start()
	Input.action_press(&"pitch_down")
	_run(HOLD_TIME + FRAME)
	Input.action_release(&"pitch_down")
	assert_eq(_training.index, 0)
	_run(GAP + FRAME)
	assert_eq(_training.index, 1)
	assert_eq(_training.progress, 0.0)
	assert_signal_emitted_with_parameters(_training, "step_started", [1])


func test_mouse_motion_fills_only_a_mouse_step() -> void:
	_training.start()
	_training.add_mouse_motion(Vector2(30.0, 40.0))
	assert_eq(_training.progress, 0.0)
	_finish_first_step()
	_training.add_mouse_motion(Vector2(30.0, 40.0))
	assert_almost_eq(_training.progress, 0.5, 1.0e-4)


func test_finishing_the_last_step_finishes_once() -> void:
	_training.start()
	_finish_first_step()
	_training.add_mouse_motion(Vector2(0.0, MOUSE_DISTANCE * 3.0))
	assert_eq(_training.progress, 1.0)
	_run(GAP + FRAME)
	_run(GAP)
	assert_false(_training.running)
	assert_null(_training.current_step())
	assert_signal_emit_count(_training, "finished", 1)


func test_nothing_happens_before_it_starts() -> void:
	Input.action_press(&"pitch_down")
	_run(HOLD_TIME * 2.0)
	_training.add_mouse_motion(Vector2.ONE * 1000.0)
	assert_eq(_training.progress, 0.0)
	assert_signal_not_emitted(_training, "step_completed")


func test_starting_without_steps_is_reported() -> void:
	var training: FlightTraining = add_child_autofree(FlightTraining.new())
	training.start()
	assert_push_error(
		"[Contract] Pre-condition broken: steps must not be empty"
	)
	assert_false(training.running)


func test_bad_values_are_reported_and_ignored() -> void:
	_training.hold_time = 0.0
	_training.input_threshold = 1.5
	_training.mouse_distance = 0.0
	_training.step_gap = -1.0
	assert_push_error("hold_time must be positive")
	assert_push_error("input_threshold must be within (0, 1]")
	assert_push_error("mouse_distance must be positive")
	assert_push_error("step_gap must not be negative")
	assert_eq(_training.hold_time, HOLD_TIME)
	assert_eq(_training.step_gap, GAP)
