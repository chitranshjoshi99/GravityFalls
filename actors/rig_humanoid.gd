@tool
class_name RigHumanoid
extends CharacterBody2D
##
## Doc 01 §6 — the humanoid skeleton every character in the project inherits.
##
## §10 makes this an INHERITED-scene base: `dipper.tscn` and all 30+ character
## scenes inherit `rig_humanoid.tscn` and override "only the CharacterProportions
## resource and part textures". That is the whole design constraint on this file:
## no bone rest position may be a literal pixel number, because a literal is a
## number the inheriting scene cannot override with one field.
##
## DEVIATION from §6.1, deliberate: §6.1 draws the root as `Node2D`; this is a
## `CharacterBody2D`. An inherited scene cannot change its root's TYPE, and both
## §10 and tracker row 1.3 require `dipper.tscn` to inherit this scene, while
## `SessionDirector._make_player()` is typed `-> PlayerController`, which extends
## `CharacterBody2D`. A `Node2D` root makes row 1.3 unbuildable as specified.
## `CharacterBody2D` IS-A `Node2D`, so §3.1's origin convention — ground contact,
## horizontally centered between the feet — is untouched; only the type narrows.
## No `CollisionShape2D` here: Doc 02 §2.1's body ellipse is rows 1.4/1.5.
##
## `@tool` because row 1.2 keyframes bone tracks in the editor and needs the real
## rest pose on screen, not an unbuilt pile of bones at the origin.
##
## Godot 2D is Y-down and the origin is the ground, so the whole body lives at
## negative Y and a limb hangs along +Y — the same convention `Tube.capsule()`
## is authored in (§4.1).

## The one field an inheriting character scene overrides (§10). Null falls back
## to `CharacterProportions.new()`, whose defaults are Dipper's (§3.3), so the
## base scene previews on its own.
@export var proportions: CharacterProportions

# ponytail: no setter, so editing `proportions` in the inspector needs a scene
# reload to re-lay-out. Row 1.2 authors against a rest pose it sets once; add the
# setter the day someone tunes proportions live.


func _ready() -> void:
	rebuild()


