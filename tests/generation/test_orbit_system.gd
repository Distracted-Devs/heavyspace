extends GutTest

const DELTA := 1.0 / 60.0

var _was_enabled: bool
var _orbits: OrbitSystem
var _generator: SystemGenerator


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_orbits = OrbitSystem.new()
	_orbits.set_physics_process(false)
	add_child_autofree(_orbits)
	var settings := SystemSettings.new()
	settings.level_seed = 99
	_generator = SystemGenerator.new(settings)


func after_each() -> void:
	Contract.enabled = _was_enabled


func _add(spec: BodySpec, parent: int) -> int:
	return _orbits.add(autofree(Node3D.new()), spec, parent)


func _step(frames: int) -> void:
	for i in frames:
		_orbits.time += DELTA
		_orbits.update_positions()


func test_root_stays_at_the_origin() -> void:
	var root := _add(_generator.root(), OrbitSystem.NO_PARENT)
	_step(60)
	assert_eq(_orbits.position_of(root), Vector3.ZERO)


func test_child_stays_orbit_radius_from_its_parent() -> void:
	var root_spec := _generator.root()
	var root := _add(root_spec, OrbitSystem.NO_PARENT)
	var planet_spec := _generator.contents_of(root_spec)[0]
	var planet := _add(planet_spec, root)
	var moon_spec := _generator.contents_of(planet_spec)[0]
	var moon := _add(moon_spec, planet)
	for i in 10:
		_step(30)
		assert_almost_eq(
			_orbits.position_of(moon).distance_to(_orbits.position_of(planet)),
			moon_spec.orbit_radius,
			1e-3,
		)


func test_body_moves_along_its_orbit_and_follows_the_spec() -> void:
	var root_spec := _generator.root()
	var root := _add(root_spec, OrbitSystem.NO_PARENT)
	var spec := _generator.contents_of(root_spec)[0]
	var slot := _add(spec, root)
	_step(120)
	assert_almost_eq(
		_orbits.position_of(slot),
		spec.orbit_offset(_orbits.time),
		Vector3.ONE * 1e-3,
	)
	assert_eq(_orbits.body_of(slot).position, _orbits.position_of(slot))


func test_velocity_matches_the_change_in_position() -> void:
	var root_spec := _generator.root()
	var root := _add(root_spec, OrbitSystem.NO_PARENT)
	var planet_spec := _generator.contents_of(root_spec)[0]
	var planet := _add(planet_spec, root)
	var moon := _add(_generator.contents_of(planet_spec)[0], planet)
	_step(1)
	var before := _orbits.position_of(moon)
	var velocity := _orbits.velocity_of(moon)
	_step(1)
	var measured := (_orbits.position_of(moon) - before) / DELTA
	assert_almost_eq(measured, velocity, Vector3.ONE * 1e-2)


func test_removed_slot_is_reused_and_others_keep_their_parent() -> void:
	var root_spec := _generator.root()
	var root := _add(root_spec, OrbitSystem.NO_PARENT)
	var contents := _generator.contents_of(root_spec)
	var first := _add(contents[0], root)
	var second := _add(contents[1], root)
	var moon_spec := _generator.contents_of(contents[1])[0]
	var moon := _add(moon_spec, second)
	_orbits.remove(first)
	var reused := _add(contents[2], root)
	assert_eq(reused, first)
	_step(10)
	assert_almost_eq(
		_orbits.position_of(moon).distance_to(_orbits.position_of(second)),
		moon_spec.orbit_radius,
		1e-3,
	)
	assert_eq(_orbits.count(), 4)


func test_removing_a_parent_with_children_is_reported_and_ignored() -> void:
	var root_spec := _generator.root()
	var root := _add(root_spec, OrbitSystem.NO_PARENT)
	_add(_generator.contents_of(root_spec)[0], root)
	_orbits.remove(root)
	assert_push_error(
		"[Contract] Pre-condition broken: slot must have no active children"
	)
	assert_true(_orbits.is_active(root))


func test_adding_under_an_inactive_parent_is_reported() -> void:
	var slot := _add(_generator.root(), 7)
	assert_push_error(
		"[Contract] Pre-condition broken: parent slot must be active"
	)
	assert_eq(slot, OrbitSystem.NO_PARENT)
	assert_eq(_orbits.count(), 0)


func test_orbit_time_stops_while_paused() -> void:
	_orbits.set_physics_process(true)
	_add(_generator.root(), OrbitSystem.NO_PARENT)
	get_tree().paused = true
	var paused_time := _orbits.time
	await wait_physics_frames(10)
	get_tree().paused = false
	assert_eq(_orbits.time, paused_time)
