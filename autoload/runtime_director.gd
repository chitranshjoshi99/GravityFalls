extends Node
## The priority resolver — Doc 00 §4. One physics tick, one pass down §4.2's
## fifteen rungs, and every gameplay mutation in the project committed from here
## (§14.1). Godot callbacks publish facts; this file decides what they mean.
##
## It is a pure function of (queue, state), and Doc 00 §12's harness depends on
## that: no `await`, no `create_tween()`, no `get_tree().create_timer()`, and no
## `Input.*` appears anywhere below. Every duration is a physics-tick countdown
## derived from the owning document's float constant (§2.4), so the suite can
## step a fade, a wipe, a grace window or a blackout without a frame of real
## time passing — and so no tween, fade or animation can gate a gameplay state
## change (contract 21).
##
## **How it reaches other systems.** `CombatDirector`, `CutsceneDirector`,
## `TransitionDirector`, `ZoneManager`, `AudioDirector` and `SessionDirector` do
## not exist yet (tracker rows 0.11, 0.12, 2.3), and naming an unregistered
## autoload is a parse error rather than a runtime one. So the resolver holds
## exactly two nullable, duck-typed handles — `player` and `zone_manager` —
## which `SessionDirector` assigns at row 0.12 and the harness fills with stubs.
## Where a rung's full commit needs a system that does not exist, it commits the
## part the resolver genuinely owns (player state, lock ticks, pending flags,
## the committed signal) and carries a `ponytail:` comment naming the row that
## finishes it. No placeholder subsystem is invented to stand in.

## §6.2's committed domain. UI, audio, VFX and dialogue subscribe to these and
## never to the raw events, because an event is a request and these are facts.
signal checkpoint_committed(id: StringName)
signal secret_revealed(id: StringName)
signal damage_committed(amount: int)
signal zone_entered(id: StringName)
signal chapter_advanced(chapter: int)

## Doc 00 §2.2's table and contract 11. Above every gameplay node (default 0) and
## `CombatDirector` (50), below `ZoneManager` (110) so residency changes land
## after this tick's state is committed rather than mid-resolution.
const PHYSICS_PRIORITY := 100

const TICK := 1.0 / 60.0

## Every gameplay duration is a tick count derived from its owning document's
## float constant (§2.4). The float is the authority; the integer is never typed
## out, because two hand-maintained numbers drift the first time either moves.
const FADE_DURATION := 0.35            ## §7.4 gated fade
const DOOR_WIPE_DURATION := 0.25       ## §7.6 interior door wipe
const SEAM_WIPE_DURATION := 0.12       ## §7.4 seam fallback wipe
const ARRIVAL_GRACE_DURATION := 0.15   ## §7.7 arrival grace
const BLACKOUT_DURATION := 0.6         ## Doc 02 §7.3 desaturate-and-cut

const FADE_TICKS := int(round(FADE_DURATION / TICK))
const DOOR_WIPE_TICKS := int(round(DOOR_WIPE_DURATION / TICK))
const SEAM_WIPE_TICKS := int(round(SEAM_WIPE_DURATION / TICK))
const ARRIVAL_GRACE_TICKS := int(round(ARRIVAL_GRACE_DURATION / TICK))
const BLACKOUT_TICKS := int(round(BLACKOUT_DURATION / TICK))

const VEHICLE_EXIT_SPEED := 20.0       ## §5.3 — dismount only below this speed

## Doc 06 §5.4: the inventory entry, never an `InputMap` edit, is what unlocks
## the verb (contract 34). A remap, a reload or a stale settings.cfg cannot
## grant or revoke it.
const JOURNAL_ITEM := &"journal_3"
const UV_ITEM := &"uv_penlight"

## Assigned by `SessionDirector.begin_session()` (§3.2) and by nothing else.
## Typed, because §4.1's own skeleton is written against `PlayerController`.
var player: PlayerController
## Duck-typed on purpose: `ZoneManager` is registered above this autoload in the
## shipped game but does not exist until tracker row 2.3, and a typed field
## against a missing class is a parse error.
var zone_manager: Node

var _pending_blackout := false
var _lock_ticks := 0                   ## > 0 means a transition owns the frame (§4.5)
var _arrival_grace_ticks := 0

## What the lock is carrying, handed to the destination on completion.
var _pending_zone: StringName = &""
var _pending_marker: StringName = &""
var _pending_teardown: Dictionary = {}
## §5.3: a vehicle crosses a boundary with the player, so a transition entered
## while `DRIVING` must not silently dismount on arrival. Everything else — a
## respawn's `BLACKOUT` included — returns `FREE` per §7.4 step 8.
var _state_before_lock: PlayerController.State = PlayerController.State.FREE

## Per-tick scratch, cleared at the top of every resolve.
var _zone_committed := false           ## a SEAMLESS activation committed (§7.8, §4.6)
var _damage_committed := false         ## §4.2 row 4 cancels the intents below it
var _committed: Array[RuntimeEvent] = []  ## consumed this tick; the rest may defer


