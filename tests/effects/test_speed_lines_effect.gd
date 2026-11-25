extends GutTest

const STEP := 1.0 / 60.0

var _was_enabled: bool
var _ship: RigidBody3D
var _input: InputComponent
var _fuel: FuelComponent
var _thruster: ThrusterComponent
var _meter: EngineMeterComponent
var _view: CameraComponent
var _effect: SpeedLinesEffect


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
	_view.add_child(_view.camera)
	_view.set_physics_process(false)
	for child in [_input, _fuel, _thruster, _meter, _view]:
		_ship.add_child(child)
	add_child_autofree(_ship)
	_effect = SpeedLinesEffect.new()
	_effect.ship = _ship
	_effect.engine_meter = _meter
	_effect.camera_component = _view
	_effect.set_process(false)
	_ship.add_child(_effect)


func after_each() -> void:
	Contract.enabled = _was_enabled


func _accelerate(seconds: float) -> void:
	for step in roundi(seconds / STEP):
		_meter.update(STEP)


func _warp() -> WarpEffect:
	var warp := WarpEffect.new()
	warp.camera = add_child_autofree(Camera3D.new())
	warp.mesh = add_child_autofree(Node3D.new())
	warp.set_process(false)
	add_child_autofree(warp)
	_effect.warp_effect = warp
	return warp


func test_no_lines_while_coasting() -> void:
	_ship.linear_velocity = Vector3(0.0, 0.0, -50.0)
	_effect.update()
	assert_eq(_effect.level(), 0.0)
	assert_false(_effect.particles.emitting)


func test_a_full_boost_draws_full_lines() -> void:
	_input.thrust_intent = Vector3.FORWARD
	_accelerate(2.0)
	_ship.linear_velocity = Vector3(0.0, 0.0, -50.0)
	_effect.update()
	assert_almost_eq(_effect.level(), 1.0, 1e-2)
	assert_true(_effect.particles.emitting)
	var process := _effect.particles.process_material as ParticleProcessMaterial
	assert_almost_eq(
		process.direction,
		Vector3(0.0, 0.0, 1.0),
		Vector3.ONE * 1e-4,
	)


func test_the_lines_level_follows_thrust_acceleration() -> void:
	_meter.thrust_acceleration = 77.5
	assert_almost_eq(_effect.level(), 0.5, 1e-4)


func test_a_stopped_ship_draws_no_lines() -> void:
	_meter.thrust_acceleration = 150.0
	_ship.freeze = true
	assert_eq(_effect.level(), 0.0)


func test_a_warp_draws_lines_along_the_nose() -> void:
	var warp := _warp()
	warp.play_in()
	_ship.linear_velocity = Vector3(10.0, 0.0, 0.0)
	_effect.update()
	assert_almost_eq(_effect.level(), 1.0, 1e-4)
	var process := _effect.particles.process_material as ParticleProcessMaterial
	assert_almost_eq(
		process.direction,
		Vector3(0.0, 0.0, 1.0),
		Vector3.ONE * 1e-4,
	)
	assert_almost_eq(process.initial_velocity_max, _effect.warp_speed, 1e-3)


func test_missing_components_are_reported() -> void:
	_effect.engine_meter = null
	_effect.update()
	assert_push_error("ship, engine_meter and camera_component must be set")


func test_bad_settings_are_reported_and_ignored() -> void:
	_effect.max_accel = 1.0
	assert_push_error("max_accel must be above min_accel")
	_effect.lifetime = 0.0
	assert_push_error("lifetime must be positive")
	_effect.max_alpha = 2.0
	assert_push_error("max_alpha must be within [0, 1]")
	_effect.warp_stretch = 0.5
	assert_push_error("warp_stretch must be at least 1")
	assert_eq(_effect.max_accel, 150.0)
