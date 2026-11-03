class_name HeavierEffect
extends CollectableEffect

@export var amount := 1


func apply(collector: Node) -> void:
	var mass_component := collector.get_node_or_null("MassComponent") as MassComponent
	if mass_component:
		mass_component.change_mass(amount)
