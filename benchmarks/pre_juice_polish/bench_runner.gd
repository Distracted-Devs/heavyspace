extends Node

# Headless benchmark of the pre-juice polish feature.
# Keys:
#   contracts=1|0   Contract.enabled
#   seed=12345 warmup=30 fly=600 speed=20 switches=20 shop=300
#   gpu=0|1         1 = windowed GPU run instead (see below)
#   grow=1|0        0 = rings appear at full size (no grow-in), to compare
#   menu=1|0        0 = no pause menu, to see its share of a device switch
#   spot=0|1        GPU view: 0 = the spawn, 1 = inside the home ring
#   detail=400      GPU detail switch: rings this close (beyond their
#                   reach) get 64 segments, the rest 12
# CPU run (headless):
# 1. Loads the level, finishes the warp in, and with the tutorial on its
#    objective flies the ship `speed` units a frame along the systems'
#    orbit for `fly` frames, so rings stream in and grow. Each frame it
#    times the feature's own work: the grow-in, the tutorial overlay and
#    its planet marker, the warp prompt and the pulses; and separately the
#    streamer's update (ring generation and upload, spiking on the frames
#    a ring streams in).
# 2. Switches the input device `switches` times (every prompt and the
#    pause menu's controls view rebuild), timing each switch.
# 3. Opens the shop with a full bank and times the shop guide and its
#    effects for `shop` frames.
# GPU run (gpu=1, needs a window): holds the spawn view of the home ring
# and planet, and for proxy spheres of 12, 32 and 64 segments reports the
# GPU render time and primitives drawn. Then the per-ring detail switch:
# rings within 400 of the camera (beyond their reach) at 64, the rest 12.
# Prints one line, "RESULT {json}". Times are in ms.

const LEVEL := "res://scenes/levels/generated_level.tscn"
const FRAME := 1.0 / 60.0
const GPU_SEGMENTS: Array[int] = [12, 32, 64]
const GPU_WARMUP := 30
const GPU_FRAMES := 120
const RING_MIDDLE := 105.0

var done := false

var _options := {
	"contracts": 1,
	"seed": 12345,
	"warmup": 30,
	"fly": 600,
	"speed": 20.0,
	"switches": 20,
	"shop": 300,
	"gpu": 0,
	"grow": 1,
	"menu": 1,
	"spot": 0,
	"detail": 400.0,
}
var _level: Node3D
var _player: Player
var _streamer: HierarchyStreamer
var _grow: GrowInEffect
var _tutorial: TutorialOverlay
var _warp_prompt: WarpPrompt
var _pulses: Array[PulseEffect] = []
var _camera: Camera3D
var _direction := Vector3.ZERO
var _time := 0.0
var _result := { }


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		var parts := argument.split("=")
		if parts.size() == 2 and _options.has(parts[0]):
			_options[parts[0]] = float(parts[1])
	Contract.enabled = int(_options.contracts) == 1
	_run.call_deferred()


func _run() -> void:
	_load_level()
	if int(_options.gpu) == 1:
		await _measure_gpu()
	else:
		await _measure_flight()
		await _measure_switches()
		await _measure_shop()
	_result["contracts"] = Contract.enabled
	print("RESULT ", JSON.stringify(_result))
	get_tree().paused = false
	done = true


func _load_level() -> void:
	_level = load(LEVEL).instantiate()
	_player = _level.get_node("Player")
	_player.flight_input.capture_mouse = false
	_streamer = _level.get_node("HierarchyStreamer")
	_streamer.level_seed = int(_options.seed)
	_tutorial = _level.get_node("TutorialOverlay")
	_tutorial.tutorial = TutorialProgress.new()
	_tutorial.tutorial.finish(TutorialProgress.Part.CONTROLS)
	(_level.get_node("ShopOverlay") as ShopOverlay).reload_on_launch = false
	if int(_options.menu) == 0:
		var menu := _level.get_node("PauseMenu")
		_level.remove_child(menu)
		menu.free()
	add_child(_level)
	var effect: WarpEffect = _level.get_node("WarpEffect")
	effect.advance(effect.warp_duration)
	_grow = _level.get_node("GrowInEffect")
	if int(_options.grow) == 0:
		_grow.grow_time = 0.0
	_warp_prompt = _level.get_node("WarpPrompt")
	_pulses = [
		_level.get_node("WarpPrompt/Pulse"),
		_level.get_node("LoseOverlay/RestartPulse"),
	]
	_camera = _player.camera_component.camera
	_player.freeze = true
	_player.pickup_component.process_mode = Node.PROCESS_MODE_DISABLED
	(_level.get_node("LoseController") as LoseController).disarm()


