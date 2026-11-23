extends GutTest


func test_seed_matches_the_shader_formula() -> void:
	assert_almost_eq(
		PlanetSeed.of(300.0, 1.2),
		fposmod(300.0 * 0.0137 + 1.2 * 0.6180339, 1.0),
		1.0e-9,
	)


func test_seed_is_within_zero_and_one() -> void:
	for orbit_radius in [0.0, 1.0, 523.7, 99999.0]:
		for phase in [-TAU, -1.0, 0.0, 2.5, TAU]:
			var seed_value := PlanetSeed.of(orbit_radius, phase)
			assert_true(seed_value >= 0.0 and seed_value < 1.0)


func test_same_orbit_gives_the_same_seed() -> void:
	assert_eq(PlanetSeed.of(812.5, 0.3), PlanetSeed.of(812.5, 0.3))


func test_different_orbits_give_different_seeds() -> void:
	assert_ne(PlanetSeed.of(400.0, 0.1), PlanetSeed.of(450.0, 0.1))
