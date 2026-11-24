extends GutTest

const LABELS := preload("res://resources/ui/control_labels.tres")

var _was_enabled: bool


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true


func after_each() -> void:
	Contract.enabled = _was_enabled


func test_the_games_labels_are_valid_and_cover_every_control() -> void:
	assert_true(LABELS.require_valid())
	for action: StringName in [
		&"back_thruster",
		&"pitch_down",
		&"pitch_up",
		&"turn_left",
		&"turn_right",
		&"roll_left",
		&"roll_right",
		&"warp_out",
		&"restart",
		&"pause",
		&"look_up",
	]:
		assert_gte(LABELS.index_of(action), 0, action)


func test_each_action_has_a_label_a_caption_and_an_axis_label() -> void:
	var row: int = LABELS.index_of(&"pitch_down")
	assert_eq(LABELS.labels[row], "Pitch down")
	assert_eq(LABELS.short_labels[row], "Pitch ↓")
	assert_eq(LABELS.axis_labels[row], "Pitch")


func test_mouse_look_is_a_keyboard_extra() -> void:
	assert_eq(Array(LABELS.keyboard_extra_icons), ["mouse_xy"])
	assert_eq(Array(LABELS.keyboard_extra_labels), ["Look"])


func test_unknown_action_has_no_row() -> void:
	assert_eq(LABELS.index_of(&"no_such_action"), -1)


func test_mismatched_arrays_are_reported() -> void:
	var labels := ControlLabels.new()
	labels.actions = [&"pause"]
	assert_false(labels.require_valid())
	assert_push_error(
		"[Contract] Pre-condition broken: "
		+ "each action needs a label, a short label and an axis label"
	)
