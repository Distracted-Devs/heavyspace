class_name PlanetSeed

const RADIUS_WEIGHT := 0.0137
const PHASE_WEIGHT := 0.6180339


static func of(orbit_radius: float, phase: float) -> float:
	var seed_value := fposmod(
		orbit_radius * RADIUS_WEIGHT + phase * PHASE_WEIGHT,
		1.0,
	)
	Contract.ensure(
		seed_value >= 0.0 and seed_value < 1.0,
		"seed must be within [0, 1)",
	)
	return seed_value
