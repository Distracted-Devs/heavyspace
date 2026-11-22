class_name LiveBodyPool
extends Node

const BODY_SCENE := preload("res://scenes/bodies/mass_body.tscn")

@export_group("Components")
@export var streamer: HierarchyStreamer

var root_body: MassBody

var _drawn: Array[OrbitRenderer] = []
var _drawn_tiers: Array[Tier] = []
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
	Contract.invariant(
		_live_bodies_match_hidden_copies(),
		"every live body must match one hidden drawn copy",
	)


func live_count() -> int:
	return _bodies.size()


func body_for(renderer: OrbitRenderer, index: int) -> MassBody:
	var slot: int = _slot_of.get(_key(renderer, index), -1)
	return null if slot < 0 else _bodies[slot]


func _move_or_release(focus_position: Vector3, time: float) -> void:
	for slot in range(_bodies.size() - 1, -1, -1):
		var renderer := _body_renderers[slot]
		var index := _body_indices[slot]
		var centre := renderer.child_position(index, time)
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
		for index in renderer.count():
			if renderer.is_hidden(index):
				continue
			var centre := renderer.child_position(index, time)
			if focus_position.distance_to(centre) < live_distance:
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
	var last := _bodies.size() - 1
	_slot_of.erase(_key(_body_renderers[slot], _body_indices[slot]))
	_bodies[slot].queue_free()
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


func _on_collapsing(_path: PackedInt32Array, renderer: OrbitRenderer) -> void:
	for slot in range(_bodies.size() - 1, -1, -1):
		if _body_renderers[slot] == renderer:
			_release(slot)
	var drawn_slot := _drawn.find(renderer)
	_drawn.remove_at(drawn_slot)
	_drawn_tiers.remove_at(drawn_slot)


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
