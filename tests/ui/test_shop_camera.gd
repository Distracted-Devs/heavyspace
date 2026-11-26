extends GutTest

const FRAME := 1.0 / 60.0

var _was_enabled: bool
var _camera: ShopCamera


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_camera = ShopCamera.new()
	add_child_autofree(_camera)


func after_each() -> void:
	Contract.enabled = _was_enabled


func test_snapping_centres_on_the_target_at_the_default_zoom() -> void:
	_camera.snap(Vector2(300, -200))
	assert_eq(_camera.position, Vector2(300, -200))
	assert_eq(_camera.zoom, 0.95)
	assert_eq(_camera.target_zoom, 0.95)


func test_it_glides_closer_every_frame_without_passing_the_target() -> void:
	var target := Vector2(340, 190)
	var length := target.length()
	var distance := length
	for frame in 120:
		_camera.advance(FRAME, target, 0.0)
		var now := _camera.position.distance_to(target)
		assert_lte(now, distance + 1e-4)
		assert_lte(_camera.position.dot(target.normalized()), length + 1e-4)
		distance = now
	assert_almost_eq(_camera.position, target, Vector2.ONE * 0.5)


func test_the_glide_eases_out_of_the_start() -> void:
	var target := Vector2(1000, 0)
	_camera.advance(FRAME, target, 0.0)
	var first := _camera.position.x
	_camera.advance(FRAME, target, 0.0)
	assert_gt(_camera.position.x - first, first)


func test_a_held_push_zooms_and_stays_in_range() -> void:
	_camera.snap(Vector2.ZERO)
	for frame in 600:
		_camera.advance(FRAME, Vector2.ZERO, 1.0)
	assert_almost_eq(_camera.target_zoom, 2.2, 1e-6)
	assert_almost_eq(_camera.zoom, 2.2, 1e-3)
	for frame in 600:
		_camera.advance(FRAME, Vector2.ZERO, -1.0)
	assert_almost_eq(_camera.zoom, 0.45, 1e-3)


func test_a_full_push_doubles_the_target_in_one_over_zoom_speed() -> void:
	_camera.snap(Vector2.ZERO)
	_camera.advance(1.0 / _camera.zoom_speed, Vector2.ZERO, 1.0)
	assert_almost_eq(_camera.target_zoom, 1.9, 1e-6)


func test_a_wheel_notch_steps_the_target_zoom() -> void:
	_camera.snap(Vector2.ZERO)
	_camera.step_zoom(1.0)
	assert_almost_eq(_camera.target_zoom, 0.95 * 1.15, 1e-6)
	_camera.step_zoom(-20.0)
	assert_eq(_camera.target_zoom, 0.45)


func test_no_time_changes_nothing() -> void:
	_camera.snap(Vector2.ZERO)
	_camera.advance(0.0, Vector2(500, 500), 1.0)
	assert_eq(_camera.position, Vector2.ZERO)
	assert_eq(_camera.zoom, 0.95)


func test_the_offset_puts_the_position_in_the_centre() -> void:
	_camera.snap(Vector2(100, 50))
	var view := Vector2(1920, 1080)
	var centre := _camera.offset(view) + _camera.position * _camera.zoom
	assert_almost_eq(centre, view * 0.5, Vector2.ONE * 1e-4)


func test_bad_input_is_reported_and_changes_nothing() -> void:
	_camera.snap(Vector2.ZERO)
	_camera.advance(-1.0, Vector2(10, 0), 0.0)
	assert_push_error("delta must not be negative")
	_camera.advance(FRAME, Vector2(10, 0), 2.0)
	assert_push_error("push must be within [-1, 1]")
	assert_eq(_camera.position, Vector2.ZERO)


func test_bad_exports_are_reported_and_ignored() -> void:
	var smooth_time := _camera.smooth_time
	_camera.smooth_time = 0.0
	var max_zoom := _camera.max_zoom
	_camera.max_zoom = 0.1
	_camera.wheel_step = 1.0
	assert_push_error("smooth_time must be positive")
	assert_push_error("max_zoom must be at least min_zoom")
	assert_push_error("wheel_step must be above 1")
	assert_eq(_camera.smooth_time, smooth_time)
	assert_eq(_camera.max_zoom, max_zoom)
