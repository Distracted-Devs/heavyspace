class_name FakeBody


static func make() -> RigidBody3D:
	var body := RigidBody3D.new()
	body.gravity_scale = 0.0
	body.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	body.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.5
	collider.shape = shape
	body.add_child(collider)
	return body
