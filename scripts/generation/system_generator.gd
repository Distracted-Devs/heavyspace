class_name SystemGenerator
extends RefCounted

const TOLERANCE := 1e-6

var settings: SystemSettings
var level_seed: int
var valid: bool

var _layouts: Dictionary[String, PackedFloat64Array] = { }


func _init(system_settings: SystemSettings) -> void:
	settings = system_settings
	valid = settings != null and settings.is_valid()
	if not valid:
		return
	level_seed = settings.level_seed
	if level_seed == 0:
		level_seed = randi_range(1, 0x7fffffff)


func root() -> BodySpec:
	if not valid:
		return null
	var spec := BodySpec.new()
	spec.radius = settings.root_radius
	_finish_core(spec, _rng_for(spec.path), Vector3.UP, false)
	spec.system_normal = Vector3.UP
	_layout(spec)
	return spec


func contents_of(parent: BodySpec) -> Array[BodySpec]:
	var contents: Array[BodySpec] = []
	if not valid:
		return contents
	if not Contract.require(
		parent != null and not parent.is_pickup,
		"parent must be a body, not a pickup",
	):
		return contents
	var orbit_radii := _layout(parent)
	for index in parent.child_count:
		var child := _child_core(parent, index)
		_layout(child)
		_set_orbit_radius(child, orbit_radii[index])
		contents.append(child)
	for index in parent.pickup_count:
		contents.append(_new_pickup(parent, parent.child_count + index))
	Contract.ensure(
		_contents_fit(parent, contents),
		"contents must fit their shells, belt and parent system",
	)
	return contents


func _child_core(parent: BodySpec, index: int) -> BodySpec:
	var child := _new_spec(parent, index)
	var rng := _rng_for(child.path)
	child.radius = (
		parent.radius * rng.randf_range(settings.ratio_min, settings.ratio_max)
	)
	_finish_core(child, rng, parent.system_normal, true)
	child.system_normal = _tilted(
		child.orbit_normal(),
		settings.system_tilt_degrees,
		rng,
	)
	return child


func _new_spec(parent: BodySpec, index: int) -> BodySpec:
	var spec := BodySpec.new()
	spec.path = parent.path.duplicate()
	spec.path.append(index)
	spec.depth = parent.depth + 1
	return spec


func _new_pickup(parent: BodySpec, index: int) -> BodySpec:
	var pickup := _new_spec(parent, index)
	var rng := _rng_for(pickup.path)
	pickup.is_pickup = true
	pickup.radius = maxf(
		(
			parent.radius
			* rng.randf_range(
				settings.pickup_ratio_min,
				settings.pickup_ratio_max,
			)
		),
		settings.min_pickup_radius,
	)
	pickup.mass = settings.mass_law.mass_for_radius(pickup.radius)
	pickup.system_radius = pickup.radius
	_choose_orbit(
		pickup,
		rng,
		parent.system_normal,
		settings.belt_inclination_degrees,
	)
	_set_orbit_radius(
		pickup,
		rng.randf_range(
			parent.belt_inner + pickup.radius,
			parent.belt_outer - pickup.radius,
		),
	)
	return pickup


func _finish_core(
	spec: BodySpec,
	rng: RandomNumberGenerator,
	plane_normal: Vector3,
	orbits: bool,
) -> void:
	spec.mass = settings.mass_law.mass_for_radius(spec.radius)
	if spec.depth < settings.max_depth:
		spec.child_count = rng.randi_range(
			settings.children_min,
			settings.children_max,
		)
	var has_belt := (
		settings.pickups_per_body > 0
		and spec.radius * settings.pickup_ratio_max
		>= settings.min_pickup_radius
	)
	spec.pickup_count = settings.pickups_per_body if has_belt else 0
	if orbits:
		_choose_orbit(spec, rng, plane_normal, settings.max_inclination_degrees)


