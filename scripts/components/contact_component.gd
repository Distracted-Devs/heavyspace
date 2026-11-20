class_name ContactComponent
extends Node

signal heavier_contact(other: Node3D, other_mass: float)
signal lighter_contact(other: Node3D, other_mass: float)

@export_group("Components")
@export var body: RigidBody3D
@export var mass_component: MassComponent


func _ready() -> void:
	body.contact_monitor = true
	body.max_contacts_reported = maxi(body.max_contacts_reported, 1)
	Contract.ensure(
		body.contact_monitor and body.max_contacts_reported >= 1,
		"body must report contacts",
	)
	body.body_entered.connect(_on_body_entered)


func _on_body_entered(other: Node) -> void:
	var other_mass := mass_of(other)
	if is_nan(other_mass):
		return
	if other_mass > mass_component.current_mass:
		heavier_contact.emit(other, other_mass)
	else:
		lighter_contact.emit(other, other_mass)


static func mass_of(other: Node) -> float:
	for child in other.get_children():
		var source := child as GravityComponent
		if source:
			return source.mass
	var rigid := other as RigidBody3D
	if rigid:
		return rigid.mass
	return NAN
