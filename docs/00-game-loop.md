# DOCUMENT 00 — Game Loop, Runtime Events & Session Lifecycle

**Consumes:** `foundation.md`, Documents 1–5
**Feeds:** Documents 6–25 (every chapter)
**Purpose:** The implementation contract for Godot 4.x / GDScript. This document defines *when* systems run, which system owns each transition, what wins when several things happen in the same physics tick, and how a session begins, persists, fails, and ends.

This is the foundational runtime document. Where it conflicts with Documents 1–5, this document wins — §0.2 names every specific override rather than claiming a blanket one.

---

## 0. How to read this document

### 0.1 References, not restatements

Tuning constants live in exactly one document each. Doc 00 references them and never copies them, because a duplicated constant is a constant that will drift.

| Value | Owner | Doc 00 uses it in |
|---|---|---|
| Journal speed, walk/run/sneak speeds | Doc 2 §3.1 | §5 state table |
| `OPEN_TIME` 0.42 / `CLOSE_TIME` 0.30 / `FUMBLE_DURATION` 0.80 | Doc 2 §5.1 | §5.2 Journal machine |
| `IFRAME_DURATION` 0.90, health pips, knockback | Doc 2 §7.1 | §4.3 hit resolution |
| `SCAN_DURATION` 1.40, range, cone | Doc 2 §5.4 | §6.4 scan cancellation |
| Dodge impulse, i-frame window, stamina cost | Doc 2 §3.4 | §4.3 |
| `DEPTH_RATIO` 0.62 | Doc 2 §12.1 | anything positional |
| `CELL`, `STREAM_MARGIN`, `UNLOAD_MARGIN`, `SEAM_BLOCK_GRACE` | Doc 3 §3.2 | §7 zone travel |
| Zone grid, adjacency, `seam_chapter`, `unlock_chapter` | Doc 3 §1 | §7, §9 |
| `ZONE_CROSSFADE` 2.5 s, ducking table | Doc 5 §3, §8 | §7.3, §7.4 |
| `Weirdness` API (`set_zone_floor`, `pulse`, `release`) | Doc 1 §2.1 | §7.3 |
| HUD fade timings, dialogue mode rules | Doc 4 §2.7, §3.2 | §11 |

If a number appears in this document without a citation, this document owns it.

### 0.2 Named supersessions

Docs 1–5 contain illustrative snippets that mutate state directly from Godot callbacks. Those snippets are superseded here. The *design intent* of each is preserved exactly; only the call path changes.

**This table is a changelog, not a mechanism.** Every row below has been applied *in place* in the source document as well — Docs 1–5 no longer contain the superseded text. That rule exists because the halfway position is where drift hides: superseding `PlayerController.State` while leaving Doc 2's `match` statement consuming the old six values produced a controller that silently coasted through four states, inside a section already marked superseded and therefore already looking handled. A builder reading Doc 2 top to bottom must never find a superseded-notice comment sitting above text that is still wrong. **Anything this document supersedes gets fixed at the source and recorded here — never referenced and left standing.**

| Superseded | Replaced by | Nature of change |
|---|---|---|
| Doc 2 §3.3 `PlayerController.State` (6 states) | §5.1 (10 states) | Adds `ATTACKING`, `DRIVING`, `ZONE_TRANSITION`, `BLACKOUT` — **and Doc 2's `_physics_process` `match` now has an arm for each** |
| Doc 2 §3.5 `scan` bound to "Hold J + `attack`" | Doc 2 §3.5 | `InputMap` has no chord action. `scan` is a first-class action on `Left Shift` / RT |
| Doc 2 §5.4 `Scanner._best_target()` polling bodies | Doc 2 §5.4 | Scannables are `Area2D`s; `get_overlapping_bodies()` could never return one |
| Doc 4 §2.1 HUD reading `GameState.health` / `.stamina` | Doc 4 §2.1, §14 below | Live state belongs to the player node, not the persistence autoload |
| Doc 1 §2.1 `Weirdness.level` as the value systems read | Doc 1 §2.1 | Split into `target_level` (where the tween is headed) and `applied` (where it is) |
| Doc 3 §1.1 `ZoneDef.seam_chapter` | Doc 3 §1.1 `SeamLink` | Per-edge data moved off the per-zone field |
| Doc 3 §2.1 `WeirdnessGrade` in the per-zone layer stack | Doc 1 §2.1, §3.2 below | Exactly one grade, on `world_root`, bound by `begin_session()` |
| Doc 5 §7.1 placeholder bake at startup | Doc 5 §7.1 | Moved offline to `tools/bake_placeholders.gd`; boot loads committed WAVs |
| Doc 2 §5.2 `Journal.on_owner_damaged()` timer | §5.2, §2.4 | `create_timer` → resolver-counted ticks |
| Doc 2 §7.1 `Health.take_damage()` i-frame timer | §2.4 | Same |
| Doc 2 §8 `Interactor._unhandled_input()` direct `interact()` | §6.1 | Direct call → `INTERACT_REQUEST` |
| Doc 3 §3.1 `ZoneBoundary._on_entered()` direct `gated_transition()` | §7.5 | Direct call → `GATED_ZONE_REQUEST` |
| Doc 3 §3.2 `ZoneManager.set_current()` | §7.2 `activate_zone()` | Renamed; single commit path |
| Doc 3 §8 `DoorTransition`, "no zone-manager involvement" | §7.6 | Interiors are `ZoneDef`s with streaming disabled |
| Doc 4 §3.1 `DialogueLine.pause_player` | §8.4 | Field removed; author a `CUTSCENE_REQUEST` |
| Docs 2 §5.2 / 3 §6 `SfxBus.play()` | §2.3 | Name corrected to `AudioDirector.play_sfx()` |
| Doc 4 §2.7 `BossDirector.active` | §2.3 | Folded into `CombatDirector.boss_active` |

Doc 1 is not superseded anywhere. Its tokens, rigs, and `Weirdness` autoload stand as written.

---

## 1. Player-facing loop

```text
Explore → notice threat, anomaly, clue, or blocked path
→ investigate with the Journal, UV light, scan, or an item
→ learn a weakness / reveal a secret / solve a route
→ survive the consequence and gain knowledge, access, or story progress
→ enter the next space and repeat
```

The Journal is deliberately part of the live loop, not a safe pause screen. Knowledge creates advantage, but obtaining it costs time, movement speed, and attention. Doc 2 §12.6's "the world never pauses" is the rule that makes this real, and §10 of this document is the only exception to it.

---

## 2. Architecture

### 2.1 Ownership and signal direction

No gameplay system calls another system's state setter from an `Area2D.body_entered`, `area_entered`, or hitbox callback. Those callbacks only publish facts.

```text
Godot callbacks / input / animation call tracks
                    ↓
            RuntimeEvents.enqueue()
                    ↓
      RuntimeDirector resolves one tick
                    ↓
 PlayerController / Journal / ZoneManager commit state
                    ↓
     UI, Audio, VFX, dialogue react to committed signals
```

### 2.2 Autoloads, in registration order

Registration order is load-bearing: an autoload may only reference autoloads registered above it during `_ready()`.

| # | Autoload | `process_physics_priority` | Owns |
|---:|---|---:|---|
| 1 | `Tokens` | — | Doc 1 constants, expression presets |
| 2 | `Weirdness` | — | Doc 1 §2.1. Single supernatural-intensity float |
| 3 | `Settings` | — | Doc 4 §5.1 accessibility + Doc 4 §7.3 options. Own file, never in a save |
| 4 | `GameState` | — | §9. Persistent chapter, flags, inventory, entries, checkpoints, save I/O |
| 5 | `RuntimeEvents` | — | §2.5. Double-buffered event queue. Has no `_physics_process` at all |
| 6 | `AudioDirector` | — | Doc 5. BGM racks, crossfade, buses, SFX |
| 7 | `CombatDirector` | 50 | §2.3. Aggro set, `threat_active`, boss phase |
| 8 | `CutsceneDirector` | — | §8. Queued/active cutscenes, `CUTSCENE` ownership |
| 9 | `TransitionDirector` | — | §7.4. Overlay fades, gated-travel coroutine |
| 10 | `ZoneManager` | 110 | Doc 3 §3.2 + §7.2. Residency, `activate_zone()`, streaming |
| 11 | `SessionDirector` | — | §3. Boot, world root, player instancing, session begin/end |
| 12 | `RuntimeDirector` | **100** | §4. Priority resolution and cross-system sequencing |

**`Journal` is deliberately absent from this table, and must stay absent.** It is a node on the player, reached as `RuntimeDirector.player.journal`. In Godot 4 an autoload named `Journal` and a `class_name Journal` collide on one global identifier and the engine errors, so `Journal.state` (instance) and `Journal.FUMBLE_DURATION` (constant) could never both resolve. The timings live in a static `JournalConst` (Doc 2 §5.2); the state lives on the node. Same rule for `Health` and `Stamina` — nodes on the player, never globals.

**The priority numbers are not decoration.** Godot adds autoloads as root's first children, so by default they `_physics_process()` *before* the scene tree — the exact opposite of what §4's frame contract requires. `RuntimeDirector` must run after every body has moved and every trigger has published. Pin these values in each script's `_ready()`:

```gdscript
func _ready() -> void:
    process_physics_priority = 100      # after all gameplay nodes (default 0)
```

`ZoneManager` streams at 110 so residency changes land after the tick's state is committed, never mid-resolution.

### 2.3 `CombatDirector`

Doc 4 §2.7 and §3.2 both read combat state that no document defined. It lives here.

```gdscript
# res://autoload/combat_director.gd — Autoload "CombatDirector"
extends Node

signal threat_changed(active: bool)
signal boss_phase_changed(boss_id: StringName, phase: int)

## Referenced, never copied — §0.1's rule applied to itself. A duplicated 4.0
## here and in Doc 4 is two numbers that will drift the first time either moves.
const THREAT_LINGER := HudVisibility.IDLE_HIDE_DELAY   ## Doc 4 §2.7

var threat_active: bool = false      ## Doc 4 §2.7, §3.2 read this
var boss_active: bool = false        ## replaces Doc 4's BossDirector.active
var boss_id: StringName = &""
var boss_phase: int = 0              ## Doc 5 §4.2 gates boss_bill stems on this

var _aggro: Dictionary = {}          # enemy instance id -> ticks since last aggro
```

An enemy registers on aggro and deregisters on death or de-aggro. `threat_active` is true while `_aggro` is non-empty, and stays true for `THREAT_LINGER` after it empties — so the HUD does not blink off between waves and Doc 4 §3.2 does not flip a mid-fight line back to a box.

`boss_phase` is the sole input to Doc 5 §4.2's stem gating. Chapter docs advance it; they never touch `AudioDirector` stems directly.

### 2.4 No `SceneTree` timers for gameplay state

Doc 2 §5.2 and §7.1 use `get_tree().create_timer(...).timeout.connect(...)`. That pattern breaks three ways: it mutates state outside the resolver, it does not survive §10's pause predictably, and it cannot be stepped by §12's headless tests.

