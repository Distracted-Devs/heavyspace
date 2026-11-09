extends Node3D

@export_group("Objects")
@export var planet: GravityBody
@export var pickup: PackedScene

@export var number_of_mass_pickups: int = 20
@export var spawn_radius_from_planet: float = 2500.0





func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"restart"):
		get_tree().reload_current_scene()


func _spawn_pickups() -> void:
	var spawn_centre: Vector3 = planet.global_position
	var per_spawn_angle: float = 360.0 / number_of_mass_pickups
	for pickup_index in range(0, number_of_mass_pickups):
		var spawn_angle := per_spawn_angle * pickup_index
		var spawn_location: Vector3 = spawn_radius_from_planet * Vector3(
			spawn_centre.x,
			sin(spawn_angle) + spawn_centre.y,
			cos(spawn_angle) + spawn_centre.z,
		)
		var new_pickup: Collectable = pickup.instantiate()

		add_child(new_pickup)
		new_pickup.global_position = spawn_location
		new_pickup.scale = Vector3(10.0, 10.0, 10.0)
