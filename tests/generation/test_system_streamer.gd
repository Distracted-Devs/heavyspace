extends GutTest

const BODY_SCENE := preload("res://scenes/bodies/mass_body.tscn")

var _was_enabled: bool
var _streamer: SystemStreamer
var _target: Node3D


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	var orbits := OrbitSystem.new()
	orbits.set_physics_process(false)
	add_child_autofree(orbits)
	var bodies: Node3D = add_child_autofree(Node3D.new())
	_target = add_child_autofree(Node3D.new())
	_target.position = Vector3(1e6, 0.0, 0.0)
	var settings := SystemSettings.new()
	settings.level_seed = 7
	_streamer = SystemStreamer.new()
	_streamer.settings = settings
	_streamer.body_scene = BODY_SCENE
	_streamer.orbit_system = orbits
	_streamer.bodies_root = bodies
	_streamer.target = _target
	_streamer.set_physics_process(false)
	add_child_autofree(_streamer)


func after_each() -> void:
	Contract.enabled = _was_enabled


func _root_spec() -> BodySpec:
	return _streamer.spec_of(_streamer.root_slot)


func _first_child_slot(parent: int) -> int:
	for slot in _streamer.live_slots():
		var spec := _streamer.spec_of(slot)
		if (
			_streamer.orbit_system.parent_of(slot) == parent
			and not spec.is_pickup
		):
			return slot
	return OrbitSystem.NO_PARENT


func _move_target_to(slot: int) -> void:
	_target.position = _streamer.orbit_system.position_of(slot)


func test_start_expands_the_root_only() -> void:
	_streamer.start()
	var root := _root_spec()
	assert_true(_streamer.is_expanded(_streamer.root_slot))
	assert_eq(
		_streamer.live_slots().size(),
		1 + root.child_count + root.pickup_count,
	)


func test_root_stays_expanded_when_the_target_is_far_away() -> void:
	_streamer.start()
	_streamer.update_streaming()
	assert_true(_streamer.is_expanded(_streamer.root_slot))


func test_nearby_body_expands_and_far_body_collapses() -> void:
	_streamer.start()
	var planet := _first_child_slot(_streamer.root_slot)
	var planet_spec := _streamer.spec_of(planet)
	_move_target_to(planet)
	_streamer.update_streaming()
	assert_true(_streamer.is_expanded(planet))
	_target.position = Vector3(1e6, 0.0, 0.0)
	_streamer.update_streaming()
	assert_false(_streamer.is_expanded(planet))
	assert_not_null(_streamer.spec_of(planet), planet_spec.key())


func test_hysteresis_keeps_a_body_expanded_between_the_factors() -> void:
	_streamer.start()
	var planet := _first_child_slot(_streamer.root_slot)
	var spec := _streamer.spec_of(planet)
	_move_target_to(planet)
	_streamer.update_streaming()
	var middle := (_streamer.expand_factor + _streamer.collapse_factor) / 2.0
	_target.position += spec.orbit_u * spec.system_radius * middle
	_streamer.update_streaming()
	assert_true(_streamer.is_expanded(planet))


func test_expanding_twice_is_a_no_op() -> void:
	_streamer.start()
	var before := _streamer.live_slots().size()
	_streamer.expand(_streamer.root_slot)
	assert_eq(_streamer.live_slots().size(), before)


func test_collapse_frees_exactly_the_subtree() -> void:
	_streamer.start()
	var before := _streamer.live_slots().size()
	var planet := _first_child_slot(_streamer.root_slot)
	_streamer.expand(planet)
	var moon := _first_child_slot(planet)
	_streamer.expand(moon)
	assert_gt(_streamer.live_slots().size(), before)
	_streamer.collapse(planet)
	assert_eq(_streamer.live_slots().size(), before)
	assert_eq(_streamer.orbit_system.count(), before)


func test_every_live_body_has_a_live_expanded_parent() -> void:
	_streamer.start()
	var planet := _first_child_slot(_streamer.root_slot)
	_move_target_to(planet)
	_streamer.update_streaming()
	var moon := _first_child_slot(planet)
	_move_target_to(moon)
	_streamer.update_streaming()
	for slot in _streamer.live_slots():
		if slot == _streamer.root_slot:
			continue
		var parent := _streamer.orbit_system.parent_of(slot)
		assert_true(_streamer.is_expanded(parent))


func test_consumed_bodies_are_not_respawned() -> void:
	_streamer.start()
	var planet := _first_child_slot(_streamer.root_slot)
	_streamer.expand(planet)
	var pickup: BodySpec = null
	for slot in _streamer.live_slots():
		var spec := _streamer.spec_of(slot)
		if spec.is_pickup and _streamer.orbit_system.parent_of(slot) == planet:
			pickup = spec
			break
	_streamer.mark_consumed(pickup)
	_streamer.collapse(planet)
	_streamer.expand(planet)
	for slot in _streamer.live_slots():
		assert_ne(_streamer.spec_of(slot).key(), pickup.key())


func test_spawned_bodies_match_their_spec() -> void:
	watch_signals(_streamer)
	_streamer.start()
	var root_body: MassBody = _streamer.orbit_system.body_of(
		_streamer.root_slot
	)
	assert_eq(root_body.radius, _root_spec().radius)
	assert_eq(root_body.mass, _root_spec().mass)
	assert_signal_emit_count(
		_streamer,
		"body_spawned",
		_streamer.live_slots().size(),
	)


func test_bad_factors_are_reported_and_nothing_starts() -> void:
	_streamer.collapse_factor = 1.0
	assert_false(_streamer.start())
	assert_push_error(
		"[Contract] Pre-condition broken: "
		+ "collapse_factor must be greater than expand_factor > 0"
	)
	assert_eq(_streamer.live_slots().size(), 0)
