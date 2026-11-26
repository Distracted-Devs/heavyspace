extends GutTest

var _was_enabled: bool
var _camera: Camera3D
var _marker: TargetMarker


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_camera = Camera3D.new()
	add_child_autofree(_camera)
	_marker = TargetMarker.new()
	_marker.set_process(false)
	add_child_autofree(_marker)


func after_each() -> void:
	Contract.enabled = _was_enabled


func _screen() -> Vector2:
	return _camera.get_viewport().get_visible_rect().size


func _aim(target: Vector3) -> void:
	_marker.target = target
	_marker.has_target = true
	_marker.place(_camera)


func test_a_point_ahead_is_marked_where_it_is() -> void:
	_aim(Vector3(0.0, 0.0, -10.0))
	assert_true(_marker.on_screen)
	assert_almost_eq(
		_marker.marker_position,
		_screen() * 0.5,
		Vector2.ONE * 0.5,
	)


func test_a_point_off_to_the_right_gets_an_edge_arrow() -> void:
	_aim(Vector3(100.0, 0.0, -1.0))
	assert_false(_marker.on_screen)
	assert_almost_eq(_marker.pointing, Vector2.RIGHT, Vector2.ONE * 1.0e-3)
	assert_almost_eq(
		_marker.marker_position.x,
		_screen().x - _marker.margin,
		0.5,
	)
	assert_almost_eq(_marker.marker_position.y, _screen().y * 0.5, 0.5)


func test_the_arrow_stays_inside_the_safe_area() -> void:
	var safe := Rect2(
		Vector2.ONE * _marker.margin,
		_screen() - Vector2.ONE * _marker.margin * 2.0,
	)
	for target in [
		Vector3(50.0, 80.0, -1.0),
		Vector3(-200.0, -10.0, -5.0),
		Vector3(3.0, -400.0, -2.0),
	]:
		_aim(target)
		assert_false(_marker.on_screen)
		assert_true(safe.grow(0.5).has_point(_marker.marker_position))


func test_a_point_behind_points_the_right_way() -> void:
	_aim(Vector3(-5.0, 0.0, 10.0))
	assert_false(_marker.on_screen)
	assert_lt(_marker.pointing.x, 0.0)


func test_a_point_dead_behind_points_up() -> void:
	_aim(Vector3(0.0, 0.0, 10.0))
	assert_false(_marker.on_screen)
	assert_almost_eq(_marker.pointing, Vector2.UP, Vector2.ONE * 1.0e-3)


func test_nothing_is_marked_without_a_target() -> void:
	_marker.has_target = false
	_marker.place(_camera)
	assert_false(_marker.is_marking())
	_aim(Vector3(0.0, 0.0, -10.0))
	assert_true(_marker.is_marking())
	_marker.place(null)
	assert_false(_marker.is_marking())


func test_it_ignores_the_mouse() -> void:
	assert_eq(_marker.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_negative_margin_is_reported_and_ignored() -> void:
	var margin := _marker.margin
	_marker.margin = -1.0
	assert_push_error(
		"[Contract] Pre-condition broken: margin must not be negative"
	)
	assert_eq(_marker.margin, margin)
