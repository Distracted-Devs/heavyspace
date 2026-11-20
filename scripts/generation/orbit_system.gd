class_name OrbitSystem
extends Node

const NO_PARENT := -1
const TOLERANCE := 1e-3

var time := 0.0

var _bodies: Array[Node3D] = []
var _parents := PackedInt32Array()
var _depths := PackedInt32Array()
var _orbit_radii := PackedFloat64Array()
var _angular_speeds := PackedFloat64Array()
var _phases := PackedFloat64Array()
var _orbit_us := PackedVector3Array()
var _orbit_vs := PackedVector3Array()
var _positions := PackedVector3Array()
var _child_counts := PackedInt32Array()
var _active := PackedByteArray()
var _free_slots := PackedInt32Array()
var _slots_by_depth: Array[PackedInt32Array] = []
var _depth_index := PackedInt32Array()
var _count := 0


func _init() -> void:
	process_physics_priority = -3


func _physics_process(delta: float) -> void:
	time += delta
	update_positions()


func count() -> int:
	return _count


func is_active(slot: int) -> bool:
	return slot >= 0 and slot < _active.size() and _active[slot] == 1


func position_of(slot: int) -> Vector3:
	return _positions[slot]


func velocity_of(slot: int) -> Vector3:
	var velocity := Vector3.ZERO
	while slot != NO_PARENT:
		velocity += _orbit_velocity(slot)
		slot = _parents[slot]
	return velocity


func body_of(slot: int) -> Node3D:
	return _bodies[slot]


func parent_of(slot: int) -> int:
	return _parents[slot]


func add(body: Node3D, spec: BodySpec, parent: int) -> int:
	if not Contract.require(
		parent == NO_PARENT or is_active(parent),
		"parent slot must be active",
	):
		return NO_PARENT
	var slot := _allocate()
	var depth := 0 if parent == NO_PARENT else _depths[parent] + 1
	_bodies[slot] = body
	_parents[slot] = parent
	_depths[slot] = depth
	_orbit_radii[slot] = spec.orbit_radius
	_angular_speeds[slot] = spec.angular_speed
	_phases[slot] = spec.phase
	_orbit_us[slot] = spec.orbit_u
	_orbit_vs[slot] = spec.orbit_v
	_child_counts[slot] = 0
	_active[slot] = 1
	if parent != NO_PARENT:
		_child_counts[parent] += 1
	while _slots_by_depth.size() <= depth:
		_slots_by_depth.append(PackedInt32Array())
	_depth_index[slot] = _slots_by_depth[depth].size()
	_slots_by_depth[depth].append(slot)
	_count += 1
	_positions[slot] = _place(slot)
	body.position = _positions[slot]
	_check_lengths()
	return slot


func remove(slot: int) -> void:
	if not Contract.require(is_active(slot), "slot must be active"):
		return
	if not Contract.require(
		_child_counts[slot] == 0,
		"slot must have no active children",
	):
		return
	var parent := _parents[slot]
	if parent != NO_PARENT:
		_child_counts[parent] -= 1
	var list := _slots_by_depth[_depths[slot]]
	var index := _depth_index[slot]
	var last := list[list.size() - 1]
	list[index] = last
	_depth_index[last] = index
	list.resize(list.size() - 1)
	_slots_by_depth[_depths[slot]] = list
	_active[slot] = 0
	_bodies[slot] = null
	_free_slots.append(slot)
	_count -= 1
	_check_lengths()


func update_positions() -> void:
	for slots in _slots_by_depth:
		for slot in slots:
			var position := _place(slot)
			_positions[slot] = position
			_bodies[slot].position = position
			var parent := _parents[slot]
			if parent != NO_PARENT:
				Contract.invariant(
					absf(
						position.distance_to(_positions[parent])
						- _orbit_radii[slot]
					)
					< TOLERANCE * maxf(_orbit_radii[slot], 1.0),
					"body must stay orbit_radius from its parent",
				)


func _place(slot: int) -> Vector3:
	var parent := _parents[slot]
	if parent == NO_PARENT:
		return Vector3.ZERO
	var angle := _phases[slot] + _angular_speeds[slot] * time
	return _positions[parent] + _orbit_radii[slot] * (
		cos(angle) * _orbit_us[slot] + sin(angle) * _orbit_vs[slot]
	)


func _orbit_velocity(slot: int) -> Vector3:
	if _parents[slot] == NO_PARENT:
		return Vector3.ZERO
	var angle := _phases[slot] + _angular_speeds[slot] * time
	return (
		_orbit_radii[slot] * _angular_speeds[slot]
		* (-sin(angle) * _orbit_us[slot] + cos(angle) * _orbit_vs[slot])
	)


func _allocate() -> int:
	if not _free_slots.is_empty():
		var reused := _free_slots[_free_slots.size() - 1]
		_free_slots.resize(_free_slots.size() - 1)
		return reused
	var slot := _active.size()
	_bodies.append(null)
	_parents.append(NO_PARENT)
	_depths.append(0)
	_orbit_radii.append(0.0)
	_angular_speeds.append(0.0)
	_phases.append(0.0)
	_orbit_us.append(Vector3.ZERO)
	_orbit_vs.append(Vector3.ZERO)
	_positions.append(Vector3.ZERO)
	_child_counts.append(0)
	_active.append(0)
	_depth_index.append(0)
	return slot


func _check_lengths() -> void:
	var size := _active.size()
	var listed := 0
	for slots in _slots_by_depth:
		listed += slots.size()
	Contract.invariant(
		(
			_bodies.size() == size and _parents.size() == size
			and _depths.size() == size and _orbit_radii.size() == size
			and _angular_speeds.size() == size and _phases.size() == size
			and _orbit_us.size() == size and _orbit_vs.size() == size
			and _positions.size() == size and _child_counts.size() == size
			and _depth_index.size() == size and listed == _count
			and _count + _free_slots.size() == size
		),
		"orbit arrays must stay parallel and every active slot listed once",
	)
