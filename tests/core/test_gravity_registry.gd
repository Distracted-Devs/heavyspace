extends GutTest

const REGISTRY_SCRIPT := preload("res://scripts/core/gravity_registry.gd")

var _was_enabled: bool
var _registry: Node


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_registry = autofree(REGISTRY_SCRIPT.new())


func after_each() -> void:
	Contract.enabled = _was_enabled


func _source(source_mass: float) -> GravityComponent:
	var source: GravityComponent = autofree(GravityComponent.new())
	source.mass = source_mass
	return source


func _assert_lengths_match_count() -> void:
	var size: int = _registry.count()
	assert_eq(_registry.positions.size(), size)
	assert_eq(_registry.masses.size(), size)
	assert_eq(_registry.radii.size(), size)


func test_register_stores_source_data_at_its_index() -> void:
	var source := _source(4.0)
	source.radius = 2.0
	source.source_position = Vector3(1.0, 2.0, 3.0)
	_registry.register(source)
	var index: int = _registry.index_of(source)
	assert_eq(_registry.count(), 1)
	assert_eq(_registry.positions[index], Vector3(1.0, 2.0, 3.0))
	assert_eq(_registry.masses[index], 4.0)
	assert_eq(_registry.radii[index], 2.0)


func test_duplicate_register_is_reported_and_ignored() -> void:
	var source := _source(4.0)
	_registry.register(source)
	_registry.register(source)
	assert_push_error(
		"[Contract] Pre-condition broken: source must not be registered"
	)
	assert_eq(_registry.count(), 1)
	_assert_lengths_match_count()


func test_null_register_is_reported_and_ignored() -> void:
	_registry.register(null)
	assert_push_error(
		"[Contract] Pre-condition broken: source must not be null"
	)
	assert_eq(_registry.count(), 0)


func test_stray_unregister_is_reported_and_ignored() -> void:
	_registry.register(_source(4.0))
	_registry.unregister(_source(5.0))
	assert_push_error(
		"[Contract] Pre-condition broken: source must be registered"
	)
	assert_eq(_registry.count(), 1)
	_assert_lengths_match_count()


func test_unregister_keeps_other_sources_data_and_lengths() -> void:
	var first := _source(1.0)
	var middle := _source(2.0)
	var last := _source(3.0)
	for source in [first, middle, last]:
		_registry.register(source)
	_registry.unregister(middle)
	assert_eq(_registry.count(), 2)
	assert_eq(_registry.index_of(middle), -1)
	assert_eq(_registry.masses[_registry.index_of(first)], 1.0)
	assert_eq(_registry.masses[_registry.index_of(last)], 3.0)
	_assert_lengths_match_count()


func test_sources_heavier_than_is_strict() -> void:
	var lighter := _source(1.0)
	var equal := _source(2.0)
	var heavier := _source(3.0)
	for source in [lighter, equal, heavier]:
		_registry.register(source)
	var expected := PackedInt32Array([_registry.index_of(heavier)])
	assert_eq(_registry.sources_heavier_than(2.0), expected)


func test_unregistered_source_is_no_longer_returned() -> void:
	var source := _source(10.0)
	_registry.register(source)
	_registry.unregister(source)
	assert_eq(_registry.sources_heavier_than(1.0), PackedInt32Array())


func test_update_of_unregistered_source_is_reported() -> void:
	_registry.update(_source(1.0))
	assert_push_error(
		"[Contract] Pre-condition broken: source must be registered"
	)
