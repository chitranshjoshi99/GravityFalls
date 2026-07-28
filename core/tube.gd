class_name Tube
## Doc 01 §4: a single capsule spans both bones of a rubber-hose limb.


## Vertical capsule from a proximal attachment at (0, 0), extending along +Y.
## The default keeps 28 vertices, while deliberately placing three shaft samples
## in the 0.38–0.62 elbow band on each side. Uniform sixths yield only two
## blended vertices and fail the tracker’s load-bearing blend-band contract.
static func capsule(length: float, width: float, seg: int = 8,
		width_end: float = -1.0, shaft_segs: int = 6) -> PackedVector2Array:
	if length <= 0.0 or width <= 0.0 or seg < 3 or shaft_segs < 4:
		push_error("Tube.capsule requires positive dimensions, seg >= 3, and shaft_segs >= 4")
		return PackedVector2Array()

	var w0 := width * 0.5
	var w1 := (width if width_end < 0.0 else width_end) * 0.5
	var shaft_samples := _shaft_samples(shaft_segs)
	var points := PackedVector2Array()

	points.append(Vector2(w0, 0.0))
	for t in shaft_samples:
		points.append(Vector2(lerpf(w0, w1, t), length * t))
	points.append(Vector2(w1, length))

	for i in range(1, seg):
		var angle := PI * float(i) / float(seg)
		points.append(Vector2(cos(angle) * w1, length + sin(angle) * w1))
	points.append(Vector2(-w1, length))

	for i in range(shaft_samples.size() - 1, -1, -1):
		var t: float = shaft_samples[i]
		points.append(Vector2(-lerpf(w0, w1, t), length * t))
	points.append(Vector2(-w0, 0.0))

	for i in range(1, seg):
		var angle := PI + PI * float(i) / float(seg)
		points.append(Vector2(cos(angle) * w0, sin(angle) * w0))

	return points


## The default shape remains 28 vertices but has at least six total points in
## the arm blend band. Other counts retain an even linear distribution.
static func _shaft_samples(shaft_segs: int) -> PackedFloat32Array:
	if shaft_segs == 6:
		return PackedFloat32Array([0.16, 0.40, 0.50, 0.60, 0.84])
	var samples := PackedFloat32Array()
	for i in range(1, shaft_segs):
		samples.append(float(i) / float(shaft_segs))
	return samples


static func hose_weights(t: float, blend_start: float = 0.38,
		blend_end: float = 0.62) -> Vector2:
	if blend_end <= blend_start:
		push_error("Tube.hose_weights requires blend_end > blend_start")
		return Vector2(1.0, 0.0)
	var fore := smoothstep(blend_start, blend_end, clampf(t, 0.0, 1.0))
	return Vector2(1.0 - fore, fore)


## Map capsule points to hose texture pixels, including the transparent border.
static func hose_uv(points: PackedVector2Array, width: float,
		width_end: float = -1.0, margin: float = 1.0) -> PackedVector2Array:
	var w_max := maxf(width, width if width_end < 0.0 else width_end)
	var w0 := width * 0.5
	var uv := PackedVector2Array()
	for point in points:
		uv.append(Vector2(
			point.x + w_max * 0.5 + margin,
			point.y + w0 + margin
		))
	return uv


static func hose_texture_size(length: float, width: float,
		width_end: float = -1.0, margin: float = 1.0) -> Vector2:
	var end_width := width if width_end < 0.0 else width_end
	return Vector2(
		maxf(width, end_width) + margin * 2.0,
		length + width * 0.5 + end_width * 0.5 + margin * 2.0
	)
