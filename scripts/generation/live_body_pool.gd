class_name LiveBodyPool
extends Node

const BODY_SCENE := preload("res://scenes/bodies/mass_body.tscn")

@export_group("Components")
@export var streamer: HierarchyStreamer

var root_body: MassBody

var _drawn: Array[OrbitRenderer] = []
var _drawn_tiers: Array[Tier] = []
var _drawn_paths: Array[PackedInt32Array] = []
var _bodies: Array[MassBody] = []
var _body_renderers: Array[OrbitRenderer] = []
var _body_indices := PackedInt32Array()
var _slot_of: Dictionary[String, int] = { }


func _init() -> void:
	process_physics_priority = -3


func _ready() -> void:
	if not Contract.require(streamer != null, "streamer must be set"):
		return
	streamer.expanded.connect(_on_expanded)
	streamer.collapsing.connect(_on_collapsing)
	for path in streamer.expanded_paths():
		_on_expanded(path, streamer.renderer_for(path))
	root_body = _make_body(
		"Root",
		streamer.root_radius,
		streamer.root_mass,
		streamer.global_position,
	)


func _physics_process(_delta: float) -> void:
	if streamer == null or streamer.focus == null or streamer.clock == null:
		return
	update(streamer.focus.global_position, streamer.clock.time)


func update(focus_position: Vector3, time: float) -> void:
	if streamer == null:
		return
	root_body.global_position = streamer.global_position
	_move_or_release(focus_position, time)
	_promote_near(focus_position, time)
	if Contract.enabled:
		Contract.invariant(
			_live_bodies_match_hidden_copies(),
			"every live body must match one hidden drawn copy",
		)


func live_count() -> int:
	return _bodies.size()


func body_for(renderer: OrbitRenderer, index: int) -> MassBody:
	var slot: int = _slot_of.get(_key(renderer, index), -1)
	return null if slot < 0 else _bodies[slot]


func is_live(body: MassBody) -> bool:
	return _bodies.has(body)


func bodies_within(
	centre: Vector3,
	reach: float,
	max_mass: float,
) -> Array[MassBody]:
	var found: Array[MassBody] = []
	if not Contract.require(reach >= 0.0, "reach must not be negative"):
		return found
	for body in _bodies:
		if body.mass > max_mass:
			continue
		if centre.distance_to(body.global_position) - body.radius <= reach:
			found.append(body)
	return found


func take(body: MassBody) -> TakenBodies:
	var taken := TakenBodies.new()
	var slot := _bodies.find(body)
	if not Contract.require(
		slot >= 0 and body != root_body,
		"body must be a live body",
	):
		return taken
	var path := _path_of(slot)
	taken.bodies.append(body)
	_forget(slot)
	for other in range(_bodies.size() - 1, -1, -1):
		if _is_below(_path_of(other), path):
			taken.bodies.append(_bodies[other])
			_forget(other)
	for drawn_slot in _drawn.size():
		if not _is_below(_drawn_paths[drawn_slot], path, true):
			continue
		var renderer := _drawn[drawn_slot]
		var masses := renderer.layout.mass
		for index in renderer.count():
			if not renderer.is_hidden(index):
				taken.drawn_mass += masses[index]
	var count := _bodies.size()
	streamer.remove(path)
	Contract.ensure(
		_bodies.size() == count and _owns_none(taken.bodies),
		"taken bodies must have left the pool",
	)
	return taken


func _owns_none(bodies: Array[MassBody]) -> bool:
	for body in bodies:
		if _bodies.has(body):
			return false
	return true


func _path_of(slot: int) -> PackedInt32Array:
	var drawn_slot := _drawn.find(_body_renderers[slot])
	var path := _drawn_paths[drawn_slot].duplicate()
	path.append(_body_indices[slot])
	return path


