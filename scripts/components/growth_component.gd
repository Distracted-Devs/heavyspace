class_name GrowthComponent
extends Node

@export_group("Components")
@export var mass_component: MassComponent
@export var mesh: Node3D
@export var collider: CollisionShape3D
@export var camera: CameraComponent
@export var pickup: PickupComponent

@export_group("Growth")
@export_range(0.01, 1.0, 0.0001, "or_greater") var size_exponent := 0.3333:
	set(value):
		if not Contract.require(value > 0.0, "size_exponent must be positive"):
			return
		size_exponent = value

var _base_scale := Vector3.ONE
var _base_radius := 0.0
var _base_distance := 0.0
var _sphere: SphereShape3D


func _ready() -> void:
	if not Contract.require(
		mass_component != null,
		"mass_component must be set",
	):
		return
	if mesh:
		_base_scale = mesh.scale
	if collider:
		_sphere = (collider.shape as SphereShape3D).duplicate()
		collider.shape = _sphere
		_base_radius = _sphere.radius
	if camera:
		_base_distance = camera.distance
	mass_component.mass_changed.connect(_on_mass_changed)
	_apply()


func size() -> float:
	var starting := mass_component.starting_mass
	if not Contract.require(starting > 0.0, "starting_mass must be positive"):
		return 1.0
	return pow(mass_component.current_mass / starting, size_exponent)


func _on_mass_changed(_mass: float) -> void:
	_apply()


func _apply() -> void:
	var grown := size()
	if mesh:
		mesh.scale = _base_scale * grown
	if _sphere:
		_sphere.radius = _base_radius * grown
	if camera:
		camera.distance = _base_distance * grown
	if pickup:
		pickup.size_scale = grown
