class_name EndgameBuild
extends Node

@export var toggle_key := KEY_F2
@export var tree: SkillTree = preload(
	"res://resources/progression/skill_tree.tres"
)
@export_range(1.0, 1e15, 1.0, "or_greater", "exp") var bank_amount := 1e12:
	set(value):
		if not Contract.require(value > 0.0, "bank_amount must be positive"):
			return
		bank_amount = value
@export var reload_scene := true

var enabled := false


func _ready() -> void:
	if not OS.is_debug_build():
		set_process_unhandled_input(false)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode != toggle_key:
		return
	get_viewport().set_input_as_handled()
	toggle()


func apply(progression: Progression, tutorial: TutorialProgress) -> void:
	if not Contract.require(
		progression != null and tutorial != null and tree != null,
		"progression and tutorial must be set",
	):
		return
	if progression.bank < bank_amount:
		progression.bank_mass(bank_amount - progression.bank)
	var bought := true
	while bought:
		bought = false
		for node in tree.nodes:
			while progression.buy(node):
				bought = true
	tutorial.finish(TutorialProgress.Part.CONTROLS)
	tutorial.finish(TutorialProgress.Part.OBJECTIVE)
	Contract.ensure(
		tree
		.nodes
		.all(
			func(node: SkillNode) -> bool:
				return not progression.can_buy(node),
		),
		"no skill can still be bought",
	)


func toggle() -> void:
	enabled = not enabled
	if enabled:
		apply(RunProgress.progression, RunProgress.tutorial)
	else:
		RunProgress.progression = Progression.new()
	if not reload_scene:
		return
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
