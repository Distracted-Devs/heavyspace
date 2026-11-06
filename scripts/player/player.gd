class_name Player
extends Node3D

@export_group("Movement")
@export var roll_impulse := 2.0
@export var pitch_impulse := 2.0
@export var yaw_impulse := 2.0
@export var thrust_force := 20.0
@export var rotation_correction_speed := 1.0
@export var rotation_correction_multiplier := 1.0
@export var rotation_correction_exponent := 0.01

@export_group("Orbit lock")

@export var min_lock_altitude := 10.0
@export var max_lock_altitude := 500.0
@export var orbit_speed_multiplier := 2.0
@export var orbit_boost_response := 3.0
@export var orbit_align_speed := 4.0

@export_group("Fuel")
@export var fuel_drain_rate := 20.0
@export var mass_to_fuel_ratio := .01

@export_group("Components")
@export var mass_component: MassComponent
@export var fuel_component: FuelComponent
@export var gravity_effect: GravityEffect
@export var ship: RigidBody3D

signal orbit_lock_changed(locked: bool)

## The orbit the ship is riding while locked (null when free-flying).
var _locked_orbit: Orbit
var _locked_source: Node3D
var _lock_time := 0.0
## Current orbit time scale: 1 when coasting, up to orbit_speed_multiplier.
var _orbit_time_scale := 1.0


func _ready() -> void:
	add_to_group("player")
	fuel_component.changed.connect(_on_fuel_changed)
	mass_component.add_mass(fuel_component.fuel * mass_to_fuel_ratio)