func _ready() -> void:
	process_physics_priority = PHYSICS_PRIORITY
	# Doc 00 §12 check 15 / contract 11. Godot adds autoloads as root's first
	# children, so the default priority would resolve this BEFORE the scene tree
	# — the exact opposite of §4.1's frame contract. The frame contract is void
	# without this line, so it is asserted rather than merely written.
	assert(
		process_physics_priority > 0,
		"RuntimeDirector must resolve after every gameplay node (Doc 00 §2.2)"
	)


## §3.2 step 3. The resolver is inert until it has a player.
func bind(p: PlayerController) -> void:
	player = p


func _physics_process(_delta: float) -> void:
	if player == null:
		return
	RuntimeEvents.swap()   # 4a — everything published since the last resolve
	_poll_contacts()       # 4b
	_tick_durations()      # 4c
	_resolve()             # 4d + 4e
	_defer_survivors()     # 4f


## §4.1 step 4b / §4.3. Combat overlap is POLLED, not signal-driven, because the
## arrival order of an `area_entered` signal relative to this resolver is not a
## guarantee Godot makes. Polling is.
##
## `get_overlapping_areas()` reflects the world as of the last COMPLETED physics
## step — the physics server refreshes overlap lists after every
## `_physics_process` callback in the frame — so the resolver sees a hitbox on
## the tick AFTER it arms, whatever `process_physics_priority` says (contract
## 35). A dodge input published in frame N therefore beats a hitbox that armed
## in frame N, which is §4.3's rule and is intended.
# ponytail: empty hook — row 4.1 brings the first hitbox there is to poll.
func _poll_contacts() -> void:
	pass


## §4.1 step 4c. Tick counts, never `SceneTree` timers (§2.4): a timer mutates
## state outside the resolver, does not survive §10's pause predictably, and
## cannot be stepped by a headless test.
func _tick_durations() -> void:
	# PlayerController owns the fan-out to Health's i-frames, the Journal's
	# fumble, and the dodge and attack counters. One call site is what stops a
	# counter being decremented twice once rows 1.4, 1.5 and 1.9 fill it in.
	player.tick_durations()
	if _arrival_grace_ticks > 0:
		_arrival_grace_ticks -= 1
	if _lock_ticks > 0:
		_lock_ticks -= 1
		if _lock_ticks == 0:
			_release_lock()


func _resolve() -> void:
	_zone_committed = false
	_damage_committed = false
	_committed.clear()

	# Priority 0 — an in-flight transition or a blackout owns the frame.
	if _lock_ticks > 0 or player.state == PlayerController.State.BLACKOUT:
		_resolve_locked()
		return

	if _try_respawn():        return    # 1
	if _try_zone_travel():    return    # 2  — true ONLY when the commit took the
	                                    #      lock; seamless returns false and
	                                    #      resolution continues (§4.5)
	if _try_lethal():         return    # 3
	_try_damage()                       # 4  — cancels lower intents, does not skip them
	if _try_pause():          return    # 5
	if _try_cutscene():       return    # 6
	if _try_dodge():          return    # 7
	if _try_vehicle():        return    # 8
	if _try_attack():         return    # 9
	if _try_item_use():       return    # 10
	if _try_journal():        return    # 11
	if _try_journal_domain(): return    # 12  — UV toggle, radial commit, text submit
	_try_interact()                     # 13
	_try_passive()                      # 14
	_try_chapter_advance()              # 15  — always last


## Priority 0. The only events that may pass while locked.
func _resolve_locked() -> void:
	# Respawn is reachable ONLY here: BLACKOUT is itself a locked state, so
	# priority 1 in _resolve() would otherwise be dead code (§11.1).
	if RuntimeEvents.has(RuntimeEvent.Type.RESPAWN_REQUEST):
		_try_respawn()
		return
	_discard_locked_events()


## A gated transition ending is the lock's own completion, not an event — so
## there is nothing here to consume, and the next `swap()` drops the rest.
##
## The discard is the feature. No checkpoint, secret, anomaly or input may
## commit behind an opaque overlay (§6.3, §11.1), and destination triggers that
## fired their one `body_entered` at the spawn marker are re-polled by
## `ZoneManager` on completion (§4.6) rather than replayed from here.
func _discard_locked_events() -> void:
	pass


## §4.1 step 4f / §4.6. Exactly three things survive a lost tick; everything
## else is discarded and re-detected, which is correct for continuous facts —
## an anomaly the player is still standing in re-publishes next tick anyway, and
## a dropped `E` costs 16 ms.
func _defer_survivors() -> void:
	# Nothing survives the lock, including these three. §6.3 and §11.1 are
	# absolute: what is published behind an opaque overlay is discarded, and
	# deferring here would instead carry it across the whole transition and fire
	# it on arrival. The condition is re-read rather than remembered because a
	# gated commit at priority 2 takes the lock DURING this very tick.
	if _lock_ticks > 0 or player.state == PlayerController.State.BLACKOUT:
		return
	# §8.1 requires a cutscene request to survive a same-tick hit and a Journal
	# close; §9.4 never drops a chapter advance.
	_defer_uncommitted(RuntimeEvent.Type.CUTSCENE_REQUEST)
	_defer_uncommitted(RuntimeEvent.Type.CHAPTER_ADVANCE_REQUEST)
	if not _zone_committed:
		return
	# A destination checkpoint or secret that fired behind a SEAMLESS activation
	# was not suppressed by anything — the trigger fired legitimately, and
	# `body_entered` fires exactly once, so dropping it loses the checkpoint
	# until the player physically leaves and re-enters it.
	_defer_uncommitted(RuntimeEvent.Type.CHECKPOINT_REACHED)
	_defer_uncommitted(RuntimeEvent.Type.SECRET_REVEAL_REQUEST)


