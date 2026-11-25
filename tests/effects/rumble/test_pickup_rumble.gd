extends RumbleFixture


func test_a_pickup_gives_one_short_punchy_pulse() -> void:
	var absorb: AbsorbEffect = add_child_autofree(AbsorbEffect.new())
	var pickup: PickupRumble = _add(PickupRumble.new())
	pickup.absorb_effect = absorb
	absorb.absorbed.emit(1.0)
	assert_almost_eq(_mixer.strong(), pickup.strong, 1e-5)
	assert_almost_eq(_mixer.weak(), pickup.weak, 1e-5)
	_mixer.advance(pickup.duration)
	assert_eq(_mixer.strong(), 0.0)


func test_the_pulse_has_a_snappy_tail() -> void:
	var absorb: AbsorbEffect = add_child_autofree(AbsorbEffect.new())
	var pickup: PickupRumble = _add(PickupRumble.new())
	pickup.absorb_effect = absorb
	absorb.absorbed.emit(1.0)
	_mixer.advance(pickup.duration * 0.5)
	var expected := pickup.strong * pow(0.5, pickup.fade_power)
	assert_almost_eq(_mixer.strong(), expected, 1e-6)


func test_bad_settings_are_reported_and_ignored() -> void:
	var pickup: PickupRumble = _add(PickupRumble.new())
	pickup.duration = 0.0
	assert_push_error("duration must be positive")
	pickup.strong = 2.0
	assert_push_error("strong must be within [0, 1]")
	assert_eq(pickup.duration, 0.1)
