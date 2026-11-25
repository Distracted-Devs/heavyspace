extends SceneTree

# Launches the game feel benchmark (see bench_runner.gd for its keys):
#   timeout 60 godot --headless --fixed-fps 60 \
#       -s benchmarks/game_feel/bench.gd -- [key=value ...]
# For the GPU figures, run it in a window instead (no --headless):
#   timeout 60 godot -s benchmarks/game_feel/bench.gd -- gpu=1
# The runner is loaded at the first frame, because scripts that use the
# autoloads can't compile before they exist.

const RUNNER := "res://benchmarks/game_feel/bench_runner.gd"

var _runner: Node


func _process(_delta: float) -> bool:
	if _runner == null:
		_runner = load(RUNNER).new()
		root.add_child(_runner)
		return false
	return _runner.done
