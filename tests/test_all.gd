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
const SettingsScript := preload("res://autoload/settings.gd")
const SaveDataResource := preload("res://core/save_data.gd")
const GameStateScript := preload("res://autoload/game_state.gd")
const RuntimeEventRecord := preload("res://core/runtime_event.gd")
const RuntimeEventsScript := preload("res://autoload/runtime_events.gd")
## Preloaded like every script above, and for the same reason harness.gd's header
## gives: a `--script` run resolves the global name `RigHumanoid` out of the
## editor's class cache, which a fresh clone does not have.
const RigHumanoidScene := preload("res://actors/rig_humanoid.tscn")
const EyePairScene := preload("res://actors/eye_pair.tscn")

## Doc 01 §6.2's draw-order table, written down once so a part added later with
## no `z_index` fails loudly instead of drawing wherever the tree happens to put
## it. §6.2 is the SOLE sort inside a character (AUDIT B19), which makes this
## table the whole of row 1.1's Verify column.
##
## Two reconciliations, both forced by §6.2 disagreeing with the rest of Doc 01:
##
##   * §6.2 rows read `arm_far_hose` / `arm_near_hose` / `hand_far` / `hand_near`,
##     but §12 contract 8 and §9.3 name the NODES `arm_hose_l/r`, `hand_l/r`.
##     Far and near are ROLES: the −20 / +40 pair that §6.2's own "side-facing
##     swaps the two arm groups" moves between them. Front-facing is the default
##     and the base authors it — right arm near, left arm far, because §6.3 gives
##     `a_hand_r` the flashlight, the grapple and the one-handed Journal carry.
##     No swap machinery exists yet; a facing system is row 1.2's.
##   * `hair_back` (10) and `hair_front` (30) are absent for exactly the reason
##     §6.1's `b_hair_01→03` chain is absent from the base: Wendy/Mabel only, and
##     an inherited scene adds nodes freely.
const PART_Z_INDEX: Dictionary = {
	"arm_hose_l": -20, "hand_l": -20,
	"leg_hose_l": -10, "leg_hose_r": -10, "foot_l": -10, "foot_r": -10,
	"torso": 0,
	"head_base": 10,
	"eyes": 20, "brows": 20, "mouth": 20,
	"hat": 30,
	"arm_hose_r": 40, "hand_r": 40,
	"held_item": 50,
}

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

	# Six checks below drive a specified `push_error` on purpose — §8.2.1's
	# forbidden-intent gate, §8.2's unrequested-cutscene refusal, and §11.3's
	# unregistered-setup refusal — so a GREEN run prints six ERROR lines. Said out
	# loud because row 6.1's gate is the printed `checks passed` line, and a reader
	# who learns to skim past ERROR output is a reader who will skim past a real
	# one. If the count here stops matching, that is itself the finding.
	print("test_all: six ERROR lines below are EXPECTED — checks that assert push_error fires")

	var h := RuntimeHarness.new()

	_check_display_settings(h)   # tracker 0.1
	_check_project_structure(h)  # tracker 0.2
	_check_tokens_and_resources(h)  # tracker 0.4
	_check_geometry(h)              # tracker 0.5
	_check_weirdness(h)             # tracker 0.6 / Doc 00 §12 check 36
	_check_settings(h)              # tracker 0.7
	_check_save_data(h)             # tracker 0.8 / Doc 00 §12 checks 32–33
	_check_runtime_events(h)        # tracker 0.9 / Doc 00 §12 check 16
	_check_runtime_director(h)      # tracker 0.10 / Doc 00 §12 checks 15, 4, 17, 20
	_check_combat_director(h)       # tracker 0.11 / Doc 00 §2.3, §11.3
	_check_cutscene_director(h)     # tracker 0.11 / Doc 00 §8, §12 check 23
	_check_transition_director(h)   # tracker 0.11 / Doc 00 §7.4, §12 check 20
	# Last in the row, and last of the 0.11 calls on purpose: it drives the resolver
	# against all three directors above, so their own checks come first.
	_check_resolver_wiring(h)       # tracker 0.11 / Doc 00 §12 checks 22-24, 28

	# --- (scene) checks -----------------------------------------------------
	# Doc 00 §12's checks 1-3, 6, 14, 34, 35 and 39 need a real scene tree.
	# §12 says they run from res://tests/scene_harness.tscn; check 35 is the first
	# of them to come due (row 0.12) and it needs a real `root`, real nodes and a
	# real material — all of which a `--script` SceneTree already has — and no
	# physics server, no rendering and no main scene. So it runs here, in the one
	# suite, and the harness SCENE stays unbuilt until a check needs something a
	# `--script` run genuinely lacks: overlap queries, collision, a camera. Rows
	# 1.4 and 4.1 are where that arrives.
	await _check_session_director(h)   # tracker 0.12 / Doc 00 §12 checks 12, 35
	# Also a (scene) check: the rig is laid out by its own `_ready()`, so the
	# instances below are added to `root`. No physics, no rendering, no camera.
	_check_rig_humanoid(h)             # tracker 1.1 / Doc 01 §6, §12 contract 3
	_check_rig_parts(h)                # tracker 1.1 / Doc 01 §§4, 5, 6.2, §12 contract 8

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
	# A --script SceneTree does instantiate project autoloads, but this file
	# compiles before they exist, so the global identifier `Tokens` is not
	# usable here. Assert the project registration and the constants themselves.
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

	# create_tween() needs a node in the tree, hence the add_child(). A --script
	# SceneTree does instantiate project autoloads, so the live Weirdness node
	# exists — but this check drives the level hard and must not leave the
	# shipped singleton mid-tween, so it builds its own instance.
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


## Tracker 0.7 / Doc 04 §5.1. Preferences are person-level data, not a
## playthrough field: the test uses an isolated config path and never touches
## the developer's real settings.cfg.
func _check_settings(h) -> void:
	h.expect_eq(
		ProjectSettings.get_setting("autoload/Settings"), "*res://autoload/settings.gd",
		"Settings autoload registration"
	)
	var path := "user://test_settings_0_7.cfg"
	DirAccess.remove_absolute(path)
	var settings: Node = SettingsScript.new()
	settings.load_from(path)
	h.expect(settings.text_effects_enabled, "text effects default on")
	h.expect_eq(settings.text_scale, 1.0, "text scale default")
	h.expect(not settings.reduce_flashing, "reduce flashing default off")

	settings.text_effects_enabled = false
	settings.text_scale = 1.37
	settings.reduce_flashing = true
	h.expect_eq(settings.text_scale, 1.25, "text scale snaps to a supported value")
	h.expect(settings.save_to(path), "Settings writes its ConfigFile")

	var reloaded: Node = SettingsScript.new()
	reloaded.load_from(path)
	h.expect(not reloaded.text_effects_enabled, "text effects setting persists")
	h.expect_eq(reloaded.text_scale, 1.25, "text scale persists")
	h.expect(reloaded.reduce_flashing, "reduce flashing persists")

	var state: Node = GameStateScript.new()
	state.new_game()
	h.expect(not reloaded.text_effects_enabled and reloaded.reduce_flashing,
		"New Game does not reset person-level settings")

	var shader := load("res://shaders/weirdness.gdshader")
	var material := ShaderMaterial.new()
	material.shader = shader
	var weirdness: Node = WeirdnessScript.new()
	weirdness.bind(material)
	reloaded.apply_to_weirdness(weirdness)
	h.expect_eq(material.get_shader_parameter("aberration_px"), 0.3,
		"reduce flashing clamps the shader aberration")
	reloaded.reduce_flashing = false
	reloaded.apply_to_weirdness(weirdness)
	h.expect_eq(material.get_shader_parameter("aberration_px"), 6.0,
		"normal flashing restores the authored aberration")
	settings.free()
	reloaded.free()
	state.free()
	weirdness.free()
	DirAccess.remove_absolute(path)


## Tracker 0.8 / Doc 00 §9.2. Assert every field and the types JSON normally
## loses; merely checking equal values would miss StringName-key regressions.
func _check_save_data(h) -> void:
	h.expect_eq(
		ProjectSettings.get_setting("autoload/GameState"), "*res://autoload/game_state.gd",
		"GameState autoload registration"
	)
	var source := SaveDataResource.new()
	source.chapter = 3
	source.flags = {&"ch01_gnomes_defeated": true, &"npc_wendy_trust": 2}
	source.inventory = {&"journal_3": 1, &"uv_penlight": 1}
	source.journal_entries = [&"entry_gnomes"]
	source.journal_overrides = {
		&"entry_gnomes": {&"weakness_written": "leaf blowers", &"weakness_verified": true}
	}
	source.secrets_found = [&"secret_shack_roof"]
	source.sigils_found = [&"sigil_hand"]
	source.ciphers_solved = [&"ch01_attic_caesar"]
	source.checkpoint = {
		&"id": &"cp_ch01_porch", &"zone_id": &"z_shack_ext",
		&"spawn_marker": &"sp_ch01_porch", &"wake_line_id": &"line_wake",
		&"position": Vector2(112.5, -48.25), &"encounter": {&"boss_id": &"boss_gnomonster", &"phase": 2},
	}
	source.playtime = 123.5

	var restored := GameStateScript.deserialize(GameStateScript.serialize(source))
	h.expect(restored != null, "serialized SaveData deserializes")
	if restored != null:
		h.expect_eq(restored.chapter, source.chapter, "chapter round-trips")
		h.expect_eq(restored.flags, source.flags, "flags round-trip")
		h.expect_eq(restored.inventory, source.inventory, "inventory round-trips")
		h.expect_eq(restored.journal_entries, source.journal_entries, "journal entries round-trip")
		h.expect_eq(restored.journal_overrides, source.journal_overrides, "journal overrides round-trip")
		h.expect_eq(restored.secrets_found, source.secrets_found, "secrets round-trip")
		h.expect_eq(restored.sigils_found, source.sigils_found, "sigils round-trip")
		h.expect_eq(restored.ciphers_solved, source.ciphers_solved, "ciphers round-trip")
		h.expect_eq(restored.checkpoint, source.checkpoint, "checkpoint round-trips")
		h.expect_eq(restored.playtime, source.playtime, "playtime round-trips")
		h.expect_eq(typeof(restored.flags.keys()[0]), TYPE_STRING_NAME, "flag key restores as StringName")
		h.expect_eq(typeof(restored.journal_overrides.keys()[0]), TYPE_STRING_NAME,
			"journal override key restores as StringName")
		h.expect(restored.checkpoint[&"position"] is Vector2, "checkpoint position restores as Vector2")

	var newer := JSON.stringify({"version": GameStateScript.SAVE_VERSION + 1})
	h.expect(GameStateScript.deserialize(newer) == null, "newer save version is refused")

	var state: Node = GameStateScript.new()
	state.data = source
	state.new_game()
	h.expect(state.data.journal_overrides.is_empty(), "New Game clears journal overrides")

	var slot := "user://test_slot0_0_8.sav"
	DirAccess.remove_absolute(slot)
	DirAccess.remove_absolute(slot + ".tmp")
	h.expect(GameStateScript.write_atomic(slot, source), "initial slot writes atomically")
	var replacement := SaveDataResource.new()
	replacement.chapter = 4
	h.expect(not GameStateScript.write_atomic(slot, replacement, true),
		"interrupted write stops before rename")
	var after_interruption := GameStateScript.load_from_path(slot)
	h.expect(after_interruption != null and after_interruption.chapter == source.chapter,
		"interrupted save leaves the previous slot loadable")
	state.free()
	DirAccess.remove_absolute(slot)
	DirAccess.remove_absolute(slot + ".tmp")


## Tracker 0.9 / Doc 00 §12 check 16 — the input-loss regression test.
##
## Godot flushes input in the IDLE frame, so every E, J and pause press is
## published OUTSIDE the physics pass. A queue cleared on a schedule would wipe
## them; the double buffer means every event published between two resolves is
## seen by exactly one resolve. "Exactly once" is both halves of the check: not
## zero (lost) and not twice (replayed).
func _check_runtime_events(h) -> void:
	h.expect_eq(
		ProjectSettings.get_setting("autoload/RuntimeEvents"),
		"*res://autoload/runtime_events.gd",
		"RuntimeEvents autoload registration"
	)
	var q: Node = RuntimeEventsScript.new()
	# Doc 00 §2.2: this node is driven by RuntimeDirector, never self-ticking.
	h.expect(not q.has_method("_physics_process"), "RuntimeEvents has no _physics_process")
	root.add_child(q)

	# --- check 16 proper: published with no intervening swap, seen exactly once.
	q.enqueue(RuntimeEventRecord.Type.INTERACT_REQUEST, null)
	var seen := 0
	for _resolve in 2:
		q.swap()
		seen += q.take(RuntimeEventRecord.Type.INTERACT_REQUEST).size()
	h.expect_eq(seen, 1, "an event published outside the physics pass is seen exactly once")

	# The stamp survives the swap, so the resolver can tell how stale an event is.
	q.enqueue(RuntimeEventRecord.Type.DAMAGE, null, {&"amount": 2})
	q.swap()
	var dmg: RuntimeEvent = q.first(RuntimeEventRecord.Type.DAMAGE)
	h.expect(dmg != null, "first() finds the enqueued event")
	if dmg != null:
		h.expect_eq(dmg.payload.get(&"amount"), 2, "payload survives the swap")
		h.expect_eq(dmg.source, NodePath(), "a null publisher leaves an empty source path")
	h.expect(q.has(RuntimeEventRecord.Type.DAMAGE), "has() agrees with first()")
	h.expect(
		not q.has(RuntimeEventRecord.Type.ATTACK_REQUEST),
		"has() is false for a type that was never published"
	)
	h.expect_eq(
		q.take(RuntimeEventRecord.Type.ATTACK_REQUEST).size(), 0,
		"take() returns only the requested type"
	)

	# --- publishing during a resolve lands on the NEXT one, and cannot mutate
	#     the array being iterated. This is what makes re-entrancy structurally
	#     impossible rather than merely avoided.
	q.swap()
	q.enqueue(RuntimeEventRecord.Type.CHECKPOINT_REACHED, null)
	q.swap()
	var active: Array[RuntimeEvent] = q.take(RuntimeEventRecord.Type.CHECKPOINT_REACHED)
	var during: int = active.size()
	q.enqueue(RuntimeEventRecord.Type.CHECKPOINT_REACHED, null)  # published mid-resolve
	h.expect_eq(
		q.take(RuntimeEventRecord.Type.CHECKPOINT_REACHED).size(), during,
		"an event published during a resolve does not join the resolve in progress"
	)
	q.swap()
	h.expect_eq(
		q.take(RuntimeEventRecord.Type.CHECKPOINT_REACHED).size(), 1,
		"an event published during a resolve lands on the next one"
	)

	# --- defer() carries a lost tick's event forward (§4.6) and keeps the order
	#     the resolver saw. Doc 00 §2.5's bare push_front() reverses this pair.
	q.swap()
	var a := RuntimeEventRecord.new()
	a.type = RuntimeEventRecord.Type.CHECKPOINT_REACHED
	a.payload = {&"id": &"first"}
	var b := RuntimeEventRecord.new()
	b.type = RuntimeEventRecord.Type.CHECKPOINT_REACHED
	b.payload = {&"id": &"second"}
	q.defer(a)
	q.defer(b)
	q.swap()
	var carried: Array[RuntimeEvent] = q.take(RuntimeEventRecord.Type.CHECKPOINT_REACHED)
	h.expect_eq(carried.size(), 2, "both deferred events survive into the next resolve")
	if carried.size() == 2:
		h.expect_eq(carried[0].payload.get(&"id"), &"first", "defer preserves relative order")
		h.expect_eq(carried[1].payload.get(&"id"), &"second", "defer preserves relative order")
	q.swap()
	h.expect_eq(
		q.take(RuntimeEventRecord.Type.CHECKPOINT_REACHED).size(), 0,
		"a deferred event is not carried a second time"
	)

	# --- order is monotonic within a tick and resets on swap.
	q.enqueue(RuntimeEventRecord.Type.DODGE_REQUEST, null)
	q.enqueue(RuntimeEventRecord.Type.DODGE_REQUEST, null)
	q.swap()
	var dodges: Array[RuntimeEvent] = q.take(RuntimeEventRecord.Type.DODGE_REQUEST)
	h.expect_eq(dodges.size(), 2, "both same-type events survive one swap")
	if dodges.size() == 2:
		h.expect(dodges[0].order < dodges[1].order, "order is monotonic within a tick")
		h.expect_eq(dodges[0].order, 0, "order resets on swap")

	q.free()


