@tool
class_name PixelateEffect
extends CompositorEffect

const CONTEXT := &"pixelate_effect"
const SOURCE := &"source"

@export_range(1, 32, 1) var pixel_size: int = 8
## Pixelate before transparent objects are drawn, so they stay crisp on top
## (used by the minimap so its lines and markers aren't pixelated).
@export var before_transparent: bool = false:
	set(value):
		before_transparent = value
		effect_callback_type = _callback_type()

var _rd: RenderingDevice
var _shader: RID
var _pipeline: RID
var _sampler: RID


func _init() -> void:
	effect_callback_type = _callback_type()
	RenderingServer.call_on_render_thread(_initialize_compute)


func _callback_type() -> EffectCallbackType:
	if before_transparent:
		return EFFECT_CALLBACK_TYPE_POST_OPAQUE
	return EFFECT_CALLBACK_TYPE_POST_TRANSPARENT


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _rd:
		if _sampler.is_valid():
			_rd.free_rid(_sampler)
		if _shader.is_valid():
			_rd.free_rid(_shader)


func _initialize_compute() -> void:
	_rd = RenderingServer.get_rendering_device()
	if not _rd:
		return

	var shader_file: RDShaderFile = load("res://resources/shaders/pixelate_world.glsl")
	_shader = _rd.shader_create_from_spirv(shader_file.get_spirv())
	if not _shader.is_valid():
		return
	_pipeline = _rd.compute_pipeline_create(_shader)

	var sampler_state := RDSamplerState.new()
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	_sampler = _rd.sampler_create(sampler_state)


func _render_callback(callback_type: int, render_data: RenderData) -> void:
	if not _rd or callback_type != _callback_type() or not _pipeline.is_valid():
		return
	if pixel_size <= 1:
		return

	var buffers := render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	if not buffers:
		return

	var size := buffers.get_internal_size()
	if size.x == 0 or size.y == 0:
		return

	var view_count := buffers.get_view_count()
	if not buffers.has_texture(CONTEXT, SOURCE):
		var usage := RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
		buffers.create_texture(CONTEXT, SOURCE, RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT, usage, RenderingDevice.TEXTURE_SAMPLES_1, size, view_count, 1, true, false)

	var copy_bytes := PackedFloat32Array([size.x, size.y, float(pixel_size), 1.0]).to_byte_array()
	var pixelate_bytes := PackedFloat32Array([size.x, size.y, float(pixel_size), 0.0]).to_byte_array()
	var groups := Vector3i((size.x - 1) / 8 + 1, (size.y - 1) / 8 + 1, 1)

	for view in view_count:
		var color := buffers.get_color_layer(view)
		var depth := buffers.get_depth_layer(view)
		var source := buffers.get_texture_slice(CONTEXT, SOURCE, view, 0, 1, 1)

		var color_uniform := RDUniform.new()
		color_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		color_uniform.binding = 0
		color_uniform.add_id(color)

		var depth_uniform := RDUniform.new()
		depth_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		depth_uniform.binding = 1
		depth_uniform.add_id(_sampler)
		depth_uniform.add_id(depth)

		var source_uniform := RDUniform.new()
		source_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		source_uniform.binding = 2
		source_uniform.add_id(source)

		var uniform_set := UniformSetCacheRD.get_cache(_shader, 0, [color_uniform, depth_uniform, source_uniform])

		var compute_list := _rd.compute_list_begin()
		_rd.compute_list_bind_compute_pipeline(compute_list, _pipeline)
		_rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
		_rd.compute_list_set_push_constant(compute_list, copy_bytes, copy_bytes.size())
		_rd.compute_list_dispatch(compute_list, groups.x, groups.y, groups.z)
		_rd.compute_list_add_barrier(compute_list)
		_rd.compute_list_set_push_constant(compute_list, pixelate_bytes, pixelate_bytes.size())
		_rd.compute_list_dispatch(compute_list, groups.x, groups.y, groups.z)
		_rd.compute_list_end()
