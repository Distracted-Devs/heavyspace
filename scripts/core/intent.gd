class_name Intent


static func is_within_unit(intent: Vector3) -> bool:
	var magnitudes := intent.abs()
	return magnitudes.x <= 1.0 and magnitudes.y <= 1.0 and magnitudes.z <= 1.0