## Tracker 0.10 / Doc 00 §12 checks 15, 4, 17 and 20 — the resolver itself.
##
## Every check below drives the LIVE `RuntimeDirector` autoload through the
## §12 harness. The point of §12's design is that `_resolve()` is a pure
## function of (queue, state): no frame is awaited, no physics server runs, and
## no tween, fade or `TransitionDirector` exists anywhere in the process. If a
## gameplay state change ever came to depend on an animation completing, these
## checks would hang or fail rather than quietly pass in the editor and break
## on a slow machine.
func _check_runtime_director(h) -> void:
	h.expect_eq(
		ProjectSettings.get_setting("autoload/RuntimeDirector"),
		"*res://autoload/runtime_director.gd",
		"RuntimeDirector autoload registration"
	)
	# Reached by node path, not preload: runtime_director.gd names the
	# `RuntimeEvents` and `GameState` globals, which do not exist at the moment
	# this file compiles, so a preload const here would fail the whole suite.
	var d: Node = root.get_node_or_null(^"RuntimeDirector")
	if not h.expect(d != null, "RuntimeDirector autoload is in the tree"):
		return

	# --- check 15: the resolver runs LAST among gameplay scripts -------------
	# Godot adds autoloads as root's first children, so the default priority of 0
	# would resolve this BEFORE every body has moved and every trigger has
	# published — the exact opposite of §4.1's frame contract, and a bug that
	# shows up as one-frame-stale reads rather than as a crash. Read off the live
	# node, so the assertion covers the value that actually ships rather than the
	# constant's source text.
	h.expect_eq(d.process_physics_priority, 100, "RuntimeDirector physics priority")
	h.expect(
		d.process_physics_priority > 0,
		"resolver runs after every gameplay node (Doc 00 §2.2, default 0)"
	)
	h.expect(
		d.process_physics_priority > 50,
		"resolver runs after CombatDirector (Doc 00 §2.2, 50)"
	)
	h.expect(
		d.process_physics_priority < 110,
		"resolver runs before ZoneManager (Doc 00 §2.2, 110) — residency streams after the commit"
	)

	# --- check 4: damage and E in the same tick ------------------------------
	# §4.4's first row. The bug this catches is an interaction that commits
	# alongside the hit that was supposed to cancel it: the player takes damage
	# AND opens the chest, which reads as an input that "went through anyway".
	h.reset(d)
	h.enqueue(RuntimeEventRecord.Type.INTERACT_REQUEST, {&"target": h.stub_interactable})
	h.enqueue(RuntimeEventRecord.Type.DAMAGE, {&"amount": 1})
	h.step()
	h.expect_eq(h.health.current, h.health.max_pips - 1, "same-tick damage applies exactly once")
	h.expect_eq(h.stub_interactable.interact_calls, 0, "same-tick damage cancels the interaction")
	# Two independent mechanisms enforce that cancellation today — `_try_interact`
	# refuses on `_damage_committed`, and the hit has already moved the player out
	# of `FREE`. Both are asserted, because rows 1.5 and 4.1 bring i-frames and
	# HURT recovery that could remove either one without touching the other.
	h.expect_eq(h.player.state, PlayerController.State.HURT, "the hit leaves the player in HURT")

	# --- check 17: a seam is not a transition, and not a shield --------------
	# The single most load-bearing distinction in §4.5. If a seamless crossing
	# ever took a lock, every open-world zone edge would flicker control away for
	# 0.7 s; if it ever ended the tick, walking across a seam would grant
	# invulnerability to anything on the far side.
	h.reset(d)
	h.enqueue(RuntimeEventRecord.Type.ZONE_ACTIVATION_REQUEST, {&"to": &"z_woods"})
	h.step()
	h.expect_eq(h.zone.current_zone, &"z_woods", "a seamless activation commits the zone")
	h.expect_eq(h.zone.activate_calls, 1, "a seamless activation calls activate_zone exactly once")
	h.expect_eq(d._lock_ticks, 0, "a seamless activation takes no transition lock")
	h.expect_eq(h.player.state, PlayerController.State.FREE, "a seamless activation leaves the player FREE")

	h.reset(d)
	h.enqueue(RuntimeEventRecord.Type.ZONE_ACTIVATION_REQUEST, {&"to": &"z_woods"})
	h.enqueue(RuntimeEventRecord.Type.DAMAGE, {&"amount": 1})
	h.step()
	h.expect_eq(h.zone.current_zone, &"z_woods", "a same-tick hit does not cancel the crossing")
	h.expect_eq(h.health.current, h.health.max_pips - 1, "a seam is not a shield — the same-tick hit lands")

	# The gated half: takes the lock, owns the player, and ends the tick, so the
	# `E` published alongside it never reaches priority 13.
	h.reset(d)
	h.enqueue(RuntimeEventRecord.Type.GATED_ZONE_REQUEST,
		{&"to": &"z_int_shack", &"spawn_marker": &"sp_door"})
	h.enqueue(RuntimeEventRecord.Type.INTERACT_REQUEST, {&"target": h.stub_interactable})
	h.step()
	h.expect(d._lock_ticks > 0, "a gated request takes the transition lock")
	h.expect_eq(h.player.state, PlayerController.State.ZONE_TRANSITION,
		"a gated request puts the player in ZONE_TRANSITION")
	h.expect_eq(h.stub_interactable.interact_calls, 0, "a gated commit ends the tick")
	h.expect_eq(h.zone.activate_calls, 0,
		"a gated activation waits behind the opaque overlay (§7.4 step 5b)")

	# --- check 20: control returns on the countdown, never on an animation ---
	# Four entry points — gated travel, an interior door wipe, §3.2's boot lock
	# and a respawn — share one release path, so boot is not a special case with
	# its own rule. With no `TransitionDirector` in existence, a resolver that
	# waited on a fade would never release at all; one that released on its own
	# frame counter would release at the wrong tick. Both are caught by asserting
	# the tick BEFORE the countdown ends as well as the tick it ends on.
	#
	# The counts come from the director's own constants. Typing 42 here would be
	# a second hand-maintained number that drifts the first time §7.4's 0.35 s
	# moves — exactly what §2.4 forbids.
	var k: Dictionary = d.get_script().get_script_constant_map()
	var fade: int = k["FADE_TICKS"]
	var door: int = k["DOOR_WIPE_TICKS"]

	h.reset(d)
	d.begin_gated_transition(&"z_int_shack", &"sp_door")
	_expect_lock_releases(h, d, fade * 2, "a gated transition")
	h.expect_eq(h.zone.current_zone, &"z_int_shack", "the gated transition arrives on release")

	h.reset(d)
	d.begin_door_transition(&"z_int_lab", &"sp_stairs")
	_expect_lock_releases(h, d, door * 2, "an interior door wipe")

	h.reset(d)
	d.take_lock(fade)   # §3.2 step 5's boot lock
	_expect_lock_releases(h, d, fade, "the boot lock")

	# A respawn commits at priority 1 and takes the lock during that same tick,
	# so its countdown starts one step in. §11.2's checkpoint is the default
	# empty one, which is the same-zone path.
	h.reset(d)
	h.enqueue(RuntimeEventRecord.Type.RESPAWN_REQUEST)
	h.health.current = 1
	h.step()
	h.expect_eq(h.player.state, PlayerController.State.ZONE_TRANSITION,
		"a respawn takes the lock on the tick it commits")
	h.expect_eq(h.health.current, h.health.max_pips, "a respawn restores full health")
	_expect_lock_releases(h, d, fade, "a respawn")

	h.release()


