class_name GrowInEffect
extends Node

@export_group("Components")
@export var streamer: HierarchyStreamer

@export_group("Grow")
@export_range(0.0, 5.0, 0.01, "or_greater") var grow_time := 0.6:
	set(value):
		if not Contract.require(value >= 0.0, "grow_time must not be negative"):
			return
		grow_time = value
@export_range(0.05, 5.0, 0.01, "or_greater") var ease_curve := 2.0:
	set(value):
		if not Contract.require(value > 0.0, "ease_curve must be positive"):
			return
		ease_curve = value

var _renderers: Array[OrbitRenderer] = []
var _elapsed := PackedFloat32Array()


func _ready() -> void:
	if not Contract.require(streamer != null, "streamer must be set"):
		return
	streamer.expanded.connect(_on_expanded)
	streamer.collapsing.connect(_on_collapsing)


func _process(delta: float) -> void:
	advance(delta)


func growing_count() -> int:
	return _renderers.size()


func advance(delta: float) -> void:
	if not Contract.require(delta >= 0.0, "delta must not be negative"):
		return
	for slot in range(_renderers.size() - 1, -1, -1):
		_elapsed[slot] += delta
		var done := (
			1.0 if grow_time <= 0.0 else minf(_elapsed[slot] / grow_time, 1.0)
		)
		_renderers[slot].display_scale = ease(done, ease_curve)
		if done >= 1.0:
			_renderers[slot].display_scale = 1.0
			_forget(slot)
	Contract.invariant(
		_elapsed.size() == _renderers.size(),
		"there must be one elapsed time per growing renderer",
	)


func _on_expanded(_path: PackedInt32Array, renderer: OrbitRenderer) -> void:
	if grow_time <= 0.0:
		return
	renderer.display_scale = 0.0
	_renderers.append(renderer)
	_elapsed.append(0.0)


func _on_collapsing(_path: PackedInt32Array, renderer: OrbitRenderer) -> void:
	var slot := _renderers.find(renderer)
	if slot >= 0:
		_forget(slot)


func _forget(slot: int) -> void:
	var last := _renderers.size() - 1
	_renderers[slot] = _renderers[last]
	_elapsed[slot] = _elapsed[last]
	_renderers.resize(last)
	_elapsed.resize(last)
