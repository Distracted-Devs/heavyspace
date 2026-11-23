class_name RunStarter
extends Node

@export_group("Components")
@export var player: Player

@export_group("Upgrades")
@export var upgrades: Array[Upgrade] = []

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
		_upgrades_are_unique(),
		"upgrades must be set with unique ids",
	):
		return
	for upgrade in upgrades:
		upgrade.apply(player, progression.level_of(upgrade))
	progression.start_run()
	started = true


func _upgrades_are_unique() -> bool:
	var ids := { }
	for upgrade in upgrades:
		if upgrade == null or ids.has(upgrade.id):
			return false
		ids[upgrade.id] = true
	return true