## Tracker 0.11 / Doc 00 §2.3 and §11.3 — `CombatDirector`, the first of the
## row's three autoloads. Its Verify column is two claims, and both are proved
## below: `threat_active` lingers after the aggro set empties, and `boss_phase`
## is the sole boss-music gate.
##
## Every check drives the LIVE autoload, because that is the node Doc 4's HUD and
## Doc 5's music will read — a fresh instance of the script would be one nothing
## else in the process can see. It is therefore shared state, and this function
## leaves it reset.
func _check_combat_director(h) -> void:
	h.expect_eq(
		ProjectSettings.get_setting("autoload/CombatDirector"),
		"*res://autoload/combat_director.gd",
		"CombatDirector autoload registration"
	)
	# By node path, never the global identifier. This file compiles before a
	# --script SceneTree instantiates any autoload (harness.gd's header), so
	# naming `CombatDirector` here would fail the whole suite at parse time — a
	# mistake this project has already made once.
	var c: Node = root.get_node_or_null(^"CombatDirector")
	if not h.expect(c != null, "CombatDirector autoload is in the tree"):
		return
	var d: Node = root.get_node_or_null(^"RuntimeDirector")
	if not h.expect(d != null, "RuntimeDirector autoload is in the tree"):
		return

	# --- §2.2's ordering, off both live nodes --------------------------------
	# Read from the nodes rather than from either constant's source text: the
	# table orders what actually ships. 50 is below the resolver's 100 so this
	# tick's threat flag is settled before the resolver reads it, and above every
	# gameplay node's default 0 so the enemies that set it have already run.
	h.expect_eq(c.process_physics_priority, 50, "CombatDirector physics priority")
	h.expect(
		c.process_physics_priority > 0,
		"CombatDirector ticks after every gameplay node (Doc 00 §2.2, default 0)"
	)
	h.expect(
		c.process_physics_priority < d.process_physics_priority,
		"CombatDirector settles threat before the resolver reads it (Doc 00 §2.2: 50 < 100)"
	)

	# The linger is stepped by the director's own constant. Typing 240 here would
	# be a second hand-maintained number that drifts the first time Doc 4 §2.7's
	# 4.0 s moves — exactly what §2.4 forbids.
	var k: Dictionary = c.get_script().get_script_constant_map()
	var linger: float = k["THREAT_LINGER"]
	var linger_ticks: int = k["THREAT_LINGER_TICKS"]
	h.expect_eq(linger, 4.0, "THREAT_LINGER is Doc 4 §2.7's IDLE_HIDE_DELAY")
	h.expect(linger_ticks > 0, "the linger derives a positive tick count (§2.4)")

	var threat: Array[bool] = []
	var on_threat := func(active: bool) -> void: threat.append(active)
	c.threat_changed.connect(on_threat)

	# --- Verify, first half: threat_active lingers after aggro empties --------
	# Without the linger the HUD blinks off between waves and Doc 4 §3.2 flips a
	# mid-fight line back to a box — the two readers §2.3 names.
	c.reset()
	threat.clear()
	var enemy := Node.new()
	c.register_aggro(enemy)
	h.expect(c.threat_active, "a registered aggro makes the threat active")
	h.expect(threat.size() == 1 and threat[0], "threat_changed fired with true")
	c.deregister_aggro(enemy)
	h.expect(c.threat_active, "threat_active survives the aggro set emptying")
	for _i in linger_ticks - 1:
		_tick(c)
	h.expect(c.threat_active, "threat_active still true one tick before the linger ends")
	_tick(c)
	h.expect(not c.threat_active, "threat_active drops when the linger runs out")
	h.expect(threat.size() == 2 and not threat[1], "threat_changed fired with false")

	# A wave arriving mid-linger cancels the countdown outright rather than
	# inheriting what is left of it.
	c.reset()
	var first := Node.new()
	var second := Node.new()
	c.register_aggro(first)
	c.deregister_aggro(first)
	for _i in linger_ticks - 1:
		_tick(c)
	c.register_aggro(second)
	_tick(c)
	h.expect(c.threat_active, "a second enemy registering during the linger keeps the threat active")
	c.deregister_aggro(second)
	for _i in linger_ticks - 1:
		_tick(c)
	h.expect(c.threat_active, "the countdown restarted from full rather than resuming")
	_tick(c)
	h.expect(not c.threat_active, "the restarted countdown still ends")

	# An enemy freed without deregistering — a zone teardown, or any death path
	# row 4.3 has not written yet — must not pin the threat true forever, which
	# would leave the HUD faded out for the rest of the session.
	c.reset()
	var ghost := Node.new()
	c.register_aggro(ghost)
	ghost.free()
	h.expect(c.threat_active, "a freed enemy still leaves the threat active for its linger")
	for _i in linger_ticks:
		_tick(c)
	h.expect(not c.threat_active, "an enemy freed without deregistering does not pin threat_active true")
	h.expect(c._aggro.is_empty(), "the prune drops the freed enemy's entry")

	# --- Verify, second half: boss_phase is the sole gate --------------------
	c.reset()
	var phases: Array = []
	var on_phase := func(id: StringName, phase: int) -> void: phases.append([id, phase])
	c.boss_phase_changed.connect(on_phase)

	c.begin_boss(&"boss_gnome", 1)
	h.expect(c.boss_active, "begin_boss arms the encounter")
	h.expect_eq(c.boss_id, &"boss_gnome", "begin_boss records the boss id")
	h.expect_eq(c.boss_phase, 1, "begin_boss sets the phase")
	h.expect_eq(phases.size(), 1, "beginning a boss emits boss_phase_changed once")
	if phases.size() == 1:
		h.expect_eq(phases[0][0], &"boss_gnome", "boss_phase_changed carries the boss id")
		h.expect_eq(phases[0][1], 1, "boss_phase_changed carries the new phase")
	c.advance_boss_phase()
	h.expect_eq(c.boss_phase, 2, "advance_boss_phase moves one phase")
	h.expect(
		phases.size() == 2 and phases[1][1] == 2 and phases[1][0] == &"boss_gnome",
		"advancing emits the new phase with the boss id"
	)
	c.set_boss_phase(2)
	h.expect_eq(phases.size(), 2, "re-setting the same phase emits nothing")
	c.clear_boss()
	h.expect(
		not c.boss_active and c.boss_id == &"" and c.boss_phase == 0,
		"clear_boss clears every boss field"
	)
	h.expect(
		phases.size() == 3 and phases[2][0] == &"boss_gnome" and phases[2][1] == 0,
		"the clearing emission still names the boss that ended"
	)

	# The static half. Doc 5 §4.2's gating READS `boss_phase`; the traffic is
	# one-way, and nothing in this file may reach the other way. `boss_phase` also
	# has exactly one writer, so a phase can never move without the signal.
	#
	# The LIVE half of this claim — that no other system gates its music on
	# anything except this field — arrives with row 3.2, which is the row that
	# authors the first gate there is to check.
	var src := FileAccess.get_file_as_string("res://autoload/combat_director.gd")
	h.expect(not src.is_empty(), "combat_director.gd is readable")
	h.expect(
		not src.contains("AudioDirector"),
		"CombatDirector names no audio autoload (Doc 00 §2.3 — chapters advance boss_phase instead)"
	)
	# `\b` rather than `contains()`: "system" carries "stem" as a substring, and a
	# check that fired on the word "systems" would be deleted within a week.
	var mixer := RegEx.create_from_string("(?i)\\b(stems?|bus|buses|volume_db)\\b")
	h.expect(
		mixer.search(src) == null,
		"CombatDirector references no stem and no bus — boss_phase is the whole interface"
	)
	var writes := RegEx.create_from_string("boss_phase\\s*=[^=]")
	h.expect_eq(
		writes.search_all(src).size(), 1,
		"boss_phase has exactly one writer, set_boss_phase()"
	)

	# --- reset() — §3.2 step 3, §3.3, and §11.2 step 5's ordinary respawn -----
	c.register_aggro(first)
	c.begin_boss(&"boss_gnome", 2)
	c.reset()
	h.expect(
		not c.threat_active and c._aggro.is_empty() and c._linger_ticks == 0,
		"reset() clears the aggro set and the linger"
	)
	h.expect(
		not c.boss_active and c.boss_id == &"" and c.boss_phase == 0,
		"reset() clears every boss field"
	)

	# --- §11.3's encounter restore -------------------------------------------
	c.register_aggro(first)
	c.restore_encounter({
		&"boss_id": &"boss_gnome",
		&"phase": 2,
		&"setup": &"ch01_gnomonster_ph2",
	})
	h.expect(c.boss_active, "the encounter block restores boss_active")
	h.expect_eq(c.boss_id, &"boss_gnome", "the encounter block restores boss_id")
	h.expect_eq(c.boss_phase, 2, "the block's phase is resumed at, not restarted from")
	h.expect(c._aggro.is_empty(), "§11.3 step c — aggro is cleared; the boss is state, not aggro")
	h.expect(not c.threat_active, "a restored encounter does not wake the player into a threat")

	# --- §11.3's named phase-setup registry ----------------------------------
	# `has_phase_setup()` is the half the resolver needs: an
	# ENCOUNTER_STATE_REQUEST whose `setup` was never registered is rejected
	# rather than written, because a typo there produces a checkpoint that
	# respawns into an empty boss arena.
	h.expect(not c.has_phase_setup(&"ch01_gnomonster_ph2"), "an unregistered setup is unknown")
	c.register_phase_setup(&"ch01_gnomonster_ph2", &"ch01_gnomonster_ph2")
	h.expect(c.has_phase_setup(&"ch01_gnomonster_ph2"), "a registered setup is known")

	# --- the D9 drift guard --------------------------------------------------
	# `HudVisibility` does not exist today: its contextual fade is tracker
	# Deferred D9 and it arrives with the HUD at row 3.5, which is why
	# THREAT_LINGER inlines Doc 4 §2.7's 4.0 rather than referencing it. These
	# four lines assert nothing yet and fire automatically the day that file is
	# authored with a different number — the drift §0.1 forbids, caught by the
	# suite instead of by a HUD that hides mid-fight.
	var hud_path := "res://ui/hud/hud_visibility.gd"
	if FileAccess.file_exists(hud_path):
		var hud: Dictionary = load(hud_path).get_script_constant_map()
		h.expect_eq(
			hud.get("IDLE_HIDE_DELAY"), linger,
			"HudVisibility.IDLE_HIDE_DELAY is CombatDirector.THREAT_LINGER (Doc 00 §0.1)"
		)

	c.threat_changed.disconnect(on_threat)
	c.boss_phase_changed.disconnect(on_phase)
	# Shared state for every later check, and for any real physics frame after
	# the suite finishes.
	c._phase_setups.clear()
	c.reset()
	enemy.free()
	first.free()
	second.free()


## Tracker 0.11 / Doc 00 §8 and §12 check 23 — `CutsceneDirector`.
##
## The LIVE autoload again, because that is the node the resolver reaches at
## priority 6 and the node row 3.6's dialogue runner will call `complete()` on. It
## is therefore shared state, and this function leaves it reset.
##
## Check 23 has two halves. Its request-time half — "only the three permitted
## intent types are accepted; any other is rejected at request time" — is what
## this row can prove; the other half, that the intent resolves through its normal
## priority row on the following tick and loses to same-tick damage, needs the
## resolver wiring that the next task in this row adds.
func _check_cutscene_director(h) -> void:
	h.expect_eq(
		ProjectSettings.get_setting("autoload/CutsceneDirector"),
		"*res://autoload/cutscene_director.gd",
		"CutsceneDirector autoload registration"
	)
	# By node path, never the global identifier — harness.gd's header, and the
	# mistake this project has already made once.
	var c: Node = root.get_node_or_null(^"CutsceneDirector")
	if not h.expect(c != null, "CutsceneDirector autoload is in the tree"):
		return
	var q: Node = root.get_node_or_null(^"RuntimeEvents")
	if not h.expect(q != null, "RuntimeEvents autoload is in the tree"):
		return

	# Two swaps drain both buffers: the first discards whatever an earlier check
	# left resolvable, the second discards what that swap made active. One swap
	# would leave this check's enqueues mixed with someone else's.
	q.swap()
	q.swap()
	c.reset()

	# --- §12 check 23, request-time half: the permitted three -----------------
	# Driven off the director's own constant rather than a list retyped here, so
	# the check cannot silently disagree with the boundary it is guarding.
	var permitted: Array = c.get_script().get_script_constant_map()["PERMITTED_COMPLETE_INTENTS"]
	h.expect_eq(permitted.size(), 3, "§8.2.1 permits exactly three follow-up intents")
	for intent: int in permitted:
		var id := StringName("t_permitted_%d" % intent)
		h.expect(
			c.request(id, {&"on_complete_flag": &"sys_t", &"on_complete_intent": intent}),
			"a permitted on_complete_intent (%d) is accepted" % intent
		)
		h.expect(c._pending.has(id), "the accepted request is stored against its id")
	q.swap()
	h.expect_eq(
		q.take(RuntimeEventRecord.Type.CUTSCENE_REQUEST).size(), permitted.size(),
		"each accepted request published one CUTSCENE_REQUEST"
	)
	c.reset()
	q.swap()

	# --- and the rejected rest ------------------------------------------------
	# §8.2.1 names these three explicitly: never a zone request, never a damage
	# event, never a cutscene. A chapter's typo here would otherwise hand the
	# resolver an unaudited intent to enqueue on completion.
	for forbidden: int in [
		RuntimeEventRecord.Type.GATED_ZONE_REQUEST,
		RuntimeEventRecord.Type.DAMAGE,
		RuntimeEventRecord.Type.CUTSCENE_REQUEST,
	]:
		h.expect(
			not c.request(&"t_forbidden", {&"on_complete_intent": forbidden}),
			"a forbidden on_complete_intent (%d) is rejected at request time" % forbidden
		)
		h.expect(c._pending.is_empty(), "a rejected request stores nothing")
	# The difference between a validated boundary and a return value nobody
	# enforces: the queue must be untouched, not merely the answer false.
	q.swap()
	h.expect_eq(
		q.take(RuntimeEventRecord.Type.CUTSCENE_REQUEST).size(), 0,
		"a rejected request reaches the queue not at all"
	)
	q.swap()

	# --- §8.2's optional field ------------------------------------------------
	# Most cutscenes declare no follow-up intent, so an absent one is not a
	# rejection.
	h.expect(
		c.request(&"t_plain", {
			&"skippable": true,
			&"lines": [],
			&"camera": &"path/to/CameraRig",
			&"on_complete_flag": &"ch03_met_gideon",
		}),
		"a request with no on_complete_intent at all is accepted (§8.2 marks it optional)"
	)
	q.swap()
	var published: Array[RuntimeEvent] = q.take(RuntimeEventRecord.Type.CUTSCENE_REQUEST)
	h.expect_eq(published.size(), 1, "one accepted request enqueues exactly one CUTSCENE_REQUEST")
	if published.size() == 1:
		h.expect_eq(
			published[0].payload.get(&"id"), &"t_plain",
			"the payload names the cutscene, so the resolver can say what it commits"
		)
	q.swap()

	# --- §8.1 step 5: taking one active --------------------------------------
	h.expect(not c.is_active(), "nothing is active until the resolver commits a request")
	h.expect(c.begin(&"t_plain"), "taking a pending id active succeeds")
	h.expect(c.is_active(), "the taken cutscene is active")
	h.expect_eq(c.active_id, &"t_plain", "the active id is the one the resolver named")

	# An id that was never requested — a CUTSCENE_REQUEST published by something
	# other than request() — is refused rather than activated as an empty config,
	# which would be an invisible cutscene with no authored line to end it.
	c.reset()
	h.expect(not c.begin(&"t_never_requested"), "an id that was never requested is refused")
	h.expect(not c.is_active(), "the refused take leaves nothing active")

	# --- §8.1 step 6 and the consume-once handoff -----------------------------
	var config := {
		&"skippable": true,
		&"on_complete_flag": &"ch03_met_gideon",
		&"on_complete_intent": RuntimeEventRecord.Type.JOURNAL_TOGGLE_REQUEST,
	}
	c.request(&"t_handoff", config)
	c.begin(&"t_handoff")
	c.complete()
	h.expect(not c.is_active(), "complete() clears the active cutscene")
	var handed: Dictionary = c.take_completed()
	h.expect_eq(
		handed.get(&"on_complete_flag"), &"ch03_met_gideon",
		"the handoff returns the finished cutscene's config"
	)
	h.expect_eq(
		handed.get(&"on_complete_intent"), RuntimeEventRecord.Type.JOURNAL_TOGGLE_REQUEST,
		"the handoff carries the intent the resolver enqueues"
	)
	# The check that stops a doubled flag write and a doubled enqueue.
	h.expect(
		c.take_completed().is_empty(),
		"the handoff is consume-once — a second read is empty"
	)

	# And it is a copy, so the resolver cannot mutate the director's state through
	# the value it was handed. Mutate what came back, then re-request the same id
	# and read what the director stored.
	handed[&"on_complete_flag"] = &"mutated"
	c.request(&"t_handoff", config)
	h.expect_eq(
		(c._pending[&"t_handoff"] as Dictionary).get(&"on_complete_flag"), &"ch03_met_gideon",
		"the handoff returned a copy — mutating it does not reach the stored config"
	)

	# --- reset() — §3.3's end_session(), §12 check 12 -------------------------
	# `camera` is a node path or a node reference authored by a chapter, which is
	# the freed-node reference check 12 hunts for, so all three stores clear.
	c.request(&"t_queued", {})
	c.begin(&"t_handoff")
	c.complete()
	c.request(&"t_active", {})
	c.begin(&"t_active")
	h.expect(
		not c._pending.is_empty() and c.is_active() and not c._completed.is_empty(),
		"all three stores are occupied before the reset"
	)
	c.reset()
	h.expect(c._pending.is_empty(), "reset() leaves nothing pending")
	h.expect(not c.is_active(), "reset() leaves nothing active")
	h.expect(c._completed.is_empty(), "reset() leaves nothing finished")

	# --- the static half: §14.1's boundary, asserted rather than intended -----
	# Only RuntimeDirector mutates gameplay state. This director owns the queue
	# and the active config; the player's state, `on_complete_flag` and the
	# follow-up intent are all committed at priority 6 and on completion by the
	# resolver, so none of those systems may be named here at all.
	var src := FileAccess.get_file_as_string("res://autoload/cutscene_director.gd")
	h.expect(not src.is_empty(), "cutscene_director.gd is readable")
	h.expect(
		not src.contains("PlayerController"),
		"CutsceneDirector names no PlayerController (§8.1 step 5 — the resolver sets CUTSCENE)"
	)
	var state_write := RegEx.create_from_string("(?m)^[^#]*\\bstate\\s*=[^=]")
	h.expect(
		state_write.search(src) == null,
		"CutsceneDirector assigns no state (§14.1 — one committer of gameplay state)"
	)
	h.expect(
		not src.contains("GameState"),
		"CutsceneDirector names no GameState (§8.2 — the resolver writes on_complete_flag)"
	)
	h.expect(
		not src.contains("CombatDirector"),
		"CutsceneDirector reaches no other row-0.11 director"
	)
	h.expect(
		not src.contains("Weirdness"),
		"CutsceneDirector touches no Weirdness"
	)

	# Shared state for every later check, and for any real physics frame after
	# the suite finishes.
	c.reset()
	q.swap()
	q.swap()


