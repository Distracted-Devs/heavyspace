extends Node

@export var G: float = 100.0
@export var softening: float = 1.0
@export var max_speed: float = 1500.0
@export var substeps: int = 4


func _physics_process(delta: float) -> void:
	var bodies := get_tree().get_nodes_in_group("bodies")
	var dt := delta / substeps
	for i in substeps:
		_step(bodies, dt)


func _step(bodies: Array, dt: float) -> void:
	var accels: Array[Vector3] = []
	accels.resize(bodies.size())
	accels.fill(Vector3.ZERO)
	var best_pull: Array[float] = []
	best_pull.resize(bodies.size())
	best_pull.fill(0.0)
	var best_parent: Array = []
	best_parent.resize(bodies.size())

	for i in bodies.size():
		for j in range(i + 1, bodies.size()):
			var a: Body3D = bodies[i]
			var b: Body3D = bodies[j]
			var d := b.global_position - a.global_position
			var dist_sq := d.length_squared() + softening * softening
			var dir := d / sqrt(dist_sq)

			var pull_on_a := G * b.mass / dist_sq
			var pull_on_b := G * a.mass / dist_sq

			if pull_on_a > best_pull[i]:
				best_pull[i] = pull_on_a
				best_parent[i] = b
			if pull_on_b > best_pull[j]:
				best_pull[j] = pull_on_b
				best_parent[j] = a

			accels[i] += dir * pull_on_a
			accels[j] -= dir * pull_on_b

			a.resolve_overlap(b)

	for i in bodies.size():
		var body: Body3D = bodies[i]
		body.gravity_acceleration = accels[i]
		if body.is_static:
			continue

		if body.is_orbit_locked:
			# Keep the parent chosen at lock time; only pick one if none is set
			if body.orbit_parent == null:
				body.orbit_parent = best_parent[i]
			if body.orbit_parent:
				_step_locked(body, dt)
				continue

		body.velocity += accels[i] * dt
		body.velocity = body.velocity.limit_length(max_speed)
		body.global_position += body.velocity * dt


func _step_locked(body: Body3D, dt: float) -> void:
	var parent := body.orbit_parent
	var offset := body.global_position - parent.global_position
	var r := offset.length()
	if r < 0.001:
		return
	var dir := offset / r

	# Rest length: the distance the spring wants to hold.
	if body.lock_rest_length < 0.0:
		body.lock_rest_length = r

	var rel_vel := body.velocity - parent.velocity
	var radial_speed := rel_vel.dot(dir) # + moving away, - moving closer
	var stretch := r - body.lock_rest_length

	# Spring + damper along the line to the parent (acceleration, so mass-independent).
	var accel := -(body.spring_stiffness * stretch + body.spring_damping * radial_speed) * dir

	# Semi-implicit Euler: update velocity first, then position with the new velocity.
	rel_vel += accel * dt
	body.velocity = parent.velocity + rel_vel
	body.global_position += body.velocity * dt
