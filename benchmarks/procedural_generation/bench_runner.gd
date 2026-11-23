extends Node

# The benchmark itself, loaded by bench.gd once the autoloads exist.
#
# Headless benchmark of the generated level. Run with a fixed step, so every
# frame is one physics tick of 1/60s:
#   godot --headless --fixed-fps 60 \
#       -s benchmarks/procedural_generation/bench.gd -- [key=value ...]
# Keys:
#   scenario=orbit|ring|fly  orbit the home system at the spawn distance,
#                            skim through its ring, or fly in a straight line
#   speed=300                fly speed (u/s), added to the spawn velocity
#   contracts=1|0            Contract.enabled
#   frames=600 warmup=60 seed=12345
#   probe=1                  time each step of the streamer and pool too
#   systems.<field>=value    any Tier field of the systems tier
#   rings.<field>=value      any Tier field of the ring tier
# Prints one line, "RESULT {json}". All times are in ms: "frame" is the whole
# frame's wall time, "physics" the scene's physics step, and "own" the
# streamer, pool and tint together.

const LEVEL := "res://scenes/levels/generated_level.tscn"


class Driver:
	extends Node

	var streamer: HierarchyStreamer
	var pool: LiveBodyPool
	var tint: MassTintDebug
	var player: Player
	var clock: Clock
	var path: Callable
	var warmup := 60
	var frames := 600
	var frame := 0
	var stream_ms := PackedFloat64Array()
	var pool_ms := PackedFloat64Array()
	var tint_ms := PackedFloat64Array()
	var frame_ms := PackedFloat64Array()
	var physics_ms := PackedFloat64Array()
	var physics_start := 0
	var last_frame := 0
	var live := PackedInt32Array()
	var expanded := PackedInt32Array()
	var probe := false
	var parts: Dictionary[String, PackedFloat64Array] = { }


	func _init() -> void:
		process_physics_priority = -4


	func recording() -> bool:
		return frame > warmup


	func _physics_process(_delta: float) -> void:
		player.global_position = path.call(clock.time)
		var focus := player.global_position
		var start := Time.get_ticks_usec()
		if probe:
			_probe_streamer(focus, clock.time)
		else:
			streamer.update(focus, clock.time)
		var mid := Time.get_ticks_usec()
		if probe:
			_probe_pool(focus, clock.time)
		else:
			pool.update(focus, clock.time)
		var end := Time.get_ticks_usec()
		if recording():
			stream_ms.append((mid - start) / 1000.0)
			pool_ms.append((end - mid) / 1000.0)
			live.append(pool.live_count())
			expanded.append(streamer.expanded_paths().size())


	# The same steps as HierarchyStreamer.update, timed one by one. Keep them
	# in step with it.
	func _probe_streamer(focus: Vector3, time: float) -> void:
		var start := Time.get_ticks_usec()
		streamer._place_renderers(time)
		start = _part("streamer.place", start)
		streamer._collapse_far(focus)
		start = _part("streamer.collapse", start)
		streamer._expand_near(focus, time)
		start = _part("streamer.expand", start)
		if Contract.enabled:
			Contract.invariant(streamer._hierarchy_is_consistent(), "probe")
		_part("streamer.invariant", start)


	# The same steps as LiveBodyPool.update, timed one by one.
	func _probe_pool(focus: Vector3, time: float) -> void:
		var start := Time.get_ticks_usec()
		pool.root_body.global_position = streamer.global_position
		pool._move_or_release(focus, time)
		start = _part("pool.move", start)
		pool._promote_near(focus, time)
		start = _part("pool.promote", start)
		if Contract.enabled:
			Contract.invariant(pool._live_bodies_match_hidden_copies(), "probe")
		_part("pool.invariant", start)


	func _part(part: String, start: int) -> int:
		var now := Time.get_ticks_usec()
		if recording():
			if not parts.has(part):
				parts[part] = PackedFloat64Array()
			parts[part].append((now - start) / 1000.0)
		return now


	func _process(delta: float) -> void:
		frame += 1
		var start := Time.get_ticks_usec()
		tint._process(delta)
		var end := Time.get_ticks_usec()
		if recording():
			tint_ms.append((end - start) / 1000.0)
			frame_ms.append((start - last_frame) / 1000.0)
		last_frame = start


# Marks the start and end of the scene's physics step. The physics monitors
# can't be used per frame: they hold the worst frame of each second.
class Marker:
	extends Node

	var driver: Driver
	var is_start := true


	func _init(owner_driver: Driver, start: bool) -> void:
		driver = owner_driver
		is_start = start
		process_physics_priority = -1000 if start else 1000


	func _physics_process(_delta: float) -> void:
		var now := Time.get_ticks_usec()
		if is_start:
			driver.physics_start = now
		elif driver.recording():
			driver.physics_ms.append((now - driver.physics_start) / 1000.0)


var done := false

var _args := { }
var _driver: Driver
var _load_ms := 0.0
var _home_ring_count := 0
var _level: Node3D


