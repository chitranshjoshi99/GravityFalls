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
const TokensScript := preload("res://autoload/tokens.gd")
const PaletteResource := preload("res://core/palette.gd")
const CharacterProportionsResource := preload("res://core/character_proportions.gd")
const TubeGeometry := preload("res://core/tube.gd")
const EyeGeometry := preload("res://core/eyes.gd")
const WeirdnessScript := preload("res://autoload/weirdness.gd")

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
	# One frame before anything runs. A node added to `root` during `_init()` is
	# not yet inside the tree, and a Tween bound to a node outside the tree does
	# not advance — which would make row 0.6's check silently assert nothing.
	await process_frame

	var h := RuntimeHarness.new()

	_check_display_settings(h)   # tracker 0.1
	_check_project_structure(h)  # tracker 0.2
	_check_tokens_and_resources(h)  # tracker 0.4
	_check_geometry(h)              # tracker 0.5
	_check_weirdness(h)             # tracker 0.6 / Doc 00 §12 check 36

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


## Tracker 0.4 / Doc 01 §§1 and 3. Resource loading catches broken ext_resource
## paths and class regressions before zones or character scenes depend on them.
func _check_tokens_and_resources(h) -> void:
	# A --script SceneTree is launched directly and does not instantiate project
	# autoloads; assert the project registration and the constants themselves.
	h.expect_eq(
		ProjectSettings.get_setting("autoload/Tokens"), "*res://autoload/tokens.gd",
		"Tokens autoload registration"
	)
	h.expect(TokensScript.EXPRESSION_PRESETS.has(&"worried"), "Tokens exposes expression presets")
	var woods := load("res://resources/palettes/pal_woods.tres")
	h.expect(woods is PaletteResource, "pal_woods.tres loads as Palette")
	if woods is PaletteResource:
		h.expect_eq(woods.ambient_weirdness, 0.05, "woods ambient weirdness")

	var dipper := load("res://resources/proportions/prop_dipper.tres")
	h.expect(dipper is CharacterProportionsResource, "prop_dipper.tres loads as CharacterProportions")
	if dipper is CharacterProportionsResource:
		var stack: float = dipper.head_diameter + dipper.segment(&"torso").x \
			+ dipper.segment(&"leg_upper").x + dipper.segment(&"leg_lower").x \
			+ dipper.segment(&"foot").x
		h.expect(
			absf(stack - dipper.height) < dipper.height * 0.05,
			"proportion stack %f remains within 5%% of declared height %f" % [stack, dipper.height]
		)


## Tracker 0.5 / Doc 01 §§4–5. These checks protect geometry that otherwise
## fails only after real hose textures are authored.
func _check_geometry(h) -> void:
	var capsule := TubeGeometry.capsule(100.0, 20.0, 8)
	h.expect_eq(capsule.size(), 28, "capsule vertex count")
	h.expect(_signed_area(capsule) > 0.0, "capsule winding is clockwise in Y-down space")
	for point in capsule:
		h.expect(absf(point.x) <= 10.001, "capsule respects half-width at %s" % point)
		h.expect(point.y >= -10.001 and point.y <= 110.001, "capsule respects cap bounds at %s" % point)

	var in_blend_band := 0
	for point in capsule:
		var t: float = point.y / 100.0
		if t > 0.38 and t < 0.62:
			in_blend_band += 1
	h.expect(in_blend_band >= 4, "capsule has at least four vertices in the hose blend band")

	var tapered := TubeGeometry.capsule(100.0, 20.0, 8, 16.0)
	h.expect_eq(tapered.size(), 28, "tapered capsule vertex count")
	h.expect(absf(tapered[0].x) > absf(tapered[tapered.size() / 2].x), "capsule tapers at the far end")

	var proportions := CharacterProportionsResource.new()
	var arm_length: float = proportions.segment(&"arm_upper").x + proportions.segment(&"arm_fore").x
	var arm_width: float = proportions.segment(&"arm_upper").y
	var arm_width_end: float = proportions.segment(&"arm_fore").y
	var hose := TubeGeometry.capsule(arm_length, arm_width, 8, arm_width_end)
	var uv := TubeGeometry.hose_uv(hose, arm_width, arm_width_end)
	var texture_size := TubeGeometry.hose_texture_size(arm_length, arm_width, arm_width_end)
	h.expect_eq(uv.size(), hose.size(), "hose has one UV per vertex")
	for coordinate in uv:
		h.expect(
			coordinate.x >= 0.0 and coordinate.x <= texture_size.x
				and coordinate.y >= 0.0 and coordinate.y <= texture_size.y,
			"hose UV remains inside its texture at %s" % coordinate
		)

	var previous_fore_weight := -1.0
	for i in range(21):
		var weight := TubeGeometry.hose_weights(float(i) / 20.0)
		h.expect(is_equal_approx(weight.x + weight.y, 1.0), "hose weights partition to one at t=%f" % (float(i) / 20.0))
		h.expect(weight.y >= previous_fore_weight, "hose fore weight is monotonic")
		previous_fore_weight = weight.y
	h.expect_eq(TubeGeometry.hose_weights(0.0), Vector2(1.0, 0.0), "hose starts fully upper-bone")
	h.expect_eq(TubeGeometry.hose_weights(1.0), Vector2(0.0, 1.0), "hose ends fully fore-bone")

	var eye := EyeGeometry.geometry(82.0)
	var pupil_max_offset: float = float(eye["pupil_max_offset"])
	var pupil_radius: float = float(eye["pupil_radius"])
	var radius: float = float(eye["radius"])
	var offset := EyeGeometry.pupil_offset(Vector2(9.0, -4.0), pupil_max_offset)
	h.expect(offset.length() <= pupil_max_offset + 0.001, "pupil never escapes the sclera")
	h.expect(pupil_radius + pupil_max_offset <= radius, "pupil geometry fits inside the sclera")


