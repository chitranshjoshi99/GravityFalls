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
##      scenes. Those arrive with tracker rows 0.9 and 0.10; nothing needs
##      them yet, so nothing is written for them here.
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