func _defer_uncommitted(type: RuntimeEvent.Type) -> void:
	for e in RuntimeEvents.take(type):
		if not _committed.has(e):
			RuntimeEvents.defer(e)


# --- 1. respawn -------------------------------------------------------------

## §11.2. Reads the in-memory checkpoint, never the disk (§9.3): a secret found
## ten seconds before dying survives the death.
func _try_respawn() -> bool:
	var e := RuntimeEvents.first(RuntimeEvent.Type.RESPAWN_REQUEST)
	if e == null:
		return false
	_committed.append(e)
	_pending_blackout = false

	var cp: Dictionary = GameState.data.checkpoint
	var to: StringName = cp.get(&"zone_id", &"")
	var marker: StringName = cp.get(&"spawn_marker", &"")

	# Step 3. A cross-zone respawn genuinely IS zone travel, which is why respawn
	# sits at priority 1 rather than being a special case: reusing §7.4 means it
	# is covered by the same tests. The overlay is already opaque, so no fade-out
	# is played — the lock runs the mount and the fade-in only.
	if to != &"" and zone_manager != null and to != zone_manager.current_zone:
		_begin_locked_travel(to, marker, FADE_TICKS, {})
	else:
		# ponytail: same-zone placement at checkpoint.position lands with the
		# spawn markers at row 2.7. The lock still runs the fade-in, so control
		# returns on the countdown rather than on a tween either way (§4.5).
		take_lock(FADE_TICKS)

	# Step 4. Health and stamina full, knockback cleared.
	if player.health != null:
		player.health.current = player.health.max_pips
	player.velocity = Vector2.ZERO
	# ponytail: `external_force` is cleared at row 1.4, Stamina refilled at 1.5,
	# the Journal forced CLOSED at 1.9 (§11.1 — no visible reopen).

	# ponytail: steps 5-7 — CombatDirector.reset() or §11.3's encounter restore,
	# enemy respawn, and AudioDirector's 1.0 s duck release — need rows 0.11,
	# 2.7 and 3.2. The state this row owns is committed above.
	return true


# --- 2. zone travel ---------------------------------------------------------

## Returns true only when the commit TOOK THE LOCK. A seamless activation
## commits and returns false, because a seamless crossing is not a transition:
## it removes no control, plays no fade, and must not behave like one in the
## resolver either. A player who walks across a seam into an enemy hitbox on the
## same tick takes the hit — a seam is not a shield (§4.5).
func _try_zone_travel() -> bool:
	var gated := RuntimeEvents.first(RuntimeEvent.Type.GATED_ZONE_REQUEST)
	if gated != null and _validate_zone_request(gated, false):
		_committed.append(gated)
		_arm_pending_blackout()
		# §7.6: a `DoorBoundary` is the same script with a 0.25 s wipe, so the
		# publisher names its own wipe and the default is §7.4's fade.
		var wipe: int = int(gated.payload.get(&"wipe_ticks", FADE_TICKS))
		_begin_locked_travel(
			gated.payload.get(&"to", &""),
			gated.payload.get(&"spawn_marker", &""),
			wipe,
			gated.payload.get(&"teardown", {})
		)
		return true

	var seam := RuntimeEvents.first(RuntimeEvent.Type.SEAM_FALLBACK_REQUEST)
	if seam != null and _validate_zone_request(seam, false):
		_committed.append(seam)
		_arm_pending_blackout()
		# The only transition a player can trigger by out-running the loader, and
		# logged so playtesting reveals whether Doc 3's STREAM_MARGIN needs
		# retuning rather than leaving it to feel (§7.4.1).
		push_warning("Seam fallback wipe to %s — the player beat the loader" % seam.payload.get(&"to", &""))
		_begin_locked_travel(
			seam.payload.get(&"to", &""),
			seam.payload.get(&"spawn_marker", &""),
			SEAM_WIPE_TICKS,
			seam.payload.get(&"teardown", {})
		)
		return true

	var seamless := RuntimeEvents.first(RuntimeEvent.Type.ZONE_ACTIVATION_REQUEST)
	if seamless != null and _validate_zone_request(seamless, true):
		_committed.append(seamless)
		_arm_pending_blackout()
		var to: StringName = seamless.payload.get(&"to", &"")
		# §7.2: activate_zone() is the single writer of current zone, palette
		# floor and BGM. Audio starts after the scene is resident and after real
		# entry, never during background loading (Doc 5 §11.5).
		zone_manager.activate_zone(to)
		zone_entered.emit(to)
		GameState.mark_dirty()   # §9.1 — a committed activation autosaves
		_zone_committed = true
	return false


