extends GutTest

const BODY_SCENE := preload("res://scenes/bodies/mass_body.tscn")
const LEVEL_SCENE := preload("res://scenes/levels/sandbox_level.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const FRAMES := 30

var _was_enabled: bool
var _body: MassBody


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_body = add_child_autofree(BODY_SCENE.instantiate())


func after_each() -> void:
	Contract.enabled = _was_enabled


func test_radius_sizes_mesh_collider_and_gravity_together() -> void:
	_body.radius = 80.0
	assert_eq(_body.mesh.scale, Vector3.ONE * 80.0)
	assert_eq(_body.collider.shape.radius, 80.0)
	assert_eq(_body.gravity.radius, 80.0)


func test_mass_reaches_the_gravity_component() -> void:
	_body.mass = 250.0
	assert_eq(_body.gravity.mass, 250.0)


func test_non_positive_radius_breaks_pre_condition_and_is_ignored() -> void:
	_body.radius = 0.0
	assert_push_error(
		"[Contract] Pre-condition broken: radius must be positive"
	)
	assert_eq(_body.radius, 50.0)
	assert_eq(_body.mesh.scale, Vector3.ONE * 50.0)


func test_non_positive_mass_breaks_pre_condition_and_is_ignored() -> void:
	_body.mass = -1.0
	assert_push_error("[Contract] Pre-condition broken: mass must be positive")
	assert_eq(_body.mass, 10000.0)
	assert_eq(_body.gravity.mass, 10000.0)


func test_bodies_share_the_mesh_but_own_their_collider_sphere() -> void:
	var other: MassBody = add_child_autofree(BODY_SCENE.instantiate())
	other.radius = 10.0
	assert_eq(other.mesh.mesh, _body.mesh.mesh)
	assert_ne(other.collider.shape, _body.collider.shape)
	assert_eq(_body.collider.shape.radius, 50.0)


func test_level_body_is_heavier_than_player_starting_mass() -> void:
	var level: Node = autofree(LEVEL_SCENE.instantiate())
	var body_gravity: GravityComponent = level.get_node(
		"MassBody/GravityComponent"
	)
	var player: Player = level.get_node("Player")
	assert_gt(body_gravity.mass, player.mass_component.starting_mass)


func test_moving_body_crashes_into_the_player() -> void:
	_body.radius = 1.0
	_body.position = Vector3(0.0, 0.0, -4.0)
	var player: Player = PLAYER_SCENE.instantiate()
	player.flight_input.capture_mouse = false
	add_child_autofree(player)
	watch_signals(player.contact_component)
	for i in FRAMES:
		_body.position.z += 0.2
		await wait_physics_frames(1)
	assert_signal_emitted(player.contact_component, "heavier_contact")
