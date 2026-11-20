extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const THRUST_FRAMES := 30

var _was_enabled: bool


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true


func after_each() -> void:
	Input.action_release("back_thruster")
	Input.action_release("turn_left")
	Input.action_release("roll_left")
	Input.action_release("pitch_down")
	Contract.enabled = _was_enabled


func _spawn_player(position := Vector3.ZERO) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player.position = position
	return add_child_autofree(player)


func test_back_thrust_follows_visual_forward_when_root_is_rotated() -> void:
	var player := _spawn_player()
	player.rotation.y = PI / 2.0
	var forward := -player.global_basis.z
	Input.action_press("back_thruster")
	await wait_physics_frames(THRUST_FRAMES)
	assert_almost_eq(
		player.linear_velocity.normalized(),
		forward,
		Vector3.ONE * 1e-3,
	)
	assert_almost_eq(forward, Vector3.LEFT, Vector3.ONE * 1e-3)


func test_velocity_is_constant_with_no_input_or_sources() -> void:
	var player := _spawn_player()
	var velocity := Vector3(1.0, 2.0, -3.0)
	player.linear_velocity = velocity
	await wait_physics_frames(THRUST_FRAMES)
	assert_almost_eq(player.linear_velocity, velocity, Vector3.ONE * 1e-4)


func test_twice_the_mass_halves_thrust_acceleration() -> void:
	var light := _spawn_player()
	var heavy := _spawn_player(Vector3.RIGHT * 10.0)
	light.mass_component.current_mass = 1.0
	heavy.mass_component.current_mass = 2.0
	Input.action_press("back_thruster")
	await wait_physics_frames(THRUST_FRAMES)
	var light_speed := light.linear_velocity.length()
	var heavy_speed := heavy.linear_velocity.length()
	assert_gt(light_speed, 0.0)
	assert_almost_eq(heavy_speed / light_speed, 0.5, 1e-3)


func test_rotational_acceleration_falls_with_mass_radius_squared() -> void:
	for action in ["pitch_down", "turn_left", "roll_left"]:
		var light := _spawn_player()
		var heavy := _spawn_player(Vector3.RIGHT * 10.0)
		light.mass_component.current_mass = 1.0
		heavy.mass_component.current_mass = 2.0
		Input.action_press(action)
		await wait_physics_frames(THRUST_FRAMES)
		Input.action_release(action)
		var light_spin := light.angular_velocity.length()
		var heavy_spin := heavy.angular_velocity.length()
		var light_radius := light.size_component.radius
		var heavy_radius := heavy.size_component.radius
		var expected := (
			(1.0 * light_radius * light_radius)
			/ (2.0 * heavy_radius * heavy_radius)
		)
		assert_gt(light_spin, 0.0, action)
		assert_almost_eq(heavy_spin / light_spin, expected, 1e-3, action)


func test_player_mass_follows_mass_component() -> void:
	var player := _spawn_player()
	assert_eq(player.mass, player.mass_component.starting_mass)
	player.mass_component.current_mass = 3.5
	assert_eq(player.mass, 3.5)


func test_back_thrust_draws_from_player_fuel() -> void:
	var player := _spawn_player()
	Input.action_press("back_thruster")
	await wait_physics_frames(THRUST_FRAMES)
	assert_lt(player.fuel_component.fuel, player.fuel_component.tank_size)
