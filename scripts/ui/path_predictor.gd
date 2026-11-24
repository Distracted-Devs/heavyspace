class_name PathPredictor
extends RefCounted

enum Forecast {
	NONE,
	IMPACT,
	ESCAPE,
	ORBIT,
}

const MIN_DISTANCE_SQUARED := 1.0

var step := 1.0 / 30.0:
	set(value):
		if not Contract.require(value > 0.0, "step must be positive"):
			return
		step = value
var duration := 120.0:
	set(value):
		if not Contract.require(value > 0.0, "duration must be positive"):
			return
		duration = value
var max_steps := 2400:
	set(value):
		if not Contract.require(value > 0, "max_steps must be positive"):
			return
		max_steps = value
var sample_every := 3:
	set(value):
		if not Contract.require(value >= 1, "sample_every must be at least 1"):
			return
		sample_every = value
var escape_factor := 1.5:
	set(value):
		if not Contract.require(
			value >= 1.0,
			"escape_factor must be at least 1",
		):
			return
		escape_factor = value

var max_sources := 0:
	set(value):
		var message := "max_sources must not be negative"
		if not Contract.require(value >= 0, message):
			return
		max_sources = value

var falloff_exponent := 2.0:
	set(value):
		var message := "falloff_exponent must be positive"
		if not Contract.require(value > 0.0, message):
			return
		falloff_exponent = value
var drift_enabled := false

var points := PackedVector3Array()
var forecast := Forecast.NONE


static func focus_index(
	position: Vector3,
	mass: float,
	positions: PackedVector3Array,
	masses: PackedFloat64Array,
	depths: PackedInt32Array,
) -> int:
	if not Contract.require(
		positions.size() == masses.size() and masses.size() == depths.size(),
		"positions, masses and depths must be the same length",
	):
		return -1
	var tier := -1
	for index in masses.size():
		if masses[index] > mass:
			tier = maxi(tier, depths[index])
	var best := -1
	var best_pull := -1.0
	for index in masses.size():
		if masses[index] <= mass or depths[index] != tier:
			continue
		var distance_squared := maxf(
			positions[index].distance_squared_to(position),
			MIN_DISTANCE_SQUARED,
		)
		var pull := masses[index] / distance_squared
		if pull > best_pull:
			best_pull = pull
			best = index
	return best


func step_count() -> int:
	return mini(int(duration / step), max_steps)


func predict(
	position: Vector3,
	velocity: Vector3,
	forward: Vector3,
	alignment: float,
	damping: float,
	gravity_constant: float,
	positions: PackedVector3Array,
	masses: PackedFloat64Array,
	radii: PackedFloat64Array,
	mass: float,
	focus: Vector3,
	drift := Vector3.ZERO,
) -> void:
	points.clear()
	points.append(position)
	forecast = Forecast.NONE
	if not Contract.require(
		positions.size() == masses.size() and masses.size() == radii.size(),
		"positions, masses and radii must be the same length",
	):
		return
	if not Contract.require(damping >= 0.0, "damping must not be negative"):
		return
	if not Contract.require(
		alignment >= 0.0 and alignment <= 1.0,
		"alignment must be within [0, 1]",
	):
		return
	if not Contract.require(
		not forward.is_zero_approx(),
		"forward must not be zero",
	):
		return
	var heavier := _strongest_heavier(position, mass, positions, masses)
	if heavier.is_empty():
		forecast = Forecast.ESCAPE
		return
	_simulate(
		position,
		velocity,
		forward.normalized(),
		alignment,
		damping,
		gravity_constant,
		heavier,
		positions,
		masses,
		radii,
		focus,
		drift if drift_enabled else Vector3.ZERO,
	)
	Contract.ensure(
		points.size() <= floori(float(max_steps) / sample_every) + 2,
		"the path must hold at most max_steps / sample_every + 2 points",
	)


