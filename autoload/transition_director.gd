extends CanvasLayer
## The transition overlay — Doc 00 §7.4. Owns pixels, and nothing else.
##
## **It is presentation only, and that is the whole design.** §4.5: "The lock is a
## tick countdown, never a tween. The overlay tween *mirrors* it visually and has
## no authority over gameplay state." So the resolver, the event queue, the
## persistent-state autoload, Doc 01 §2.1's intensity float, both sibling row-0.11
## directors and Dipper himself are named nowhere below — deliberately and
## checkably, since the suite scans this file's own source text for every one of
## those identifiers (row 0.11's Verify column, §12 check 20). A single reference
## to any of them is the beginning of a gameplay state change that waits on an
## animation, which is exactly what §4.5 forbids: "Gameplay never resumes because
## an animation finished — it resumes because the resolver says so."
##
## The corollary, and the reason there is no completion signal, no `await` target
## and no callback here: there is deliberately no way for gameplay to wait on this
## file. A fade still running when the lock releases is a cosmetic overshoot, and a
## fade that ends early is a few black frames — never a lockout.
##
## **A tween is legal here and nowhere else in this row.** §2.4 bans `SceneTree`
## timers for gameplay state but exempts presentation outright: "Presentation-only
## timers (a tween on a HUD element, a shader fade) may still use tweens freely."
## Doc 01 §2.1's grade fade is the project's existing precedent for exactly this
## shape — kill the running tween, start one, one writer of the driven value.
##
## Durations arrive as physics-tick counts from the caller — `FADE_TICKS`,
## `DOOR_WIPE_TICKS` and `SEAM_WIPE_TICKS`, all owned by the resolver and all
## derived from their document's float (§2.4) — and are converted to seconds here.
## None of §7.4's, §7.6's or §7.4.1's durations is written in this file, because a
## second copy is what §0.1 forbids and what drifts the first time either moves.

## §2.4's tick, restated rather than referenced: the constants that own the fade
## durations live on the resolver, and naming the resolver here would break the
## purity boundary above for a float that has been 1/60 since §2.4 was written.
const TICK := 1.0 / 60.0

## Doc 04 §0's canvas table: `CanvasLayer` 10 (HUD) / 20 (menus) / 30
## (transitions). Above everything the game draws, including both UI layers,
## because a fade that leaves the HUD sitting on top of it is not a fade.
const LAYER := 30

## The overlay. `extends CanvasLayer` rather than a `Node` that creates one: an
## autoload is a node on `root` either way, so extending it directly is one node
## and no lookup instead of two nodes and a path.
var _overlay: ColorRect

## Exactly one tween drives `_overlay.color.a`, ever. Two live tweens fighting over
## one alpha is the bug §12 check 36 catches for the intensity float.
var _tween: Tween


func _ready() -> void:
	layer = LAYER
	_overlay = ColorRect.new()
	# Black, and fully transparent: a boot that never calls anything shows the
	# game rather than a black screen.
	_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	# The native filter, not an input guard of our own. An overlay that eats clicks
	# at any alpha is a bug felt as dead UI, and `MOUSE_FILTER_IGNORE` is the engine
	# answering it at every alpha for free.
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The anchor preset, not a 1920x1080 rect and not a resize handler. Doc 01 §0's
	# display contract is `canvas_items` + `keep`, so the Control's anchors — taken
	# against the viewport, since its parent is not a Control — cover the whole
	# canvas at every window size and aspect.
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)


## §3.2 step 4: "Mount behind an already-opaque overlay — no fade-out, we start
## black." Immediate, and it kills any tween in flight — an in-flight fade that
## survived this call would tween straight back off the black just asked for.
##
## This doubles as the reset this file would otherwise need. §3.3's `end_session()`
## has no per-session state here to clear: the overlay's alpha is the only state
## there is, and §3.2 opens by setting it to what boot wants. An empty `reset()`
## would be a method with no body and no caller.
func set_opaque(opaque: bool) -> void:
	_kill_tween()
	_overlay.color.a = 1.0 if opaque else 0.0


## §3.2 step 5 and §7.4 step 7: opaque to transparent over `ticks` physics ticks.
## Tweened from the CURRENT alpha rather than snapped to 1.0 first, so a call
## landing on a partial fade continues from what is on screen.
func play_fade_in(ticks: int) -> void:
	_retween().tween_property(_overlay, ^"color:a", 0.0, _seconds(ticks))


## §4.5's `play_fade(FADE_TICKS)  # presentation only`, and the whole visual of
## §7.4: fade to opaque (step 4), hold while the destination mounts (step 5), fade
## back in (step 7). The same method serves §7.6's interior door wipe and §7.4.1's
## seam wipe — the only difference between the three is the tick count the caller
## passes, so there is one method here and not three.
##
## Safe to interrupt and safe to outlive, per §4.5: a later call supersedes whatever
## is in flight, and nothing gates the lock's countdown on this sequence finishing.
func play_fade(ticks: int) -> void:
	var secs := _seconds(ticks)
	var t := _retween()
	t.tween_property(_overlay, ^"color:a", 1.0, secs)
	# §7.4 step 5 sits between the two fades, so it is written as part of the
	# sequence rather than pretended away. The lock is
	# `wipe_ticks * 2 + _mount_budget_ticks(to)`, and this hold is the term that
	# absorbs the third one — which is what keeps the overlay's total duration equal
	# to the lock instead of ending two-thirds of the way through it.
	#
	# ponytail: zero-length today, because the mount budget is 0 until row 2.3
	# gives `ZoneManager` a real load estimate. When it does, the hold reads that
	# budget and nothing else in this file changes.
	t.tween_interval(0.0)
	t.tween_property(_overlay, ^"color:a", 0.0, secs)


## The state query, and the minimum one: the suite needs the overlay's opacity to
## check anything at all, and `set_opaque()` must be observably immediate. Nothing
## here reports whether a fade is running or how far along it is — see the header
## on why nothing may come to depend on that.
func alpha() -> float:
	return _overlay.color.a


## Ticks to seconds. The one conversion in the file, so callers keep passing tick
## counts and no duration of §7.4's is ever spelled out here. Clamped at zero: a
## wipe of no ticks is an instant cut, not a reversed tween.
func _seconds(ticks: int) -> float:
	return maxi(ticks, 0) * TICK


## Killing the running tween first is what guarantees exactly one writer of
## `_overlay.color.a` in any frame — a new transition must replace the curve, never
## race it. Doc 01 §2.1's grade fade does the same, for the same reason.
func _retween() -> Tween:
	_kill_tween()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return _tween


func _kill_tween() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