func _measure_flight() -> void:
	for node: Node in [_grow, _tutorial, _warp_prompt, _streamer]:
		node.set_process(false)
		node.set_physics_process(false)
	_tutorial.planet_marker.set_process(false)
	for pulse in _pulses:
		pulse.set_process(false)
	var systems := _streamer.renderer_for(PackedInt32Array())
	var outward := _player.global_position - systems.global_position
	_direction = outward.cross(systems.global_basis.y).normalized()
	var own := PackedFloat64Array()
	var streaming := PackedFloat64Array()
	var expansions := 0
	var total := int(_options.warmup) + int(_options.fly)
	for frame in total:
		await get_tree().physics_frame
		_player.global_position += _direction * float(_options.speed)
		_time += FRAME
		var before := _streamer.expanded_paths().size()
		var start := Time.get_ticks_usec()
		_streamer.update(_player.global_position, _streamer.clock.time)
		var streamed := Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
		_grow.advance(FRAME)
		_tutorial.refresh(FRAME)
		_tutorial.planet_marker.place(_camera)
		_warp_prompt.refresh()
		for pulse in _pulses:
			pulse.advance(FRAME)
		var spent := Time.get_ticks_usec() - start
		if frame < int(_options.warmup):
			continue
		own.append(spent / 1000.0)
		streaming.append(streamed / 1000.0)
		if _streamer.expanded_paths().size() > before:
			expansions += 1
	_result["feature_frame"] = _stats(own)
	_result["streamer_update"] = _stats(streaming)
	_result["expansions"] = expansions
	_result["tutorial_phase"] = _tutorial.phase


func _measure_switches() -> void:
	var switches := PackedFloat64Array()
	var first := 0.0
	for index in int(_options.switches):
		await get_tree().process_frame
		var start := Time.get_ticks_usec()
		InputDevice.device = (
			DeviceTracker.Device.CONTROLLER
			if index % 2 == 0
			else DeviceTracker.Device.KEYBOARD_MOUSE
		)
		var spent := (Time.get_ticks_usec() - start) / 1000.0
		if index == 0:
			first = spent
		else:
			switches.append(spent)
	InputDevice.device = DeviceTracker.Device.KEYBOARD_MOUSE
	_result["first_switch"] = first
	_result["device_switch"] = _stats(switches)


func _measure_shop() -> void:
	var shop: ShopOverlay = _level.get_node("ShopOverlay")
	shop.progression.bank_mass(1.0e6)
	shop.open()
	var guide: ShopGuide = shop.get_node("ShopGuide")
	guide.set_process(false)
	var effects: Array[Node] = [
		guide.buy_tag_bounce,
		guide.buy_hint_pulse,
		guide.warp_pulse,
		guide.warp_arrow_bounce,
	]
	for effect in effects:
		effect.set_process(false)
	var spent_frames := PackedFloat64Array()
	for frame in int(_options.shop):
		await get_tree().process_frame
		var start := Time.get_ticks_usec()
		guide.refresh()
		for effect in effects:
			effect.call(&"advance", FRAME)
		spent_frames.append((Time.get_ticks_usec() - start) / 1000.0)
	_result["shop_guide"] = _stats(spent_frames)
	_result["guiding_buy"] = guide.buy_target() != null


func _measure_gpu() -> void:
	var viewport := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	if int(_options.spot) == 1:
		var home := _streamer.renderer_for(PackedInt32Array([0]))
		var outward := (_player.global_position - home.global_position)
		_player.global_position = (
			home.global_position + outward.normalized() * RING_MIDDLE
		)
	for segments in GPU_SEGMENTS:
		_set_segments(
			func(_renderer: OrbitRenderer) -> int:
				return segments,
		)
		await _sample(viewport, str(segments))
	var planets := _streamer.renderer_for(PackedInt32Array())
	_set_segments(
		func(renderer: OrbitRenderer) -> int:
			return 12 if renderer == planets else 64,
	)
	await _sample(viewport, "planets_12_rings_64")
	_set_segments(
		func(renderer: OrbitRenderer) -> int:
			return 12 if renderer == planets else 32,
	)
	await _sample(viewport, "planets_12_rings_32")
	_set_segments(
		func(renderer: OrbitRenderer) -> int:
			if renderer == planets:
				return 12
			return 64 if _gap(renderer) < float(_options.detail) else 12,
	)
	await _sample(viewport, "planets_12_near_rings_64")
	var near := 0
	for renderer in _renderers():
		if renderer != planets and _gap(renderer) < float(_options.detail):
			near += 1
	_result["near_rings"] = near
	_result["rings"] = _renderers().size() - 1


func _gap(renderer: OrbitRenderer) -> float:
	return (
		_camera.global_position.distance_to(renderer.global_position)
		- renderer.reach()
	)


func _set_segments(segments_for: Callable) -> void:
	for renderer in _renderers():
		renderer.proxy_segments = segments_for.call(renderer)
		renderer.multimesh.mesh = renderer._proxy_mesh()


func _sample(viewport: RID, label: String) -> void:
	for frame in GPU_WARMUP:
		await get_tree().process_frame
	var gpu := PackedFloat64Array()
	var primitives := PackedFloat64Array()
	for frame in GPU_FRAMES:
		await get_tree().process_frame
		gpu.append(
			RenderingServer.viewport_get_measured_render_time_gpu(viewport)
		)
		primitives.append(
			Performance.get_monitor(
				Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME
			)
		)
	_result["gpu_" + label] = _stats(gpu)
	_result["primitives_" + label] = _stats(primitives).mean


func _renderers() -> Array[OrbitRenderer]:
	var found: Array[OrbitRenderer] = []
	for path in _streamer.expanded_paths():
		found.append(_streamer.renderer_for(path))
	return found


func _stats(values: PackedFloat64Array) -> Dictionary:
	if values.is_empty():
		return { "mean": 0.0, "p95": 0.0, "worst": 0.0 }
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value in values:
		total += value
	return {
		"mean": snappedf(total / values.size(), 0.0001),
		"p95": snappedf(sorted[int(floor(0.95 * (sorted.size() - 1)))], 0.0001),
		"worst": snappedf(sorted[-1], 0.0001),
	}
