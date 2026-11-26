extends GutTest

var _was_enabled: bool
var _framing: TitleFraming


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_framing = TitleFraming.new()


func after_each() -> void:
	Contract.enabled = _was_enabled


func test_bad_framing_is_reported_and_ignored() -> void:
	var distance_radii := _framing.distance_radii
	_framing.distance_radii = 0.0
	assert_push_error("distance_radii must be positive")
	var elevation_degrees := _framing.elevation_degrees
	_framing.elevation_degrees = 90.0
	assert_push_error("elevation_degrees must be within (-90, 90)")
	_framing.screen_point = Vector2(1.5, 0.5)
	assert_push_error("screen_point must be within [0, 1] on both axes")
	assert_eq(_framing.distance_radii, distance_radii)
	assert_eq(_framing.elevation_degrees, elevation_degrees)
