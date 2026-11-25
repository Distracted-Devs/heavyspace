extends RumbleFixture


func test_it_feeds_the_rumble_autoload_by_default() -> void:
	var source: RumbleSource = add_child_autofree(RumbleSource.new())
	assert_eq(source.rumble, get_node(^"/root/Rumble"))


func test_a_given_mixer_is_kept() -> void:
	var source: RumbleSource = _add(RumbleSource.new())
	assert_eq(source.rumble, _mixer)


func test_motor_levels_must_be_within_zero_and_one() -> void:
	assert_true(RumbleSource.motor_valid(0.0, "level"))
	assert_true(RumbleSource.motor_valid(1.0, "level"))
	assert_false(RumbleSource.motor_valid(1.1, "level"))
	assert_push_error("level must be within [0, 1]")


func test_positive_settings_must_be_above_zero() -> void:
	assert_true(RumbleSource.positive(0.1, "time"))
	assert_false(RumbleSource.positive(0.0, "time"))
	assert_push_error("time must be positive")


func test_pausing_releases_the_held_level() -> void:
	var source: RumbleSource = _add(RumbleSource.new())
	source.held_source = &"test"
	_mixer.hold(&"test", 0.6, 1.0)
	get_tree().paused = true
	assert_eq(_mixer.strong(), 0.0)
	get_tree().paused = false


func test_leaving_the_tree_releases_the_held_level() -> void:
	var source: RumbleSource = _add(RumbleSource.new())
	source.held_source = &"test"
	_mixer.hold(&"test", 0.6, 1.0)
	remove_child(source)
	assert_eq(_mixer.strong(), 0.0)
	add_child(source)


func test_a_source_that_runs_while_paused_keeps_its_hold() -> void:
	var source: RumbleSource = _add(RumbleSource.new())
	source.process_mode = Node.PROCESS_MODE_ALWAYS
	source.held_source = &"test"
	_mixer.hold(&"test", 0.6, 1.0)
	get_tree().paused = true
	assert_almost_eq(_mixer.strong(), 1.0, 1e-6)
	get_tree().paused = false
