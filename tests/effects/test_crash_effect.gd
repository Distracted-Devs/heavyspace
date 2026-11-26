extends GutTest

var _was_enabled: bool
var _ship: Node3D
var _lose: LoseController
var _effect: CrashEffect


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_ship = add_child_autofree(Node3D.new())
	_ship.position = Vector3(10.0, -4.0, 25.0)
	_ship.scale = Vector3.ONE * 3.0
	_lose = LoseController.new()
	_effect = CrashEffect.new()
	_effect.ship = _ship
	_effect.lose_controller = _lose
	_effect.set_process(false)
	add_child_autofree(_effect)


func after_each() -> void:
	Contract.enabled = _was_enabled
	_lose.free()


func _blast() -> Node3D:
	return _effect.get_child(_effect.get_child_count() - 1)


func test_play_spawns_one_explosion_at_the_ship() -> void:
	_effect.play()
	assert_eq(_effect.active_count(), 1)
	assert_almost_eq(
		_blast().global_position.distance_to(_ship.global_position),
		0.0,
		1.0e-4,
	)


func test_explosion_scales_with_the_ship() -> void:
	_effect.play()
	assert_almost_eq(_blast().scale.distance_to(Vector3.ONE * 3.0), 0.0, 1.0e-4)


func test_losing_the_run_plays_it() -> void:
	_lose.lost_game.emit(null)
	assert_eq(_effect.active_count(), 1)


func test_explosion_is_freed_after_its_lifetime() -> void:
	_effect.play()
	var blast := _blast()
	_effect.advance(_effect.lifetime * 0.5)
	assert_eq(_effect.active_count(), 1)
	_effect.advance(_effect.lifetime * 0.5)
	assert_eq(_effect.active_count(), 0)
	assert_true(blast.is_queued_for_deletion())


func test_explosions_age_independently() -> void:
	_effect.play()
	_effect.advance(_effect.lifetime * 0.75)
	_effect.play()
	_effect.advance(_effect.lifetime * 0.5)
	assert_eq(_effect.active_count(), 1)


func test_missing_ship_is_reported() -> void:
	_effect.ship = null
	_effect.play()
	assert_push_error(
		"[Contract] Pre-condition broken: ship and explosion must be set"
	)
	assert_eq(_effect.active_count(), 0)


func test_non_positive_lifetime_is_reported_and_ignored() -> void:
	var lifetime := _effect.lifetime
	_effect.lifetime = 0.0
	assert_push_error(
		"[Contract] Pre-condition broken: lifetime must be positive"
	)
	assert_eq(_effect.lifetime, lifetime)


func test_the_explosion_follows_the_ship() -> void:
	_effect.play()
	_ship.position = Vector3(40.0, 0.0, 0.0)
	_effect.advance(0.1)
	assert_eq(_blast().global_position, _ship.global_position)


func test_a_following_explosion_simulates_in_its_own_frame() -> void:
	_effect.play()
	var all := _blast().find_children("*", "GPUParticles3D")
	assert_false(all.is_empty())
	assert_true(
		all.all(
			func(node: Node) -> bool:
				return node.local_coords,
		)
	)


func test_an_explosion_can_stay_where_it_was_set_off() -> void:
	_effect.follow_ship = false
	_effect.play()
	var at := _blast().global_position
	_ship.position = Vector3(40.0, 0.0, 0.0)
	_effect.advance(0.1)
	assert_eq(_blast().global_position, at)
