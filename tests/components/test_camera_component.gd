extends GutTest

const DELTA := 1.0 / 60.0

var _was_enabled: bool
var _ship: Node3D
var _view: CameraComponent


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_ship = Node3D.new()
	_view = CameraComponent.new()
	_view.camera = Camera3D.new()
	_view.add_child(_view.camera)
	_view.set_physics_process(false)
	_ship.add_child(_view)
	add_child_autofree(_ship)


func after_each() -> void:
	Contract.enabled = _was_enabled


func _look(stick: Vector2, mouse: Vector2, seconds: float) -> void:
	for i in roundi(seconds / DELTA):
		_view.update_look(stick, mouse, DELTA)


func _view_direction() -> Vector3:
	return -_view.camera.global_basis.z


func _start_pitch() -> float:
	return deg_to_rad(_view.start_pitch_degrees)


func test_camera_starts_behind_the_ship_at_start_pitch() -> void:
	assert_almost_eq(_view.yaw, 0.0, 1e-9)
	assert_almost_eq(_view.pitch, _start_pitch(), 1e-9)
	assert_almost_eq(
		_view.camera.global_position.distance_to(_ship.global_position),
		_view.distance,
		1e-4,
	)


func test_stick_right_turns_the_view_right() -> void:
	_look(Vector2.RIGHT, Vector2.ZERO, 0.25)
	assert_gt(_view_direction().x, 0.0)
	assert_almost_eq(_view.yaw, -_view.look_speed * 0.25, 1e-4)


func test_stick_up_raises_the_view() -> void:
	var start_height := _view_direction().y
	_look(Vector2.UP, Vector2.ZERO, 0.25)
	assert_gt(_view_direction().y, start_height)


func test_pitch_is_clamped_to_max_pitch() -> void:
	_look(Vector2.UP, Vector2.ZERO, 5.0)
	assert_almost_eq(_view.pitch, deg_to_rad(_view.max_pitch_degrees), 1e-6)
	_look(Vector2.DOWN, Vector2.ZERO, 5.0)
	assert_almost_eq(_view.pitch, -deg_to_rad(_view.max_pitch_degrees), 1e-6)


func test_mouse_turns_the_view_by_exactly_mouse_look() -> void:
	_view.update_look(Vector2.ZERO, Vector2(0.2, -0.1), DELTA)
	assert_almost_eq(_view.yaw, -0.2, 1e-6)
	assert_almost_eq(_view.pitch, _start_pitch() + 0.1, 1e-6)


func test_camera_follows_ship_rotation() -> void:
	_ship.rotation.y = PI / 2.0
	_view.update_look(Vector2.ZERO, Vector2.ZERO, DELTA)
	assert_almost_eq(
		_view.camera.global_position.distance_to(_ship.global_position),
		_view.distance,
		1e-4,
	)
	assert_lt(_view_direction().x, 0.0)


func test_bad_settings_are_reported_and_ignored() -> void:
	var cases := [
		["look_speed", -1.0, "look_speed must not be negative"],
		["max_pitch_degrees", 90.0, "max_pitch_degrees must be within (0, 90)"],
		["distance", 0.0, "distance must be positive"],
	]
	for case in cases:
		var old_value: float = _view.get(case[0])
		_view.set(case[0], case[1])
		assert_push_error("[Contract] Pre-condition broken: %s" % case[2])
		assert_eq(_view.get(case[0]), old_value, case[0])


func test_released_stick_leaves_the_view_where_it_is() -> void:
	_look(Vector2.RIGHT, Vector2.ZERO, 0.25)
	var turned_yaw := _view.yaw
	_look(Vector2.ZERO, Vector2.ZERO, 2.0)
	assert_almost_eq(_view.yaw, turned_yaw, 1e-9)
