extends Node

# Benchmark of the HUD and art: thrust gauge, minimap, sun, thrust and
# crash effects, while flying the generated level.
#   godot --headless --fixed-fps 60 \
#       -s benchmarks/hud_and_art/bench.gd -- contracts=0
# Drop --headless for a rough rendered run (frame times include the GPU).
# Keys:
#   contracts=1|0   Contract.enabled
#   seed=12345 warmup=60 fly=600 crashes=5 crash_at=100
#   step=, duration=, max_steps=   override the minimap's prediction
# It flies for real (arcade flight, physics, boost held, turning on a fixed
# pattern) from the home ring's mid-radius, with collisions off so it can't
# crash. Each feature node's per-frame call is made here and timed, instead
# of from its own _process. `crashes` explosions are played, one a frame,
# from frame `crash_at`. The minimap's prediction is also timed on its own
# every 10th frame, with the same inputs.
# Prints one line, "RESULT {json}". Times are in ms.

const LEVEL := "res://scenes/levels/generated_level.tscn"
const TURN_PERIOD := 120
const PREDICT_EVERY := 10

var done := false

var _args := { }
var _level: Node3D
var _player: Player
var _minimap: Minimap
var _gauge: FuelGauge
var _sun: Sun
var _thrust: ThrustEffect
var _crash: CrashEffect
var _predictor := PathPredictor.new()
var _warm: Node3D
var _frame := 0
var _flying := false
var _last_frame := 0
var _absorbed := 0
var _samples := { }


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		_args[parts[0]] = parts[1] if parts.size() > 1 else "1"
	Contract.enabled = _arg("contracts", "1") == "1"
	for key in [
		"frame",
		"minimap",
		"predict",
		"gauge",
		"sun",
		"thrust",
		"crash_play",
		"crash_advance",
		"path_points",
		"map_bodies",
		"heavier",
	]:
		_samples[key] = PackedFloat64Array()

	_level = (load(LEVEL) as PackedScene).instantiate()
	var streamer: HierarchyStreamer = _level.get_node("HierarchyStreamer")
	streamer.level_seed = int(_arg("seed", "12345"))
	_player = _level.get_node("Player")
	_player.flight_input.capture_mouse = false
	_minimap = _level.get_node("Minimap")
	_gauge = _level.get_node("FuelGauge")
	_sun = _level.get_node("Sun")
	_thrust = _player.get_node("ThrustEffect")
	_crash = _level.get_node("CrashEffect")
	if _args.has("step"):
		_minimap.step = float(_args.step)
	if _args.has("duration"):
		_minimap.duration = float(_args.duration)
	if _args.has("max_steps"):
		_minimap.max_steps = int(_args.max_steps)
	_predictor.step = _minimap.step
	_predictor.duration = _minimap.duration
	_predictor.max_steps = _minimap.max_steps
	_predictor.max_sources = _minimap.max_sources
	for node: Node in [_minimap, _gauge, _sun, _thrust, _crash]:
		node.set_process(false)
	add_child(_level)

	_player.collision_layer = 0
	_player.collision_mask = 0
	_place_in_ring(streamer)
	_player.get_node("AbsorbEffect").absorbed.connect(_on_absorbed)
	if _arg("explosion", "") == "prewarm":
		var warm := _crash.explosion.instantiate() as Node3D
		_level.add_child(warm)
		warm.visible = false
		_warm = warm
	elif _arg("explosion", "") == "reuse":
		_warm = _crash.explosion.instantiate() as Node3D
		_level.add_child(_warm)


func _place_in_ring(streamer: HierarchyStreamer) -> void:
	var clock: Clock = _level.get_node("Clock")
	var systems := streamer.renderer_for(PackedInt32Array())
	var ring := streamer.renderer_for(PackedInt32Array([0]))
	var tier := streamer.tier_of(PackedInt32Array([0]))
	var radius := (
		(tier.orbit_inner + tier.orbit_outer) * 0.5 * systems.layout.radius[0]
	)
	var plane := ring.global_basis
	var centre := systems.child_position(0, clock.time)
	_player.global_position = centre + plane.x * radius
	_player.global_basis = Basis.looking_at(plane.z, plane.y)
	_player.linear_velocity = plane.z * 20.0


func _on_absorbed(_mass: float) -> void:
	if _flying:
		_absorbed += 1


func _process(delta: float) -> void:
	if done:
		return
	_frame += 1
	var now := Time.get_ticks_usec()
	if _flying:
		_samples.frame.append((now - _last_frame) / 1000.0)
	_last_frame = now
	var warmup := int(_arg("warmup", "60"))
	var fly := int(_arg("fly", "600"))
	if _frame == 2 and _warm and _arg("explosion", "") == "prewarm":
		_warm.queue_free()
	if _frame == warmup:
		_flying = true
		Input.action_press("back_thruster")
	_run_feature(delta)
	if not _flying:
		return
	var fly_frame := _frame - warmup
	_steer(fly_frame)
	var crash_at := int(_arg("crash_at", "100"))
	if (
		fly_frame >= crash_at
		and fly_frame < crash_at + int(_arg("crashes", "5"))
	):
		if _arg("explosion", "") == "reuse":
			_samples.crash_play.append(_time(_restart_warm))
		else:
			_samples.crash_play.append(_time(_crash.play))
	if fly_frame % PREDICT_EVERY == 0:
		_samples.predict.append(_time(_predict_alone))
		_samples.path_points.append(_predictor.points.size())
		_samples.map_bodies.append(_minimap.map_body_count())
		_samples.heavier.append(
			GravityRegistry.sources_heavier_than(_player.mass).size()
		)
	if fly_frame >= fly:
		_release_all()
		_report()
		done = true


