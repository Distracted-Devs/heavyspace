class_name RumbleFixture
extends GutTest

var _was_enabled: bool
var _mixer: RumbleMixer


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_mixer = RumbleMixer.new()
	_mixer.set_process(false)
	add_child_autofree(_mixer)


func after_each() -> void:
	get_tree().paused = false
	Contract.enabled = _was_enabled


func _add(source: RumbleSource) -> RumbleSource:
	source.rumble = _mixer
	source.set_process(false)
	add_child_autofree(source)
	return source


func _meter() -> EngineMeterComponent:
	var body := FakeBody.make()
	var meter := EngineMeterComponent.new()
	meter.body = body
	meter.set_physics_process(false)
	body.add_child(meter)
	add_child_autofree(body)
	return meter


func _warp() -> WarpEffect:
	var warp := WarpEffect.new()
	warp.camera = add_child_autofree(Camera3D.new())
	warp.mesh = add_child_autofree(Node3D.new())
	warp.set_process(false)
	add_child_autofree(warp)
	return warp
