extends GutTest

var _law: MassLaw


func before_each() -> void:
	_law = MassLaw.new()


func test_default_law_gives_the_player_mass_one_at_radius_half() -> void:
	assert_almost_eq(_law.mass_for_radius(0.5), 1.0, 1e-9)


func test_mass_follows_density_times_radius_to_the_exponent() -> void:
	_law.density = 3.0
	_law.exponent = 2.0
	assert_almost_eq(_law.mass_for_radius(4.0), 48.0, 1e-9)


func test_radius_for_mass_inverts_mass_for_radius() -> void:
	for radius in [0.05, 0.5, 7.0, 200.0]:
		var mass := _law.mass_for_radius(radius)
		assert_almost_eq(_law.radius_for_mass(mass), radius, radius * 1e-9)


func test_non_positive_settings_are_reported_and_ignored() -> void:
	_law.density = 0.0
	assert_push_error(
		"[Contract] Pre-condition broken: density must be positive"
	)
	_law.exponent = -1.0
	assert_push_error(
		"[Contract] Pre-condition broken: exponent must be positive"
	)
	assert_almost_eq(_law.density, 2.0 ** 1.5, 1e-9)
	assert_eq(_law.exponent, 1.5)


func test_non_positive_inputs_are_reported() -> void:
	assert_true(is_nan(_law.mass_for_radius(0.0)))
	assert_push_error(
		"[Contract] Pre-condition broken: radius must be positive"
	)
	assert_true(is_nan(_law.radius_for_mass(-1.0)))
	assert_push_error("[Contract] Pre-condition broken: mass must be positive")