**Every gameplay duration is counted in physics ticks by the system that owns it, decremented in its resolver-invoked `tick()`.** Presentation-only timers (a tween on a HUD element, a shader fade) may still use tweens freely.

```gdscript
const TICK := 1.0 / 60.0
const FUMBLE_TICKS := int(round(JournalConst.FUMBLE_DURATION / TICK))   # Doc 2 §5.1 → 48
```

Durations are always derived from the owning document's float constant, never re-entered as an integer literal.

### 2.5 Event record

```gdscript
# res://core/runtime_event.gd
class_name RuntimeEvent
extends RefCounted

enum Type {
	# --- lifecycle & travel ------------------------------------------------
	ZONE_ACTIVATION_REQUEST,   # seamless: activation volume crossed
	GATED_ZONE_REQUEST,        # gated: boundary entered, fade required
	SEAM_FALLBACK_REQUEST,     # Doc 3 §3.3 grace wipe — loader lost the race
	RESPAWN_REQUEST,           # blackout complete, return at checkpoint
	CHAPTER_ADVANCE_REQUEST,   # §9.4

	# --- forced ------------------------------------------------------------
	LETHAL_DAMAGE,
	DAMAGE,
	CUTSCENE_REQUEST,

	# --- player intents ----------------------------------------------------
	PAUSE_REQUEST,
	DODGE_REQUEST,
	VEHICLE_BOARD_REQUEST,
	VEHICLE_EXIT_REQUEST,
	ATTACK_REQUEST,
	ITEM_USE_REQUEST,
	ITEM_SELECT_REQUEST,       # radial commit, Doc 4 §6.3
	JOURNAL_TOGGLE_REQUEST,
	JOURNAL_SUBMIT_REQUEST,    # player text: a weakness or a cipher answer (§8.3)
	UV_TOGGLE_REQUEST,
	INTERACT_REQUEST,

	# --- passive progression -----------------------------------------------
	CHECKPOINT_REACHED,
	ENCOUNTER_STATE_REQUEST,   # arm/clear a checkpoint's encounter block (§11.3)
	SECRET_REVEAL_REQUEST,
	ANOMALY_ENTERED,
	ANOMALY_EXITED,
}

var type: Type
var source: NodePath
var payload: Dictionary
var physics_frame: int
var order: int                 # monotonic queue order within this physics tick
```

**The queue is double-buffered, and it is never cleared on a schedule.** Publishers write to
`_incoming`. `RuntimeDirector` swaps the buffers at the start of its own resolve and reads
`_active`. Nothing else clears either one.

This is not a style choice. Godot dispatches `_input` / `_unhandled_input` during the input
flush, which — with default (non-agile) event flushing — happens in the *idle* frame, not
inside the physics pass. A queue cleared at physics priority −100 would therefore wipe every
`E`, `J`, and pause press published since the previous physics tick. **Input loss, not input
latency.** A swap has no such window: every event published between two resolves is seen by
exactly one resolve.

```gdscript
# res://autoload/runtime_events.gd — Autoload "RuntimeEvents"
extends Node

var _incoming: Array[RuntimeEvent] = []   ## publishers write here, any time
var _active: Array[RuntimeEvent] = []     ## RuntimeDirector reads here, during resolve
var _order := 0

## Called by RuntimeDirector at the top of its resolve, and by nothing else.
func swap() -> void:
	_active = _incoming
	_incoming = []
	_order = 0

func enqueue(type: RuntimeEvent.Type, source: Node, payload: Dictionary = {}) -> void:
	var e := RuntimeEvent.new()
	e.type = type
	e.source = source.get_path() if source else NodePath()
	e.payload = payload
	e.physics_frame = Engine.get_physics_frames()
	e.order = _order
	_order += 1
	_incoming.append(e)

## Carry an event that lost its tick into the next resolve, preserving order (§4.6).
func defer(e: RuntimeEvent) -> void:
	_incoming.push_front(e)

func take(type: RuntimeEvent.Type) -> Array[RuntimeEvent]:
	return _active.filter(func(e): return e.type == type)

func first(type: RuntimeEvent.Type) -> RuntimeEvent:
	for e in _active:
		if e.type == type:
			return e
	return null

func has(type: RuntimeEvent.Type) -> bool:
	return first(type) != null
```

`order` is a deterministic tie-breaker within one type only. Gameplay precedence comes from §4.2 and nothing else.

Because publishing always targets `_incoming`, a commit that enqueues during resolution — a
respawn queuing its wake-line cutscene, say — lands on the *next* tick and cannot mutate the
array being iterated. Re-entrancy is structurally impossible rather than merely avoided.

**One-frame latency is accepted and uniform.** Anything published after `RuntimeDirector` has swapped in frame *N* resolves in frame *N+1*. This is deterministic, applies to every system equally, and is invisible at 60 Hz. Do not add a second resolution pass to chase it.

---

## 3. Boot & session lifecycle

Nothing in Docs 1–5 mounts the first zone or creates the player. `SessionDirector` does.

### 3.1 Boot sequence

```text
1. Autoloads _ready() in §2.2 order. No gameplay nodes exist yet.
2. AudioDirector loads placeholder WAVs from res://assets/audio/ like any other
   asset. Nothing is synthesised at runtime — Doc 5 §7.1 bakes offline.
3. Settings.load() from user://settings.cfg. Applied before any UI draws.
   Settings NEVER gates a gameplay verb: every action is bound here, and an
   unearned verb is refused at the resolver (§4.2 rows 11-12), not left unbound.
4. Main menu scene (Doc 4 §7.1). AudioDirector.set_zone(&"bgm_menu").
   "Continue" is hidden unless GameState.has_save().
5. New Game  → GameState.new_game()
   Continue  → GameState.load_slot(0); on parse failure, warn and fall back to (4)
   Chapters  → §9.5 scratch session
6. SessionDirector.begin_session()
7. Control returns to the player, and §7.7's arrival grace applies.
```

### 3.2 `begin_session()`

```gdscript
# res://autoload/session_director.gd — Autoload "SessionDirector"
extends Node

const PLAYER_SCENE := preload("res://actors/player/dipper.tscn")
const WORLD_SCENE := preload("res://world/world_root.tscn")

var world_root: Node2D
var player: PlayerController

func begin_session() -> void:
	# 1. World root: owns the Doc 3 §2.3 parallax, hosts every zone instance, and
	#    carries THE one weirdness grade for the whole game.
	world_root = WORLD_SCENE.instantiate()
	get_tree().root.add_child(world_root)

	# 1b. Bind the grade. Doc 1 §2.1 defines Weirdness.bind() and nothing called
	#     it — the shader would have sat at its default forever. It binds here,
	#     once, to the single ColorRect on world_root. NOT per zone: three
	#     resident zones would mean three chained backbuffer copies with only one
	#     of them actually driven.
	Weirdness.bind(world_root.get_node(^"WeirdnessGrade").material)

	# 2. Player exists before any zone does, so triggers never fire into a null.
	player = PLAYER_SCENE.instantiate()
	player.state = PlayerController.State.ZONE_TRANSITION   # locked until mounted
	world_root.get_node(^"Actors").add_child(player)

	# 3. Wire the systems that Doc 3 §3.2 left unassigned.
	ZoneManager.bind(world_root, player)
	RuntimeDirector.bind(player)
	CombatDirector.reset()

	# 4. Mount behind an already-opaque overlay — no fade-out, we start black.
	var cp := GameState.data.checkpoint
	TransitionDirector.set_opaque(true)
	# Marker first, raw coordinate only as a fallback (§9.2). A new game names a
	# marker it cannot resolve until the zone instantiates, which is exactly why
	# the marker — not a Vector2 — is what the checkpoint carries.
	await ZoneManager.mount_initial(cp.zone_id, cp.spawn_marker, cp.position)
	# activate_zone() has now committed palette, weirdness floor, and BGM.

	# 5. Hand the lock to the resolver. It counts the fade in ticks and releases
	#    the player itself; the tween only mirrors it (§4.5). Boot does not await
	#    an animation to decide when gameplay starts.
	RuntimeDirector.take_lock(RuntimeDirector.FADE_TICKS)
	TransitionDirector.play_fade_in(RuntimeDirector.FADE_TICKS)
```

The player is instantiated **before** the first zone so that destination `Area2D`s at the spawn marker overlap a body that already exists. Reversing this is the classic first-frame null.

`_lock_ticks` reaching zero is what returns control and starts §7.7's arrival grace — the same path a gated transition and a respawn take, so boot is not a special case with its own release rule. The `await` on `mount_initial()` is legitimate: it waits on `ResourceLoader`, which is genuinely asynchronous, not on a tween.

### 3.3 `end_session()`

Quit to Menu, or the credits. Flush a save (§9.3), free `world_root`, `CombatDirector.reset()`, `Weirdness.set_zone_floor(0.0)`, `AudioDirector.set_zone(&"bgm_menu")`, then load the menu scene. `RuntimeEvents` is cleared. No gameplay autoload holds a reference to a freed node afterward — §12 check 12 proves it.

---

## 4. One physics-tick contract

### 4.1 The frame

`RuntimeDirector._physics_process()` at priority 100 owns the contract below. Input may be sampled earlier in the frame, but it remains an intent until this resolver commits it.

```text
1. Input handlers publish intents          (idle frame or physics — either is safe)
2. AI, animation call tracks, movement, physics bodies advance
3. Passive trigger volumes publish facts   (Area2D signals)
4. RuntimeDirector, priority 100:
   a. RuntimeEvents.swap() — everything published since the last resolve
   b. poll hitbox overlaps directly (§4.3)
   c. tick owned durations: i-frames, fumble, dodge, attack, grace, lock (§2.4)
   d. resolve by §4.2 priority
   e. commit state and emit committed-domain signals
   f. defer any unresolved event that §4.6 says survives
5. ZoneManager streams/culls               (priority 110)
6. _process(): UI, audio, camera, VFX, dialogue react to committed signals
```

Step 1 has no ordering requirement, which is the point of §2.5's swap. Input is free to arrive in the idle frame; it will still be seen by exactly one resolve.

Step 4b matters. Combat overlap is **polled**, not signal-driven, because signal arrival order relative to the resolver is not a guarantee Godot makes. Polling is.

**Be precise about what polling gives you.** `get_overlapping_areas()` reflects the world as of the **last completed physics step** — Godot's physics server refreshes `Area2D` overlap lists during its own step, which runs *after* every `_physics_process` callback in the frame. `process_physics_priority = 100` orders this resolver relative to other *scripts*; it does not order it relative to the physics server, and no priority value can. So the resolver sees a hitbox on the tick **after** it arms.

That is one tick of uniform staleness, accepted for exactly the reason §2.5's one-frame latency is accepted: it is deterministic, it applies to every combatant equally, and it is invisible at 60 Hz. What matters is that §4.3's rule is stated against the model that actually ships, not against a model where "this tick" means something the engine never promised — otherwise §12's checks encode the wrong expectation, pass against stubs, and disagree with live play.

