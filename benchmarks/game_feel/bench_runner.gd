extends Node

# Headless benchmark of the game feel feature.
# Keys:
#   contracts=1|0   Contract.enabled
#   seed=12345 warmup=30 fly=600 crash=180 buys=12 title=300
#   gpu=0|1         1 = windowed GPU run instead (see below)
# CPU run (headless):
# 1. Flight: the level with the ship boosting flat out and yawing, under
#    its own physics, for `fly` frames. Each frame it times every game
#    feel effect's update on its own (they're switched off and called by
#    hand), and the frame's process and physics time.
# 2. Warp: one warp out, timing the effects that follow the warp curve.
# 3. Crash: the frame the run is lost (explosion, bounce, hit-stop and
#    rumbles start) as a spike, then `crash` frames of the slow motion.
# 4. Shop: `buys` purchases with a full bank, timing each one (punch, bank
#    count-up, unlock reveal), then the tweens they start.
# 5. Title: the title screen for `title` frames, its camera and the frame.
# GPU run (gpu=1, needs a window): the boosting flight, sampling the GPU
# render time with the speed lines, dust and blur on and each off.
# Prints one line, "RESULT {json}". Times are in ms.

const LEVEL := "res://scenes/levels/generated_level.tscn"
const TITLE := "res://scenes/title/title_screen.tscn"
const FRAME := 1.0 / 60.0
const GPU_WARMUP := 30
const GPU_FRAMES := 120

var done := false

var _options := {
	"contracts": 1,
	"seed": 12345,
	"warmup": 30,
	"fly": 600,
	"crash": 180,
	"buys": 12,
	"title": 300,
	"gpu": 0,
}
var _level: Node3D
var _player: Player
var _effects := { }
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
		await _measure_warp()
		await _measure_crash()
		await _measure_shop()
		await _measure_title()
	_result["contracts"] = Contract.enabled
	print("RESULT ", JSON.stringify(_result))
	Engine.time_scale = 1.0
	get_tree().paused = false
	done = true


func _load_level() -> void:
	_level = load(LEVEL).instantiate()
	_player = _level.get_node("Player")
	_player.flight_input.capture_mouse = false
	(_level.get_node("HierarchyStreamer") as HierarchyStreamer).level_seed = (
		int(_options.seed)
	)
	var tutorial: TutorialOverlay = _level.get_node("TutorialOverlay")
	tutorial.tutorial = TutorialProgress.new()
	tutorial.tutorial.finish(TutorialProgress.Part.CONTROLS)
	tutorial.tutorial.finish(TutorialProgress.Part.OBJECTIVE)
	(_level.get_node("ShopOverlay") as ShopOverlay).reload_on_launch = false
	add_child(_level)
	var warp: WarpEffect = _level.get_node("WarpEffect")
	warp.advance(warp.warp_duration)
	_player.fuel_component.tank_size = 1.0e6
	_player.fuel_component.refill_time = 0.01
	_player.pickup_component.process_mode = Node.PROCESS_MODE_DISABLED
	_player.flight_input.process_mode = Node.PROCESS_MODE_DISABLED
	(_level.get_node("LoseController") as LoseController).disarm()
	_effects = {
		"engine_meter": _player.get_node("EngineMeterComponent"),
		"thrust": _player.get_node("ThrustEffect"),
		"bank": _player.get_node("BankEffect"),
		"camera_follow": _player.get_node("CameraFollowEffect"),
		"speed_lines": _player.get_node("SpeedLinesEffect"),
		"space_dust": _player.get_node("SpaceDustEffect"),
		"thrust_rumble": _player.get_node("ThrustRumble"),
		"camera_shake": _level.get_node("CameraShakeEffect"),
		"radial_blur": _level.get_node("RadialBlurEffect"),
		"warp_rumble": _level.get_node("WarpRumble"),
		"time_scale": _level.get_node("TimeScaleEffect"),
		"crash_bounce": _level.get_node("CrashBounceEffect"),
		"crash_effect": _level.get_node("CrashEffect"),
		"rumble_mixer": get_node(^"/root/Rumble"),
	}
	for node: Node in _effects.values():
		node.set_process(false)
		node.set_physics_process(false)


