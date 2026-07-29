extends Node
## Combat state — Doc 00 §2.3. The aggro set, `threat_active`, and the boss
## fields, and nothing else.
##
## Doc 4 §2.7 and §3.2 both read combat state that no document defined, and Doc 5
## §4.2 gates the boss music on `boss_phase`. Contract 18 makes this file the
## single source of all three, which is the whole reason it exists.
##
## **It reaches nothing.** The resolver, the event queue, `GameState`,
## `Weirdness`, Doc 5's audio autoload (row 3.2) and the player are all named
## nowhere below, deliberately and checkably (row 0.11's Verify column): §14.1
## gives the resolver sole ownership of gameplay mutation, and this director owns
## only its own domain. Callers come to it — the resolver on respawn (§11.2 step
## 5), a chapter on a phase change, an enemy on aggro — and it calls out to no
## one. That is what keeps it testable without a scene, and what keeps it from
## becoming a second place gameplay gets committed.
##
## Durations are physics-tick counts derived from their owning document's float
## (§2.4), never `SceneTree` timers: a timer mutates state outside the resolver,
## does not survive §10's pause predictably, and cannot be stepped by a headless
## test.

## §2.3. Doc 4 §2.7's contextual fade and §3.2's dialogue mode both subscribe.
signal threat_changed(active: bool)
## §2.3. Doc 5 §4.2's boss-music gating subscribes to this and reads `boss_phase`;
## the traffic is one-way, which is why no audio identifier appears in this file.
signal boss_phase_changed(boss_id: StringName, phase: int)

## Doc 00 §2.2's table. Above every gameplay node (default 0) and below
## `RuntimeDirector` (100), so the flag this file decides is already settled by
## the time the resolver reads it in the same frame.
const PHYSICS_PRIORITY := 50

const TICK := 1.0 / 60.0

## Doc 4 §2.7 `HudVisibility.IDLE_HIDE_DELAY` is the authority for this 4.0, and
## §2.3 writes it as `const THREAT_LINGER := HudVisibility.IDLE_HIDE_DELAY` —
## referenced, never copied, because two copies drift the first time either moves
## (§0.1). **`HudVisibility` does not exist yet**: it is the `CanvasLayer` script
## Doc 4 §2.7 authors, its contextual fade is tracker Deferred D9, and it arrives
## with the HUD at row 3.5. Naming a class that does not exist is a parse error,
## not a runtime one, so the float is inlined here.
# ponytail: literal 4.0 until row 3.5, where `HudVisibility.IDLE_HIDE_DELAY`
# replaces it. The suite already asserts the two agree the moment that file
# appears, so the drift cannot survive the row that closes this.
const THREAT_LINGER := 4.0

## §2.4: the float is the authority and the tick count is derived from it. A
## hand-typed 240 would be a second number to maintain.
const THREAT_LINGER_TICKS := int(round(THREAT_LINGER / TICK))

var threat_active: bool = false      ## Doc 4 §2.7, §3.2 read this
var boss_active: bool = false        ## replaces Doc 4's BossDirector.active
var boss_id: StringName = &""
var boss_phase: int = 0              ## Doc 5 §4.2 gates boss_gnome's music on this

## Keyed by instance id so an enemy freed without deregistering is detectable —
## a Node reference would go dangling and a name would not be unique.
##
# ponytail: §2.3 declares the value as "ticks since last aggro", and nothing
# reads it: de-aggro is an explicit `deregister_aggro()` call (§2.3), so there is
# no per-enemy timeout for a per-entry counter to drive. Dictionary-as-set is
# Godot's idiom for exactly this. Row 4.3 brings the first real enemy; if it ever
# wants a decay rather than an explicit call, the value is where it goes.
var _aggro: Dictionary = {}

## §2.3's linger, counted down only while `_aggro` is empty. Re-armed on every
## tick the set is non-empty, so the HUD does not blink off between waves.
var _linger_ticks: int = 0

## §11.3's named phase setups, registered by a chapter at `_ready()`.
# ponytail: the stored value is untyped because nothing instantiates it until
# row 4.6 — `has_phase_setup()` is the only half the resolver needs today, to
# refuse an `ENCOUNTER_STATE_REQUEST` naming a setup that was never registered.
var _phase_setups: Dictionary = {}


func _ready() -> void:
	process_physics_priority = PHYSICS_PRIORITY
	# Doc 00 §2.2. Godot adds autoloads as root's first children, so the default
	# priority would prune and decide `threat_active` BEFORE this frame's enemies
	# have registered — a one-frame-stale flag rather than a crash. Asserted
	# rather than merely written, for the same reason the resolver asserts its 100.
	assert(
		process_physics_priority > 0,
		"CombatDirector must tick after every gameplay node (Doc 00 §2.2)"
	)


## An enemy registers on aggro (§2.3) and deregisters on death or de-aggro.
func register_aggro(enemy: Node) -> void:
	# `is_instance_valid` rather than a null check: it covers both null and an
	# already-freed node, and `get_instance_id()` on a freed one is an error.
	if not is_instance_valid(enemy):
		return
	_aggro[enemy.get_instance_id()] = true
	# A second enemy arriving during the linger cancels the countdown outright,
	# which is what "does not blink off between waves" means.
	_linger_ticks = THREAT_LINGER_TICKS
	_set_threat(true)


