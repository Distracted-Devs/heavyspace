class_name AbsorbSquash


static func along(
	t: float,
	anticipation: float,
	squash: float,
	stretch: float,
) -> float:
	if not _valid(t, anticipation, squash, stretch):
		return 1.0
	var length := 1.0
	if t < anticipation:
		length = 1.0 - squash * sin(PI * t / anticipation)
	else:
		var u := (t - anticipation) / (1.0 - anticipation)
		length = 1.0 + stretch * u * u
	Contract.ensure(length > 0.0, "the length along the pull must be positive")
	return length


static func _valid(
	t: float,
	anticipation: float,
	squash: float,
	stretch: float,
) -> bool:
	return (
		Contract.require(t >= 0.0 and t <= 1.0, "t must be within [0, 1]")
		and Contract.require(
			anticipation >= 0.0 and anticipation < 1.0,
			"anticipation must be within [0, 1)",
		)
		and Contract.require(
			squash >= 0.0 and squash < 1.0,
			"squash must be within [0, 1)",
		)
		and Contract.require(stretch >= 0.0, "stretch must not be negative")
	)
