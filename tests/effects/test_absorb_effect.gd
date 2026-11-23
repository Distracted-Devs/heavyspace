extends GutTest

const BODY_SCENE := preload("res://scenes/bodies/mass_body.tscn")
const DURATION := 0.5

var _was_enabled: bool
var _ship: Node3D
var _effect: AbsorbEffect


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_ship = add_child_autofree(Node3D.new())
	_ship.position = Vector3(10.0, 0.0, 0.0)
	_effect = AbsorbEffect.new()
	_effect.ship = _ship
	_effect.suck_duration = DURATION
	_effect.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(_effect)


func after_each() -> void:
	Contract.enabled = _was_enabled


func _body(at: Vector3, body_mass := 2.0, radius := 1.5) -> MassBody:
	var body: MassBody = BODY_SCENE.instantiate()
	body.radius = radius
	body.mass = body_mass
	body.position = at
	add_child_autofree(body)
	return body


func _absorbed_masses() -> Array[float]:
	var masses: Array[float] = []
	_effect.absorbed.connect(
		func(value: float) -> void:
			masses.append(value),
	)
	return masses


func test_caught_body_keeps_its_place_under_the_effect() -> void:
	var body := _body(Vector3(14.0, 3.0, 0.0))
	_effect.absorb(body)
	assert_eq(body.get_parent(), _effect)
	assert_almost_eq(
		body.global_position,
		Vector3(14.0, 3.0, 0.0),
		Vector3.ONE * 1.0e-5,
	)
	assert_true(_effect.is_absorbing(body))
	assert_eq(_effect.absorbing_count(), 1)


func test_caught_body_stops_being_a_gravity_source() -> void:
	var body := _body(Vector3(14.0, 0.0, 0.0))
	assert_gte(GravityRegistry.index_of(body.gravity), 0)
	var count := GravityRegistry.count()
	_effect.absorb(body)
	assert_eq(GravityRegistry.count(), count - 1)
	for child in body.get_children():
		assert_false(child is GravityComponent, "gravity must be gone")


func test_caught_body_cannot_collide_by_the_next_physics_step() -> void:
	var body := _body(Vector3(14.0, 0.0, 0.0))
	_effect.absorb(body)
	await wait_physics_frames(1)
	assert_true(body.collider.disabled)


func test_body_closes_in_on_the_ship_with_an_eased_lerp() -> void:
	var body := _body(Vector3(14.0, 0.0, 0.0))
	_effect.absorb(body)
	_effect.advance(DURATION * 0.5)
	var expected := _ship.global_position + Vector3(4.0, 0.0, 0.0) * 0.75
	assert_almost_eq(body.global_position, expected, Vector3.ONE * 1.0e-4)


func test_body_follows_a_moving_ship() -> void:
	var body := _body(Vector3(14.0, 0.0, 0.0))
	_effect.absorb(body)
	_ship.global_position += Vector3(0.0, 50.0, -20.0)
	_effect.advance(DURATION * 0.25)
	var remaining := 1.0 - 0.25 * 0.25
	var expected := _ship.global_position + Vector3(4.0, 0.0, 0.0) * remaining
	assert_almost_eq(body.global_position, expected, Vector3.ONE * 1.0e-4)


func test_body_shrinks_as_it_closes_in() -> void:
	var body := _body(Vector3(14.0, 0.0, 0.0), 2.0, 1.5)
	_effect.absorb(body)
	_effect.advance(DURATION * 0.5)
	assert_almost_eq(
		body.mesh.scale,
		Vector3.ONE * 1.5 * 0.75,
		Vector3.ONE * 1.0e-4,
	)


func test_body_keeps_its_size_with_shrink_off() -> void:
	_effect.shrink = false
	var body := _body(Vector3(14.0, 0.0, 0.0), 2.0, 1.5)
	_effect.absorb(body)
	_effect.advance(DURATION * 0.5)
	assert_eq(body.mesh.scale, Vector3.ONE * 1.5)


func test_body_arrives_on_the_ship_at_suck_duration_and_is_freed() -> void:
	var body := _body(Vector3(14.0, 0.0, 0.0))
	_effect.absorb(body)
	_effect.advance(DURATION * 0.6)
	assert_false(body.is_queued_for_deletion())
	_effect.advance(DURATION * 0.4)
	assert_almost_eq(
		body.global_position,
		_ship.global_position,
		Vector3.ONE * 1.0e-5,
	)
	assert_true(body.is_queued_for_deletion())
	assert_false(_effect.is_absorbing(body))
	assert_eq(_effect.absorbing_count(), 0)


func test_absorbed_is_emitted_once_with_the_body_and_extra_mass() -> void:
	var masses := _absorbed_masses()
	_effect.absorb(_body(Vector3(14.0, 0.0, 0.0), 2.0), 3.5)
	_effect.advance(DURATION)
	_effect.advance(DURATION)
	assert_eq(masses, [5.5] as Array[float])


func test_several_bodies_are_absorbed_independently() -> void:
	var masses := _absorbed_masses()
	_effect.absorb(_body(Vector3(14.0, 0.0, 0.0), 1.0))
	_effect.advance(DURATION * 0.5)
	_effect.absorb(_body(Vector3(6.0, 0.0, 0.0), 2.0))
	assert_eq(_effect.absorbing_count(), 2)
	_effect.advance(DURATION * 0.5)
	assert_eq(masses, [1.0] as Array[float])
	_effect.advance(DURATION * 0.5)
	assert_eq(masses, [1.0, 2.0] as Array[float])


func test_physics_frames_advance_the_absorb() -> void:
	_effect.process_mode = Node.PROCESS_MODE_INHERIT
	var masses := _absorbed_masses()
	_effect.suck_duration = 0.05
	_effect.absorb(_body(Vector3(14.0, 0.0, 0.0), 2.0))
	await wait_physics_frames(10)
	assert_eq(masses, [2.0] as Array[float])


func test_absorbing_a_body_twice_is_rejected() -> void:
	var body := _body(Vector3(14.0, 0.0, 0.0))
	_effect.absorb(body)
	_effect.absorb(body)
	assert_push_error(
		"[Contract] Pre-condition broken: body must not already be absorbing"
	)
	assert_eq(_effect.absorbing_count(), 1)


func test_negative_extra_mass_is_rejected() -> void:
	var body := _body(Vector3(14.0, 0.0, 0.0))
	_effect.absorb(body, -1.0)
	assert_push_error(
		"[Contract] Pre-condition broken: extra_mass must not be negative"
	)
	assert_false(_effect.is_absorbing(body))


func test_absorbing_without_a_ship_is_rejected() -> void:
	_effect.ship = null
	var body := _body(Vector3(14.0, 0.0, 0.0))
	_effect.absorb(body)
	assert_push_error("[Contract] Pre-condition broken: ship must be set")
	assert_false(_effect.is_absorbing(body))


func test_absorbing_null_is_rejected() -> void:
	_effect.absorb(null)
	assert_push_error("[Contract] Pre-condition broken: body must be valid")
	assert_eq(_effect.absorbing_count(), 0)


func test_non_positive_suck_duration_is_rejected() -> void:
	_effect.suck_duration = 0.0
	assert_push_error(
		"[Contract] Pre-condition broken: suck_duration must be positive"
	)
	assert_eq(_effect.suck_duration, DURATION)
