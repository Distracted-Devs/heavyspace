extends GutTest

const STEP := 1.0 / 60.0

var _was_enabled: bool
var _ship: RigidBody3D
var _mesh: Node3D
var _effect: BankEffect


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_ship = FakeBody.make()
	_ship.set_physics_process(false)
	_mesh = Node3D.new()
	_mesh.scale = Vector3.ONE * 2.0
	_ship.add_child(_mesh)
	add_child_autofree(_ship)
	_effect = BankEffect.new()
	_effect.ship = _ship
	_effect.mesh = _mesh
	_effect.set_physics_process(false)
	add_child_autofree(_effect)


func after_each() -> void:
	Contract.enabled = _was_enabled


func _spin(yaw_rate: float, seconds: float) -> void:
	_ship.angular_velocity = _ship.global_basis * Vector3(0.0, yaw_rate, 0.0)
	for step in roundi(seconds / STEP):
		_effect.update(STEP)


func test_level_flight_doesnt_bank() -> void:
	_spin(0.0, 0.5)
	assert_eq(_effect.bank, 0.0)


func test_a_turn_banks_by_the_yaw_rate() -> void:
	_spin(0.5, 1.0)
	assert_almost_eq(_effect.bank, deg_to_rad(30.0), 1e-3)
	assert_almost_eq(_mesh.rotation.z, _effect.bank, 1e-3)


func test_the_bank_is_capped() -> void:
	_spin(5.0, 1.0)
	assert_almost_eq(_effect.bank, deg_to_rad(_effect.max_bank_degrees), 1e-3)


func test_it_tilts_back_after_the_turn() -> void:
	_spin(0.5, 1.0)
	_spin(0.0, 1.0)
	assert_almost_eq(_effect.bank, 0.0, 1e-3)


func test_banking_keeps_the_mesh_scale() -> void:
	_spin(0.5, 1.0)
	assert_almost_eq(_mesh.scale, Vector3.ONE * 2.0, Vector3.ONE * 1e-4)


func test_a_stopped_ship_leaves_the_mesh_alone() -> void:
	_ship.freeze = true
	_mesh.rotation = Vector3(0.3, 0.2, 0.1)
	_spin(0.5, 0.5)
	assert_almost_eq(_mesh.rotation, Vector3(0.3, 0.2, 0.1), Vector3.ONE * 1e-4)


func test_missing_components_are_reported() -> void:
	_effect.mesh = null
	_effect.update(STEP)
	assert_push_error("ship and mesh must be set")


func test_bad_settings_are_reported_and_ignored() -> void:
	_effect.bank_per_yaw_rate = -1.0
	assert_push_error("bank_per_yaw_rate must not be negative")
	var max_bank_degrees := _effect.max_bank_degrees
	_effect.max_bank_degrees = 95.0
	assert_push_error("max_bank_degrees must be within [0, 90]")
	_effect.bank_speed = 0.0
	assert_push_error("bank_speed must be positive")
	assert_eq(_effect.max_bank_degrees, max_bank_degrees)
