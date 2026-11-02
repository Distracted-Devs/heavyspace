extends Node3D

@onready var player: PlayerShip = $PlayerShip
@onready var label: Label = $HUD/Label


func _process(_delta: float) -> void:
	label.text = "Velocity: %.2f\nMass: %.2f\n" % [
		player.ship.linear_velocity.length(),
		player.ship.mass,
	]
	if Input.is_physical_key_pressed(KEY_R):
		get_tree().reload_current_scene()
	pass
