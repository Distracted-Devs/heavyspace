extends Node

# Times the parts of one ring expanding: TierGenerator.generate, then
# OrbitRenderer.show_layout, then the first child_positions. Loaded by
# expand.gd. Keys: contracts=1|0, repeats=200, rings.<field>=value.
# Prints one line, "RESULT {json}", in ms.

var done := false

var _args := { }


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		_args[parts[0]] = parts[1] if parts.size() > 1 else "1"
	Contract.enabled = _args.get("contracts", "1") == "1"
	var tier: Tier = load("res://resources/generation/rings_tier.tres")
	tier = tier.duplicate()
	for key: String in _args:
		if key.begins_with("rings."):
			tier.set(key.trim_prefix("rings."), float(_args[key]))
	var repeats := int(_args.get("repeats", "200"))
	var generate_ms := PackedFloat64Array()
	var show_ms := PackedFloat64Array()
	var positions_ms := PackedFloat64Array()
	var count := 0
	for repeat in repeats:
		var path := PackedInt32Array([repeat])
		var start := Time.get_ticks_usec()
		var layout := TierGenerator.generate(12345, path, 50.0, tier, 1.0)
		var generated := Time.get_ticks_usec()
		var renderer := OrbitRenderer.new()
		add_child(renderer)
		renderer.show_layout(layout)
		var shown := Time.get_ticks_usec()
		renderer.child_positions(1.0)
		var end := Time.get_ticks_usec()
		renderer.free()
		count = layout.size()
		generate_ms.append((generated - start) / 1000.0)
		show_ms.append((shown - generated) / 1000.0)
		positions_ms.append((end - shown) / 1000.0)
	var result := {
		"args": _args,
		"count": count,
		"generate": _mean(generate_ms),
		"show_layout": _mean(show_ms),
		"child_positions": _mean(positions_ms),
	}
	print("RESULT ", JSON.stringify(result))
	done = true


func _mean(samples: PackedFloat64Array) -> float:
	var total := 0.0
	for sample in samples:
		total += sample
	return total / samples.size()
