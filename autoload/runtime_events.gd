extends Node
## The double-buffered event queue — Doc 00 §2.5. Publishers write to
## `_incoming`; RuntimeDirector swaps at the top of its resolve and reads
## `_active`. Nothing else clears either one.
##
## This is not a style choice. Godot dispatches _input / _unhandled_input during
## the input flush, which — with default (non-agile) event flushing — happens in
## the IDLE frame, not inside the physics pass. A queue cleared at physics
## priority -100 would wipe every E, J and pause press published since the
## previous physics tick: input LOSS, not input latency. A swap has no such
## window, so every event published between two resolves is seen by exactly one
## resolve. Doc 00 §12 check 16 is the regression test.
##
## Because publishing always targets `_incoming`, a commit that enqueues during
## resolution — a respawn queuing its wake-line cutscene, say — lands on the
## NEXT tick and cannot mutate the array being iterated. Re-entrancy is
## structurally impossible rather than merely avoided.
##
## No _physics_process, deliberately (Doc 00 §2.2). This node is driven, never
## ticking.

var _incoming: Array[RuntimeEvent] = []   ## publishers write here, any time
var _active: Array[RuntimeEvent] = []     ## RuntimeDirector reads here, during resolve
var _order := 0

## How many events at the head of `_incoming` were carried in by defer(). Their
## relative order is preserved by inserting each after the last one, rather than
## push_front'ing every one to position zero.
var _deferred := 0


## Called by RuntimeDirector at the top of its resolve, and by nothing else.
func swap() -> void:
	_active = _incoming
	_incoming = []
	_order = 0
	_deferred = 0


func enqueue(type: RuntimeEvent.Type, source: Node, payload: Dictionary = {}) -> void:
	var e := RuntimeEvent.new()
	e.type = type
	e.source = source.get_path() if source else NodePath()
	e.payload = payload
	e.physics_frame = Engine.get_physics_frames()
	e.order = _order
	_order += 1
	_incoming.append(e)


## Carry an event that lost its tick into the next resolve, preserving order
## (§4.6).
##
## Doc 00 §2.5 writes this as a bare push_front(). That inverts the relative
## order of two events deferred in the same resolve — defer(A) then defer(B)
## leaves [B, A] — which contradicts §4.6's "preserving order" in the one case
## where it can be observed: a checkpoint and a secret both firing behind a
## seamless activation. Inserting after the previously deferred events keeps
## them in the order the resolver saw them, and still puts every deferred event
## ahead of anything published since.
func defer(e: RuntimeEvent) -> void:
	_incoming.insert(_deferred, e)
	_deferred += 1


## Array.filter() returns an untyped Array, which cannot be returned from a
## function typed Array[RuntimeEvent] — hence the explicit build.
func take(type: RuntimeEvent.Type) -> Array[RuntimeEvent]:
	var out: Array[RuntimeEvent] = []
	for e in _active:
		if e.type == type:
			out.append(e)
	return out


func first(type: RuntimeEvent.Type) -> RuntimeEvent:
	for e in _active:
		if e.type == type:
			return e
	return null


func has(type: RuntimeEvent.Type) -> bool:
	return first(type) != null