## Tracker 0.11 / Doc 00 §7.4 and §12 check 20 — `TransitionDirector`, the last of
## the row's three autoloads.
##
## The LIVE autoload again, because that is the node §3.2 step 4 and §4.5's snippet
## both call. It is therefore shared state, and this function leaves the overlay
## transparent with no tween running.
##
## Every fade below is advanced with `custom_step()` rather than by awaiting real
## frames — row 0.6's weirdness check does the same — so these checks are a pure
## function of the calls made and cannot flake on timing.
##
## The half of check 20 this row cannot prove is the live one: that a gated
## transition, a door wipe, boot and a respawn all release control on
## `_lock_ticks == 0` *with the fade stubbed out entirely*. Row 0.10 already proves
## it (`_expect_lock_releases`) precisely because no overlay existed to stub. What
## is proved here is the other direction — that this file cannot reach gameplay
## even if it wanted to.
func _check_transition_director(h) -> void:
	h.expect_eq(
		ProjectSettings.get_setting("autoload/TransitionDirector"),
		"*res://autoload/transition_director.gd",
		"TransitionDirector autoload registration"
	)
	# By node path, never the global identifier — harness.gd's header, and the
	# mistake this project has already made once.
	var t: Node = root.get_node_or_null(^"TransitionDirector")
	if not h.expect(t != null, "TransitionDirector autoload is in the tree"):
		return

	# --- the overlay itself ---------------------------------------------------
	var o: ColorRect = t._overlay
	if not h.expect(o != null, "the overlay ColorRect exists"):
		return
	h.expect_eq(t.layer, 30, "the overlay is on Doc 04 §0's transitions CanvasLayer 30")
	# A boot that calls nothing must show the game, not a black screen.
	h.expect_eq(t.alpha(), 0.0, "the overlay starts fully transparent")
	h.expect_eq(o.color, Color(0.0, 0.0, 0.0, 0.0), "the overlay is black at zero alpha")
	# The native filter, asserted off the node rather than trusted: a fading
	# overlay that eats clicks is a bug felt as dead UI, and it would be invisible
	# to every other check in this file.
	h.expect_eq(
		o.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"the overlay ignores mouse input at every alpha (Control.mouse_filter, not a guard)"
	)
	# Doc 01 §0's display contract is `canvas_items` + `keep`, so full-rect anchors
	# with zero offsets cover the canvas at every window size and aspect. Asserting
	# the anchors rather than a 1920x1080 size is what makes that true of a resized
	# window too.
	h.expect(
		o.anchor_left == 0.0 and o.anchor_top == 0.0
			and o.anchor_right == 1.0 and o.anchor_bottom == 1.0,
		"the overlay is anchored full-rect, not sized to a hardcoded canvas"
	)
	h.expect(
		o.offset_left == 0.0 and o.offset_top == 0.0
			and o.offset_right == 0.0 and o.offset_bottom == 0.0,
		"the full-rect preset leaves no offsets to inset the overlay"
	)
	h.expect_eq(o.size, root.get_visible_rect().size, "the overlay covers the whole viewport")

	# The tick counts come from the resolver, which owns every duration in §7.4.
	# Retyping 21 here would be the second hand-maintained number §2.4 forbids.
	var d: Node = root.get_node_or_null(^"RuntimeDirector")
	if not h.expect(d != null, "RuntimeDirector autoload is in the tree"):
		return
	var rk: Dictionary = d.get_script().get_script_constant_map()
	var fade_ticks: int = rk["FADE_TICKS"]
	var secs: float = fade_ticks * (t.get_script().get_script_constant_map()["TICK"] as float)
	h.expect(secs > 0.0, "the fade converts to a positive number of seconds")

	# --- set_opaque(): §3.2 step 4, and immediate ------------------------------
	# Asserted in the same call with no frame in between, because "mount behind an
	# already-opaque overlay" is false the moment it takes a frame to go black.
	t.set_opaque(true)
	h.expect_eq(t.alpha(), 1.0, "set_opaque(true) is immediate — opaque with no frame in between")
	t.set_opaque(false)
	h.expect_eq(t.alpha(), 0.0, "set_opaque(false) is immediate too")

	# --- play_fade_in(): §3.2 step 5 and §7.4 step 7 ---------------------------
	t.set_opaque(true)
	t.play_fade_in(fade_ticks)
	h.expect_eq(t.alpha(), 1.0, "play_fade_in does not snap off the black it starts from")
	t._tween.custom_step(secs * 0.5)
	# The intermediate assertion: a fade that jumped straight to its target would
	# pass an end-state check and fail this one.
	h.expect(
		t.alpha() > 0.0 and t.alpha() < 1.0,
		"play_fade_in eases rather than snapping, got %f" % t.alpha()
	)
	t._tween.custom_step(secs)
	h.expect_eq(t.alpha(), 0.0, "play_fade_in reaches fully transparent")

	# --- play_fade(): the whole §7.4 shape ------------------------------------
	# Out (step 4), hold while the destination mounts (step 5), back in (step 7).
	t.set_opaque(false)
	t.play_fade(fade_ticks)
	t._tween.custom_step(secs * 0.5)
	h.expect(
		t.alpha() > 0.0 and t.alpha() < 1.0,
		"play_fade eases out rather than cutting to black, got %f" % t.alpha()
	)
	# Stepped in small increments so the opaque peak between the two fades is
	# observed rather than skipped over. The hold is zero-length until row 2.3
	# gives the mount a budget, so the peak is one instant wide.
	var peak: float = t.alpha()
	var trough := 1.0
	for _i in 44:
		t._tween.custom_step(secs * 2.0 / 40.0)
		peak = maxf(peak, t.alpha())
		trough = minf(trough, t.alpha())
	h.expect(peak >= 0.999, "play_fade reaches opaque on its way through, peaked at %f" % peak)
	h.expect_eq(t.alpha(), 0.0, "play_fade ends fully transparent (§7.4 step 7)")
	h.expect(
		trough < peak,
		"play_fade came back in rather than holding at its peak"
	)

	# --- one writer of the alpha ---------------------------------------------
	# §12 check 36's phrasing for the intensity float, applied here: a later call
	# supersedes whatever is in flight, and two live tweens fighting over one alpha
	# is the bug this check exists to catch.
	t.set_opaque(true)
	t.play_fade_in(fade_ticks)
	var superseded: Tween = t._tween
	t._tween.custom_step(secs * 0.5)
	t.play_fade(fade_ticks)
	h.expect(not superseded.is_running(), "a second call kills the fade in flight")
	h.expect(t._tween != superseded, "a second call leaves exactly one tween on the alpha")
	# And set_opaque() kills one too, or the fade it interrupts would tween straight
	# back off the black §3.2 step 4 just asked for.
	var killed: Tween = t._tween
	t.set_opaque(true)
	h.expect(not killed.is_running(), "set_opaque kills the tween in flight")
	h.expect_eq(t.alpha(), 1.0, "set_opaque wins against the fade it interrupted")

	# --- the purity check, and the one that matters most ----------------------
	# §4.5: this file mirrors the lock and has no authority over it. "Gameplay never
	# resumes because an animation finished — it resumes because the resolver says
	# so." A single reference to any name below is the beginning of a gameplay state
	# change that waits on an animation, so the boundary is scanned rather than
	# intended — the same static read `_check_combat_director()` makes.
	var src := FileAccess.get_file_as_string("res://autoload/transition_director.gd")
	h.expect(not src.is_empty(), "transition_director.gd is readable")
	for forbidden: String in [
		"RuntimeDirector", "RuntimeEvents", "GameState", "Weirdness",
		"CombatDirector", "CutsceneDirector", "PlayerController", "player",
	]:
		h.expect(
			not src.contains(forbidden),
			"TransitionDirector names no %s — it mirrors the lock and cannot gate it (§4.5)"
				% forbidden
		)

	# And it owns no duration of its own. §7.4's 0.35, §7.6's 0.25 and §7.4.1's 0.12
	# all live on the resolver already; a second copy is what §0.1 and §2.4 forbid,
	# and it drifts silently the first time either moves.
	for literal: String in ["0.35", "0.25", "0.12"]:
		h.expect(
			not src.contains(literal),
			"TransitionDirector restates no duration literal (%s) — callers pass tick counts"
				% literal
		)

	# Shared state for every later check, and for any real frame after the suite
	# finishes: transparent, with nothing running.
	t.set_opaque(false)


