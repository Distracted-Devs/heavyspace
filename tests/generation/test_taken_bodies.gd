extends GutTest


func test_new_result_holds_no_bodies_and_no_drawn_mass() -> void:
	var taken := TakenBodies.new()
	assert_true(taken.bodies.is_empty())
	assert_eq(taken.drawn_mass, 0.0)


func test_results_do_not_share_their_body_list() -> void:
	var first := TakenBodies.new()
	var second := TakenBodies.new()
	var body: MassBody = add_child_autofree(
		preload("res://scenes/bodies/mass_body.tscn").instantiate()
	)
	first.bodies.append(body)
	assert_true(second.bodies.is_empty())