## Lays every bone, anchor and the shadow out at its rest position, derived from
## `proportions` alone. Public because it is also the editor's entry point.
func rebuild() -> void:
	var p: CharacterProportions = proportions if proportions != null else CharacterProportions.new()

	# §3.2's segment table. `.x` is length, `.y` is width.
	var foot := p.segment(&"foot")
	var leg_lower := p.segment(&"leg_lower")
	var leg_upper := p.segment(&"leg_upper")
	var torso := p.segment(&"torso")
	var arm_upper := p.segment(&"arm_upper")
	var arm_fore := p.segment(&"arm_fore")
	var hand := p.segment(&"hand")
	var head_d := p.head_diameter

	# §3.2's stack, read upward from the ground: foot, lower leg, upper leg, hips.
	var hip_y := -(foot.x + leg_lower.x + leg_upper.x)
	# §3.2: "Head mounts directly to torso top — the show has no visible neck."
	# Local to `b_torso`, whose own origin is the hip joint.
	var head_base := -torso.x
	# Shoulders sit at the top of the torso, dropped half a hose width so the
	# capsule's round cap stays inside the torso silhouette, and are separated by
	# the torso's own width.
	var shoulder := Vector2(torso.y * 0.5, head_base + arm_upper.y * 0.5)
	# §5.1's eye line is measured DOWN from the head top; `b_head` sits at the head
	# base, so it is one diameter up and then back down by `center_y`.
	var eye: Dictionary = Eyes.geometry(head_d)
	var eye_y := -head_d + float(eye["center_y"])
	# Brows ride on the top edge of the sclera circles (§5.2 pass 4, "brows, on
	# their own bones, above"), separated like the eyes they sit over.
	var brow := Vector2(float(eye["separation"]) * 0.5, eye_y - float(eye["radius"]))

	var sk := "Skeleton2D/b_hips"
	var torso_n := sk + "/b_torso"
	var head_n := torso_n + "/b_head"
	var arm_l := torso_n + "/b_arm_l_upper"
	var arm_r := torso_n + "/b_arm_r_upper"
	var leg_l := sk + "/b_leg_l_upper"
	var leg_r := sk + "/b_leg_r_upper"

	# Left is screen-left (−X) and right is screen-right; §6.2's side-facing arm
	# swap is a `Parts` z_index concern, never a bone one.
	_place({
		sk: Vector2(0.0, hip_y),
		# The pelvis IS the hip joint, so the torso pivots at zero offset from it.
		torso_n: Vector2.ZERO,
		head_n: Vector2(0.0, head_base),
		head_n + "/b_brow_l": Vector2(-brow.x, brow.y),
		head_n + "/b_brow_r": brow,
		# The mouth mount, halfway between the eye line and the chin (§6.1).
		head_n + "/b_jaw": Vector2(0.0, eye_y * 0.5),
		arm_l: Vector2(-shoulder.x, shoulder.y),
		arm_l + "/b_arm_l_fore": Vector2(0.0, arm_upper.x),
		arm_l + "/b_arm_l_fore/b_hand_l": Vector2(0.0, arm_fore.x),
		arm_r: shoulder,
		arm_r + "/b_arm_r_fore": Vector2(0.0, arm_upper.x),
		arm_r + "/b_arm_r_fore/b_hand_r": Vector2(0.0, arm_fore.x),
		leg_l: Vector2(-leg_upper.y * 0.5, 0.0),
		leg_l + "/b_leg_l_lower": Vector2(0.0, leg_upper.x),
		# §3.2's foot LENGTH is the ankle rise inside the height stack, and the
		# foot bone is mounted at the sole rather than the ankle: that is the
		# pivot a planted foot actually rotates about, and it makes §3.1's
		# ground-contact origin something a check can read straight off the bone.
		leg_l + "/b_leg_l_lower/b_foot_l": Vector2(0.0, leg_lower.x + foot.x),
		leg_r: Vector2(leg_upper.y * 0.5, 0.0),
		leg_r + "/b_leg_r_lower": Vector2(0.0, leg_upper.x),
		leg_r + "/b_leg_r_lower/b_foot_r": Vector2(0.0, leg_lower.x + foot.x),

		# §6.3's eight anchors, each under the node §6.3's table names. Seven hang
		# off bones — an anchor that did not could not follow one — and `a_ground`
		# is the one §6.3 puts on `CharacterRoot`, which is why the `Anchors`
		# container §6.1 draws can hold it and only it.
		arm_r + "/b_arm_r_fore/b_hand_r/a_hand_r": Vector2(0.0, hand.x * 0.5),
		arm_l + "/b_arm_l_fore/b_hand_l/a_hand_l": Vector2(0.0, hand.x * 0.5),
		head_n + "/a_head_top": Vector2(0.0, -head_d),
		head_n + "/a_face": Vector2(0.0, eye_y),
		# 2D has no depth, so "behind" is a quarter torso-width against the facing
		# direction (+X by default) — enough for Doc 02's stow offset to read.
		torso_n + "/a_back": Vector2(-torso.y * 0.25, head_base * 0.5),
		torso_n + "/a_chest": Vector2(0.0, head_base * 0.5),
		sk + "/a_interact": Vector2.ZERO,
		"Anchors/a_ground": Vector2.ZERO,
	})

	# Flat contact ellipse on the ground plane, sized off the foot width (itself
	# `leg_width · 1.7`) so it tracks the character's stance, not its height.
	var shadow := get_node_or_null(^"Shadow") as Polygon2D
	if shadow != null:
		shadow.polygon = _ellipse(foot.y, foot.y * 0.3, 16)

	# --- §6.2's parts ---------------------------------------------------------
	# Geometry only. The z_index table, the placeholder colours and the nodes
	# themselves are authored in the scene — Deferred R1 replaces the fills by
	# assigning a texture to THESE nodes, and an artist cannot select a node that
	# is conjured at runtime.
	#
	# ponytail: `Polygon2D.texture`, `uv` and `texture_scale` are left untouched,
	# so `Tube.hose_uv()` and `hose_texture_size()` have no caller yet. Deferred
	# D11 — zero PNGs exist, every part is a flat colour fill, and §12 contract 7
	# says no art asset is a hard dependency. Row 6.3's striped-hose test is what
	# earns the UVs; R1 is what earns the textures.
	if get_node_or_null(^"Skeleton2D") == null:
		return

	# Bone rest positions read back off the skeleton just laid out, in the root's
	# own space, so a part can never drift from the bone it rides.
	var head_at := _local_of(head_n)

	# §4.2 / §12 contract 8: a limb is ONE polygon spanning BOTH bones. Two
	# polygons hinged at a shared point are the hard mechanical elbow this whole
	# design exists to avoid, and no amount of animation fixes one.
	# Arms take §4.2's 0.38–0.62 blend band; legs take 0.42–0.66, because §4.2
	# puts knees slightly lower proportionally than elbows.
	const ARM_BAND := Vector2(0.38, 0.62)
	const LEG_BAND := Vector2(0.42, 0.66)
	_hose("arm_hose_l", arm_l, arm_l + "/b_arm_l_fore",
		arm_upper.x + arm_fore.x, arm_upper.y, arm_fore.y, ARM_BAND)
	_hose("arm_hose_r", arm_r, arm_r + "/b_arm_r_fore",
		arm_upper.x + arm_fore.x, arm_upper.y, arm_fore.y, ARM_BAND)
	_hose("leg_hose_l", leg_l, leg_l + "/b_leg_l_lower",
		leg_upper.x + leg_lower.x, leg_upper.y, leg_lower.y, LEG_BAND)
	_hose("leg_hose_r", leg_r, leg_r + "/b_leg_r_lower",
		leg_upper.x + leg_lower.x, leg_upper.y, leg_lower.y, LEG_BAND)

	# §4.4: hands and feet are RIGID — weight 1.0 to the terminal bone, no
	# blending. A mitten is a short capsule and a foot is a rounded wedge, so
	# `Tube.capsule` at a stubby length is both of them and costs nothing.
	var hand_bone_l := arm_l + "/b_arm_l_fore/b_hand_l"
	var hand_bone_r := arm_r + "/b_arm_r_fore/b_hand_r"
	var foot_bone_l := leg_l + "/b_leg_l_lower/b_foot_l"
	var foot_bone_r := leg_r + "/b_leg_r_lower/b_foot_r"
	_rigid("hand_l", hand_bone_l, _local_of(hand_bone_l), Tube.capsule(hand.x, hand.y, 8))
	_rigid("hand_r", hand_bone_r, _local_of(hand_bone_r), Tube.capsule(hand.x, hand.y, 8))
	# The foot bone is mounted at the SOLE (see `_place`'s note), so the wedge is
	# lifted to sit on top of it rather than under the ground. `Tube.capsule`
	# spans (0, 0) to (0, length) plus a round cap of `width * 0.5` past EACH end,
	# so the lift is length + half-width — the distal cap's own radius, which is
	# the part that used to hang `leg_w · 0.85` below §3.1's ground-contact origin.
	# Doc 02 §1.3 keys Y-sorting, the shadow and the collision capsule off that
	# origin, and the `Shadow` ellipse below is already centred on it, so a sole
	# anywhere but y = 0 puts the shadow at the ankles.
	var sole := foot.x + foot.y * 0.5
	_rigid("foot_l", foot_bone_l, _local_of(foot_bone_l) - Vector2(0.0, sole),
		Tube.capsule(foot.x, foot.y, 8))
	_rigid("foot_r", foot_bone_r, _local_of(foot_bone_r) - Vector2(0.0, sole),
		Tube.capsule(foot.x, foot.y, 8))

	# Torso hangs from the torso top down to the hip joint its bone pivots on.
	_rigid("torso", torso_n, Vector2(0.0, head_at.y), Tube.capsule(torso.x, torso.y, 8))
	# §3.1's head is a circle of diameter D whose BASE is the torso top (§3.2 —
	# no neck), so its centre is half a diameter above the bone.
	_rigid("head_base", head_n, head_at - Vector2(0.0, head_d * 0.5),
		_ellipse(head_d * 0.5, head_d * 0.5, 20))
	# §3.3's cap, sitting on the crown. FINDING: §3.3 says the cap has "its own
	# bone"; §6.1's tree has no such bone, so it rides `b_head` — which is what
	# makes it survive the `surprise` head-snap, since it moves with the skull
	# rather than lagging it. A cap bone is an inherited scene's to add.
	#
	# NOT a `Tube.capsule`. A capsule is round at BOTH ends, so it bulged half a
	# width above the crown and its distal cap reached 0.52·D below it — past
	# §5.1's 0.46·D eye line, and with `hat` at z_index 30 over `brows` at 20 that
	# hid both brows and the top of both pupils. A bowl cut with an unauthored
	# scowl, and no numeric check can see it. §3.3 calls Dipper's part a cap, so
	# the placeholder is built as one: a shallow dome over the crown and a lip
	# projecting along +X, the facing direction `a_back` is measured against.
	#
	# Depths are fractions of D below the crown, which is where this polygon's
	# origin sits. The head is a circle of radius 0.5·D (§3.1), so at depth `u·D`
	# its half-width is `D · sqrt(u - u²)` — 0.20·D at u = 0.04, 0.30·D at u = 0.10.
	# The dome's 0.34·D × 0.15·D ellipse runs OUTSIDE that curve at every x it
	# spans, so the skull cannot poke through the cap it is wearing. The band and
	# brim bottom at 0.16·D is the lowest point of the whole part, which clears the
	# brows' own top edge — 0.21·D (eye radius) + 0.03·D (brow half-height) above
	# §5.1's 0.46·D line, so 0.22·D below the crown — by 0.06·D.
	#
	# ponytail: twelve points and no helper — one caller, and Refinement R1
	# replaces the whole shape with a cap texture on this same node.
	var cap := PackedVector2Array()
	for i in 9:
		# Half-ellipse, +X edge over the crown to −X edge. Peaks 0.05·D ABOVE the
		# crown: a cap has thickness, and one flush with the skull reads as paint.
		var a := PI * float(i) / 8.0
		cap.append(Vector2(cos(a) * head_d * 0.34, head_d * (0.10 - sin(a) * 0.15)))
	cap.append(Vector2(-head_d * 0.34, head_d * 0.16))   # band under the dome
	cap.append(Vector2(head_d * 0.62, head_d * 0.16))    # brim, underside
	cap.append(Vector2(head_d * 0.62, head_d * 0.10))    # brim tip, back to the dome
	_rigid("hat", head_n, head_at - Vector2(0.0, head_d), cap)
	# §5.2 pass 4: brows are parts on their own bones, never drawn by the eyes.
	_rigid("brows/brow_l", head_n + "/b_brow_l", _local_of(head_n + "/b_brow_l"),
		_ellipse(head_d * 0.135, head_d * 0.03, 8))
	_rigid("brows/brow_r", head_n + "/b_brow_r", _local_of(head_n + "/b_brow_r"),
		_ellipse(head_d * 0.135, head_d * 0.03, 8))
	# §7's `talk` runs on `b_jaw` alone, so the mouth is the one part that layers
	# over every body animation.
	_rigid("mouth", head_n + "/b_jaw", _local_of(head_n + "/b_jaw"),
		_ellipse(head_d * 0.15, head_d * 0.045, 12))

	# §5.1's eye line, which `a_face` already sits on.
	#
	# ponytail: the eye pair is positioned, not PARENTED to `b_head`, because
	# §6.2 puts every part under `Parts`. A `_draw()` node takes no bone weights,
	# so unlike every Polygon2D above it does not follow the head when the bone
	# moves — a `RemoteTransform2D` on `b_head` with `update_scale = false` (§5.3
	# squashes `scale.y` and must win) is the fix, and row 1.2 is where a moving
	# head first exists to need it.
	var eyes := get_node_or_null(^"Parts/eyes") as Node2D
	if eyes != null:
		eyes.position = _local_of(head_n + "/a_face")
		# `set()` rather than a typed `EyePair` handle. A `--script` run resolves a
		# global class name out of the editor's class cache, and a class added in
		# the same commit as its first user is not in a fresh clone's cache yet —
		# which is a PARSE error here, and a parse error in this file is the whole
		# suite. Verified the hard way; harness.gd's header calls the same shot.
		eyes.set(&"head_diameter", head_d)

	# §6.2 puts the held item above everything; §6.3 gives `a_hand_r` the
	# flashlight, the grappling hook and the one-handed Journal carry.
	var held := get_node_or_null(^"Parts/held_item") as Node2D
	if held != null:
		held.position = _local_of(hand_bone_r + "/a_hand_r")


