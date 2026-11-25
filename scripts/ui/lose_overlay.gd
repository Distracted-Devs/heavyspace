class_name LoseOverlay
extends CanvasLayer

@export_group("Components")
@export var lose_controller: LoseController
@export var time_scale_effect: TimeScaleEffect

@export_group("Timing")
@export_range(0.0, 3.0, 0.05, "or_greater") var popup_delay := 0.3:
	set(value):
		var message := "popup_delay must not be negative"
		if not Contract.require(value >= 0.0, message):
			return
		popup_delay = value


func _ready() -> void:
	visible = false
	lose_controller.lost_game.connect(_on_lost_game)


func _on_lost_game(_other: Node3D) -> void:
	if time_scale_effect == null:
		visible = true
		return
	time_scale_effect.finished.connect(
		_on_slow_motion_finished,
		CONNECT_ONE_SHOT,
	)


func _on_slow_motion_finished() -> void:
	var wait := get_tree().create_timer(popup_delay, true, false, true)
	wait.timeout.connect(show)
