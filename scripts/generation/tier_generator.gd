class_name TierGenerator


static func generate(
	level_seed: int,
	path: PackedInt32Array,
	parent_radius: float,
	tier: Tier,
) -> TierLayout:
	var layout := TierLayout.new()
	if not Contract.require(
		parent_radius > 0.0,
		"parent_radius must be positive",
	):
		return layout
	if not Contract.require(tier != null, "tier must not be null"):
		return layout
	if not tier.require_valid(parent_radius):
		return layout

	var rng := RandomNumberGenerator.new()
	rng.seed = hash([level_seed, path])
	layout.plane = _random_plane(rng, tier.plane_tilt_max_degrees)

	var inner := tier.orbit_inner * parent_radius
	var outer := tier.orbit_outer * parent_radius
	var cell := tier.cell_size
	var margin := tier.min_separation * 0.5
	var jitter := cell - tier.min_separation
	var spawn_chance := tier.cell_spawn_chance()
	var across := tier.cells_across(parent_radius)
	for row in across:
		for column in across:
			if rng.randf() >= spawn_chance:
				continue
			var x := -outer + column * cell + margin + rng.randf() * jitter
			var z := -outer + row * cell + margin + rng.randf() * jitter
			var orbit := Vector2(x, z).length()
			if orbit < inner or orbit > outer:
				continue
			var radius := lerpf(
				tier.radius_min,
				tier.radius_max,
				pow(rng.randf(), tier.size_bias),
			)
			layout.append(
				radius,
				tier.mass_density * pow(radius, 3.0),
				orbit,
				rng.randf_range(-tier.thickness, tier.thickness),
				_phase_of(x, z),
				_angular_speed(rng, tier, inner, orbit),
			)

	Contract.ensure(
		_children_in_range(layout, tier, inner, outer),
		"children must be within their tier ranges",
	)
	return layout


static func _random_plane(
	rng: RandomNumberGenerator,
	tilt_max_degrees: float,
) -> Basis:
	var cos_tilt := rng.randf_range(cos(deg_to_rad(tilt_max_degrees)), 1.0)
	var azimuth := rng.randf() * TAU
	var axis := Vector3(cos(azimuth), 0.0, sin(azimuth))
	var plane := Basis(axis, acos(clampf(cos_tilt, -1.0, 1.0)))
	Contract.ensure(
		(
			plane.is_conformal()
			and plane.y.angle_to(Vector3.UP)
			<= deg_to_rad(tilt_max_degrees) + 1.0e-6
		),
		"plane must be a rotation within the tilt limit",
	)
	return plane


static func _phase_of(x: float, z: float) -> float:
	var phase := fposmod(atan2(z, x), TAU)
	return 0.0 if phase >= TAU else phase


static func _angular_speed(
	rng: RandomNumberGenerator,
	tier: Tier,
	inner: float,
	orbit: float,
) -> float:
	var period := rng.randf_range(tier.inner_period_min, tier.inner_period_max)
	var speed := TAU / period * pow(inner / orbit, 1.5)
	return -speed if rng.randf() < tier.retrograde_chance else speed


static func _children_in_range(
	layout: TierLayout,
	tier: Tier,
	inner: float,
	outer: float,
) -> bool:
	for index in layout.size():
		var radius := layout.radius[index]
		var orbit := layout.orbit_radius[index]
		var phase := layout.phase[index]
		if (
			radius < tier.radius_min or radius > tier.radius_max
			or orbit < inner or orbit > outer
			or absf(layout.height[index]) > tier.thickness or phase < 0.0
			or phase >= TAU or layout.angular_speed[index] == 0.0
		):
			return false
	return true