func _update(key: String) -> float:
	var node: Node = _effects[key]
	var start := Time.get_ticks_usec()
	match key:
		"speed_lines", "space_dust", "thrust_rumble", "warp_rumble":
			node.call(&"update")
		"crash_effect":
			node.call(&"advance", FRAME)
		"rumble_mixer":
			node.call(&"advance", FRAME)
			node.call(&"send")
		_:
			node.call(&"update", FRAME)
	return (Time.get_ticks_usec() - start) / 1000.0


func _time_frames(frames: int, keys: Array, warmup := 0) -> Dictionary:
	var sums := { }
	for key in keys:
		sums[key] = 0.0
	var total := PackedFloat64Array()
	var whole := PackedFloat64Array()
	var last := Time.get_ticks_usec()
	for frame in frames + warmup:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var frame_total := 0.0
		for key in keys:
			var spent := _update(key)
			frame_total += spent
			if frame >= warmup:
				sums[key] += spent
		if frame >= warmup:
			total.append(frame_total)
			whole.append((now - last) / 1000.0)
		last = Time.get_ticks_usec()
	var out := { "total": _stats(total), "engine_frame": _stats(whole) }
	for key in keys:
		out[key] = snappedf(sums[key] / maxf(frames, 1.0), 0.0001)
	return out


const FLIGHT_KEYS := [
	"engine_meter",
	"thrust",
	"bank",
	"camera_follow",
	"speed_lines",
	"space_dust",
	"thrust_rumble",
	"camera_shake",
	"radial_blur",
	"warp_rumble",
	"rumble_mixer",
]


func _measure_flight() -> void:
	_player.flight_input.thrust_intent = Vector3.FORWARD
	_player.flight_input.rotation_intent = Vector3(0.0, 0.6, 0.0)
	_result["flight"] = await _time_frames(
		int(_options.fly),
		FLIGHT_KEYS,
		int(_options.warmup),
	)
	_result["flight_speed"] = snappedf(_player.linear_velocity.length(), 0.1)


func _measure_warp() -> void:
	var warp: WarpEffect = _level.get_node("WarpEffect")
	warp.set_process(false)
	warp.play()
	var frames := roundi(warp.warp_duration / FRAME)
	var out := { }
	var timing := PackedFloat64Array()
	for frame in frames:
		await get_tree().physics_frame
		warp.advance(FRAME)
		var frame_total := 0.0
		for key in FLIGHT_KEYS:
			frame_total += _update(key)
		timing.append(frame_total)
	out["total"] = _stats(timing)
	_result["warp"] = out
	var camera := _player.camera_component.camera
	camera.fov = (
		_player.get_node("CameraFollowEffect") as CameraFollowEffect
	).base_fov
	_player.get_node("Mesh").position = Vector3.ZERO
	_player.get_node("Mesh").scale = Vector3.ONE * 2.0


func _measure_crash() -> void:
	var lose: LoseController = _level.get_node("LoseController")
	var hit := Node3D.new()
	_level.add_child(hit)
	hit.global_position = _player.global_position + Vector3(0.0, 0.0, -5.0)
	await get_tree().physics_frame
	var start := Time.get_ticks_usec()
	lose.lost_game.emit(hit)
	_result["crash_spike"] = snappedf(
		(Time.get_ticks_usec() - start) / 1000.0,
		0.0001,
	)
	_player.stop_flight()
	var keys := [
		"time_scale",
		"crash_bounce",
		"crash_effect",
		"camera_shake",
		"bank",
		"camera_follow",
		"speed_lines",
		"space_dust",
		"thrust",
		"radial_blur",
		"rumble_mixer",
	]
	_result["crash"] = await _time_frames(int(_options.crash), keys)
	Engine.time_scale = 1.0


