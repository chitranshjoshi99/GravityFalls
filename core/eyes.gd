class_name Eyes
## Doc 01 §5: touching-circle eyes and pupil containment math.

const RADIUS_RATIO: float = 0.21
const OVERLAP: float = 0.06
const CENTER_Y_RATIO: float = 0.46
const PUPIL_RATIO: float = 0.34
const OUTLINE_RATIO: float = 0.055


static func geometry(head_diameter: float) -> Dictionary:
	var radius := maxf(head_diameter, 0.0) * RADIUS_RATIO
	var pupil_radius := radius * PUPIL_RATIO
	return {
		"radius": radius,
		"separation": 2.0 * radius * (1.0 - OVERLAP),
		"center_y": maxf(head_diameter, 0.0) * CENTER_Y_RATIO,
		"pupil_radius": pupil_radius,
		"pupil_max_offset": maxf(radius - pupil_radius - 2.0, 0.0),
		"outline_width": maxf(radius * OUTLINE_RATIO, 2.0),
	}


static func pupil_offset(look_dir: Vector2, max_offset: float) -> Vector2:
	return look_dir.limit_length(maxf(max_offset, 0.0))
