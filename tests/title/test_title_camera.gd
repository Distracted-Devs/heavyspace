extends GutTest

const FOV := 75.0
const SIZE := Vector2(1600.0, 900.0)

var _was_enabled: bool
var _framing: TitleFraming


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_framing = TitleFraming.new()


func after_each() -> void:
	Contract.enabled = _was_enabled


func _frame(centre: Vector3, radius: float, angle: float) -> Transform3D:
	return TitleCamera.frame(
		centre,
		radius,
		angle,
		_framing,
		FOV,
		SIZE.x / SIZE.y,
	)


func _on_screen(eye: Transform3D, point: Vector3) -> Vector2:
	var local := eye.affine_inverse() * point
	var tan_v := tan(deg_to_rad(FOV) * 0.5)
	var ndc := Vector2(
		local.x / (-local.z * tan_v * SIZE.x / SIZE.y),
		local.y / (-local.z * tan_v),
	)
	return Vector2((ndc.x + 1.0) * 0.5, (1.0 - ndc.y) * 0.5)


func test_the_camera_sits_its_distance_from_the_body() -> void:
	var centre := Vector3(100.0, -20.0, 50.0)
	var eye := _frame(centre, 5000.0, 0.3)
	var distance := eye.origin.distance_to(centre)
	assert_almost_eq(distance, 5000.0 * _framing.distance_radii, 1e-2)


func test_the_camera_is_above_the_orbital_plane() -> void:
	var eye := _frame(Vector3.ZERO, 10.0, 0.0)
	var height := eye.origin.y / eye.origin.length()
	assert_almost_eq(height, sin(deg_to_rad(_framing.elevation_degrees)), 1e-4)


func test_the_body_lands_on_the_screen_point() -> void:
	var centre := Vector3(10.0, 0.0, -30.0)
	var eye := _frame(centre, 50.0, 1.2)
	var spot := _on_screen(eye, centre)
	assert_almost_eq(spot, _framing.screen_point, Vector2.ONE * 1e-3)


func test_the_angle_circles_the_body() -> void:
	var first := _frame(Vector3.ZERO, 10.0, 0.0).origin
	var later := _frame(Vector3.ZERO, 10.0, PI).origin
	assert_almost_eq(later.x, -first.x, 1e-3)
	assert_almost_eq(later.z, -first.z, 1e-3)


func test_bad_inputs_are_reported() -> void:
	TitleCamera.frame(Vector3.ZERO, 0.0, 0.0, _framing, FOV, 1.0)
	assert_push_error("radius must be positive")
	TitleCamera.frame(Vector3.ZERO, 1.0, 0.0, null, FOV, 1.0)
	assert_push_error("framing must be set")
	TitleCamera.frame(Vector3.ZERO, 1.0, 0.0, _framing, 180.0, 1.0)
	assert_push_error("fov must be within (0, 180)")
