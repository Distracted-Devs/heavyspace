class_name TutorialOverlay
extends CanvasLayer

enum Phase {
	WAITING,
	CONTROLS,
	OBJECTIVE,
	DONE,
}

const ARROW_SIZE := 22.0
const ARROW_GAP := 10.0

@export_group("Components")
@export var player: Player
@export var streamer: HierarchyStreamer
@export var lose_controller: LoseController
@export var warp_controller: WarpController
@export var warp_effect: WarpEffect
@export var cargo_panel: Control

@export_group("Parts")
@export var training: FlightTraining
@export var panel: Control
@export var header: Label
@export var prompt: InputPrompt
@export var hint: Label
@export var bar: Control
@export var planet_marker: TargetMarker
@export var cargo_arrow: Control
@export var cargo_bounce: BounceEffect

@export_group("Tutorial")
@export_range(0.0, 10.0, 0.1, "or_greater") var objective_linger := 3.0:
	set(value):
		var message := "objective_linger must not be negative"
		if not Contract.require(value >= 0.0, message):
			return
		objective_linger = value
@export_range(0.0, 5000.0, 10.0, "or_greater") var arrived_distance := 150.0:
	set(value):
		var message := "arrived_distance must not be negative"
		if not Contract.require(value >= 0.0, message):
			return
		arrived_distance = value
@export var every_run := false
@export_range(0.1, 20.0, 0.1) var fade_speed := 4.0
@export var arrow_colour := Color(1.0, 0.88, 0.3)
@export var bar_colour := Color(1.0, 0.3, 0.8)
@export var done_colour := Color(1.0, 0.88, 0.3)

var tutorial: TutorialProgress
var phase := Phase.WAITING

var _mining := false
var _linger := -1.0
var _fade := 0.0


func _enter_tree() -> void:
	if tutorial == null:
		tutorial = RunProgress.tutorial


func _ready() -> void:
	_show(0.0)
	cargo_arrow.visible = false
	planet_marker.has_target = false
	bar.draw.connect(_draw_bar)
	cargo_arrow.draw.connect(_draw_cargo_arrow)
	if not Contract.require(
		(
			player != null and streamer != null
			and lose_controller != null and warp_controller != null
		),
		"player, streamer, lose_controller and warp_controller must be set",
	):
		return
	training.step_started.connect(_on_step_started)
	training.step_completed.connect(_on_step_completed)
	training.finished.connect(_on_training_finished)
	if warp_effect != null and warp_effect.playing_in:
		warp_effect.finished.connect(begin, CONNECT_ONE_SHOT)
	else:
		begin()


func _process(delta: float) -> void:
	refresh(delta)


func begin() -> void:
	if every_run:
		tutorial.reset()
	match tutorial.next_part():
		TutorialProgress.Part.CONTROLS:
			phase = Phase.CONTROLS
			training.start()
		TutorialProgress.Part.OBJECTIVE:
			_start_objective()
		_:
			phase = Phase.DONE


func refresh(delta: float) -> void:
	if phase == Phase.OBJECTIVE:
		_advance_objective(delta)
	var showing := (
		(phase == Phase.CONTROLS or phase == Phase.OBJECTIVE)
		and not lose_controller.lost and not warp_controller.warping
	)
	_fade = move_toward(_fade, 1.0 if showing else 0.0, delta * fade_speed)
	_show(_fade)
	bar.queue_redraw()
	cargo_arrow.queue_redraw()


func _on_step_started(index: int) -> void:
	var step := training.steps[index]
	header.text = "// FLIGHT TRAINING %d/%d" % [
		index + 1,
		training.steps.size(),
	]
	prompt.keyboard_fallback = step.keyboard_fallback
	prompt.actions = step.actions
	prompt.text = step.title
	_say(step.hint.to_upper(), &"HoloText")
	bar.visible = true


func _on_step_completed(_index: int) -> void:
	_say("NICE!", &"HoloGold")