func _is_below(
	path: PackedInt32Array,
	ancestor: PackedInt32Array,
	or_equal := false,
) -> bool:
	if path.size() < ancestor.size():
		return false
	if path.size() == ancestor.size() and not or_equal:
		return false
	return path.slice(0, ancestor.size()) == ancestor


func _move_or_release(focus_position: Vector3, time: float) -> void:
	for slot in range(_bodies.size() - 1, -1, -1):
		var renderer := _body_renderers[slot]
		var index := _body_indices[slot]
		var centre := renderer.child_positions(time)[index]
		var tier := _drawn_tiers[_drawn.find(renderer)]
		if focus_position.distance_to(centre) > tier.release_distance:
			renderer.set_hidden(index, false)
			_release(slot)
		else:
			_bodies[slot].global_position = centre


func _promote_near(focus_position: Vector3, time: float) -> void:
	for drawn_slot in _drawn.size():
		var renderer := _drawn[drawn_slot]
		var live_distance := _drawn_tiers[drawn_slot].live_distance
		var to_centre := focus_position.distance_to(renderer.global_position)
		if to_centre - renderer.reach() >= live_distance:
			continue
		var positions := renderer.child_positions(time)
		var live_squared := live_distance * live_distance
		for index in positions.size():
			var centre := positions[index]
			if focus_position.distance_squared_to(centre) >= live_squared:
				continue
			if not renderer.is_hidden(index):
				_promote(renderer, index, centre)


func _promote(renderer: OrbitRenderer, index: int, centre: Vector3) -> void:
	var layout := renderer.layout
	var body := _make_body(
		"%s_%d" % [renderer.name, index],
		layout.radius[index],
		layout.mass[index],
		centre,
	)
	renderer.set_hidden(index, true)
	_slot_of[_key(renderer, index)] = _bodies.size()
	_bodies.append(body)
	_body_renderers.append(renderer)
	_body_indices.append(index)


func _release(slot: int) -> void:
	_bodies[slot].queue_free()
	_forget(slot)


func _forget(slot: int) -> void:
	var last := _bodies.size() - 1
	_slot_of.erase(_key(_body_renderers[slot], _body_indices[slot]))
	if slot != last:
		_bodies[slot] = _bodies[last]
		_body_renderers[slot] = _body_renderers[last]
		_body_indices[slot] = _body_indices[last]
		_slot_of[_key(_body_renderers[slot], _body_indices[slot])] = slot
	_bodies.resize(last)
	_body_renderers.resize(last)
	_body_indices.resize(last)


func _on_expanded(path: PackedInt32Array, renderer: OrbitRenderer) -> void:
	_drawn.append(renderer)
	_drawn_tiers.append(streamer.tier_of(path))
	_drawn_paths.append(path.duplicate())
	for index in streamer.removed_indices(path):
		renderer.set_hidden(index, true)


func _on_collapsing(_path: PackedInt32Array, renderer: OrbitRenderer) -> void:
	for slot in range(_bodies.size() - 1, -1, -1):
		if _body_renderers[slot] == renderer:
			_release(slot)
	var drawn_slot := _drawn.find(renderer)
	_drawn.remove_at(drawn_slot)
	_drawn_tiers.remove_at(drawn_slot)
	_drawn_paths.remove_at(drawn_slot)


func _make_body(
	body_name: String,
	radius: float,
	mass: float,
	centre: Vector3,
) -> MassBody:
	var body := BODY_SCENE.instantiate() as MassBody
	body.name = body_name
	body.radius = radius
	body.mass = mass
	# Placed before it enters the tree, so its first physics step doesn't
	# sweep it from the origin.
	body.position = centre
	add_child(body)
	return body


func _live_bodies_match_hidden_copies() -> bool:
	if _slot_of.size() != _bodies.size():
		return false
	for slot in _bodies.size():
		if not _body_renderers[slot].is_hidden(_body_indices[slot]):
			return false
	return true


func _key(renderer: OrbitRenderer, index: int) -> String:
	return "%d:%d" % [renderer.get_instance_id(), index]
