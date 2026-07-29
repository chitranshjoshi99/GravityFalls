extends Node
## Queued and active cutscenes — Doc 00 §8. It owns the cutscene queue, the
## active cutscene's authored config, and the completion handoff. Nothing else.
##
## **It mutates no gameplay state.** §14.1 contract 1 gives `RuntimeDirector`
## sole ownership of every gameplay commit, and §8.1 is written that way: the
## resolver is what sets the player to `CUTSCENE` at priority 6 (step 5), what
## writes `on_complete_flag` into the persistent state, what returns the player to
## `FREE`, and what enqueues `on_complete_intent` (step 6, §8.2.1). So no
## player-state assignment, no persistent-state autoload and no sibling row-0.11
## director is named anywhere below — deliberately and checkably, since the suite
## scans this file's own source text for all three (row 0.11's Verify column).
##
## **`request()` validates and enqueues; the resolver stays the acceptor.** That
## preserves §8.1 steps 1-3 — a story volume's request is still tested against
## same-tick damage and an open Journal by the resolver, and still "remains
## pending" rather than being dropped — while giving Docs 6-25 the
## `CutsceneDirector.request(...)` surface §8.2 authors against.
##
## **Completion is POLLED, not signalled.** `complete()` parks the finished
## config and `take_completed()` hands it over on the resolver's next pass. No
## `RuntimeEvent.Type` value exists for it: a completion is a fact, not a
## request, and a signal back into the resolver would commit outside §4.1's one
## pass. The handoff is consume-once for the same reason — read twice and
## `on_complete_flag` is written twice and the intent enqueued twice.
##
## This file has no durations, because it owns none: line timings arrive with the
## dialogue runner at row 3.6, and §7.7's arrival grace is counted by the
## resolver alone (see `request()`). Any duration it ever gains is a physics-tick
## count derived from its document's float (§2.4), never a `SceneTree` timer.

## §8.2.1, and the whole of it: `on_complete_intent` "may name
## `JOURNAL_TOGGLE_REQUEST`, `ITEM_SELECT_REQUEST`, or `UV_TOGGLE_REQUEST`, and
## nothing else. It may never name a zone request, a damage event, or a
## cutscene." Kept as one constant so §12 check 23 can read the permitted set
## rather than restate it — two copies of a security list drift, and the drift
## is silent.
##
## Typed `Array[int]` rather than `Array[RuntimeEvent.Type]` so an arbitrary
## authored value can be tested for membership without a failed cast first.
const PERMITTED_COMPLETE_INTENTS: Array[int] = [
	RuntimeEvent.Type.JOURNAL_TOGGLE_REQUEST,
	RuntimeEvent.Type.ITEM_SELECT_REQUEST,
	RuntimeEvent.Type.UV_TOGGLE_REQUEST,
]

## §2.2's "Queued/active cutscenes": more than one request may be pending, and
## exactly one may be active. Keyed by the id §8.2 authors, so the resolver can
## name which cutscene it is committing.
##
# ponytail: insertion order and nothing more. No priority ordering, no
# cancellation and no skip system — §8.2's `skippable` is stored and unread
# until row 3.8 authors the chapter card that honours it, and nothing in Docs
# 00-25 asks a queued cutscene to outrank another one yet.
var _pending: Dictionary = {}

## The active cutscene's id, or `&""`. Read by the resolver and by row 3.6's
## dialogue runner; written here only.
var active_id: StringName = &""
var _active_config: Dictionary = {}

## The finished cutscene's config, parked for exactly one `take_completed()`.
var _completed: Dictionary = {}


