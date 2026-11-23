extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const EXPONENT := 1.0 / 3.0

var _was_enabled: bool


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true


func after_each() -> void:
	Contract.enabled = _was_enabled


func _grown_player(with_pickup := true) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player.flight_input.capture_mouse = false
	var growth: GrowthComponent = player.get_node("GrowthComponent")
	growth.size_exponent = EXPONENT
	if not with_pickup:
		growth.pickup = null
	add_child_autofree(player)
	player.freeze = true
	return player


func _growth(player: Player) -> GrowthComponent:
	return player.get_node("GrowthComponent")


func _radius(player: Player) -> float:
	var collider: CollisionShape3D = player.get_node("Collider")
	return (collider.shape as SphereShape3D).radius


func test_size_is_one_at_the_starting_mass() -> void:
	var player := _grown_player()
	assert_almost_eq(_growth(player).size(), 1.0, 1.0e-9)


func test_size_follows_mass_to_the_exponent() -> void:
	var player := _grown_player()
	player.mass_component.current_mass = 8.0
	var expected := pow(8.0 / player.mass_component.starting_mass, EXPONENT)
	assert_almost_eq(_growth(player).size(), expected, 1.0e-9)


func test_mesh_collider_camera_and_pickup_scale_with_size() -> void:
	var player := _grown_player()
	var mesh: Node3D = player.get_node("Mesh")
	var base_scale := mesh.scale
	var base_radius := _radius(player)
	var base_distance := player.camera_component.distance
	player.mass_component.current_mass = 27.0
	var size := _growth(player).size()
	assert_almost_eq(mesh.scale, base_scale * size, Vector3.ONE * 1.0e-6)
	assert_almost_eq(_radius(player), base_radius * size, 1.0e-6)
	assert_almost_eq(
		player.camera_component.distance,
		base_distance * size,
		1.0e-6,
	)
	var pickup: PickupComponent = player.get_node("PickupComponent")
	assert_almost_eq(pickup.size_scale, size, 1.0e-9)


func test_growing_one_ship_leaves_another_ships_collider_alone() -> void:
	var grown := _grown_player()
	var other := _grown_player()
	var base := _radius(other)
	grown.mass_component.current_mass = 64.0
	assert_gt(_radius(grown), base)
	assert_eq(_radius(other), base)


func test_thrust_and_torque_are_unchanged_by_growth() -> void:
	var player := _grown_player()
	var thrust := player.thruster.back_thrust_force
	var torques := [
		player.rotator.pitch_torque,
		player.rotator.turn_torque,
		player.rotator.roll_torque,
	]
	player.mass_component.current_mass = 50.0
	assert_eq(player.thruster.back_thrust_force, thrust)
	assert_eq(
		[
			player.rotator.pitch_torque,
			player.rotator.turn_torque,
			player.rotator.roll_torque,
		],
		torques,
	)


func test_unset_parts_are_skipped() -> void:
	var mass := MassComponent.new()
	add_child_autofree(mass)
	var growth := GrowthComponent.new()
	growth.mass_component = mass
	add_child_autofree(growth)
	mass.current_mass = 8.0
	assert_almost_eq(growth.size(), pow(8.0, 0.3333), 1.0e-9)


func test_works_without_a_pickup() -> void:
	var player := _grown_player(false)
	player.mass_component.current_mass = 8.0
	assert_gt(_radius(player), 0.5)
	var pickup: PickupComponent = player.get_node("PickupComponent")
	assert_eq(pickup.size_scale, 1.0)


func test_non_positive_exponent_is_rejected() -> void:
	var growth := GrowthComponent.new()
	growth.size_exponent = 0.0
	assert_push_error(
		"[Contract] Pre-condition broken: size_exponent must be positive"
	)
	assert_eq(growth.size_exponent, 0.3333)
	growth.free()