## §7.3 step 4 and §7.8's failure list: Journal open, destination unavailable,
## locked, or the threshold not crossed. A failed validation means lethal damage
## resolves normally — there is no escape (§7.8).
func _validate_zone_request(e: RuntimeEvent, seamless: bool) -> bool:
	if zone_manager == null:
		return false
	var to: StringName = e.payload.get(&"to", &"")
	if to == &"" or to == zone_manager.current_zone:
		return false
	# §4.5: only FREE and DRIVING travel. The vehicle crosses with the player.
	if player.state != PlayerController.State.FREE \
			and player.state != PlayerController.State.DRIVING:
		return false
	# Contract 4 / §7.5: a Journal-open player cannot change zones. The boundary
	# blocks rather than auto-closing the book.
	if _journal_open():
		return false
	if not zone_manager.is_unlocked(to):
		return false
	# An open seam is what makes a crossing seamless in the first place (Doc 3
	# §3.1), so a gated request must NOT be tested against it — every interior
	# door would fail.
	if seamless and not zone_manager.is_seam_open(zone_manager.current_zone, to):
		return false
	# ponytail: "destination loaded" is unasked — ZoneManager has no public
	# residency query until row 2.3, and losing the race to the loader is what
	# SEAM_FALLBACK_REQUEST already exists to answer (§7.4.1).
	return true


## §7.8. A zone request committing at priority 2 beats lethal damage at priority
## 3, so the hit is recorded and served from the destination instead. Changing
## zones can save the player: a deliberate, testable mercy, not an accident of
## ordering.
func _arm_pending_blackout() -> void:
	if RuntimeEvents.has(RuntimeEvent.Type.LETHAL_DAMAGE):
		_pending_blackout = true


# --- 3. lethal --------------------------------------------------------------

func _try_lethal() -> bool:
	# §7.8: a zone commit this tick defers the blackout to the destination.
	if _zone_committed:
		return false
	# The deferred blackout begins once arrival is stable — the lock is gone and
	# §7.7's grace has run out — never on the tick the transition committed.
	if _pending_blackout and _lock_ticks == 0 and _arrival_grace_ticks == 0:
		begin_blackout()
		return true
	var e := RuntimeEvents.first(RuntimeEvent.Type.LETHAL_DAMAGE)
	if e == null:
		return false
	_committed.append(e)
	begin_blackout()
	return true


## §11.1, and a named lock entry point so §12 check 20 can drive it. The
## blackout's presentation (desaturate over 0.6 s, Dipper crumples, cut to
## black) mirrors this countdown and has no authority over it.
func begin_blackout() -> void:
	_pending_blackout = false
	# §5.3: lethal damage while driving forces an exit at the vehicle's position
	# first, so the save/checkpoint anchor is a body standing on ground.
	_exit_vehicle()
	player.state = PlayerController.State.BLACKOUT
	_lock_ticks = BLACKOUT_TICKS
	# ponytail: the Journal is forced CLOSED with no visible reopen at row 1.9,
	# and Doc 5 §5.6's 24 dB Master duck lands at row 3.2.


# --- 4. damage --------------------------------------------------------------

## The first of §4.1's two deliberate exceptions: this applies and then CANCELS
## the intents below it, rather than ending the tick and skipping them silently.
func _try_damage() -> bool:
	var events := RuntimeEvents.take(RuntimeEvent.Type.DAMAGE)
	if events.is_empty():
		return false

	var total := 0
	for e in events:
		# §4.3: multiple sources in one tick resolve as ONE hit. Doc 2 §7.1's
		# i-frame flag is set on the first commit and drops the second in the
		# same tick, so the resolver leans on that instead of deduplicating.
		_committed.append(e)
		var amount := int(e.payload.get(&"amount", 1))
		if _apply_damage(amount):
			total += amount
	if total == 0:
		# Every source was refused — an active i-frame window, most likely, which
		# is exactly what §4.3 means by "an already-active dodge protects".
		return false

	_damage_committed = true
	match player.state:
		PlayerController.State.DRIVING:
			# §5.3: damage transfers to Health normally, knockback goes to the
			# vehicle, and the player keeps driving.
			pass
		PlayerController.State.JOURNAL:
			# §5.2: damage while reading fumbles the book — 0.80 s, and it fits
			# inside the 0.90 s i-frame window on purpose (Doc 2 §7.1).
			player.state = PlayerController.State.FUMBLING
		_:
			player.state = PlayerController.State.HURT
	damage_committed.emit(total)
	return true


func _apply_damage(amount: int) -> bool:
	if player.health != null and player.health.has_method(&"take_damage"):
		return player.health.take_damage(amount)
	# ponytail: no Health node until row 1.5. Without one there are no i-frames
	# to refuse the hit, so the commit stands and §4.2 row 4's cancellation —
	# which is what this row is gated on — is still exercised.
	return true


# --- 5. pause ---------------------------------------------------------------

