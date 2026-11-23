extends Node

# Headless benchmark of the game loop: fly, warp, shop.
#   godot --headless --fixed-fps 60 \
#       -s benchmarks/game_loop/bench.gd -- contracts=0
# Keys:
#   contracts=1|0   Contract.enabled
#   seed=12345 warmup=60 fly=600 warp=90 buys=50 starts=20
# Phase 1 flies for real (arcade flight, physics, boost held, turning on a
# fixed pattern) from the home ring's mid-radius, with collisions off so it
# can't crash. Phase 2 warps out and runs the warp effect. Phase 3 opens the
# shop with a bank of 1000 and buys `buys` upgrades, one a frame, rotating
# through the six. Then `starts` run starts are timed on fresh players.
# Prints one line, "RESULT {json}". Times are in ms.

const LEVEL := "res://scenes/levels/generated_level.tscn"
const PLAYER := "res://scenes/player/player.tscn"
const TURN_PERIOD := 120

enum Phase {
	WARMUP,
	FLY,
	WARP,
	SHOP,
	DONE,
}


class Marker:
	extends Node

	var driver: Node
	var is_start := true


	func _init(owner_driver: Node, start: bool) -> void:
		driver = owner_driver
		is_start = start
		process_physics_priority = -1000 if start else 1000


	func _physics_process(_delta: float) -> void:
		var now := Time.get_ticks_usec()
		if is_start:
			driver.physics_start = now
		elif driver.phase in driver.physics_ms:
			driver.physics_ms[driver.phase].append(
				(now - driver.physics_start) / 1000.0,
			)


class ArcadeTimer:
	extends Node

	var arcade: ArcadeFlightComponent
	var samples := PackedFloat64Array()
	var recording := false


	func _init() -> void:
		process_physics_priority = 1


	func _physics_process(_delta: float) -> void:
		var start := Time.get_ticks_usec()
		arcade.align()
		if recording:
			samples.append((Time.get_ticks_usec() - start) / 1000.0)


var done := false
var phase := Phase.WARMUP
var physics_start := 0
var physics_ms := { }

var _args := { }
var _level: Node3D
var _player: Player
var _progression: Progression
var _arcade_timer: ArcadeTimer
var _momentum: MomentumComponent
var _warp: WarpController
var _effect: WarpEffect
var _shop: ShopOverlay
var _starter: RunStarter
var _frame := 0
var _phase_frame := 0
var _last_frame := 0
var _absorbed := 0
var _frame_ms := { }
var _momentum_ms := PackedFloat64Array()
var _effect_ms := PackedFloat64Array()
var _open_ms := PackedFloat64Array()
var _buy_ms := PackedFloat64Array()
var _start_ms := PackedFloat64Array()
var _buys := 0
var _speeds := PackedFloat64Array()


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		_args[parts[0]] = parts[1] if parts.size() > 1 else "1"
	Contract.enabled = _arg("contracts", "1") == "1"
	for each in [Phase.FLY, Phase.WARP, Phase.SHOP]:
		physics_ms[each] = PackedFloat64Array()
		_frame_ms[each] = PackedFloat64Array()

	_progression = Progression.new()
	_level = (load(LEVEL) as PackedScene).instantiate()
	var streamer: HierarchyStreamer = _level.get_node("HierarchyStreamer")
	streamer.level_seed = int(_arg("seed", "12345"))
	_player = _level.get_node("Player")
	_player.flight_input.capture_mouse = false
	_starter = _level.get_node("RunStarter")
	_starter.progression = _progression
	_warp = _level.get_node("WarpController")
	_warp.progression = _progression
	_warp.warp_cost = 0.0
	_shop = _level.get_node("ShopOverlay")
	_shop.progression = _progression
	_shop.reload_on_launch = false
	_effect = _level.get_node("WarpEffect")
	_level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_level)

	_player.collision_layer = 0
	_player.collision_mask = 0
	_place_in_ring(streamer)

	_arcade_timer = ArcadeTimer.new()
	_arcade_timer.arcade = _player.arcade_flight
	_player.arcade_flight.set_physics_process(false)
	_level.add_child(_arcade_timer)

	_momentum = _player.get_node("MomentumComponent")
	var mass := _player.mass_component
	mass.mass_changed.disconnect(_momentum._on_mass_changed)
	mass.mass_changed.connect(_on_mass_changed)
	_player.get_node("AbsorbEffect").absorbed.connect(_on_absorbed)

	_effect.set_process(false)
	_warp.warp_finished.disconnect(_shop.open)
	_warp.warp_finished.connect(_on_warp_finished)

	_level.add_child(Marker.new(self, true))
	_level.add_child(Marker.new(self, false))


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
	_player.linear_velocity = (
		systems.child_velocity(0, clock.time) + plane.z * 20.0
	)


