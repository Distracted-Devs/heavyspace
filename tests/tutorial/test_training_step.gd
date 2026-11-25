extends GutTest


func test_a_new_step_counts_only_its_actions() -> void:
	var step := TrainingStep.new()
	assert_eq(step.actions.size(), 0)
	assert_false(step.counts_mouse_motion)
	assert_eq(step.keyboard_fallback, "")


func test_a_step_keeps_what_it_teaches() -> void:
	var step := TrainingStep.new()
	step.actions = [&"look_up", &"look_down"]
	step.keyboard_fallback = "mouse_xy"
	step.counts_mouse_motion = true
	assert_eq(Array(step.actions), [&"look_up", &"look_down"])
	assert_eq(step.keyboard_fallback, "mouse_xy")
	assert_true(step.counts_mouse_motion)