## §10. Pause is not a state; it is `get_tree().paused`, orthogonal to §5.1's
## enum. A request in a forbidden state is DROPPED, never queued: a pause that
## fires 0.4 s later, after the fade finished, reads as an input bug.
func _try_pause() -> bool:
	var e := RuntimeEvents.first(RuntimeEvent.Type.PAUSE_REQUEST)
	if e == null:
		return false
	_committed.append(e)
	if player.state == PlayerController.State.CUTSCENE \
			or player.state == PlayerController.State.ZONE_TRANSITION \
			or player.state == PlayerController.State.BLACKOUT:
		# ponytail: Doc 5 §5.6's ui_denied cue plays instead, from row 3.4.
		return false
	# ponytail: the menu opens itself at row 3.8. The pause menu is the only
	# legal `get_tree().paused = true` (§10, Doc 4 §7.2) — never the resolver.
	return true


# --- 6. cutscene ------------------------------------------------------------

func _try_cutscene() -> bool:
	var e := RuntimeEvents.first(RuntimeEvent.Type.CUTSCENE_REQUEST)
	if e == null:
		return false
	# §8.1 steps 2-3: same-tick damage resolves first. The request remains
	# pending and is carried by §4.6 rather than dropped.
	if _damage_committed:
		return false
	# §8.1 step 4: a Journal that is not CLOSED performs one normal close first,
	# and never reopens afterwards.
	if _journal_open():
		# ponytail: row 1.9 starts that close; until the Journal node exists the
		# request simply waits, which is the same observable behaviour.
		return false
	_committed.append(e)
	player.state = PlayerController.State.CUTSCENE
	# ponytail: CutsceneDirector.request() at row 0.11 owns the dialogue, the
	# camera, the return to FREE, and the `on_complete_flag` write that keeps an
	# interrupted cutscene from leaving a half-set world (§8.2).
	return true


# --- 7. dodge ---------------------------------------------------------------

func _try_dodge() -> bool:
	var e := RuntimeEvents.first(RuntimeEvent.Type.DODGE_REQUEST)
	if e == null:
		return false
	# §4.2 row 7: begins only if no hit connected this tick.
	if _damage_committed:
		return false
	if player.state != PlayerController.State.FREE \
			and player.state != PlayerController.State.JOURNAL:
		return false
	_committed.append(e)
	# ponytail: §5.2's forced Journal close — immediate, and explicitly NOT the
	# 0.80 s damage fumble — lands with the Journal node at row 1.9, and the
	# impulse, the 0.05-0.26 s i-frame window and the 25 stamina cost at rows
	# 4.2 and 1.5.
	player.state = PlayerController.State.DODGING
	return true


# --- 8. vehicles ------------------------------------------------------------

## §5.3. The cart is a possessed body, not a mount: Doc 3 §7 owns its handling,
## this document owns the ownership transfer.
func _try_vehicle() -> bool:
	var board := RuntimeEvents.first(RuntimeEvent.Type.VEHICLE_BOARD_REQUEST)
	if board != null:
		_committed.append(board)
		# Journal-open players cannot board, same affordance as the boundary
		# blocker (§5.2, contract 4).
		if player.state == PlayerController.State.FREE and not _journal_open():
			player.state = PlayerController.State.DRIVING
			# ponytail: row 4.5 disables the player's collision and Interactor,
			# retargets the camera, auto-boards the companion and starts Doc 5
			# §5.2's engine layers. Interact-range re-verification belongs there
			# too — the vehicle is the only node that knows its own mount point.
			return true
		return false

	var leave := RuntimeEvents.first(RuntimeEvent.Type.VEHICLE_EXIT_REQUEST)
	if leave != null:
		_committed.append(leave)
		if player.state == PlayerController.State.DRIVING \
				and player.velocity.length() < VEHICLE_EXIT_SPEED:
			_exit_vehicle()
			return true
	return false


## §5.3's reverse, and the one commit the resolver owns in it.
# ponytail: player state only — row 4.5 places Dipper at the dismount marker on
# walkable ground and restores collision, camera and companion.
func _exit_vehicle() -> void:
	if player.state == PlayerController.State.DRIVING:
		player.state = PlayerController.State.FREE


# --- 9. attack --------------------------------------------------------------

func _try_attack() -> bool:
	var e := RuntimeEvents.first(RuntimeEvent.Type.ATTACK_REQUEST)
	if e == null:
		return false
	if _damage_committed:
		return false
	if player.state != PlayerController.State.FREE:
		return false
	_committed.append(e)
	player.state = PlayerController.State.ATTACKING
	# ponytail: Doc 2 §4's windup + active + recovery counts, and the hitbox on
	# the animation call track that arms with them, are row 4.1's. The state this
	# row owns is set; the return to FREE on recovery end arrives with it.
	return true


# --- 10. item use -----------------------------------------------------------

func _try_item_use() -> bool:
	var e := RuntimeEvents.first(RuntimeEvent.Type.ITEM_USE_REQUEST)
	if e == null:
		return false
	# §4.2 row 10: the horn and thrown items work from the driver's seat.
	if player.state != PlayerController.State.FREE \
			and player.state != PlayerController.State.JOURNAL \
			and player.state != PlayerController.State.DRIVING:
		return false
	_committed.append(e)
	# An item the player does not hold is refused here, not left unbound —
	# contract 34, the same gate as rows 11 and 12.
	if not _holds(e.payload.get(&"item", &"")):
		return false
	# ponytail: the effects themselves are per-item and land with the items
	# (rows 3.7 and P5). The resolver owns the gate, which is what §4.2 row 10 is.
	return true


