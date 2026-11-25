class_name SpeedLinesEffect
extends Node3D

const MIN_AMOUNT_RATIO := 0.01
const BASE_LENGTH := 0.3
const LINE_RADIUS := 0.015
const MIN_SPEED := 1.0
const VISIBILITY_HALF := 1e4

@export_group("Components")
@export var ship: RigidBody3D
@export var engine_meter: EngineMeterComponent
@export var camera_component: CameraComponent
@export var warp_effect: WarpEffect

@export_group("Lines")
@export_range(0.0, 100.0, 0.5, "or_greater") var min_accel := 5.0:
	set(value):
		if _not_negative(value, "min_accel"):
			min_accel = value
@export_range(1.0, 1000.0, 1.0, "or_greater") var max_accel := 150.0:
	set(value):
		var message := "max_accel must be above min_accel"
		if not Contract.require(value > min_accel, message):
			return
		max_accel = value
@export_range(1, 4000, 1, "or_greater") var amount := 400:
	set(value):
		if not Contract.require(value >= 1, "amount must be at least 1"):
			return
		amount = value
@export_range(0.05, 5.0, 0.05, "or_greater") var lifetime := 0.8:
	set(value):
		if _positive(value, "lifetime"):
			lifetime = value
@export_range(0.0, 3.0, 0.05, "or_greater") var extra_speed := 0.3:
	set(value):
		if _not_negative(value, "extra_speed"):
			extra_speed = value
@export_range(0.1, 10.0, 0.1, "or_greater") var spread := 3.0:
	set(value):
		if _positive(value, "spread"):
			spread = value
@export_range(0.05, 5.0, 0.05, "or_greater") var length := 1.0:
	set(value):
		if _positive(value, "length"):
			length = value
@export_range(0.0, 1.0, 0.01) var max_alpha := 0.6:
	set(value):
		if not Contract.require(
			value >= 0.0 and value <= 1.0,
			"max_alpha must be within [0, 1]",
		):
			return
		max_alpha = value
@export var colour := Color(0.8, 0.9, 1.0)

@export_group("Warp")
@export_range(0.0, 2000.0, 10.0, "or_greater") var warp_speed := 600.0:
	set(value):
		if _not_negative(value, "warp_speed"):
			warp_speed = value
@export_range(1.0, 10.0, 0.1, "or_greater") var warp_stretch := 4.0:
	set(value):
		var message := "warp_stretch must be at least 1"
		if not Contract.require(value >= 1.0, message):
			return
		warp_stretch = value

var particles: GPUParticles3D

var _process_material: ParticleProcessMaterial
var _mesh: CylinderMesh
var _draw: StandardMaterial3D


func _init() -> void:
	_build()


func _ready() -> void:
	particles.amount = amount
	particles.lifetime = lifetime


func _process(_delta: float) -> void:
	update()


func level() -> float:
	var warp := _warp_intensity()
	if ship.freeze:
		return warp
	var span := max_accel - min_accel
	var thrust := (engine_meter.thrust_acceleration - min_accel) / span
	return maxf(clampf(thrust, 0.0, 1.0), warp)


func update() -> void:
	if not Contract.require(
		ship != null and engine_meter != null and camera_component != null,
		"ship, engine_meter and camera_component must be set",
	):
		return
	var shown := level()
	particles.emitting = shown > 0.0
	particles.amount_ratio = maxf(shown, MIN_AMOUNT_RATIO)
	_draw.albedo_color = Color(colour, max_alpha * shown)
	var velocity := ship.linear_velocity
	var speed := velocity.length()
	var extra := speed * extra_speed
	var stretch := 1.0
	var warp := _warp_intensity()
	if warp > 0.0:
		speed = maxf(speed, MIN_SPEED)
		velocity = -ship.global_basis.z.normalized() * speed
		extra = warp_speed * warp
		stretch = lerpf(1.0, warp_stretch, warp)
	if speed < 0.01:
		return
	var travel := velocity / speed
	var distance := camera_component.distance
	var ahead := (speed + extra) * lifetime * 0.5
	particles.global_position = ship.global_position + travel * ahead
	var half := distance * spread
	_process_material.emission_box_extents = Vector3(half, half, half)
	_process_material.direction = -travel
	_process_material.initial_velocity_min = extra
	_process_material.initial_velocity_max = extra
	_mesh.height = length * distance * (BASE_LENGTH + shown) * stretch


func _warp_intensity() -> float:
	if warp_effect == null or ship.freeze:
		return 0.0
	return warp_effect.intensity()


func _build() -> void:
	particles = GPUParticles3D.new()
	particles.top_level = true
	particles.local_coords = false
	particles.emitting = false
	particles.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Y_TO_VELOCITY
	var corner := Vector3.ONE * -VISIBILITY_HALF
	particles.visibility_aabb = AABB(
		corner,
		Vector3.ONE * VISIBILITY_HALF * 2.0,
	)
	_process_material = ParticleProcessMaterial.new()
	_process_material.emission_shape = (
		ParticleProcessMaterial.EMISSION_SHAPE_BOX
	)
	_process_material.spread = 0.0
	_process_material.gravity = Vector3.ZERO
	_process_material.alpha_curve = _fade_curve()
	particles.process_material = _process_material
	_mesh = CylinderMesh.new()
	_mesh.top_radius = LINE_RADIUS
	_mesh.bottom_radius = LINE_RADIUS
	_mesh.radial_segments = 4
	_mesh.rings = 1
	_draw = StandardMaterial3D.new()
	_draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_draw.vertex_color_use_as_albedo = true
	_draw.albedo_color = Color(colour, 0.0)
	_mesh.material = _draw
	particles.draw_pass_1 = _mesh
	add_child(particles)


func _fade_curve() -> CurveTexture:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.2, 1.0))
	curve.add_point(Vector2(0.8, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture


func _positive(value: float, setting: String) -> bool:
	return Contract.require(value > 0.0, "%s must be positive" % setting)


func _not_negative(value: float, setting: String) -> bool:
	return Contract.require(value >= 0.0, "%s must not be negative" % setting)
