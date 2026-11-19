extends Node

var positions: PackedVector3Array:
	get:
		return _positions
var masses: PackedFloat64Array:
	get:
		return _masses
var radii: PackedFloat64Array:
	get:
		return _radii

var _sources: Array[GravityComponent] = []
var _nodes: Array[Node3D] = []
var _positions := PackedVector3Array()
var _masses := PackedFloat64Array()
var _radii := PackedFloat64Array()
var _index_of_source: Dictionary[GravityComponent, int] = { }


func _init() -> void:
	process_physics_priority = -2


func _physics_process(_delta: float) -> void:
	for index in _nodes.size():
		_positions[index] = _nodes[index].global_position


func count() -> int:
	return _sources.size()


func index_of(source: GravityComponent) -> int:
	return _index_of_source.get(source, -1)


func register(source: GravityComponent) -> void:
	if not Contract.require(source != null, "source must not be null"):
		return
	if not Contract.require(
		not _index_of_source.has(source),
		"source must not be registered",
	):
		return
	var node := source.source_node
	if not Contract.require(
		node != null and node.is_inside_tree(),
		"source parent must be a Node3D in the tree",
	):
		return
	_index_of_source[source] = _sources.size()
	_sources.append(source)
	_nodes.append(node)
	_positions.append(node.global_position)
	_masses.append(source.mass)
	_radii.append(source.radius)
	_check_lengths()


func unregister(source: GravityComponent) -> void:
	if not Contract.require(
		_index_of_source.has(source),
		"source must be registered",
	):
		return
	var index: int = _index_of_source[source]
	var last := _sources.size() - 1
	_move(last, index)
	_index_of_source.erase(source)
	_sources.resize(last)
	_nodes.resize(last)
	_positions.resize(last)
	_masses.resize(last)
	_radii.resize(last)
	_check_lengths()


func update(source: GravityComponent) -> void:
	var index := index_of(source)
	if not Contract.require(index >= 0, "source must be registered"):
		return
	_masses[index] = source.mass
	_radii[index] = source.radius


func sources_heavier_than(mass: float) -> PackedInt32Array:
	var heavier := PackedInt32Array()
	for index in _masses.size():
		if _masses[index] > mass:
			heavier.append(index)
	return heavier


func _move(from: int, to: int) -> void:
	var source := _sources[from]
	_sources[to] = source
	_nodes[to] = _nodes[from]
	_positions[to] = _positions[from]
	_masses[to] = _masses[from]
	_radii[to] = _radii[from]
	_index_of_source[source] = to


func _check_lengths() -> void:
	var size := _sources.size()
	Contract.invariant(
		(
			_nodes.size() == size and _positions.size() == size
			and _masses.size() == size and _radii.size() == size
			and _index_of_source.size() == size
		),
		"packed arrays must match count()",
	)
