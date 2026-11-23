extends GutTest

var _effect: CrashEffect


func before_each() -> void:
	_effect = CrashEffect.new()
	_effect.ship = add_child_autofree(Node3D.new())


func test_prewarm_is_on_by_default() -> void:
	autofree(_effect)
	assert_true(_effect.prewarm)


func test_prewarm_doesnt_count_as_an_active_explosion() -> void:
	add_child_autofree(_effect)
	assert_eq(_effect.active_count(), 0)


func test_prewarm_frees_its_explosion() -> void:
	add_child_autofree(_effect)
	await wait_process_frames(2)
	assert_eq(_effect.get_child_count(), 0)


func test_no_prewarm_spawns_nothing() -> void:
	_effect.prewarm = false
	add_child_autofree(_effect)
	assert_eq(_effect.get_child_count(), 0)
