extends GutTest

const GAUGE_SCENE := preload("res://scenes/ui/cargo_gauge.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var _was_enabled: bool
var _cargo: CargoComponent
var _gauge: CargoGauge


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_cargo = CargoComponent.new()
	_cargo.tank_size = 5.0
	add_child_autofree(_cargo)
	_gauge = GAUGE_SCENE.instantiate()
	_gauge.cargo = _cargo
	_gauge.set_process(false)
	add_child_autofree(_gauge)


func after_each() -> void:
	Contract.enabled = _was_enabled


func test_one_fill_per_owned_tank() -> void:
	_gauge.refresh(0.0)
	assert_eq(_gauge.fills.size(), 1)
	_cargo.tanks = 3
	_gauge.refresh(0.0)
	assert_eq(_gauge.fills.size(), 3)


func test_fills_follow_the_cargo_in_order() -> void:
	_cargo.tanks = 2
	_cargo.add(7.5)
	_gauge.refresh(0.0)
	assert_almost_eq(_gauge.fills[0], 1.0, 1e-6)
	assert_almost_eq(_gauge.fills[1], 0.5, 1e-6)


func test_the_title_counts_full_tanks_of_owned() -> void:
	_cargo.tanks = 2
	_cargo.add(5.0)
	_gauge.refresh(0.0)
	assert_eq(_gauge.title.text, "// MASS TANKS 1/2")


func test_the_readout_shows_mass_and_filling() -> void:
	_cargo.add(2.5)
	_gauge.refresh(0.0)
	assert_eq(_gauge.readout.text, "MASS 2.5/5 | FILLING")
	assert_false(_gauge.warp_ready)


func test_a_ready_full_cargo_reads_full_and_warp_ready() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	player.flight_input.capture_mouse = false
	add_child_autofree(player)
	var lose := LoseController.new()
	lose.player = player
	add_child_autofree(lose)
	var warp := WarpController.new()
	warp.player = player
	warp.lose_controller = lose
	warp.progression = Progression.new()
	add_child_autofree(warp)
	_gauge.cargo = player.cargo
	_gauge.warp_controller = warp
	player.cargo.add(player.cargo.capacity())
	_gauge.refresh(0.0)
	assert_true(_gauge.warp_ready)
	assert_string_ends_with(_gauge.readout.text, "| FULL | WARP READY")


func test_a_filling_tank_uses_the_filling_colour() -> void:
	_gauge.refresh(0.0)
	assert_eq(_gauge.tank_colour(false), _gauge.filling_colour)
	assert_eq(_gauge.tank_colour(true), _gauge.full_colour)


func test_it_sits_under_the_panel_it_follows() -> void:
	var above := Control.new()
	above.position = Vector2(10.0, 10.0)
	above.size = Vector2(100.0, 40.0)
	add_child_autofree(above)
	_gauge.below = above
	_gauge.gap_px = 6.0
	_gauge.refresh(0.0)
	assert_eq(_gauge.panel.position.y, 56.0)


func test_missing_cargo_is_reported() -> void:
	_gauge.cargo = null
	_gauge.refresh(0.0)
	assert_push_error("cargo must be set")


func test_bad_settings_are_reported_and_ignored() -> void:
	_gauge.bar_height_px = 5.0
	assert_push_error("bar_height_px must be at least 10")
	_gauge.gap_px = -1.0
	assert_push_error("gap_px must not be negative")
	_gauge.ready_flash_hz = 0.0
	assert_push_error("ready_flash_hz must be positive")
