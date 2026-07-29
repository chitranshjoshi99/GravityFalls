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
