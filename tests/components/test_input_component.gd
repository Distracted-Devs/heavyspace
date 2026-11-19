extends GutTest


class OutOfRangeInput:
	extends InputComponent

	func _update_intent(_delta: float) -> void:
		thrust_intent = Vector3(0.0, 0.0, -2.0)


var _was_enabled: bool


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true


func after_each() -> void:
	Contract.enabled = _was_enabled


func test_base_input_intends_nothing() -> void:
	var input: InputComponent = add_child_autofree(InputComponent.new())
	await wait_physics_frames(1)
	assert_eq(input.thrust_intent, Vector3.ZERO)
	assert_eq(input.rotation_intent, Vector3.ZERO)


func test_out_of_range_implementation_breaks_post_condition() -> void:
	var input: InputComponent = OutOfRangeInput.new()
	input.set_physics_process(false)
	add_child_autofree(input)
	input._physics_process(0.0)
	assert_push_error(
		"[Contract] Post-condition broken: intent axes must be within [-1, 1]"
	)
