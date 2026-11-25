extends GutTest

var _was_enabled: bool
var _settings: GameSettings
var _rumble: RumbleMixer


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_settings = GameSettings.new()
	_settings.path = "user://test_rumble_settings.cfg"
	_settings.load_on_ready = false
	add_child_autofree(_settings)
	_rumble = RumbleMixer.new()
	_rumble.settings = _settings
	_rumble.set_process(false)
	add_child_autofree(_rumble)


func after_each() -> void:
	DirAccess.remove_absolute(_settings.path)
	Contract.enabled = _was_enabled


func test_silent_with_nothing_playing() -> void:
	assert_eq(_rumble.weak(), 0.0)
	assert_eq(_rumble.strong(), 0.0)


func test_a_pulse_fades_to_nothing_over_its_duration() -> void:
	_rumble.pulse(0.4, 0.8, 1.0)
	assert_almost_eq(_rumble.strong(), 0.8, 1e-6)
	_rumble.advance(0.5)
	assert_almost_eq(_rumble.strong(), 0.4, 1e-6)
	assert_almost_eq(_rumble.weak(), 0.2, 1e-6)
	_rumble.advance(0.5)
	assert_eq(_rumble.strong(), 0.0)
	assert_eq(_rumble.weak(), 0.0)


func test_a_fade_power_sharpens_the_tail() -> void:
	_rumble.pulse(0.0, 1.0, 1.0, 2.0)
	_rumble.advance(0.5)
	assert_almost_eq(_rumble.strong(), 0.25, 1e-6)


func test_a_held_level_stays_until_released() -> void:
	_rumble.hold(&"thrust", 0.3, 0.0)
	_rumble.advance(10.0)
	assert_almost_eq(_rumble.weak(), 0.3, 1e-6)
	_rumble.release(&"thrust")
	assert_eq(_rumble.weak(), 0.0)


func test_holding_zero_releases() -> void:
	_rumble.hold(&"warp", 0.5, 0.5)
	_rumble.hold(&"warp", 0.0, 0.0)
	assert_eq(_rumble.weak(), 0.0)


func test_the_mix_is_the_strongest_per_motor() -> void:
	_rumble.hold(&"thrust", 0.35, 0.0)
	_rumble.pulse(0.1, 0.7, 1.0)
	assert_almost_eq(_rumble.weak(), 0.35, 1e-6)
	assert_almost_eq(_rumble.strong(), 0.7, 1e-6)


func test_sends_the_mix_when_vibration_is_on() -> void:
	_rumble.hold(&"thrust", 0.3, 0.6)
	_rumble.send()
	assert_almost_eq(_rumble.sent_weak, 0.3, 1e-6)
	assert_almost_eq(_rumble.sent_strong, 0.6, 1e-6)


func test_sends_nothing_when_vibration_is_off() -> void:
	_settings.vibration = false
	_rumble.hold(&"thrust", 0.3, 0.6)
	_rumble.send()
	assert_eq(_rumble.sent_weak, 0.0)
	assert_eq(_rumble.sent_strong, 0.0)


func test_bad_pulses_are_reported_and_ignored() -> void:
	_rumble.pulse(1.5, 0.0, 1.0)
	assert_push_error("motors must be within [0, 1]")
	_rumble.pulse(0.5, 0.5, 0.0)
	assert_push_error("duration must be positive")
	_rumble.pulse(0.5, 0.5, 1.0, 0.0)
	assert_push_error("fade_power must be positive")
	assert_eq(_rumble.weak(), 0.0)


func test_a_bad_hold_is_reported_and_ignored() -> void:
	_rumble.hold(&"thrust", -0.1, 0.0)
	assert_push_error("motors must be within [0, 1]")
	assert_eq(_rumble.weak(), 0.0)


func test_a_negative_delta_is_reported() -> void:
	_rumble.advance(-1.0)
	assert_push_error("delta must not be negative")
