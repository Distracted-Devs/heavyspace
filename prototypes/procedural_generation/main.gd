extends Node3D
## Prototype: two hand-built levels of the hierarchy. A giant body with a ring
## of "systems", each one a Saturn-like central body with its own ring of
## smaller bodies. Everything moves on scripted circular orbits. Reuses the
## test level (player, overlays, lose flow, tint) and swaps its planet out.
##
## Systems orbit the giant at the real circular-orbit speed for its mass, and
## the player spawns with its home system's velocity, so ship and system fall
## around the giant together.
##
## Performance: everything is drawn by MultiMeshes whose orbits run in a
## vertex shader (orbit.gdshader), so drawn bodies cost no CPU. A real
## MassBody (collision, gravity) exists only near the player, at exactly the
## shader's position, and hides its drawn copy while it exists.

const LEVEL := preload("res://scenes/levels/test_level.tscn")
const BODY := preload("res://scenes/bodies/mass_body.tscn")
const ORBIT_SHADER := preload("res://prototypes/procedural_generation/orbit.gdshader")
const EARTH := preload("res://resources/textures/earth.jpg")

@export_group("System")
@export var seed_value := 1
## Where the player's home system starts (the player is near the origin).
@export var centre := Vector3(0, 0, -300)
## Tilt of each system's ring plane, in degrees.
@export var ring_tilt_degrees := Vector3(20, 0, 10)

@export_group("Central body")
## The player's radius is 0.5, so 50 is 100x the player.
@export var central_radius := 50.0
@export var central_mass := 10000.0

@export_group("Ring")
@export var ring_count := 100
## Inner and outer orbit radius, as multiples of the central radius.
@export var ring_inner := 1.6
@export var ring_outer := 2.6
## Vertical scatter either side of the ring plane, in world units.
@export var ring_thickness := 2.0
@export var body_radius_min := 0.2
@export var body_radius_max := 3.0
## Skews sizes towards small (1 = uniform, higher = more small bodies).
@export var size_bias := 2.0
## Seconds for one orbit at the inner edge. Outer orbits are slower (Kepler).
@export var inner_orbit_period := 90.0

@export_group("Mass")
## Ring mass from size: mass = player_mass * (radius / player_radius)^3, so
## anything bigger than the ship is heavier than it.
@export var player_radius := 0.5
@export var player_mass := 1.0

@export_group("Giant")
## 100x the central body.
@export var giant_radius := 5000.0
## Surface gravity is G * mass / radius^2 (G = 10). 1e7 gives 4 at the
## surface, about 1 at the systems' orbits.
@export var giant_mass := 1.0e7
@export var system_count := 10
## Inner and outer system orbit radius, as multiples of the giant's radius.
@export var system_ring_inner := 1.6
@export var system_ring_outer := 2.6
## Vertical scatter of systems either side of the giant's ring plane.
@export var system_ring_thickness := 1000.0
@export var giant_tilt_degrees := Vector3(-10, 0, 25)
## Must match the player's GravityReceiverComponent.gravity_constant.
@export var gravity_constant := 10.0
## 1 = real circular-orbit speed (the player orbits alongside for free).
@export var system_speed_scale := 1.0
## Give the player its home system's velocity at spawn.
@export var inherit_home_velocity := true
## Systems start at least this far apart (centre to centre).
@export var min_system_separation := 600.0
@export var camera_far := 60000.0

@export_group("Streaming")
## A system's ring is drawn when the player is this close to its centre, and
## dropped past collapse_distance (the gap stops it flickering at the edge).
@export var expand_distance := 2000.0
@export var collapse_distance := 3000.0
## A system's central body becomes a real body (gravity, collision) within
## this distance, and goes back to drawn-only past system_live_release.
@export var system_live_distance := 3000.0
@export var system_live_release := 3500.0
## A ring body becomes a real body within this distance of the player, and
## goes back to drawn-only past live_release.
@export var live_radius := 60.0
@export var live_release := 90.0
## Sphere detail for drawn bodies (real bodies use the full sphere).
@export var proxy_segments := 12

@export_group("Tint")
@export var lighter_colour := Color(0.3, 1.0, 0.3)
@export var heavier_colour := Color(1.0, 0.3, 0.3)

# Systems: index 0 is the player's home.
var _sys_orbit_radius := PackedFloat32Array()
var _sys_orbit_height := PackedFloat32Array()
var _sys_phase := PackedFloat32Array()
var _sys_speed := PackedFloat32Array()
var _sys_centre := PackedVector3Array()
## Real central body per system, or null while drawn-only.
var _sys_live: Array = []
## Per system: null when not drawn, else a dictionary for its ring.
var _rings: Array = []
var _systems_mm: MultiMesh

var _ring_basis := Basis()
var _giant_basis := Basis()
var _giant_centre := Vector3.ZERO
var _time := 0.0
var _level: Node
var _player: Player
var _material: ShaderMaterial
var _proxy_mesh: SphereMesh
var _tinted_for_mass := -1.0


