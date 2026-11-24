extends GutTest

const HZ := 2.0
const BRIGHTNESS := 1.5

var _was_enabled: bool
var _target: ColorRect
var _pulse: PulseEffect


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_target = add_child_autofree(ColorRect.new())
	_target.modulate = Color(1.0, 1.0, 1.0, 0.5)
	_pulse = PulseEffect.new()
	_pulse.target = _target
	_pulse.hz = HZ
	_pulse.brightness = BRIGHTNESS
	_pulse.set_process(false)
	add_child_autofree(_pulse)


func after_each() -> void:
	Contract.enabled = _was_enabled


func test_it_starts_unlit() -> void:
	_pulse.advance(0.0)
	assert_eq(_pulse.level(), 0.0)
	assert_eq(_target.modulate, Color(1.0, 1.0, 1.0, 0.5))


func test_it_peaks_half_a_period_in_keeping_alpha() -> void:
	_pulse.advance(0.5 / HZ)
	assert_almost_eq(_pulse.level(), 1.0, 1.0e-6)
	assert_almost_eq(_target.modulate.r, BRIGHTNESS, 1.0e-5)
	assert_almost_eq(_target.modulate.b, BRIGHTNESS, 1.0e-5)
	assert_eq(_target.modulate.a, 0.5)


func test_it_repeats_every_period() -> void:
	_pulse.advance(0.3 / HZ)
	var first := _pulse.level()
	_pulse.advance(1.0 / HZ)
	assert_almost_eq(_pulse.level(), first, 1.0e-5)


func test_level_stays_within_zero_and_one() -> void:
	for step in 40:
		_pulse.advance(0.037)
		assert_between(_pulse.level(), 0.0, 1.0)


func test_turning_it_off_restores_white_and_resets_the_time() -> void:
	_pulse.advance(0.5 / HZ)
	_pulse.active = false
	assert_eq(_target.modulate, Color(1.0, 1.0, 1.0, 0.5))
	_pulse.advance(0.5 / HZ)
	assert_eq(_target.modulate, Color(1.0, 1.0, 1.0, 0.5))
	_pulse.active = true
	assert_eq(_pulse.level(), 0.0)


func test_bad_values_are_reported_and_ignored() -> void:
	_pulse.hz = 0.0
	_pulse.brightness = 0.5
	assert_push_error("[Contract] Pre-condition broken: hz must be positive")
	assert_push_error(
		"[Contract] Pre-condition broken: brightness must be at least 1"
	)
	assert_eq(_pulse.hz, HZ)
	assert_eq(_pulse.brightness, BRIGHTNESS)


func test_it_runs_by_itself_each_frame() -> void:
	_pulse.set_process(true)
	await wait_process_frames(3)
	assert_gt(_pulse.level(), 0.0)
