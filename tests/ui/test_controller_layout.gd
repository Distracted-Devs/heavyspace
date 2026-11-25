extends GutTest

const LAYOUT := preload("res://resources/ui/controller_layout.tres")
const LABELS := preload("res://resources/ui/control_labels.tres")
const ICON_SET := preload("res://resources/ui/input_icon_set.tres")

var _was_enabled: bool


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true


func after_each() -> void:
	Contract.enabled = _was_enabled


func test_the_games_layout_is_valid() -> void:
	assert_true(LAYOUT.require_valid())
	assert_eq(LAYOUT.slot_names.size(), 16)


func _label(action: StringName) -> String:
	return LABELS.labels[LABELS.index_of(action)]


func _axis(action: StringName) -> String:
	return LABELS.axis_labels[LABELS.index_of(action)]


func test_every_bound_control_is_at_its_slot() -> void:
	var entries: Dictionary = LAYOUT.entries(LABELS, ICON_SET)
	assert_eq(entries.get("rt"), [["rt", _label(&"back_thruster")]])
	assert_eq(entries.get("lb"), [["lb", _label(&"roll_left")]])
	assert_eq(entries.get("rb"), [["rb", _label(&"roll_right")]])
	assert_eq(entries.get("x"), [["x_color", _label(&"warp_out")]])
	assert_false(entries.has("view"), "Select is unbound")
	assert_eq(entries.get("menu"), [["menu", _label(&"pause")]])


func test_a_sticks_axes_are_grouped_by_axis_label() -> void:
	var entries: Dictionary = LAYOUT.entries(LABELS, ICON_SET)
	assert_eq(
		entries.get("ls"),
		[["l_y", _axis(&"pitch_down")], ["l_x", _axis(&"turn_left")]],
	)
	assert_eq(entries.get("rs"), [["r_2d", _axis(&"look_up")]])


func test_unbound_slots_have_no_entries() -> void:
	var entries: Dictionary = LAYOUT.entries(LABELS, ICON_SET)
	for slot in ["lt", "dpad_up", "dpad_down", "dpad_left", "dpad_right"]:
		assert_false(entries.has(slot), slot)
	for slot in ["y", "b", "a"]:
		assert_false(entries.has(slot), slot)


func test_unused_lines_are_the_lines_of_every_other_slot() -> void:
	var entries: Dictionary = LAYOUT.entries(LABELS, ICON_SET)
	var unused: PackedStringArray = LAYOUT.unused_lines(entries.keys())
	var lt: int = LAYOUT.slot_names.find("lt")
	var rt: int = LAYOUT.slot_names.find("rt")
	for id in LAYOUT.slot_lines[lt]:
		assert_has(unused, id)
	for id in LAYOUT.slot_lines[rt]:
		assert_does_not_have(unused, id)


func test_every_line_id_is_in_the_picture() -> void:
	var svg := FileAccess.get_file_as_string(LAYOUT.picture)
	for lines: PackedStringArray in LAYOUT.slot_lines:
		for id in lines:
			assert_string_contains(svg, 'id="%s"' % id)


func test_mismatched_slots_are_reported() -> void:
	var layout := ControllerLayout.new()
	layout.slot_names = ["lt"]
	assert_false(layout.require_valid())
	assert_push_error(
		"[Contract] Pre-condition broken: "
		+ "every slot needs a side, a height and lines"
	)
