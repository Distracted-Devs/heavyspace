extends GutTest

const MAP_SCENE := preload("res://scenes/ui/minimap.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const BODY_SCENE := preload("res://scenes/bodies/mass_body.tscn")

var _was_enabled: bool
var _player: Player
var _map: Minimap


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_player = PLAYER_SCENE.instantiate()
	_player.flight_input.capture_mouse = false
	add_child_autofree(_player)
	_player.freeze = true
	_map = MAP_SCENE.instantiate()
	_map.player = _player
	_map.set_process(false)
	add_child_autofree(_map)


func after_each() -> void:
	Contract.enabled = _was_enabled


func _body(at: Vector3, mass: float, radius := 10.0) -> MassBody:
	var body: MassBody = BODY_SCENE.instantiate()
	body.radius = radius
	body.mass = mass
	body.position = at
	return add_child_autofree(body)


func test_focuses_on_the_heavier_body_pulling_hardest() -> void:
	var near := _body(Vector3(60.0, 0.0, 0.0), _player.mass * 100.0)
	_body(Vector3(-900.0, 0.0, 0.0), _player.mass * 200.0)
	await wait_physics_frames(1)
	_map.refresh(0.1)
	assert_eq(_map.focus_position(), near.global_position)


func test_focuses_on_the_player_when_nothing_is_heavier() -> void:
	_body(Vector3(60.0, 0.0, 0.0), _player.mass * 0.5)
	await wait_physics_frames(1)
	_map.refresh(0.1)
	assert_eq(_map.focus_position(), _player.global_position)


func test_one_map_sphere_per_nearby_body_coloured_by_threat() -> void:
	var heavy := _body(Vector3(60.0, 0.0, 0.0), _player.mass * 100.0)
	var light := _body(Vector3(0.0, 0.0, 40.0), _player.mass * 0.5, 2.0)
	await wait_physics_frames(1)
	_map.refresh(0.1)
	assert_eq(_map.map_body_count(), 2)
	assert_eq(
		_map.map_body_for(heavy).material_override,
		_map.danger_material(),
	)
	assert_eq(
		_map.map_body_for(light).material_override,
		_map.edible_material(),
	)
	assert_eq(_map.map_body_for(light).scale, Vector3.ONE * 2.0)


func test_far_bodies_are_left_off_the_map() -> void:
	_body(Vector3(60.0, 0.0, 0.0), _player.mass * 100.0)
	_body(Vector3(0.0, 0.0, 90000.0), _player.mass * 0.5)
	await wait_physics_frames(1)
	_map.refresh(0.1)
	assert_eq(_map.map_body_count(), 1)


func test_freed_bodies_leave_the_map() -> void:
	var heavy := _body(Vector3(60.0, 0.0, 0.0), _player.mass * 100.0)
	await wait_physics_frames(1)
	_map.refresh(0.1)
	heavy.free()
	await wait_physics_frames(1)
	_map.refresh(0.1)
	assert_eq(_map.map_body_count(), 0)


func test_path_colour_follows_the_forecast() -> void:
	_body(Vector3(0.0, 0.0, -60.0), _player.mass * 1.0e6)
	await wait_physics_frames(1)
	_map.refresh(0.1)
	assert_eq(_map.forecast(), PathPredictor.Forecast.IMPACT)
	assert_eq(_map.forecast_colour(), _map.impact_colour)


func test_view_radius_stays_within_its_limits() -> void:
	_body(Vector3(5.0e6, 0.0, 0.0), _player.mass * 100.0)
	await wait_physics_frames(1)
	for frame in 10:
		_map.refresh(0.5)
	assert_between(_map.view_radius, _map.min_view_radius, _map.max_view_radius)


func test_bodies_between_the_camera_and_the_ship_are_hidden() -> void:
	_body(Vector3(400.0, 0.0, 0.0), _player.mass * 100.0)
	await wait_physics_frames(1)
	_map.refresh(0.1)
	var marker := _map.ship_marker.position
	var camera := _map.camera.position
	var blocker := _body(
		_map.focus_position() + marker.lerp(camera, 0.1),
		_player.mass * 0.5,
		5.0,
	)
	var aside := _body(
		_map.focus_position() + marker + Vector3(0.0, 0.0, 60.0),
		_player.mass * 0.5,
		5.0,
	)
	_map.refresh(0.0)
	assert_false(_map.map_body_for(blocker).visible)
	assert_true(_map.map_body_for(aside).visible)


func test_a_body_holding_the_camera_is_hidden() -> void:
	var giant := _body(Vector3(60.0, 0.0, 0.0), _player.mass * 100.0, 50000.0)
	await wait_physics_frames(1)
	_map.refresh(0.1)
	assert_false(_map.map_body_for(giant).visible)


func test_prediction_follows_the_facing_under_arcade_flight() -> void:
	_player.arcade_flight.alignment = 1.0
	_player.linear_velocity = Vector3(10.0, 0.0, 0.0)
	_body(Vector3(0.0, 300.0, 0.0), _player.mass * 100.0)
	await wait_physics_frames(1)
	_player.linear_velocity = Vector3(10.0, 0.0, 0.0)
	_map.refresh(0.1)
	var points := _map._predictor.points
	var heading := (points[points.size() - 1] - points[0]).normalized()
	assert_almost_eq(heading.dot(-_player.global_basis.z), 1.0, 1.0e-3)


func test_ship_marker_tip_points_along_the_facing() -> void:
	_player.global_basis = Basis.looking_at(Vector3(1.0, -0.5, 0.3))
	_body(Vector3(0.0, 0.0, -60.0), _player.mass * 100.0)
	await wait_physics_frames(1)
	_map.refresh(0.1)
	var cone := _map.ship_marker.get_child(0) as Node3D
	var tip := cone.global_basis.y.normalized()
	assert_almost_eq(tip.dot(-_player.global_basis.z), 1.0, 1.0e-4)


func test_a_focus_bigger_than_the_view_still_fits_whole() -> void:
	_body(Vector3(0.0, 0.0, -6000.0), _player.mass * 1.0e6, 5000.0)
	await wait_physics_frames(1)
	for frame in 30:
		_map.refresh(0.5)
	assert_gte(_map.view_radius, 5000.0 * _map.focus_fit * 0.99)


func test_missing_player_is_reported() -> void:
	_map.player = null
	_map.refresh(0.1)
	assert_push_error("[Contract] Pre-condition broken: player must be set")
