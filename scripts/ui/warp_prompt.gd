class_name WarpPrompt
extends CanvasLayer

@export_group("Components")
@export var warp_controller: WarpController


func _ready() -> void:
	visible = false
	Contract.require(warp_controller != null, "warp_controller must be set")


func _process(_delta: float) -> void:
	refresh()


func refresh() -> void:
	visible = warp_controller != null and warp_controller.can_warp()