```gdscript
# res://autoload/runtime_director.gd — Autoload "RuntimeDirector" (skeleton)
extends Node

var player: PlayerController
var _pending_blackout := false
var _lock_ticks := 0                    ## > 0 means a transition owns the frame (§4.5)
var _arrival_grace_ticks := 0

func _ready() -> void:
	process_physics_priority = 100

func _physics_process(_delta: float) -> void:
	if player == null:
		return
	RuntimeEvents.swap()
	_poll_contacts()
	_tick_durations()                   # decrements _lock_ticks among others
	_resolve()

func _resolve() -> void:
	# Priority 0 — an in-flight transition or a blackout owns the frame.
	if _lock_ticks > 0 or player.state == PlayerController.State.BLACKOUT:
		_resolve_locked()
		return

	if _try_respawn():        return    # 1
	_try_zone_travel()                  # 2  — see below; seamless does NOT end the tick
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
	# priority 1 in _resolve() would otherwise be dead code.
	if RuntimeEvents.has(RuntimeEvent.Type.RESPAWN_REQUEST):
		_try_respawn()
		return
	# A gated transition ending is the lock's own completion, not an event.
	# Everything else published this tick is discarded by design (§6.3): no
	# checkpoint, secret, anomaly, or input may commit behind an opaque overlay.
	_discard_locked_events()
```

Each `_try_*` returns `true` only if it committed. A committed higher priority ends the tick for every *intent* below it. Two deliberate exceptions:

- `_try_damage()` applies and then cancels lower intents rather than skipping them silently.
- `_try_zone_travel()` never ends the tick on a **seamless** activation, for the reason in §4.5.

### 4.2 Resolution priority

| Priority | Event | Result |
|---:|---|---|
| **0** | Active transition lock / `BLACKOUT` | Gate, not an event. All gameplay input is dropped. Passive triggers are suppressed (§6.3). Only the owning director's own completion may pass. |
| 1 | `RESPAWN_REQUEST` | Blackout is complete. Commits §11.2's respawn, which may itself be a zone travel. |
| 2 | `GATED_ZONE_REQUEST` · `SEAM_FALLBACK_REQUEST` | Validated and committed **before** damage. **Takes the transition lock** and ends the tick. A same-tick lethal hit is deferred to the destination (§7.8). |
| 2 | `ZONE_ACTIVATION_REQUEST` (seamless) | Validated and committed **before** damage, and takes **no** lock — resolution continues down this table. §4.5. A same-tick lethal hit is still deferred (§7.8). |
| 3 | `LETHAL_DAMAGE` | Starts blackout, unless a zone request committed at priority 2. |
| 4 | `DAMAGE` | Cancels interaction, Journal scan/open, attack, and dodge requests not already protected by active i-frames. |
| 5 | `PAUSE_REQUEST` | §10. Dropped, never queued, if state forbids it. |
| 6 | `CUTSCENE_REQUEST` | Begins only after damage has resolved. A pending Journal first closes under §5.2. |
| 7 | `DODGE_REQUEST` | Begins only if no hit connected this tick. |
| 8 | `VEHICLE_BOARD_REQUEST` · `VEHICLE_EXIT_REQUEST` | §5.3. Requires `FREE` / `DRIVING` respectively, and zero velocity to exit. |
| 9 | `ATTACK_REQUEST` | Requires `FREE`. Enters `ATTACKING` for Doc 2 §4's windup+active+recovery. |
| 10 | `ITEM_USE_REQUEST` | Requires `FREE`, `JOURNAL`, or `DRIVING` (horn, thrown item). |
| 11 | `JOURNAL_TOGGLE_REQUEST` | Opens/closes only in a permitted player state (§5.2). |
| 12 | `UV_TOGGLE_REQUEST` · `ITEM_SELECT_REQUEST` · `JOURNAL_SUBMIT_REQUEST` | Journal-domain intents. Require `JOURNAL` (UV, submit) or `FREE`/`JOURNAL` (radial). §8.3. |
| 13 | `INTERACT_REQUEST` | Calls an interactable only while Player state is `FREE` and no higher-priority event won. |
| 14 | `CHECKPOINT_REACHED` · `ENCOUNTER_STATE_REQUEST` · `SECRET_REVEAL_REQUEST` · `ANOMALY_ENTERED/EXITED` | Commit only when trigger processing is armed (§6.3). |
| 15 | `CHAPTER_ADVANCE_REQUEST` | Always last, so a chapter advance never lands mid-resolution and never changes a gate another `_try_*` already read this tick. |

**Scan is not an event.** Doc 2 §5.4 polls `Input.is_action_pressed("scan")` continuously and requires `PlayerController.State.JOURNAL`. That poll stays — it is a *continuous* intent, not a discrete one, and the resolver governs it by owning the `JOURNAL` state it depends on. Damage, dodge, cutscene, and zone travel all cancel an in-progress scan through §5.2's cancellation rule.

### 4.3 "The hit arrived first"

Combat overlaps are polled at step 4b, before any intent is committed. An enemy hitbox that was overlapping Dipper **as of the last completed physics step** wins and deals damage. If a dodge was committed in an earlier tick and its i-frame window (Doc 2 §3.4) is active when the hit resolves, the hit is ignored.

**A hit wins if it arrived first; an already-active dodge protects.** "Arrived first" means the overlap was already established when the resolver looked — a hitbox arming from an animation call track during frame *N* is seen at frame *N+1*, so a dodge input arriving in frame *N* beats it. That is correct and intended: the player reacted before the attack was live. Animation call tracks remain the source of truth for hitbox activation and i-frame timing (Doc 2 §4.1).

Multiple damage sources in one tick resolve as one hit. Doc 2 §7.1's i-frame flag is set on the first commit, so the second is dropped in the same tick rather than stacking — the resolver relies on this rather than deduplicating separately.

### 4.4 Same-tick examples

| Facts collected this tick | Resolution |
|---|---|
| `E` pressed + non-lethal hit | Damage applies; interaction is cancelled. |
| Story trigger + non-lethal hit | Damage applies first; cutscene begins on the next eligible tick. |
| Zone activation threshold + lethal hit | Zone transition commits; blackout is deferred until arrival. |
| Dodge input + already-active enemy hitbox | Damage applies; dodge does not begin. |
| Checkpoint + secret + anomaly, while transition locked | All three remain suppressed; none fire. |
| Attack input + `J` pressed | Attack wins (priority 9 over 11); the Journal does not open. |
| Pause + lethal damage | Damage resolves first; blackout starts; the pause request is dropped, not queued (§10). |
| Chapter advance + zone activation | Zone commits at priority 2; the advance lands at 15, after `current_zone` is already the destination. |
| Boundary crossed while driving | Vehicle crosses with the player (§5.3); the Journal was already blocked. |

---

### 4.5 The transition lock

Only **gated** travel takes the lock. This is the single most load-bearing distinction in the resolver, and §4.2's table states it per row.

| Travel | Lock | Player state | Rest of the tick |
|---|---|---|---|
| `ZONE_ACTIVATION_REQUEST` (seamless, §7.3) | **No** | stays `FREE` / `DRIVING` | Continues normally — damage, intents, and passive events all still resolve |
| `GATED_ZONE_REQUEST` (§7.4) | Yes | `ZONE_TRANSITION` | Ends. Lower priorities are discarded by §6.3 |
| `SEAM_FALLBACK_REQUEST` (§7.4) | Yes | `ZONE_TRANSITION` | Ends |
| `RESPAWN_REQUEST` crossing a zone (§11.2) | Yes | `BLACKOUT` → `ZONE_TRANSITION` | Ends |

A seamless crossing is not a transition. It removes no control, plays no fade, and takes no lock — so it must not behave like one in the resolver either. A player who walks across a seam and into an enemy hitbox on the same tick takes the hit; a seam is not a shield.

**The lock is a tick countdown, never a tween.** `_lock_ticks` is set from the owning sequence's duration and decremented in `_tick_durations()`. The overlay tween *mirrors* it visually and has no authority over gameplay state — §2.4's rule applied to the one place it most matters:

```gdscript
const FADE_TICKS      := 21   # 0.35 s — §7.4
const DOOR_WIPE_TICKS := 15   # 0.25 s — §7.6
const SEAM_WIPE_TICKS := 7    # 0.12 s — §7.4 fallback

func begin_gated_transition(to: StringName, marker: StringName) -> void:
	_lock_ticks = FADE_TICKS * 2 + _mount_budget_ticks(to)
	player.state = PlayerController.State.ZONE_TRANSITION
	TransitionDirector.play_fade(FADE_TICKS)      # presentation only
```

If the mount finishes early the lock is truncated to the remaining fade; if it overruns, the lock extends and the overlay simply holds opaque. Gameplay never resumes because an animation finished — it resumes because the resolver says so.

### 4.6 What survives a lost tick

An event that did not commit is discarded, with three exceptions that are explicitly deferred to the next resolve via `RuntimeEvents.defer()`:

| Event | Why it is deferred rather than dropped |
|---|---|
| `CUTSCENE_REQUEST` | §8.1 requires it to survive a same-tick hit and a Journal close. Already stated as "remains pending". |
| `CHECKPOINT_REACHED` · `SECRET_REVEAL_REQUEST` published during a **seamless** activation | The destination trigger fired legitimately; nothing was suppressed. See below. |
| `CHAPTER_ADVANCE_REQUEST` | Never dropped. If something outranked it, it lands next tick. |

Everything else — input intents, anomaly enter/exit, damage — is discarded and re-detected. That is correct for continuous facts: an anomaly the player is still standing in re-publishes next tick anyway, and a dropped `E` costs 16 ms.

**Why passive events need this rule at all.** `Area2D.body_entered` fires exactly once. If a checkpoint in the destination zone fires on the same tick the player crosses a seam, and the resolver drops it, that checkpoint is lost until the player physically leaves and re-enters it. §4.5's "seamless does not end the tick" already prevents this for the common case; `defer()` covers the ordering edge where the trigger published *after* the resolver swapped.

For **gated** travel the opposite rule applies, and it is not a leak: destination triggers overlapping Dipper at the spawn marker are suppressed by §6.3 on purpose. Because they already fired their one `body_entered` behind the overlay, arming cannot rely on a signal that has been and gone — so on transition completion `ZoneManager` **polls** `get_overlapping_bodies()` on every armed trigger in the destination and publishes for whatever is genuinely overlapping. §6.3 says "queued as dormant"; this is the concrete mechanism.

---

## 5. Player states

### 5.1 The enum

Extends Doc 2 §3.3 — that enum's six states keep their exact meaning; four are added.

```gdscript
enum State {
	FREE,
	JOURNAL,
	ATTACKING,          # new — Doc 2 §4 gives the timings, no state owned them
	DODGING,
	HURT,
	FUMBLING,
	DRIVING,            # new — Doc 3 §7 cart, §5.3 boat
	CUTSCENE,
	ZONE_TRANSITION,    # new
	BLACKOUT,           # new
}
```