## Tracker 0.6 / Doc 00 §12 check 36. `level_changed` must carry `applied` — the
## eased value — and never `target_level`, which snaps the instant a pulse is
## requested. If those two ever diverge, "one float runs the supernatural"
## becomes two floats on two curves, and the visuals and the audio drift apart
## at exactly the authored moments that matter.
##
## The tween is advanced with custom_step() rather than by awaiting frames, so
## this check is a pure function of the calls made and cannot flake on timing.
##
## The other half of check 36 — that a mid-tween pulse leaves exactly one writer
## of a *stem's* volume_db — needs AudioDirector, which arrives at tracker row
## 3.2. What is asserted here is the upstream cause: exactly one live tween
## writing `applied`. The stem assertion is appended when the stems exist.
func _check_weirdness(h) -> void:
	h.expect_eq(
		ProjectSettings.get_setting("autoload/Weirdness"), "*res://autoload/weirdness.gd",
		"Weirdness autoload registration"
	)

	var shader := load("res://shaders/weirdness.gdshader")
	h.expect(shader is Shader, "weirdness.gdshader loads as a Shader")
	if shader is Shader:
		var uniforms: PackedStringArray = []
		for u in shader.get_shader_uniform_list():
			uniforms.append(String(u["name"]))
		h.expect(uniforms.has("weirdness"), "shader exposes the weirdness uniform")
		# Row 0.7's reduce_flashing clamps this, so it cannot become a literal.
		h.expect(uniforms.has("aberration_px"), "shader keeps aberration_px a uniform")

	# create_tween() needs a node in the tree, and a --script SceneTree does not
	# instantiate project autoloads, so the check builds its own instance.
	var w: Node = WeirdnessScript.new()
	root.add_child(w)

	var seen: Array[float] = []
	w.level_changed.connect(func(v: float) -> void: seen.append(v))

	w.set_zone_floor(0.8, 1.2)
	h.expect_eq(w.target_level, 0.8, "zone floor sets the target")
	h.expect_eq(w.applied, 0.0, "applied does not snap to the target")
	h.expect(seen.is_empty(), "no emission before the tween moves")

	w._tween.custom_step(0.6)
	h.expect(
		w.applied > 0.0 and w.applied < 0.8,
		"applied eases toward the target, got %f" % w.applied
	)
	h.expect(not seen.is_empty(), "the tween emits level_changed")
	if not seen.is_empty():
		h.expect_eq(seen[-1], w.applied, "level_changed carries applied")
		for v in seen:
			h.expect(v != 0.8, "level_changed never carries the snapped target")

	# A pulse landing mid-tween must replace the curve, not race it.
	var superseded: Tween = w._tween
	w.pulse(1.0, 0.4)
	h.expect(not superseded.is_running(), "a mid-tween pulse kills the running tween")
	h.expect(w._tween != superseded, "a mid-tween pulse starts exactly one new tween")
	h.expect_eq(w.target_level, 1.0, "an event above the floor wins")

	# Releasing the event decays back to the floor, not to zero.
	w.release(0.4)
	h.expect_eq(w.target_level, 0.8, "release returns to the zone floor")

	w.pulse(5.0)
	h.expect_eq(w.target_level, 1.0, "pulse clamps above one")
	w.release(0.1)
	w.set_zone_floor(-3.0)
	h.expect_eq(w.target_level, 0.0, "zone floor clamps below zero")

	# bind() applies immediately, so a freshly bound material is never a frame stale.
	var mat := ShaderMaterial.new()
	mat.shader = shader
	w.applied = 0.42
	w.bind(mat)
	h.expect_eq(
		mat.get_shader_parameter("weirdness"), w.applied,
		"bind() drives the material immediately"
	)

	w.free()


func _signed_area(points: PackedVector2Array) -> float:
	var area := 0.0
	for i in range(points.size()):
		var next := points[(i + 1) % points.size()]
		area += points[i].x * next.y - next.x * points[i].y
	return area * 0.5


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