## Tracker 0.11, last task — the resolver wired to the row's three directors.
##
## Row 0.10 left six `ponytail:` deferrals in `runtime_director.gd` naming this row;
## these checks are the other half of closing them. Everything below drives the LIVE
## resolver through the §12 harness against the LIVE directors, because that is the
## only combination the shipped game has.
##
## What is proved here that no earlier check could be: §12 check 22's ordering
## (a teardown lands before `activate_zone()` and while no trigger is armed), check
## 23's timing in BOTH directions (the follow-up intent resolves a tick later, and
## loses to damage), check 24's two respawn paths, check 28's rejection, §7.7's
## grace, and — now that a real overlay exists to fail to wait for — check 20 in the
## direction that matters.
func _check_resolver_wiring(h) -> void:
	var d: Node = root.get_node_or_null(^"RuntimeDirector")
	var c: Node = root.get_node_or_null(^"CombatDirector")
	var cs: Node = root.get_node_or_null(^"CutsceneDirector")
	var t: Node = root.get_node_or_null(^"TransitionDirector")
	var gs: Node = root.get_node_or_null(^"GameState")
	if not h.expect(
			d != null and c != null and cs != null and t != null and gs != null,
			"every autoload the resolver wiring needs is in the tree"):
		return

	# Every count comes from the owning script's own constants. Typing 21, 9 or
	# "journal_3" here would be the second hand-maintained number §2.4 forbids.
	var k: Dictionary = d.get_script().get_script_constant_map()
	var fade: int = k["FADE_TICKS"]
	var door: int = k["DOOR_WIPE_TICKS"]
	var grace: int = k["ARRIVAL_GRACE_TICKS"]
	var journal_item: StringName = k["JOURNAL_ITEM"]
	var tick: float = t.get_script().get_script_constant_map()["TICK"]
	h.expect(grace > 1, "§7.7's grace derives more than one tick, so it can be observed running")

	# --- §11.2 step 5: an ordinary respawn resets combat ----------------------
	# Armed first, so the check cannot pass vacuously against a combat director that
	# was already clear.
	h.reset(d)
	gs.data.checkpoint = {&"zone_id": &"", &"spawn_marker": &"", &"encounter": {}}
	var enemy := Node.new()
	c.register_aggro(enemy)
	c.begin_boss(&"boss_gnome", 2)
	h.expect(
		c.boss_active and c.threat_active and not c._aggro.is_empty(),
		"the ordinary-respawn check starts from an armed boss and a live threat"
	)
	h.enqueue(RuntimeEventRecord.Type.RESPAWN_REQUEST)
	h.step()
	h.expect(not c.boss_active, "an ordinary respawn clears boss_active (§11.2 step 5)")
	h.expect_eq(c.boss_id, &"", "an ordinary respawn clears boss_id")
	h.expect_eq(c.boss_phase, 0, "an ordinary respawn clears boss_phase")
	h.expect(c._aggro.is_empty(), "an ordinary respawn clears the aggro set")
	h.expect(not c.threat_active, "the player does not wake into an active threat")

	# --- §11.3 / §12 check 24: a mid-boss respawn RESTORES --------------------
	# Resetting here would drop the player at a checkpoint with the boss gone and
	# the fight unwinnable — the failure §11.3 exists to prevent.
	h.reset(d)
	gs.data.checkpoint = {
		&"zone_id": &"", &"spawn_marker": &"",
		&"encounter": {&"boss_id": &"boss_gnome", &"phase": 2, &"setup": &"cp_wire_setup"},
	}
	c.register_aggro(enemy)
	h.enqueue(RuntimeEventRecord.Type.RESPAWN_REQUEST)
	h.step()
	h.expect(c.boss_active, "a checkpoint carrying an encounter restores boss_active")
	h.expect_eq(c.boss_id, &"boss_gnome", "the block's boss_id is restored")
	h.expect_eq(c.boss_phase, 2, "the block's phase is resumed AT, not restarted from")
	h.expect(c._aggro.is_empty(), "§11.3 step c — aggro is cleared; the boss is state, not aggro")

	# --- §7.4.1's clear_combat, and §12 check 22's ordering -------------------
	# The teardown applies at step 5a: "after the destination mounts and before
	# activate_zone() commits", behind an opaque overlay and with no trigger armed.
	# `boss_phase_changed` fires from inside `CombatDirector.reset()`, so the probe
	# observes the world at the exact instant the teardown's effects become visible —
	# which is the only way to assert an ordering inside one synchronous call.
	h.reset(d)
	gs.data.checkpoint = {&"zone_id": &"", &"spawn_marker": &"", &"encounter": {}}
	c.begin_boss(&"boss_gnome", 1)
	c.register_aggro(enemy)
	var at_teardown: Array = []
	var probe := func(_id: StringName, _phase: int) -> void:
		at_teardown.append([h.zone.activate_calls, d.can_process_world_triggers()])
	c.boss_phase_changed.connect(probe)
	h.enqueue(RuntimeEventRecord.Type.GATED_ZONE_REQUEST, {
		&"to": &"z_int_shack", &"spawn_marker": &"sp_door",
		&"teardown": {&"clear_combat": true},
	})
	h.step()
	h.expect(
		c.boss_active,
		"the teardown waits for step 5a — it does not fire on the tick the request commits"
	)
	for _i in fade * 2:
		h.step()
	c.boss_phase_changed.disconnect(probe)
	h.expect(not c.boss_active, "clear_combat cleared the boss by the time the lock released")
	h.expect(c._aggro.is_empty(), "clear_combat cleared the aggro set too (§7.4.1)")
	h.expect_eq(at_teardown.size(), 1, "the teardown cleared combat exactly once")
	if at_teardown.size() == 1:
		h.expect_eq(
			at_teardown[0][0], 0,
			"§12 check 22 — the teardown applied BEFORE activate_zone() committed (§7.4 step 5a)"
		)
		h.expect(
			not at_teardown[0][1],
			"§12 check 22 — the teardown applied while world triggers were disarmed"
		)
	h.expect_eq(h.zone.activate_calls, 1, "the destination still activated on release")

	# The negative, and it is the half no positive test can see: a teardown that
	# fired unconditionally would pass everything above.
	h.reset(d)
	c.begin_boss(&"boss_gnome", 1)
	h.enqueue(RuntimeEventRecord.Type.GATED_ZONE_REQUEST,
		{&"to": &"z_int_shack", &"spawn_marker": &"sp_door"})
	for _i in fade * 2 + 1:
		h.step()
	h.expect_eq(h.zone.current_zone, &"z_int_shack", "the teardown-free transition still arrived")
	h.expect(c.boss_active, "a transition declaring no teardown leaves combat alone")
	h.expect_eq(c.boss_phase, 1, "and leaves the phase alone")

	# --- §7.4 step 4: the gated fade is played, with the request's own ticks ---
	h.reset(d)
	h.enqueue(RuntimeEventRecord.Type.GATED_ZONE_REQUEST,
		{&"to": &"z_woods", &"spawn_marker": &"sp_seam", &"wipe_ticks": door})
	h.step()
	if h.expect(
			t._tween != null and t._tween.is_running(),
			"a gated commit plays TransitionDirector's fade (§4.5's presentation-only call)"):
		t._tween.custom_step(door * tick * 0.5)
		h.expect(
			t.alpha() > 0.0 and t.alpha() < 1.0,
			"the fade is easing out mid-wipe, got %f" % t.alpha()
		)
		t._tween.custom_step(door * tick * 0.48)
		# The discriminator: had the resolver passed its own FADE_TICKS instead of
		# the request's DOOR_WIPE_TICKS, this much of a longer fade would still be
		# well short of opaque.
		h.expect(
			t.alpha() > 0.99,
			"the fade used the request's own wipe_ticks (%d), got alpha %f" % [door, t.alpha()]
		)

	# --- §12 check 20, in the direction that finally matters ------------------
	# Row 0.10 proved the lock releases on its countdown when no overlay existed at
	# all. A real overlay exists now, so the claim can be tested against one left
	# mid-fade with its tween killed outright: the lock must still release exactly on
	# `_lock_ticks == 0`. "Gameplay never resumes because an animation finished — it
	# resumes because the resolver says so."
	h.reset(d)
	d.begin_gated_transition(&"z_int_lab", &"sp_stairs")
	if t._tween != null:
		t._tween.custom_step(fade * tick * 0.5)
		t._tween.kill()
	h.expect(
		t.alpha() > 0.0 and t.alpha() < 1.0,
		"the overlay is stranded mid-fade, got %f" % t.alpha()
	)
	_expect_lock_releases(h, d, fade * 2, "a gated transition whose fade was killed mid-wipe")
	h.expect_eq(h.zone.current_zone, &"z_int_lab", "and the destination still arrived")

	# --- §8.1 step 5: a cutscene begins THROUGH CutsceneDirector --------------
	h.reset(d)
	h.expect(cs.request(&"cw_begin", {}), "the authored request is accepted")
	h.step()
	h.expect_eq(
		h.player.state, PlayerController.State.CUTSCENE,
		"a committed CUTSCENE_REQUEST puts the player in CUTSCENE (§8.1 step 5)"
	)
	h.expect(cs.is_active(), "and the resolver took that cutscene active")
	h.expect_eq(cs.active_id, &"cw_begin", "naming it by the id the payload carried")

	# The soft-lock guard. An id nothing ever requested has no config, so there is
	# no authored line to end it — a `CUTSCENE` state with nothing to leave it. This
	# drives `CutsceneDirector.begin()`'s push_error on purpose.
	h.reset(d)
	h.enqueue(RuntimeEventRecord.Type.CUTSCENE_REQUEST, {&"id": &"cw_never_requested"})
	h.step()
	h.expect_eq(
		h.player.state, PlayerController.State.FREE,
		"a CUTSCENE_REQUEST for a cutscene nothing requested leaves the player FREE"
	)
	h.expect(not cs.is_active(), "and leaves nothing active")

	# --- §12 check 23, completion half: the flag, FREE, and the intent's TIMING
	h.reset(d)
	gs.data.flags.erase(&"cw_flag")
	gs.data.inventory[journal_item] = 1
	cs.request(&"cw_complete", {
		&"on_complete_flag": &"cw_flag",
		&"on_complete_intent": RuntimeEventRecord.Type.JOURNAL_TOGGLE_REQUEST,
	})
	h.step()
	h.expect(cs.is_active(), "the cutscene under test is running")
	h.expect(
		not gs.data.flags.has(&"cw_flag"),
		"on_complete_flag is not written while the cutscene is still running"
	)
	# Row 3.6's dialogue runner makes this call when the last authored line ends.
	cs.complete()
	h.step()
	h.expect(
		bool(gs.data.flags.get(&"cw_flag", false)),
		"§8.2 — the resolver writes on_complete_flag into GameState on completion"
	)
	h.expect(gs._dirty, "and marks the save dirty, like every other committing rung")
	h.expect_eq(
		h.player.state, PlayerController.State.FREE,
		"§8.1 step 6 — completion returns the player to FREE"
	)
	# The half a resolver that applied the intent inline would fail. §8.2.1's
	# mechanism is an enqueue, and `RuntimeEvents.enqueue()` always writes
	# `_incoming`, so the intent cannot resolve on the tick it was created.
	h.expect(
		h.player.state != PlayerController.State.JOURNAL,
		"the follow-up intent did NOT resolve on the completion tick"
	)
	h.step()
	h.expect_eq(
		h.player.state, PlayerController.State.JOURNAL,
		"§8.2.1 — the intent resolves through its own priority row on the FOLLOWING tick"
	)

	# --- §12 check 23, cancellation half — the point of the whole indirection --
	# "If the player takes a hit on the tick after the cutscene ends, damage at
	# priority 4 cancels it and the Journal stays closed — which is correct, and
	# which a direct `state = OPEN` would have gotten wrong."
	h.reset(d)
	gs.data.inventory[journal_item] = 1
	cs.request(&"cw_cancel", {
		&"on_complete_intent": RuntimeEventRecord.Type.JOURNAL_TOGGLE_REQUEST,
	})
	h.step()
	cs.complete()
	h.step()
	h.expect_eq(h.player.state, PlayerController.State.FREE, "the cutscene ended with control returned")
	h.enqueue(RuntimeEventRecord.Type.DAMAGE, {&"amount": 1})
	h.step()
	h.expect_eq(
		h.player.state, PlayerController.State.HURT,
		"the hit committed at priority 4 on the intent's own tick"
	)
	h.expect(
		h.player.state != PlayerController.State.JOURNAL,
		"§12 check 23 — damage cancels the follow-up intent and the Journal stays closed"
	)

	# The item gate, asserted separately so the cancellation above cannot have gone
	# green for the wrong cause: without Journal 3 the intent is refused by contract
	# 34 rather than by any damage.
	h.reset(d)
	gs.data.inventory.erase(journal_item)
	cs.request(&"cw_ungated", {
		&"on_complete_intent": RuntimeEventRecord.Type.JOURNAL_TOGGLE_REQUEST,
	})
	h.step()
	cs.complete()
	h.step()
	h.step()
	h.expect_eq(
		h.player.state, PlayerController.State.FREE,
		"a follow-up JOURNAL_TOGGLE_REQUEST is refused outright without Journal 3 (contract 34)"
	)

	# --- §7.7's arrival grace: refused, never dropped -------------------------
	# The grace is armed the way arrival actually arms it — by releasing a real lock
	# — rather than by writing the counter. The request is authored AFTER the release
	# because §6.3 and §11.1 discard whatever is published behind an opaque overlay,
	# which is §7.4 step 9's ordering too.
	h.reset(d)
	gs.data.inventory[journal_item] = 1
	d.begin_gated_transition(&"z_woods", &"sp_arrive")
	for _i in fade * 2:
		h.step()
	h.expect_eq(d._arrival_grace_ticks, grace, "releasing the lock arms §7.7's grace")
	h.expect_eq(
		h.player.state, PlayerController.State.FREE,
		"§7.7 — control returns BEFORE an automatic arrival story may take it"
	)
	h.expect(cs.request(&"cw_arrival", {&"arrival_story": true}), "the arrival story is authored")
	for _i in grace - 1:
		h.step()
	h.expect(d._arrival_grace_ticks > 0, "the grace is still running")
	h.expect(not cs.is_active(), "the arrival story is refused while the grace runs")
	h.expect_eq(h.player.state, PlayerController.State.FREE, "and the player keeps control")
	h.step()
	h.expect_eq(d._arrival_grace_ticks, 0, "the grace has run out")
	h.expect(
		cs.is_active(),
		"the arrival story commits once the grace reaches zero — refused, never dropped (§4.6)"
	)
	h.expect_eq(h.player.state, PlayerController.State.CUTSCENE, "and the resolver takes control for it")

	# --- §12 check 28: an unregistered `setup` is rejected, not written -------
	# "A typo there would otherwise produce a checkpoint that respawns into an empty
	# boss arena, which is the worst failure this whole mechanism exists to prevent."
	# This drives the resolver's push_error on purpose.
	h.reset(d)
	gs.data.checkpoint = {&"zone_id": &"", &"spawn_marker": &"", &"encounter": {}}
	var arm := {&"boss_id": &"boss_gnome", &"phase": 2, &"setup": &"cw_setup"}
	h.enqueue(RuntimeEventRecord.Type.ENCOUNTER_STATE_REQUEST, arm)
	h.step()
	h.expect(
		(gs.data.checkpoint[&"encounter"] as Dictionary).is_empty(),
		"an arm naming an unregistered setup is refused, and did not PARTIALLY write the block"
	)
	# The same request, once the chapter has registered the name.
	c.register_phase_setup(&"cw_setup", &"cw_setup")
	h.enqueue(RuntimeEventRecord.Type.ENCOUNTER_STATE_REQUEST, arm)
	h.step()
	var armed: Dictionary = gs.data.checkpoint[&"encounter"]
	h.expect_eq(armed.get(&"boss_id"), &"boss_gnome", "the same arm commits once the setup is registered")
	h.expect_eq(armed.get(&"phase"), 2, "and carries the phase to resume at")
	h.expect_eq(armed.get(&"setup"), &"cw_setup", "and the setup name the chapter registered")
	# An empty payload clears, and is always legal — a chapter clears the block on
	# the boss's defeat (§11.3, §12 check 25).
	h.enqueue(RuntimeEventRecord.Type.ENCOUNTER_STATE_REQUEST, {})
	h.step()
	h.expect(
		(gs.data.checkpoint[&"encounter"] as Dictionary).is_empty(),
		"an empty ENCOUNTER_STATE_REQUEST always clears the block"
	)

	# --- the purity guard -----------------------------------------------------
	# This file's own header, and §4.5: the resolver is a pure function of
	# (queue, state) — no `await`, no `create_tween()`, no `get_tree().create_timer()`
	# and no `Input.*`. It now calls into a director that owns a tween, so the
	# boundary is scanned rather than intended, the same static read the three
	# director checks make. `^[^#]*` rather than `contains()`: the header explains
	# the ban in prose, and a check that fired on its own documentation would be
	# deleted within a week.
	var src := FileAccess.get_file_as_string("res://autoload/runtime_director.gd")
	h.expect(not src.is_empty(), "runtime_director.gd is readable")
	for forbidden: String in [
		"\\bawait\\b", "create_tween\\(", "create_timer\\(", "\\bInput\\.",
	]:
		h.expect(
			RegEx.create_from_string("(?m)^[^#]*" + forbidden).search(src) == null,
			"RuntimeDirector's code contains no %s — every duration is a tick countdown (§2.4, §4.5)"
				% forbidden
		)
	# And it reaches the three directors as globals, never through a nullable handle:
	# they are registered above it, so there is nothing to duck-type.
	for named: String in ["CombatDirector", "CutsceneDirector", "TransitionDirector"]:
		h.expect(src.contains(named + "."), "RuntimeDirector calls %s directly" % named)

	# Shared state, for every later check and for any real physics frame after the
	# suite finishes. `new_game()` is what undoes the checkpoint, flag and inventory
	# writes above — they are `GameState`, which the harness does not own.
	h.release()
	gs.new_game()
	enemy.free()


## Doc 3 §3.2's two entry points that Doc 00 §3.2 actually calls, and nothing
## else. `ZoneManager` does not exist until tracker row 2.3, so the stub is also
## the only way to observe §3.2's ordering rule from outside: it records, at the
## moment the first zone is asked to mount, whether the player was already in the
## tree. That is the row's Notes clause turned into a fact rather than a reading
## of the source.
class ZoneManagerStub extends Node:
	var bound_world: Node
	var bound_player: Node
	var mount_calls := 0
	var mounted_zone: StringName = &""
	var mounted_marker: StringName = &""
	var player_in_tree_at_mount := false

	func bind(world_root: Node2D, p: Node2D) -> void:
		bound_world = world_root
		bound_player = p

	func mount_initial(zone_id: StringName, marker: StringName, _position: Vector2) -> void:
		mount_calls += 1
		mounted_zone = zone_id
		mounted_marker = marker
		player_in_tree_at_mount = bound_player != null and bound_player.is_inside_tree()


## Doc 5's one call §3.3 makes. Row 3.2 builds the real one.
class AudioDirectorStub extends Node:
	var zone_calls: Array[StringName] = []

	func set_zone(id: StringName) -> void:
		zone_calls.append(id)


