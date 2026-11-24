extends Node

# Headless benchmark of the skill tree shop.
# Keys:
#   contracts=1|0   Contract.enabled
#   nodes=11|N      the tuned tree, or a generated tree of N nodes
#   seed=12345 warmup=30 open=300 buys=60 builds=20 starts=20 boosts=2000
# 1. Builds the shop `builds` times (its _ready adds one view per node),
#    and times `starts` run starts on fresh players with every node bought
#    once.
# 2. Loads the level, warps, and with the shop open times its per-frame
#    work for `open` frames: focus moves every 20 frames, zoom held in and
#    out in turns (opening itself is timed once). Then presses `buys`
#    views, one a frame, round-robin.
# 3. Times `boosts` physics steps of the missing fuel boost.
# Prints one line, "RESULT {json}". Times are in ms. The sky's render isn't
# measured: headless has no GPU.

const LEVEL := "res://scenes/levels/generated_level.tscn"
const PLAYER := "res://scenes/player/player.tscn"
const SHOP := "res://scenes/ui/shop_overlay.tscn"
const TUNED := "res://resources/progression/skill_tree.tres"
const FRAME := 1.0 / 60.0
const FOCUS_EVERY := 20
const ZOOM_EVERY := 60


class Marker:
	extends Node

	var driver: Node
	var is_start := true


	func _init(owner_driver: Node, start: bool) -> void:
		driver = owner_driver
		is_start = start
		process_mode = Node.PROCESS_MODE_ALWAYS
		process_priority = -1000 if start else 1000


	func _process(_delta: float) -> void:
		if is_start:
			driver.frame_start = Time.get_ticks_usec()
		elif driver.timing_frames:
			driver.frame_ms.append(driver.ms_since(driver.frame_start))


var done := false
var frame_start := 0
var timing_frames := false
var frame_ms := PackedFloat64Array()

var _args := { }
var _tree: SkillTree
var _progression: Progression
var _level: Node3D
var _shop: ShopOverlay
var _frame := 0
var _buys := 0
var _focus := 0
var _build_ms := PackedFloat64Array()
var _start_ms := PackedFloat64Array()
var _open_ms := PackedFloat64Array()
var _buy_ms := PackedFloat64Array()
var _boost_ms := PackedFloat64Array()
var _open_call_ms := 0.0


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		_args[parts[0]] = parts[1] if parts.size() > 1 else "1"
	Contract.enabled = _arg("contracts", "1") == "1"
	_tree = _make_tree(int(_arg("nodes", "11")))
	_progression = Progression.new()
	_time_builds()
	_time_run_starts()
	_time_boosts()
	_load_level()
	add_child(Marker.new(self, true))
	add_child(Marker.new(self, false))


func _process(_delta: float) -> void:
	if done:
		return
	_frame += 1
	var warmup := int(_arg("warmup", "30"))
	if _frame == warmup:
		_progression.bank_mass(1e6)
		var start := Time.get_ticks_usec()
		_level.get_node("WarpController").warp_finished.emit()
		_open_call_ms = ms_since(start)
		return
	if _frame < warmup:
		return
	if _frame <= warmup + int(_arg("open", "300")):
		timing_frames = true
		_shop_frame(_frame - warmup)
		return
	timing_frames = false
	if _buys < int(_arg("buys", "60")):
		var view := _shop.views[_buys % _shop.views.size()]
		var start := Time.get_ticks_usec()
		view.pressed.emit()
		_buy_ms.append(ms_since(start))
		_buys += 1
		return
	_report()
	Input.action_release(&"shop_zoom_in")
	Input.action_release(&"shop_zoom_out")
	get_tree().paused = false
	done = true


func _shop_frame(frame: int) -> void:
	if frame % FOCUS_EVERY == 0:
		_focus = (_focus + 1) % _shop.views.size()
		_shop.views[_focus].grab_focus()
	if floori(float(frame) / ZOOM_EVERY) % 2 == 0:
		Input.action_release(&"shop_zoom_out")
		Input.action_press(&"shop_zoom_in")
	else:
		Input.action_release(&"shop_zoom_in")
		Input.action_press(&"shop_zoom_out")
	var start := Time.get_ticks_usec()
	_shop._process(FRAME)
	_open_ms.append(ms_since(start))