func _on_training_finished() -> void:
	tutorial.finish(TutorialProgress.Part.CONTROLS)
	_start_objective()


func _start_objective() -> void:
	phase = Phase.OBJECTIVE
	_mining = true
	_linger = -1.0
	header.text = "// OBJECTIVE"
	prompt.keyboard_fallback = ""
	prompt.actions = []
	prompt.text = "MINE YOUR QUOTA"
	_say("FLY INTO BODIES SMALLER THAN YOU TO FILL YOUR TANKS", &"HoloText")
	bar.visible = false


func _advance_objective(delta: float) -> void:
	if _mining and player.cargo.stored > 0.0:
		_mining = false
		_linger = objective_linger
		prompt.text = "NICE! KEEP MINING"
		_say("FILL EVERY TANK, THEN WARP OUT", &"HoloGold")
	if _mining:
		_aim_markers()
	else:
		_hide_markers()
		_linger -= delta
		if _linger <= 0.0:
			tutorial.finish(TutorialProgress.Part.OBJECTIVE)
			phase = Phase.DONE


func _aim_markers() -> void:
	var planet := _nearest_planet()
	if not planet.is_empty():
		var centre: Vector3 = planet[0]
		var radius: float = planet[1]
		var surface := player.global_position.distance_to(centre) - radius
		planet_marker.target = centre
		planet_marker.text = "PLANET %dm" % int(surface)
		planet_marker.has_target = surface >= arrived_distance
	cargo_arrow.visible = cargo_panel != null
	if cargo_panel != null:
		var rect := cargo_panel.get_global_rect()
		cargo_bounce.base_position = Vector2(
			rect.end.x + ARROW_GAP,
			rect.get_center().y - cargo_arrow.size.y * 0.5,
		)
	if not cargo_bounce.active:
		cargo_bounce.active = true


func _hide_markers() -> void:
	planet_marker.has_target = false
	cargo_arrow.visible = false
	if cargo_bounce.active:
		cargo_bounce.active = false


func _nearest_planet() -> Array:
	var systems := streamer.renderer_for(PackedInt32Array())
	if systems == null or systems.count() == 0:
		return []
	var time := streamer.clock.time if streamer.clock != null else 0.0
	var positions := systems.child_positions(time)
	var from := player.global_position
	var nearest := 0
	for index in positions.size():
		if (
			from.distance_squared_to(positions[index])
			< from.distance_squared_to(positions[nearest])
		):
			nearest = index
	return [positions[nearest], systems.layout.radius[nearest]]


func _say(text: String, look: StringName) -> void:
	hint.text = text
	hint.theme_type_variation = look


func _show(alpha: float) -> void:
	panel.modulate.a = alpha
	planet_marker.modulate.a = alpha
	cargo_arrow.modulate.a = alpha


func _draw_bar() -> void:
	var rect := Rect2(Vector2.ZERO, bar.size)
	var filled := clampf(training.progress, 0.0, 1.0)
	bar.draw_rect(rect, Color(0.0, 0.09, 0.12, 0.8))
	bar.draw_rect(
		Rect2(rect.position, Vector2(rect.size.x * filled, rect.size.y)),
		done_colour if filled >= 1.0 else bar_colour,
	)
	bar.draw_rect(rect, Color(0.3, 0.9, 1.0, 0.5), false, 1.0)


func _draw_cargo_arrow() -> void:
	var middle := cargo_arrow.size.y * 0.5
	var tip := Vector2(0.0, middle)
	cargo_arrow.draw_colored_polygon(
		PackedVector2Array(
			[
				tip,
				tip + Vector2(ARROW_SIZE, -ARROW_SIZE * 0.6),
				tip + Vector2(ARROW_SIZE, ARROW_SIZE * 0.6),
			]
		),
		arrow_colour,
	)
	cargo_arrow.draw_string(
		cargo_arrow.get_theme_default_font(),
		Vector2(ARROW_SIZE + 8.0, middle + 6.0),
		"YOUR QUOTA",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		18,
		arrow_colour,
	)
