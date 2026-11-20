extends GutTest

const OVERLAY_SCENE := preload("res://scenes/ui/pause_overlay.tscn")

var _pause: PauseController
var _overlay: PauseOverlay


func before_each() -> void:
	_pause = add_child_autofree(PauseController.new())
	_overlay = OVERLAY_SCENE.instantiate()
	_overlay.pause_controller = _pause
	add_child_autofree(_overlay)


func after_each() -> void:
	get_tree().paused = false


func test_label_is_hidden_while_running() -> void:
	assert_false(_overlay.visible)


func test_label_is_visible_only_while_paused() -> void:
	_pause.set_paused(true)
	assert_true(_overlay.visible)
	_pause.set_paused(false)
	assert_false(_overlay.visible)
