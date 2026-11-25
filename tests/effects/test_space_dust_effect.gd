extends GutTest

var _was_enabled: bool
var _ship: RigidBody3D
var _view: CameraComponent
var _effect: SpaceDustEffect


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_ship = FakeBody.make()
	_ship.position = Vector3(10.0, 20.0, 30.0)
	_view = CameraComponent.new()
	_view.camera = Camera3D.new()
	_view.add_child(_view.camera)
	_view.set_physics_process(false)
	_ship.add_child(_view)
	add_child_autofree(_ship)
	_effect = SpaceDustEffect.new()
	_effect.ship = _ship
	_effect.camera_component = _view
	_effect.set_process(false)
	_ship.add_child(_effect)


func after_each() -> void:
	Contract.enabled = _was_enabled


func _parameter(parameter: StringName) -> Variant:
	var shader := _effect.particles.process_material as ShaderMaterial
	return shader.get_shader_parameter(parameter)


func test_the_box_is_centred_on_the_ship() -> void:
	_effect.update()
	assert_eq(_parameter(&"box_centre"), _ship.global_position)
	var half := _effect.spread * _view.distance
	assert_almost_eq(_parameter(&"box_half"), half, 1e-4)


func test_the_dust_drifts_against_the_travel() -> void:
	_ship.linear_velocity = Vector3(5.0, 0.0, 0.0)
	_effect.update()
	var speed := _effect.drift * _view.distance
	var drift: Vector3 = _parameter(&"drift")
	assert_almost_eq(drift, Vector3(-speed, 0.0, 0.0), Vector3.ONE * 1e-4)


func test_slow_dust_drifts_past_the_nose() -> void:
	_ship.linear_velocity = Vector3(0.1, 0.0, 0.0)
	_effect.update()
	var drift: Vector3 = _parameter(&"drift")
	assert_almost_eq(drift.normalized(), Vector3.BACK, Vector3.ONE * 1e-4)


func test_hidden_once_flight_has_stopped() -> void:
	_effect.update()
	assert_true(_effect.particles.visible)
	_ship.freeze = true
	_effect.update()
	assert_false(_effect.particles.visible)


func test_motes_scale_with_the_camera_distance() -> void:
	_effect.update()
	var mesh := _effect.particles.draw_pass_1 as CylinderMesh
	assert_almost_eq(mesh.height, _effect.mote_length * _view.distance, 1e-5)


func test_missing_components_are_reported() -> void:
	_effect.camera_component = null
	_effect.update()
	assert_push_error("ship and camera_component must be set")


func test_bad_settings_are_reported_and_ignored() -> void:
	_effect.amount = 0
	assert_push_error("amount must be at least 1")
	_effect.edge_fade = 1.0
	assert_push_error("edge_fade must be within [0, 1)")
	_effect.alpha = -0.5
	assert_push_error("alpha must be within [0, 1]")
	_effect.mote_length = 0.0
	assert_push_error("mote_length must be positive")
	assert_eq(_effect.amount, 250)
