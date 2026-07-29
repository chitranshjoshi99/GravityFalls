extends RefCounted
##
## Shared scaffolding for the one test suite, res://tests/test_all.gd.
##
## Two jobs, and they stay separate:
##
##   1. Check bookkeeping — `expect()` / `expect_eq()` record a pass or a
##      failure and never abort. Godot strips `assert()` from release builds,
##      so a suite built on bare asserts silently passes there; these helpers
##      are what make the exit code honest.
##   2. The pure runtime harness of Doc 00 §12 — `reset()`, `enqueue()`,
##      `step()` and the Player / Journal / ZoneManager / Health stubs that
##      drive `RuntimeDirector._resolve()` with no physics server and no real
##      scenes.
##
## ponytail: no class_name. The suite runs as `godot --headless --script`,
## which resolves global class names out of the editor's class cache — a file
## that does not exist on a fresh clone that has never been imported. A
## `preload()` const in test_all.gd works with or without that cache.

var passed: int = 0
var failures: PackedStringArray = []


## Records a pass or a failure. Returns the condition so a caller can branch.
func expect(condition: bool, message: String) -> bool:
	if condition:
		passed += 1
	else:
		failures.append(message)
	return condition


## Equality check that puts both sides in the failure line — the difference
## between "stretch aspect is wrong" and a message you can act on.
func expect_eq(actual: Variant, expected: Variant, what: String) -> bool:
	return expect(
		actual == expected,
		"%s: expected %s, got %s" % [what, str(expected), str(actual)]
	)


func report() -> void:
	if failures.is_empty():
		print("test_all: %d checks passed" % passed)
		return
	printerr("test_all: %d passed, %d FAILED" % [passed, failures.size()])
	for f in failures:
		printerr("  FAIL  %s" % f)


func exit_code() -> int:
	return 0 if failures.is_empty() else 1


# --- 2. the pure runtime harness — Doc 00 §12 -------------------------------
#
# The resolver is a pure function of (queue, state), so §12's harness drives it
# with hand-enqueued events and stub systems: no physics server, no rendering,
# no real scenes, and — the point of check 20 — no tween anywhere in existence.
#
# It drives the LIVE `RuntimeDirector` and `RuntimeEvents` autoloads, never
# fresh instances of their scripts: the resolver reads the `RuntimeEvents`
# singleton, so a second queue instance is one it would never see. That makes
# the autoloads shared state across checks, which is what `reset()` is for.
#
# The autoload GLOBAL IDENTIFIERS (`RuntimeEvents`, `GameState`) are not usable
# here — this script is preloaded by test_all.gd and therefore compiles before
# a `--script` SceneTree instantiates any autoload. The nodes themselves exist
# by the time a check runs, so they are reached from the director by path.

var director: Node                 ## the live RuntimeDirector autoload
var player: PlayerController       ## real: RuntimeDirector.player is typed
var journal: Node
var zone: Node
var health: Node
var stub_interactable: Node
var _events: Node
var _game_state: Node
## The three row-0.11 directors the resolver now commits into. Shared with every
## check, so `reset()` clears each one's own domain state — see `_reset_directors()`.
var _combat: Node
var _cutscene: Node
var _transition: Node


## Doc 00 §5.2 / §7.5. The resolver asks one question of the Journal — "does
## this block travel", i.e. "is it anything other than CLOSED".
class JournalStub extends Node:
	var open := false
	func blocks_zone_travel() -> bool:
		return open


## Doc 00 §7.2. `activate_zone()` is the single writer of the current zone, and
## the call count is what check 17 and check 2 both read.
class ZoneStub extends Node:
	var current_zone: StringName = &"z_shack_ext"
	var unlocked := true
	var seam_open := true
	var activate_calls := 0

	func is_unlocked(_to: StringName) -> bool:
		return unlocked

	func is_seam_open(_from: StringName, _to: StringName) -> bool:
		return seam_open

	func activate_zone(to: StringName) -> void:
		current_zone = to
		activate_calls += 1


## Doc 2 §7.1. `take_damage()` returns false when an i-frame refuses the hit,
## which is what lets the resolver treat several sources in one tick as one hit.
class HealthStub extends Node:
	var max_pips := 6
	var current := 6
	var take_damage_calls := 0

	func take_damage(amount: int) -> bool:
		take_damage_calls += 1
		current = maxi(current - amount, 0)
		return true