func _make_tree(count: int) -> SkillTree:
	var tuned: SkillTree = load(TUNED)
	if count == tuned.nodes.size():
		return tuned
	var effects := tuned.effects()
	var tree := SkillTree.new()
	var columns := ceili(sqrt(float(count)))
	for index in count:
		var node := SkillNode.new()
		node.id = StringName("node_%d" % index)
		node.title = "Generated node %d +20%%" % index
		node.effect = effects[index % effects.size()]
		node.step = 0.2
		node.cost = 1.0
		node.max_buys = 5
		var column := floori(float(index) / columns)
		node.required_level = column
		node.grid = Vector2(column, index % columns - floori(columns / 2.0))
		tree.nodes.append(node)
	return tree


func _new_starter() -> RunStarter:
	var starter := RunStarter.new()
	starter.tree = _tree
	starter.progression = _progression
	return starter


func _time_builds() -> void:
	var scene: PackedScene = load(SHOP)
	var warp := WarpController.new()
	var starter := _new_starter()
	for each in int(_arg("builds", "20")):
		var shop: ShopOverlay = scene.instantiate()
		shop.warp_controller = warp
		shop.run_starter = starter
		shop.progression = _progression
		var start := Time.get_ticks_usec()
		add_child(shop)
		_build_ms.append(ms_since(start))
		shop.free()
	warp.free()
	starter.free()


func _time_run_starts() -> void:
	var bought := Progression.new()
	bought.bank_mass(1e6)
	for node in _tree.nodes:
		bought.buy(node)
	var scene: PackedScene = load(PLAYER)
	for each in int(_arg("starts", "20")):
		var player: Player = scene.instantiate()
		var starter := _new_starter()
		starter.progression = bought
		starter.player = player
		var start := Time.get_ticks_usec()
		starter.start_run()
		_start_ms.append(ms_since(start))
		starter.free()
		player.free()


func _time_boosts() -> void:
	var fuel := FuelComponent.new()
	var thruster := ThrusterComponent.new()
	var boost := MissingFuelBoostComponent.new()
	boost.thruster = thruster
	boost.fuel = fuel
	boost.bonus_per_missing = 1.0
	add_child(fuel)
	add_child(boost)
	fuel.set_physics_process(false)
	boost.set_physics_process(false)
	for each in int(_arg("boosts", "2000")):
		fuel.draw(0.0005)
		var start := Time.get_ticks_usec()
		boost._physics_process(FRAME)
		_boost_ms.append(ms_since(start))
	boost.free()
	fuel.free()
	thruster.free()


func _load_level() -> void:
	_level = (load(LEVEL) as PackedScene).instantiate()
	var streamer: HierarchyStreamer = _level.get_node("HierarchyStreamer")
	streamer.level_seed = int(_arg("seed", "12345"))
	var player: Player = _level.get_node("Player")
	player.flight_input.capture_mouse = false
	var starter: RunStarter = _level.get_node("RunStarter")
	starter.progression = _progression
	starter.tree = _tree
	var warp: WarpController = _level.get_node("WarpController")
	warp.progression = _progression
	_shop = _level.get_node("ShopOverlay")
	_shop.progression = _progression
	_shop.reload_on_launch = false
	_level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_level)
	_shop.set_process(false)


func ms_since(start: int) -> float:
	return (Time.get_ticks_usec() - start) / 1000.0


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
		"mean": snappedf(total / sorted.size(), 0.0001),
		"p95": snappedf(sorted[int(sorted.size() * 0.95)], 0.0001),
		"worst": snappedf(sorted[sorted.size() - 1], 0.0001),
	}


func _report() -> void:
	var result := {
		"args": _args,
		"nodes": _tree.nodes.size(),
		"shop_open_call": snappedf(_open_call_ms, 0.0001),
		"shop_build": _stats(_build_ms),
		"run_start": _stats(_start_ms),
		"shop_open_process": _stats(_open_ms),
		"frame_process_open": _stats(frame_ms),
		"buy": _stats(_buy_ms),
		"boost_physics": _stats(_boost_ms),
	}
	print("RESULT ", JSON.stringify(result))
