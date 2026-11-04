class_name FuelEffect
extends CollectableEffect

@export var amount := 10


func apply(collector: Node) -> void:
	var fuel_component := collector.get_node_or_null("FuelComponent") as FuelComponent
	if fuel_component:
		fuel_component.add_fuel(amount)