## §4.2's hose: ONE `Polygon2D` spanning BOTH bones of a limb, blended across
## the middle by vertex Y. `blend` is the band — §4.2's 0.38–0.62 for an arm,
## 0.42–0.66 for a leg.
func _hose(part: String, upper: String, fore: String, length: float,
		width: float, width_end: float, blend: Vector2) -> void:
	var poly := _part(part)
	if poly == null:
		return
	# §8.1's pivot rule: the hose's origin IS its proximal joint — the shoulder
	# or the hip — which is where `Tube.capsule` puts (0, 0) and where the upper
	# bone rests.
	poly.position = _local_of(upper)
	poly.polygon = Tube.capsule(length, width, 8, width_end)
	var upper_weights := PackedFloat32Array()
	var fore_weights := PackedFloat32Array()
	for vertex in poly.polygon:
		# `t` is the vertex's Y over the hose length. `hose_weights` clamps, so
		# the two round caps resolve cleanly to (1, 0) and (0, 1).
		var w := Tube.hose_weights(vertex.y / length, blend.x, blend.y)
		upper_weights.append(w.x)
		fore_weights.append(w.y)
	_bind(poly, {upper: upper_weights, fore: fore_weights})


## §4.4's rigid part: weight 1.0 to one bone, no blending. Also the torso, the
## head and the face pieces, none of which spans a joint either.
func _rigid(part: String, bone: String, at: Vector2, points: PackedVector2Array) -> void:
	var poly := _part(part)
	if poly == null:
		return
	poly.position = at
	poly.polygon = points
	var weights := PackedFloat32Array()
	weights.resize(points.size())
	weights.fill(1.0)
	_bind(poly, {bone: weights})


