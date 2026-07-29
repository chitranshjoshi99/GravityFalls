class_name PlayerController
extends CharacterBody2D
## Dipper's body — Doc 2 §3.3, whose enum is superseded by Doc 00 §5.1.
##
## Tracker row 0.10 created this file for the enum alone: Doc 00 §4.1 and §6.3's
## authored resolver source name `PlayerController.State.BLACKOUT` and
## `PlayerController.State.ZONE_TRANSITION`, so RuntimeDirector cannot be written
## to its own specification until this type exists. Row 1.4 completes the file —
## the speed exports, DEPTH_RATIO, _physics_process, HeightBody and Stamina all
## belong to it, and its own check (Doc 00 §12 check 31, every state has an arm)
## is what gates them.
##
## Doc 2 §3.3's six-value enum is superseded by Doc 00 §5.1's ten. The six keep
## their exact meaning; ATTACKING, DRIVING, ZONE_TRANSITION and BLACKOUT are new.
## The order and grouping below are authored, not incidental — Doc 00 §4.2's
## priority ladder and every later resolver arm resolve on these names, so a
## rename or a reorder is a silent breakage rather than a compile error.

enum State {
	FREE,
	JOURNAL,
	ATTACKING,          # Doc 2 §4 gives the timings, no state owned them
	DODGING,
	HURT,
	FUMBLING,
	DRIVING,            # Doc 3 §7 cart, §5.3 boat
	CUTSCENE,
	ZONE_TRANSITION,
	BLACKOUT,
}

var state: State = State.FREE

## Untyped `Node` slots, not `@onready` typed references: the `Journal` and
## `Health` classes do not exist until rows 1.9 and 1.5, and a typed declaration
## against a missing class_name is a parse error, not a deferred one.
# ponytail: plain Node slots — row 1.9 types `journal`, row 1.5 types `health`.
var journal: Node
var health: Node

## Doc 00 §4.1 step 4c: the resolver ticks the player's owned durations —
## i-frames, fumble, dodge and attack counters — in ticks per §2.4, never in
## tweens. Row 0.10 needs the call site to exist; the counters themselves belong
## to the rows that introduce them.
# ponytail: empty body — rows 1.4 and 1.5 fill in the counters it decrements.
func tick_durations() -> void:
	pass
