extends GutTest

const PLANET_SCENE := preload("res://scenes/bodies/test_planet.tscn")
const LEVEL_SCENE := preload("res://scenes/levels/test_level.tscn")

var _was_enabled: bool
var _planet: Planet


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_planet = add_child_autofree(PLANET_SCENE.instantiate())


func after_each() -> void:
	Contract.enabled = _was_enabled


func test_radius_sizes_mesh_collider_and_gravity_together() -> void:
	_planet.radius = 80.0
	assert_eq(_planet.mesh.radius, 80.0)
	assert_eq(_planet.collider.shape.radius, 80.0)
	assert_eq(_planet.gravity.radius, 80.0)


func test_non_positive_radius_breaks_pre_condition_and_is_ignored() -> void:
	_planet.radius = 0.0
	assert_push_error(
		"[Contract] Pre-condition broken: radius must be positive"
	)
	assert_eq(_planet.radius, 50.0)
	assert_eq(_planet.mesh.radius, 50.0)


func test_level_planet_is_heavier_than_player_starting_mass() -> void:
	var level: Node = autofree(LEVEL_SCENE.instantiate())
	var planet_gravity: GravityComponent = level.get_node(
		"Planet/GravityComponent"
	)
	var player: Player = level.get_node("Player")
	assert_gt(planet_gravity.mass, player.starting_mass)


func test_each_planet_owns_its_collider_sphere() -> void:
	var other: Planet = add_child_autofree(PLANET_SCENE.instantiate())
	other.radius = 10.0
	assert_ne(other.collider.shape, _planet.collider.shape)
	assert_eq(_planet.collider.shape.radius, 50.0)
