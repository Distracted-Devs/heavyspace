extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const PLANET_SCENE := preload("res://scenes/bodies/test_planet.tscn")
const FRAMES := 30

var _was_enabled: bool
var _player: Player
var _lose: LoseController
var _rock: Node3D


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_player = PLAYER_SCENE.instantiate()
	_player.flight_input.capture_mouse = false
	add_child_autofree(_player)
	_lose = LoseController.new()
	_lose.player = _player
	add_child_autofree(_lose)
	_rock = add_child_autofree(Node3D.new())
	watch_signals(_lose)


func after_each() -> void:
	Contract.enabled = _was_enabled


func _touch_heavier() -> void:
	_player.contact_component.heavier_contact.emit(_rock, 100.0)


func test_starts_not_lost() -> void:
	assert_false(_lose.lost)


func test_first_heavier_contact_loses_once() -> void:
	_touch_heavier()
	_touch_heavier()
	assert_true(_lose.lost)
	assert_signal_emit_count(_lose, "lost_game", 1)
	assert_signal_emitted_with_parameters(_lose, "lost_game", [_rock])


func test_lighter_contact_never_loses() -> void:
	_player.contact_component.lighter_contact.emit(_rock, 0.5)
	assert_false(_lose.lost)
	assert_signal_not_emitted(_lose, "lost_game")


func test_after_losing_the_ship_fuel_and_camera_stay_put() -> void:
	_player.linear_velocity = Vector3(0.0, 0.0, -3.0)
	_player.fuel_component.draw(0.5)
	_touch_heavier()
	await wait_physics_frames(1)
	var stopped_position := _player.global_position
	var stopped_fuel := _player.fuel_component.fuel
	var stopped_yaw := _player.camera_component.yaw
	Input.action_press("back_thruster")
	await wait_physics_frames(FRAMES)
	Input.action_release("back_thruster")
	assert_true(_player.freeze)
	assert_eq(_player.global_position, stopped_position)
	assert_eq(_player.fuel_component.fuel, stopped_fuel)
	assert_eq(_player.camera_component.yaw, stopped_yaw)
	assert_eq(_player.camera_component.process_mode, Node.PROCESS_MODE_DISABLED)


func test_flying_into_a_heavier_planet_loses() -> void:
	var planet: Planet = PLANET_SCENE.instantiate()
	planet.radius = 1.0
	planet.position = Vector3(0.0, 0.0, -3.0)
	add_child_autofree(planet)
	_player.linear_velocity = Vector3(0.0, 0.0, -5.0)
	await wait_physics_frames(FRAMES)
	assert_true(_lose.lost)
	assert_signal_emitted_with_parameters(_lose, "lost_game", [planet])
