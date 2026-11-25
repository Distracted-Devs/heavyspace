extends GutTest

const LAYOUT := preload("res://resources/ui/keyboard_layout.tres")
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


func test_keys_sit_in_their_rows() -> void:
	var q: Rect2 = LAYOUT.rect_of(KEY_Q)
	var w: Rect2 = LAYOUT.rect_of(KEY_W)
	var a: Rect2 = LAYOUT.rect_of(KEY_A)
	var space: Rect2 = LAYOUT.rect_of(KEY_SPACE)
	assert_almost_eq(q.position.y, w.position.y, 1.0e-4)
	assert_gt(w.position.x, q.position.x)
	assert_gt(a.position.y, w.position.y)
	assert_gt(space.position.y, a.position.y)
	assert_gt(space.size.x, 4.0 * w.size.x)


func test_shift_uses_the_left_key() -> void:
	assert_lt(LAYOUT.rect_of(KEY_SHIFT).position.x, 0.1)


func test_keys_off_the_picture_have_no_rect() -> void:
	assert_false(LAYOUT.has_key(KEY_ESCAPE))
	assert_eq(LAYOUT.rect_of(KEY_ESCAPE), Rect2())


func test_drawn_keys_never_overlap() -> void:
	for first in LAYOUT.key_codes.size():
		for second in range(first + 1, LAYOUT.key_codes.size()):
			if LAYOUT.key_codes[first] == LAYOUT.key_codes[second]:
				continue
			var a := _rect(first)
			var b := _rect(second)
			assert_false(
				a.grow(-1.0e-3).intersects(b),
				"%d and %d" % [first, second],
			)


func _rect(index: int) -> Rect2:
	var rect: Vector4 = LAYOUT.key_rects[index]
	return Rect2(rect.x, rect.y, rect.z, rect.w)


func test_bound_keys_get_their_actions_caption() -> void:
	var captions: Dictionary = LAYOUT.captions(LABELS)
	var row: int = LABELS.index_of(&"pitch_down")
	assert_eq(Array(captions.get(KEY_W)), [LABELS.short_labels[row]])
	for key in [KEY_S, KEY_A, KEY_E, KEY_SHIFT, KEY_SPACE]:
		assert_eq(Array(captions.get(key, [])).size(), 1, str(key))
	assert_false(captions.has(KEY_R), "restart is a crash-only prompt")
	assert_false(captions.has(KEY_ESCAPE))


func test_bindings_off_the_picture_are_extras() -> void:
	var pause: String = LABELS.labels[LABELS.index_of(&"pause")]
	assert_eq(
		LAYOUT.extras(LABELS, ICON_SET),
		[["esc", pause], ["mouse_xy", LABELS.keyboard_extra_labels[0]]],
	)
