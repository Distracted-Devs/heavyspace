class_name MassCollectable
extends Node3D

@export_group("Components")
@export var player: Player
@export var gravity_component: GravityComponent

@export_group("Magic Numbers")
@export var blow_up_speed = 0.9
@export var shrink_speed = 0.5
@export var move_to_player_speed = 0.5
@export var distance_to_player_for_pickup = 10.0

@export_group("Spawn Settings")
@export var start_scale = Vector3.ZERO
@export var end_scale = Vector3.ZERO

var startup_scale_t = 0.0
var move_to_player_t = 0.0
var pickup_scale_t = 0.0

var previous_player_position := Vector3.ZERO
var current_player_position := Vector3.ZERO


func _process(delta: float) -> void:
	current_player_position = player.body.global_position

	if startup_scale_t < 1.0:
		startup_scale_t += delta * blow_up_speed
		self.scale = start_scale.lerp(end_scale, startup_scale_t)

	if gravity_component.mass < player.current_mass:
		var distance_to_player := (self.global_position - current_player_position).length()
		if distance_to_player < distance_to_player_for_pickup:
			var player_position_diff = current_player_position - previous_player_position
			self.global_position += player_position_diff
			move_to_player_t += delta * move_to_player_speed
			pickup_scale_t += delta * shrink_speed

			self.global_position = self.global_position.lerp(
				player.body.global_position,
				move_to_player_t,
			)
			self.scale = self.scale.lerp(Vector3.ZERO, pickup_scale_t)

		if distance_to_player < 1.0:
			queue_free()

	previous_player_position = current_player_position