| State | Movement | Input accepted | Allowed exits |
|---|---|---|---|
| `FREE` | Doc 2 §3.1 | All normal intents | Journal, attack, dodge, vehicle, hurt, cutscene, zone transition, blackout, pause |
| `JOURNAL` | Doc 2 §3.1 journal speed | Movement, Journal, scan, UV, item, radial | Close, fumble, dodge, cutscene-close, blackout, pause |
| `ATTACKING` | Drifts, no steering | None | `FREE` on recovery end, `HURT`, `BLACKOUT` |
| `DODGING` | Doc 2 §3.4 impulse | None | `FREE`, `HURT` |
| `HURT` | Knockback only | None | `FREE`, `BLACKOUT`, deferred cutscene |
| `FUMBLING` | None | None | `FREE` after Journal returns `CLOSED` |
| `DRIVING` | Doc 3 §7 vehicle handling | Vehicle controls, item use, interact, pause | `FREE` on exit, `ZONE_TRANSITION`, `CUTSCENE`, `BLACKOUT` |
| `CUTSCENE` | None | Skip only if the chapter allows it | `FREE`, `BLACKOUT` |
| `ZONE_TRANSITION` | None | None | `FREE`, deferred `BLACKOUT` |
| `BLACKOUT` | None | None | `RESPAWN_REQUEST` → `FREE` |

Pause is **not** a state. It is `get_tree().paused`, orthogonal to this enum, governed by §10.

### 5.2 Journal state machine

```text
CLOSED --J--> OPENING --0.42 s--> OPEN --J--> CLOSING --0.30 s--> CLOSED
   ^                         |                     |
   |                         +--damage------------+
   +--------------------- FUMBLED --0.80 s --------+
                             |
                 dodge → immediate forced close
```

Durations are Doc 2 §5.1's, counted in ticks per §2.4.

| Cause | Required outcome |
|---|---|
| Damage in `OPENING` or `OPEN` | Cancel scan, Journal `FUMBLED`, Player `FUMBLING`, then both return to normal closed/free state. |
| Dodge in `OPENING` or `OPEN` | Cancel scan and force Journal `CLOSED` in the same tick; play the established dropped-book dive presentation, then Player enters `DODGING`. This is not the 0.80 s damage fumble. |
| Cutscene request in `OPENING` or `OPEN` | Cancel scan, complete the normal close, then `CutsceneDirector` acquires Player state. |
| Zone boundary while Journal is not closed | Boundary blocker denies travel; no state changes occur (§7.5). |
| Vehicle board request while Journal is not closed | Denied, same affordance as the boundary blocker. |
| Blackout | Journal closes without a player-visible reopen state; respawn is always `CLOSED`. |
| Pause | Journal state is frozen, not closed. Unpausing resumes mid-`OPENING` if that is where it was. |

`Journal.blocks_zone_travel()` returns true for `OPENING`, `OPEN`, `CLOSING`, and `FUMBLED`. It is false only in `CLOSED`.

`J` from `OPEN` starts the normal close. It is ignored during `OPENING`, `CLOSING`, `FUMBLED`, `ATTACKING`, `DRIVING`, `CUTSCENE`, `ZONE_TRANSITION`, and `BLACKOUT`.

### 5.3 Vehicles

The cart is a **possessed body**, not a mount. Doc 3 §7 owns its handling; this document owns the ownership transfer.

```text
Board  (priority 8, requires FREE, Journal CLOSED, within interact range):
  1. Player state → DRIVING.
  2. PlayerController collision + visual disabled; the body persists as the
     save/checkpoint anchor and follows the vehicle's transform each tick.
  3. Camera target → vehicle. Interactor disabled.
  4. Companion auto-boards (Doc 3 §7) — its follower is suspended, not freed.
  5. AudioDirector starts the Doc 5 §5.2 engine layers.

Exit   (priority 8, requires DRIVING and |speed| < 20 px/s):
  Reverse, placing Dipper at the vehicle's dismount marker on walkable ground.
```

While `DRIVING`: Journal is blocked, dodge and attack are rejected, item use is allowed (horn, thrown items), interact is allowed only for vehicle-flagged targets. Damage transfers to the player's `Health` normally and knockback applies to the vehicle. Lethal damage while driving forces an exit at the vehicle's position, then blackout.

**Vehicles cross zone boundaries.** Doc 3 sizes the world around an 18 s cart trip from Shack to Town, so a cart that cannot cross a seam is pointless. Both §7.3 and §7.4 sequences apply unchanged; the vehicle is placed at the destination's spawn marker with the player, and §7.7's arrival grace applies before control returns.

The boat (Doc 3 §5.3) reuses `DRIVING` with different handling constants and no zone crossing — the lake is one zone.

---

## 6. Interactions and trigger discipline

### 6.1 Explicit interaction is an intent

`Interactor` continues to choose the best target by range and facing exactly as Doc 2 §8 specifies. On `E`, it queues `INTERACT_REQUEST`; it does **not** call `current.interact(owner)` in `_unhandled_input()`.

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact") and current:
		RuntimeEvents.enqueue(RuntimeEvent.Type.INTERACT_REQUEST, self,
			{&"target": current})
		get_viewport().set_input_as_handled()
```

At priority 13, `RuntimeDirector` verifies `PlayerController.State.FREE`, target enabled state, range, and `target.can_interact(player)` before invoking `target.interact(player)`. Re-verifying range at commit time is deliberate: the target may have moved or despawned since the intent was published.

### 6.2 Passive triggers publish only

| Node | Callback queues | Direct mutation it must not perform |
|---|---|---|
| `Checkpoint` | `CHECKPOINT_REACHED` | `GameState.set_checkpoint()` |
| Boss phase controller | `ENCOUNTER_STATE_REQUEST` | `GameState.data.checkpoint.encounter` |
| Journal text fields | `JOURNAL_SUBMIT_REQUEST` | `journal_overrides`, `ciphers_solved` |
| `SecretTrigger` | `SECRET_REVEAL_REQUEST` | unlock entry, SFX, weirdness pulse |
| `AnomalyField` | enter/exit facts | zone progression or Player state |
| `ZoneBoundary` | gated-travel request | scene loading or Player state |
| `ZoneActivationVolume` | zone-activation request | palette/audio state |
| `SeamBlocker` | `SEAM_FALLBACK_REQUEST` | transition start |
| Enemy hitbox | polled, not queued (§4.3) | health subtraction or Journal fumble |
| Story volume | `CUTSCENE_REQUEST` | dialogue start, camera seizure |
| **`PlayerInput`** (one node on the player) | every player intent — `PAUSE_REQUEST`, `DODGE_REQUEST`, `ATTACK_REQUEST`, `ITEM_USE_REQUEST`, `ITEM_SELECT_REQUEST`, `JOURNAL_TOGGLE_REQUEST`, `UV_TOGGLE_REQUEST`, `VEHICLE_BOARD_REQUEST`, `VEHICLE_EXIT_REQUEST`, `INTERACT_REQUEST` | any state change at all — it reads input and publishes, nothing else |

**One node publishes every intent.** Nine of §4.2's priority rows would otherwise have no named source anywhere in any document. `PlayerInput` is a single `_unhandled_input` with a single `match` over actions; it never inspects player state, because deciding whether an intent is legal is the resolver's job and duplicating that test is how the two drift apart.

**Unpausing is the one input that does not go through this path.** With `PROCESS_MODE_PAUSABLE` on every gameplay node (§10), `PlayerInput._unhandled_input` is suspended while the tree is paused — so it cannot publish the un-pause, and the resolver is not running to receive it. Pausing is a `PAUSE_REQUEST`; **unpausing is the pause menu's own affordance**, handled by the menu directly, because the menu is `PROCESS_MODE_WHEN_PAUSED`.

`AnomalyField` (Doc 2 §6.1) is the one partial exception, and the boundary is precise: its **per-tick force integration into `external_force` is physics, not gameplay state**, and stays in `_physics_process` as written.

**`Weirdness` needs no resolver route.** `pulse()` and `release()` may be called directly from anywhere — an anomaly, a proximity trigger, a boss phase, a chapter beat. It is presentation state: it clamps, it tweens, it reconciles floor against event, and nothing it holds can corrupt a save or desync gameplay. Routing it through the resolver would buy a rule and cost a round trip, and the rule would immediately leak anyway (Doc 2's UV beam and Doc 6's Act 2 pulses all call it directly). `set_zone_floor()` remains `activate_zone()`'s alone, because that one is part of the zone commit.

`RuntimeDirector` commits the resulting effect and then emits `checkpoint_committed`, `secret_revealed`, `damage_committed`, `zone_entered`, `chapter_advanced`. UI and audio subscribe to those committed signals only.

### 6.3 Trigger arming

```gdscript
func can_process_world_triggers() -> bool:
	return _lock_ticks == 0 and player.state not in [
		PlayerController.State.ZONE_TRANSITION,
		PlayerController.State.BLACKOUT,
	]
```

During a gated transition, the destination scene may instantiate and its `Area2D`s may overlap Dipper at the spawn marker. Their callbacks must be ignored or queued as dormant until transition completion. The game must never award a checkpoint, secret, or anomaly effect while the screen is fading.

---

## 7. Zone travel

### 7.1 Scene roles

| Node | Responsibility |
|---|---|
| `ZoneBoundary` | Tests locked/unlocked travel and hosts the Journal-blocking collider. Doc 3 §3.1. |
| `ZoneActivationVolume` | Thin `Area2D` placed **96 px inside** the destination side of every seamless boundary. The only node allowed to request `activate_zone()`. |
| `SeamBlocker` | Doc 3 §3.3's soft block. Publishes `SEAM_FALLBACK_REQUEST` after `SEAM_BLOCK_GRACE`. |
| `ZoneManager` | Loads/unloads scenes; commits current zone only through `activate_zone()`. |
| `TransitionDirector` | Owns overlay fades and the gated-travel coroutine. |

**Doc 3 §10's authoring checklist gains two items** (10 and 11), because §10 as written predates this node:

> 10. A `ZoneActivationVolume` 96 px inside every seamless inbound edge — one per inbound direction, not one per boundary.
> 11. A `SeamBlocker` on every seam-capable boundary, disabled by default.

The 96 px activation depth prevents music and palette flicker if Dipper touches a seam, turns around, or is nudged backward by collision.

### 7.2 `activate_zone()` is the single commit

Doc 3 §3.2's `set_current()` is renamed and is now the only writer of current-zone state. Nothing else changes about its body.

```gdscript
# res://autoload/zone_manager.gd (supersedes Doc 3 §3.2 set_current)
func activate_zone(id: StringName) -> void:
	if id == current_zone:
		return
	current_zone = id
	var def: ZoneDef = _defs[id]
	Weirdness.set_zone_floor(def.ambient_weirdness)   # Doc 1 §2.1
	AudioDirector.set_zone(def.bgm_id)                # Doc 5 §3
	zone_entered.emit(id)
