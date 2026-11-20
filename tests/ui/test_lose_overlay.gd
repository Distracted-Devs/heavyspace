extends GutTest

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const OVERLAY_SCENE := preload("res://scenes/ui/lose_overlay.tscn")

var _player: Player
var _overlay: LoseOverlay


func before_each() -> void:
	_player = PLAYER_SCENE.instantiate()
	_player.flight_input.capture_mouse = false
	add_child_autofree(_player)
	var lose := LoseController.new()
	lose.player = _player
	add_child_autofree(lose)
	_overlay = OVERLAY_SCENE.instantiate()
	_overlay.lose_controller = lose
	add_child_autofree(_overlay)


func test_message_is_hidden_until_the_player_loses() -> void:
	assert_false(_overlay.visible)
	_player.contact_component.heavier_contact.emit(_player, 100.0)
	assert_true(_overlay.visible)
