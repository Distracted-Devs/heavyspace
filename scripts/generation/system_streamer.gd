class_name SystemStreamer
extends Node

signal body_spawned(body: MassBody, spec: BodySpec)

@export_group("Components")
@export var settings: SystemSettings
@export var body_scene: PackedScene
@export var orbit_system: OrbitSystem
@export var bodies_root: Node3D
@export var target: Node3D

@export_group("Streaming")
@export var expand_factor := 1.5
@export var collapse_factor := 2.0
@export var check_interval := 0.25

var generator: SystemGenerator
var consumed: Dictionary[String, bool] = { }
var root_slot := OrbitSystem.NO_PARENT

var _specs: Array[BodySpec] = []
var _expanded := PackedByteArray()
var _children: Array[PackedInt32Array] = []
var _since_check := 0.0


func _init() -> void:
	process_physics_priority = -4


func _physics_process(delta: float) -> void:
	if generator == null:
		return
	_since_check += delta
	if _since_check < check_interval:
		return
	_since_check = 0.0
	update_streaming()


func start() -> bool:
	if not Contract.require(
		collapse_factor > expand_factor and expand_factor > 0.0,
		"collapse_factor must be greater than expand_factor > 0",
	):
		return false
	if not Contract.require(
		bodies_root.global_transform == Transform3D.IDENTITY,
		"bodies_root must have an identity global transform",
	):
		return false
	generator = SystemGenerator.new(settings)
	if not generator.valid:
		generator = null
		return false
	root_slot = _spawn(generator.root(), OrbitSystem.NO_PARENT)
	expand(root_slot)
	if OS.is_debug_build():
		print("[Debug] Generated system with seed %d" % generator.level_seed)
	return true


func spec_of(slot: int) -> BodySpec:
	return _specs[slot] if slot < _specs.size() else null


func is_expanded(slot: int) -> bool:
	return slot < _expanded.size() and _expanded[slot] == 1


func live_slots() -> PackedInt32Array:
	var slots := PackedInt32Array()
	for slot in _specs.size():
		if _specs[slot] != null:
			slots.append(slot)
	return slots


func mark_consumed(spec: BodySpec) -> void:
	consumed[spec.key()] = true


func update_streaming() -> void:
	var target_position := target.global_position
	var slot := 0
	while slot < _specs.size():
		var spec := _specs[slot]
		if spec != null and not spec.is_pickup:
			var distance := target_position.distance_to(
				orbit_system.position_of(slot)
			)
			if (
				not is_expanded(slot)
				and distance < expand_factor * spec.system_radius
			):
				expand(slot)
			elif (
				is_expanded(slot) and slot != root_slot
				and distance > collapse_factor * spec.system_radius
			):
				collapse(slot)
		slot += 1
	Contract.invariant(
		_every_parent_is_live_and_expanded(),
		"every live body's parent must be live and expanded",
	)


func expand(slot: int) -> void:
	var spec := spec_of(slot)
	if not Contract.require(
		spec != null and not spec.is_pickup,
		"only a live body can expand",
	):
		return
	if is_expanded(slot):
		return
	for child_spec in generator.contents_of(spec):
		if consumed.has(child_spec.key()):
			continue
		var child := _spawn(child_spec, slot)
		_children[slot].append(child)
	_expanded[slot] = 1


func collapse(slot: int) -> void:
	if not Contract.require(
		spec_of(slot) != null,
		"only a live body can collapse",
	):
		return
	for child in _children[slot]:
		_free_subtree(child)
	_children[slot] = PackedInt32Array()
	_expanded[slot] = 0


func _free_subtree(slot: int) -> void:
	for child in _children[slot]:
		_free_subtree(child)
	_children[slot] = PackedInt32Array()
	var body := orbit_system.body_of(slot)
	orbit_system.remove(slot)
	body.queue_free()
	_specs[slot] = null
	_expanded[slot] = 0


func _spawn(spec: BodySpec, parent: int) -> int:
	var body: MassBody = body_scene.instantiate()
	body.radius = spec.radius
	body.mass = spec.mass
	var slot := orbit_system.add(body, spec, parent)
	while _specs.size() <= slot:
		_specs.append(null)
		_expanded.append(0)
		_children.append(PackedInt32Array())
	_specs[slot] = spec
	_expanded[slot] = 0
	_children[slot] = PackedInt32Array()
	bodies_root.add_child(body)
	body_spawned.emit(body, spec)
	return slot


func _every_parent_is_live_and_expanded() -> bool:
	for slot in _specs.size():
		if _specs[slot] == null or slot == root_slot:
			continue
		var parent := orbit_system.parent_of(slot)
		if spec_of(parent) == null or not is_expanded(parent):
			return false
	return true
