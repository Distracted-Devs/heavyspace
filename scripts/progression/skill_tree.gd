class_name SkillTree
extends Resource

@export var nodes: Array[SkillNode] = []


func is_valid() -> bool:
	var ids := { }
	for node in nodes:
		if node == null or not node.is_valid() or ids.has(node.id):
			return false
		ids[node.id] = true
	return true


func find(id: StringName) -> SkillNode:
	for node in nodes:
		if node != null and node.id == id:
			return node
	return null


func effects() -> Array[SkillEffect]:
	var found: Array[SkillEffect] = []
	for node in nodes:
		if node != null and node.effect != null and node.effect not in found:
			found.append(node.effect)
	return found


func amount(effect: SkillEffect, levels: Dictionary) -> float:
	if not Contract.require(
		levels.values().all(
			func(buys: int) -> bool:
				return buys >= 0,
		),
		"buys must not be negative",
	):
		return 0.0
	var total := 0.0
	for node in nodes:
		if node != null and node.effect == effect:
			total += node.step * levels.get(node.id, 0)
	Contract.ensure(total >= 0.0, "the amount must not be negative")
	return total