```

Doc 1 §1.6's `PaletteRegion` applies its palette on `_ready()` as written, but **does not call `Weirdness.set_zone_floor()`** — that call belongs here and nowhere else, or a streamed neighbour's `_ready()` would change the grade of the zone you are standing in.

### 7.3 Seamless-zone sequence

Prerequisite: the destination has been asynchronously loaded by Doc 3 §3.2's `_stream_neighbors()`.

```text
1. Dipper crosses ZoneBoundary while Journal is CLOSED.
2. He moves into ZoneActivationVolume, 96 px inside the destination.
3. Volume queues ZONE_ACTIVATION_REQUEST.
4. RuntimeDirector validates: destination loaded, unlocked, Player is FREE or
   DRIVING, no higher-priority event won.
5. ZoneManager.activate_zone(destination) — palette floor, BGM crossfade
   (Doc 5 §3), zone_entered.
6. Destination passive triggers become eligible after zone_entered returns.
7. An arrival-story request, if authored, waits for §7.7's grace.
```

**No transition lock is taken** (§4.5) — a seamless crossing never removes control, and resolution continues down §4.2's table for the rest of the tick. Audio starts **after** the scene is resident and **after** real entry, never during background loading. This is Doc 5 §11.5 restated as a sequence.

### 7.4 Gated-zone sequence

```text
1. Dipper enters ZoneBoundary with Journal CLOSED.
2. Boundary queues GATED_ZONE_REQUEST; RuntimeDirector validates it.
3. Transition lock taken. Player enters ZONE_TRANSITION. Input and world
   triggers disabled.
4. TransitionDirector fades to opaque over 0.35 s. Old-zone BGM continues.
5. ZoneManager frees the old-zone scene, loads/instantiates the destination,
   and places Dipper (and any vehicle) at spawn_marker.
5a. RuntimeDirector applies the request's TransitionTeardown, if any (§7.4.1).
6. ZoneManager.activate_zone(destination) — palette, current zone, BGM crossfade.
7. TransitionDirector fades in over 0.35 s while the BGM crossfade continues.
8. Transition lock released. Player returns to FREE; destination triggers arm.
9. Arrival-story request waits for §7.7 before it may start.
```

Starting the music at step 6 is intentional: the new scene is real, Dipper is physically there, and the visual fade-in lets the new ambience arrive with the place rather than with a loading screen.

### 7.4.1 `TransitionTeardown`

Some transitions are not just a change of place. A chapter transitioning out of a set-piece needs the boss cleared, the vehicle dismissed, health restored, and the checkpoint moved — and every one of those is gameplay state, which §14.1 says only `RuntimeDirector` may commit.

A chapter therefore **declares** the teardown as data on the request. It does not perform it.

```gdscript
# res://core/transition_teardown.gd
class_name TransitionTeardown
extends Resource

@export var clear_combat: bool = false       ## boss_active/id/phase → 0, aggro cleared
@export var exit_vehicle: bool = false       ## DRIVING → FREE, vehicle despawned
@export var restore_health: bool = false     ## Health → max_pips
@export var release_weirdness: bool = false  ## event level → 0; zone floor takes over
@export var clear_pending_blackout: bool = false
@export var set_checkpoint: Dictionary = {}  ## same shape as GameState.data.checkpoint
```

```gdscript
RuntimeEvents.enqueue(RuntimeEvent.Type.GATED_ZONE_REQUEST, self, {
	&"to": &"z_shack_ext",
	&"spawn_marker": &"sp_ch01_arrival",
	&"teardown": preload("res://chapters/ch01/rewind_teardown.tres"),
})
```

Applied at step 5a — inside the lock, while the overlay is opaque, after the destination is mounted and before `activate_zone()` commits. That ordering is deliberate: the teardown runs while nothing is visible and no trigger is armed, so a half-torn-down world is never on screen for a frame.

**It is a fixed set of flags, not a callback.** A `Callable` here would be a hole straight back through §14.1 — a chapter could do anything under the guise of a teardown, at the one moment nothing can observe it. Every field is a boolean or plain data, `RuntimeDirector` performs each commit itself, and §12 check 21 asserts the set is exhaustive. A chapter that needs something not on this list amends this document.

Teardown is optional. Most transitions declare none.

`SEAM_FALLBACK_REQUEST` (Doc 3 §3.3's grace wipe) runs this same sequence with a 0.12 s wipe instead of a 0.35 s fade. It is the only transition a player can trigger by out-running the loader, and it is logged at `push_warning` level so playtesting reveals whether `STREAM_MARGIN` needs retuning.

### 7.5 Journal boundary blocker

Every `ZoneBoundary` includes a narrow `StaticBody2D` just inside the source-zone edge. `ZoneManager` enables it whenever `Journal.blocks_zone_travel()` is true and disables it only once the Journal returns `CLOSED`.

The blocker has no dialogue and no auto-close behavior. It briefly shows the existing Journal affordance with the verb **Close Journal**. This prevents crossing the line while the book is open instead of repairing the state after the fact.

Zone travel is physically blocked while the Journal is not `CLOSED`; it never auto-closes or fumbles merely because of a boundary.

### 7.6 Interiors are zones

Doc 3 §1.4's `ZoneDef` already carries `is_interior`. Interiors register in the same `registry` and travel the same commit path; only their streaming behaviour differs.

| Property | Exterior zone | Interior zone |
|---|---|---|
| In `_stream_neighbors()` | Yes | **Never** — excluded by `is_interior` |
| In `_cull_distant()` | Yes | Never; freed explicitly on exit |
| Boundary node | `ZoneBoundary` | `DoorBoundary` (same script, 0.25 s wipe) |
| Transition | §7.3 or §7.4 by `seam_chapter` | Always §7.4, gated |
| `activate_zone()` | Yes | **Yes** — palette, weirdness floor, BGM |
| Grid offset | Doc 3 §1.2 | `Vector2i(-1, -1)` sentinel; interiors are off-grid |
| Exterior on entry | — | Freed; reloaded on exit at the door marker (Doc 3 §8) |

This replaces Doc 3 §8's "no zone-manager involvement". The intent of Doc 3 §8 is preserved in full — interiors are still separate scenes, still never streamed, still bounded by `Camera2D.limit_*`, and `int_mansion` is still the one-scene exception. What changes is that `bgm_attic`, `bgm_lab`, and every interior palette now commit through the one path that §12 tests, instead of a second lifecycle that would need every rule in this document written twice.

### 7.7 Arrival grace

On arrival, Player becomes `FREE` before an automatic zone-entry story may take control. `CutsceneDirector` waits **0.15 s** (9 ticks) after input unlock, then may resolve the authored arrival-story request. This gives the player a visible, controllable arrival beat and guarantees that dialogue never starts underneath a transition overlay.

Arrival dialogue may begin only after the fade finishes and Dipper has regained control.

### 7.8 Lethal damage at a zone threshold

If Dipper crosses the activation threshold and receives lethal damage in the same physics tick, the zone request commits first (priority 2 beats priority 3). `RuntimeDirector` records `_pending_blackout = true`, grants transition invulnerability, completes §7.3 or §7.4, then begins blackout from the destination after arrival is stable.

If the zone request failed validation — Journal open, destination unavailable, locked, or threshold not crossed — there is no escape; lethal damage resolves normally.

**Changing zones can save the player.** This is a deliberate, testable mercy, not an accident of ordering.

---

## 8. Cutscenes & dialogue

### 8.1 Sequence

```text
1. Story volume queues CUTSCENE_REQUEST.
2. RuntimeDirector first resolves same-tick damage.
3. If lethal, blackout wins. If non-lethal, play the hit; cutscene remains pending.
4. If Journal is OPENING or OPEN, cancel scan and finish the normal close.
5. CutsceneDirector sets Player to CUTSCENE, then begins dialogue/camera control.
6. On completion, Player returns to FREE. The Journal remains CLOSED.
```

Story volumes must disable themselves or set their persistent flag when their request is accepted; otherwise the player could immediately re-trigger the same cutscene after control returns. Chapter docs declare that flag by name (§9.2).

### 8.2 Cutscene authoring surface for Docs 6–25

```gdscript
CutsceneDirector.request(&"ch03_gideon_intro", {
	&"skippable": true,               # Doc 4 §7.4 chapter cards are always skippable
	&"lines": [ ... DialogueLine ... ],
	&"camera": &"path/to/CameraRig",
	&"on_complete_flag": &"ch03_met_gideon",
	&"on_complete_intent": RuntimeEvent.Type.JOURNAL_TOGGLE_REQUEST,   # optional
})
```

A cutscene never sets `GameState` fields directly. It declares `on_complete_flag`, and `RuntimeDirector` writes it on completion — so a cutscene interrupted by a blackout does not leave a half-set world.

### 8.2.1 Scripted follow-up intents

§8.1 step 6 is absolute: a cutscene always returns the player to `FREE` with the Journal `CLOSED`. A chapter that wants the player to *end up* in some other state — reading the Journal, holding an item — does not get to set it, because that is the class of direct mutation this document exists to prevent.

`on_complete_intent` is the supported path. On completion, `RuntimeDirector` writes `on_complete_flag`, returns the player to `FREE`, and then **enqueues the named intent, which resolves on the next tick through its normal priority row.**

That indirection is the whole point:

- The Journal opens via `JOURNAL_TOGGLE_REQUEST` at priority 11, so it plays the real 0.42 s `OPENING` animation and passes through the real state machine. There is no second, scripted way to open the book.
- Because it is an intent and not a state assignment, it can lose. If the player takes a hit on the tick after the cutscene ends, damage at priority 4 cancels it and the Journal stays closed — which is correct, and which a direct `state = OPEN` would have gotten wrong.

Only intents the player could have expressed themselves are legal here. `on_complete_intent` may name `JOURNAL_TOGGLE_REQUEST`, `ITEM_SELECT_REQUEST`, or `UV_TOGGLE_REQUEST`, and nothing else. It may never name a zone request, a damage event, or a cutscene.

### 8.3 Player text submission

Two places let the player type into the world: the weakness field on an incomplete entry (§9.2.1) and the Ciphers tab's decode pane (Doc 4 §6.4). Both write `GameState` — `journal_overrides` and `ciphers_solved` — so both go through the resolver like any other intent.

The UI collects text and enqueues. It validates nothing and commits nothing:

```gdscript
# res://ui/journal/weakness_field.gd  (and cipher_pane.gd)
func _on_submit_pressed() -> void:
	RuntimeEvents.enqueue(RuntimeEvent.Type.JOURNAL_SUBMIT_REQUEST, self, {
		&"kind": &"weakness",          # or &"cipher"
		&"target": &"entry_gnomes",    # entry id, or cipher fragment id
		&"text": _line_edit.text,
	})
