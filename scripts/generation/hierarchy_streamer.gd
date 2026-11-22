class_name HierarchyStreamer
extends Node3D

signal expanded(path: PackedInt32Array, renderer: OrbitRenderer)
signal collapsing(path: PackedInt32Array, renderer: OrbitRenderer)

const ROOT_SLOT := 0
const NO_PARENT := -1

@export_group("Generation")
@export var level_seed := 0
@export_range(0.01, 1.0e5, 0.01, "or_greater") var root_radius := 5000.0
@export_range(0.01, 1.0e9, 0.01, "or_greater") var root_mass := 1.0e7
@export var tiers: Array[Tier] = []

@export_group("Components")
@export var clock: Clock
@export var focus: Node3D

var resolved_seed := 0

var _paths: Array[PackedInt32Array] = []
var _depths := PackedInt32Array()
var _parent_slots := PackedInt32Array()
var _child_indices := PackedInt32Array()
var _layouts: Array[TierLayout] = []
var _slot_tiers: Array[Tier] = []
var _renderers: Array[OrbitRenderer] = []
var _slot_of: Dictionary[String, int] = { }


func _init() -> void:
	process_physics_priority = -4


func _ready() -> void:
	if not _require_valid_tiers():
		return
	resolved_seed = level_seed if level_seed != 0 else _random_seed()
	_add_slot(PackedInt32Array(), NO_PARENT, 0, root_radius)


func _physics_process(_delta: float) -> void:
	if clock != null and focus != null:
		update(focus.global_position, clock.time)


func update(focus_position: Vector3, time: float) -> void:
	if _renderers.is_empty():
		return
	_place_renderers(time)
	_collapse_far(focus_position)
	_expand_near(focus_position, time)
	Contract.invariant(
		_hierarchy_is_consistent(),
		"every expanded parent must follow its expanded ancestors",
	)


func is_expanded(path: PackedInt32Array) -> bool:
	return _slot_of.has(_key(path))


func renderer_for(path: PackedInt32Array) -> OrbitRenderer:
	var slot: int = _slot_of.get(_key(path), NO_PARENT)
	return null if slot == NO_PARENT else _renderers[slot]


func tier_of(path: PackedInt32Array) -> Tier:
	var slot: int = _slot_of.get(_key(path), NO_PARENT)
	return null if slot == NO_PARENT else _slot_tiers[slot]


func expanded_paths() -> Array[PackedInt32Array]:
	return _paths.duplicate()


func _tier_for(
	depth: int,
	_path: PackedInt32Array,
	_parent_radius: float,
) -> Tier:
	return tiers[depth]


func _place_renderers(time: float) -> void:
	for slot in range(1, _renderers.size()):
		var parent := _renderers[_parent_slots[slot]]
		_renderers[slot].global_position = parent.child_position(
			_child_indices[slot],
			time,
		)


func _collapse_far(focus_position: Vector3) -> void:
	var count := _renderers.size()
	var doomed := PackedByteArray()
	doomed.resize(count)
	var any_doomed := false
	for slot in range(1, count):
		var tier := _slot_tiers[slot]
		var distance := focus_position.distance_to(
			_renderers[slot].global_position,
		)
		if doomed[_parent_slots[slot]] or distance > tier.collapse_distance:
			doomed[slot] = 1
			any_doomed = true
	if any_doomed:
		_remove_slots(doomed)


func _expand_near(focus_position: Vector3, time: float) -> void:
	var slot := 0
	while slot < _renderers.size():
		var child_depth := _depths[slot] + 1
		if child_depth < tiers.size():
			_expand_children_near(slot, child_depth, focus_position, time)
		slot += 1


func _expand_children_near(
	slot: int,
	child_depth: int,
	focus_position: Vector3,
	time: float,
) -> void:
	var renderer := _renderers[slot]
	var layout := _layouts[slot]
	for index in layout.size():
		var path := _paths[slot].duplicate()
		path.append(index)
		var tier := _tier_for(child_depth, path, layout.radius[index])
		var centre := renderer.child_position(index, time)
		if focus_position.distance_to(centre) >= tier.expand_distance:
			continue
		if is_expanded(path):
			continue
		var child_slot := _add_slot(path, slot, index, layout.radius[index])
		_renderers[child_slot].global_position = centre


func _add_slot(
	path: PackedInt32Array,
	parent_slot: int,
	child_index: int,
	radius: float,
) -> int:
	var depth := path.size()
	var tier := _tier_for(depth, path, radius)
	var layout := TierGenerator.generate(resolved_seed, path, radius, tier)
	var renderer := OrbitRenderer.new()
	renderer.name = "Children%s" % _key(path)
	add_child(renderer)
	renderer.show_layout(layout)
	var slot := _renderers.size()
	_paths.append(path)
	_depths.append(depth)
	_parent_slots.append(parent_slot)
	_child_indices.append(child_index)
	_layouts.append(layout)
	_slot_tiers.append(tier)
	_renderers.append(renderer)
	_slot_of[_key(path)] = slot
	expanded.emit(path, renderer)
	return slot


func _remove_slots(doomed: PackedByteArray) -> void:
	for slot in range(_renderers.size() - 1, 0, -1):
		if doomed[slot]:
			collapsing.emit(_paths[slot], _renderers[slot])
			_renderers[slot].queue_free()

	var new_slot_of_old := PackedInt32Array()
	new_slot_of_old.resize(_renderers.size())
	var kept := 0
	for slot in _renderers.size():
		if doomed[slot]:
			new_slot_of_old[slot] = NO_PARENT
			continue
		new_slot_of_old[slot] = kept
		_paths[kept] = _paths[slot]
		_depths[kept] = _depths[slot]
		var parent := _parent_slots[slot]
		_parent_slots[kept] = (
			NO_PARENT if parent == NO_PARENT else new_slot_of_old[parent]
		)
		_child_indices[kept] = _child_indices[slot]
		_layouts[kept] = _layouts[slot]
		_slot_tiers[kept] = _slot_tiers[slot]
		_renderers[kept] = _renderers[slot]
		kept += 1

	_paths.resize(kept)
	_depths.resize(kept)
	_parent_slots.resize(kept)
	_child_indices.resize(kept)
	_layouts.resize(kept)
	_slot_tiers.resize(kept)
	_renderers.resize(kept)
	_slot_of.clear()
	for slot in kept:
		_slot_of[_key(_paths[slot])] = slot


func _require_valid_tiers() -> bool:
	if not Contract.require(not tiers.is_empty(), "tiers must not be empty"):
		return false
	if not Contract.require(not tiers.has(null), "tiers must not contain null"):
		return false
	var smallest_parent := root_radius
	var largest_parent := root_radius
	var valid := true
	for tier in tiers:
		valid = tier.require_valid(smallest_parent) and valid
		valid = tier.require_valid(largest_parent) and valid
		smallest_parent = tier.radius_min
		largest_parent = tier.radius_max
	return valid


func _hierarchy_is_consistent() -> bool:
	if _depths.is_empty() or _depths[ROOT_SLOT] != 0:
		return false
	for slot in range(1, _renderers.size()):
		var parent := _parent_slots[slot]
		if (
			parent < 0 or parent >= slot or _depths[slot] != _depths[parent] + 1
			or not is_instance_valid(_renderers[slot])
		):
			return false
	return _slot_of.size() == _renderers.size()


func _key(path: PackedInt32Array) -> String:
	return str(path)


func _random_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return maxi(rng.randi(), 1)
