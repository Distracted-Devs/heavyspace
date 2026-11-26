extends RumbleFixture


func test_a_warp_out_builds_to_the_jump() -> void:
	var warp := _warp()
	var rumble: WarpRumble = _add(WarpRumble.new())
	rumble.warp_effect = warp
	warp.play()
	warp.advance(warp.warp_duration * 0.5)
	rumble.update()
	assert_almost_eq(_mixer.weak(), rumble.weak * 0.5, 1e-4)
	assert_almost_eq(_mixer.strong(), rumble.strong * 0.125, 1e-4)


func test_the_warp_rumble_ends_with_the_warp() -> void:
	var warp := _warp()
	var rumble: WarpRumble = _add(WarpRumble.new())
	rumble.warp_effect = warp
	warp.play_in()
	rumble.update()
	assert_gt(_mixer.strong(), 0.9)
	warp.advance(warp.warp_duration)
	rumble.update()
	assert_eq(_mixer.strong(), 0.0)


func test_a_missing_warp_is_reported() -> void:
	var rumble: WarpRumble = _add(WarpRumble.new())
	rumble.update()
	assert_push_error("warp_effect must be set")


func test_bad_settings_are_reported_and_ignored() -> void:
	var rumble: WarpRumble = _add(WarpRumble.new())
	var strong_power := rumble.strong_power
	rumble.strong_power = 0.0
	assert_push_error("strong_power must be positive")
	assert_eq(rumble.strong_power, strong_power)


func test_the_shop_pausing_at_the_end_of_a_warp_stops_the_rumble() -> void:
	var warp := _warp()
	var rumble: WarpRumble = _add(WarpRumble.new())
	rumble.warp_effect = warp
	warp.play()
	warp.advance(warp.warp_duration * 0.99)
	rumble.update()
	assert_gt(_mixer.strong(), 0.9)
	get_tree().paused = true
	assert_eq(_mixer.strong(), 0.0)
	get_tree().paused = false
