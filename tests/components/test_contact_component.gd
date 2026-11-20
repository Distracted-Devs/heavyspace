extends GutTest

const BODY_SCENE := preload("res://scenes/bodies/mass_body.tscn")
const FRAMES := 30

var _was_enabled: bool
var _body: RigidBody3D
var _mass: MassComponent
var _contacts: ContactComponent


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_body = FakeBody.make()
	_mass = MassComponent.new()
	_mass.body = _body
	_mass.starting_mass = 2.0
	_contacts = ContactComponent.new()
	_contacts.body = _body
	_contacts.mass_component = _mass
	_body.add_child(_mass)
	_body.add_child(_contacts)
	add_child_autofree(_body)
	watch_signals(_contacts)


func after_each() -> void:
	Contract.enabled = _was_enabled


func _static_block(position: Vector3) -> StaticBody3D:
	var block := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	collider.shape = BoxShape3D.new()
	block.add_child(collider)
	block.position = position
	return add_child_autofree(block)


func _rigid_ball(ball_mass: float, position: Vector3) -> RigidBody3D:
	var ball := FakeBody.make()
	ball.mass = ball_mass
	ball.position = position
	return add_child_autofree(ball)


func _fly_into(target_position: Vector3) -> void:
	_body.linear_velocity = (target_position - _body.position).normalized() * 5
	await wait_physics_frames(FRAMES)


func test_body_reports_contacts() -> void:
	assert_true(_body.contact_monitor)
	assert_gte(_body.max_contacts_reported, 1)


func test_heavier_planet_emits_heavier_contact_once() -> void:
	var planet: MassBody = BODY_SCENE.instantiate()
	planet.radius = 1.0
	planet.position = Vector3(0.0, 0.0, -3.0)
	add_child_autofree(planet)
	await _fly_into(planet.position)
	assert_signal_emit_count(_contacts, "heavier_contact", 1)
	assert_signal_emitted_with_parameters(
		_contacts,
		"heavier_contact",
		[planet, planet.gravity.mass],
	)
	assert_signal_not_emitted(_contacts, "lighter_contact")


func test_lighter_body_emits_lighter_contact() -> void:
	var ball := _rigid_ball(1.0, Vector3(0.0, 0.0, -3.0))
	await _fly_into(ball.position)
	assert_signal_emitted_with_parameters(
		_contacts,
		"lighter_contact",
		[ball, 1.0],
	)
	assert_signal_not_emitted(_contacts, "heavier_contact")


func test_equal_mass_body_emits_lighter_contact() -> void:
	var ball := _rigid_ball(_mass.current_mass, Vector3(0.0, 0.0, -3.0))
	await _fly_into(ball.position)
	assert_signal_emit_count(_contacts, "lighter_contact", 1)
	assert_signal_not_emitted(_contacts, "heavier_contact")


func test_massless_body_emits_nothing() -> void:
	var block := _static_block(Vector3(0.0, 0.0, -3.0))
	await _fly_into(block.position)
	assert_gt(_body.linear_velocity.z, -4.0, "the bodies must have touched")
	assert_signal_not_emitted(_contacts, "heavier_contact")
	assert_signal_not_emitted(_contacts, "lighter_contact")


func test_touching_again_emits_again() -> void:
	var ball := _rigid_ball(1.0, Vector3.ZERO)
	_contacts._on_body_entered(ball)
	_contacts._on_body_entered(ball)
	assert_signal_emit_count(_contacts, "lighter_contact", 2)


func test_gravity_component_mass_wins_over_rigid_body_mass() -> void:
	var ball := _rigid_ball(1.0, Vector3(50.0, 0.0, 0.0))
	var source := GravityComponent.new()
	source.mass = 500.0
	ball.add_child(source)
	assert_eq(ContactComponent.mass_of(ball), 500.0)
