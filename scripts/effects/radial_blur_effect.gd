class_name RadialBlurEffect
extends CanvasLayer

const SHADER := preload("res://resources/shaders/radial_blur.gdshader")
const SHOWN_STRENGTH := 0.002
const SHOWN_ABERRATION := 0.0001

@export_group("Components")
@export var engine_meter: EngineMeterComponent
@export var camera: Camera3D
@export var focus: Node3D
@export var warp_effect: WarpEffect

@export_group("Blur")
@export_range(0.0, 10.0, 0.05, "or_greater") var blur_strength := 2.0:
	set(value):
		if _not_negative(value, "blur_strength"):
			blur_strength = value
@export_range(0.0, 1.0, 0.01) var clear_radius := 0.05:
	set(value):
		if not Contract.require(
			value >= 0.0 and value <= 1.0,
			"clear_radius must be within [0, 1]",
		):
			return
		clear_radius = value
@export_range(0.01, 1.0, 0.01, "or_greater") var falloff := 0.35:
	set(value):
		if _positive(value, "falloff"):
			falloff = value
@export_range(0.0, 1.0, 0.01, "or_greater") var reach := 0.12:
	set(value):
		if _not_negative(value, "reach"):
			reach = value
@export_range(0.1, 30.0, 0.1, "or_greater") var blur_speed := 4.0:
	set(value):
		if _positive(value, "blur_speed"):
			blur_speed = value

@export_group("Warp")
@export_range(0.0, 30.0, 0.1, "or_greater") var warp_blur := 10.0:
	set(value):
		if _not_negative(value, "warp_blur"):
			warp_blur = value
@export_range(0.0, 2.0, 0.01, "or_greater") var warp_aberration := 1.0:
	set(value):
		if _not_negative(value, "warp_aberration"):
			warp_aberration = value

var rect: ColorRect
var strength := 0.0
var aberration := 0.0

var _boost_blur := 0.0
var _shader: ShaderMaterial


func _init() -> void:
	layer = -1
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.visible = false
	_shader = ShaderMaterial.new()
	_shader.shader = SHADER
	rect.material = _shader
	add_child(rect)


func _process(delta: float) -> void:
	update(delta)


func update(delta: float) -> void:
	if not Contract.require(
		engine_meter != null and camera != null and focus != null,
		"engine_meter, camera and focus must be set",
	):
		return
	if not Contract.require(delta >= 0.0, "delta must not be negative"):
		return
	var target := blur_strength * engine_meter.scaled_boost()
	_boost_blur = lerpf(_boost_blur, target, 1.0 - exp(-blur_speed * delta))
	if _boost_blur < SHOWN_STRENGTH * 0.1:
		_boost_blur = 0.0
	var warp := warp_effect.intensity() if warp_effect != null else 0.0
	strength = maxf(_boost_blur, warp_blur * warp)
	aberration = warp_aberration * warp
	rect.visible = strength > SHOWN_STRENGTH or aberration > SHOWN_ABERRATION
	_shader.set_shader_parameter(&"strength", strength)
	_shader.set_shader_parameter(&"aberration", aberration)
	_shader.set_shader_parameter(&"clear_radius", clear_radius)
	_shader.set_shader_parameter(&"falloff", falloff)
	_shader.set_shader_parameter(&"reach", reach)
	var spot := focus.global_position
	if not camera.is_position_behind(spot):
		var screen := camera.get_viewport().get_visible_rect().size
		var centre := camera.unproject_position(spot) / screen
		_shader.set_shader_parameter(&"centre", centre)


func _positive(value: float, setting: String) -> bool:
	return Contract.require(value > 0.0, "%s must be positive" % setting)


func _not_negative(value: float, setting: String) -> bool:
	return Contract.require(value >= 0.0, "%s must not be negative" % setting)
