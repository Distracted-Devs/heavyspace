class_name PickupComponent
extends Node

@export_group("Components")
@export var body: RigidBody3D
@export var mass_component: MassComponent
@export var collider: CollisionShape3D
@export var pool: LiveBodyPool
@export var absorb: AbsorbEffect
@export var cargo: CargoComponent

@export_group("Pickup")
@export_range(0.0, 100.0, 0.1, "or_greater") var pickup_radius := 8.0:
	set(value):
		if not Contract.require(
			value >= 0.0,
			"pickup_radius must not be negative",
		):
			return
		pickup_radius = value
@export_range(0.01, 10.0, 0.01, "or_greater") var mass_conversion := 1.0:
	set(value):
		var message := "mass_conversion must be positive"
		if not Contract.require(value > 0.0, message):
			return
		mass_conversion = value
@export_range(0.01, 100.0, 0.01, "or_greater") var size_scale := 1.0:
	set(value):
		if not Contract.require(value > 0.0, "size_scale must be positive"):
			return
		size_scale = value


func _ready() -> void:
	if absorb != null:
		absorb.absorbed.connect(_on_absorbed)


func _physics_process(_delta: float) -> void:
	collect()


func reach() -> float:
	var sphere := collider.shape as SphereShape3D if collider else null
	var ship_radius := sphere.radius if sphere else 0.0
	return pickup_radius * size_scale + ship_radius


func collect() -> void:
	if pool == null or absorb == null:
		return
	if cargo != null and cargo.is_full():
		return
	var caught := pool.bodies_within(
		body.global_position,
		reach(),
		mass_component.current_mass,
	)
	caught.sort_custom(_heavier_first)
	for candidate in caught:
		if not pool.is_live(candidate):
			continue
		var taken := pool.take(candidate)
		for index in taken.bodies.size():
			var extra := taken.drawn_mass if index == 0 else 0.0
			absorb.absorb(taken.bodies[index], extra)
	Contract.ensure(
		_all_held(caught),
		"every caught body must be held by the absorb effect",
	)


func _all_held(caught: Array[MassBody]) -> bool:
	for candidate in caught:
		if not absorb.is_absorbing(candidate):
			return false
	return true


func _heavier_first(a: MassBody, b: MassBody) -> bool:
	return a.mass > b.mass


func _on_absorbed(mass: float) -> void:
	if cargo != null:
		cargo.add(mass * mass_conversion)
		return
	mass_component.current_mass += mass * mass_conversion
