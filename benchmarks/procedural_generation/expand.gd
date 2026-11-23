extends SceneTree

# Launches expand_runner.gd (see it for its options):
#   godot --headless -s benchmarks/procedural_generation/expand.gd -- [...]

const RUNNER := "res://benchmarks/procedural_generation/expand_runner.gd"

var _runner: Node


func _process(_delta: float) -> bool:
	if _runner == null:
		_runner = load(RUNNER).new()
		root.add_child(_runner)
		return false
	return _runner.done