## De-aggro or death. `threat_active` is NOT dropped here — §2.3's linger is
## decided in one place, `_physics_process`, and this is not it.
func deregister_aggro(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		# Already freed, so its id is already invalid and the prune above owns it.
		return
	_aggro.erase(enemy.get_instance_id())


func _physics_process(_delta: float) -> void:
	# The root-cause guard, and it lives here rather than in each caller: an enemy
	# that dies without deregistering — freed by a zone teardown, or by any of the
	# paths row 4.3 has not written yet — would otherwise pin `threat_active` true
	# forever, and the HUD would never come back. One prune where the flag is
	# decided covers every caller there will ever be.
	for id: int in _aggro.keys():
		if not is_instance_id_valid(id):
			_aggro.erase(id)

	if not _aggro.is_empty():
		_linger_ticks = THREAT_LINGER_TICKS
		_set_threat(true)
	elif threat_active:
		_linger_ticks -= 1
		if _linger_ticks <= 0:
			_set_threat(false)


## §2.3 / §11.3 step a. A chapter begins an encounter; the phase content and the
## per-boss phase COUNT are chapter data (Doc 5 §4.2 gives `boss_gnome` three,
## `boss_bill` five), so no count is encoded here — rows 4.4 and 5.9 own it.
func begin_boss(id: StringName, phase: int = 0) -> void:
	boss_active = true
	boss_id = id
	set_boss_phase(phase)


## Doc 6 §7's phase progression, and the reason `boss_phase` has one writer.
func advance_boss_phase() -> void:
	set_boss_phase(boss_phase + 1)


## **The only writer of `boss_phase`.** Doc 5 §4.2 gates the boss music on this
## field and on nothing else, and chapter docs advance it here rather than
## reaching into Doc 5's mixer themselves (§2.3). One writer is what makes that
## claim checkable.
func set_boss_phase(phase: int) -> void:
	if boss_phase == phase:
		return
	boss_phase = phase
	boss_phase_changed.emit(boss_id, phase)


## The boss's defeat, and Doc 06 §5.4's `clear_combat` teardown flag. The phase
## is cleared before the id so the final emission still names the boss that ended.
func clear_boss() -> void:
	boss_active = false
	set_boss_phase(0)
	boss_id = &""


## §3.2 step 3 (`begin_session`), §3.3 (`end_session`) and §11.2 step 5 (an
## ordinary respawn): the player wakes up safe, never into an active threat.
func reset() -> void:
	_aggro.clear()
	_linger_ticks = 0
	_set_threat(false)
	clear_boss()


## §11.3. Called instead of `reset()` when the checkpoint carries an `encounter`
## block — `{ &"boss_id": StringName, &"phase": int, &"setup": StringName }` —
## because resetting mid-boss drops the player at a checkpoint with the boss gone
## and the fight unwinnable.
func restore_encounter(encounter: Dictionary) -> void:
	# The block round-trips through the save file (§9.2), so it is not trusted to
	# be well formed. An armed encounter naming no boss would leave `boss_active`
	# true with nothing to fight — the same unwinnable respawn §11.3 exists to
	# prevent, arrived at from the other direction.
	var id: StringName = encounter.get(&"boss_id", &"")
	if id == &"":
		push_error("encounter block names no boss_id, resetting instead: %s" % encounter)
		reset()
		return

	# Step c: aggro is cleared. The boss is not aggro, it is state.
	_aggro.clear()
	_linger_ticks = 0
	_set_threat(false)

	# Step a. The phase is the one to resume AT, not to restart from.
	begin_boss(id, int(encounter.get(&"phase", 0)))

	# ponytail: step b — instantiating the setup named by `encounter.setup` (the
	# boss rig, any vehicle and any escort NPC at their phase-start positions) —
	# is row 4.6's, which is also where `_phase_setups` gains a reader. Step c's
	# ordinary-enemy respawn is row 2.7's, and step d — the boss piece resuming at
	# the phase's authored configuration, cutting on the next bar (Doc 5 §4.4) —
	# is row 3.2's. What this row owns is committed above.


## §11.3's last paragraphs: a chapter registers its named phase setups at
## `_ready()`. `setup` is a `StringName` — never a scene path, and never a
## `Callable`, which contract 25 forbids in an encounter block outright.
##
## The parameter is `setup_name` rather than §11.3's `name` because `name` is
## `Node.name` here and shadowing it is a warning on every parse.
func register_phase_setup(setup_name: StringName, setup: Variant) -> void:
	_phase_setups[setup_name] = setup


## §11.3 / §12 check 28. An `ENCOUNTER_STATE_REQUEST` whose `setup` names
## something never registered is rejected rather than written, because a typo
## there produces a checkpoint that respawns into an empty boss arena — and the
## player only discovers it after dying.
func has_phase_setup(setup_name: StringName) -> bool:
	return _phase_setups.has(setup_name)


## One writer of `threat_active`, so the signal cannot fire without the field
## moving or the field move without the signal.
func _set_threat(active: bool) -> void:
	if threat_active == active:
		return
	threat_active = active
	threat_changed.emit(active)
