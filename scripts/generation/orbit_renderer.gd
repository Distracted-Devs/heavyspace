class_name OrbitRenderer
extends MultiMeshInstance3D

const UNTINTED := Color.WHITE
const FLOATS_PER_INSTANCE := 20
const COLOUR_OFFSET := 12
const CUSTOM_OFFSET := 16
const MIN_DISPLAY_SCALE := 0.001

@export_group("Look")
@export var proxy_material: Material = preload(
	"res://resources/materials/planet_proxy.tres"
)
@export_range(4, 128, 1) var proxy_segments := 64

var layout: TierLayout:
	get:
		return _layout

var display_scale := 1.0:
	set(value):
		if not Contract.require(
			is_finite(value) and value >= 0.0,
			"display_scale must be finite and not negative",
		):
			return
		display_scale = value
		_upload_transforms()

var _layout := TierLayout.new()
var _buffer := PackedFloat32Array()
var _drawn := PackedFloat32Array()
var _reach := 0.0
var _positions := PackedVector3Array()
var _positions_time := NAN
var _positions_transform := Transform3D()


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
	_upload_transforms()
	multimesh.custom_aabb = _ring_bounds(children)
	_reach = _furthest_reach(children)
	_positions_time = NAN
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


func drawn_radius(index: int) -> float:
	if not _require_index(index):
		return 0.0
	if display_scale == 1.0:
		return _buffer[index * FLOATS_PER_INSTANCE]
	return _drawn[index * FLOATS_PER_INSTANCE]


func _upload_transforms() -> void:
	if count() == 0:
		return
	if display_scale == 1.0:
		multimesh.buffer = _buffer
		return
	var share := maxf(display_scale, MIN_DISPLAY_SCALE)
	_drawn = _buffer.duplicate()
	for index in count():
		var slot := index * FLOATS_PER_INSTANCE
		_drawn[slot] *= share
		_drawn[slot + 5] *= share
		_drawn[slot + 10] *= share
	multimesh.buffer = _drawn


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


func reach() -> float:
	return _reach


func child_positions(time: float) -> PackedVector3Array:
	var xform := global_transform
	if time == _positions_time and xform == _positions_transform:
		return _positions
	var orbit := _layout.orbit_radius
	var height := _layout.height
	var phase := _layout.phase
	var speed := _layout.angular_speed
	var child_count := _layout.size()
	_positions.resize(child_count)
	for index in child_count:
		var angle := phase[index] + speed[index] * time
		_positions[index] = xform * Vector3(
			cos(angle) * orbit[index],
			height[index],
			sin(angle) * orbit[index],
		)
	_positions_time = time
	_positions_transform = xform
	return _positions


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


func _furthest_reach(children: TierLayout) -> float:
	var furthest := 0.0
	for index in children.size():
		var offset := Vector2(
			children.orbit_radius[index],
			children.height[index],
		)
		furthest = maxf(furthest, offset.length() + children.radius[index])
	return furthest


func _ring_bounds(children: TierLayout) -> AABB:
	var outward := 0.0
	var rise := 0.0
	for index in children.size():
		var radius := children.radius[index]
		outward = maxf(outward, children.orbit_radius[index] + radius)
		rise = maxf(rise, absf(children.height[index]) + radius)
	var extent := Vector3(outward, rise, outward)
	return AABB(-extent, extent * 2.0)


func _proxy_mesh() -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = proxy_segments
	mesh.rings = maxi(floori(proxy_segments * 0.5), 2)
	Contract.require(proxy_material != null, "proxy_material must be set")
	mesh.material = proxy_material
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
