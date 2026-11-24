extends "res://scripts/generation/hierarchy_streamer.gd"

## Prototype streamer: the same as production, but the tiers at
## `jitter_depths` place each body anywhere in its cell that keeps the whole
## body inside the cell (cell size minus its diameter), so neighbours can't
## overlap and the grid disappears.

## 0 = every body centred in its cell (a perfect grid); 1 = it may wander as
## far as its cell allows.
var jitter := 1.0
## Depth 1 is the ring around each planet (the rings tier).
var jitter_depths := PackedInt32Array([1])
## Proxy sphere segments. 64 matches the live bodies' unit sphere exactly,
## so the vertex-raised terrain doesn't change shape when a body goes live
## (production: 12).
var proxy_segments := 64
## Seconds a newly streamed-in ring of bodies takes to grow to full size.
var grow_in_time := 0.6
## Godot ease() curve for the grow: > 1 eases in, < 1 eases out.
var grow_in_ease := 2.0

## [renderer, seconds since it streamed in]
var _growing: Array = []


func _process(delta: float) -> void:
	for slot in range(_growing.size() - 1, -1, -1):
		var entry: Array = _growing[slot]
		var renderer: OrbitRenderer = entry[0]
		if not is_instance_valid(renderer) or renderer.is_queued_for_deletion():
			_growing.remove_at(slot)
			continue
		entry[1] += delta
		var t := minf(entry[1] / grow_in_time, 1.0)
		_show_grown(renderer, ease(t, grow_in_ease))
		if t >= 1.0:
			_growing.remove_at(slot)


## Draws every instance at `amount` of its size. Only the instance scale
## changes: the proxy shader divides its orbit offset by that scale, so the
## bodies grow in place, and child_positions() is untouched.
func _show_grown(renderer: OrbitRenderer, amount: float) -> void:
	if renderer.count() == 0:
		return
	if amount >= 1.0:
		renderer.multimesh.buffer = renderer._buffer
		return
	var buffer: PackedFloat32Array = renderer._buffer.duplicate()
	var scale_by := maxf(amount, 0.001)
	for index in renderer.count():
		var slot := index * OrbitRenderer.FLOATS_PER_INSTANCE
		buffer[slot] *= scale_by
		buffer[slot + 5] *= scale_by
		buffer[slot + 10] *= scale_by
	renderer.multimesh.buffer = buffer


func _add_slot(
	path: PackedInt32Array,
	parent_slot: int,
	child_index: int,
	radius: float,
) -> int:
	var depth := path.size()
	var tier := _tier_for(depth, path, radius)
	var layout: TierLayout
	if depth in jitter_depths:
		layout = _generate_jittered(path, radius, tier, _focus_mass_now())
	else:
		layout = TierGenerator.generate(
			resolved_seed,
			path,
			radius,
			tier,
			_focus_mass_now(),
		)
	var renderer := OrbitRenderer.new()
	renderer.name = "Children%s" % _key(path)
	renderer.proxy_segments = proxy_segments
	add_child(renderer)
	renderer.show_layout(layout)
	if grow_in_time > 0.0:
		_growing.append([renderer, 0.0])
		_show_grown(renderer, 0.0)
	var slot := _renderers.size()
	_paths.append(path)
	_depths.append(depth)
	_parent_slots.append(parent_slot)
	_child_indices.append(child_index)
	_layouts.append(layout)
	_slot_tiers.append(tier)
	_renderers.append(renderer)
	_slot_of[_key(path)] = slot
	expanded.emit(path, renderer)
	return slot


func _generate_jittered(
	path: PackedInt32Array,
	parent_radius: float,
	tier: Tier,
	focus_mass: float,
) -> TierLayout:
	var layout := TierLayout.new()
	if not tier.require_valid(parent_radius):
		return layout
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([resolved_seed, path])
	layout.plane = TierGenerator._random_plane(rng, tier.plane_tilt_max_degrees)

	var inner := tier.orbit_inner * parent_radius
	var outer := tier.orbit_outer * parent_radius
	var cell := tier.cell_size
	var spawn_chance := tier.cell_spawn_chance()
	var across := tier.cells_across(parent_radius)
	for row in across:
		for column in across:
			if rng.randf() >= spawn_chance:
				continue
			# The radius comes first, so the body's own size sets how far it
			# may move: body + jitter always stays inside the cell.
			var radius := lerpf(
				tier.radius_min,
				tier.radius_max,
				pow(rng.randf(), tier.size_bias),
			)
			var room := maxf(cell - 2.0 * radius, 0.0)
			var x := (
				-outer + column * cell + radius
				+ room * (0.5 + (rng.randf() - 0.5) * jitter)
			)
			var z := (
				-outer + row * cell + radius
				+ room * (0.5 + (rng.randf() - 0.5) * jitter)
			)
			var orbit := Vector2(x, z).length()
			if orbit < inner or orbit > outer:
				continue
			layout.append(
				radius,
				TierGenerator._mass_of(radius, tier, focus_mass),
				orbit,
				rng.randf_range(-tier.thickness, tier.thickness),
				TierGenerator._phase_of(x, z),
				TierGenerator._angular_speed(rng, tier, inner, orbit),
			)
	return layout