## Tracker 0.12 / Doc 00 §3, §12 checks 12 and 35.
##
## This check drives the LIVE `SessionDirector` against the LIVE resolver and the
## real `root`, because that is the only place check 35's "exactly one node in the
## tree" can be counted. Every tick is driven by hand through `_tick()` rather
## than by awaiting real frames, for the same reason the pure harness does it: an
## awaited frame would advance the boot lock by an unpredictable amount and the
## check would flake instead of failing. The two `await process_frame`s below are
## the exception, and they are there because `queue_free()` is what §3.3 uses.
##
## It leaves the tree exactly as it found it — session ended, handles nulled,
## stubs freed, `GameState` clean — so a real physics frame after the suite
## finishes cannot resolve against anything this check made.
func _check_session_director(h) -> void:
	h.expect_eq(
		ProjectSettings.get_setting("autoload/SessionDirector"),
		"*res://autoload/session_director.gd",
		"SessionDirector autoload registration"
	)
	var s: Node = root.get_node_or_null(^"SessionDirector")
	var d: Node = root.get_node_or_null(^"RuntimeDirector")
	var w: Node = root.get_node_or_null(^"Weirdness")
	var ev: Node = root.get_node_or_null(^"RuntimeEvents")
	var gs: Node = root.get_node_or_null(^"GameState")
	var t: Node = root.get_node_or_null(^"TransitionDirector")
	if not h.expect(
		s != null and d != null and w != null and ev != null and gs != null and t != null,
		"the row 0.12 autoloads are all in the tree"
	):
		return

	# §2.2: "Registration order is load-bearing." Asserted off root's child order
	# rather than off project.godot's text, because the child order IS the order
	# the engine ran the `_ready()`s in — SessionDirector reaches for RuntimeDirector
	# and must be registered above it.
	var kids := root.get_children()
	h.expect(
		kids.find(s) < kids.find(d),
		"SessionDirector is registered above RuntimeDirector (§2.2's eleventh and twelfth)"
	)
	h.expect(
		kids.find(s) > kids.find(t),
		"and below TransitionDirector, which it calls at §3.2 step 4"
	)

	# The two collaborators §3.2 names that do not exist yet. Substituting stubs
	# here is what makes steps 3, 4 and §3.3's audio line observable at all; the
	# handles are public for exactly this, and nothing in the shipped game writes
	# them (SessionDirector._ready() resolves both by path).
	var zm := ZoneManagerStub.new()
	var audio := AudioDirectorStub.new()
	root.add_child(zm)
	root.add_child(audio)
	s.zone_manager = zm
	s.audio_director = audio

	# A known checkpoint, so the marker-first rule of §9.2 is observable in what
	# `mount_initial()` receives. `new_game()` at the end of the check undoes it.
	gs.data.checkpoint[&"zone_id"] = &"z_shack_ext"
	gs.data.checkpoint[&"spawn_marker"] = &"sp_porch"

	# --- §3.2 -----------------------------------------------------------------
	# Awaited even though the stub cannot suspend: row 2.3 gives `mount_initial()`
	# a real threaded load, and a call site that only works while the loader is a
	# stub is a call site that breaks on the day it matters.
	await s.begin_session()

	h.expect(
		s.world_root != null and s.world_root.is_inside_tree(),
		"begin_session() puts a world root in the tree"
	)
	h.expect_eq(zm.bound_world, s.world_root, "ZoneManager is bound to that world root (§3.2 step 3)")
	h.expect_eq(d.player, s.player, "the resolver is bound to the player (§3.2 step 3)")
	h.expect_eq(d.zone_manager, zm, "and to the zone manager, which row 0.10 left for this row")
	h.expect_eq(zm.mount_calls, 1, "the initial zone mounts exactly once")
	h.expect_eq(zm.mounted_zone, &"z_shack_ext", "the checkpoint's zone is what mounts")
	h.expect_eq(
		zm.mounted_marker, &"sp_porch",
		"and the marker — not a raw coordinate — is what it mounts at (§9.2, contract 33)"
	)

	# The row's Notes clause, and §3.2's own closing paragraph: "The player is
	# instantiated BEFORE the first zone so that destination Area2Ds at the spawn
	# marker overlap a body that already exists. Reversing this is the classic
	# first-frame null."
	h.expect(
		zm.player_in_tree_at_mount,
		"the player is already in the tree when the first zone is asked to mount (§3.2)"
	)
	h.expect(
		s.player != null and s.player.get_parent() != null
			and s.player.get_parent().name == "Actors",
		"the player is parented under world_root's Actors node"
	)

	# --- §12 check 35 ---------------------------------------------------------
	# "Exactly one node in the tree carries the weirdness shader material, and
	# Weirdness.bind() was called on it during begin_session()." Counted over the
	# WHOLE tree, from root, because the failure this catches is a second grade
	# appearing in a zone scene or surviving a previous session — never a second
	# one next to the first.
	var shader: Shader = load("res://shaders/weirdness.gdshader")
	h.expect(shader != null, "the weirdness shader loads")
	var carriers: Array[CanvasItem] = []
	_collect_grade_carriers(root, shader, carriers)
	h.expect_eq(carriers.size(), 1, "exactly one node in the tree carries the weirdness shader (§12·35)")
	if carriers.size() == 1:
		var grade := carriers[0]
		h.expect_eq(grade.name, "WeirdnessGrade", "and it is the node Doc 01 §2.1 names")
		h.expect_eq(
			w._mat, grade.material,
			"Weirdness.bind() was called on that node's material during begin_session() (§12·35)"
		)
		var grade_layer := _canvas_layer_of(grade)
		h.expect(
			grade_layer != null and grade_layer.layer == 100,
			"the grade sits on its own CanvasLayer at layer 100 (Doc 01 §2.1)"
		)
		h.expect(
			grade.get_parent() != null and s.world_root.is_ancestor_of(grade),
			"and it hangs off world_root, never off a zone scene (Doc 03 §2.3)"
		)

	# --- §3.2 steps 4-5: the boot lock ----------------------------------------
	var rk: Dictionary = d.get_script().get_script_constant_map()
	var fade_ticks: int = rk["FADE_TICKS"]
	h.expect_eq(t.alpha(), 1.0, "the mount happened behind an already-opaque overlay (§3.2 step 4)")
	h.expect_eq(d._lock_ticks, fade_ticks, "boot hands the resolver a full fade's countdown")
	h.expect_eq(
		s.player.state, PlayerController.State.ZONE_TRANSITION,
		"boot holds control while the countdown runs"
	)
	# §12 check 20's fourth entry point — boot — and §4.5: control comes back
	# because the resolver says so, not because the fade finished. No frame is
	# awaited here, so no tween has advanced at all.
	for _i in fade_ticks:
		_tick(d)
	h.expect_eq(d._lock_ticks, 0, "the boot lock counts down to zero")
	h.expect_eq(
		s.player.state, PlayerController.State.FREE,
		"a booted session is playable — control returns on _lock_ticks == 0 (§3.2 step 5)"
	)

	# --- §12 check 12 ---------------------------------------------------------
	# An event published by the session that is quitting must not resolve into the
	# next one, so there is something in the queue when end_session() runs.
	ev.enqueue(RuntimeEventRecord.Type.INTERACT_REQUEST, null, {})
	var freed_world: Node = s.world_root
	var freed_player: Node = s.player
	var grade_material: ShaderMaterial = w._mat

	s.end_session()

	# §9.1's write-trigger table lists end_session(), and §9.1's rule is that a
	# write is a dirty flag flushed off the physics frame. Asserted and then
	# CLEARED: GameState._process() would otherwise autosave over the developer's
	# real slot 0 on the next frame, which this check awaits two of.
	h.expect(gs._dirty, "end_session() flushes a save through §9.1's dirty flag")
	gs._dirty = false

	h.expect(d.player == null, "end_session() leaves the resolver holding no player (§12·12)")
	h.expect(d.zone_manager == null, "and no zone manager")
	h.expect(
		zm.bound_world == null and zm.bound_player == null,
		"ZoneManager is unbound from the subtree about to be freed (§12·12)"
	)
	h.expect(
		w._mat == null and grade_material != null,
		"Weirdness is unbound from the freed grade's material (§12·12, §12·35)"
	)
	h.expect(s.world_root == null and s.player == null, "SessionDirector drops its own two handles")
	h.expect(
		ev._active.is_empty() and ev._incoming.is_empty(),
		"RuntimeEvents is cleared, so nothing published by the quitting session survives (§3.3)"
	)
	h.expect_eq(
		audio.zone_calls, [&"bgm_menu"] as Array[StringName],
		"the menu rack is what plays after a session ends (§3.3)"
	)

	# `queue_free()` is §3.3's own choice — its caller is a menu button's signal
	# handler — so the frame it defers to is what this awaits. Two of them: the
	# first services the deletion queue, the second is where a leaked reference
	# would show up as a call into freed memory.
	await process_frame
	await process_frame
	h.expect(not is_instance_valid(freed_world), "the world root is actually freed (§12·12)")
	h.expect(not is_instance_valid(freed_player), "and the player with it")
	var orphans: Array[CanvasItem] = []
	_collect_grade_carriers(root, shader, orphans)
	h.expect(
		orphans.is_empty(),
		"no grade survives the session that made it — a second one is what §12·35 forbids"
	)

	# "...and begin_session() immediately after it produces a playable state."
	await s.begin_session()
	h.expect_eq(zm.mount_calls, 2, "a re-begun session mounts its zone again")
	var rebound: Array[CanvasItem] = []
	_collect_grade_carriers(root, shader, rebound)
	h.expect_eq(rebound.size(), 1, "and still exactly one node carries the shader (§12·35)")
	if rebound.size() == 1:
		h.expect_eq(w._mat, rebound[0].material, "Weirdness re-binds to the new grade")
	for _i in fade_ticks:
		_tick(d)
	h.expect_eq(
		s.player.state, PlayerController.State.FREE,
		"the re-begun session is playable, not stuck in ZONE_TRANSITION (§12·12)"
	)

	# Shared state, for any real frame after the suite finishes: end the session,
	# drop the stubs the shipped game would never have, and undo the checkpoint
	# this check wrote.
	s.end_session()
	gs._dirty = false
	s.zone_manager = null
	s.audio_director = null
	zm.free()
	audio.free()
	t.set_opaque(false)
	gs.new_game()


