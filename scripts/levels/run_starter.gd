class_name RunStarter
extends Node

@export_group("Components")
@export var player: Player

@export_group("Skill tree")
@export var tree: SkillTree

var progression: Progression
var started := false


func _enter_tree() -> void:
	if progression == null:
		progression = RunProgress.progression
	start_run()


func start_run() -> void:
	if started:
		return
	if not Contract.require(
		player != null and not player.is_node_ready(),
		"player must be set and not yet ready",
	):
		return
	if not Contract.require(
		tree == null or tree.is_valid(),
		"the skill tree must be valid",
	):
		return
	if tree != null:
		var buys := progression.buys_by_id()
		for effect in tree.effects():
			effect.apply(player, tree.amount(effect, buys))
	progression.start_run()
	started = true
