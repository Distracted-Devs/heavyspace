extends Node

# Headless benchmark of the pickup rate. The ship laps its home ring at
# mid-ring, with the pickup radius and the speed both scaled by `scale`:
#   godot --headless --fixed-fps 60 \
#       -s benchmarks/player_growth/bench.gd -- scale=1 contracts=0
# Keys:
#   scale=1            multiplies base_radius and base_speed
#   base_radius=8      pickup radius at scale 1
#   base_speed=20      speed along the ring (u/s) at scale 1
#   contracts=1|0      Contract.enabled
#   frames=600 warmup=60 seed=12345
# Prints one line, "RESULT {json}". Times are in ms. "collect" is
# PickupComponent.collect, "absorb" is AbsorbEffect.advance (which includes
# the mass gain and the growth update), "frame" the whole frame's wall time
# and "physics" the scene's physics step.

const LEVEL := "res://scenes/levels/generated_level.tscn"


class Mover:
	extends Node

	var player: Player
	var clock: Clock
	var path: Callable


	func _init() -> void:
		process_physics_priority = -5


	func _physics_process(_delta: float) -> void:
		player.global_position = path.call(clock.time)


class Driver:
	extends Node

	var pickup: PickupComponent
	var absorb: AbsorbEffect
	var pool: LiveBodyPool
	var player: Player
	var warmup := 60
	var frames := 600
	var frame := 0
	var absorbed := 0
	var collect_ms := PackedFloat64Array()
	var absorb_ms := PackedFloat64Array()
	var frame_ms := PackedFloat64Array()
	var physics_ms := PackedFloat64Array()
	var caught := PackedInt32Array()
	var in_flight := PackedInt32Array()
	var live := PackedInt32Array()
	var physics_start := 0
	var last_frame := 0


	func _init() -> void:
		process_physics_priority = 0


	func _ready() -> void:
		absorb.absorbed.connect(_on_absorbed)


	func recording() -> bool:
		return frame > warmup


	func _on_absorbed(_mass: float) -> void:
		if recording():
			absorbed += 1


	func _physics_process(delta: float) -> void:
		var before := absorb.absorbing_count()
		var start := Time.get_ticks_usec()
		pickup.collect()
		var mid := Time.get_ticks_usec()
		var after := absorb.absorbing_count()
		absorb.advance(delta)
		var end := Time.get_ticks_usec()
		if recording():
			collect_ms.append((mid - start) / 1000.0)
			absorb_ms.append((end - mid) / 1000.0)
			caught.append(after - before)
			in_flight.append(after)
			live.append(pool.live_count())


	func _process(_delta: float) -> void:
		frame += 1
		var now := Time.get_ticks_usec()
		if recording():
			frame_ms.append((now - last_frame) / 1000.0)
		last_frame = now


# Marks the start and end of the scene's physics step.
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
var _start_mass := 0.0
var _radius := 0.0
var _speed := 0.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		_args[parts[0]] = parts[1] if parts.size() > 1 else "1"
	Contract.enabled = _arg("contracts", "1") == "1"
	var scale := float(_arg("scale", "1"))
	_radius = float(_arg("base_radius", "8")) * scale
	_speed = float(_arg("base_speed", "20")) * scale

	var level: Node3D = (load(LEVEL) as PackedScene).instantiate()
	var streamer: HierarchyStreamer = level.get_node("HierarchyStreamer")
	streamer.level_seed = int(_arg("seed", "12345"))
	var player: Player = level.get_node("Player")
	player.flight_input.capture_mouse = false
	add_child(level)

	# The ship follows a fixed path, so it can't crash.
	player.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	player.freeze = true
	player.collision_layer = 0
	player.collision_mask = 0
	_start_mass = player.mass_component.current_mass

	var pickup: PickupComponent = level.get_node("Player/PickupComponent")
	var absorb: AbsorbEffect = level.get_node("Player/AbsorbEffect")
	pickup.pickup_radius = _radius
	pickup.set_physics_process(false)
	absorb.set_physics_process(false)

	var mover := Mover.new()
	mover.player = player
	mover.clock = level.get_node("Clock")
	mover.path = _ring_lap(streamer)
	level.add_child(mover)

	_driver = Driver.new()
	_driver.pickup = pickup
	_driver.absorb = absorb
	_driver.pool = level.get_node("LiveBodyPool")
	_driver.player = player
	_driver.warmup = int(_arg("warmup", "60"))
	_driver.frames = int(_arg("frames", "600"))
	level.add_child(_driver)
	level.add_child(Marker.new(_driver, true))
	level.add_child(Marker.new(_driver, false))


func _process(_delta: float) -> void:
	if done or _driver.frame < _driver.warmup + _driver.frames:
		return
	_report()
	done = true


func _arg(key: String, fallback: String) -> String:
	return _args.get(key, fallback)


func _ring_lap(streamer: HierarchyStreamer) -> Callable:
	var systems := streamer.renderer_for(PackedInt32Array())
	var home := 0
	var ring := streamer.renderer_for(PackedInt32Array([home]))
	var plane := ring.global_basis
	var tier := streamer.tier_of(PackedInt32Array([home]))
	var home_radius := systems.layout.radius[home]
	var radius := (tier.orbit_inner + tier.orbit_outer) * 0.5 * home_radius
	var omega := _speed / radius
	return func(time: float) -> Vector3:
		var angle := omega * time
		return (
			systems.child_position(home, time)
			+ plane * Vector3(cos(angle), 0.0, sin(angle)) * radius
		)


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


func _report() -> void:
	var seconds := _driver.frames / 60.0
	var player := _driver.player
	var result := {
		"args": _args,
		"pickup_radius": _radius,
		"speed": _speed,
		"absorbed": _driver.absorbed,
		"pickups_per_second": _driver.absorbed / seconds,
		"mass_gained": player.mass_component.current_mass - _start_mass,
		"final_reach": _driver.pickup.reach(),
		"collect": _stats(_driver.collect_ms),
		"absorb": _stats(_driver.absorb_ms),
		"frame": _stats(_driver.frame_ms),
		"physics": _stats(_driver.physics_ms),
		"caught_per_frame": _int_stats(_driver.caught),
		"in_flight": _int_stats(_driver.in_flight),
		"live": _int_stats(_driver.live),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
	}
	print("RESULT ", JSON.stringify(result))
