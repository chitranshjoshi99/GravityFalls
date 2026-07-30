@tool
class_name EyePair
extends Node2D
##
## Doc 01 §5 — the signature feature, drawn rather than authored.
##
## §5.2 is explicit that this is a `_draw()` node "so it stays correct at any
## head size", and §9.3 is explicit that eyes are the one part nobody supplies a
## PNG for: eye art would break both the blink squash and the merged outline.
## Every number comes from `Eyes.geometry()`; nothing here is a literal, for the
## same §10 reason the rig has no literal bone positions.
##
## §5.2's merged outline is four passes, in order, and the order IS the trick —
## the outline circles overlap by exactly as much as the sclera circles, so the
## peanut silhouette emerges for free with no boolean union and no seam where
## the two circles meet.
##
## `@tool` so the face is on screen in the editor, where row 1.2 keys against it.

## `bill_black` (§1.3) — the one colour the show draws every line in.
const INK: Color = Color(0.05490196, 0.05490196, 0.05490196)

## The rig writes this from `proportions.head_diameter` in `rebuild()`; the
## default is §3.3's Dipper so the scene previews standalone.
@export var head_diameter: float = 82.0:
	set(value):
		head_diameter = value
		queue_redraw()

## Where the pupils look. `Eyes.pupil_offset()` clamps it inside the sclera, so
## an unclamped gaze vector from a look-at target is safe to write straight in.
@export var look_dir: Vector2 = Vector2.ZERO:
	set(value):
		look_dir = value
		queue_redraw()

# ponytail: no blink timer here. §5.3 makes a blink a `scale.y` squash on THIS
# node, which is an AnimationPlayer track — row 1.2's keyframes, not a second
# clock this node runs on its own.


func _draw() -> void:
	var g: Dictionary = Eyes.geometry(head_diameter)
	var radius: float = float(g["radius"])
	if radius <= 0.0:
		return  # A zero-diameter head is a proportions bug, not a drawing one.

	# §5.1's separation is measured centre to centre, straddling this node's
	# origin — which the rig parks on the eye line, `0.46 · D` below the head top.
	var half := float(g["separation"]) * 0.5
	var centers: Array[Vector2] = [Vector2(-half, 0.0), Vector2(half, 0.0)]
	var outline: float = float(g["outline_width"])
	var pupil: Vector2 = Eyes.pupil_offset(look_dir, float(g["pupil_max_offset"]))
	var pupil_radius: float = float(g["pupil_radius"])

	for c in centers:  # 1. the outline pass, which merges into one peanut.
		draw_circle(c, radius + outline, INK)
	for c in centers:  # 2. the sclera.
		draw_circle(c, radius, Color.WHITE)
	for c in centers:  # 3. the pupils, already clamped inside the sclera.
		draw_circle(c + pupil, pupil_radius, INK)
	# 4. §5.2's fourth pass is the brows — and they are NOT drawn here. They ride
	# `b_brow_l` / `b_brow_r` (§6.1) because §5.3 drives every expression off brow
	# rotation and Y offset, which is a bone track. A brow drawn in this `_draw()`
	# would be a brow no animation could reach.
