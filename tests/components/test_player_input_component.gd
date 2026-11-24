extends GutTest

const ACTIONS: Array[String] = [
	"back_thruster",
	"pitch_down",
	"pitch_up",
	"turn_left",
	"turn_right",
	"roll_left",
	"roll_right",
	"look_left",
	"look_right",
	"look_up",
	"look_down",
]

var _input: PlayerInputComponent


func before_each() -> void:
	_input = PlayerInputComponent.new()
	_input.capture_mouse = false
	add_child_autofree(_input)


func after_each() -> void:
	for action in ACTIONS:
		Input.action_release(action)


func _press_and_step(actions: Array[String]) -> void:
	for action in actions:
		Input.action_press(action)
	await wait_physics_frames(1)


func test_no_input_gives_zero_intent() -> void:
	await wait_physics_frames(1)
	assert_eq(_input.thrust_intent, Vector3.ZERO)
	assert_eq(_input.rotation_intent, Vector3.ZERO)


func test_back_thruster_intends_forward() -> void:
	await _press_and_step(["back_thruster"])
	assert_eq(_input.thrust_intent, Vector3.FORWARD)


func test_turn_left_and_roll_right_set_rotation_axes() -> void:
	await _press_and_step(["turn_left", "roll_right"])
	assert_eq(_input.rotation_intent, Vector3(0.0, 1.0, -1.0))


func test_pitch_down_intends_nose_down() -> void:
	await _press_and_step(["pitch_down"])
	assert_eq(_input.rotation_intent, Vector3.LEFT)


func test_invert_pitch_flips_pitch_intent() -> void:
	_input.invert_pitch = true
	await _press_and_step(["pitch_down"])
	assert_eq(_input.rotation_intent, Vector3.RIGHT)


func test_half_pulled_trigger_gives_half_thrust() -> void:
	Input.action_press("back_thruster", 0.5)
	await wait_physics_frames(1)
	assert_almost_eq(_input.thrust_intent.z, -0.5, 1e-6)


func test_all_inputs_keep_intent_within_unit() -> void:
	await _press_and_step(ACTIONS)
	assert_true(Intent.is_within_unit(_input.thrust_intent))
	assert_true(Intent.is_within_unit(_input.rotation_intent))


func test_look_actions_set_look_intent() -> void:
	await _press_and_step(["look_right", "look_up"])
	assert_almost_eq(
		_input.look_intent,
		Vector2(1.0, -1.0).normalized(),
		Vector2.ONE * 1e-6,
	)


func test_look_intent_stays_within_unit() -> void:
	await _press_and_step(["look_right", "look_down"])
	assert_lte(absf(_input.look_intent.x), 1.0)
	assert_lte(absf(_input.look_intent.y), 1.0)


func test_mouse_motion_is_used_exactly_once() -> void:
	_input.set_physics_process(false)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(100.0, -50.0)
	_input._unhandled_input(motion)
	_input._unhandled_input(motion)
	_input._update_intent(1.0 / 60.0)
	assert_almost_eq(
		_input.mouse_look,
		Vector2(200.0, -100.0) * _input.mouse_sensitivity,
		Vector2.ONE * 1e-6,
	)
	_input._update_intent(1.0 / 60.0)
	assert_eq(_input.mouse_look, Vector2.ZERO)
