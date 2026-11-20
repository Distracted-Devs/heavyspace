class_name MassLaw
extends Resource

@export var density := 2.0 ** 1.5:
	set(value):
		if not Contract.require(value > 0.0, "density must be positive"):
			return
		density = value
@export var exponent := 1.5:
	set(value):
		if not Contract.require(value > 0.0, "exponent must be positive"):
			return
		exponent = value


func mass_for_radius(radius: float) -> float:
	if not Contract.require(radius > 0.0, "radius must be positive"):
		return NAN
	return density * radius ** exponent


func radius_for_mass(mass: float) -> float:
	if not Contract.require(mass > 0.0, "mass must be positive"):
		return NAN
	return (mass / density) ** (1.0 / exponent)