# --- 11. journal ------------------------------------------------------------

func _try_journal() -> bool:
	var e := RuntimeEvents.first(RuntimeEvent.Type.JOURNAL_TOGGLE_REQUEST)
	if e == null:
		return false
	if _damage_committed:
		return false
	_committed.append(e)
	# Contract 34: `J` is bound at boot like every other action; holding Journal
	# 3 is the whole gate, so the verb survives a remap and a stale settings.cfg.
	if not _holds(JOURNAL_ITEM):
		return false
	if player.state == PlayerController.State.JOURNAL:
		# §5.2: `J` from OPEN starts the normal close, and is ignored during
		# OPENING, CLOSING and FUMBLED.
		# ponytail: row 1.9 owns those sub-states and holds the player in JOURNAL
		# through the 0.30 s CLOSING; with no Journal node the close is instant.
		player.state = PlayerController.State.FREE
		return true
	if player.state != PlayerController.State.FREE:
		# §5.2's ignore list: ATTACKING, DRIVING, CUTSCENE, ZONE_TRANSITION,
		# BLACKOUT — and HURT/FUMBLING/DODGING accept no input at all (§5.1).
		return false
	player.state = PlayerController.State.JOURNAL
	# ponytail: the 0.42 s OPENING and Doc 1 §7's journal_raise are row 1.9's.
	return true


# --- 12. journal domain -----------------------------------------------------

## UV toggle, radial commit and text submit. They can lose, and that is correct:
## a hit at priority 4 cancels a submission along with every other Journal-domain
## intent, the typed text stays in the field, and the player resubmits after the
## fumble. A UI that committed directly would have written to the save mid-fumble
## (§8.3).
func _try_journal_domain() -> bool:
	if _damage_committed:
		return false

	var uv := RuntimeEvents.first(RuntimeEvent.Type.UV_TOGGLE_REQUEST)
	if uv != null:
		_committed.append(uv)
		if player.state == PlayerController.State.JOURNAL and _holds(UV_ITEM):
			# ponytail: the beam, its Weirdness pulse and the overlay are rows
			# 2.9 and 3.7. `Weirdness.pulse()` needs no resolver route (§6.2).
			return true
		return false

	var select := RuntimeEvents.first(RuntimeEvent.Type.ITEM_SELECT_REQUEST)
	if select != null:
		_committed.append(select)
		if player.state == PlayerController.State.FREE \
				or player.state == PlayerController.State.JOURNAL:
			# ponytail: the radial itself is Deferred D6; row 3.7's item cycle
			# publishes this event and reads the committed selection back.
			return true
		return false

	var submit := RuntimeEvents.first(RuntimeEvent.Type.JOURNAL_SUBMIT_REQUEST)
	if submit != null:
		_committed.append(submit)
		if player.state != PlayerController.State.JOURNAL:
			return false
		var kind: StringName = submit.payload.get(&"kind", &"")
		# `kind` is a closed set. An unrecognised value is rejected here rather
		# than dispatched, because a second event type would mean a second path
		# to audit (§8.3).
		if kind != &"weakness" and kind != &"cipher":
			push_error("JOURNAL_SUBMIT_REQUEST has an unrecognised kind: %s" % kind)
			return false
		# ponytail: the dispatch to JournalDB.submit_weakness() (row 1.12) or
		# Cipher/CipherLock (row 1.11), the mark_dirty, and the
		# `journal_submit_committed(kind, target, accepted)` signal the pane
		# reacts to all land with those rows. Nothing here may write the save
		# early — an unverified answer written now is worse than none.
		return true
	return false


# --- 13. interact -----------------------------------------------------------

## §6.1. `Interactor` chooses the best target by range and facing and publishes;
## the resolver re-verifies at commit time, because the target may have moved or
## despawned since the intent was published.
func _try_interact() -> bool:
	var e := RuntimeEvents.first(RuntimeEvent.Type.INTERACT_REQUEST)
	if e == null:
		return false
	# §4.4: `E` plus a non-lethal hit means damage applies and the interaction is
	# cancelled. Doc 00 §12 check 4.
	if _damage_committed:
		return false
	if player.state != PlayerController.State.FREE:
		return false
	_committed.append(e)
	var target: Variant = e.payload.get(&"target")
	if not (target is Node) or not is_instance_valid(target):
		return false
	if not target.get(&"enabled"):
		return false
	# Range and facing are re-verified through the Interactor itself, which
	# recomputed its best target this very tick (§4.1 step 2) and owns Doc 2 §8's
	# RADIUS, FORWARD_OFFSET and FACING_WEIGHT. Copying those three numbers here
	# would be two sets of tuning that drift the first time either moves (§0.1).
	var interactor := player.get_node_or_null(^"Interactor")
	if interactor != null and interactor.get(&"current") != target:
		return false
	if target.has_method(&"can_interact") and not target.can_interact(player):
		return false
	target.interact(player)
	return true


# --- 14. passive progression ------------------------------------------------