func _measure_shop() -> void:
	var shop: ShopOverlay = _level.get_node("ShopOverlay")
	var progression := Progression.new()
	progression.bank_mass(1.0e12)
	shop.progression = progression
	var juice: ShopJuice = _level.get_node("ShopJuice")
	juice._note()
	progression.changed.connect(shop._refresh)
	shop.open()
	var tree := (_level.get_node("RunStarter") as RunStarter).tree
	var buys := PackedFloat64Array()
	var punches := PackedFloat64Array()
	var reveals := 0
	for index in int(_options.buys):
		await get_tree().process_frame
		var node := _next_buy(tree, progression)
		if node == null:
			break
		var start := Time.get_ticks_usec()
		progression.buy(node)
		buys.append((Time.get_ticks_usec() - start) / 1000.0)
		start = Time.get_ticks_usec()
		juice._on_changed()
		punches.append((Time.get_ticks_usec() - start) / 1000.0)
		reveals += juice.revealed.size()
	_result["shop_refresh"] = _stats(buys)
	_result["shop_juice"] = _stats(punches)
	_result["shop_reveals"] = reveals
	var tweens := PackedFloat64Array()
	for frame in 60:
		await get_tree().process_frame
		var start := Time.get_ticks_usec()
		for tween in get_tree().get_processed_tweens():
			tween.custom_step(FRAME)
		tweens.append((Time.get_ticks_usec() - start) / 1000.0)
	_result["shop_tweens"] = _stats(tweens)
	get_tree().paused = false


func _next_buy(tree: SkillTree, progression: Progression) -> SkillNode:
	for node in tree.nodes:
		if progression.can_buy(node):
			return node
	return null


func _measure_title() -> void:
	_level.queue_free()
	await get_tree().process_frame
	var title: TitleScreen = load(TITLE).instantiate()
	add_child(title)
	title.set_process(false)
	for frame in int(_options.warmup):
		await get_tree().process_frame
	var camera := PackedFloat64Array()
	var whole := PackedFloat64Array()
	var last := Time.get_ticks_usec()
	for frame in int(_options.title):
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		whole.append((now - last) / 1000.0)
		title.update(FRAME)
		camera.append((Time.get_ticks_usec() - now) / 1000.0)
		last = Time.get_ticks_usec()
	_result["title_camera"] = _stats(camera)
	_result["title_engine_frame"] = _stats(whole)
	title.queue_free()


func _measure_gpu() -> void:
	for node: Node in _effects.values():
		node.set_process(true)
		node.set_physics_process(true)
	_player.flight_input.thrust_intent = Vector3.FORWARD
	_player.flight_input.rotation_intent = Vector3(0.0, 0.6, 0.0)
	var viewport := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	var lines: SpeedLinesEffect = _effects.speed_lines
	var dust: SpaceDustEffect = _effects.space_dust
	var blur: RadialBlurEffect = _effects.radial_blur
	await _sample(viewport, "all_on")
	lines.particles.visible = false
	await _sample(viewport, "no_lines")
	lines.particles.visible = true
	dust.set_process(false)
	dust.particles.visible = false
	await _sample(viewport, "no_dust")
	dust.set_process(true)
	blur.set_process(false)
	blur.rect.visible = false
	await _sample(viewport, "no_blur")
	blur.set_process(true)


func _sample(viewport: RID, label: String) -> void:
	for frame in GPU_WARMUP:
		await get_tree().process_frame
	var gpu := PackedFloat64Array()
	for frame in GPU_FRAMES:
		await get_tree().process_frame
		gpu.append(
			RenderingServer.viewport_get_measured_render_time_gpu(viewport)
		)
	_result["gpu_" + label] = _stats(gpu)


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