func _run_feature(delta: float) -> void:
	var minimap_ms := _time(
		func() -> void:
			_minimap.refresh(delta),
	)
	var gauge_ms := _time(
		func() -> void:
			_gauge.refresh(delta),
	)
	var sun_ms := _time(
		func() -> void:
			_sun.follow(get_viewport().get_camera_3d()),
	)
	var thrust_ms := _time(_thrust.refresh)
	var crash_ms := _time(
		func() -> void:
			_crash.advance(delta),
	)
	if not _flying:
		return
	_samples.minimap.append(minimap_ms)
	_samples.gauge.append(gauge_ms)
	_samples.sun.append(sun_ms)
	_samples.thrust.append(thrust_ms)
	_samples.crash_advance.append(crash_ms)


func _predict_alone() -> void:
	match _arg("experiment", ""):
		"prune8":
			_predict_pruned(8)
			return
		"ray":
			_ray_forecast()
			return
	_predictor.predict(
		_player.global_position,
		_player.linear_velocity,
		-_player.global_basis.z,
		_player.arcade_flight.alignment,
		_player.linear_damp,
		_player.gravity_receiver.gravity_constant,
		GravityRegistry.positions,
		GravityRegistry.masses,
		GravityRegistry.radii,
		_player.mass,
		_minimap.focus_position(),
	)


func _restart_warm() -> void:
	_warm.global_position = _player.get_node("Mesh").global_position
	for child in _warm.get_children():
		(child as GPUParticles3D).restart()


func _predict_pruned(keep: int) -> void:
	var positions := GravityRegistry.positions
	var masses := GravityRegistry.masses
	var radii := GravityRegistry.radii
	var at := _player.global_position
	var pulls: Array = []
	for index in masses.size():
		if masses[index] > _player.mass:
			var pull := masses[index] / maxf(
				positions[index].distance_squared_to(at),
				1.0,
			)
			pulls.append([pull, index])
	pulls.sort_custom(
		func(a: Array, b: Array) -> bool:
			return a[0] > b[0],
	)
	var kept_positions := PackedVector3Array()
	var kept_masses := PackedFloat64Array()
	var kept_radii := PackedFloat64Array()
	for pair in pulls.slice(0, keep):
		kept_positions.append(positions[pair[1]])
		kept_masses.append(masses[pair[1]])
		kept_radii.append(radii[pair[1]])
	_predictor.predict(
		at,
		_player.linear_velocity,
		-_player.global_basis.z,
		_player.arcade_flight.alignment,
		_player.linear_damp,
		_player.gravity_receiver.gravity_constant,
		kept_positions,
		kept_masses,
		kept_radii,
		_player.mass,
		_minimap.focus_position(),
	)


func _ray_forecast() -> void:
	var positions := GravityRegistry.positions
	var masses := GravityRegistry.masses
	var radii := GravityRegistry.radii
	var origin := _player.global_position
	var forward := -_player.global_basis.z
	var nearest := INF
	for index in masses.size():
		if masses[index] <= _player.mass:
			continue
		var to_centre := positions[index] - origin
		var along := to_centre.dot(forward)
		if along < 0.0:
			continue
		var miss_squared := to_centre.length_squared() - along * along
		var radius_squared := radii[index] * radii[index]
		if miss_squared < radius_squared:
			nearest = minf(nearest, along - sqrt(radius_squared - miss_squared))
	_predictor.points = PackedVector3Array(
		[origin, origin + forward * minf(nearest, 4000.0)]
	)


func _time(work: Callable) -> float:
	var start := Time.get_ticks_usec()
	work.call()
	return (Time.get_ticks_usec() - start) / 1000.0


func _steer(fly_frame: int) -> void:
	var step := floori(float(fly_frame) / TURN_PERIOD) % 4
	Input.action_release("turn_left")
	Input.action_release("turn_right")
	Input.action_release("pitch_up")
	if step == 1:
		Input.action_press("turn_left")
	elif step == 2:
		Input.action_press("pitch_up")
	elif step == 3:
		Input.action_press("turn_right")


func _release_all() -> void:
	for action in ["back_thruster", "turn_left", "turn_right", "pitch_up"]:
		Input.action_release(action)


func _arg(key: String, fallback: String) -> String:
	return _args.get(key, fallback)


func _stats(samples: PackedFloat64Array) -> Dictionary:
	if samples.is_empty():
		return { "n": 0 }
	var sorted := samples.duplicate()
	sorted.sort()
	var total := 0.0
	for sample in sorted:
		total += sample
	return {
		"n": sorted.size(),
		"mean": total / sorted.size(),
		"p95": sorted[int(sorted.size() * 0.95)],
		"worst": sorted[sorted.size() - 1],
	}


func _report() -> void:
	var result := { "args": _args, "absorbed": _absorbed }
	for key: String in _samples:
		result[key] = _stats(_samples[key])
	print("RESULT ", JSON.stringify(result))
