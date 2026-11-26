extends GutTest

const STEP := 1.0 / 60.0

var _was_enabled: bool
var _body: RigidBody3D
var _input: InputComponent
var _fuel: FuelComponent
var _thruster: ThrusterComponent
var _meter: EngineMeterComponent
var _particles: GPUParticles3D
var _process: ParticleProcessMaterial
var _effect: ThrustEffect


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_body = FakeBody.make()
	_input = InputComponent.new()
	_fuel = FuelComponent.new()
	_fuel.set_physics_process(false)
	_thruster = ThrusterComponent.new()
	_thruster.body = _body
	_thruster.flight_input = _input
	_thruster.back_thrust_force = 150.0
	_thruster.set_physics_process(false)
	_meter = EngineMeterComponent.new()
	_meter.body = _body
	_meter.flight_input = _input
	_meter.fuel = _fuel
	_meter.thruster = _thruster
	_meter.set_physics_process(false)
	for child in [_input, _fuel, _thruster, _meter]:
		_body.add_child(child)
	add_child_autofree(_body)
	_process = ParticleProcessMaterial.new()
	_process.initial_velocity_min = 4.0
	_process.initial_velocity_max = 6.0
	_process.scale_min = 1.0
	_process.scale_max = 2.0
	_particles = GPUParticles3D.new()
	_particles.process_material = _process
	add_child_autofree(_particles)
	_effect = ThrustEffect.new()
	_effect.engine_meter = _meter
	_effect.particles = _particles
	_effect.set_process(false)
	add_child_autofree(_effect)


func after_each() -> void:
	Contract.enabled = _was_enabled


func _run(seconds: float) -> void:
	for step in roundi(seconds / STEP):
		_effect.update(STEP)


func _material() -> ParticleProcessMaterial:
	return _particles.process_material as ParticleProcessMaterial


func test_it_works_on_its_own_copy_of_the_material() -> void:
	assert_ne(_material(), _process)


func test_idles_at_the_idle_look() -> void:
	_run(1.0)
	assert_true(_particles.emitting)
	assert_almost_eq(_particles.amount_ratio, _effect.idle_amount, 1e-4)
	var velocity := _effect.idle_velocity * 4.0
	assert_almost_eq(_material().initial_velocity_min, velocity, 1e-3)
	assert_almost_eq(_material().scale_max, _effect.idle_scale * 2.0, 1e-3)


func test_full_boost_spools_up_to_the_boost_look() -> void:
	_input.thrust_intent = Vector3.FORWARD
	_run(3.0)
	assert_almost_eq(_effect.engine_level, 1.0, 1e-3)
	assert_almost_eq(_particles.amount_ratio, 1.0, 1e-3)
	var velocity := _effect.boost_velocity * 6.0
	assert_almost_eq(_material().initial_velocity_max, velocity, 1e-2)
	assert_almost_eq(_material().scale_min, _effect.boost_scale, 1e-3)


func test_a_stronger_booster_runs_the_plume_harder() -> void:
	_thruster.thrust_multiplier = 2.0
	_input.thrust_intent = Vector3.FORWARD
	_run(3.0)
	assert_almost_eq(_effect.engine_level, 2.0, 1e-2)
	var at_one := _effect.boost_velocity * 4.0
	assert_gt(_material().initial_velocity_min, at_one)


func test_it_spools_up_faster_than_down() -> void:
	_input.thrust_intent = Vector3.FORWARD
	_run(0.2)
	var risen := _effect.engine_level
	_run(3.0)
	_input.thrust_intent = Vector3.ZERO
	_run(0.2)
	assert_gt(risen, 1.0 - _effect.engine_level)


func test_hidden_once_flight_has_stopped() -> void:
	_body.freeze = true
	_effect.update(STEP)
	assert_false(_particles.emitting)


func test_hidden_while_warping() -> void:
	var warp := WarpEffect.new()
	warp.camera = add_child_autofree(Camera3D.new())
	warp.mesh = add_child_autofree(Node3D.new())
	warp.set_process(false)
	add_child_autofree(warp)
	_effect.warp_effect = warp
	warp.play()
	_effect.update(STEP)
	assert_false(_particles.emitting)


func test_missing_components_are_reported() -> void:
	_effect.particles = null
	_effect.update(STEP)
	assert_push_error("engine_meter and particles must be set")


func test_bad_settings_are_reported_and_ignored() -> void:
	_effect.idle_level = 1.5
	assert_push_error("idle_level must be within [0, 1]")
	var spool_up := _effect.spool_up
	_effect.spool_up = 0.0
	assert_push_error("spool_up must be positive")
	_effect.spool_down = -1.0
	assert_push_error("spool_down must be positive")
	_effect.idle_amount = 2.0
	assert_push_error("idle_amount must be within [0, 1]")
	_effect.boost_velocity = -1.0
	assert_push_error("boost_velocity must not be negative")
	assert_eq(_effect.spool_up, spool_up)
