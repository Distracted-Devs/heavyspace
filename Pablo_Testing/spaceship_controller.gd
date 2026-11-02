class_name OrbitShip
extends Node3D
## Proof-of-concept orbit spaceship.
##
## - Gravity from every OrbitPlanet (group "gravity_sources") pulls on the ship.
## - The ship always points where it is moving, so as gravity bends its path
##   the nose turns toward the planet.
## - W / S / A / D only gently nudge the nose. They are too weak to beat
##   gravity on their own: you have to use your mass to control speed.
## - Left click = lighter, right click = heavier. Momentum is conserved
##   (like Body3D.conserve_momentum), so lighter = faster, heavier = slower.
## - Touching the planet, or staying past max_altitude too long, restarts.
##
## Hints, the orbit trail and the predicted path are shown by the minimap
## (orbit_minimap.gd), which reads the public state of this node.

@export_group("Flight")
## Initial speed along the nose. Below orbit speed, so you start falling.
@export var start_speed: float = 45.0
## Max nose up / down rate (W / S), in radians per second. Kept low on purpose.
@export var pitch_speed: float = 0.08
## Max turn rate (A / D), in radians per second.
@export var turn_speed: float = 0.1
## How quickly steering ramps up / down when keys are pressed / released.
@export var steering_response: float = 2.5

@export_group("Mass")
@export var start_mass: float = 1.0
@export var min_mass: float = 0.2
@export var max_mass: float = 4.0
## How quickly mass changes while a mouse button is held (fraction per second).
@export var mass_change_rate: float = 0.6
## Grow / shrink the pyramid with mass so the change is visible.
@export var scale_with_mass: bool = true

@export_group("Bounds")
## Highest altitude above the planet surface before you count as out of bounds.
@export var max_altitude: float = 300.0
## Seconds you can stay out of bounds before the scene restarts.
@export var out_of_bounds_time: float = 2.0
## The red boundary shell in the world fades in this close to the limit.
@export var boundary_fade_distance: float = 120.0

@export_group("Prediction")
## How far ahead the predicted path is simulated, in seconds.
@export var path_seconds: float = 60.0
@export var path_step: float = 1.0 / 30.0
## How much of the flown path is kept as a trail, in seconds.
@export var trail_seconds: float = 60.0
@export var trail_interval: float = 0.1

const BOUNDARY_COLOUR := Color(1.0, 0.3, 0.2)

# Public state, read by the minimap.
var velocity: Vector3 = Vector3.ZERO
var mass: float = 1.0
var sources: Array[Node] = []
var predicted_path: PackedVector3Array = []
var trail: PackedVector3Array = []
var will_crash := false
var will_leave_bounds := false
var out_of_bounds_timer := 0.0

var _restarting := false
var _steer := Vector2.ZERO # x = turn, y = pitch, smoothed
var _trail_timer := 0.0
var _boundary: MeshInstance3D
var _boundary_material: StandardMaterial3D

@onready var _pyramid: Node3D = $Pyramid
@onready var _hitbox: Area3D = $Pyramid/Hitbox
@onready var _base_pyramid_scale: Vector3 = _pyramid.scale


func _ready() -> void:
	mass = start_mass
	velocity = -global_basis.z * start_speed
	_hitbox.area_entered.connect(_on_hit)
	_hitbox.body_entered.connect(_on_hit)
	_apply_mass_scale()


func _physics_process(delta: float) -> void:
	sources = get_tree().get_nodes_in_group("gravity_sources")
	_handle_mass(delta)
	_handle_steering(delta)

	var old_forward := velocity.normalized()
	velocity += gravity_at(global_position) * delta
	global_position += velocity * delta
	_turn_nose(old_forward, velocity.normalized())

	_update_trail(delta)
	_update_bounds(delta)
	_update_prediction()


func gravity_at(point: Vector3) -> Vector3:
	var accel := Vector3.ZERO
	for source: OrbitPlanet in sources:
		accel += source.acceleration_at(point)
	return accel


func strongest_source_at(point: Vector3) -> OrbitPlanet:
	var best: OrbitPlanet = null
	var best_pull := 0.0
	for source: OrbitPlanet in sources:
		var pull := source.acceleration_at(point).length()
		if pull > best_pull:
			best_pull = pull
			best = source
	return best


func altitude_above(planet: OrbitPlanet, point: Vector3) -> float:
	return point.distance_to(planet.global_position) - planet.radius


# --- Controls ----------------------------------------------------------------

func _handle_mass(delta: float) -> void:
	var direction := 0.0
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		direction -= 1.0
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		direction += 1.0
	if direction == 0.0:
		return

	var old_mass := mass
	mass = clampf(mass * exp(direction * mass_change_rate * delta), min_mass, max_mass)
	# Conservation of momentum: m1 * v1 = m2 * v2
	velocity *= old_mass / mass
	_apply_mass_scale()


func _handle_steering(delta: float) -> void:
	var target := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A):
		target.x += 1.0
	if Input.is_physical_key_pressed(KEY_D):
		target.x -= 1.0
	if Input.is_physical_key_pressed(KEY_W):
		target.y += 1.0
	if Input.is_physical_key_pressed(KEY_S):
		target.y -= 1.0
	_steer = _steer.move_toward(target, steering_response * delta)

	# Rotate both the ship and its velocity, so it keeps flying where it points.
	if _steer.y != 0.0:
		_rotate_ship(global_basis.x, _steer.y * pitch_speed * delta)
	if _steer.x != 0.0:
		_rotate_ship(global_basis.y, _steer.x * turn_speed * delta)


func _rotate_ship(axis: Vector3, angle: float) -> void:
	axis = axis.normalized()
	velocity = velocity.rotated(axis, angle)
	global_basis = global_basis.rotated(axis, angle).orthonormalized()


