extends GutTest

const PARENT_RADIUS := 50.0
const GROW_TIME := 0.6
const EASE_CURVE := 2.0

var _was_enabled: bool
var _streamer: HierarchyStreamer
var _effect: GrowInEffect
var _renderer: OrbitRenderer


func before_each() -> void:
	_was_enabled = Contract.enabled
	Contract.enabled = true
	_streamer = autofree(HierarchyStreamer.new())
	_effect = GrowInEffect.new()
	_effect.streamer = _streamer
	_effect.grow_time = GROW_TIME
	_effect.ease_curve = EASE_CURVE
	_effect.set_process(false)
	add_child_autofree(_effect)
	_renderer = add_child_autofree(OrbitRenderer.new())
	_renderer.show_layout(
		TierGenerator.generate(
			1,
			PackedInt32Array([0]),
			PARENT_RADIUS,
			Tier.new(),
		)
	)


func after_each() -> void:
	Contract.enabled = _was_enabled


func _expand() -> void:
	_streamer.expanded.emit(PackedInt32Array([0]), _renderer)


func test_new_renderer_starts_at_nothing() -> void:
	_expand()
	assert_eq(_renderer.display_scale, 0.0)
	assert_eq(_effect.growing_count(), 1)


func test_grow_follows_the_ease_curve() -> void:
	_expand()
	_effect.advance(GROW_TIME * 0.5)
	assert_almost_eq(_renderer.display_scale, ease(0.5, EASE_CURVE), 1.0e-6)


func test_grow_ends_at_exactly_full_size_and_stops() -> void:
	_expand()
	_effect.advance(GROW_TIME * 0.7)
	_effect.advance(GROW_TIME * 0.7)
	assert_eq(_renderer.display_scale, 1.0)
	assert_eq(_effect.growing_count(), 0)


func test_no_grow_time_leaves_new_renderers_full_size() -> void:
	_effect.grow_time = 0.0
	_expand()
	assert_eq(_renderer.display_scale, 1.0)
	assert_eq(_effect.growing_count(), 0)


func test_collapsed_renderer_is_dropped() -> void:
	_expand()
	_streamer.collapsing.emit(PackedInt32Array([0]), _renderer)
	assert_eq(_effect.growing_count(), 0)
	_effect.advance(GROW_TIME)
	assert_eq(_renderer.display_scale, 0.0)


func test_each_renderer_grows_on_its_own_clock() -> void:
	_expand()
	_effect.advance(GROW_TIME * 0.5)
	var later: OrbitRenderer = add_child_autofree(OrbitRenderer.new())
	later.show_layout(_renderer.layout)
	_streamer.expanded.emit(PackedInt32Array([1]), later)
	_effect.advance(GROW_TIME * 0.5)
	assert_eq(_renderer.display_scale, 1.0)
	assert_almost_eq(later.display_scale, ease(0.5, EASE_CURVE), 1.0e-6)


func test_negative_grow_time_is_reported_and_ignored() -> void:
	_effect.grow_time = -1.0
	assert_push_error(
		"[Contract] Pre-condition broken: grow_time must not be negative"
	)
	assert_eq(_effect.grow_time, GROW_TIME)


func test_non_positive_ease_curve_is_reported_and_ignored() -> void:
	_effect.ease_curve = 0.0
	assert_push_error(
		"[Contract] Pre-condition broken: ease_curve must be positive"
	)
	assert_eq(_effect.ease_curve, EASE_CURVE)


func test_missing_streamer_is_reported() -> void:
	var effect := GrowInEffect.new()
	add_child_autofree(effect)
	assert_push_error("[Contract] Pre-condition broken: streamer must be set")