func _layout(spec: BodySpec) -> PackedFloat64Array:
	var key := spec.key()
	var orbit_radii: PackedFloat64Array
	if _layouts.has(key):
		orbit_radii = _layouts[key]
	else:
		orbit_radii = PackedFloat64Array()
		var cursor := spec.radius
		for index in spec.child_count:
			var child := _child_core(spec, index)
			_layout(child)
			cursor += settings.shell_gap * child.system_radius
			cursor += child.system_radius
			orbit_radii.append(cursor)
			cursor += child.system_radius
		_layouts[key] = orbit_radii
		_layouts[key + "|outer"] = PackedFloat64Array([cursor])
	var shells_outer: float = _layouts[key + "|outer"][0]
	spec.system_radius = shells_outer
	if spec.pickup_count > 0:
		spec.belt_inner = shells_outer + settings.belt_gap * spec.radius
		spec.belt_outer = spec.belt_inner + settings.belt_width * spec.radius
		spec.system_radius = spec.belt_outer
	return orbit_radii


func _choose_orbit(
	spec: BodySpec,
	rng: RandomNumberGenerator,
	plane_normal: Vector3,
	max_inclination_degrees: float,
) -> void:
	var normal := _tilted(plane_normal, max_inclination_degrees, rng)
	spec.orbit_u = _perpendicular(normal)
	spec.orbit_v = normal.cross(spec.orbit_u).normalized()
	spec.phase = rng.randf() * TAU
	spec.linear_speed = rng.randf_range(settings.speed_min, settings.speed_max)


func _set_orbit_radius(spec: BodySpec, orbit_radius: float) -> void:
	spec.orbit_radius = orbit_radius
	spec.angular_speed = spec.linear_speed / orbit_radius


func _tilted(
	normal: Vector3,
	max_degrees: float,
	rng: RandomNumberGenerator,
) -> Vector3:
	var tilt := deg_to_rad(rng.randf_range(0.0, max_degrees))
	var axis := _perpendicular(normal).rotated(normal, rng.randf() * TAU)
	return normal.rotated(axis, tilt).normalized()


func _perpendicular(normal: Vector3) -> Vector3:
	var helper := Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT
	return normal.cross(helper).normalized()


func _rng_for(path: PackedInt32Array) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([level_seed, path])
	return rng


func _contents_fit(parent: BodySpec, contents: Array[BodySpec]) -> bool:
	var shells_limit := (
		parent.belt_inner if parent.pickup_count > 0 else parent.system_radius
	)
	var children: Array[BodySpec] = []
	for spec in contents:
		if not _orbit_is_valid(spec, parent):
			return false
		if spec.is_pickup:
			if (
				spec.orbit_radius - spec.radius < parent.belt_inner - TOLERANCE
				or spec.orbit_radius + spec.radius
				> parent.belt_outer + TOLERANCE
			):
				return false
			continue
		if (
			spec.orbit_radius - spec.system_radius < parent.radius - TOLERANCE
			or spec.orbit_radius + spec.system_radius > shells_limit + TOLERANCE
		):
			return false
		for other in children:
			var apart := absf(spec.orbit_radius - other.orbit_radius)
			if apart < spec.system_radius + other.system_radius - TOLERANCE:
				return false
		children.append(spec)
	return true


func _orbit_is_valid(spec: BodySpec, parent: BodySpec) -> bool:
	var max_degrees := (
		settings.belt_inclination_degrees
		if spec.is_pickup
		else settings.max_inclination_degrees
	)
	var inclination := rad_to_deg(
		spec.orbit_normal().angle_to(parent.system_normal)
	)
	var speed := spec.orbit_radius * absf(spec.angular_speed)
	return (
		spec.radius < parent.radius and spec.depth == parent.depth + 1
		and is_equal_approx(spec.orbit_u.length(), 1.0)
		and is_equal_approx(spec.orbit_v.length(), 1.0)
		and absf(spec.orbit_u.dot(spec.orbit_v)) < TOLERANCE
		and inclination <= max_degrees + 1e-3
		and speed >= settings.speed_min - TOLERANCE
		and speed <= settings.speed_max + TOLERANCE
	)