```

At priority 12 `RuntimeDirector` verifies Player state is `JOURNAL`, dispatches on `kind` to `JournalDB.submit_weakness()` or `Cipher`/`CipherLock`, marks the save dirty, and emits `journal_submit_committed(kind, target, accepted)`. The pane reacts to that signal — it never reads its own return value, because the submission may not have happened.

**It can lose, and that is correct.** A hit landing on the same tick resolves at priority 4 and cancels the submission along with every other Journal-domain intent; the typed text stays in the field and the player can press submit again after the fumble. A UI that committed directly would have written to the save mid-fumble.

One event covers both cases because they are the same shape — player text, a target id, an accept/reject answer — and a second event type would mean a second path to audit. `kind` is a closed set; an unrecognized value is rejected with `push_error` at commit.

### 8.4 `pause_player` is removed

Doc 4 §3.1's `DialogueLine.pause_player` set `PlayerController` to `CUTSCENE` directly, which §14.1 forbids. The field is deleted. Any line needing player lockout is authored as a `CUTSCENE_REQUEST` through §8.2.

Everything else in Doc 4 §3 survives untouched — `Mode.AUTO` resolution, the combat bubble-forcing in §3.2, and §11.1's rule that box dialogue never renders during combat. `CombatDirector.threat_active` (§2.3) is what `resolve_mode()` reads.

---

## 9. Persistence, chapters & flags

### 9.1 Save model

**Autosave only. No manual save UI.** Doc 2 §12.10 promises that failure costs time and never progress; a manual-save model would break that promise for any player who quits mid-chapter.

| Write trigger | Slot |
|---|---|
| `CHECKPOINT_REACHED` commits (priority 14) | 0 |
| `CHAPTER_ADVANCE_REQUEST` commits (priority 15) | 0 |
| `activate_zone()` commits a new zone | 0 |
| `end_session()` (§3.3) | 0 |

Writes are **deferred to the end of the tick and executed off the physics frame** — `GameState` sets a dirty flag during resolution and flushes in `_process()`. A save write never stalls a physics frame.

Doc 3 §9 calls `int_attic` the "primary save point." Under autosave that reading holds without a save UI: the attic checkpoint is where players will naturally end a session, and Doc 5 §4.1's `bgm_attic` is already specced as the safety cue.

**Writes are atomic.** Autosave-only means the save file *is* the player's progress — there is no manual backup to fall back on, so a crash or a quit mid-write must not be able to leave a half-written slot 0. Write to `user://slot0.tmp`, `close()` it, then rename over `user://slot0.sav`. Rename is the atomic step; a torn write can then only ever destroy the temp file.

**(web)** `user://` persists through IndexedDB. Godot syncs IDBFS internally once the file handle closes — there is no GDScript-callable flush to invoke, so do not go looking for one. What you *can* do is detect unavailability: check `OS.is_userfs_persistent()` at boot and, if it is false (private browsing, storage pressure), surface a one-time warning that progress will not persist. Silent loss with no manual save is the worst possible failure here.

### 9.2 Save schema

The save is **one value type**, not a bag of fields on the autoload. `GameState` holds a `SaveData` and swaps it; `new_game()` and `load_slot()` replace it wholesale. That is what makes `serialize`/`deserialize` pure, testable functions and gives §9.2's round-trip check something to actually call.

```gdscript
# res://core/save_data.gd
class_name SaveData
extends Resource

var chapter: int = 1
var flags: Dictionary = {}              # StringName -> bool | int | float | String
var inventory: Dictionary = {}          # StringName -> int
var journal_entries: Array[StringName] = []   ## which entries are unlocked
var journal_overrides: Dictionary = {}        ## StringName -> Dictionary; §9.2.1
var secrets_found: Array[StringName] = []
var sigils_found: Array[StringName] = []      # Doc 3 §6.2, ten of them
var ciphers_solved: Array[StringName] = []
var checkpoint := {
	&"id": &"", &"zone_id": &"", &"spawn_marker": &"", &"wake_line_id": &"",
	&"position": Vector2.ZERO,            ## fallback only — see below
	&"encounter": {},                     ## §11.3; empty for ordinary checkpoints
}
var playtime: float = 0.0
```

```gdscript
# res://autoload/game_state.gd — Autoload "GameState"
const SAVE_VERSION := 1
const SLOT_0 := "user://slot0.sav"

var data: SaveData = SaveData.new()      ## the ONE accessor. Never a second shape.

func new_game() -> void:  data = SaveData.new()
func has_save() -> bool:  return FileAccess.file_exists(SLOT_0)
```

**`spawn_marker` is authoritative; `position` is a fallback.** Doc 3 §1.1 forbids hardcoding world coordinates — a zone edit that moves a marker would otherwise silently invalidate every checkpoint written before it, resuming the player inside geometry or off the tilemap. Transitions already carry a `spawn_marker: StringName` and no coordinate; checkpoints now match. `mount_initial(zone_id, marker, fallback_pos)` resolves the marker after the destination instantiates and only falls back to the raw `Vector2` when the marker is empty — which is the mid-zone case, a checkpoint the player triggered by walking rather than one an author placed.

**Serialization format: JSON, normalized at exactly one boundary.** No other format survives this schema. `store_var` preserves types but is fragile across engine upgrades, which is precisely what §9.2's migration story has to outlive. JSON is stable but lossy in two specific ways, so `deserialize` — and nothing else, anywhere — fixes both:

1. **Every dictionary key is a `String` on disk** and is converted back with `StringName(k)` on load. Godot's `String`/`StringName` dictionary-key equivalence has shifted across 4.x point releases; a twenty-chapter save format must not depend on it.
2. **`Vector2` stores as `[x, y]`** and is rebuilt on load. JSON has no vector type.

```gdscript
static func serialize(d: SaveData) -> String
static func deserialize(text: String) -> SaveData   ## the ONLY place keys are normalized
```

`Settings` (Doc 4 §5.1, §7.3) is **not** in the save. It lives in `user://settings.cfg` and survives New Game — accessibility settings are a property of the person, not the playthrough. It also never gates a gameplay verb (§3.1 step 3).

### 9.2.1 `journal_overrides` — the Journal is writable

`JournalEntry` resources are **authored, immutable, shared assets**. Writing to one at runtime is a bug with two heads: the change is lost on reload because `.tres` files are not saved, and — worse — the mutated resource persists in memory across New Game, so a fresh playthrough starts with the previous player's handwriting in it.

Every mutable per-entry fact therefore lives in the save, keyed by entry id:

```gdscript
journal_overrides = {
	&"entry_gnomes": {
		&"weakness_written": "leaf blowers",   ## verbatim, whatever the player typed
		&"weakness_verified": true,
	},
}
```

Rules:

1. An entry with no override behaves exactly as authored. Absence is the default, so the dictionary stays small and most entries never appear in it.
2. **Missing keys read as defaults**, per §9.2's migration rule — so a later chapter adding a per-entry field (a player sketch, a margin note, a sighting count) needs no `SAVE_VERSION` bump.
3. Reads go through `JournalDB`, never through the resource directly:

```gdscript
# res://core/journal_db.gd
static func weakness_written(id: StringName) -> String:
	return GameState.data.journal_overrides.get(id, {}).get(&"weakness_written", "")

static func is_verified(id: StringName) -> bool:
	var e := entry(id)
	if not e.weakness.is_empty():
		return true                        # Ford's own entries are trusted
	return GameState.data.journal_overrides.get(id, {}).get(&"weakness_verified", false)

static func damage_multiplier(id: StringName) -> float:
	return 1.45 if is_verified(id) else 1.0

## The only writer. Called by RuntimeDirector at priority 12 (§8.3), never by UI.
static func submit_weakness(id: StringName, text: String) -> bool:
	var ok := entry(id).verifies(text)
	var o: Dictionary = GameState.data.journal_overrides.get_or_add(id, {})
	o[&"weakness_written"] = text
	o[&"weakness_verified"] = ok
	GameState.mark_dirty()                 # §9.1 deferred autosave
	return ok
```

`JournalEntry` keeps `accepted_answers` and the pure `verifies()` / `_normalize()` comparison, because those are authored data and a pure function. It holds no player state at all.

§12 check 26 round-trips an override through a save, and check 27 asserts that a New Game leaves no override behind.

**Flag namespace.** Twenty chapter docs writing into one dictionary needs a rule, or Chapter 14 silently overwrites Chapter 3.

| Prefix | Owner | Example |
|---|---|---|
| `ch<NN>_` | Chapter doc NN, exclusively | `ch03_met_gideon` |
| `zone_` | Zone/world state | `zone_vending_code_known` |
| `sys_` | This document | `sys_first_journal_open` |
| `npc_` | Cross-chapter NPC relationship | `npc_wendy_trust` (int) |

A chapter doc may **read** any flag and may **write** only its own `ch<NN>_` prefix plus the shared `zone_` / `npc_` namespaces. §12 check 10 asserts no flag is written under another chapter's prefix.

**Version migration.** `SAVE_VERSION` bumps whenever a field is removed or its meaning changes; adding a field does not require a bump because missing keys read as defaults. `load_slot()` runs migrations in sequence and refuses to load a save from a *newer* version than the build, falling back to the main menu with a clear message rather than half-loading.

### 9.3 What a blackout does not do

Respawn reads **in-memory `GameState`**, never the disk. A secret found ten seconds before dying survives the death. Doc 2 §7.3's table is authoritative and unchanged: no progress lost, position at the last checkpoint, health full, cost is time and any in-progress scan, enemies respawn in the current room only. §11.2 gives the sequence.

### 9.4 Chapter progression

**Chapter docs advance the chapter, explicitly, at one named story beat each.** No quest system infers it.

```gdscript
RuntimeEvents.enqueue(RuntimeEvent.Type.CHAPTER_ADVANCE_REQUEST, self,
	{&"to": 4, &"from": 3})
```

Rules:

1. `chapter` is **monotonic**. A request whose `to` is not `from + 1` is rejected with `push_error`. Chapter Select uses §9.5, not this event.
2. Committing at priority 15 means `current_zone`, damage, and every other commit for that tick have already landed. The advance never changes a gate another resolver step read this tick.
3. On commit, `ZoneManager` re-evaluates residency: newly unlocked zones become streamable, and `is_seam_open()` (Doc 3 §3.2) may now return true for boundaries the player is standing near. Seams open **live**, without a transition — the boundary's `SeamLink` state activates on the next tick and the player can simply walk through.
4. `chapter_advanced` is emitted after the write. Doc 3 §5.1's portal weirdness ramp and Doc 5 §5.4's portal hum stages subscribe to it; neither polls `GameState.data.chapter` per frame.
5. An autosave follows immediately (§9.1).

### 9.5 Chapter Select uses a scratch save

Doc 4 §7.1 offers replayable chapters. Replay never touches slot 0.

```text
1. Copy slot 0 → memory. Load a chapter-start template into a scratch state.
2. begin_session() against the scratch state. Autosaves (§9.1) write to slot
   "scratch", never slot 0.
3. On exit, the scratch slot is deleted and slot 0 is untouched.
```