## Smallest rotation that takes the nose from the old travel direction to the
## new one. The camera is a child, so it keeps the same view behind the ship.
func _turn_nose(from: Vector3, to: Vector3) -> void:
	if from.is_zero_approx() or to.is_zero_approx() or from.is_equal_approx(to):
		return
	if from.dot(to) < -0.999:
		return
	var arc := Quaternion(from, to)
	global_basis = (Basis(arc) * global_basis).orthonormalized()


func _apply_mass_scale() -> void:
	if scale_with_mass:
		_pyramid.scale = _base_pyramid_scale * pow(mass / start_mass, 1.0 / 3.0)


# --- Death -------------------------------------------------------------------

func _on_hit(_other: Node) -> void:
	_restart()


func _restart() -> void:
	if _restarting:
		return
	_restarting = true
	get_tree().reload_current_scene.call_deferred()


# --- Bounds ------------------------------------------------------------------

func is_out_of_bounds(point: Vector3) -> bool:
	var planet := strongest_source_at(point)
	return planet != null and altitude_above(planet, point) > max_altitude


func _update_bounds(delta: float) -> void:
	if is_out_of_bounds(global_position):
		out_of_bounds_timer += delta
		if out_of_bounds_timer >= out_of_bounds_time:
			_restart()
	else:
		out_of_bounds_timer = 0.0
	_update_boundary_shell()


## A red shell in the world showing the outer limit. It appears as you get close.
func _update_boundary_shell() -> void:
	var planet := strongest_source_at(global_position)
	if planet == null:
		return
	if _boundary == null:
		var sphere := SphereMesh.new()
		sphere.radius = planet.radius + max_altitude
		sphere.height = sphere.radius * 2.0
		sphere.radial_segments = 96
		sphere.rings = 48
		_boundary_material = StandardMaterial3D.new()
		_boundary_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_boundary_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_boundary_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_boundary_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		sphere.material = _boundary_material
		_boundary = MeshInstance3D.new()
		_boundary.mesh = sphere
		_boundary.top_level = true
		_boundary.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_boundary)
	_boundary.global_position = planet.global_position
	var distance_to_edge := max_altitude - altitude_above(planet, global_position)
	var closeness := clampf(1.0 - distance_to_edge / boundary_fade_distance, 0.0, 1.0)
	var colour := BOUNDARY_COLOUR
	colour.a = closeness * 0.35
	_boundary_material.albedo_color = colour
	_boundary.visible = closeness > 0.0


# --- Trail & prediction (drawn by the minimap) -------------------------------

func _update_trail(delta: float) -> void:
	_trail_timer += delta
	if _trail_timer < trail_interval:
		return
	_trail_timer = 0.0
	trail.append(global_position)
	var max_points := int(trail_seconds / trail_interval)
	if trail.size() > max_points:
		trail = trail.slice(trail.size() - max_points)


## Simulates gravity forward in time: where the ship goes if nothing changes.
func _update_prediction() -> void:
	predicted_path.clear()
	predicted_path.append(global_position)
	will_crash = false
	will_leave_bounds = false
	var p := global_position
	var v := velocity
	var steps := int(path_seconds / path_step)
	for i in steps:
		v += gravity_at(p) * path_step
		p += v * path_step
		var planet := strongest_source_at(p)
		if planet and altitude_above(planet, p) < 0.0:
			will_crash = true
			predicted_path.append(p)
			break
		if not will_leave_bounds and planet and altitude_above(planet, p) > max_altitude:
			will_leave_bounds = true
		if i % 3 == 0:
			predicted_path.append(p)


# --- Status (shown by the minimap) -------------------------------------------

func get_status() -> Dictionary:
	var planet := strongest_source_at(global_position)
	if planet == null:
		return {}

	var to_ship := global_position - planet.global_position
	var speed := velocity.length()
	var orbit_speed := planet.orbit_speed_at(global_position)
	var escaping := planet.orbital_energy(global_position, velocity) >= 0.0
	# Angle of the nose above (+) or below (-) the horizon.
	var nose_angle := 0.0
	if speed > 0.001:
		nose_angle = rad_to_deg(asin(clampf(velocity.dot(to_ship.normalized()) / speed, -1.0, 1.0)))

	var status: String
	var hints: Array[String] = []
	if out_of_bounds_timer > 0.0:
		status = "[color=#ff5544]OUT OF BOUNDS! Get back in %.1fs[/color]" % (out_of_bounds_time - out_of_bounds_timer)
		hints.append("Hold [b]RIGHT click[/b] to slow down and fall back in.")
	elif will_crash:
		status = "[color=#ff5544]CRASH COURSE[/color]"
		if speed < orbit_speed:
			hints.append("Too slow! Hold [b]LEFT click[/b]: lighter = faster.")
		if nose_angle < -3.0:
			hints.append("Nose down %.0f°. [b]W[/b] helps a little." % -nose_angle)
	elif escaping or will_leave_bounds:
		status = "[color=#ffcc33]DRIFTING OUT OF BOUNDS[/color]"
		if speed > orbit_speed:
			hints.append("Too fast! Hold [b]RIGHT click[/b]: heavier = slower.")
		if nose_angle > 3.0:
			hints.append("Nose up %.0f°. [b]S[/b] helps a little." % nose_angle)
	else:
		status = "[color=#55ff66]STABLE ORBIT[/color]"
		hints.append("Keep the green loop closed. Small taps to fine-tune.")

	return {
		"planet": planet,
		"status": status,
		"hints": hints,
		"speed": speed,
		"orbit_speed": orbit_speed,
		"nose_angle": nose_angle,
		"altitude": to_ship.length() - planet.radius,
		"max_altitude": max_altitude,
		"mass": mass,
	}
