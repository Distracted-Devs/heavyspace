extends GutTest

var _clock: Clock


func before_each() -> void:
	_clock = add_child_autofree(Clock.new())


func after_each() -> void:
	get_tree().paused = false


func test_time_starts_at_zero() -> void:
	assert_eq(_clock.time, 0.0)


func test_time_advances_by_delta_each_physics_frame() -> void:
	_clock._physics_process(0.25)
	_clock._physics_process(0.5)
	assert_almost_eq(_clock.time, 0.75, 1.0e-9)


func test_time_never_goes_backwards() -> void:
	_clock._physics_process(1.0)
	_clock._physics_process(-0.5)
	assert_eq(_clock.time, 1.0)


func test_time_holds_while_not_running() -> void:
	_clock._physics_process(1.0)
	_clock.running = false
	_clock._physics_process(2.0)
	assert_eq(_clock.time, 1.0)


func test_runs_by_default() -> void:
	assert_true(_clock.running)


func test_clock_ticks_before_the_gravity_registry() -> void:
	assert_lt(
		_clock.process_physics_priority,
		GravityRegistry.process_physics_priority,
	)


func test_time_advances_with_the_physics_frames() -> void:
	await wait_physics_frames(3)
	assert_gt(_clock.time, 0.0)


func test_time_stops_while_paused() -> void:
	await wait_physics_frames(1)
	get_tree().paused = true
	var paused_at := _clock.time
	await wait_physics_frames(3)
	get_tree().paused = false
	assert_eq(_clock.time, paused_at)


func test_shader_time_matches_the_clock() -> void:
	_clock._physics_process(2.0)
	var shader_time: Variant = RenderingServer.global_shader_parameter_get(
		Clock.SHADER_TIME
	)
	if shader_time == null:
		pass_test("The headless renderer doesn't keep shader globals.")
		return
	assert_almost_eq(float(shader_time), _clock.time, 1.0e-6)


func test_speed_scales_how_fast_time_passes() -> void:
	_clock.speed = 100.0
	_clock._physics_process(0.25)
	assert_almost_eq(_clock.time, 25.0, 1.0e-6)


func test_a_negative_speed_is_reported_and_ignored() -> void:
	var was := Contract.enabled
	Contract.enabled = true
	var speed := _clock.speed
	_clock.speed = -1.0
	assert_push_error("speed must not be negative")
	assert_eq(_clock.speed, speed)
	Contract.enabled = was