func _on_mass_changed(new_mass: float) -> void:
	var start := Time.get_ticks_usec()
	_momentum._on_mass_changed(new_mass)
	if phase != Phase.WARMUP:
		_momentum_ms.append((Time.get_ticks_usec() - start) / 1000.0)


func _on_absorbed(_mass: float) -> void:
	if phase == Phase.FLY:
		_absorbed += 1


func _on_warp_finished() -> void:
	var start := Time.get_ticks_usec()
	_shop.open()
	_open_ms.append((Time.get_ticks_usec() - start) / 1000.0)
	_progression.bank_mass(1000.0)
	_next_phase(Phase.SHOP)


func _process(delta: float) -> void:
	if done:
		return
	_frame += 1
	_phase_frame += 1
	var now := Time.get_ticks_usec()
	if phase in _frame_ms:
		_frame_ms[phase].append((now - _last_frame) / 1000.0)
	_last_frame = now
	match phase:
		Phase.WARMUP:
			if _phase_frame >= int(_arg("warmup", "60")):
				_next_phase(Phase.FLY)
				_arcade_timer.recording = true
				Input.action_press("back_thruster")
		Phase.FLY:
			_steer()
			_speeds.append(_player.linear_velocity.length())
			if _phase_frame >= int(_arg("fly", "600")):
				_release_all()
				_arcade_timer.recording = false
				_next_phase(Phase.WARP)
				_warp.warp_out()
		Phase.WARP:
			var start := Time.get_ticks_usec()
			_effect.advance(delta)
			_effect_ms.append((Time.get_ticks_usec() - start) / 1000.0)
		Phase.SHOP:
			_shop_frame()


func _steer() -> void:
	var step := floori(float(_phase_frame) / TURN_PERIOD) % 4
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


func _shop_frame() -> void:
	if _buys < int(_arg("buys", "50")):
		var button := _shop.buttons[_buys % _shop.buttons.size()]
		var start := Time.get_ticks_usec()
		button.pressed.emit()
		_buy_ms.append((Time.get_ticks_usec() - start) / 1000.0)
		_buys += 1
		return
	_time_run_starts()
	_report()
	get_tree().paused = false
	phase = Phase.DONE
	done = true


func _time_run_starts() -> void:
	var scene: PackedScene = load(PLAYER)
	for each in int(_arg("starts", "20")):
		var player: Player = scene.instantiate()
		var starter := RunStarter.new()
		starter.player = player
		starter.upgrades = _starter.upgrades
		starter.progression = _progression
		var start := Time.get_ticks_usec()
		starter.start_run()
		_start_ms.append((Time.get_ticks_usec() - start) / 1000.0)
		starter.free()
		player.free()


func _next_phase(next: Phase) -> void:
	phase = next
	_phase_frame = 0


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
	var result := {
		"args": _args,
		"absorbed": _absorbed,
		"speed": _stats(_speeds),
		"bank_left": _progression.bank,
		"align": _stats(_arcade_timer.samples),
		"momentum": _stats(_momentum_ms),
		"warp_effect": _stats(_effect_ms),
		"shop_open": _stats(_open_ms),
		"buy": _stats(_buy_ms),
		"run_start": _stats(_start_ms),
		"shop_first_frame": _frame_ms[Phase.SHOP][0],
	}
	for each: Phase in [Phase.FLY, Phase.WARP, Phase.SHOP]:
		var phase_name: String = Phase.keys()[each].to_lower()
		result["frame_" + phase_name] = _stats(_frame_ms[each])
		result["physics_" + phase_name] = _stats(physics_ms[each])
	print("RESULT ", JSON.stringify(result))
