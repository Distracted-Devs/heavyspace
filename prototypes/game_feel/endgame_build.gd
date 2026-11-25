extends Node

# Maxes every skill in the tree before the level's RunStarter applies them.
# Sits before GeneratedLevel in main.tscn so its _enter_tree runs first.
# F2 flips it on/off in game and restarts the run; the choice lasts until
# the game is closed.

const META := &"game_feel_endgame"

## The starting state when the game launches. F2 flips it in game.
@export var enabled := true
@export var skip_tutorial := true
@export var toggle_key := KEY_F2
@export var tree: Resource = preload("res://resources/progression/skill_tree.tres")

var _label: Label


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not RunProgress.has_meta(META):
		RunProgress.set_meta(META, enabled)
	if skip_tutorial:
		RunProgress.tutorial.finish(TutorialProgress.Part.CONTROLS)
		RunProgress.tutorial.finish(TutorialProgress.Part.OBJECTIVE)
	if not _is_on():
		return
	var progression = RunProgress.progression
	if progression.bank < 1e11:
		progression.bank_mass(1e12)
	# Unlocks depend on player level, so keep sweeping until nothing more buys.
	var bought := true
	while bought:
		bought = false
		for node in tree.nodes:
			while progression.buy(node):
				bought = true


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_label.position = Vector2(-260, 8)
	_label.size = Vector2(250, 20)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.modulate = Color(1, 1, 1, 0.6)
	_label.text = "ENDGAME BUILD %s  [F2]" % ("ON" if _is_on() else "OFF")
	layer.add_child(_label)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != toggle_key:
		return
	get_viewport().set_input_as_handled()
	var on := not _is_on()
	RunProgress.set_meta(META, on)
	if not on:
		RunProgress.progression = Progression.new()
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func _is_on() -> bool:
	return RunProgress.get_meta(META, enabled)
