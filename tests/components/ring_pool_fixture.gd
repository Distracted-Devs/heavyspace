extends RefCounted

const SYSTEM_CENTRE_TIME := 0.0


static func make_streamer() -> HierarchyStreamer:
	var streamer := HierarchyStreamer.new()
	streamer.level_seed = 7
	streamer.root_radius = 100.0
	streamer.root_mass = 1.0e7
	streamer.tiers = [_systems_tier(), _rings_tier()]
	return streamer


static func make_pool(streamer: HierarchyStreamer) -> LiveBodyPool:
	var pool := LiveBodyPool.new()
	pool.streamer = streamer
	return pool


static func make_ring_body_live(
	streamer: HierarchyStreamer,
	pool: LiveBodyPool,
) -> OrbitRenderer:
	var systems := streamer.renderer_for(PackedInt32Array())
	var system_centre := systems.child_position(0, SYSTEM_CENTRE_TIME)
	streamer.update(system_centre, SYSTEM_CENTRE_TIME)
	pool.update(system_centre, SYSTEM_CENTRE_TIME)
	var ring := streamer.renderer_for(PackedInt32Array([0]))
	var spot := ring.child_position(innermost(ring), SYSTEM_CENTRE_TIME)
	streamer.update(spot, SYSTEM_CENTRE_TIME)
	pool.update(spot, SYSTEM_CENTRE_TIME)
	return ring


static func innermost(renderer: OrbitRenderer) -> int:
	var orbits := renderer.layout.orbit_radius
	var best := 0
	for index in orbits.size():
		if orbits[index] < orbits[best]:
			best = index
	return best


static func _systems_tier() -> Tier:
	var tier := Tier.new()
	tier.orbit_inner = 1.5
	tier.orbit_outer = 3.0
	tier.radius_min = 10.0
	tier.radius_max = 10.0
	tier.mass_density = 0.5
	tier.thickness = 5.0
	tier.min_separation = 40.0
	tier.cell_size = 50.0
	tier.spawn_density = 5.0e-6
	tier.inner_period_min = 3000.0
	tier.inner_period_max = 3000.0
	tier.live_distance = 30.0
	tier.release_distance = 45.0
	return tier


static func _rings_tier() -> Tier:
	var tier := Tier.new()
	tier.orbit_inner = 2.0
	tier.orbit_outer = 4.0
	tier.radius_min = 1.0
	tier.radius_max = 2.0
	tier.thickness = 1.0
	tier.min_separation = 4.0
	tier.cell_size = 5.0
	tier.spawn_density = 0.006
	tier.inner_period_min = 600.0
	tier.inner_period_max = 600.0
	tier.expand_distance = 60.0
	tier.collapse_distance = 90.0
	tier.live_distance = 6.0
	tier.release_distance = 9.0
	return tier
