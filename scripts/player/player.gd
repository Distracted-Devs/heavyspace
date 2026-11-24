class_name Player
extends RigidBody3D

@export_group("Components")
@export var flight_input: InputComponent
@export var thruster: ThrusterComponent
@export var rotator: RotationComponent
@export var mass_component: MassComponent
@export var fuel_component: FuelComponent
@export var camera_component: CameraComponent
@export var contact_component: ContactComponent
@export var gravity_receiver: GravityReceiverComponent
@export var pickup_component: PickupComponent
@export var arcade_flight: ArcadeFlightComponent
@export var cargo: CargoComponent
@export var cargo_weight: CargoWeightComponent
@export var missing_fuel_boost: MissingFuelBoostComponent


func stop_flight() -> void:
	_apply_stop_flight.call_deferred()


func _apply_stop_flight() -> void:
	freeze = true
	var components := _flight_components()
	for component in components:
		component.process_mode = Node.PROCESS_MODE_DISABLED
	Contract.ensure(
		(
			freeze
			and components.all(
				func(component: Node) -> bool:
					return (
						component.process_mode == Node.PROCESS_MODE_DISABLED
					),
			)
		),
		"stopped flight must freeze the body and disable its components",
	)


func _flight_components() -> Array[Node]:
	var components: Array[Node] = [
		flight_input,
		thruster,
		rotator,
		fuel_component,
		gravity_receiver,
		camera_component,
	]
	if pickup_component != null:
		components.append(pickup_component)
	if arcade_flight != null:
		components.append(arcade_flight)
	return components
