class_name Orbit
extends RefCounted

var mu: float

var semi_major_axis: float
var eccentricity: float
## Specific orbital energy. < 0 = bound to the body.
var energy: float
var periapsis: float
var apoapsis: float
## Seconds for one full loop. INF when not bound.
var period: float

# Orbit plane basis: _p points at periapsis, _q is 90 degrees ahead of it.
var _p: Vector3
var _q: Vector3
var _mean_motion: float
var _mean_anomaly_at_epoch: float


static func from_state(rel_position: Vector3, velocity: Vector3, mu_value: float) -> Orbit:
	var orbit := Orbit.new()
	orbit.mu = mu_value
	var r := maxf(rel_position.length(), 0.0001)
	var h := rel_position.cross(velocity)
	orbit.energy = velocity.length_squared() * 0.5 - mu_value / r

	var e_vec := velocity.cross(h) / mu_value - rel_position / r
	orbit.eccentricity = e_vec.length()

	if orbit.energy >= 0.0 or h.length_squared() < 0.000001:
		# Escape path or straight up/down: not an orbit.
		orbit.semi_major_axis = -mu_value / (2.0 * orbit.energy) if orbit.energy != 0.0 else INF
		orbit.periapsis = 0.0 if h.length_squared() < 0.000001 \
				else h.length_squared() / (mu_value * (1.0 + orbit.eccentricity))
		orbit.apoapsis = INF
		orbit.period = INF
		return orbit

	var a := -mu_value / (2.0 * orbit.energy)
	var e := orbit.eccentricity
	orbit.semi_major_axis = a
	orbit.periapsis = a * (1.0 - e)
	orbit.apoapsis = a * (1.0 + e)
	orbit._mean_motion = sqrt(mu_value / (a * a * a))
	orbit.period = TAU / orbit._mean_motion

	var n := h.normalized()

	orbit._p = e_vec / e if e > 0.00001 else rel_position / r
	orbit._q = n.cross(orbit._p).normalized()

	# Where the ship is right now along the ellipse (true -> eccentric -> mean anomaly).
	var nu := atan2(rel_position.dot(orbit._q), rel_position.dot(orbit._p))
	var ecc_anomaly := 2.0 * atan2(sqrt(1.0 - e) * sin(nu * 0.5), sqrt(1.0 + e) * cos(nu * 0.5))
	orbit._mean_anomaly_at_epoch = ecc_anomaly - e * sin(ecc_anomaly)
	return orbit


func is_bound() -> bool:
	return energy < 0.0 and period < INF


## Bound and never dips below min_radius (the planet surface plus a margin).
func is_stable(min_radius: float) -> bool:
	return is_bound() and periapsis > min_radius


## Position relative to the body, t seconds after the orbit was measured.
func position_at(t: float) -> Vector3:
	var ecc_anomaly := _eccentric_anomaly(t)
	var a := semi_major_axis
	var e := eccentricity
	return _p * (a * (cos(ecc_anomaly) - e)) + _q * (a * sqrt(1.0 - e * e) * sin(ecc_anomaly))


## Velocity t seconds after the orbit was measured.
func velocity_at(t: float) -> Vector3:
	var ecc_anomaly := _eccentric_anomaly(t)
	var a := semi_major_axis
	var e := eccentricity
	var r := a * (1.0 - e * cos(ecc_anomaly))
	var k := sqrt(mu * a) / r
	return _p * (-k * sin(ecc_anomaly)) + _q * (k * sqrt(1.0 - e * e) * cos(ecc_anomaly))


## Solves Kepler's equation M = E - e sin E with Newton's method.
func _eccentric_anomaly(t: float) -> float:
	var mean_anomaly := fposmod(_mean_anomaly_at_epoch + _mean_motion * t, TAU)
	var e := eccentricity
	var ecc_anomaly := mean_anomaly if e < 0.8 else PI
	for i in 12:
		var f := ecc_anomaly - e * sin(ecc_anomaly) - mean_anomaly
		var step := f / (1.0 - e * cos(ecc_anomaly))
		ecc_anomaly -= step
		if absf(step) < 1e-9:
			break
	return ecc_anomaly
