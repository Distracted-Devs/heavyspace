extends GutTest

const SUN_SCENE := preload("res://scenes/bodies/sun.tscn")

var _was_enabled: bool
var _sun: Sun
var _camera: Camera3D


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_sun = SUN_SCENE.instantiate()
	_sun.set_process(false)
	add_child_autofree(_sun)
	_camera = add_child_autofree(Camera3D.new())
	_camera.far = 60000.0
	_camera.position = Vector3(100.0, -20.0, 7.0)


func after_each() -> void:
	Contract.enabled = _was_enabled


func test_sits_at_distance_along_its_direction_from_the_camera() -> void:
	_sun.follow(_camera)
	var expected := _camera.global_position + _sun.direction * _sun.distance
	assert_almost_eq(_sun.global_position.distance_to(expected), 0.0, 1.0e-3)


func test_never_crosses_the_far_plane() -> void:
	_camera.far = 2000.0
	_sun.follow(_camera)
	var reach := _sun.global_position.distance_to(_camera.global_position)
	assert_almost_eq(reach, _sun.horizon_limit(_camera), 1.0e-2)
	assert_lt(reach + _sun.radius * _sun.corona_scale * 0.5, _camera.far)


func test_centres_on_the_origin_without_a_camera() -> void:
	_sun.follow(null)
	assert_almost_eq(
		_sun.global_position.distance_to(_sun.direction * _sun.distance),
		0.0,
		1.0e-3,
	)


func test_scales_the_body_and_corona() -> void:
	_sun.radius = 400.0
	_sun.corona_scale = 2.0
	_sun.follow(_camera)
	assert_eq(_sun.body.scale, Vector3.ONE * 400.0)
	assert_eq(_sun.corona.scale, Vector3.ONE * 800.0)


func test_sunlight_shines_away_from_the_sun() -> void:
	_sun.direction = Vector3(1.0, 1.0, 0.0)
	_sun.follow(_camera)
	var shine := -_sun.light.global_basis.z
	assert_almost_eq(shine.dot(-_sun.direction), 1.0, 1.0e-4)
	assert_eq(_sun.light.light_energy, _sun.light_intensity)
	assert_almost_eq(_sun.light.shadow_opacity, _sun.shadow_strength, 1.0e-6)


func test_direction_is_stored_normalised() -> void:
	_sun.direction = Vector3(0.0, 3.0, 4.0)
	assert_almost_eq(_sun.direction.length(), 1.0, 1.0e-6)


func test_fill_light_is_hidden_at_zero_intensity() -> void:
	_sun.fill_intensity = 0.0
	_sun.follow(_camera)
	assert_false(_sun.fill_light.visible)


func test_fill_light_comes_from_the_far_side() -> void:
	_sun.follow(_camera)
	var fill_from := _sun.fill_light.global_basis.z
	assert_lt(fill_from.dot(_sun.direction), 0.0)
	assert_eq(_sun.fill_light.light_color, _sun.fill_colour)


func test_zero_direction_is_reported_and_ignored() -> void:
	var before := _sun.direction
	_sun.direction = Vector3.ZERO
	assert_push_error(
		"[Contract] Pre-condition broken: direction must not be zero"
	)
	assert_eq(_sun.direction, before)


func test_negative_light_is_reported_and_ignored() -> void:
	_sun.light_intensity = -1.0
	assert_push_error(
		"[Contract] Pre-condition broken: light_intensity must not be negative"
	)
	assert_eq(_sun.light_intensity, 3.0)
