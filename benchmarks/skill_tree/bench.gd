extends SceneTree

# Launches the skill tree benchmark (see bench_runner.gd for its options):
#   timeout 60 godot --headless --fixed-fps 60 \
#       -s benchmarks/skill_tree/bench.gd -- [key=value ...]
# The runner is loaded at the first frame, because scripts that use the
# autoloads can't compile before they exist.

const RUNNER := "res://benchmarks/skill_tree/bench_runner.gd"

var _runner: Node


func _process(_delta: float) -> bool:
	if _runner == null:
		_runner = load(RUNNER).new()
		root.add_child(_runner)
		return false
	return _runner.done
