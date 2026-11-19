class_name Player
extends RigidBody3D

@export_group("Components")
@export var flight_input: InputComponent
@export var thruster: ThrusterComponent
@export var rotator: RotationComponent
@export var mass_component: MassComponent

@export_group("Gravity")
@export var gravity_constant := 0.001

var gravity_sources: Array[GravityComponent] = []


func _ready() -> void:
	add_to_group("gravity_affected")


func _physics_process(delta: float) -> void:
	apply_gravity(delta)


func apply_gravity(_delta: float):
	var current_mass := mass_component.current_mass
	for gravity_source in gravity_sources:
		if gravity_source:
			if not is_instance_valid(gravity_source):
				remove_gravity_source(gravity_source)
				continue
			if current_mass > gravity_source.mass:
				continue

			var source_dir: Vector3 = (
				gravity_source.source_position - global_position
			)
			var distance_to_source := source_dir.length()
			source_dir = source_dir.normalized()
			var gravity_force: Vector3 = (
				source_dir * current_mass
				* gravity_source.mass * gravity_constant
				/ (distance_to_source * distance_to_source)
			)
			apply_force(gravity_force)


func add_gravity_source(source: GravityComponent):
	gravity_sources.append(source)


func remove_gravity_source(source: GravityComponent):
	gravity_sources.append(source)
