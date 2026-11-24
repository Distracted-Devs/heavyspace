extends "res://scripts/generation/live_body_pool.gd"

## Prototype pool: the same as production, but a promoted body's mesh is
## turned to its ring's frame. The proxy draws the surface in the ring's
## (randomly tilted) frame while the live body was world-aligned, so the
## whole surface pattern used to jump round at live_distance.

var match_proxy_orientation := true


func _promote(renderer: OrbitRenderer, index: int, centre: Vector3) -> void:
	super(renderer, index, centre)
	if not match_proxy_orientation:
		return
	var body := _bodies[_bodies.size() - 1]
	var turn := renderer.global_basis.orthonormalized()
	body.mesh.basis = turn * Basis.from_scale(body.mesh.scale)
