extends "res://scripts/levels/player_spawn.gd"

## Prototype spawn: the same as production, then the ship turns to face the
## nearest planet (the nearest body of the systems tier).

var face_nearest_planet := true


func spawn() -> void:
	super.spawn()
	if face_nearest_planet:
		_face_nearest_planet()


func _face_nearest_planet() -> void:
	var systems := streamer.renderer_for(PackedInt32Array())
	if systems == null or systems.count() == 0:
		return
	var time := streamer.clock.time if streamer.clock != null else 0.0
	var from := player.global_position
	var nearest := Vector3.ZERO
	var best := INF
	for index in systems.count():
		var centre := systems.child_position(index, time)
		var distance := from.distance_squared_to(centre)
		if distance < best:
			best = distance
			nearest = centre
	var forward := (nearest - from).normalized()
	# Keep the ship's roll: its up stays in the home ring's plane normal.
	var up := player.global_basis.y
	if absf(forward.dot(up)) > 0.999:
		up = player.global_basis.z
	player.global_basis = Basis.looking_at(forward, up)