func _strongest_heavier(
	position: Vector3,
	mass: float,
	positions: PackedVector3Array,
	masses: PackedFloat64Array,
) -> PackedInt32Array:
	var heavier := PackedInt32Array()
	var pulls := PackedFloat64Array()
	for index in masses.size():
		if masses[index] <= mass:
			continue
		var pull := masses[index] / maxf(
			positions[index].distance_squared_to(position),
			MIN_DISTANCE_SQUARED,
		)
		if max_sources > 0 and heavier.size() == max_sources:
			var weakest := _weakest(pulls)
			if pull <= pulls[weakest]:
				continue
			heavier[weakest] = index
			pulls[weakest] = pull
			continue
		heavier.append(index)
		pulls.append(pull)
	return heavier


static func _weakest(pulls: PackedFloat64Array) -> int:
	var weakest := 0
	for slot in range(1, pulls.size()):
		if pulls[slot] < pulls[weakest]:
			weakest = slot
	return weakest


func _simulate(
	position: Vector3,
	velocity: Vector3,
	forward: Vector3,
	alignment: float,
	damping: float,
	gravity_constant: float,
	heavier: PackedInt32Array,
	positions: PackedVector3Array,
	masses: PackedFloat64Array,
	radii: PackedFloat64Array,
	focus: Vector3,
	drift: Vector3,
) -> void:
	var start_distance := position.distance_to(focus)
	var swept := 0.0
	var previous := position - focus
	var own := velocity - drift
	var kept := maxf(0.0, 1.0 - damping * step)
	for index in step_count():
		if _inside_any(position, heavier, positions, radii):
			points.append(position)
			forecast = Forecast.IMPACT
			return
		var pull := GravityReceiverComponent.acceleration_at(
			position,
			heavier,
			positions,
			masses,
			radii,
			gravity_constant,
			falloff_exponent,
		) * step
		if drift_enabled:
			drift = (drift + pull) * kept
			own = _align(own * kept, forward, alignment)
		else:
			own = _align((own + pull) * kept, forward, alignment)
		var next := position + (own + drift) * step
		var hit := _first_hit(position, next, heavier, positions, radii)
		if hit >= 0.0:
			points.append(position.lerp(next, hit))
			forecast = Forecast.IMPACT
			return
		position = next
		var relative := position - focus
		swept += atan2(
			previous.cross(relative).length(),
			previous.dot(relative),
		)
		previous = relative
		if index % sample_every == 0:
			points.append(position)
		if swept >= TAU:
			points.append(position)
			forecast = Forecast.ORBIT
			return
	points.append(position)
	if position.distance_to(focus) > start_distance * escape_factor:
		forecast = Forecast.ESCAPE


static func _first_hit(
	from: Vector3,
	to: Vector3,
	heavier: PackedInt32Array,
	positions: PackedVector3Array,
	radii: PackedFloat64Array,
) -> float:
	var travel := to - from
	var length_squared := travel.length_squared()
	if length_squared == 0.0:
		return -1.0
	var first := INF
	for source in heavier:
		var along := clampf(
			(positions[source] - from).dot(travel) / length_squared,
			0.0,
			1.0,
		)
		var closest := from + travel * along
		if closest.distance_to(positions[source]) < radii[source]:
			first = minf(first, along)
	return first if first < INF else -1.0


static func _inside_any(
	position: Vector3,
	heavier: PackedInt32Array,
	positions: PackedVector3Array,
	radii: PackedFloat64Array,
) -> bool:
	for source in heavier:
		if position.distance_to(positions[source]) < radii[source]:
			return true
	return false


static func _align(
	velocity: Vector3,
	forward: Vector3,
	alignment: float,
) -> Vector3:
	var speed := velocity.length()
	if speed == 0.0:
		return velocity
	var turned := velocity.lerp(forward * speed, alignment)
	if turned.is_zero_approx():
		return forward * speed
	return turned.normalized() * speed