func _try_passive() -> bool:
	if not can_process_world_triggers():
		return false
	var committed := false

	for e in RuntimeEvents.take(RuntimeEvent.Type.CHECKPOINT_REACHED):
		_committed.append(e)
		var id: StringName = e.payload.get(&"id", &"")
		GameState.data.checkpoint = {
			&"id": id,
			&"zone_id": e.payload.get(&"zone_id", &""),
			&"spawn_marker": e.payload.get(&"spawn_marker", &""),
			&"wake_line_id": e.payload.get(&"wake_line_id", &""),
			# §9.2: the marker is authoritative and the raw coordinate is the
			# fallback for a mid-zone checkpoint the player walked into.
			&"position": e.payload.get(&"position", Vector2.ZERO),
			# §11.3: a checkpoint carries whatever encounter is armed when it is
			# TAKEN, so a player who returns after winning wakes in an empty
			# clearing rather than a resurrected fight.
			&"encounter": GameState.data.checkpoint.get(&"encounter", {}),
		}
		GameState.mark_dirty()   # §9.1 — autosave, flushed off the physics frame
		checkpoint_committed.emit(id)
		committed = true

	for e in RuntimeEvents.take(RuntimeEvent.Type.ENCOUNTER_STATE_REQUEST):
		_committed.append(e)
		# An empty payload clears; a populated one arms. Committing at 14 means
		# a player who dies on the exact tick a phase begins respawns at the
		# PREVIOUS phase, never a half-armed new one (§11.3).
		# ponytail: rejecting an arm whose `setup` was never registered needs
		# CombatDirector's phase-setup registry — rows 0.11 and 4.6. Until then
		# an unregistered name is written rather than refused, which §12 check 28
		# is what will catch.
		GameState.data.checkpoint[&"encounter"] = e.payload.duplicate(true)
		GameState.mark_dirty()
		committed = true

	for e in RuntimeEvents.take(RuntimeEvent.Type.SECRET_REVEAL_REQUEST):
		_committed.append(e)
		var id: StringName = e.payload.get(&"id", &"")
		if id != &"" and not GameState.data.secrets_found.has(id):
			GameState.data.secrets_found.append(id)
			GameState.mark_dirty()
		secret_revealed.emit(id)
		committed = true

	for e in RuntimeEvents.take(RuntimeEvent.Type.ANOMALY_ENTERED):
		_committed.append(e)
		committed = true
	for e in RuntimeEvents.take(RuntimeEvent.Type.ANOMALY_EXITED):
		_committed.append(e)
		committed = true
	# ponytail: an anomaly's per-tick force integration stays in AnomalyField's
	# own _physics_process — §6.2's one scoped exception — and its Weirdness
	# pulse needs no resolver route either. Consuming the fact here is all the
	# resolver owes it until row 2.9 gives it zone progression to gate.

	return committed


## §6.3. During a gated transition the destination scene may instantiate and its
## Area2Ds may overlap Dipper at the spawn marker. The game must never award a
## checkpoint, secret or anomaly effect while the screen is fading.
func can_process_world_triggers() -> bool:
	return _lock_ticks == 0 and player.state != PlayerController.State.ZONE_TRANSITION \
		and player.state != PlayerController.State.BLACKOUT


# --- 15. chapter advance ----------------------------------------------------

## Always last, so a chapter advance never lands mid-resolution and never
## changes a gate another `_try_*` already read this tick (§9.4 rule 2).
func _try_chapter_advance() -> bool:
	var e := RuntimeEvents.first(RuntimeEvent.Type.CHAPTER_ADVANCE_REQUEST)
	if e == null:
		return false
	_committed.append(e)
	var current: int = GameState.data.chapter
	var to := int(e.payload.get(&"to", 0))
	var from := int(e.payload.get(&"from", current))
	# §9.4 rule 1: `chapter` is monotonic, and Chapter Select uses §9.5's scratch
	# save rather than this event. A rejected request is consumed rather than
	# deferred — carrying it forward would re-fire this push_error every tick.
	if to != from + 1 or to != current + 1:
		push_error(
			"CHAPTER_ADVANCE_REQUEST must be exactly +1: to=%d from=%d chapter=%d"
			% [to, from, current]
		)
		return false
	GameState.data.chapter = to
	GameState.mark_dirty()   # §9.1
	chapter_advanced.emit(to)
	# ponytail: ZoneManager re-evaluating residency so a seam opens LIVE, without
	# a transition (§9.4 rule 3), is row 2.3's — it subscribes to this signal.
	return true


# --- the transition lock ----------------------------------------------------

## §3.2 step 5's boot lock, and the same-zone respawn's. The lock is a tick
## countdown, never a tween: the overlay mirrors it and has no authority over
## gameplay state (contract 21). Boot does not await an animation to decide when
## gameplay starts.
func take_lock(ticks: int) -> void:
	_state_before_lock = player.state
	_lock_ticks = maxi(ticks, 0)
	player.state = PlayerController.State.ZONE_TRANSITION


## §7.4's gated sequence, and §12 check 20's first entry point.
func begin_gated_transition(to: StringName, marker: StringName,
		teardown: Dictionary = {}) -> void:
	_begin_locked_travel(to, marker, FADE_TICKS, teardown)


