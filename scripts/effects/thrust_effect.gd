class_name ThrustEffect
extends Node

@export_group("Components")
@export var engine_meter: EngineMeterComponent
@export var particles: GPUParticles3D
@export var warp_effect: WarpEffect

@export_group("Spool")
@export_range(0.0, 1.0, 0.01) var idle_level := 0.0:
	set(value):
		if not Contract.require(
			value >= 0.0 and value <= 1.0,
			"idle_level must be within [0, 1]",
		):
			return
		idle_level = value
@export_range(0.1, 30.0, 0.1, "or_greater") var spool_up := 6.0:
	set(value):
		if not Contract.require(value > 0.0, "spool_up must be positive"):
			return
		spool_up = value
@export_range(0.1, 30.0, 0.1, "or_greater") var spool_down := 3.0:
	set(value):
		if not Contract.require(value > 0.0, "spool_down must be positive"):
			return
		spool_down = value
@export_range(0.0, 1.0, 0.01) var idle_amount := 0.05:
	set(value):
		if not Contract.require(
			value >= 0.0 and value <= 1.0,
			"idle_amount must be within [0, 1]",
		):
			return
		idle_amount = value
@export_range(0.0, 5.0, 0.01, "or_greater") var idle_velocity := 0.3:
	set(value):
		if _not_negative(value, "idle_velocity"):
			idle_velocity = value
@export_range(0.0, 5.0, 0.01, "or_greater") var boost_velocity := 1.3:
	set(value):
		if _not_negative(value, "boost_velocity"):
			boost_velocity = value
@export_range(0.0, 5.0, 0.01, "or_greater") var idle_scale := 0.5:
	set(value):
		if _not_negative(value, "idle_scale"):
			idle_scale = value
@export_range(0.0, 5.0, 0.01, "or_greater") var boost_scale := 1.2:
	set(value):
		if _not_negative(value, "boost_scale"):
			boost_scale = value

var engine_level := 0.0

var _material: ParticleProcessMaterial
var _base_velocity := Vector2.ZERO
var _base_scale := Vector2.ZERO


func _ready() -> void:
	if particles == null:
		return
	var source := particles.process_material as ParticleProcessMaterial
	if source == null:
		return
	_material = source.duplicate()
	particles.process_material = _material
	_base_velocity = Vector2(
		_material.initial_velocity_min,
		_material.initial_velocity_max,
	)
	_base_scale = Vector2(_material.scale_min, _material.scale_max)


func _process(delta: float) -> void:
	update(delta)


func update(delta: float) -> void:
	if not Contract.require(
		engine_meter != null and particles != null,
		"engine_meter and particles must be set",
	):
		return
	if not Contract.require(delta >= 0.0, "delta must not be negative"):
		return
	var target := maxf(idle_level, engine_meter.scaled_boost())
	var rate := spool_up if target > engine_level else spool_down
	engine_level = lerpf(engine_level, target, 1.0 - exp(-rate * delta))
	var warping := warp_effect != null and warp_effect.playing
	particles.emitting = not engine_meter.body.freeze and not warping
	var level := clampf(engine_level, 0.0, 1.0)
	particles.amount_ratio = lerpf(idle_amount, 1.0, level)
	if _material != null:
		var velocity := _base_velocity * lerpf(
			idle_velocity,
			boost_velocity,
			engine_level,
		)
		_material.initial_velocity_min = velocity.x
		_material.initial_velocity_max = velocity.y
		var size := _base_scale * lerpf(idle_scale, boost_scale, level)
		_material.scale_min = size.x
		_material.scale_max = size.y
	var most := engine_meter.max_strength + 1e-4
	Contract.invariant(
		engine_level >= 0.0 and engine_level <= most,
		"engine_level must be within [0, max_strength]",
	)


func _not_negative(value: float, setting: String) -> bool:
	return Contract.require(value >= 0.0, "%s must not be negative" % setting)