## §8.2's authoring surface for Docs 6-25. Returns whether the request was
## accepted; a story volume disables itself or sets its persistent flag on
## acceptance (§8.1), so the answer is load-bearing.
func request(id: StringName, config: Dictionary) -> bool:
	# §8.2.1 and §12 check 23's last sentence: "any other is rejected at request
	# time". This is a trust boundary, not a convenience — a chapter's typo here
	# would otherwise hand the resolver an unaudited intent to enqueue on
	# completion, and the forbidden values are exactly the dangerous ones: a zone
	# request that teleports the player, a damage event, or a second cutscene.
	# The field is optional, so an absent one is not a rejection (§8.2).
	if config.has(&"on_complete_intent"):
		var intent: Variant = config[&"on_complete_intent"]
		if not (intent is int) or not PERMITTED_COMPLETE_INTENTS.has(intent):
			push_error(
				("cutscene %s names a forbidden on_complete_intent: %s — §8.2.1 permits "
				+ "only JOURNAL_TOGGLE_REQUEST, ITEM_SELECT_REQUEST and UV_TOGGLE_REQUEST")
				% [id, str(intent)]
			)
			return false

	_pending[id] = config
	# §8.1 step 1. Exactly one event, carrying the id so the resolver can name
	# what it commits, and §7.7's marker so it can refuse to commit it too early.
	#
	# §7.7's arrival grace: an arrival story is marked `&"arrival_story": true` in
	# its config and the marker rides into the payload. Its meaning is that the
	# resolver must not commit this request while its own `_arrival_grace_ticks`
	# is still running, so the player gets a visible, controllable arrival beat
	# and dialogue never begins underneath a transition overlay.
	#
	# ponytail: this is one half of the rule. The resolver's half — refusing a
	# marked request during the grace — is the next task in row 0.11.
	# `RuntimeDirector` already owns `ARRIVAL_GRACE_TICKS` and counts it down in
	# `_tick_durations()`; a second counter here would be two numbers that drift
	# (§0.1, §2.4) and a gameplay gate outside the resolver (§14.1).
	RuntimeEvents.enqueue(RuntimeEvent.Type.CUTSCENE_REQUEST, self, {
		&"id": id,
		&"arrival_story": config.get(&"arrival_story", false),
	})
	return true


## §8.1 step 5. Called by the resolver once it has committed the request at
## priority 6 — same-tick damage resolved, the Journal closed, and the player
## already set to `CUTSCENE` there.
func begin(id: StringName) -> bool:
	if not _pending.has(id):
		# A `CUTSCENE_REQUEST` published by something other than `request()`
		# arrives here with no config. Activating an empty one would give the
		# player an invisible cutscene with no authored line to end it — a
		# lockout only a `complete()` from nowhere could clear — so it is refused
		# rather than activated.
		push_error(
			"no pending cutscene named %s — a CUTSCENE_REQUEST must come from CutsceneDirector.request() (§8.2)"
				% id
		)
		return false
	active_id = id
	_active_config = _pending[id]
	_pending.erase(id)
	# ponytail: reading `lines` into a dialogue runner and handing `camera` a
	# camera is row 3.6's. There is no dialogue system, no typewriter and no
	# camera control in this file, by design — this row owns the queue.
	return true


func is_active() -> bool:
	return active_id != &""


## §8.1 step 6. Marks the active cutscene finished and clears it as active; the
## resolver collects the config on its next pass and performs all three commits.
# ponytail: what calls this is row 3.6's dialogue runner, when the last authored
# line ends — and the camera hand-back goes with it. Nothing calls it today
# except the suite.
func complete() -> void:
	if active_id == &"":
		return
	_completed = _active_config
	active_id = &""
	_active_config = {}


## The handoff, polled by the resolver each tick and **consume-once**: a second
## call in the same tick or the next returns an empty Dictionary. The resolver
## writes `on_complete_flag`, returns the player to `FREE` and enqueues
## `on_complete_intent` from what it gets back, so a handoff that could be read
## twice would double the flag write and the enqueue.
##
## A copy, never the stored Dictionary — the resolver holds this value across
## three commits, and handing over the original would let it mutate this
## director's state through the value it was given.
func take_completed() -> Dictionary:
	var out: Dictionary = _completed.duplicate()
	_completed = {}
	return out


## §3.3's `end_session()` and §12 check 12. A config's `camera` is a node path or
## a node reference authored by a chapter and its `lines` are Resources — exactly
## the freed-node reference check 12 hunts for — so all three stores are cleared,
## not only the active one.
func reset() -> void:
	_pending.clear()
	active_id = &""
	_active_config = {}
	_completed = {}