## §7.6's interior door — the same sequence with a 0.25 s wipe. Check 20's
## second entry point.
func begin_door_transition(to: StringName, marker: StringName,
		teardown: Dictionary = {}) -> void:
	_begin_locked_travel(to, marker, DOOR_WIPE_TICKS, teardown)


## Doc 3 §3.3's grace wipe: the one transition a player can trigger by
## out-running the loader.
func begin_seam_fallback(to: StringName, marker: StringName,
		teardown: Dictionary = {}) -> void:
	_begin_locked_travel(to, marker, SEAM_WIPE_TICKS, teardown)


func _begin_locked_travel(to: StringName, marker: StringName, wipe_ticks: int,
		teardown: Dictionary) -> void:
	_pending_zone = to
	_pending_marker = marker
	_pending_teardown = teardown
	# §4.5: fade out, mount, fade in. If the mount finishes early the lock is
	# truncated to the remaining fade; if it overruns the lock extends and the
	# overlay simply holds opaque. Gameplay never resumes because an animation
	# finished — it resumes because the resolver says so.
	take_lock(wipe_ticks * 2 + _mount_budget_ticks(to))
	# ponytail: TransitionDirector.play_fade(wipe_ticks) — presentation only —
	# is row 0.11's, and ZoneManager's free/load/place is row 2.3's.


## §4.5's mount budget.
# ponytail: 0 until row 2.3 — ZoneManager owns the load and has no public budget
# query yet, so the lock is the two wipes alone.
func _mount_budget_ticks(_to: StringName) -> int:
	return 0


## The countdown reaching zero is what returns control — the same path for a
## gated transition, a door wipe, boot and a respawn, so boot is not a special
## case with its own release rule (§3.2, §12 check 20).
func _release_lock() -> void:
	if player.state == PlayerController.State.BLACKOUT:
		# §11.2 step 1. The blackout's own countdown completing is not an event,
		# so the resolver publishes the respawn it is waiting for; without this
		# the player never wakes (§11.1) and §12 check 19 deadlocks.
		RuntimeEvents.enqueue(RuntimeEvent.Type.RESPAWN_REQUEST, self)
		return
	_complete_transition()
	player.state = PlayerController.State.DRIVING \
		if _state_before_lock == PlayerController.State.DRIVING \
		else PlayerController.State.FREE
	# §7.7: control returns first, then an authored arrival story may take it.
	# This is what guarantees dialogue never starts underneath the overlay.
	_arrival_grace_ticks = ARRIVAL_GRACE_TICKS


## §7.4 steps 5a-6, in that order and behind an opaque overlay: the teardown
## runs while nothing is visible and no trigger is armed, so a half-torn-down
## world is never on screen for a frame.
func _complete_transition() -> void:
	if _pending_zone == &"":
		return
	_apply_teardown(_pending_teardown)
	if zone_manager != null:
		zone_manager.activate_zone(_pending_zone)
	zone_entered.emit(_pending_zone)
	GameState.mark_dirty()   # §9.1
	# ponytail: `_pending_marker` is the destination spawn point. ZoneManager
	# consumes it at row 2.3, where the mount and the placement live; it is
	# carried rather than dropped because it is the request's own payload.
	_pending_zone = &""
	_pending_marker = &""
	_pending_teardown = {}


## §7.4.1. A chapter DECLARES its transition-time state changes as plain data
## and never performs them: a `Callable` here would be a hole straight back
## through §14.1, at the one moment nothing can observe it.
# ponytail: a payload Dictionary rather than the Resource §7.4.1 sketches —
# tracker D1, until a second chapter declares one. Row 2.8 owns this handling;
# what is committed here is what the resolver already owns today.
func _apply_teardown(teardown: Dictionary) -> void:
	if teardown.is_empty():
		return
	if teardown.get(&"exit_vehicle", false):
		_exit_vehicle()
	if teardown.get(&"restore_health", false) and player.health != null:
		player.health.current = player.health.max_pips
	if teardown.get(&"release_weirdness", false):
		Weirdness.release()   # event level → 0; the zone floor takes over
	if teardown.get(&"clear_pending_blackout", false):
		_pending_blackout = false
	var checkpoint: Dictionary = teardown.get(&"set_checkpoint", {})
	if not checkpoint.is_empty():
		GameState.data.checkpoint = checkpoint.duplicate(true)
		GameState.mark_dirty()
	# ponytail: `clear_combat` — boss_active/id/phase to zero and aggro cleared —
	# needs CombatDirector, row 0.11.


# --- shared predicates ------------------------------------------------------

## "Not CLOSED", in the Journal's own words (§5.2, §7.5): true for OPENING,
## OPEN, CLOSING and FUMBLED. The Journal is a node on the player and never an
## autoload (§2.2, contract 30), and it arrives at row 1.9 — until then nothing
## blocks, which is the same answer a CLOSED book gives.
func _journal_open() -> bool:
	if player.journal == null or not player.journal.has_method(&"blocks_zone_travel"):
		return false
	return player.journal.blocks_zone_travel()


## Contract 34: an unearned verb is refused here, never by leaving an InputMap
## action unbound.
func _holds(item: StringName) -> bool:
	if item == &"":
		return false
	return int(GameState.data.inventory.get(item, 0)) > 0
