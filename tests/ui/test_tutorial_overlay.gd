extends GutTest

const LEVEL_PATH := "res://scenes/levels/generated_level.tscn"
const Phase := TutorialOverlay.Phase
const Part := TutorialProgress.Part

var _level: Node3D
var _tutorial: TutorialProgress
var _overlay: TutorialOverlay
var _effect: WarpEffect


func before_each() -> void:
	_tutorial = TutorialProgress.new()


func after_each() -> void:
	get_tree().paused = false


func _build(every_run := false) -> void:
	var progression := Progression.new()
	_level = load(LEVEL_PATH).instantiate()
	(_level.get_node("Player") as Player).flight_input.capture_mouse = false
	(_level.get_node("RunStarter") as RunStarter).progression = progression
	var warp: WarpController = _level.get_node("WarpController")
	warp.progression = progression
	var shop: ShopOverlay = _level.get_node("ShopOverlay")
	shop.progression = progression
	shop.reload_on_launch = false
	_overlay = _level.get_node("TutorialOverlay")
	_overlay.tutorial = _tutorial
	_overlay.every_run = every_run
	_overlay.set_process(false)
	_overlay.training.set_process(false)
	add_child_autofree(_level)
	_effect = _level.get_node("WarpEffect")


func _warp_in() -> void:
	_effect.advance(_effect.warp_duration)


func _player() -> Player:
	return _level.get_node("Player")


func _prompt_text() -> String:
	return _overlay.prompt.text


func test_it_waits_for_the_warp_in() -> void:
	_build()
	assert_eq(_overlay.phase, Phase.WAITING)
	_warp_in()
	assert_eq(_overlay.phase, Phase.CONTROLS)


func test_training_shows_each_step() -> void:
	_build()
	_warp_in()
	assert_eq(_overlay.header.text, "// FLIGHT TRAINING 1/5")
	assert_eq(_prompt_text(), "PITCH")
	assert_eq(Array(_overlay.prompt.actions), [&"pitch_down", &"pitch_up"])
	assert_eq(_overlay.hint.text, "TIP THE NOSE UP AND DOWN")
	_overlay.training.step_started.emit(3)
	assert_eq(_overlay.header.text, "// FLIGHT TRAINING 4/5")
	assert_eq(_prompt_text(), "LOOK")
	assert_eq(_overlay.prompt.keyboard_fallback, "mouse_xy")


func test_a_completed_step_says_nice() -> void:
	_build()
	_warp_in()
	_overlay.training.step_completed.emit(0)
	assert_eq(_overlay.hint.text, "NICE!")


func test_the_games_course() -> void:
	_build()
	var titles := []
	for step in _overlay.training.steps:
		titles.append(step.title)
	assert_eq(titles, ["PITCH", "YAW", "ROLL", "LOOK", "BOOST"])
	assert_true(_overlay.training.steps[3].counts_mouse_motion)


func test_finishing_training_moves_on_to_the_objective() -> void:
	_build()
	_warp_in()
	_overlay.training.finished.emit()
	assert_true(_tutorial.is_done(Part.CONTROLS))
	assert_eq(_overlay.phase, Phase.OBJECTIVE)
	assert_eq(_overlay.header.text, "// OBJECTIVE")
	assert_eq(_prompt_text(), "MINE YOUR QUOTA")
	_overlay.refresh(0.0)
	assert_true(_overlay.planet_marker.has_target)
	assert_true(_overlay.cargo_arrow.visible)


func test_the_planet_marker_marks_the_nearest_root_child() -> void:
	_tutorial.finish(Part.CONTROLS)
	_build()
	_warp_in()
	_overlay.refresh(0.0)
	var systems := (_level.get_node("HierarchyStreamer") as HierarchyStreamer)
	var positions := systems.renderer_for(PackedInt32Array()).child_positions(
		systems.clock.time
	)
	var from := _player().global_position
	var nearest := positions[0]
	for centre in positions:
		if from.distance_to(centre) < from.distance_to(nearest):
			nearest = centre
	assert_eq(_overlay.planet_marker.target, nearest)
	assert_string_starts_with(_overlay.planet_marker.text, "PLANET ")


func test_the_planet_marker_hides_once_arrived() -> void:
	_tutorial.finish(Part.CONTROLS)
	_build()
	_overlay.arrived_distance = 1.0e6
	_warp_in()
	_overlay.refresh(0.0)
	assert_false(_overlay.planet_marker.has_target)


func test_a_session_past_the_controls_starts_at_the_objective() -> void:
	_tutorial.finish(Part.CONTROLS)
	_build()
	_warp_in()
	assert_eq(_overlay.phase, Phase.OBJECTIVE)


func test_the_first_pickup_ends_the_objective_after_a_while() -> void:
	_tutorial.finish(Part.CONTROLS)
	_build()
	_warp_in()
	_player().cargo.add(0.5)
	_overlay.refresh(0.0)
	assert_eq(_prompt_text(), "NICE! KEEP MINING")
	assert_false(_overlay.planet_marker.has_target)
	assert_false(_overlay.cargo_arrow.visible)
	_overlay.refresh(_overlay.objective_linger + 0.1)
	assert_true(_tutorial.is_done(Part.OBJECTIVE))
	assert_eq(_overlay.phase, Phase.DONE)


func test_a_finished_session_shows_nothing() -> void:
	_tutorial.finish(Part.CONTROLS)
	_tutorial.finish(Part.OBJECTIVE)
	_build()
	_warp_in()
	assert_eq(_overlay.phase, Phase.DONE)
	_overlay.refresh(1.0)
	assert_eq(_overlay.panel.modulate.a, 0.0)


func test_every_run_starts_over() -> void:
	_tutorial.finish(Part.CONTROLS)
	_tutorial.finish(Part.OBJECTIVE)
	_build(true)
	_warp_in()
	assert_eq(_overlay.phase, Phase.CONTROLS)


func test_it_fades_out_after_a_crash() -> void:
	_build()
	_warp_in()
	_overlay.refresh(1.0)
	assert_eq(_overlay.panel.modulate.a, 1.0)
	_player().contact_component.heavier_contact.emit(_player(), 100.0)
	_overlay.refresh(1.0)
	assert_eq(_overlay.panel.modulate.a, 0.0)
