extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const BOOSTER := preload(
	"res://resources/progression/effects/booster_effect.tres"
)

var _was_enabled: bool


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true


func after_each() -> void:
	Contract.enabled = _was_enabled


func test_a_missing_player_is_reported() -> void:
	BOOSTER.apply(null, 1.0)
	assert_push_error("[Contract] Pre-condition broken: player must be set")


func test_a_negative_amount_is_reported_and_changes_nothing() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	var force := player.thruster.back_thrust_force
	BOOSTER.apply(player, -0.5)
	assert_push_error(
		"[Contract] Pre-condition broken: amount must not be negative"
	)
	assert_eq(player.thruster.back_thrust_force, force)
	player.free()
