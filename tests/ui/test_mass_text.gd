extends GutTest


func test_whole_masses_have_no_decimals_or_space() -> void:
	assert_eq(MassText.mkg(10.0), "10Mkg")
	assert_eq(MassText.mkg(0.0), "0Mkg")


func test_fractional_masses_have_one_decimal() -> void:
	assert_eq(MassText.mkg(12.34), "12.3Mkg")
