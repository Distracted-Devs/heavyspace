class_name TitleCamera

const TOLERANCE := 1e-3


static func frame(
	centre: Vector3,
	radius: float,
	angle: float,
	framing: TitleFraming,
	fov: float,
	aspect: float,
) -> Transform3D:
	if not _valid(radius, framing, fov, aspect):
		return Transform3D.IDENTITY
	var elevation := deg_to_rad(framing.elevation_degrees)
	var around := Vector3(
		cos(elevation) * sin(angle),
		sin(elevation),
		cos(elevation) * cos(angle),
	)
	var eye := centre + around * radius * framing.distance_radii
	var look := Transform3D(Basis.IDENTITY, eye).looking_at(centre, Vector3.UP)
	# Turn away from the body so it lands on screen_point, not the middle:
	# on screen x runs left −1 to right 1 and y bottom −1 to top 1.
	var point := framing.screen_point
	var ndc := Vector2(point.x * 2.0 - 1.0, 1.0 - point.y * 2.0)
	var tan_v := tan(deg_to_rad(fov) * 0.5)
	var pitch := atan(ndc.y * tan_v)
	var yaw := atan(ndc.x * tan_v * aspect * cos(pitch))
	var turn := Basis.from_euler(Vector3(-pitch, yaw, 0.0), EULER_ORDER_YXZ)
	var framed := Transform3D(look.basis * turn, eye)
	Contract.ensure(
		_lands_on(framed, centre, point, tan_v, aspect),
		"the body must land on the screen point, in front",
	)
	return framed


static func _lands_on(
	eye: Transform3D,
	centre: Vector3,
	point: Vector2,
	tan_v: float,
	aspect: float,
) -> bool:
	var local := eye.affine_inverse() * centre
	if local.z >= 0.0:
		return false
	var ndc := Vector2(
		local.x / (-local.z * tan_v * aspect),
		local.y / (-local.z * tan_v),
	)
	var spot := Vector2((ndc.x + 1.0) * 0.5, (1.0 - ndc.y) * 0.5)
	return spot.distance_to(point) < TOLERANCE


static func _valid(
	radius: float,
	framing: TitleFraming,
	fov: float,
	aspect: float,
) -> bool:
	return (
		Contract.require(radius > 0.0, "radius must be positive")
		and Contract.require(framing != null, "framing must be set")
		and Contract.require(
			fov > 0.0 and fov < 180.0,
			"fov must be within (0, 180)",
		)
		and Contract.require(aspect > 0.0, "aspect must be positive")
	)