func _physics_process(delta: float) -> void:
	if _locked_orbit:
		# Locked: no steering, Space only speeds the ship along the orbit.
		_apply_orbit_boost(delta)
		_follow_locked_orbit(delta)
		return
	_apply_rotation_correction(delta)
	_apply_rotation(delta)
	_apply_thrust(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_orbit_lock") and not event.is_echo():
		if _locked_orbit:
			unlock_orbit()
		else:
			lock_orbit()



# --- Orbit lock ----------------------------------------------------------------


## I still dont understand all of this since it uses a formula was so weird but looks awesome

func get_orbit_source() -> Node3D:
	return gravity_effect.strongest_source(ship.global_position)


## The orbit the ship would follow if it stopped thrusting right now.
func get_current_orbit() -> Orbit:
	if _locked_orbit:
		return _locked_orbit
	var source := get_orbit_source()
	return gravity_effect.orbit_around(source)


## Ship velocity, including while riding a locked orbit (the ship is frozen then,
## so linear_velocity is zero).
func get_ship_velocity() -> Vector3:
	if _locked_orbit:
		return _locked_orbit.velocity_at(_lock_time) * _orbit_time_scale
	return ship.linear_velocity


## Velocity used to draw and predict the orbit (ignores the boost time scale).
func get_orbit_velocity() -> Vector3:
	if _locked_orbit:
		return _locked_orbit.velocity_at(_lock_time)
	return ship.linear_velocity


func can_lock_orbit() -> bool:
	var source := get_orbit_source()
	if source == null:
		return false
	var orbit := gravity_effect.orbit_around(source)
	var radius := GravityEffect.source_radius(source)
	return orbit.is_stable(radius + min_lock_altitude) \
			and orbit.apoapsis <= radius + max_lock_altitude


func is_orbit_locked() -> bool:
	return _locked_orbit != null


## Freezes the current orbit's shape and rides it on rails, so it never
## decays or drifts. Fails if the orbit isn't stable.
func lock_orbit() -> bool:
	if _locked_orbit or not can_lock_orbit():
		return false
	_locked_source = get_orbit_source()
	_locked_orbit = gravity_effect.orbit_around(_locked_source)
	_lock_time = 0.0
	_orbit_time_scale = 1.0
	gravity_effect.enabled = false

	# Taken out of the physics simulation
	ship.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	ship.freeze = true
	ship.linear_velocity = Vector3.ZERO
	ship.angular_velocity = Vector3.ZERO
	orbit_lock_changed.emit(true)
	return true


## Back to free flight
func unlock_orbit() -> void:
	if not _locked_orbit:
		return
	ship.freeze = false
	ship.linear_velocity = _locked_orbit.velocity_at(_lock_time)
	ship.angular_velocity = Vector3.ZERO
	_orbit_time_scale = 1.0
	_locked_orbit = null
	_locked_source = null
	gravity_effect.enabled = true
	orbit_lock_changed.emit(false)


func _follow_locked_orbit(delta: float) -> void:
	if not is_instance_valid(_locked_source):
		unlock_orbit()
		return
	# Boosting just plays the orbit forward faster: same ellipse, more speed.
	_lock_time += delta * _orbit_time_scale
	var rel_position := _locked_orbit.position_at(_lock_time)
	ship.global_position = _locked_source.global_position + rel_position
	_align_to_orbit(rel_position, _locked_orbit.velocity_at(_lock_time), delta)



## points away from the body it's orbiting.
func _align_to_orbit(rel_position: Vector3, velocity: Vector3, delta: float) -> void:
	var up := rel_position.normalized()
	var forward := velocity.normalized()
	if up.is_zero_approx() or forward.is_zero_approx() \
			or forward.cross(up).is_zero_approx():
		return
	var target := Basis.looking_at(forward, up).get_rotation_quaternion()
	var current := ship.global_basis.orthonormalized().get_rotation_quaternion()
	var weight := 1.0 - exp(-orbit_align_speed * delta)
	ship.global_basis = Basis(current.slerp(target, weight))


## Space while locked actys as a turbio
func _apply_orbit_boost(delta: float) -> void:

	var boosting := Input.is_physical_key_pressed(KEY_SPACE) and fuel_component.fuel > 0.0
	
	var target_scale := orbit_speed_multiplier if boosting else 1.0
	
	_orbit_time_scale = move_toward(
		_orbit_time_scale,
		target_scale,
		orbit_boost_response * maxf(orbit_speed_multiplier - 1.0, 1.0) * delta,
	)
	if boosting:
		##maybe this should consume a different type of fuel???
		fuel_component.add_fuel(-fuel_drain_rate * delta)



func _apply_rotation(delta: float) -> void:
	var roll := int(Input.is_physical_key_pressed(KEY_A)) - int(
		Input.is_physical_key_pressed(KEY_D)
	)
	var pitch := int(Input.is_physical_key_pressed(KEY_S)) - int(
		Input.is_physical_key_pressed(KEY_W)
	)
	var yaw := int(Input.is_physical_key_pressed(KEY_Q)) - int(Input.is_physical_key_pressed(KEY_E))

	var torque := ship.global_basis.z * roll * roll_impulse \
			+ ship.global_basis.x * pitch * pitch_impulse \
			+ ship.global_basis.y * yaw * yaw_impulse

	if torque != Vector3.ZERO:
		ship.apply_torque_impulse(torque * delta)


func _apply_thrust(delta: float) -> void:
	if Input.is_physical_key_pressed(KEY_SPACE) and fuel_component.fuel > 0.0:
		ship.apply_central_force(-ship.global_basis.z * thrust_force)
		fuel_component.add_fuel(-fuel_drain_rate * delta)


func _get_mass(node: Node) -> float:
	if node is RigidBody3D:
		return node.mass
	return node.get_meta("mass", 1.0)


func _on_fuel_changed(_new_fuel: float, delta_fuel: float) -> void:
	mass_component.add_mass(delta_fuel * mass_to_fuel_ratio)


func _apply_rotation_correction(_delta: float) -> void:
	var closest_gravity_body: GravityBody
	var closest_gravity_body_distance: float = INF
	for node in get_tree().get_nodes_in_group(&"gravity"):
		var gravity_body := node as GravityBody
		if not gravity_body:
			continue
		var gravity_body_distance: float = (
			gravity_body.global_position - ship.global_position
		).length()

		if gravity_body_distance < closest_gravity_body_distance:
			closest_gravity_body = gravity_body
			closest_gravity_body_distance = gravity_body_distance

	if not closest_gravity_body:
		return

	var closest_gravity_body_radius: float = closest_gravity_body.diameter / 2.0
	# Clamp: on contact the ship sinks slightly into the surface, and a negative
	# base raised to a fractional power is NaN, which corrupts the ship's physics.
	var altitude := maxf(closest_gravity_body_distance - closest_gravity_body_radius, 0.0)
	var rotation_correction_coefficient: float = rotation_correction_multiplier / (
		(altitude + 1.0) ** rotation_correction_exponent
	)
	var rotation_correction: float = rotation_correction_coefficient * rotation_correction_speed
	# print(closest_gravity_body_distance - closest_gravity_body_radius)

	# if too far away, exit
	if rotation_correction < 0.01:
		return

	var up: Vector3 = ship.global_position - closest_gravity_body.global_position

	if up.is_zero_approx():
		return
	up = up.normalized()

	# Tangent: velocity minus its radial part, falling back to the current nose.
	var nose: Vector3 = -ship.global_basis.z
	var forward = nose - up * nose.dot(up)
	if forward.is_zero_approx():
		# Nose points straight at / away from the body: use the ship's up instead.
		var ship_up: Vector3 = ship.global_basis.y
		forward = ship_up - up * ship_up.dot(up)
		if forward.is_zero_approx():
			return

	# -Z along the tangent, +Y away from the body.
	var target_basis := Basis.looking_at(forward, up)
	var current_basis: Basis = ship.global_basis.orthonormalized()

	# Rotation that takes current -> target.
	var error: Quaternion = target_basis.get_rotation_quaternion() \
			* current_basis.get_rotation_quaternion().inverse()
	if error.w < 0.0:
		error = -error # take the short way around
	var angle := error.get_angle()
	if angle < 0.0001:
		return # already aligned (get_axis() is NaN for an identity rotation)

	# Drive the body with angular velocity (safe with the physics engine).
	ship.angular_velocity += error.get_axis() * angle * rotation_correction