func _set_up() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		_args[parts[0]] = parts[1] if parts.size() > 1 else "1"
	Contract.enabled = _arg("contracts", "1") == "1"

	var level: Node3D = (load(LEVEL) as PackedScene).instantiate()
	var streamer: HierarchyStreamer = level.get_node("HierarchyStreamer")
	streamer.level_seed = int(_arg("seed", "12345"))
	var tiers: Array[Tier] = []
	for tier in streamer.tiers:
		tiers.append(tier.duplicate())
	_apply_tier_args(tiers[0], "systems.")
	_apply_tier_args(tiers[1], "rings.")
	streamer.tiers = tiers
	var player: Player = level.get_node("Player")
	player.flight_input.capture_mouse = false

	var start := Time.get_ticks_usec()
	add_child(level)
	_load_ms = (Time.get_ticks_usec() - start) / 1000.0
	_level = level
	_home_ring_count = streamer.renderer_for(PackedInt32Array([0])).count()

	# The benchmark moves the player on a fixed path, so it can't crash.
	player.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	player.freeze = true
	player.collision_layer = 0
	player.collision_mask = 0

	var pool: LiveBodyPool = level.get_node("LiveBodyPool")
	var tint: MassTintDebug = level.get_node("MassTintDebug")
	streamer.set_physics_process(false)
	pool.set_physics_process(false)
	tint.set_process(false)

	_driver = Driver.new()
	_driver.streamer = streamer
	_driver.pool = pool
	_driver.tint = tint
	_driver.player = player
	_driver.clock = level.get_node("Clock")
	_driver.warmup = int(_arg("warmup", "60"))
	_driver.frames = int(_arg("frames", "600"))
	_driver.probe = _arg("probe", "0") == "1"
	_driver.path = _path_for(_arg("scenario", "orbit"), streamer, player)
	level.add_child(_driver)
	level.add_child(Marker.new(_driver, true))
	level.add_child(Marker.new(_driver, false))


func _ready() -> void:
	_set_up()


func _process(_delta: float) -> void:
	if done or _driver.frame < _driver.warmup + _driver.frames:
		return
	_report()
	done = true


func _arg(key: String, fallback: String) -> String:
	return _args.get(key, fallback)


func _apply_tier_args(tier: Tier, prefix: String) -> void:
	for key: String in _args:
		if key.begins_with(prefix):
			tier.set(key.trim_prefix(prefix), float(_args[key]))


func _path_for(
	scenario: String,
	streamer: HierarchyStreamer,
	player: Player,
) -> Callable:
	var systems := streamer.renderer_for(PackedInt32Array())
	var home := 0
	var ring := streamer.renderer_for(PackedInt32Array([home]))
	var plane := ring.global_basis
	var start := player.global_position
	var g := player.gravity_receiver.gravity_constant
	var home_mass := systems.layout.mass[home]
	match scenario:
		"orbit":
			var radius := 300.0
			var omega := sqrt(g * home_mass / radius) / radius
			return _circle(systems, home, plane, radius, omega)
		"ring":
			# Mid-ring, overtaking the ring bodies at twice their speed.
			var tier := streamer.tier_of(PackedInt32Array([home]))
			var home_radius := systems.layout.radius[home]
			var inner := tier.orbit_inner * home_radius
			var radius := (inner + tier.orbit_outer * home_radius) * 0.5
			var period := tier.inner_period_min
			var omega := 2.0 * TAU / period * pow(inner / radius, 1.5)
			return _circle(systems, home, plane, radius, omega)
		_:
			var speed := float(_arg("speed", "300"))
			var target := _nearest_other_system(systems, start)
			var velocity := (
				player.linear_velocity + start.direction_to(target) * speed
			)
			return func(time: float) -> Vector3:
				return start + velocity * time


func _circle(
	systems: OrbitRenderer,
	home: int,
	plane: Basis,
	radius: float,
	omega: float,
) -> Callable:
	return func(time: float) -> Vector3:
		var angle := omega * time
		return (
			systems.child_position(home, time)
			+ plane * Vector3(cos(angle), 0.0, sin(angle)) * radius
		)


func _nearest_other_system(systems: OrbitRenderer, from: Vector3) -> Vector3:
	var positions := systems.child_positions(0.0)
	var nearest := Vector3.INF
	for index in range(1, positions.size()):
		if positions[index].distance_to(from) < nearest.distance_to(from):
			nearest = positions[index]
	return nearest


func _stats(samples: PackedFloat64Array) -> Dictionary:
	var sorted := samples.duplicate()
	sorted.sort()
	var total := 0.0
	for sample in sorted:
		total += sample
	return {
		"mean": total / sorted.size(),
		"p95": sorted[int(sorted.size() * 0.95)],
		"worst": sorted[sorted.size() - 1],
	}


func _int_stats(samples: PackedInt32Array) -> Dictionary:
	var total := 0
	var most := 0
	for sample in samples:
		total += sample
		most = maxi(most, sample)
	return { "mean": float(total) / samples.size(), "max": most }


func _part_stats() -> Dictionary:
	var stats := { }
	for part in _driver.parts:
		stats[part] = _stats(_driver.parts[part])
	return stats


func _report() -> void:
	var own := PackedFloat64Array()
	for index in _driver.stream_ms.size():
		own.append(
			_driver.stream_ms[index] + _driver.pool_ms[index]
			+ _driver.tint_ms[mini(index, _driver.tint_ms.size() - 1)],
		)
	var systems := _driver.streamer.renderer_for(PackedInt32Array())
	var result := {
		"args": _args,
		"systems": systems.count(),
		"home_ring": _home_ring_count,
		"load_ms": _load_ms,
		"own": _stats(own),
		"streamer": _stats(_driver.stream_ms),
		"pool": _stats(_driver.pool_ms),
		"tint": _stats(_driver.tint_ms),
		"frame": _stats(_driver.frame_ms),
		"physics": _stats(_driver.physics_ms),
		"live": _int_stats(_driver.live),
		"expanded": _int_stats(_driver.expanded),
		"parts": _part_stats(),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
	}
	print("RESULT ", JSON.stringify(result))