## Tracker 1.1 / Doc 01 §6 and §12 contract 3. `rig_humanoid.tscn` is an
## INHERITED-SCENE base (§10): 30+ character scenes derive from it, row 1.2
## keyframes bone tracks by these exact node paths, and Docs 02 and 04 mount
## equipment and spawn UI from the §6.3 anchors by name. So every name and every
## parent below is a contract, not a detail — a rename here is silent breakage in
## every character at once.
##
## The geometry half asserts the rig is PROPORTION-HONEST: nothing is checked
## against a constant copied into this file, everything against what
## `CharacterProportions.segment()` returns. That is the check that fails the day
## someone bakes Dipper's pixel numbers into the rig and quietly breaks §3.1's
## "rescaling is one field change, not a re-measure".
func _check_rig_humanoid(h) -> void:
	h.expect(RigHumanoidScene is PackedScene, "rig_humanoid.tscn loads as a PackedScene")
	var rig := RigHumanoidScene.instantiate()
	# §6.1 draws the root as a `Node2D`; this narrows it to `CharacterBody2D`.
	# An inherited scene cannot change its root's TYPE, §10 and row 1.3 both require
	# dipper.tscn to INHERIT this scene, and `SessionDirector._make_player()` is
	# typed `-> PlayerController`, which extends `CharacterBody2D`. Since
	# `CharacterBody2D` IS-A `Node2D`, §3.1's ground-contact origin is unchanged.
	h.expect(rig is CharacterBody2D, "the rig instantiates as a CharacterBody2D (§6.1, narrowed for row 1.3)")
	h.expect_eq(rig.name, &"CharacterRoot", "the root carries §6.1's name")

	# §6.1's tree, path by path — the path IS the parent assertion. Eighteen bones:
	# the `b_hair_01 → b_hair_02 → b_hair_03` chain §6.1 marks "(Wendy/Mabel only)"
	# is deliberately absent from the base and added by the scenes that inherit it.
	var hips := "Skeleton2D/b_hips"
	var torso_n := hips + "/b_torso"
	var head_n := torso_n + "/b_head"
	var arm_l := torso_n + "/b_arm_l_upper"
	var arm_r := torso_n + "/b_arm_r_upper"
	var hand_l := arm_l + "/b_arm_l_fore/b_hand_l"
	var hand_r := arm_r + "/b_arm_r_fore/b_hand_r"
	var leg_l := hips + "/b_leg_l_upper"
	var leg_r := hips + "/b_leg_r_upper"
	var foot_l := leg_l + "/b_leg_l_lower/b_foot_l"
	var foot_r := leg_r + "/b_leg_r_lower/b_foot_r"
	var bone_paths: PackedStringArray = [
		hips, torso_n, head_n,
		head_n + "/b_brow_l", head_n + "/b_brow_r", head_n + "/b_jaw",
		arm_l, arm_l + "/b_arm_l_fore", hand_l,
		arm_r, arm_r + "/b_arm_r_fore", hand_r,
		leg_l, leg_l + "/b_leg_l_lower", foot_l,
		leg_r, leg_r + "/b_leg_r_lower", foot_r,
	]
	h.expect_eq(bone_paths.size(), 18, "§6.1's base tree is eighteen bones, hair excluded")
	for path in bone_paths:
		h.expect(rig.get_node_or_null(path) is Bone2D, "%s is a Bone2D at its §6.1 path" % path)

	h.expect(rig.get_node_or_null(^"Skeleton2D") is Skeleton2D, "Skeleton2D is a Skeleton2D")
	h.expect(rig.get_node_or_null(^"Parts") is Node2D, "Parts is a Node2D")
	h.expect(rig.get_node_or_null(^"Anchors") is Node2D, "Anchors is a Node2D")
	var shadow := rig.get_node_or_null(^"Shadow")
	h.expect(shadow is Polygon2D, "Shadow is a Polygon2D")
	h.expect(
		shadow != null and shadow.get_parent() == rig,
		"and hangs off the root, unparented from the skeleton (§6.1) — it never rotates with a bone"
	)

	# AUDIT B19 / §6.2: the z_index table is the SOLE sort inside a character. A
	# second sort over the same children re-sorts a swinging arm mid-animation,
	# which is intermittent limb pop-through in `walk` and `run` — invisible in a
	# still, and the classic cutout artifact. Walked over the WHOLE rig, not just
	# `Parts`, because an ancestor that y-sorts sorts `Parts`'s children too.
	h.expect(not (rig.get_node(^"Parts") as Node2D).y_sort_enabled, "Parts.y_sort_enabled is false (§6.2)")
	var y_sorters: PackedStringArray = []
	_collect_y_sorted(rig, rig, y_sorters)
	h.expect(y_sorters.is_empty(), "nothing in the rig y-sorts (AUDIT B19): %s" % ", ".join(y_sorters))

	# §6.3's table, and it is authoritative about the PARENT: an anchor under a
	# plain container could not follow the bone it mounts to.
	#
	# FINDING — §6.1 and §6.3 disagree. §6.1 draws `Anchors (Node2D)` as a sibling
	# of `Skeleton2D` holding the anchors; §6.3 parents seven of the eight to bones.
	# Resolved in §6.3's favour, since a bone-following anchor is the whole point of
	# the node: the seven bone-mounted anchors are children of their bones, and the
	# `Anchors` container holds `a_ground` — whose §6.3 parent is `CharacterRoot`,
	# which a container that is itself a child of `CharacterRoot` satisfies.
	var anchor_parents := {
		"a_hand_r": hand_r,
		"a_hand_l": hand_l,
		"a_head_top": head_n,
		"a_face": head_n,
		"a_back": torso_n,
		"a_chest": torso_n,
		"a_ground": "Anchors",
		"a_interact": hips,
	}
	h.expect_eq(anchor_parents.size(), 8, "§12 contract 3 promises eight anchors")
	for anchor_name: String in anchor_parents:
		var parent_path: String = anchor_parents[anchor_name]
		var anchor := rig.get_node_or_null(parent_path + "/" + anchor_name)
		h.expect(anchor is Marker2D, "%s is a Marker2D under %s (§6.3)" % [anchor_name, parent_path])
	h.expect(
		rig.get_node(^"Anchors").get_parent() == rig,
		"the Anchors container is a child of CharacterRoot, so a_ground's §6.3 parent still holds"
	)

	# --- the derived layout ---------------------------------------------------
	# `_ready()` is what lays the skeleton out, and it only runs in the tree. This
	# is the same call the @tool script makes in the editor for row 1.2.
	root.add_child(rig)

	# The script's own fallback when `proportions` is null, and §3.3's Dipper.
	var p := CharacterProportionsResource.new()
	var foot: Vector2 = p.segment(&"foot")
	var shin: Vector2 = p.segment(&"leg_lower")
	var thigh: Vector2 = p.segment(&"leg_upper")
	var torso: Vector2 = p.segment(&"torso")
	var arm_upper: Vector2 = p.segment(&"arm_upper")
	var arm_fore: Vector2 = p.segment(&"arm_fore")
	var hip_y := -(foot.x + shin.x + thigh.x)

	var hips_node: Node2D = rig.get_node(hips)
	h.expect(
		absf(hips_node.position.y - hip_y) < 0.01,
		"the hips rest at the top of §3.2's foot+shin+thigh stack (%f)" % hips_node.position.y
	)
	# A Bone2D whose position differs from its rest is already POSED, and row 1.2's
	# animations key their deltas off `rest`.
	for path in bone_paths:
		var bone: Bone2D = rig.get_node(path)
		h.expect(
			bone.rest.origin.is_equal_approx(bone.position),
			"%s's rest matches the position it was laid out at" % path
		)

	# §3.1: origin at ground contact, feet-centered.
	for path in [foot_l, foot_r]:
		var f: Node2D = rig.get_node(path)
		h.expect(absf(f.global_position.y) < p.height * 0.01, "%s rests on the ground plane (§3.1)" % path)
	h.expect(
		is_equal_approx((rig.get_node(foot_l) as Node2D).global_position.x,
			-(rig.get_node(foot_r) as Node2D).global_position.x),
		"and the feet straddle the origin, so it is horizontally centered between them"
	)

	# §3.2 has no neck: the head mounts directly to the torso top.
	var head: Node2D = rig.get_node(head_n)
	h.expect(
		absf(head.global_position.y - (hip_y - torso.x)) < 0.01,
		"the head mounts directly at the torso top — §3.2 gives the kids no neck"
	)
	var head_top: Node2D = rig.get_node(head_n + "/a_head_top")
	h.expect(
		absf(head_top.global_position.y + p.height) < p.height * 0.05,
		"the top of the head lands within §11's 5%% of the declared height (%f vs %f)"
			% [head_top.global_position.y, -p.height]
	)
	# §5.1's eye line, which is also where the face anchor spawns portraits from.
	var eye_line: float = head.global_position.y - p.head_diameter \
		+ float(EyeGeometry.geometry(p.head_diameter)["center_y"])
	h.expect(
		absf((rig.get_node(head_n + "/a_face") as Node2D).global_position.y - eye_line) < 0.01,
		"a_face sits on §5.1's eye line"
	)
	var brow: Node2D = rig.get_node(head_n + "/b_brow_l")
	h.expect(brow.global_position.y < eye_line, "the brows sit above the eye line, not on it")

	var shoulder_l: Node2D = rig.get_node(arm_l)
	var shoulder_r: Node2D = rig.get_node(arm_r)
	h.expect(
		absf(absf(shoulder_r.position.x - shoulder_l.position.x) - torso.y) < torso.y * 0.25,
		"the shoulders are separated by roughly §3.2's torso width"
	)
	h.expect(is_equal_approx(shoulder_l.position.y, shoulder_r.position.y), "and sit at the same height")
	h.expect(
		shoulder_l.global_position.y >= hip_y - torso.x
			and shoulder_l.global_position.y <= hip_y - torso.x * 0.75,
		"in the top quarter of the torso (%f)" % shoulder_l.global_position.y
	)
	h.expect(
		absf((rig.get_node(hand_l) as Node2D).global_position.y
			- (shoulder_l.global_position.y + arm_upper.x + arm_fore.x)) < 0.01,
		"and the arm chain hangs §3.2's upper+fore length below them"
	)
	h.expect(
		(rig.get_node(hand_l) as Node2D).global_position.y < 0.0,
		"a hanging hand stays above the ground"
	)
	h.expect(
		(rig.get_node(^"Shadow") as Polygon2D).polygon.size() > 3,
		"the shadow ellipse is built from the proportions, not left empty"
	)

	# --- the §10 one-field rescale --------------------------------------------
	# The check that fails the day someone hardcodes Dipper's numbers: the ONLY
	# difference between these two rigs is `height`.
	var tall := CharacterProportionsResource.new()
	tall.height = 300.0
	var big := RigHumanoidScene.instantiate()
	big.proportions = tall
	root.add_child(big)

	var big_hips: Node2D = big.get_node(hips)
	var tall_hip_y := -(tall.segment(&"foot").x + tall.segment(&"leg_lower").x
		+ tall.segment(&"leg_upper").x)
	h.expect(
		absf(big_hips.position.y - tall_hip_y) < 0.01,
		"a rescaled rig's hips follow ITS OWN segment() stack (%f)" % big_hips.position.y
	)
	h.expect(
		absf(big_hips.position.y / hips_node.position.y - tall.height / p.height) < 0.001,
		"the hip height scales with `height` alone — §3.1's one field, not a re-measure"
	)
	var big_top: Node2D = big.get_node(head_n + "/a_head_top")
	h.expect(
		absf(big_top.global_position.y + tall.height) < tall.height * 0.05,
		"and the taller rig is as tall as ITS height says (%f vs %f)"
			% [big_top.global_position.y, -tall.height]
	)
	h.expect(
		absf((big.get_node(foot_l) as Node2D).global_position.y) < tall.height * 0.01,
		"while its feet stay on the ground plane"
	)

	# `free()`, not `queue_free()`: a `--script` run quits without servicing the
	# deletion queue, so a queued node is a leak the suite reports on exit.
	big.free()
	rig.free()


## Tracker 1.1 / Doc 01 §§4, 5 and 6.2 — the PARTS half of the rig, which is the
## half that decides whether a limb bends or hinges. `_check_rig_humanoid` above
## already asserted that nothing in the rig y-sorts; that walk covers `Parts` and
## everything under it, so it is deliberately not repeated here.
func _check_rig_parts(h) -> void:
	var rig := RigHumanoidScene.instantiate()
	root.add_child(rig)   # `_ready()` is what derives the geometry.
	var parts := rig.get_node(^"Parts") as Node2D
	var skeleton := rig.get_node(^"Skeleton2D") as Skeleton2D

	# --- §6.2's table, read in BOTH directions --------------------------------
	# Every row is a node at exactly its z_index, and every node is a row. The
	# second direction is the one that catches the part someone adds later and
	# leaves at the default 0, drawing inside the torso.
	for part_name: String in PART_Z_INDEX:
		var part := parts.get_node_or_null(part_name) as CanvasItem
		if h.expect(part != null, "§6.2's `%s` exists under Parts" % part_name):
			h.expect_eq(part.z_index, int(PART_Z_INDEX[part_name]), "%s z_index (§6.2)" % part_name)
	for child in parts.get_children():
		h.expect(
			PART_Z_INDEX.has(String(child.name)),
			"Parts/%s is a row of §6.2's draw-order table" % child.name
		)

	# --- §4.2's hoses, the thing that makes or breaks the style ----------------
	# §12 contract 8: ONE polygon per limb spanning BOTH bones, never split at the
	# elbow or knee. Two polygons hinged at a shared point are the hard mechanical
	# elbow the whole design exists to avoid — and with flat placeholder fills the
	# failure is INVISIBLE until the first hose PNG lands at row 6.3.
	var p := CharacterProportionsResource.new()
	var arm_length: float = p.segment(&"arm_upper").x + p.segment(&"arm_fore").x
	var leg_length: float = p.segment(&"leg_upper").x + p.segment(&"leg_lower").x
	# §4.2's bands. Legs sit 0.04 lower than arms: "knees sit slightly lower
	# proportionally than elbows".
	var arm_band := Vector2(0.38, 0.62)
	var leg_band := Vector2(0.42, 0.66)
	# name, upper bone (relative to the SKELETON, which is what resolves it),
	# far bone, hose length, blend band.
	var hoses: Array = [
		["arm_hose_l", "b_hips/b_torso/b_arm_l_upper", "b_hips/b_torso/b_arm_l_upper/b_arm_l_fore", arm_length, arm_band],
		["arm_hose_r", "b_hips/b_torso/b_arm_r_upper", "b_hips/b_torso/b_arm_r_upper/b_arm_r_fore", arm_length, arm_band],
		["leg_hose_l", "b_hips/b_leg_l_upper", "b_hips/b_leg_l_upper/b_leg_l_lower", leg_length, leg_band],
		["leg_hose_r", "b_hips/b_leg_r_upper", "b_hips/b_leg_r_upper/b_leg_r_lower", leg_length, leg_band],
	]
	for row: Array in hoses:
		var hose_name := String(row[0])
		var upper := String(row[1])
		var far := String(row[2])
		var length := float(row[3])
		var band: Vector2 = row[4]

		var hose := parts.get_node_or_null(hose_name) as Polygon2D
		if not h.expect(hose != null, "%s is a Polygon2D under Parts" % hose_name):
			continue
		h.expect_eq(hose.polygon.size(), 28, "%s is §4.1's 28-vertex capsule" % hose_name)
		h.expect(
			hose.get_node_or_null(hose.skeleton) == skeleton,
			"%s's skeleton resolves to the rig's Skeleton2D" % hose_name
		)
		# Exactly two: one bone is a rigid limb, three is a rig Doc 01 does not
		# describe, and a hose split into two polygons never gets here at all.
		if not h.expect_eq(hose.get_bone_count(), 2, "%s spans exactly two bones (§4.2)" % hose_name):
			continue
		h.expect_eq(String(hose.get_bone_path(0)), upper, "%s's first bone is its upper segment" % hose_name)
		h.expect_eq(String(hose.get_bone_path(1)), far, "%s's second bone is its far segment" % hose_name)

		var upper_weights := hose.get_bone_weights(0)
		var far_weights := hose.get_bone_weights(1)
		h.expect_eq(upper_weights.size(), hose.polygon.size(), "%s weights its upper bone once per vertex" % hose_name)
		h.expect_eq(far_weights.size(), hose.polygon.size(), "%s weights its far bone once per vertex" % hose_name)
		if upper_weights.size() != hose.polygon.size() or far_weights.size() != hose.polygon.size():
			continue

		# Partition of unity, vertex by vertex. A vertex whose weights sum to
		# anything but 1.0 shrinks or explodes as the joint bends, and it does so
		# silently — the polygon is still closed and still filled.
		var partitioned := true
		var on_profile := true
		var blended := 0
		for i in hose.polygon.size():
			if not is_equal_approx(upper_weights[i] + far_weights[i], 1.0):
				partitioned = false
			# `t` from the vertex's own Y over the hose length, which is how §4.2
			# says the weights are derived in the first place.
			var expected := TubeGeometry.hose_weights(hose.polygon[i].y / length, band.x, band.y)
			if not (is_equal_approx(upper_weights[i], expected.x) and is_equal_approx(far_weights[i], expected.y)):
				on_profile = false
			if upper_weights[i] > 0.0 and upper_weights[i] < 1.0:
				blended += 1
		h.expect(partitioned, "%s's two bones partition to 1.0 at every vertex (§4.2)" % hose_name)
		h.expect(on_profile, "%s follows §4.2's weight profile for its own blend band" % hose_name)
		# §11's guard, applied to the REAL limb rather than to a synthetic capsule:
		# with no vertices strictly inside the band every vertex belongs wholly to
		# one bone and "limbs will hinge, not bend".
		h.expect(
			blended >= 4,
			"%s has at least four vertices strictly inside its blend band, got %d" % [hose_name, blended]
		)

	# The two bands are really different ON THE RIG, not two constants that happen
	# to be typed in a file: at the same normalised `t` the profiles must disagree.
	var arm_mid := _fore_weight_at(parts.get_node_or_null(^"arm_hose_l") as Polygon2D, arm_length, 0.5)
	var leg_mid := _fore_weight_at(parts.get_node_or_null(^"leg_hose_l") as Polygon2D, leg_length, 0.5)
	h.expect(arm_mid >= 0.0 and leg_mid >= 0.0, "both hoses carry a vertex at mid-limb to compare")
	h.expect(
		is_equal_approx(arm_mid, TubeGeometry.hose_weights(0.5, 0.38, 0.62).y),
		"the arm blends on §4.2's 0.38–0.62 band at mid-limb (%f)" % arm_mid
	)
	h.expect(
		is_equal_approx(leg_mid, TubeGeometry.hose_weights(0.5, 0.42, 0.66).y),
		"the leg blends on §4.2's shifted 0.42–0.66 band at mid-limb (%f)" % leg_mid
	)
	h.expect(
		absf(arm_mid - leg_mid) > 0.1,
		"and the knee really does sit lower than the elbow — same t, different weight (%f vs %f)"
			% [arm_mid, leg_mid]
	)

	# --- §4.4: hands and feet are RIGID ---------------------------------------
	# Weight 1.0 to the terminal bone, no blending. A mitten that blended would
	# deform when the wrist turned, which is the one place the show never bends.
	var rigid_parts := {
		"hand_l": "b_hips/b_torso/b_arm_l_upper/b_arm_l_fore/b_hand_l",
		"hand_r": "b_hips/b_torso/b_arm_r_upper/b_arm_r_fore/b_hand_r",
		"foot_l": "b_hips/b_leg_l_upper/b_leg_l_lower/b_foot_l",
		"foot_r": "b_hips/b_leg_r_upper/b_leg_r_lower/b_foot_r",
	}
	for part_name: String in rigid_parts:
		var poly := parts.get_node_or_null(part_name) as Polygon2D
		if not h.expect(poly != null, "%s is a Polygon2D under Parts" % part_name):
			continue
		if not h.expect_eq(poly.get_bone_count(), 1, "%s is rigid — one bone, no blending (§4.4)" % part_name):
			continue
		h.expect_eq(
			String(poly.get_bone_path(0)), String(rigid_parts[part_name]),
			"%s hangs off its own terminal bone" % part_name
		)
		var weights := poly.get_bone_weights(0)
		h.expect_eq(weights.size(), poly.polygon.size(), "%s weights once per vertex" % part_name)
		var all_one := weights.size() > 0
		for w in weights:
			if not is_equal_approx(w, 1.0):
				all_one = false
		h.expect(all_one, "%s is weighted 1.0 at every vertex (§4.4)" % part_name)

	# --- Deferred D11 / §12 contract 7 ----------------------------------------
	# Zero PNGs exist and none may be added: `Polygon2D.texture` stays null and
	# every part is a flat colour fill. Real art lands at R1 by assigning textures
	# to these same nodes, which is also why the nodes are authored in the scene
	# and not conjured here.
	var polygons: Array[Polygon2D] = []
	_collect_polygons(parts, polygons)
	var textured: PackedStringArray = []
	var empty: PackedStringArray = []
	for poly in polygons:
		if poly.texture != null:
			textured.append(String(poly.name))
		if poly.polygon.size() < 3:
			empty.append(String(poly.name))
	h.expect(
		textured.is_empty(),
		"no part carries a texture — placeholders render everything (D11 / §12 contract 7): %s"
			% ", ".join(textured)
	)
	h.expect(
		empty.is_empty(),
		"every part's geometry is derived from the proportions, not left empty: %s" % ", ".join(empty)
	)

	# --- §5: the eye pair ------------------------------------------------------
	var eyes := parts.get_node_or_null(^"eyes") as Node2D
	if h.expect(eyes != null, "the `eyes` part is present (§6.2)"):
		h.expect_eq(
			eyes.scene_file_path, "res://actors/eye_pair.tscn",
			"and is an instance of §10's eye_pair.tscn, not a bespoke node"
		)
		h.expect_eq(eyes.get(&"head_diameter"), p.head_diameter, "the rig drives its head diameter")
		# §5.1's vertical centre is 0.46·D below the head top — the same line
		# `a_face` already sits on, so the two must not be allowed to disagree.
		var face := rig.get_node(^"Skeleton2D/b_hips/b_torso/b_head/a_face") as Node2D
		h.expect(
			eyes.global_position.is_equal_approx(face.global_position),
			"and parks it on §5.1's eye line, where a_face is (%s vs %s)"
				% [eyes.global_position, face.global_position]
		)

	# --- §3.1's ground plane and §5.1's eye line, read off the POLYGONS --------
	_check_rig_silhouette(h, rig, p.head_diameter, "the base rig")

	# --- the §10 one-field rescale, applied to the parts ----------------------
	# The same contract `_check_rig_humanoid` asserted for bones: an inheriting
	# character overrides ONE resource, and the geometry follows. This is the
	# check that fails the day someone bakes Dipper's numbers into a polygon.
	var tall := CharacterProportionsResource.new()
	tall.height = 300.0
	tall.head_ratio = 0.27   # §3.3's Wendy — a different HEAD, not just a taller body.
	var big := RigHumanoidScene.instantiate()
	big.proportions = tall
	root.add_child(big)

	var big_eyes := big.get_node(^"Parts/eyes") as Node2D
	h.expect_eq(
		big_eyes.get(&"head_diameter"), tall.head_diameter,
		"a rescaled rig's eyes follow ITS OWN head diameter (§10's one field)"
	)
	var base_radius: float = float(EyeGeometry.geometry(p.head_diameter)["radius"])
	var tall_radius: float = float(EyeGeometry.geometry(tall.head_diameter)["radius"])
	h.expect(
		not is_equal_approx(base_radius, tall_radius),
		"and that really is a different §5.1 eye radius, so the check is not comparing a constant to itself"
	)
	var big_face := big.get_node(^"Skeleton2D/b_hips/b_torso/b_head/a_face") as Node2D
	h.expect(
		big_eyes.global_position.is_equal_approx(big_face.global_position),
		"while still landing on its own eye line"
	)

	# The hoses rescale with it. `hose_texture_size` minus its two margins is
	# exactly the capsule's Y extent, so this reads the shape rather than trusting
	# an index into `Tube`'s vertex order.
	var big_arm := big.get_node(^"Parts/arm_hose_l") as Polygon2D
	var base_arm := parts.get_node(^"arm_hose_l") as Polygon2D
	var tall_arm_length: float = tall.segment(&"arm_upper").x + tall.segment(&"arm_fore").x
	var tall_extent: float = TubeGeometry.hose_texture_size(
		tall_arm_length, tall.segment(&"arm_upper").y, tall.segment(&"arm_fore").y).y - 2.0
	h.expect(
		absf(_polygon_height(big_arm.polygon) - tall_extent) < 0.01,
		"a rescaled rig's arm hose spans ITS OWN §3.2 arm length (%f vs %f)"
			% [_polygon_height(big_arm.polygon), tall_extent]
	)
	h.expect(
		not is_equal_approx(_polygon_height(big_arm.polygon), _polygon_height(base_arm.polygon)),
		"which is not the base rig's arm length — the geometry is derived, never baked"
	)
	# Both silhouette contracts survive the rescale, or they were pixel numbers
	# that happened to work at Dipper's size.
	_check_rig_silhouette(h, big, tall.head_diameter, "the rescaled rig")

	# `free()`, not `queue_free()`: a `--script` run quits without servicing the
	# deletion queue, so a queued node is a leak the suite reports on exit.
	big.free()
	rig.free()


