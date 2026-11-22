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


func _tinted_streamer() -> HierarchyStreamer:
	var systems := Tier.new()
	systems.orbit_inner = 1.5
	systems.orbit_outer = 3.0
	systems.radius_min = 1.0
	systems.radius_max = 3.0
	systems.mass_density = 0.1
	systems.thickness = 5.0
	systems.min_separation = 40.0
	systems.cell_size = 50.0
	systems.spawn_density = 5.0e-6
	var streamer := HierarchyStreamer.new()
	streamer.level_seed = 3
	streamer.root_radius = 100.0
	streamer.tiers = [systems]
	add_child_autofree(streamer)
	_tint.free()
	_tint = MassTintDebug.new()
	_tint.player = _player
	_tint.streamer = streamer
	add_child_autofree(_tint)
	return streamer


func _assert_drawn_tint(renderer: OrbitRenderer) -> void:
	var player_mass := _player.mass_component.current_mass
	var heavier := 0
	var lighter := 0
	for index in renderer.count():
		if renderer.layout.mass[index] > player_mass:
			assert_eq(renderer.tint(index), _tint.heavier_colour)
			heavier += 1
		else:
			assert_eq(renderer.tint(index), _tint.lighter_colour)
			lighter += 1
	assert_gt(heavier, 0)
	assert_gt(lighter, 0)


func test_drawn_bodies_are_tinted_by_mass() -> void:
	var streamer := _tinted_streamer()
	await wait_process_frames(1)
	_assert_drawn_tint(streamer.renderer_for(PackedInt32Array()))


func test_drawn_tint_flips_when_the_player_outgrows_a_body() -> void:
	var streamer := _tinted_streamer()
	await wait_process_frames(1)
	_player.mass_component.current_mass = 2.0
	await wait_process_frames(1)
	_assert_drawn_tint(streamer.renderer_for(PackedInt32Array()))


func test_disabling_untints_drawn_bodies() -> void:
	var streamer := _tinted_streamer()
	await wait_process_frames(1)
	_tint.enabled = false
	await wait_process_frames(1)
	var renderer := streamer.renderer_for(PackedInt32Array())
	for index in renderer.count():
		assert_eq(renderer.tint(index), OrbitRenderer.UNTINTED)