func _ready() -> void:
	_level = LEVEL.instantiate()
	var old_planet := _level.get_node("MassBody")
	_level.remove_child(old_planet)
	old_planet.free()

	_material = ShaderMaterial.new()
	_material.shader = ORBIT_SHADER
	_material.set_shader_parameter("albedo_texture", EARTH)
	_proxy_mesh = SphereMesh.new()
	_proxy_mesh.radial_segments = proxy_segments
	_proxy_mesh.rings = maxi(proxy_segments / 2, 2)
	_proxy_mesh.material = _material

	_ring_basis = Basis.from_euler(ring_tilt_degrees * (PI / 180.0))
	_giant_basis = Basis.from_euler(giant_tilt_degrees * (PI / 180.0))
	_lay_out_systems()

	# Place the giant so the home system starts at `centre`.
	_giant_centre = centre - _system_offset(0)
	var giant := _make_body("Giant", giant_radius, giant_mass)
	giant.position = _giant_centre
	_level.add_child(giant)

	_systems_mm = _make_multimesh(system_count, giant_radius * 3.0)
	for s in system_count:
		_systems_mm.set_instance_transform(
			s,
			Transform3D(Basis.from_scale(Vector3.ONE * central_radius)),
		)
		_systems_mm.set_instance_custom_data(
			s,
			Color(
				_sys_orbit_radius[s],
				_sys_orbit_height[s],
				_sys_phase[s],
				_sys_speed[s],
			),
		)
	_level.add_child(
		_make_multimesh_node(
			"Systems",
			_systems_mm,
			Transform3D(_giant_basis, _giant_centre),
		)
	)

	add_child(_level)

	_player = _level.get_node("Player") as Player
	if inherit_home_velocity:
		_player.linear_velocity = _system_velocity(0)
	var camera := _player.get_node("CameraComponent/Camera3D") as Camera3D
	camera.far = camera_far
	_physics_process(0.0)
	print(
		"[Proto] giant r=%.0f, %d systems x %d ring bodies, home speed %.1f"
		% [
			giant_radius,
			system_count,
			ring_count,
			_system_velocity(0).length(),
		]
	)


func _lay_out_systems() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var s_inner := system_ring_inner * giant_radius
	var s_outer := system_ring_outer * giant_radius
	var placed := PackedVector3Array()
	var tries := 0
	while _sys_orbit_radius.size() < system_count:
		var orbit := rng.randf_range(s_inner, s_outer)
		var height := rng.randf_range(-1.0, 1.0) * system_ring_thickness
		var phase := rng.randf() * TAU
		var local := Vector3(cos(phase) * orbit, height, sin(phase) * orbit)
		tries += 1
		var clear := true
		if tries < system_count * 50:
			for p in placed:
				if p.distance_to(local) < min_system_separation:
					clear = false
					break
		if not clear:
			continue
		placed.append(local)
		_sys_orbit_radius.append(orbit)
		_sys_orbit_height.append(height)
		_sys_phase.append(phase)
		var v := sqrt(gravity_constant * giant_mass / orbit)
		_sys_speed.append(system_speed_scale * v / orbit)
		_sys_centre.append(Vector3.ZERO)
		_sys_live.append(null)
		_rings.append(null)


func _physics_process(delta: float) -> void:
	_time += delta
	_material.set_shader_parameter("orbit_time", _time)
	var tint_changed := _update_tint_mass()
	var player_pos := _player.global_position
	var ring_reach := (
		ring_outer * central_radius + ring_thickness + live_release
	)
	for s in system_count:
		var c := _giant_centre + _system_offset(s)
		_sys_centre[s] = c
		var d := player_pos.distance_to(c)
		_update_live_system(s, c, d)
		if _rings[s] == null and d < expand_distance:
			_expand(s)
		elif _rings[s] != null and d > collapse_distance:
			_collapse(s)
		var ring = _rings[s]
		if ring == null:
			continue
		ring.node.global_transform = Transform3D(_ring_basis, c)
		if tint_changed:
			_tint_ring(ring)
		if d < ring_reach or not ring.live.is_empty():
			_update_live_ring(s, ring, player_pos)
	if tint_changed:
		for s in system_count:
			var live := _sys_live[s] != null
			_systems_mm.set_instance_color(
				s,
				_colour_for(central_mass, not live),
			)


func _update_live_system(s: int, c: Vector3, d: float) -> void:
	var body: MassBody = _sys_live[s]
	if body == null and d < system_live_distance:
		body = _make_body("System%d" % s, central_radius, central_mass)
		body.position = c
		_level.add_child(body)
		_sys_live[s] = body
		_systems_mm.set_instance_color(s, _colour_for(central_mass, false))
	elif body != null and d > system_live_release:
		body.queue_free()
		_sys_live[s] = null
		_systems_mm.set_instance_color(s, _colour_for(central_mass, true))
	elif body != null:
		body.global_position = c


