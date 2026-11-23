class_name Tier
extends Resource

const MAX_CELLS := 1000000

@export_group("Orbit")
@export_range(1.0, 10.0, 0.01, "or_greater") var orbit_inner := 1.6
@export_range(1.0, 10.0, 0.01, "or_greater") var orbit_outer := 2.6
@export_range(0.01, 100.0, 0.01, "or_greater") var thickness := 10.0
@export_range(0.0, 180.0, 0.1) var plane_tilt_max_degrees := 180.0

@export_group("Size")
@export_range(0.01, 100.0, 0.01, "or_greater") var radius_min := 1.0
@export_range(0.01, 100.0, 0.01, "or_greater") var radius_max := 3.0
@export_range(0.01, 10.0, 0.01, "or_greater") var size_bias := 2.0
@export_range(0.0, 100.0, 0.0001, "or_greater") var mass_density := 8.0

@export_group("Mass cap")
@export_range(0.0, 10.0, 0.01, "or_greater") var mass_ceiling_fraction := 0.0
@export_range(0.0, 1.0e6, 0.001, "or_greater") var mass_min := 0.1
@export_range(0.01, 10.0, 0.01, "or_greater") var mass_bias := 1.5

@export_group("Spawning")
@export_range(0.0, 1.0, 1.0e-12, "or_greater") var spawn_density := 7.6e-4
@export_range(0.01, 1000.0, 0.01, "or_greater") var cell_size := 8.0
@export_range(0.0, 1000.0, 0.01, "or_greater") var min_separation := 6.0

@export_group("Speed")
@export_range(0.1, 1000.0, 0.1, "or_greater") var inner_period_min := 60.0
@export_range(0.1, 1000.0, 0.1, "or_greater") var inner_period_max := 60.0
@export_range(0.0, 1.0, 0.01) var retrograde_chance := 0.0

@export_group("Streaming")
@export_range(0.0, 1.0e5, 0.1, "or_greater") var expand_distance := 2000.0
@export_range(0.0, 1.0e5, 0.1, "or_greater") var collapse_distance := 3000.0
@export_range(0.0, 1.0e5, 0.1, "or_greater") var live_distance := 60.0
@export_range(0.0, 1.0e5, 0.1, "or_greater") var release_distance := 90.0


func expected_count(parent_radius: float) -> float:
	var inner := orbit_inner * parent_radius
	var outer := orbit_outer * parent_radius
	var ring_area := PI * (outer * outer - inner * inner)
	return spawn_density * ring_area * 2.0 * thickness


func is_mass_capped() -> bool:
	return mass_ceiling_fraction > 0.0


func cell_spawn_chance() -> float:
	return spawn_density * cell_size * cell_size * 2.0 * thickness


func cells_across(parent_radius: float) -> int:
	return ceili(2.0 * orbit_outer * parent_radius / cell_size)


func require_valid(parent_radius: float) -> bool:
	var checks := [
		Contract.require(
			radius_min > 0.0 and radius_min <= radius_max,
			"radius_min must be positive and at most radius_max",
		),
		Contract.require(
			orbit_inner <= orbit_outer,
			"orbit_inner must be at most orbit_outer",
		),
		Contract.require(thickness > 0.0, "thickness must be positive"),
		Contract.require(size_bias > 0.0, "size_bias must be positive"),
		Contract.require(mass_density > 0.0, "mass_density must be positive"),
		Contract.require(spawn_density > 0.0, "spawn_density must be positive"),
		Contract.require(
			mass_ceiling_fraction >= 0.0,
			"mass_ceiling_fraction must not be negative",
		),
		Contract.require(
			not is_mass_capped() or mass_min > 0.0,
			"a capped tier's mass_min must be positive",
		),
		Contract.require(
			not is_mass_capped() or mass_bias > 0.0,
			"a capped tier's mass_bias must be positive",
		),
		Contract.require(
			inner_period_min > 0.0 and inner_period_min <= inner_period_max,
			"inner periods must be positive and ordered",
		),
		Contract.require(
			retrograde_chance >= 0.0 and retrograde_chance <= 1.0,
			"retrograde_chance must be in [0, 1]",
		),
		Contract.require(
			plane_tilt_max_degrees >= 0.0 and plane_tilt_max_degrees <= 180.0,
			"plane_tilt_max_degrees must be in [0, 180]",
		),
		Contract.require(
			orbit_inner * parent_radius >= parent_radius + radius_max,
			"children must not touch the parent",
		),
		Contract.require(
			min_separation >= 2.0 * radius_max,
			"min_separation must be at least twice radius_max",
		),
		Contract.require(
			min_separation <= cell_size,
			"min_separation must be at most cell_size",
		),
		Contract.require(
			cell_spawn_chance() <= 1.0,
			"cell spawn chance must be at most 1",
		),
		Contract.require(
			collapse_distance > expand_distance,
			"collapse_distance must be greater than expand_distance",
		),
		Contract.require(
			release_distance > live_distance,
			"release_distance must be greater than live_distance",
		),
		Contract.require(
			pow(cells_across(parent_radius), 2.0) <= MAX_CELLS,
			"grid must have at most %d cells" % MAX_CELLS,
		),
	]
	return not checks.has(false)
