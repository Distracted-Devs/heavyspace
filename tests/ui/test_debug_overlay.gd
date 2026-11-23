extends GutTest

const OVERLAY_SCENE := preload("res://scenes/ui/debug_overlay.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var _overlay: DebugOverlay
var _player: Player


func before_each() -> void:
	_player = PLAYER_SCENE.instantiate()
	_player.position = Vector3(1.0, 2.0, 3.0)
	add_child_autofree(_player)
	_overlay = OVERLAY_SCENE.instantiate()
	_overlay.player = _player
	add_child_autofree(_overlay)


func test_describe_shows_position_velocity_and_mass() -> void:
	_player.mass_component.current_mass = 2.5
	_player.linear_velocity = Vector3(0.0, 0.0, -4.0)
	var text := _overlay.describe(_player)
	assert_string_contains(text, "Position  (1.00, 2.00, 3.00)")
	assert_string_contains(text, "Velocity  (0.00, 0.00, -4.00)  |4.00|")
	assert_string_contains(text, "Mass      2.50")


func test_describe_shows_rotation_in_degrees() -> void:
	_player.rotation.y = PI / 2.0
	assert_string_contains(
		_overlay.describe(_player),
		"Rotation  (0.00, 90.00, 0.00)°",
	)


func test_label_follows_the_player_each_frame() -> void:
	_player.mass_component.current_mass = 7.0
	await wait_process_frames(1)
	assert_string_contains(_overlay.label.text, "Mass      7.00")


func test_describe_shows_fuel_remaining_over_tank_size() -> void:
	_player.fuel_component.tank_size = 3.0
	_player.fuel_component.draw(0.6)
	assert_string_contains(_overlay.describe(_player), "Fuel      0.40 / 3.00")


func test_describe_shows_the_active_input_device() -> void:
	var player_input := _player.flight_input as PlayerInputComponent
	assert_string_contains(
		_overlay.describe(_player),
		"Input     Keyboard/Mouse",
	)
	player_input.active_device = PlayerInputComponent.Device.CONTROLLER
	assert_string_contains(_overlay.describe(_player), "Input     Controller")