## Tracker 1.1 repair / Doc 01 §3.1 and §5.1 — the two contracts that live in the
## POLYGONS rather than in the bones, and that every numeric check in this file
## missed because it read a bone position instead of the shape riding it.
##
##   * §3.1 puts the character origin at ground contact. A foot BONE resting on
##     y = 0 says nothing about the foot: `Tube.capsule` adds a round cap of half
##     the end width past each end, and that cap put `leg_w · 0.85` of foot below
##     the floor while `Shadow` — correctly centred on y = 0 — sat at the ankles.
##   * §5.1 puts the eye line 0.46·D below the head top and §5.2 puts the brows
##     above it. `hat` draws at z_index 30 over `brows` at 20 (§6.2), so a cap
##     that reaches past the brows does not overlap them, it DELETES them.
##
## Run against the base rig and against §10's one-field rescale, since a fix that
## only holds at Dipper's D is a pixel number wearing a formula's clothes.
##
## Godot 2D is Y-down and the origin IS the ground, so "below the ground" is a
## POSITIVE Y and "above the eye line" is a smaller one.
func _check_rig_silhouette(h, rig: Node2D, head_diameter: float, label: String) -> void:
	var parts := rig.get_node(^"Parts") as Node2D
	var to_rig := rig.global_transform.affine_inverse()
	var polygons: Array[Polygon2D] = []
	_collect_polygons(parts, polygons)
	# Not a formality: an empty walk would pass every assertion below vacuously.
	# Fourteen — §6.2's rows minus `eyes` (a `_draw()` node) and `held_item` (a
	# bare mount point), plus the two brows the `brows` row expands into.
	h.expect_eq(polygons.size(), 14, "%s: the ground walk sees every §6.2 polygon part" % label)

	# A pixel of slack — these are derived floats, not authored ones — against a
	# height of 250+ px, so a real breach is two orders of magnitude larger.
	const GROUND_EPS := 1.0
	var sunk := PackedStringArray()
	var soles := {}
	var hat_bottom := -INF
	var brow_top := INF
	for poly in polygons:
		# The part's OWN transform, not just its `polygon`: `_rigid` and `_hose`
		# put the derived offset in `position`, which is exactly where the foot
		# bug lived.
		var span := _polygon_y_span(to_rig * poly.global_transform, poly.polygon)
		if span.y > GROUND_EPS:
			sunk.append("%s (+%.2f)" % [poly.name, span.y])
		var part_name := String(poly.name)
		if part_name.begins_with("foot_"):
			soles[part_name] = span.y
		elif part_name == "hat":
			hat_bottom = span.y
		elif part_name.begins_with("brow_"):
			brow_top = minf(brow_top, span.x)
	# Nothing is exempt. `Shadow` is a ground decal centred on y = 0 and is
	# deliberately out of range here — it hangs off `CharacterRoot`, not `Parts`.
	h.expect(
		sunk.is_empty(),
		"%s: no part of the rig crosses §3.1's ground plane: %s" % [label, ", ".join(sunk)]
	)

	# The other half of §3.1, and the reason the check above is not enough on its
	# own: a rig hovering a foot off the floor passes "nothing below y = 0" and is
	# just as wrong — the shadow would sit under nobody.
	h.expect_eq(soles.size(), 2, "%s: both feet are present to stand on" % label)
	for foot_name: String in soles:
		h.expect(
			absf(soles[foot_name]) <= GROUND_EPS,
			"%s: %s's sole rests ON the ground plane, neither sunk nor floating (%.2f)"
				% [label, foot_name, soles[foot_name]]
		)

	# §5.1's eye line, measured down from the crown `a_head_top` marks, exactly as
	# `rebuild()` derives it — never a copied constant.
	var crown: float = (to_rig * (rig.get_node(
		^"Skeleton2D/b_hips/b_torso/b_head/a_head_top") as Node2D).global_position).y
	var eye_line: float = crown + float(EyeGeometry.geometry(head_diameter)["center_y"])
	h.expect(hat_bottom > -INF, "%s: the `hat` part carries geometry to measure" % label)
	h.expect(brow_top < INF, "%s: the brows carry geometry to measure" % label)
	h.expect(
		brow_top < eye_line,
		"%s: the brow polygons sit above §5.1's eye line (%.2f vs %.2f)" % [label, brow_top, eye_line]
	)
	h.expect(
		hat_bottom < eye_line,
		"%s: the hat's lowest point clears §5.1's eye line, so it cannot cover a pupil (%.2f vs %.2f)"
			% [label, hat_bottom, eye_line]
	)
	# Asserted against the brows THEMSELVES rather than a margin typed in here, so
	# the check follows them if §5.2's brow geometry ever moves.
	h.expect(
		hat_bottom < brow_top,
		"%s: and clears the brows it draws over at z_index 30 (%.2f vs %.2f)"
			% [label, hat_bottom, brow_top]
	)


## The topmost and bottommost Y of a polygon once its own transform is applied.
## Godot 2D is Y-down, so `.x` is the top edge and `.y` is the bottom one.
func _polygon_y_span(xform: Transform2D, points: PackedVector2Array) -> Vector2:
	var span := Vector2(INF, -INF)
	for point in points:
		var y := (xform * point).y
		span = Vector2(minf(span.x, y), maxf(span.y, y))
	return span


## The far-bone weight of the vertex sitting at `t` along a hose, or −1.0 when
## the hose has no vertex there — which is itself a finding, since §4.1's shaft
## samples are what put vertices inside the blend band at all.
func _fore_weight_at(hose: Polygon2D, length: float, t: float) -> float:
	if hose == null or hose.get_bone_count() < 2:
		return -1.0
	var weights := hose.get_bone_weights(1)
	for i in hose.polygon.size():
		if absf(hose.polygon[i].y / length - t) < 0.001:
			return weights[i]
	return -1.0


func _collect_polygons(n: Node, out: Array[Polygon2D]) -> void:
	if n is Polygon2D:
		out.append(n)
	for child in n.get_children():
		_collect_polygons(child, out)


func _polygon_height(points: PackedVector2Array) -> float:
	var low := INF
	var high := -INF
	for point in points:
		low = minf(low, point.y)
		high = maxf(high, point.y)
	return high - low


## Every node in a rig that y-sorts. §6.2 allows exactly none: `z_index` is the
## sole sort inside a character, and the second sort is invisible until a limb
## pops through mid-`walk`.
func _collect_y_sorted(from: Node, n: Node, out: PackedStringArray) -> void:
	if n is CanvasItem and (n as CanvasItem).y_sort_enabled:
		out.append(str(from.get_path_to(n)))
	for child in n.get_children():
		_collect_y_sorted(from, child, out)


## The nearest `CanvasLayer` above a node, walked rather than queried: Godot 4.7
## exposes no `get_canvas_layer()` on `CanvasItem`, and the walk answers the
## question Doc 01 §2.1 actually asks — which layer is the grade drawn on —
## whether row 2.2 parents it directly or nests it.
func _canvas_layer_of(n: Node) -> CanvasLayer:
	var p := n.get_parent()
	while p != null:
		if p is CanvasLayer:
			return p
		p = p.get_parent()
	return null


## Every `CanvasItem` in the tree whose material runs the weirdness shader.
## Recursive from `root`, because §12 check 35 is a statement about the whole
## tree: the bug it catches is a grade in a zone scene or one left behind by a
## previous session, neither of which is anywhere near the real one.
func _collect_grade_carriers(n: Node, shader: Shader, out: Array[CanvasItem]) -> void:
	if n is CanvasItem:
		var mat := (n as CanvasItem).material
		if mat is ShaderMaterial and (mat as ShaderMaterial).shader == shader:
			out.append(n)
	for child in n.get_children():
		_collect_grade_carriers(child, shader, out)


## The autoload's own tick. Statically typed as `Node`,
## `c._physics_process(0.0)` dispatches to the native no-op virtual; `call()`
## reaches the GDScript override — the same reason harness.gd's `step()` does it.
func _tick(n: Node) -> void:
	n.call(&"_physics_process", 0.0)


## Doc 00 §12 check 20's shape, run once per entry point: step the resolver the
## lock's own declared number of ticks and assert control is still held one tick
## short of zero and returned exactly at zero.
func _expect_lock_releases(h, d: Node, ticks: int, what: String) -> void:
	h.expect_eq(d._lock_ticks, ticks, "%s declares its full countdown" % what)
	for _i in ticks - 1:
		h.step()
	h.expect(
		d._lock_ticks == 1 and h.player.state == PlayerController.State.ZONE_TRANSITION,
		"%s still holds control one tick before the countdown ends (_lock_ticks=%d, state=%d)"
			% [what, d._lock_ticks, h.player.state]
	)
	h.step()
	h.expect_eq(d._lock_ticks, 0, "%s countdown reaches zero" % what)
	h.expect_eq(h.player.state, PlayerController.State.FREE, "%s returns control at zero" % what)


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
