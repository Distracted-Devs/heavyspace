extends GutTest

const STEP := 1.0 / 60.0

var _was_enabled: bool
var _ship: RigidBody3D
var _input: InputComponent
var _fuel: FuelComponent
var _thruster: ThrusterComponent
var _meter: EngineMeterComponent
var _camera: Camera3D
var _focus: Node3D
var _effect: RadialBlurEffect


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
	for child in [_input, _fuel, _thruster, _meter]:
		_ship.add_child(child)
	add_child_autofree(_ship)
	_camera = Camera3D.new()
	_camera.position = Vector3(0.0, 0.0, 5.0)
	add_child_autofree(_camera)
	_focus = add_child_autofree(Node3D.new())
	_effect = RadialBlurEffect.new()
	_effect.engine_meter = _meter
	_effect.camera = _camera
	_effect.focus = _focus
	_effect.set_process(false)
	add_child_autofree(_effect)


func after_each() -> void:
	Contract.enabled = _was_enabled


func _run(seconds: float) -> void:
	for step in roundi(seconds / STEP):
		_effect.update(STEP)


func _parameter(parameter: StringName) -> Variant:
	var shader := _effect.rect.material as ShaderMaterial
	return shader.get_shader_parameter(parameter)


func test_clear_and_hidden_while_coasting() -> void:
	_run(0.5)
	assert_eq(_effect.strength, 0.0)
	assert_false(_effect.rect.visible)


func test_a_full_boost_eases_up_to_the_blur_strength() -> void:
	_input.thrust_intent = Vector3.FORWARD
	_run(0.1)
	assert_lt(_effect.strength, _effect.blur_strength * 0.5)
	_run(3.0)
	assert_almost_eq(_effect.strength, _effect.blur_strength, 1e-3)
	assert_true(_effect.rect.visible)
	assert_almost_eq(_parameter(&"strength"), _effect.strength, 1e-5)


func test_a_warp_blurs_and_splits_the_colours() -> void:
	var warp := WarpEffect.new()
	warp.camera = add_child_autofree(Camera3D.new())
	warp.mesh = add_child_autofree(Node3D.new())
	warp.set_process(false)
	add_child_autofree(warp)
	_effect.warp_effect = warp
	warp.play_in()
	_effect.update(STEP)
	assert_almost_eq(_effect.strength, _effect.warp_blur, 1e-4)
	assert_almost_eq(_effect.aberration, _effect.warp_aberration, 1e-4)
	assert_true(_effect.rect.visible)


func test_the_blur_is_centred_on_the_focus() -> void:
	_input.thrust_intent = Vector3.FORWARD
	_run(0.5)
	var centre: Vector2 = _parameter(&"centre")
	assert_almost_eq(centre, Vector2(0.5, 0.5), Vector2.ONE * 1e-3)


func test_missing_components_are_reported() -> void:
	_effect.focus = null
	_effect.update(STEP)
	assert_push_error("engine_meter, camera and focus must be set")


func test_bad_settings_are_reported_and_ignored() -> void:
	var blur_strength := _effect.blur_strength
	_effect.blur_strength = -1.0
	assert_push_error("blur_strength must not be negative")
	_effect.clear_radius = 2.0
	assert_push_error("clear_radius must be within [0, 1]")
	_effect.falloff = 0.0
	assert_push_error("falloff must be positive")
	_effect.blur_speed = 0.0
	assert_push_error("blur_speed must be positive")
	assert_eq(_effect.blur_strength, blur_strength)
