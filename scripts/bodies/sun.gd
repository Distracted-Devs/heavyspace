class_name Sun
extends Node3D

const SURFACE_ENERGY := &"sun_energy"
const CORONA_INTENSITY := &"intensity"
const CORONA_SHARE := 0.25
const FAR_MARGIN := 0.9

@export_group("Components")
@export var body: MeshInstance3D
@export var corona: MeshInstance3D
@export var light: DirectionalLight3D
@export var fill_light: DirectionalLight3D

@export_group("Sun")
@export var direction := Vector3(0.433, 0.5, 0.75):
	set(value):
		if not Contract.require(
			not value.is_zero_approx(),
			"direction must not be zero",
		):
			return
		direction = value.normalized()
@export_range(1.0, 100000.0, 1.0, "or_greater") var distance := 3200.0:
	set(value):
		if not Contract.require(value > 0.0, "distance must be positive"):
			return
		distance = value
@export_range(1.0, 10000.0, 1.0, "or_greater") var radius := 650.0:
	set(value):
		if not Contract.require(value > 0.0, "radius must be positive"):
			return
		radius = value
@export_range(1.0, 10.0, 0.1, "or_greater") var corona_scale := 3.0:
	set(value):
		var message := "corona_scale must be at least 1"
		if not Contract.require(value >= 1.0, message):
			return
		corona_scale = value
@export_range(0.0, 20.0, 0.1, "or_greater") var light_intensity := 3.0:
	set(value):
		var message := "light_intensity must not be negative"
		if not Contract.require(value >= 0.0, message):
			return
		light_intensity = value
@export_range(0.0, 20.0, 0.1, "or_greater") var surface_energy := 2.5:
	set(value):
		var message := "surface_energy must not be negative"
		if not Contract.require(value >= 0.0, message):
			return
		surface_energy = value
@export_range(0.0, 50.0, 0.1, "or_greater") var glow_intensity := 12.0:
	set(value):
		var message := "glow_intensity must not be negative"
		if not Contract.require(value >= 0.0, message):
			return
		glow_intensity = value
@export_range(0.0, 1.0, 0.01) var shadow_strength := 0.85:
	set(value):
		if not Contract.require(
			value >= 0.0 and value <= 1.0,
			"shadow_strength must be within [0, 1]",
		):
			return
		shadow_strength = value

@export_group("Fill light")
@export_range(0.0, 10.0, 0.05, "or_greater") var fill_intensity := 0.6:
	set(value):
		var message := "fill_intensity must not be negative"
		if not Contract.require(value >= 0.0, message):
			return
		fill_intensity = value
@export var fill_colour := Color(0.55, 0.65, 1.0)
@export_range(0.0, 1.0, 0.01) var fill_side_offset := 0.35:
	set(value):
		if not Contract.require(
			value >= 0.0 and value <= 1.0,
			"fill_side_offset must be within [0, 1]",
		):
			return
		fill_side_offset = value


func _init() -> void:
	process_priority = 1000


func _process(_delta: float) -> void:
	follow(get_viewport().get_camera_3d())


func follow(camera: Camera3D) -> void:
	var origin := Vector3.ZERO
	var reach := distance
	if camera:
		origin = camera.global_position
		reach = minf(distance, horizon_limit(camera))
	global_position = origin + direction * reach
	body.scale = Vector3.ONE * radius
	corona.scale = Vector3.ONE * radius * corona_scale
	light.global_basis = _facing(-direction)
	light.light_energy = light_intensity
	light.shadow_opacity = shadow_strength
	fill_light.global_basis = _facing(-_fill_direction())
	fill_light.light_energy = fill_intensity
	fill_light.light_color = fill_colour
	fill_light.visible = fill_intensity > 0.0
	_set_parameter(body, SURFACE_ENERGY, surface_energy)
	_set_parameter(corona, CORONA_INTENSITY, glow_intensity * CORONA_SHARE)
	Contract.ensure(
		light.global_basis.z.is_equal_approx(direction),
		"sunlight must shine along -direction",
	)


func horizon_limit(camera: Camera3D) -> float:
	return camera.far * FAR_MARGIN - radius * corona_scale * 0.5


func _fill_direction() -> Vector3:
	var side := direction.cross(Vector3.UP)
	if side.length() < 0.01:
		side = direction.cross(Vector3.RIGHT)
	return (-direction).slerp(side.normalized(), fill_side_offset * 0.999)


func _facing(forward: Vector3) -> Basis:
	var up := Vector3.UP
	if absf(forward.normalized().dot(Vector3.UP)) > 0.99:
		up = Vector3.FORWARD
	return Basis.looking_at(forward, up)


func _set_parameter(
	instance: MeshInstance3D,
	parameter: StringName,
	value: float,
) -> void:
	var material := instance.mesh.surface_get_material(0) as ShaderMaterial
	if material:
		material.set_shader_parameter(parameter, value)