Progress made during replay — secrets, sigils, entries — is discarded on exit. That is the cost of a single, always-coherent main save, and it is worth paying: the alternative requires all twenty chapter docs to be written defensively against flags moving backward.

The chapter-start templates are authored per chapter doc as the minimum flag set that chapter assumes. §12 check 11 asserts every chapter's template satisfies its own opening preconditions.

---

## 10. Pause

The pause menu is the only legal `get_tree().paused = true` (Doc 4 §7.2). This document defines when it may be entered.

| Player state | `PAUSE_REQUEST` |
|---|---|
| `FREE`, `JOURNAL`, `ATTACKING`, `DODGING`, `HURT`, `FUMBLING`, `DRIVING` | Accepted |
| `CUTSCENE` | **Dropped.** Skip is the cutscene's own affordance |
| `ZONE_TRANSITION`, `BLACKOUT` | **Dropped** |

Requests in a forbidden state are **dropped, not queued** — a pause that fires 0.4 s later, after the fade finished, reads as an input bug. The `ui_denied` cue (Doc 5 §5.6) plays instead.

On pause: `RuntimeEvents` retains its queue but the resolver does not run, so pending intents resolve on the first tick after unpause. §2.4's tick counters simply stop, which is why they are counters and not wall-clock timers.

`process_mode`:

| Node | Mode |
|---|---|
| Every gameplay autoload and node | `PROCESS_MODE_PAUSABLE` (default) |
| Pause menu UI, `Settings` | `PROCESS_MODE_WHEN_PAUSED` |
| `AudioDirector` | `PROCESS_MODE_ALWAYS` — it applies Doc 5 §8's −12 dB + 900 Hz lowpass duck, which cannot happen on a paused node |

---

## 11. Failure & respawn

### 11.1 Blackout

At zero pips, Doc 2 §7.3's presentation runs as written: desaturate over 0.6 s, Dipper crumples, cut to black. Doc 5 §5.6 ducks `Master` by 24 dB over 0.6 s.

`RuntimeDirector` sets Player to `BLACKOUT`, takes the lock for the blackout's own tick count, and forces Journal to `CLOSED` with no visible reopen. Priority 0 suppresses everything until the count reaches zero and a `RESPAWN_REQUEST` is queued.

`BLACKOUT` is itself a locked state, so priority 1 in `_resolve()` is unreachable while it is active. **`_resolve_locked()` is the path that consumes `RESPAWN_REQUEST`** (§4.1), and it is the only event allowed through the priority-0 gate. Without that carve-out the player never wakes up.

### 11.2 Respawn sequence

```text
1. BLACKOUT tick count reaches zero. RESPAWN_REQUEST queued.
2. Resolver, _resolve_locked(). Read GameState.data.checkpoint (in memory, §9.3).
3. If checkpoint.zone_id != current_zone:
      run §7.4's gated sequence to that zone, overlay already opaque —
      no fade-out is played, we are already black.
   Else:
      place the player at checkpoint.position.
4. Health restored to full (Doc 2 §7.3). Stamina full. external_force cleared.
5. If checkpoint.encounter is empty:
      enemies in the current room respawn; CombatDirector.reset() clears aggro,
      so the player does not wake into an active threat state.
   Else:
      §11.3's encounter restore runs instead of the reset.
6. Weirdness returns to the zone floor via activate_zone(), or set_zone_floor()
   if the zone did not change.
7. AudioDirector releases the blackout duck over 1.0 s (Doc 5 §8).
8. TransitionDirector fades in. Lock released. Player → FREE.
9. The checkpoint's wake_line_id (Doc 2 §7.3) is authored as a CUTSCENE_REQUEST
   and waits for §7.7's arrival grace like any other arrival dialogue.
```

Step 3 is why respawn sits at priority 1 rather than being a special case: a cross-zone respawn genuinely *is* zone travel, and reusing §7.4 means it is covered by the same tests.

### 11.3 Encounter respawn

Step 5's blanket `CombatDirector.reset()` is right for ordinary death — you wake up safe — and wrong for dying inside a boss fight, where it would drop the player back at a checkpoint with the boss gone and the fight unwinnable.

`GameState.data.checkpoint` therefore carries an optional `encounter` block:

```gdscript
checkpoint = {
	&"id": &"cp_ch01_clearing",
	&"zone_id": &"z_woods_south",
	&"position": Vector2(...),
	&"wake_line_id": &"",
	&"encounter": {                      ## optional; empty for ordinary checkpoints
		&"boss_id": &"boss_gnome",
		&"phase": 2,                     ## the phase to resume at, not restart from
		&"setup": &"ch01_gnomonster_ph2", ## named scene-state the chapter authors
	},
}
```

When present, step 5 restores rather than resets:

```text
a. CombatDirector.boss_active = true, boss_id and boss_phase from the block.
b. The named setup is instantiated — for a chapter, this is the boss rig, any
   vehicle, and any escort NPC, placed at their phase-start positions.
c. Ordinary enemies in the room respawn as normal. Aggro is cleared; the boss
   is not aggro, it is state.
d. AudioDirector resumes the boss piece at the phase's stem configuration,
   cutting on the next bar (Doc 5 §4.4).
```

**A checkpoint's `encounter` block is written when the checkpoint is taken, not when it is used.** A chapter arms it on entering a boss phase and clears it on the boss's defeat, so a player who returns to that checkpoint later — after winning — respawns into an empty clearing, not a resurrected fight.

`checkpoint.encounter` is `GameState`, so §14.1 applies: a chapter **requests** the change and never writes it.

```gdscript
# arm — on entering a boss phase
RuntimeEvents.enqueue(RuntimeEvent.Type.ENCOUNTER_STATE_REQUEST, self, {
	&"boss_id": &"boss_gnome",
	&"phase": 2,
	&"setup": &"ch01_gnomonster_ph2",
})

# clear — on the boss's defeat
RuntimeEvents.enqueue(RuntimeEvent.Type.ENCOUNTER_STATE_REQUEST, self, {})
```

Resolved at priority 14 with the other progression events. An empty payload clears; a populated one arms, and is rejected with `push_error` if `setup` names a phase setup that was never registered with `CombatDirector` — a typo there would otherwise produce a checkpoint that respawns into an empty boss arena, which is the worst failure this whole mechanism exists to prevent.

Committing at 14 means the arm lands after any same-tick damage or zone travel. A player who dies on the exact tick a phase begins therefore respawns at the *previous* phase's encounter, not a half-armed new one.

`setup` is a `StringName`, not a scene path or a callable. The chapter registers named phase setups with `CombatDirector`; the resolver looks one up and instantiates it. Same reasoning as §7.4.1: a callable at this point in the sequence would be an unaudited mutation hook running while the screen is black.

Chapters that have no boss never touch any of this. `encounter` defaults to `{}` and step 5 behaves exactly as it did.

---

## 12. Required implementation checks

The resolver is a pure function of (queue, state). §12's harness exploits that: it drives `RuntimeDirector._resolve()` directly with hand-enqueued events and stub systems, so no physics server, no rendering, and no real scenes are needed. Run headless.

```gdscript
# res://tests/test_all.gd — godot --headless --script res://tests/test_all.gd
extends SceneTree

func _init() -> void:
	var h := RuntimeHarness.new()          # stubs Player, Journal, ZoneManager, Health

	# --- check 7: a threshold crossing plus lethal damage reaches the
	#     destination before blackout begins ------------------------------
	h.reset()
	h.player.state = PlayerController.State.FREE
	h.enqueue(RuntimeEvent.Type.ZONE_ACTIVATION_REQUEST, {&"to": &"z_town"})
	h.enqueue(RuntimeEvent.Type.LETHAL_DAMAGE, {&"amount": 6})
	h.step()
	assert(h.zone.current == &"z_town", "zone request must win over lethal damage")
	assert(h.director._pending_blackout, "blackout must be deferred, not dropped")
	assert(h.player.state != PlayerController.State.BLACKOUT,
		"blackout must not begin before arrival")

	# --- check 4: damage and E in the same frame ------------------------
	h.reset()
	h.enqueue(RuntimeEvent.Type.INTERACT_REQUEST, {&"target": h.stub_interactable})
	h.enqueue(RuntimeEvent.Type.DAMAGE, {&"amount": 1})
	h.step()
	assert(h.health.current == h.health.max_pips - 1, "damage must apply")
	assert(h.stub_interactable.interact_calls == 0, "interact must be cancelled")

	print("runtime: all checks passed")
	quit()
```

Automated Godot headless tests must prove:

