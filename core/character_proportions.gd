class_name CharacterProportions
extends Resource
## Doc 01 §3.4. Geometry derives from height and head ratio at 1x reference scale.

@export var display_name: String = "NPC"
@export var height: float = 258.0
@export_range(0.20, 0.40) var head_ratio: float = 0.32
@export var arm_width: float = 13.0
@export var leg_width: float = 16.0
@export var torso_scale: float = 1.0
## Fraction of upper arm hidden by clothing (Mabel's sweater uses 0.4).
@export_range(0.0, 0.8) var sleeve_occlusion: float = 0.0

var head_diameter: float:
	get:
		return height * head_ratio


func segment(name: StringName) -> Vector2:
	## Returns Vector2(length, width) for a named segment.
	match name:
		&"torso":
			return Vector2(height * 0.26, head_diameter * 0.62 * torso_scale)
		&"arm_upper":
			return Vector2(height * 0.19 * (1.0 - sleeve_occlusion), arm_width)
		&"arm_fore":
			return Vector2(height * 0.17, arm_width * 0.92)
		&"hand":
			return Vector2(height * 0.055, arm_width * 1.5)
		&"leg_upper":
			return Vector2(height * 0.20, leg_width)
		&"leg_lower":
			return Vector2(height * 0.18, leg_width * 0.90)
		&"foot":
			return Vector2(height * 0.05, leg_width * 1.7)
	push_error("Unknown segment: %s" % name)
	return Vector2.ZERO
