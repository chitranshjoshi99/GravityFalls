extends SceneTree
##
## THE test suite. One entry point for every check in the project:
##
##     godot --headless --script res://tests/test_all.gd
##
## Every tracker row appends its Verify column here. Rows marked (scene) need a
## real tree and run from res://tests/scene_harness.tscn — they are still
## *entered* from this file, so there is never a second suite to remember.
##
## Exit code is 0 when green and 1 when anything failed. That is the whole
## contract this file owes the tracker.

const RuntimeHarness := preload("res://tests/harness.gd")

## Doc 01 §10's tree, which is the single authority for every res:// path in
## the project. A directory not on this list is a finding: either the file
## belongs somewhere else, or §10 gets amended and this list moves with it.
##
## §10 also says "create no folder before its first file", so this is a list of
## what is *allowed*, never a list of what must exist.
const ALLOWED_DIRS: PackedStringArray = [
	"res://autoload",
	"res://core",
	"res://actors",
	"res://actors/player",
	"res://actors/npc",
	"res://actors/enemy",
	"res://actors/vehicle",
	"res://world",
	"res://world/zones",
	"res://world/nodes",
	"res://world/tilesets",
	"res://ui",
	"res://ui/hud",
	"res://ui/journal",
	"res://ui/dialogue",
	"res://ui/menus",
	"res://chapters",
	"res://resources",
	"res://resources/palettes",
	"res://resources/proportions",
	"res://resources/zones",
	"res://resources/journal",
	"res://assets",
	"res://assets/characters",
	"res://assets/fx",
	"res://assets/props",
	"res://assets/tiles",
	"res://assets/ui",
	"res://assets/fonts",
	"res://assets/audio",
	"res://assets/audio/bgm",
	"res://assets/audio/sfx",
	"res://assets/audio/blips",
	"res://shaders",
	"res://tests",
	# tools/ is "outside res://" in §10's sense — never shipped, never run at
	# boot — which the export preset's exclude_filter is what actually enforces.
	# The repo root IS the project root, because the tracker's one test command
	# is `godot --headless --script res://tests/test_all.gd` with no --path.
	"res://tools",
	# Repo-level, not game content: excluded from the export, allowed on disk.
	"res://docs",
	"res://executions",
]

## Directories matched by prefix rather than exact name. §10 gives
## assets/characters/<name>/ one subdirectory per character.
const ALLOWED_DIR_PREFIXES: PackedStringArray = [
	"res://assets/characters/",
	# One folder per chapter, created only when that chapter is written.
	"res://chapters/ch",
]

## Files §10 does not place, because they are the project's own root furniture.
const ALLOWED_ROOT_FILES: PackedStringArray = [
	"project.godot",
	"export_presets.cfg",
	"README.md",
	"foundation.md",
	"icon.svg",
]

## Never walked: engine cache and version control.
const SKIPPED_DIRS: PackedStringArray = [
	"res://.godot",
	"res://.git",
]


func _init() -> void:
	var h := RuntimeHarness.new()

	_check_display_settings(h)   # tracker 0.1
	_check_project_structure(h)  # tracker 0.2

	# --- (scene) checks -----------------------------------------------------
	# Doc 00 §12's checks 1-3, 6, 14, 34, 35 and 39 need a real scene tree and
	# run from res://tests/scene_harness.tscn, entered from right here. Nothing
	# needs a tree until tracker row 0.12, so the harness scene is not built.

	h.report()
	quit(h.exit_code())


## Tracker 0.1 / Doc 01 §0. The programmatic half of the gate. The other half —
## that a 16:10 panel letterboxes instead of stretching — is an observation that
## needs something on screen, and is made when the first scene exists (row 1.1).
func _check_display_settings(h) -> void:
	h.expect_eq(
		ProjectSettings.get_setting("display/window/size/viewport_width"), 1920,
		"viewport width"
	)
	h.expect_eq(
		ProjectSettings.get_setting("display/window/size/viewport_height"), 1080,
		"viewport height"
	)
	h.expect_eq(
		ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items",
		"stretch mode"
	)
	# The one that silently costs ~120px of extra world on every MacBook panel
	# if it drifts to "expand".
	h.expect_eq(
		ProjectSettings.get_setting("display/window/stretch/aspect"), "keep",
		"stretch aspect"
	)


## Tracker 0.2 / Doc 01 §10. Walks the whole project and fails on any directory
## the tree does not name, or any file loose at the root that is not root
## furniture. Catches layout drift the day it happens rather than the day
## someone cannot find dipper.tscn.
func _check_project_structure(h) -> void:
	var offenders: PackedStringArray = []
	_walk("res://", offenders)
	h.expect(
		offenders.is_empty(),
		"paths outside the Doc 01 §10 tree: %s" % ", ".join(offenders)
	)


func _walk(dir_path: String, offenders: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		offenders.append("%s (unreadable)" % dir_path)
		return

	var base := dir_path.trim_suffix("/")
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var path := "%s/%s" % [base, name]
		if dir.current_is_dir():
			if not SKIPPED_DIRS.has(path):
				if _dir_allowed(path):
					_walk(path, offenders)
				else:
					offenders.append(path + "/")
		elif dir_path == "res://" and not ALLOWED_ROOT_FILES.has(name):
			# Files inside an allowed directory are that directory's business;
			# a stray file at the root is not.
			offenders.append(path)
		name = dir.get_next()
	dir.list_dir_end()


func _dir_allowed(path: String) -> bool:
	if ALLOWED_DIRS.has(path):
		return true
	for prefix in ALLOWED_DIR_PREFIXES:
		if path.begins_with(prefix):
			return true
	return false
