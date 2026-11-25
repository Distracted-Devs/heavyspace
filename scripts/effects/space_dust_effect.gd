class_name SpaceDustEffect
extends Node3D

const SHADER := preload("res://resources/shaders/space_dust.gdshader")
const SLOW_SPEED := 0.5
const LIFETIME := 600.0
const VISIBILITY_HALF := 1e7

@export_group("Components")
@export var ship: RigidBody3D
@export var camera_component: CameraComponent

@export_group("Dust")
@export_range(1, 2000, 1, "or_greater") var amount := 250:
	set(value):
		if not Contract.require(value >= 1, "amount must be at least 1"):
			return
		amount = value
@export_range(0.0, 2.0, 0.01, "or_greater") var drift := 0.15:
	set(value):
		if not Contract.require(value >= 0.0, "drift must not be negative"):
			return
		drift = value
@export_range(0.001, 0.5, 0.001, "or_greater") var mote_length := 0.04:
	set(value):
		if _positive(value, "mote_length"):
			mote_length = value
@export_range(0.0001, 0.05, 0.0001, "or_greater") var mote_radius := 0.004:
	set(value):
		if _positive(value, "mote_radius"):
			mote_radius = value
@export_range(0.0, 1.0, 0.01) var alpha := 0.35:
	set(value):
		if not Contract.require(
			value >= 0.0 and value <= 1.0,
			"alpha must be within [0, 1]",
		):
			return
		alpha = value
@export_range(0.1, 10.0, 0.1, "or_greater") var spread := 2.5:
	set(value):
		if _positive(value, "spread"):
			spread = value
@export_range(0.0, 0.99, 0.01) var edge_fade := 0.6:
	set(value):
		if not Contract.require(
			value >= 0.0 and value < 1.0,
			"edge_fade must be within [0, 1)",
		):
			return
		edge_fade = value
@export var colour := Color(0.8, 0.9, 1.0)

var particles: GPUParticles3D

var _process_material: ShaderMaterial
var _mesh: CylinderMesh
var _draw: StandardMaterial3D


func _init() -> void:
	_build()


func _ready() -> void:
	particles.amount = amount
	particles.emitting = true


func _process(_delta: float) -> void:
	update()


func update() -> void:
	if not Contract.require(
		ship != null and camera_component != null,
		"ship and camera_component must be set",
	):
		return
	particles.visible = not ship.freeze
	var distance := camera_component.distance
	var velocity := ship.linear_velocity
	var speed := velocity.length()
	var travel := -ship.global_basis.z.normalized()
	if speed > SLOW_SPEED:
		travel = velocity / speed
	_process_material.set_shader_parameter(&"box_centre", ship.global_position)
	_process_material.set_shader_parameter(&"box_half", distance * spread)
	_process_material.set_shader_parameter(&"drift", -travel * drift * distance)
	_process_material.set_shader_parameter(&"edge_fade", edge_fade)
	_draw.albedo_color = Color(colour, alpha)
	_mesh.top_radius = mote_radius * distance
	_mesh.bottom_radius = mote_radius * distance
	_mesh.height = mote_length * distance


func _build() -> void:
	particles = GPUParticles3D.new()
	particles.top_level = true
	particles.local_coords = false
	particles.lifetime = LIFETIME
	particles.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Y_TO_VELOCITY
	var corner := Vector3.ONE * -VISIBILITY_HALF
	particles.visibility_aabb = AABB(
		corner,
		Vector3.ONE * VISIBILITY_HALF * 2.0,
	)
	_process_material = ShaderMaterial.new()
	_process_material.shader = SHADER
	particles.process_material = _process_material
	_mesh = CylinderMesh.new()
	_mesh.radial_segments = 4
	_mesh.rings = 1
	_draw = StandardMaterial3D.new()
	_draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_draw.vertex_color_use_as_albedo = true
	_mesh.material = _draw
	particles.draw_pass_1 = _mesh
	add_child(particles)


func _positive(value: float, setting: String) -> bool:
	return Contract.require(value > 0.0, "%s must be positive" % setting)
