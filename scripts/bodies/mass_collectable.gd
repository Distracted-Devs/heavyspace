class_name MassCollectable
extends Node3D

@export var player: Player
@export var blow_up_speed = 0.9
@export var mass = 0.1

@export var start_scale = Vector3.ZERO
@export var end_scale = Vector3.ZERO

var startup_scale_t = 0.0
var move_to_player_t = 0.0
@onready var start_position = self.global_position


func _process(delta: float) -> void:
	if startup_scale_t < 1.0:
		startup_scale_t += delta * blow_up_speed
		self.scale = start_scale.lerp(end_scale, startup_scale_t)

	if mass < player.current_mass:
		var distance_to_player := (self.global_position - player.body.global_position).length()
		if distance_to_player < 50.0:
			move_to_player_t += delta * 10.0
			print(move_to_player_t)
			self.global_position = start_position.lerp(
				player.body.global_position,
				move_to_player_t,
			)

		if distance_to_player < 1.0:
			queue_free()