## Points a part at the rig's `Skeleton2D` and gives it its bones.
##
## Two different path bases meet here, which is the one trap in this file:
## `Polygon2D.skeleton` is relative to the POLYGON, while every bone path is
## resolved relative to the SKELETON that property names. Callers speak one
## vocabulary — paths from the root, the same ones `_place` lays out — and the
## prefix is stripped here rather than at eleven call sites.
func _bind(poly: Polygon2D, bones: Dictionary) -> void:
	var skeleton := get_node(^"Skeleton2D")
	poly.skeleton = poly.get_path_to(skeleton)
	poly.clear_bones()
	for path: String in bones:
		poly.add_bone(NodePath(path.trim_prefix("Skeleton2D/")), bones[path])


func _part(part: String) -> Polygon2D:
	var poly := get_node_or_null("Parts/" + part) as Polygon2D
	if poly == null:
		push_error("RigHumanoid: Parts/%s is missing from the scene (Doc 01 §6.2)" % part)
	return poly


## A node's rest position in the root's own space — read off the skeleton rather
## than re-derived from `segment()`, so a part cannot drift from its bone.
func _local_of(path: String) -> Vector2:
	var node := get_node_or_null(path) as Node2D
	if node == null:
		push_error("RigHumanoid: %s is missing from the scene (Doc 01 §6.1/§6.3)" % path)
		return Vector2.ZERO
	return (global_transform.affine_inverse() * node.global_transform).origin


## Flat ellipse centred on the origin. Two callers — the ground shadow and the
## head circle — and neither is a capsule, which is all `Tube` builds.
static func _ellipse(radius_x: float, radius_y: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		points.append(Vector2(cos(a) * radius_x, sin(a) * radius_y))
	return points


## Sets each node's rest position. A `Bone2D` gets `rest` written from the
## transform it was just given: a bone whose `position` differs from its `rest`
## is already posed, and row 1.2's animations key deltas off `rest`.
func _place(layout: Dictionary) -> void:
	for path: String in layout:
		var node := get_node_or_null(path) as Node2D
		if node == null:
			push_error("RigHumanoid: %s is missing from the scene (Doc 01 §6.1/§6.3)" % path)
			continue
		node.position = layout[path]
		if node is Bone2D:
			(node as Bone2D).rest = node.transform
