extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var _was_enabled: bool
var _player: Player
var _size: SizeComponent


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_player = PLAYER_SCENE.instantiate()
	_player.flight_input.capture_mouse = false
	add_child_autofree(_player)
	_size = _player.size_component


func after_each() -> void:
	Contract.enabled = _was_enabled


func test_starting_mass_gives_the_base_size() -> void:
	assert_almost_eq(_size.radius, 0.5, 1e-6)
	assert_almost_eq(_size.mesh.scale.x, 1.0, 1e-6)
	assert_almost_eq(_player.camera_component.distance, 2.7, 1e-6)


func test_radius_follows_the_mass_law() -> void:
	_player.mass_component.current_mass = 8.0
	assert_almost_eq(_size.radius, _size.mass_law.radius_for_mass(8.0), 1e-6)


func test_mesh_and_camera_scale_with_the_radius() -> void:
	_player.mass_component.current_mass = 8.0
	var factor := _size.radius / _size.base_radius
	assert_almost_eq(_size.mesh.scale.x, factor, 1e-6)
	assert_almost_eq(_player.camera_component.distance, 2.7 * factor, 1e-5)


func test_each_player_owns_its_collider_sphere() -> void:
	var other: Player = PLAYER_SCENE.instantiate()
	other.flight_input.capture_mouse = false
	add_child_autofree(other)
	other.mass_component.current_mass = 5.0
	assert_ne(other.size_component.radius, _size.radius)


func test_thrust_and_torque_do_not_scale_with_size() -> void:
	_player.mass_component.current_mass = 8.0
	assert_eq(_player.thruster.back_thrust_force, 1.0)
	assert_eq(_player.rotator.turn_torque, 0.05)
