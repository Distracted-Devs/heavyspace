class_name OrbitRenderer
extends MultiMeshInstance3D

const SHADER := preload("res://resources/shaders/orbit.gdshader")
const UNTINTED := Color.WHITE
const FLOATS_PER_INSTANCE := 20
const COLOUR_OFFSET := 12
const CUSTOM_OFFSET := 16

@export_group("Look")
@export var albedo_texture: Texture2D = preload(
	"res://resources/textures/earth.jpg"
)
@export_range(4, 64, 1) var proxy_segments := 12

var layout: TierLayout:
	get:
		return _layout

var _layout := TierLayout.new()
var _buffer := PackedFloat32Array()


func _init() -> void:
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true


func _ready() -> void:
	multimesh.mesh = _proxy_mesh()


func count() -> int:
	return _layout.size()


func show_layout(children: TierLayout) -> void:
	if not Contract.require(children != null, "layout must not be null"):
		return
	_layout = children
	basis = children.plane
	_buffer = _build_buffer(children)
	multimesh.instance_count = children.size()
	if children.size() > 0:
		multimesh.buffer = _buffer
	multimesh.custom_aabb = _ring_bounds(children)
	Contract.ensure(
		(
			multimesh.instance_count == children.size()
			and _buffer.size() == children.size() * FLOATS_PER_INSTANCE
			and basis.is_equal_approx(children.plane)
		),
		"renderer must hold one visible instance per child",
	)


func set_hidden(index: int, hidden: bool) -> void:
	if not _require_index(index):
		return
	_buffer[_colour_slot(index) + 3] = 0.0 if hidden else 1.0
	_upload_colour(index)


func is_hidden(index: int) -> bool:
	if not _require_index(index):
		return false
	return _buffer[_colour_slot(index) + 3] < 0.5


func set_tint(index: int, colour: Color) -> void:
	if not _require_index(index):
		return
	var slot := _colour_slot(index)
	_buffer[slot] = colour.r
	_buffer[slot + 1] = colour.g
	_buffer[slot + 2] = colour.b
	_upload_colour(index)


func tint(index: int) -> Color:
	if not _require_index(index):
		return UNTINTED
	var slot := _colour_slot(index)
	return Color(_buffer[slot], _buffer[slot + 1], _buffer[slot + 2])


func instance_radius(index: int) -> float:
	if not _require_index(index):
		return 0.0
	return _buffer[index * FLOATS_PER_INSTANCE]


func instance_orbit(index: int) -> Vector4:
	if not _require_index(index):
		return Vector4.ZERO
	var slot := index * FLOATS_PER_INSTANCE + CUSTOM_OFFSET
	return Vector4(
		_buffer[slot],
		_buffer[slot + 1],
		_buffer[slot + 2],
		_buffer[slot + 3],
	)


func child_position(index: int, time: float) -> Vector3:
	if not _require_index(index):
		return global_position
	var local := Orbit.position(
		_layout.orbit_radius[index],
		_layout.height[index],
		_layout.phase[index],
		_layout.angular_speed[index],
		time,
	)
	return global_transform * local


func child_velocity(index: int, time: float) -> Vector3:
	if not _require_index(index):
		return Vector3.ZERO
	var local := Orbit.velocity(
		_layout.orbit_radius[index],
		_layout.height[index],
		_layout.phase[index],
		_layout.angular_speed[index],
		time,
	)
	return global_basis * local


func _build_buffer(children: TierLayout) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(children.size() * FLOATS_PER_INSTANCE)
	for index in children.size():
		var slot := index * FLOATS_PER_INSTANCE
		var radius := children.radius[index]
		# A 3x4 transform, row by row, holding only the scale.
		buffer[slot] = radius
		buffer[slot + 5] = radius
		buffer[slot + 10] = radius
		for channel in 4:
			buffer[slot + COLOUR_OFFSET + channel] = 1.0
		buffer[slot + CUSTOM_OFFSET] = children.orbit_radius[index]
		buffer[slot + CUSTOM_OFFSET + 1] = children.height[index]
		buffer[slot + CUSTOM_OFFSET + 2] = children.phase[index]
		buffer[slot + CUSTOM_OFFSET + 3] = children.angular_speed[index]
	return buffer


func _ring_bounds(children: TierLayout) -> AABB:
	var reach := 0.0
	var rise := 0.0
	for index in children.size():
		var radius := children.radius[index]
		reach = maxf(reach, children.orbit_radius[index] + radius)
		rise = maxf(rise, absf(children.height[index]) + radius)
	var extent := Vector3(reach, rise, reach)
	return AABB(-extent, extent * 2.0)


func _proxy_mesh() -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = proxy_segments
	mesh.rings = maxi(floori(proxy_segments * 0.5), 2)
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("albedo_texture", albedo_texture)
	mesh.material = material
	return mesh


func _colour_slot(index: int) -> int:
	return index * FLOATS_PER_INSTANCE + COLOUR_OFFSET


func _upload_colour(index: int) -> void:
	var slot := _colour_slot(index)
	multimesh.set_instance_color(
		index,
		Color(
			_buffer[slot],
			_buffer[slot + 1],
			_buffer[slot + 2],
			_buffer[slot + 3],
		),
	)


func _require_index(index: int) -> bool:
	return Contract.require(
		index >= 0 and index < count(),
		"index must be within the drawn children",
	)
