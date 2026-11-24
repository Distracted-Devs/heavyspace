class_name MassText


static func mkg(mass: float) -> String:
	if is_equal_approx(mass, roundf(mass)):
		return "%dMkg" % roundi(mass)
	return "%.1fMkg" % mass
