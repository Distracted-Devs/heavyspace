class_name HierarchyStreamer
extends Node3D

signal expanded(path: PackedInt32Array, renderer: OrbitRenderer)
signal collapsing(path: PackedInt32Array, renderer: OrbitRenderer)
signal removed(path: PackedInt32Array)

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
@export var focus_mass: MassComponent

var resolved_seed := 0

var _paths: Array[PackedInt32Array] = []
var _depths := PackedInt32Array()
var _parent_slots := PackedInt32Array()
var _child_indices := PackedInt32Array()
var _layouts: Array[TierLayout] = []
var _slot_tiers: Array[Tier] = []
var _renderers: Array[OrbitRenderer] = []
var _slot_of: Dictionary[String, int] = { }
var _removed: Dictionary[String, bool] = { }
var _removed_indices: Dictionary[String, PackedInt32Array] = { }


func _init() -> void:
	process_physics_priority = -4


func _ready() -> void:
	if not _require_valid_tiers():
		return
	resolved_seed = level_seed if level_seed != 0 else _random_seed()
	var warning := mass_cap_warning()
	if warning != "" and OS.is_debug_build():
		print("[Debug] %s" % warning)
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
	if Contract.enabled:
		Contract.invariant(
			_hierarchy_is_consistent(),
			"every expanded parent must follow its expanded ancestors",
		)


func is_expanded(path: PackedInt32Array) -> bool:
	return _slot_of.has(_key(path))


func is_removed(path: PackedInt32Array) -> bool:
	for depth in range(1, path.size() + 1):
		if _removed.has(_key(path.slice(0, depth))):
			return true
	return false


func removed_indices(parent_path: PackedInt32Array) -> PackedInt32Array:
	return _removed_indices.get(_key(parent_path), PackedInt32Array())


func remove(path: PackedInt32Array) -> void:
	if not Contract.require(not path.is_empty(), "path must not be the root"):
		return
	var parent: int = _slot_of.get(_key(path.slice(0, -1)), NO_PARENT)
	if not Contract.require(
		parent != NO_PARENT,
		"path's parent must be expanded",
	):
		return
	var index := path[path.size() - 1]
	if not Contract.require(
		index >= 0 and index < _layouts[parent].size(),
		"path's index must be in its parent's layout",
	):
		return
	_removed[_key(path)] = true
	var parent_key := _key(path.slice(0, -1))
	var siblings: PackedInt32Array = _removed_indices.get(
		parent_key,
		PackedInt32Array(),
	)
	siblings.append(index)
	_removed_indices[parent_key] = siblings
	if is_expanded(path):
		var doomed := PackedByteArray()
		doomed.resize(_renderers.size())
		var root_of_subtree: int = _slot_of[_key(path)]
		for slot in range(root_of_subtree, _renderers.size()):
			if slot == root_of_subtree or doomed[_parent_slots[slot]]:
				doomed[slot] = 1
		_remove_slots(doomed)
	Contract.ensure(
		is_removed(path) and not is_expanded(path),
		"a removed path must not be expanded",
	)
	removed.emit(path)


func renderer_for(path: PackedInt32Array) -> OrbitRenderer:
	var slot: int = _slot_of.get(_key(path), NO_PARENT)
	return null if slot == NO_PARENT else _renderers[slot]


func tier_of(path: PackedInt32Array) -> Tier:
	var slot: int = _slot_of.get(_key(path), NO_PARENT)
	return null if slot == NO_PARENT else _slot_tiers[slot]


func expanded_paths() -> Array[PackedInt32Array]:
	return _paths.duplicate()


func mass_cap_warning() -> String:
	if focus_mass == null:
		return ""
	for depth in tiers.size():
		var tier := tiers[depth]
		if tier == null or not tier.is_mass_capped():
			continue
		var ceiling := focus_mass.starting_mass * tier.mass_ceiling_fraction
		if tier.mass_min > ceiling:
			return (
				"tier %d's mass_min (%s) is above the starting ceiling (%s), "
				% [depth, tier.mass_min, ceiling]
				+ "so its bodies can be heavier than the player"
			)
	return ""


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
	var layout := _layouts[slot]
	var positions := _renderers[slot].child_positions(time)
	# One path reused for every child; only its last index changes.
	var path := _paths[slot].duplicate()
	path.append(0)
	var last := path.size() - 1
	for index in layout.size():
		path[last] = index
		var tier := _tier_for(child_depth, path, layout.radius[index])
		var centre := positions[index]
		var reach := tier.expand_distance
		if focus_position.distance_squared_to(centre) >= reach * reach:
			continue
		if is_expanded(path) or _removed.has(_key(path)):
			continue
		var child_path := path.duplicate()
		var child_slot := _add_slot(
			child_path,
			slot,
			index,
			layout.radius[index],
		)
		_renderers[child_slot].global_position = centre


func _add_slot(
	path: PackedInt32Array,
	parent_slot: int,
	child_index: int,
	radius: float,
) -> int:
	var depth := path.size()
	var tier := _tier_for(depth, path, radius)
	var layout := TierGenerator.generate(
		resolved_seed,
		path,
		radius,
		tier,
		_focus_mass_now(),
	)
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


func _focus_mass_now() -> float:
	return NAN if focus_mass == null else focus_mass.current_mass


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
		valid = (
			Contract.require(
				not tier.is_mass_capped() or focus_mass != null,
				"a capped tier needs focus_mass",
			)
			and valid
		)
	return valid


func _hierarchy_is_consistent() -> bool:
	if _depths.is_empty() or _depths[ROOT_SLOT] != 0:
		return false
	for slot in range(1, _renderers.size()):
		var parent := _parent_slots[slot]
		if (
			parent < 0 or parent >= slot or _depths[slot] != _depths[parent] + 1
			or not is_instance_valid(_renderers[slot])
			or _removed.has(_key(_paths[slot]))
		):
			return false
	return _slot_of.size() == _renderers.size()


func _key(path: PackedInt32Array) -> String:
	return str(path)


func _random_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return maxi(rng.randi(), 1)
