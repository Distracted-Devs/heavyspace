extends GutTest

const BODY_SCENE := preload("res://scenes/bodies/mass_body.tscn")
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
	var radius := _body.radius
	_body.radius = 0.0
	assert_push_error(
		"[Contract] Pre-condition broken: radius must be positive"
	)
	assert_eq(_body.radius, radius)
	assert_eq(_body.mesh.scale, Vector3.ONE * radius)


func test_non_positive_mass_breaks_pre_condition_and_is_ignored() -> void:
	var mass := _body.mass
	_body.mass = -1.0
	assert_push_error("[Contract] Pre-condition broken: mass must be positive")
	assert_eq(_body.mass, mass)
	assert_eq(_body.gravity.mass, mass)


func test_bodies_share_the_mesh_but_own_their_collider_sphere() -> void:
	var other: MassBody = add_child_autofree(BODY_SCENE.instantiate())
	other.radius = 10.0
	assert_eq(other.mesh.mesh, _body.mesh.mesh)
	assert_ne(other.collider.shape, _body.collider.shape)
	assert_eq(_body.collider.shape.radius, 50.0)


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


func test_look_seed_reaches_the_mesh_instance_parameter() -> void:
	_body.look_seed = 0.25
	assert_almost_eq(
		float(_body.mesh.get_instance_shader_parameter(&"seed")),
		0.25,
		1.0e-6,
	)


func test_look_seed_outside_zero_to_one_is_reported_and_ignored() -> void:
	_body.look_seed = 0.4
	_body.look_seed = 1.0
	assert_push_error(
		"[Contract] Pre-condition broken: look_seed must be within [0, 1)"
	)
	assert_eq(_body.look_seed, 0.4)


func _tilted() -> Basis:
	return Basis(Vector3(1.0, 0.5, -0.3).normalized(), 1.1)


func test_surface_frame_turns_the_mesh_at_its_radius() -> void:
	_body.surface_frame = _tilted()
	var expected := _tilted() * Basis.from_scale(Vector3.ONE * _body.radius)
	assert_true(_body.mesh.basis.is_equal_approx(expected))


func test_radius_change_keeps_the_surface_frame() -> void:
	_body.surface_frame = _tilted()
	_body.radius = 7.0
	var expected := _tilted() * Basis.from_scale(Vector3.ONE * 7.0)
	assert_true(_body.mesh.basis.is_equal_approx(expected))
	assert_eq(_body.collider.shape.radius, 7.0)


func test_surface_frame_set_before_ready_is_applied() -> void:
	var other: MassBody = BODY_SCENE.instantiate()
	other.surface_frame = _tilted()
	add_child_autofree(other)
	var expected := _tilted() * Basis.from_scale(Vector3.ONE * other.radius)
	assert_true(other.mesh.basis.is_equal_approx(expected))


func test_surface_frame_not_a_rotation_is_reported_and_ignored() -> void:
	_body.surface_frame = Basis.from_scale(Vector3(1.0, 2.0, 1.0))
	_body.surface_frame = Basis.FLIP_X
	for bad_value in 2:
		assert_push_error(
			"[Contract] Pre-condition broken: surface_frame must be a rotation",
		)
	assert_eq(_body.surface_frame, Basis.IDENTITY)


func test_bodies_share_the_planet_material() -> void:
	var other: MassBody = add_child_autofree(BODY_SCENE.instantiate())
	var material := _body.mesh.mesh.surface_get_material(0)
	assert_eq(material, load("res://resources/materials/planet.tres"))
	assert_eq(other.mesh.mesh.surface_get_material(0), material)
