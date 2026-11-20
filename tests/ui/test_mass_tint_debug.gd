extends GutTest

const BODY_SCENE := preload("res://scenes/bodies/mass_body.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var _player: Player
var _tint: MassTintDebug


func before_each() -> void:
	_player = PLAYER_SCENE.instantiate()
	_player.flight_input.capture_mouse = false
	_player.set_physics_process(false)
	add_child_autofree(_player)
	_player.freeze = true
	_tint = MassTintDebug.new()
	_tint.player = _player
	add_child_autofree(_tint)


func _spawn_body(body_mass: float) -> MassBody:
	var body: MassBody = BODY_SCENE.instantiate()
	body.mass = body_mass
	body.position = Vector3(1000.0, 0.0, 0.0)
	return add_child_autofree(body)


func test_heavier_body_is_tinted_red() -> void:
	var body := _spawn_body(10.0)
	await wait_process_frames(1)
	assert_eq(body.mesh.material_override, _tint.heavier_material)
	assert_eq(_tint.heavier_material.albedo_color, _tint.heavier_colour)


func test_lighter_and_equal_bodies_are_tinted_green() -> void:
	var lighter := _spawn_body(0.5)
	var equal := _spawn_body(_player.mass_component.current_mass)
	await wait_process_frames(1)
	assert_eq(lighter.mesh.material_override, _tint.lighter_material)
	assert_eq(equal.mesh.material_override, _tint.lighter_material)
	assert_eq(_tint.lighter_material.albedo_color, _tint.lighter_colour)


func test_tint_keeps_the_earth_texture() -> void:
	var base: StandardMaterial3D = MassBody.UNIT_SPHERE.material
	assert_eq(_tint.lighter_material.albedo_texture, base.albedo_texture)
	assert_eq(_tint.heavier_material.albedo_texture, base.albedo_texture)


func test_tint_flips_when_the_player_outgrows_a_body() -> void:
	var body := _spawn_body(5.0)
	await wait_process_frames(1)
	_player.mass_component.current_mass = 6.0
	await wait_process_frames(1)
	assert_eq(body.mesh.material_override, _tint.lighter_material)


func test_disabled_tint_clears_the_override() -> void:
	var body := _spawn_body(10.0)
	await wait_process_frames(1)
	_tint.enabled = false
	await wait_process_frames(1)
	assert_null(body.mesh.material_override)
