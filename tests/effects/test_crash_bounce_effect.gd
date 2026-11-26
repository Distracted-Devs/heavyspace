extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const STEP := 1.0 / 60.0

var _was_enabled: bool
var _player: Player
var _planet: Node3D
var _effect: CrashBounceEffect


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_player = PLAYER_SCENE.instantiate()
	_player.flight_input.capture_mouse = false
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(_player)
	_player.global_position = Vector3(0.0, 0.0, 10.0)
	_planet = add_child_autofree(Node3D.new())
	_effect = CrashBounceEffect.new()
	_effect.player = _player
	_effect.mesh = _player.get_node("Mesh")
	_effect.camera_component = _player.camera_component
	_effect.set_physics_process(false)
	add_child_autofree(_effect)


func after_each() -> void:
	Contract.enabled = _was_enabled


func _distance() -> float:
	return _player.camera_component.distance


func test_a_head_on_crash_bounces_back_at_the_restitution() -> void:
	_player.linear_velocity = Vector3(0.0, 0.0, -100.0)
	_effect.bounce_off(_planet)
	assert_true(_effect.bouncing)
	assert_almost_eq(
		_effect.velocity,
		Vector3(0.0, 0.0, 50.0),
		Vector3.ONE * 1e-3,
	)


func test_a_slow_crash_still_bounces_away_at_the_least_speed() -> void:
	_player.linear_velocity = Vector3(0.0, 0.0, -0.1)
	_effect.bounce_off(_planet)
	var least := _effect.min_speed * _distance()
	assert_almost_eq(_effect.velocity.z, least, 1e-3)


func test_a_glancing_crash_keeps_its_sideways_speed() -> void:
	_player.linear_velocity = Vector3(20.0, 0.0, -100.0)
	_effect.bounce_off(_planet)
	assert_almost_eq(_effect.velocity.x, 20.0, 1e-3)
	assert_gt(_effect.velocity.z, 0.0)


func test_the_bounce_moves_the_ship_and_slows_down() -> void:
	_player.linear_velocity = Vector3(0.0, 0.0, -100.0)
	_effect.bounce_off(_planet)
	for step in 30:
		_effect.update(STEP)
	assert_gt(_player.global_position.z, 10.0)
	assert_lt(_effect.velocity.z, 50.0)


func test_the_ship_tumbles_as_it_bounces() -> void:
	_player.linear_velocity = Vector3(20.0, 0.0, -100.0)
	_effect.bounce_off(_planet)
	var before := _effect.mesh.global_basis
	_effect.update(STEP)
	assert_ne(_effect.mesh.global_basis, before)


func test_still_until_it_bounces() -> void:
	_effect.update(STEP)
	assert_false(_effect.bouncing)
	assert_eq(_player.global_position, Vector3(0.0, 0.0, 10.0))


func test_missing_components_are_reported() -> void:
	_effect.mesh = null
	_effect.bounce_off(_planet)
	assert_push_error("player, mesh and camera_component must be set")


func test_bad_settings_are_reported_and_ignored() -> void:
	var restitution := _effect.restitution
	_effect.restitution = 1.5
	assert_push_error("restitution must be within [0, 1]")
	_effect.min_speed = -1.0
	assert_push_error("min_speed must not be negative")
	_effect.drag = -1.0
	assert_push_error("drag must not be negative")
	assert_eq(_effect.restitution, restitution)
