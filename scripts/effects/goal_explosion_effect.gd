class_name GoalExplosionEffect
extends Node3D
## Big green "planet destroyed" burst spawned when a mission goal is completed.
## One-shot: restarts every particle child on ready, shakes the screen, and frees
## itself once the longest-lived particles are done.
##
## The whole effect scales uniformly with this node's scale (particles run in
## local space), so call fit_to_radius() to match the size of what exploded.

@export var shake_strength := 1.4
@export var shake_duration := 1.4
@export var shake_frequency := 14.0
@export var shake_rotation_deg := 4.0
## Shake fades out with camera distance (meters) so far-away goals rumble less.
## Multiplied by the effect's scale, so bigger explosions are felt from further away.
@export var shake_falloff_distance := 120.0
## Radius (meters) of the object this effect is authored for at scale 1.
## fit_to_radius() scales the effect by target_radius / reference_radius.
@export var reference_radius := 20.0
## Clamp for the size multiplier so tiny/huge goals stay sane.
@export var min_scale := 0.25
@export var max_scale := 50.0


## Scales the whole effect to fit an object of the given world-space radius.
func fit_to_radius(radius: float) -> void:
	if radius <= 0.0 or reference_radius <= 0.0:
		return
	scale = Vector3.ONE * clampf(radius / reference_radius, min_scale, max_scale)


func _ready() -> void:
	var longest := 0.0
	for child in get_children():
		if child is GPUParticles3D:
			# Local space so positions, velocities and sizes all follow our scale.
			child.local_coords = true
			child.restart()
			longest = maxf(longest, child.lifetime)
	# Deferred so the spawner has a chance to set global_position first.
	_shake.call_deferred()
	get_tree().create_timer(longest + 0.5).timeout.connect(queue_free)


func _shake() -> void:
	var size_factor := global_basis.get_scale().x
	ScreenShakeHandler.shake_at(
		global_position,
		shake_falloff_distance * size_factor,
		shake_strength,
		shake_duration,
		shake_frequency,
		shake_rotation_deg,
	)
