extends Node

## Prototype entry: instances the production level, then swaps in the
## prototype pieces before any of the level's _ready functions run.

const LEVEL := preload("res://scenes/levels/generated_level.tscn")
const STREAMER := preload("res://prototypes/pre_juice_polish/polish_streamer.gd")
const SPAWN := preload("res://prototypes/pre_juice_polish/polish_spawn.gd")
const POOL := preload("res://prototypes/pre_juice_polish/polish_pool.gd")

@export_group("Ship")
## Multiplies the ship's model (and its thrust) before growth is applied.
@export_range(0.5, 3.0, 0.01) var ship_scale := 1.3
## Grow the collision sphere with the model, so the hull matches the hits.
@export var scale_collider := true

@export_group("Thrust")
## Particles alive at once (production: 30).
@export_range(1, 1000, 1) var thrust_amount := 90
## How much of the ship's velocity each particle keeps when it's emitted.
## 1 = the plume travels with the ship; 0 = production (left behind).
@export_range(0.0, 1.0, 0.01) var thrust_inherit_velocity := 1.0
## Seconds each particle lives (production: 1).
@export_range(0.05, 5.0, 0.01) var thrust_lifetime := 0.8
## Glue the plume to the ship completely (it swings when the ship turns).
@export var thrust_local_coords := false

@export_group("Rings")
## 0 = ring bodies centred in their grid cells; 1 = anywhere the whole body
## still fits inside its cell.
@export_range(0.0, 1.0, 0.01) var ring_jitter := 1.0
## Seconds a newly streamed-in ring takes to grow to full size (0 = pop).
@export_range(0.0, 5.0, 0.01) var grow_in_time := 0.6
## Godot ease() curve: > 1 eases in (slow start), < 1 eases out.
@export_range(0.05, 5.0, 0.01) var grow_in_ease := 2.0

@export_group("Live bodies")
## Turn a body's surface to its ring's frame when it goes live, so its
## pattern doesn't jump round.
@export var match_proxy_orientation := true
## Proxy sphere segments: 64 matches the live sphere (production: 12).
@export_range(4, 128, 1) var proxy_segments := 64

@export_group("Spawn")
@export var face_nearest_planet := true
## Play the warp-out effect backwards at the start of every run.
@export var warp_in := true

@onready var pause_menu := $PauseMenu
@onready var prompts := $Prompts
@onready var tracker := $DeviceTracker
@onready var warp_in_effect := $WarpIn
@onready var tutorial := $Tutorial


func _ready() -> void:
	var level := LEVEL.instantiate()

	var streamer := level.get_node("HierarchyStreamer")
	_swap_script(streamer, STREAMER)
	streamer.jitter = ring_jitter
	streamer.grow_in_time = grow_in_time
	streamer.grow_in_ease = grow_in_ease
	streamer.proxy_segments = proxy_segments

	var pool := level.get_node("LiveBodyPool")
	_swap_script(pool, POOL)
	pool.match_proxy_orientation = match_proxy_orientation

	var spawn := level.get_node("PlayerSpawn")
	_swap_script(spawn, SPAWN)
	spawn.face_nearest_planet = face_nearest_planet

	var player := level.get_node("Player") as Node3D
	_grow_ship(player)
	_tune_thrust(player.get_node("Mesh/BlueThrust") as GPUParticles3D)

	# The menu replaces the production "Paused" label.
	var old_overlay := level.get_node("PauseOverlay")
	level.remove_child(old_overlay)
	old_overlay.free()

	add_child(level)
	pause_menu.setup(level.get_node("PauseController"), tracker)
	prompts.setup(level, tracker)
	tutorial.setup(level, tracker)
	if warp_in:
		warp_in_effect.finished.connect(tutorial.begin, CONNECT_ONE_SHOT)
		warp_in_effect.play(level.get_node("WarpEffect"))
	else:
		tutorial.begin()


func _swap_script(node: Node, script: Script) -> void:
	var saved := { }
	for property in node.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			saved[property.name] = node.get(property.name)
	node.set_script(script)
	for property_name in saved:
		node.set(property_name, saved[property_name])


func _grow_ship(player: Node3D) -> void:
	# GrowthComponent reads these as its base size in _ready.
	var mesh := player.get_node("Mesh") as Node3D
	mesh.scale *= ship_scale
	if scale_collider:
		var collider := player.get_node("Collider") as CollisionShape3D
		var sphere := collider.shape.duplicate() as SphereShape3D
		sphere.radius *= ship_scale
		collider.shape = sphere


func _tune_thrust(particles: GPUParticles3D) -> void:
	var process := particles.process_material.duplicate() as ParticleProcessMaterial
	process.inherit_velocity_ratio = thrust_inherit_velocity
	particles.process_material = process
	particles.amount = thrust_amount
	particles.lifetime = thrust_lifetime
	particles.local_coords = thrust_local_coords
