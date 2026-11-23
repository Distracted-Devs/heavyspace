extends GutTest

const GAUGE_SCENE := preload("res://scenes/ui/fuel_gauge.tscn")

var _was_enabled: bool
var _fuel: FuelComponent
var _gauge: FuelGauge


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_fuel = FuelComponent.new()
	_fuel.tank_size = 4.0
	_fuel.burn_rate = 2.0
	_fuel.set_physics_process(false)
	add_child_autofree(_fuel)
	_gauge = GAUGE_SCENE.instantiate()
	_gauge.fuel = _fuel
	_gauge.set_process(false)
	add_child_autofree(_gauge)


func after_each() -> void:
	Contract.enabled = _was_enabled


func test_full_tank_reads_full_and_lights_every_segment() -> void:
	_gauge.refresh(0.0)
	assert_eq(_gauge.fraction, 1.0)
	assert_eq(_gauge.lit_segments(), float(_gauge.segments))
	assert_false(_gauge.warning)
	assert_eq(_gauge.bar_colour(), _gauge.colour)


func test_fraction_is_fuel_over_tank_size() -> void:
	_fuel.draw(1.0)
	_gauge.refresh(0.0)
	assert_almost_eq(_gauge.fraction, 0.75, 1.0e-6)
	assert_almost_eq(_gauge.lit_segments(), 15.0, 1.0e-4)


func test_readout_shows_percent_and_seconds_of_boost_left() -> void:
	_fuel.draw(1.0)
	_gauge.refresh(0.0)
	assert_eq(_gauge.readout_text(), "FUEL  75% | T-1.5s")
	assert_eq(_gauge.readout.text, _gauge.readout_text())


func test_warns_below_the_low_fuel_fraction() -> void:
	_fuel.draw(3.5)
	_gauge.refresh(0.0)
	assert_true(_gauge.warning)
	var shown := _gauge.bar_colour()
	assert_eq(Color(shown, 1.0), Color(_gauge.low_colour, 1.0))
	assert_between(shown.a, 0.5, 1.0)


func test_warning_flashes_over_time() -> void:
	_fuel.draw(3.9)
	var alphas: Array[float] = []
	for step in 8:
		_gauge.refresh(0.07)
		alphas.append(_gauge.bar_colour().a)
	assert_gt(alphas.max() - alphas.min(), 0.2)


func test_empty_tank_lights_nothing() -> void:
	_fuel.draw(4.0)
	_gauge.refresh(0.0)
	assert_eq(_gauge.fraction, 0.0)
	assert_eq(_gauge.lit_segments(), 0.0)


func test_missing_fuel_is_reported() -> void:
	_gauge.fuel = null
	_gauge.refresh(0.0)
	assert_push_error("[Contract] Pre-condition broken: fuel must be set")


func test_too_few_segments_are_reported_and_ignored() -> void:
	_gauge.segments = 1
	assert_push_error(
		"[Contract] Pre-condition broken: segments must be within [2, 60]"
	)
	assert_eq(_gauge.segments, 20)
