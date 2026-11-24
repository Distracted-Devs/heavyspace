extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const THRUST_FRAMES := 30
const SHIP_SCALE := 1.3
const BASE_COLLIDER_RADIUS := 0.50158125
const THRUST_AMOUNT := 90
const THRUST_LIFETIME := 0.8

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


func test_coasting_without_drag_keeps_its_speed_along_the_facing() -> void:
	var player := _spawn_player()
	player.linear_damp = 0.0
	player.linear_velocity = Vector3(1.0, 2.0, -3.0)
	var speed := player.linear_velocity.length()
	await wait_physics_frames(THRUST_FRAMES)
	assert_almost_eq(
		player.linear_velocity,
		-player.global_basis.z * speed,
		Vector3.ONE * 1e-4,
	)


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


func test_turning_is_the_same_at_any_mass_and_size() -> void:
	var actions := ["pitch_down", "turn_left", "roll_left"]
	for step in actions.size():
		var action: String = actions[step]
		var apart := Vector3.BACK * 20.0 * step
		var light := _spawn_player(apart)
		var heavy := _spawn_player(apart + Vector3.RIGHT * 10.0)
		light.mass_component.current_mass = 1.0
		heavy.mass_component.current_mass = 8.0
		Input.action_press(action)
		await wait_physics_frames(THRUST_FRAMES)
		Input.action_release(action)
		var light_spin := light.angular_velocity.length()
		var heavy_spin := heavy.angular_velocity.length()
		assert_gt(light_spin, 0.0, action)
		assert_almost_eq(heavy_spin / light_spin, 1.0, 1e-3, action)


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


func test_stopping_flight_disables_the_pickup() -> void:
	var player := _spawn_player()
	var pickup := PickupComponent.new()
	player.add_child(pickup)
	player.pickup_component = pickup
	player.stop_flight()
	await wait_physics_frames(1)
	assert_eq(pickup.process_mode, Node.PROCESS_MODE_DISABLED)


func test_stopping_flight_without_a_pickup_still_stops() -> void:
	var player := _spawn_player()
	player.pickup_component = null
	player.stop_flight()
	await wait_physics_frames(1)
	assert_true(player.freeze)


func test_stopping_flight_disables_arcade_flight() -> void:
	var player := _spawn_player()
	player.stop_flight()
	await wait_physics_frames(1)
	assert_eq(player.arcade_flight.process_mode, Node.PROCESS_MODE_DISABLED)


func test_coasting_with_drag_slows_down() -> void:
	var player := _spawn_player()
	assert_gt(player.linear_damp, 0.0)
	player.linear_velocity = -player.global_basis.z * 4.0
	await wait_physics_frames(THRUST_FRAMES)
	assert_lt(player.linear_velocity.length(), 4.0)


func test_growing_slows_the_ship_by_the_momentum_factor() -> void:
	var player := _spawn_player()
	player.linear_damp = 0.0
	var momentum: MomentumComponent = player.get_node("MomentumComponent")
	var expected := 4.0 * pow(0.5, momentum.momentum_exponent)
	player.linear_velocity = -player.global_basis.z * 4.0
	player.mass_component.current_mass *= 2.0
	await wait_physics_frames(1)
	assert_lt(expected, 4.0, "growing must slow the ship")
	assert_almost_eq(player.linear_velocity.length(), expected, 1e-3)


func test_ship_mesh_and_collider_are_scaled_up_together() -> void:
	var player: Player = autofree(PLAYER_SCENE.instantiate())
	var mesh: Node3D = player.get_node("Mesh")
	var collider: CollisionShape3D = player.get_node("Collider")
	assert_almost_eq(mesh.scale, Vector3.ONE * SHIP_SCALE, Vector3.ONE * 1e-6)
	assert_almost_eq(
		(collider.shape as SphereShape3D).radius,
		BASE_COLLIDER_RADIUS * SHIP_SCALE,
		1e-6,
	)


func test_thrust_plume_is_dense_and_drawn_in_the_ships_frame() -> void:
	var player: Player = autofree(PLAYER_SCENE.instantiate())
	var thrust: GPUParticles3D = player.get_node("Mesh/BlueThrust")
	var process := thrust.process_material as ParticleProcessMaterial
	assert_eq(thrust.amount, THRUST_AMOUNT)
	assert_almost_eq(thrust.lifetime, THRUST_LIFETIME, 1e-6)
	assert_true(thrust.local_coords, "the plume moves with the ship")
	assert_eq(process.inherit_velocity_ratio, 0.0)


func test_thrust_plume_blows_out_of_the_back_of_the_ship() -> void:
	var player: Player = autofree(PLAYER_SCENE.instantiate())
	var thrust: GPUParticles3D = player.get_node("Mesh/BlueThrust")
	var process := thrust.process_material as ParticleProcessMaterial
	var mesh: Node3D = player.get_node("Mesh")
	var in_ship := mesh.basis * thrust.basis
	var travel := (in_ship * process.direction).normalized()
	var backwards := Vector3.BACK
	assert_gt(
		travel.dot(backwards),
		0.99,
		"the ship faces -Z, so smoke goes +Z",
	)
	assert_gt(thrust.position.z, 0.0, "it starts behind the ship's centre")
