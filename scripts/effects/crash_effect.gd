class_name CrashEffect
extends Node3D

@export_group("Components")
@export var lose_controller: LoseController
@export var ship: Node3D

@export_group("Crash")
@export var explosion: PackedScene = preload(
	"res://scenes/effects/ship_explosion.tscn"
)
@export_range(0.1, 30.0, 0.1, "or_greater") var lifetime := 5.0:
	set(value):
		if not Contract.require(value > 0.0, "lifetime must be positive"):
			return
		lifetime = value
@export var prewarm := true
@export var follow_ship := true

var _explosions: Array[Node3D] = []
var _ages := PackedFloat64Array()


func _ready() -> void:
	if lose_controller:
		lose_controller.lost_game.connect(_on_lost_game)
	if prewarm and explosion:
		_prewarm()


func _process(delta: float) -> void:
	advance(delta)


func play() -> void:
	if not Contract.require(
		ship != null and explosion != null,
		"ship and explosion must be set",
	):
		return
	var blast := explosion.instantiate() as Node3D
	add_child(blast)
	blast.global_position = ship.global_position
	blast.scale = ship.global_basis.get_scale()
	if follow_ship:
		for particles in blast.find_children("*", "GPUParticles3D"):
			(particles as GPUParticles3D).local_coords = true
	_explosions.append(blast)
	_ages.append(0.0)


func advance(delta: float) -> void:
	for slot in range(_explosions.size() - 1, -1, -1):
		_ages[slot] += delta
		if follow_ship and ship != null:
			_explosions[slot].global_position = ship.global_position
		if _ages[slot] >= lifetime:
			_explosions[slot].queue_free()
			_forget(slot)


func active_count() -> int:
	return _explosions.size()


func _forget(slot: int) -> void:
	var last := _explosions.size() - 1
	_explosions[slot] = _explosions[last]
	_ages[slot] = _ages[last]
	_explosions.resize(last)
	_ages.resize(last)


func _prewarm() -> void:
	var warm := explosion.instantiate() as Node3D
	warm.visible = false
	add_child(warm)
	warm.queue_free()


func _on_lost_game(_other: Node3D) -> void:
	play()