func _update_live_ring(s: int, ring: Dictionary, player_pos: Vector3) -> void:
	var centre_s := _sys_centre[s]
	var orbit: PackedFloat32Array = ring.orbit
	var height: PackedFloat32Array = ring.height
	var phase: PackedFloat32Array = ring.phase
	var speed: PackedFloat32Array = ring.speed
	var radius: PackedFloat32Array = ring.radius
	var live: Dictionary = ring.live
	var mm: MultiMesh = ring.mm
	for i in ring_count:
		var a := phase[i] + speed[i] * _time
		var pos := (
			centre_s
			+ _ring_basis
			* Vector3(cos(a) * orbit[i], height[i], sin(a) * orbit[i])
		)
		var d := pos.distance_to(player_pos)
		var body: MassBody = live.get(i)
		if body == null:
			if d < live_radius:
				var m := _ring_mass(radius[i])
				body = _make_body("S%dRing%d" % [s, i], radius[i], m)
				body.position = pos
				_level.add_child(body)
				live[i] = body
				mm.set_instance_color(i, _colour_for(m, false))
		elif d > live_release:
			body.queue_free()
			live.erase(i)
			mm.set_instance_color(i, _colour_for(_ring_mass(radius[i]), true))
		else:
			body.global_position = pos


func _expand(s: int) -> void:
	# Seeded per system, so a ring is redrawn identically.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, s])
	var inner := ring_inner * central_radius
	var outer := ring_outer * central_radius
	var inner_speed := TAU / inner_orbit_period
	var mm := _make_multimesh(ring_count, outer + body_radius_max)
	var ring := {
		mm = mm,
		node = null,
		live = { },
		radius = PackedFloat32Array(),
		orbit = PackedFloat32Array(),
		height = PackedFloat32Array(),
		phase = PackedFloat32Array(),
		speed = PackedFloat32Array(),
	}
	for i in ring_count:
		var r := lerpf(
			body_radius_min,
			body_radius_max,
			pow(rng.randf(), size_bias),
		)
		var orbit := rng.randf_range(inner, outer)
		var height := rng.randf_range(-1.0, 1.0) * ring_thickness
		var phase := rng.randf() * TAU
		var speed := inner_speed * pow(inner / orbit, 1.5)
		ring.radius.append(r)
		ring.orbit.append(orbit)
		ring.height.append(height)
		ring.phase.append(phase)
		ring.speed.append(speed)
		mm.set_instance_transform(
			i,
			Transform3D(Basis.from_scale(Vector3.ONE * r)),
		)
		mm.set_instance_custom_data(i, Color(orbit, height, phase, speed))
	_tint_ring(ring)
	ring.node = _make_multimesh_node(
		"Ring%d" % s,
		mm,
		Transform3D(_ring_basis, _sys_centre[s]),
	)
	_level.add_child(ring.node)
	_rings[s] = ring


func _collapse(s: int) -> void:
	var ring: Dictionary = _rings[s]
	for body: MassBody in ring.live.values():
		body.queue_free()
	ring.node.queue_free()
	_rings[s] = null


func _tint_ring(ring: Dictionary) -> void:
	var radius: PackedFloat32Array = ring.radius
	var mm: MultiMesh = ring.mm
	for i in radius.size():
		var drawn: bool = not ring.live.has(i)
		mm.set_instance_color(i, _colour_for(_ring_mass(radius[i]), drawn))


func _update_tint_mass() -> bool:
	var mass := _player.mass_component.current_mass
	if is_equal_approx(mass, _tinted_for_mass):
		return false
	_tinted_for_mass = mass
	return true


func _colour_for(mass: float, drawn: bool) -> Color:
	var c := heavier_colour if mass > _tinted_for_mass else lighter_colour
	c.a = 1.0 if drawn else 0.0
	return c


func _ring_mass(r: float) -> float:
	return player_mass * pow(r / player_radius, 3.0)


func _make_multimesh(count: int, half_extent: float) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = _proxy_mesh
	mm.instance_count = count
	var e := Vector3.ONE * half_extent
	mm.custom_aabb = AABB(-e, e * 2.0)
	return mm


func _make_multimesh_node(
		node_name: String,
		mm: MultiMesh,
		xform: Transform3D,
) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = mm
	node.transform = xform
	return node


func _system_angle(s: int) -> float:
	return _sys_phase[s] + _sys_speed[s] * _time


func _system_offset(s: int) -> Vector3:
	var a := _system_angle(s)
	var local := Vector3(
		cos(a) * _sys_orbit_radius[s],
		_sys_orbit_height[s],
		sin(a) * _sys_orbit_radius[s],
	)
	return _giant_basis * local


func _system_velocity(s: int) -> Vector3:
	var a := _system_angle(s)
	var tangent := Vector3(-sin(a), 0, cos(a)) * _sys_orbit_radius[s]
	return _giant_basis * (tangent * _sys_speed[s])


func _make_body(body_name: String, r: float, m: float) -> MassBody:
	var body := BODY.instantiate() as MassBody
	body.name = body_name
	body.radius = r
	body.mass = m
	return body