## Doc 00 §6.1's interaction target: `enabled` is re-verified at commit time.
class InteractableStub extends Node:
	var enabled := true
	var interact_calls := 0

	func interact(_by: Node) -> void:
		interact_calls += 1


## Points the live resolver at a fresh set of stubs and leaves it, the queue and
## GameState in a known condition. Check order can therefore never change a
## result, which matters more here than anywhere else in the suite: every check
## below shares one director instance.
func reset(d: Node) -> void:
	release()
	director = d
	_events = d.get_node(^"/root/RuntimeEvents")
	_game_state = d.get_node(^"/root/GameState")
	# By path from the director, for the reason in this section's header: the global
	# identifiers are unusable in a preloaded script.
	_combat = d.get_node(^"/root/CombatDirector")
	_cutscene = d.get_node(^"/root/CutsceneDirector")
	_transition = d.get_node(^"/root/TransitionDirector")
	_reset_directors()

	player = PlayerController.new()
	journal = JournalStub.new()
	zone = ZoneStub.new()
	health = HealthStub.new()
	stub_interactable = InteractableStub.new()
	player.journal = journal
	player.health = health

	director.zone_manager = zone
	director.bind(player)
	director._pending_blackout = false
	director._lock_ticks = 0
	director._arrival_grace_ticks = 0
	director._pending_zone = &""
	director._pending_marker = &""
	director._pending_teardown = {}
	director._zone_committed = false
	director._damage_committed = false

	# Two swaps drain both buffers: the first discards whatever the previous
	# check left resolvable, the second discards what that swap made active.
	_events.swap()
	_events.swap()
	# A committed activation calls GameState.mark_dirty(), and GameState._process
	# would then autosave over the developer's real slot 0.
	_game_state._dirty = false


## The resolver commits into all three row-0.11 directors, and every check drives
## the one live instance of each — so a check that leaves a boss armed, a cutscene
## pending or the overlay mid-fade would otherwise change the next check's result.
## Each director's own reset is what prevents that; nothing here reaches inside one
## except `_phase_setups`, which `CombatDirector.reset()` deliberately keeps (a
## chapter registers its setups once, at `_ready()`).
func _reset_directors() -> void:
	_combat.reset()
	_combat._phase_setups.clear()
	_cutscene.reset()
	# TransitionDirector has no reset() by design — the alpha is its only state, and
	# `set_opaque()` both writes it and kills any tween in flight (its header).
	_transition.set_opaque(false)


func enqueue(type: RuntimeEvent.Type, payload: Dictionary = {}) -> void:
	_events.enqueue(type, null, payload)


## One physics tick. `_physics_process()` IS the tick contract of Doc 00 §4.1
## step 4 — swap, poll, tick durations, resolve, defer — so it is called rather
## than re-implemented: a step that called `_resolve()` alone would silently
## never exercise `_defer_survivors()` and therefore never exercise §4.6, and a
## hand-written copy would drift from the resolver the first time §4.1 moves.
##
## Statically typed as `Node`, `director._physics_process(0.0)` dispatches to
## the native no-op virtual; `call()` reaches the GDScript override.
## Nothing awaits: no physics server runs and no real time passes.
func step() -> void:
	director.call(&"_physics_process", 0.0)


## Frees every node the harness made and unbinds the live director, so a real
## physics frame after the suite finishes cannot resolve against freed stubs.
func release() -> void:
	if director != null:
		director.player = null
		director.zone_manager = null
		director._lock_ticks = 0
		director._arrival_grace_ticks = 0
		director._pending_blackout = false
		director._pending_zone = &""
		director._pending_marker = &""
		director._pending_teardown = {}
	if _events != null:
		_events.swap()
		_events.swap()
	if _game_state != null:
		_game_state._dirty = false
	# Also on the way out, so a real physics frame after the suite finishes cannot
	# resolve against an armed boss or a cutscene the suite left pending.
	if _combat != null:
		_reset_directors()
	for n: Node in [player, journal, zone, health, stub_interactable]:
		if n != null:
			n.free()
	player = null
	journal = null
	zone = null
	health = null
	stub_interactable = null