1. A preloaded destination does not call `AudioDirector.set_zone()` until its `ZoneActivationVolume` is crossed.
2. Crossing an open seam calls `activate_zone()` exactly once and updates `current_zone`, palette, BGM, and map signal together.
3. A Journal blocker prevents zone activation while the Journal is `OPEN`, `OPENING`, `CLOSING`, or `FUMBLED`.
4. Damage and `E` in the same physics frame reduce health but do not call `interact()`.
5. A hitbox already active in the frame defeats a dodge request; an active i-frame defeats a later hit.
6. Destination checkpoint/secret/anomaly callbacks do not commit during a gated transition.
7. A same-tick threshold crossing plus lethal damage reaches the destination before blackout begins.
8. A Journal-active cutscene performs one normal close, never reopens the Journal, and begins only after any same-tick hit resolves.
9. `PAUSE_REQUEST` is dropped — not queued — in `CUTSCENE`, `ZONE_TRANSITION`, and `BLACKOUT`, and accepted in every other state.
10. No chapter doc's flag writes touch another chapter's `ch<NN>_` prefix (static scan over authored chapter resources).
11. Every chapter-start template (§9.5) satisfies that chapter's declared opening preconditions.
12. `end_session()` leaves no autoload holding a reference to a freed node; `begin_session()` immediately after it produces a playable state.
13. A save written at `SAVE_VERSION` round-trips every §9.2 field, and a save from a newer version is refused rather than partially loaded.
14. A cross-zone respawn reaches the checkpoint zone, restores full health, and clears aggro before control returns.
15. `RuntimeDirector.process_physics_priority` is greater than every gameplay node's, verified at runtime in `_ready()` with an assert.
16. **An event published outside the physics pass survives to the next resolve.** Enqueue with no intervening `swap()`, run two resolves, assert the event was seen exactly once — the regression test for §2.5's input-loss class.
17. A seamless `ZONE_ACTIVATION_REQUEST` takes no lock, leaves the player `FREE`, and **does not prevent a same-tick hit from landing**; a `GATED_ZONE_REQUEST` does take the lock and ends the tick.
18. A `CHECKPOINT_REACHED` published on the same tick as a seamless activation commits — that tick or the next — and is never silently lost (§4.6).
19. `RESPAWN_REQUEST` is consumed by `_resolve_locked()` during `BLACKOUT`; a blackout with a queued respawn always reaches `FREE` within its expected tick count and never deadlocks.
20. Gated transition, door wipe, boot, and respawn all release control on `_lock_ticks == 0`, with the fade tween stubbed out entirely — proving no gameplay state depends on an animation completing (§4.5).
21. **`TransitionTeardown` exposes no `Callable` field**, and every declared flag maps to a commit `RuntimeDirector` performs itself (§7.4.1). A reflection test over the resource's properties, so adding a callback field fails the build.
22. A teardown applies at step 5a — after the destination mounts, before `activate_zone()` — and never while any trigger is armed or the overlay is transparent.
23. A cutscene's `on_complete_intent` resolves through its normal priority row on the following tick, and is **cancelled by same-tick damage** rather than forced (§8.2.1). Only the three permitted intent types are accepted; any other is rejected at request time.
24. A checkpoint with an empty `encounter` resets combat on respawn; one with an `encounter` restores `boss_active`, `boss_id`, and `boss_phase` and instantiates the named setup (§11.3).
25. Defeating a boss clears the `encounter` block from any checkpoint that carries it, so returning to that checkpoint later does not resurrect the fight.
26. A `journal_overrides` entry — written text and verified flag — survives a save round-trip, and an entry with no override reads its authored values (§9.2.1).
27. `new_game()` leaves `journal_overrides` empty even after a prior session wrote to it, proving no player state leaked onto a shared `JournalEntry` resource.
28. `ENCOUNTER_STATE_REQUEST` commits only through the resolver at priority 14; an arm naming an unregistered `setup` is rejected rather than written.
29. A `JOURNAL_SUBMIT_REQUEST` in the same tick as damage does **not** write to the save; the text survives in the field and a resubmit after the fumble commits normally (§8.3).
30. No UI script calls `JournalDB.submit_weakness()` or a cipher validator directly — a static scan over `res://ui/`, so a future pane cannot quietly bypass the resolver.
31. **Every `State` value has an arm in `PlayerController._physics_process`.** For each state, one tick with a nonzero starting velocity leaves displacement within that arm's declared expectation — `BLACKOUT` and `ZONE_TRANSITION` at exactly zero. The regression test for a state that silently coasts because the `match` was never extended.
32. `deserialize(serialize(d))` reproduces `d` field for field, **including `StringName` dictionary keys and `Vector2` values** — the two things JSON loses. Assert key *types*, not just presence.
33. A save write is atomic: killing the process between the temp write and the rename leaves the previous slot 0 intact and loadable.
34. Every registered `ZoneDef` carries a non-empty `bgm_id` that exists in `AudioDirector`'s library, and every zone in the Chapter 1 path resolves — the check that catches an interior authored without music before it crashes on entry.
35. Exactly one node in the tree carries the weirdness shader material, and `Weirdness.bind()` was called on it during `begin_session()`.
36. `Weirdness.applied` — not `target_level` — is what `level_changed` carries, and a `pulse()` mid-tween leaves exactly one writer of any stem's `volume_db` in a frame.
37. `is_seam_open()` reproduces Doc 3 §1.3's adjacency table row for row, read off each `SeamLink` — the check that catches an edge whose open-chapter was inferred from its endpoints rather than authored.
38. A `Scanner` resolves both a stub `PropScannable` and a stub scannable NPC through `get_overlapping_areas()`, and returns `null` for a `PhysicsBody2D` carrying no `scannable` child.
39. `_cull_distant()` never frees an interior, and no two interiors share a `world_rect()`.
40. Every gameplay action named in Doc 2 §3.5 resolves to at least one `InputMap` event at boot, **including `journal`, `uv_light`, and `scan` before they are earned** — verbs are gated at the resolver, never by leaving an action unbound.

Checks 1–3, 6, 14, 34, 35, and 39 need a real scene tree; run them from a small `res://tests/scene_harness.tscn` driven by `Engine.get_physics_frames()`. The rest run from the pure harness above. Both are entered from the one suite, `res://tests/test_all.gd`.

---

## 13. What chapter documents (6–25) must use

Every chapter doc is authored against this surface and nothing below it.

| Need | Use | Never |
|---|---|---|
| Story beat fires | `CUTSCENE_REQUEST` via §8.2 | Call dialogue from a zone `Area2D` |
| Player lockout for a line | A cutscene (§8.4) | `DialogueLine.pause_player` — removed |
| Chapter ends | `CHAPTER_ADVANCE_REQUEST`, `to = from + 1` | Write `GameState.data.chapter` |
| Persist a beat | `on_complete_flag`, `ch<NN>_` prefix (§9.2) | Write another chapter's flags |
| Boss phase change | `CombatDirector.boss_phase` (§2.3) | Touch Doc 5's stem gains |
| Mid-fight line | `Mode.BUBBLE` (Doc 4 §3.2, §11.1) | `Mode.BOX` during combat |
| New creature | `PropScannable` + Doc 2 §5.4 scan entry | Bespoke reveal logic |
| Cipher | Doc 2 §5.6 `Cipher` + Doc 3 §6.1 schedule | A per-chapter cipher implementation |
| Hard gate | Always author a non-cipher path (Doc 2 §12.9) | A cipher-only wall |
| Respawn point | `Checkpoint` node, Doc 3 §9 placement rule | Custom respawn handling |
| State reset across a transition | A `TransitionTeardown` on the request (§7.4.1) | Mutate combat/player/health directly |
| Player ends a cutscene reading | `on_complete_intent` (§8.2.1) | Set Journal state after a cutscene |
| Dying mid-boss resumes the fight | `ENCOUNTER_STATE_REQUEST` (§11.3) | Write `checkpoint.encounter` directly |
| Player writes in the Journal | `JOURNAL_SUBMIT_REQUEST` (§8.3) | Call `JournalDB.submit_weakness()` from UI, or mutate a `JournalEntry` |

---

## 14. Contracts exported to Documents 1–5 and chapter docs

1. Gameplay mutations are committed only by `RuntimeDirector`; Godot callbacks publish events. The one scoped exception is `AnomalyField`'s per-tick force integration (§6.2).
2. `ZoneManager.activate_zone()` is the only path that changes `current_zone`, zone palette floor, and zone BGM — for exteriors and interiors alike.
3. Zone activation happens 96 px inside a destination, not merely at a shared edge.
4. Journal-open players cannot change zones or board vehicles; boundaries block rather than auto-close the Journal.
5. Audio changes on committed zone activation, never on scene preload.
6. Damage cancels interactions; same-tick hit resolution precedes cutscene start, attack, and dodge commitment.
7. A committed zone transition can defer lethal damage until the destination is reached.
8. Destination-world triggers remain dormant until the gated transition finishes and Player control returns.
9. Chapter docs author arrival dialogue as a `CUTSCENE_REQUEST`, never invoke dialogue directly from a zone `Area2D`.
10. No gameplay duration uses a `SceneTree` timer. Durations are tick counts derived from the owning document's constant.
11. `RuntimeDirector.process_physics_priority = 100`. The frame contract is void without it.
12. Saving is automatic and slot 0 is the only real save. Chapter replay uses a scratch slot and discards its progress.
13. `GameState.data.chapter` is monotonic and advances only by `CHAPTER_ADVANCE_REQUEST` from a chapter doc.
14. Flags are namespaced `ch<NN>_` / `zone_` / `sys_` / `npc_`. A chapter writes only its own prefix and the shared ones.
15. `Settings` is never part of a save.
16. Respawn reads in-memory state, never disk. Failure costs time, never progress.
17. Pause is dropped, not queued, in `CUTSCENE`, `ZONE_TRANSITION`, and `BLACKOUT`.
18. `CombatDirector` is the single source of `threat_active` and `boss_phase`; the HUD, dialogue mode selection, and boss audio all read it.
19. The event queue is double-buffered and swapped by `RuntimeDirector` alone. Nothing clears it on a schedule, so an event published from an idle-frame input handler can never be dropped unseen.
20. **Seamless travel takes no transition lock and does not end the tick.** Only gated travel, the seam fallback, and a cross-zone respawn lock the frame.
21. A transition's duration is a physics-tick countdown. Tweens mirror it; no tween, fade, or animation ever gates a gameplay state change.
22. `RESPAWN_REQUEST` is the only event that passes the priority-0 gate, consumed by `_resolve_locked()`.
23. A cutscene always ends `FREE` with the Journal `CLOSED`. A chapter wanting another end state declares `on_complete_intent`, which resolves as an ordinary intent and may lose to damage.
24. Transition-time state changes are declared as a `TransitionTeardown` resource and committed by `RuntimeDirector`. Chapters never mutate combat, player, health, Weirdness, or checkpoint state during a transition.
25. Neither `TransitionTeardown` nor an `encounter` block may carry a `Callable`. Both are plain data, and the resolver performs every commit.
26. A checkpoint taken inside a boss fight carries an `encounter` block and resumes the fight at its phase. Ordinary checkpoints reset combat as before. Chapters arm and clear it with `ENCOUNTER_STATE_REQUEST`; they never write `checkpoint.encounter`.
27. `JournalEntry` resources are immutable authored data. Every mutable per-entry fact lives in `GameState.data.journal_overrides` and is read through `JournalDB`.
28. Player-typed text — weakness fields and cipher answers alike — is submitted as `JOURNAL_SUBMIT_REQUEST` and committed by the resolver at priority 12. UI panes collect text and react to `journal_submit_committed`; they never validate or write.
29. **`GameState` holds only persisted fields, in one `SaveData` reached as `GameState.data`.** Live health, stamina, Journal state, and item state belong to the player node and are reached through `RuntimeDirector.player`. A system reaching for the nearest global instead of the owner is a bug, not a shortcut.
30. **`Journal`, `Health`, and `Stamina` are nodes on the player, never autoloads.** Journal timings live in the static `JournalConst` so they are readable at parse time; Journal state lives on the node.
31. **`Weirdness.applied` is the value every system reads.** `target_level` is where the tween is headed and nothing renders or mixes against it. `pulse()`/`release()` may be called directly from anywhere — `Weirdness` is presentation state with no resolver requirement. `set_zone_floor()` belongs to `activate_zone()` alone.
32. **The save format is JSON, normalized in `deserialize` and nowhere else**: keys are `String` on disk and rebuilt as `StringName`; `Vector2` stores as `[x, y]`. Writes go to a temp file and are renamed into place.
33. **Checkpoints name a `spawn_marker`; `position` is a fallback** for mid-zone checkpoints only. No authored checkpoint or teardown carries a raw world coordinate.
34. **Verbs are gated at the resolver, never by binding or unbinding `InputMap` actions.** Every action is bound at boot; an unearned verb is refused at priority 11/12 by an inventory check.
35. **`RuntimeDirector` sees a hitbox on the tick after it arms.** `get_overlapping_areas()` reflects the last completed physics step; no `process_physics_priority` changes that. One tick, uniform, accepted.
36. **One `PlayerInput` node publishes every player intent.** Unpausing is the pause menu's own affordance and does not route through the resolver, which is not running while paused.
37. **The web export is best-effort; macOS native is the target.** Seamless streaming assumes worker threads and degrades to gated travel without them (Doc 3 §3.3).
