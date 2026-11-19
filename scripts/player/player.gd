class_name Player
extends RigidBody3D

@export_group("Components")
@export var flight_input: InputComponent
@export var thruster: ThrusterComponent
@export var rotator: RotationComponent
@export var mass_component: MassComponent
@export var gravity_receiver: GravityReceiverComponent
