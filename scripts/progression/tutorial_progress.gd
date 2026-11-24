class_name TutorialProgress
extends RefCounted

enum Part {
	CONTROLS,
	OBJECTIVE,
	NONE,
}

var _done: Dictionary[Part, bool] = {
	Part.CONTROLS: false,
	Part.OBJECTIVE: false,
}


func next_part() -> Part:
	if not _done[Part.CONTROLS]:
		return Part.CONTROLS
	if not _done[Part.OBJECTIVE]:
		return Part.OBJECTIVE
	return Part.NONE


func is_done(part: Part) -> bool:
	return _done.get(part, false)


func finish(part: Part) -> void:
	if not Contract.require(
		_done.has(part),
		"only controls or objective can finish",
	):
		return
	_done[part] = true


func reset() -> void:
	for part in _done:
		_done[part] = false
