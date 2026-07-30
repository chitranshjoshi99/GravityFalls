extends Node
## Immutable cross-cutting values from Doc 01. Per-zone and per-character data
## belongs in Palette and CharacterProportions resources instead.

const REFERENCE_CANVAS_SIZE: Vector2i = Vector2i(1920, 1080)
const ART_AUTHORING_SCALE: float = 2.0
const TEXTURE_SCALE_FOR_2X_ART: Vector2 = Vector2(0.5, 0.5)

const EYE_BLINK_CLOSE_SECONDS: float = 0.06
const EYE_BLINK_HOLD_SECONDS: float = 0.03
const EYE_BLINK_OPEN_SECONDS: float = 0.08
const EYE_BLINK_MIN_SECONDS: float = 2.4
const EYE_BLINK_MAX_SECONDS: float = 5.8

const EXPRESSION_NEUTRAL: Dictionary = {
	"brow_rotation_degrees": Vector2(0.0, 0.0),
	"brow_y_head_ratio": 0.0,
	"pupil_scale": 1.0,
}
const EXPRESSION_WORRIED: Dictionary = {
	"brow_rotation_degrees": Vector2(12.0, -12.0),
	"brow_y_head_ratio": -0.04,
	"pupil_scale": 1.10,
}
const EXPRESSION_DELIGHTED: Dictionary = {
	"brow_rotation_degrees": Vector2(-8.0, 8.0),
	"brow_y_head_ratio": -0.08,
	"pupil_scale": 1.25,
}
const EXPRESSION_SUSPICIOUS: Dictionary = {
	"brow_rotation_degrees": Vector2(-14.0, -6.0),
	"brow_y_head_ratio": 0.05,
	"pupil_scale": 0.85,
}
const EXPRESSION_PRESETS: Dictionary = {
	&"neutral": EXPRESSION_NEUTRAL,
	&"worried": EXPRESSION_WORRIED,
	&"delighted": EXPRESSION_DELIGHTED,
	&"suspicious": EXPRESSION_SUSPICIOUS,
}
