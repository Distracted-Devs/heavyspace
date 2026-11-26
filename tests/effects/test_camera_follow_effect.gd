extends GutTest

const STEP := 1.0 / 60.0

var _was_enabled: bool
var _ship: RigidBody3D
var _input: InputComponent
var _fuel: FuelComponent
var _thruster: ThrusterComponent
var _meter: EngineMeterComponent
var _view: CameraComponent
var _effect: CameraFollowEffect


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_ship = FakeBody.make()
	_input = InputComponent.new()
	_fuel = FuelComponent.new()
	_fuel.tank_size = 1000.0
	_fuel.set_physics_process(false)
	_thruster = ThrusterComponent.new()
	_thruster.body = _ship
	_thruster.flight_input = _input
	_thruster.back_thrust_force = 150.0
	_thruster.set_physics_process(false)
	_meter = EngineMeterComponent.new()
	_meter.body = _ship
	_meter.flight_input = _input
	_meter.fuel = _fuel
	_meter.thruster = _thruster
	_meter.set_physics_process(false)
	_view = CameraComponent.new()
	_view.camera = Camera3D.new()
	_view.camera.fov = 75.0
	_view.add_child(_view.camera)
	_view.set_physics_process(false)
	for child in [_input, _fuel, _thruster, _meter, _view]:
		_ship.add_child(child)
	add_child_autofree(_ship)
	_effect = CameraFollowEffect.new()
	_effect.ship = _ship
	_effect.camera_component = _view
	_effect.engine_meter = _meter
	_effect.set_physics_process(false)
	add_child_autofree(_effect)


func after_each() -> void:
	Contract.enabled = _was_enabled


func _run(seconds: float) -> Array[float]:
	var pulls: Array[float] = []
	for step in roundi(seconds / STEP):
		_effect.update(STEP)
		pulls.append(_view.follow_offset.z)
	return pulls


func _lag_angle() -> float:
	return _view.follow_rotation.get_angle()


func test_the_first_update_starts_on_the_ship() -> void:
	_ship.rotation.y = 1.0
	_run(STEP)
	assert_almost_eq(_lag_angle(), 0.0, 1e-4)


func test_the_camera_lags_behind_a_turn_then_catches_up() -> void:
	_run(STEP)
	_ship.rotation.y = 1.0
	_run(STEP)
	assert_gt(_lag_angle(), 0.9, "it starts behind the turn")
	_run(5.0)
	assert_almost_eq(_lag_angle(), 0.0, 1e-3)


func test_boosting_tightens_the_follow() -> void:
	_run(STEP)
	_ship.rotation.y = 1.0
	_run(0.25)
	var coasting := _lag_angle()
	_ship.rotation.y = 0.0
	_run(5.0)
	_input.thrust_intent = Vector3.FORWARD
	_ship.rotation.y = 1.0
	_run(0.25)
	assert_lt(_lag_angle(), coasting)


func test_the_boost_pull_overshoots_then_settles() -> void:
	_input.thrust_intent = Vector3.FORWARD
	var pulls := _run(6.0)
	var settled := pulls[-1]
	var target := _effect.max_pull * _view.distance
	assert_almost_eq(settled, target, 1e-3)
	assert_gt(pulls.max(), settled, "the spring overshoots")


func test_the_pull_builds_with_how_long_you_boost() -> void:
	_input.thrust_intent = Vector3.FORWARD
	var pulls := _run(0.3)
	assert_lt(pulls[-1], _effect.max_pull * _view.distance * 0.8)


func test_the_pull_returns_after_the_boost() -> void:
	_input.thrust_intent = Vector3.FORWARD
	_run(3.0)
	_input.thrust_intent = Vector3.ZERO
	_run(6.0)
	assert_almost_eq(_view.follow_offset.z, 0.0, 1e-3)


func test_the_camera_rolls_with_a_share_of_the_bank() -> void:
	var bank := BankEffect.new()
	bank.bank = 0.4
	bank.set_physics_process(false)
	add_child_autofree(bank)
	_effect.bank_effect = bank
	_run(STEP)
	assert_almost_eq(_view.follow_roll, 0.4 * _effect.camera_roll, 1e-6)


func test_the_fov_kicks_out_on_boost_and_comes_back() -> void:
	_input.thrust_intent = Vector3.FORWARD
	_run(4.0)
	assert_almost_eq(_view.camera.fov, 75.0 + _effect.fov_kick, 1e-2)
	_input.thrust_intent = Vector3.ZERO
	_run(4.0)
	assert_almost_eq(_view.camera.fov, 75.0, 1e-2)


func test_the_warp_owns_the_fov() -> void:
	var warp := WarpEffect.new()
	warp.camera = Camera3D.new()
	add_child_autofree(warp.camera)
	warp.mesh = add_child_autofree(Node3D.new())
	warp.set_process(false)
	add_child_autofree(warp)
	_effect.warp_effect = warp
	warp.play()
	_view.camera.fov = 100.0
	_input.thrust_intent = Vector3.FORWARD
	_run(0.5)
	assert_eq(_view.camera.fov, 100.0)


func test_a_stopped_ship_holds_the_camera_still() -> void:
	_run(STEP)
	_ship.rotation.y = 1.0
	_run(0.2)
	var held := _view.follow_rotation
	_ship.freeze = true
	_ship.rotation.y = -1.0
	_run(0.5)
	assert_eq(_view.follow_rotation, held)


func test_missing_components_are_reported() -> void:
	_effect.engine_meter = null
	_effect.update(STEP)
	assert_push_error("ship, camera_component and engine_meter must be set")


func test_bad_settings_are_reported_and_ignored() -> void:
	var follow_speed := _effect.follow_speed
	_effect.follow_speed = 0.0
	assert_push_error("follow_speed must be positive")
	_effect.pull_ramp_time = 0.0
	assert_push_error("pull_ramp_time must be positive")
	_effect.camera_roll = 1.5
	assert_push_error("camera_roll must be within [0, 1]")
	_effect.fov_kick = -1.0
	assert_push_error("fov_kick must not be negative")
	assert_eq(_effect.follow_speed, follow_speed)
