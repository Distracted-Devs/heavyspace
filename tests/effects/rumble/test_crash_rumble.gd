extends RumbleFixture


func test_a_crash_rumbles_hard_then_fades() -> void:
	var lose: LoseController = autofree(LoseController.new())
	var crash: CrashRumble = _add(CrashRumble.new())
	crash.lose_controller = lose
	lose.lost_game.emit(add_child_autofree(Node3D.new()))
	assert_almost_eq(_mixer.weak(), 1.0, 1e-5)
	assert_almost_eq(_mixer.strong(), 1.0, 1e-5)
	_mixer.advance(crash.duration * 0.5)
	assert_almost_eq(_mixer.weak(), 0.5, 1e-4)
	assert_almost_eq(_mixer.strong(), 0.25, 1e-4)
	_mixer.advance(crash.duration * 0.5)
	assert_eq(_mixer.strong(), 0.0)


func test_bad_settings_are_reported_and_ignored() -> void:
	var crash: CrashRumble = _add(CrashRumble.new())
	crash.level = -0.1
	assert_push_error("level must be within [0, 1]")
	crash.duration = 0.0
	assert_push_error("duration must be positive")
	assert_eq(crash.level, 1.0)
