# Pre-build audit — 2026-07-28

> **Status: findings applied.** Every Critical and High finding below, and all of §4's model corrections, have been fixed in the documents. §8's four blocking questions were answered — **web is best-effort with macOS native as the primary target; `Journal` is a node on the player; `stretch_aspect = keep`; the golf cart stays in Chapter 1** — and the docs now reflect those calls. The remaining open items are §8 questions 2, 5, and 6, and TB's optional cut list in §5, which are scope decisions rather than defects. See §11 for the applied-change log.

**Mode:** pre-build. No code exists. This reviews the seven design documents before a line of GDScript is written, because a bad call caught here is a doc edit and the same call caught in month three is a rewrite.

**Personas run:** Architect (ARCH), Tech-bro (TB). Not run: product-head, design-girl, security-master, devops, legal-bro, finance-bro, COO — see §7 for what that leaves uncovered.

**Scope reviewed:** `foundation.md`, `README.md`, `docs/00`–`docs/06` (~6,300 lines).

---

## 1. Verdicts

| Persona | Verdict | Core judgement |
|---|---|---|
| **ARCH** | **Revise** | The runtime contract in Doc 00 is the strongest artifact in the project and its shape should not change. But it supersedes Docs 1–5 by *assertion* rather than by edit, and several superseded behaviours still stand uncorrected in the source docs. Ownership of `Journal`, live `Health`, `GameState`'s shape, the grade material, and the save format is unassigned in all eight documents. |
| **TB** | **Revise** | Groundwork is largely load-bearing and correctly identified. But the slice carries a golf cart, threaded streaming, a runtime audio synthesizer, and a 192-file asset manifest that Chapter 1 does not need, and there is **no locked project tree** — the single most expensive omission for a build that will run across many separate sessions. |

| Doc | Verdict | Reason |
|---|---|---|
| `README.md` | Revise | Omits Doc 00 entirely; marks Doc 6 "Not started" when it is complete; lists 5 test suites where 7 exist. |
| `00-game-loop.md` | Revise | Resolver design holds. Two of its Godot-4 justifications do not, and the supersession table is a promise with no mechanism. |
| `01-theme-animation-asset-tokens.md` | Revise | `Tube.capsule` emits zero vertices inside the blend band the entire rig depends on. Web-perf mitigation contradicted by the doc's own zone table. |
| `02-physics-engine-mechanics.md` | Revise | Scanner polls bodies for Area targets; `scan` is an InputMap-impossible chord; the state `match` was never extended for Doc 00's four new states. |
| `03-world-maps-environment.md` | Revise | Streaming assumes a background thread the web export may not have; `seam_chapter` encodes per-edge data on a per-zone field. |
| `04-ui-hud-menus.md` | Revise | HUD reads `GameState.health`/`.stamina`, which exist nowhere; "nothing is fixed-height" contradicted two sections earlier. |
| `05-audio-engine-sfx.md` | Revise | Bake-don't-stream is the right call and holds. The "well under a second" bake and the unquantized crossfade do not. |
| `06-chapter-01-tourist-trapped.md` | Revise | Best-argued doc in the set, and correct as a gate design. But it cites APIs that don't exist, and its gate cannot detect failure of the decision most expensive to reverse. |
| **Cross-doc layer** | **Revise** | Five ownership questions unassigned; the supersession table is where drift hides. |

**Verified independently** (read against source, not taken on report): B1, B4, B5, B8, B9, B10, B15.

---

## 2. Blockers — fix before writing code

These break at or near first launch, or corrupt an invariant the design promises.

### B1 · `Tube.capsule` puts zero vertices in the blend band — Critical ✓verified
`01:342-362` emits 18 vertices: two shoulder points at `y = 0`, two wrist points at `y = length`, and 14 cap points at `y ≤ 0` or `y ≥ length`. **There are no vertices along the shaft.** Since `t` is "computed from each vertex's Y position over the limb length" (`01:389`), every vertex resolves to `t ≤ 0` or `t ≥ 1`, and `hose_weights` returns exactly `(1,0)` or `(0,1)` for all 18. The 24%-of-length blend band at `01:378` is empty.

The limb hinges as two rigid halves — the "hard mechanical elbow" that `01:371` exists to prevent. **You will not see this during Chapter 1**, because the slice ships placeholder flat fills where a capsule splitting at its caps still reads as an arm. It surfaces the day the first `arm_hose_l.png` lands, after the §13 gate has passed. §11's test validates `hose_weights` in isolation and never asks whether a real capsule vertex reaches the band, so it is green while the system is inoperative.

**Fix:** add `shaft_segs: int = 6` to `Tube.capsule`, emitting intermediate vertex pairs down each side (32 vertices, still trivial). Then add to `01:771`:

```gdscript
var in_band := 0
for p in Tube.capsule(100.0, 20.0, 8):
	var t := p.y / 100.0
	if t > 0.38 and t < 0.62: in_band += 1
assert(in_band >= 4, "blend band is empty — limbs will hinge, not bend")
```

### B2 · `PlayerController` was never extended for Doc 00's four new states — High ✓verified
`00:39` supersedes the **enum** and nothing else. The `match state:` at `02:235-243` has arms for `FREE/JOURNAL`, `DODGING`, `HURT/FUMBLING`, `CUTSCENE` — no arm for `ATTACKING`, `DRIVING`, `ZONE_TRANSITION`, `BLACKOUT`, and no `_:` default. After the match, `velocity += external_force * delta` and `move_and_slide()` run unconditionally (`02:245-247`).

In three of those four states `velocity` is never written, so the body coasts at whatever it last held. Concretely: the player dies at speed, enters `BLACKOUT`, and the invisible player body — which `00:581` designates "the save/checkpoint anchor" — slides away from the death site for the entire blackout. Doc 00 §12's harness stubs the player, so no check catches it.

**Fix:** Doc 00 §0.2 must supersede the controller *body*, not just the enum. Add explicit arms:
```gdscript
State.ATTACKING:                    _move(delta, Vector2.ZERO)   # drift, no steering
State.DRIVING:                      pass                          # vehicle owns transform
State.ZONE_TRANSITION, State.BLACKOUT, State.CUTSCENE:
    velocity = Vector2.ZERO
```
Add a §12 check: for every `State` value, one tick with nonzero starting velocity leaves displacement within that arm's declared expectation.

### B3 · The Scanner polls bodies; every scannable in the design is an Area — High ✓verified
`02:452` iterates `$ScanArea.get_overlapping_bodies()` filtering on group `scannable`; `03:379` makes `PropScannable` a **`scannable` Area2D**. `Area2D.get_overlapping_bodies()` returns `PhysicsBody2D` only and will never return an `Area2D`. `_best_target()` always returns `null`.

This is Chapter 1's tutorial beat — the first scan on `gnome_tracks`, the ring, the deliberate `UNKNOWN` weakness that `06:23-31` calls the chapter's thesis. All of it hangs off a call returning an empty array.

**Fix:** standardize the target, don't branch. Every scannable exposes a child `Area2D` on layer `scannable`, NPCs included; `_best_target()` iterates `get_overlapping_areas()` and resolves `a.owner`. Add a §11 check that a stub `PropScannable` and a stub scannable NPC both resolve. (Note `06:487` makes Norman "a `PropScannable` as well as an NPC" — a naive switch to `get_overlapping_areas()` without the child-Area rule breaks *that* target instead.)

### B4 · `scan` is a chord, which `InputMap` cannot express — High ✓verified
`02:305` binds `scan` to "**Hold J + `attack`**", and `02:483` calls `Input.is_action_pressed("scan")`. Godot's `InputMap` has no chord action. Separately, `J` is the `journal` toggle — holding it means the toggle already fired — and `00:430` rejects `ATTACK_REQUEST` outside `FREE`, so `attack` in `JOURNAL` is a dead input at priority 9. And a chord is not remappable, contradicting `02:308` in the same table.

The core combat loop as stated at `02:323` — *"do I risk reading now, or fight blind?"* — is gated on an input that cannot be bound.

**Fix:** make `scan` a first-class action. Keyboard `Left Shift` (inert in `JOURNAL`, since `run` does nothing at journal speed) or Right Mouse; gamepad RT. One row at `02:305`. Add a Doc 4 §7.3 rule that the remap screen rejects a binding colliding with `journal`.

### B5 · `Journal` has no owner, and its two readings collide in Godot 4's namespace — High ✓verified
`02:362` places `journal.gd` as a node beside the player (`on_owner_damaged()`, "the owner"). `04:153` reads `Journal.state` as a singleton. `00:147` reads `Journal.FUMBLE_DURATION` as a class constant. `06:314` calls it an autoload outright. Doc 00 §2.2's authoritative twelve-row autoload table (`00:92-103`) contains **no `Journal` row**.

In Godot 4 you cannot have both: an autoload named `Journal` and a `class_name Journal` occupy the same global identifier and the engine errors on the collision. So `Journal.FUMBLE_DURATION` and `Journal.state` cannot both be reachable from that name — and this is the ownership of the most-referenced gameplay object in the design.

**Fix (needs your call — see §6):** recommendation is a node on the player. Add a Doc 00 §2.2 row making `RuntimeDirector.player.journal` the one access path; move the three constants to a static `class_name JournalConst` since §2.4 needs them at parse time; rewrite `04:153` and `06:314` accordingly. `06:314`'s "becomes available" is separately impossible for an autoload — autoloads exist from boot.

### B6 · The HUD reads runtime health off `GameState`, which owns neither — High ✓verified
`04:150-151` does `GameState.health.current` and `GameState.stamina.current`. `GameState` (`00:889-906`) is a persistence autoload holding chapter, flags, inventory, entries, overrides, secrets, sigils, ciphers, checkpoint, playtime — nothing else. `Health` is `class_name Health extends Node` on the player (`02:794`, confirmed by `02:720`'s `target.has_node("Health")`). `recently_changed_item()` at `04:154` is defined nowhere.

Three of six clauses of `_should_show()` reference nonexistent members, so Doc 4 §11.3's exported contract "Health never hides while damaged" has no implementation path.

**Fix:** add to Doc 00 §14 — *"`GameState` holds only persisted fields. Live health, stamina, and item state belong to the player node and are reached through `RuntimeDirector.player`."* Rewrite `04:148-156` against `RuntimeDirector.player.health`/`.stamina`.

### B7 · `GameState` has three incompatible shapes across two documents — High
`00:891-906` declares fields *on* the autoload and `00:277` calls `new_game()` as a void mutator. `06:904` does `var s := GameState.new_game()` — a returned state object. `06:1005` uses a third accessor, `GameState.current()`. `serialize`/`deserialize` are never defined anywhere.

Doc 6's checks 4, 15, and 16 only compile under the second shape. Those three are the *only* automated guarantees that the player's Journal handwriting round-trips and that a New Game doesn't leak the last playthrough — the enforcement for `00:910-957`, the most carefully argued invariant in the set. Under Doc 00's shape they are uncompilable, and will be quietly deleted rather than fixed.

**Fix:** pick the singleton shape (Doc 00 wins — `00:1236` exports it). Define `class_name SaveData extends Resource` holding the §9.2 fields; `GameState` holds `var data: SaveData`; `new_game()`/`load_slot()` replace it. `serialize(SaveData) -> PackedByteArray` / `deserialize(...) -> SaveData` become real, testable, pure functions — and B8 gets a place to live.

### B8 · The save has no serialization format, and its types are hostile to every candidate — High
No document names the on-disk format. Both realistic choices break on this schema. **JSON** cannot hold `Vector2` (`00:902`), and every `StringName` key round-trips as `String` — so `journal_overrides.get(id, {})` with `id: StringName` (`00:934`) may miss on reload; Godot's `String`/`StringName` dictionary-key equivalence has shifted across 4.x point releases and is not something a twenty-chapter save format should depend on. **`store_var`** preserves types but is engine-version-fragile, which is exactly what the migration story at `00:970` is supposed to survive. And "runs migrations in sequence" names no registry and no signature.

`00:1240` asserts "Failure costs time, never progress." That is guaranteed in memory. Across a *quit*, it is guaranteed by a format that does not exist. Check 13 cannot be written until the format is chosen.

**Fix:** JSON, normalized at one boundary, with two rules stated in §9.2: (1) all dict keys are `String` on disk, converted with `StringName(k)` on load, in `deserialize` and nowhere else; (2) `Vector2` stores as `[x, y]`. Give migrations a shape: `const MIGRATIONS := { 1: _m1_to_2 }`, applied ascending. Adding this now costs nothing while `SAVE_VERSION == 1`.

Related, and non-negotiable: write to `user://slot0.tmp`, `close()`, then rename. Autosave-only means the save file *is* the player's progress with no manual backup — a crash mid-write must not corrupt slot 0.

### B9 · Nobody binds the grade material, and three copies run at once — High
`01:215` defines `Weirdness.bind(mat: ShaderMaterial)`. **No caller exists in any document.** `01:251` says the grade `ColorRect` lives on a single `CanvasLayer` for the game; `03:132` puts `WeirdnessGrade` in "the §2.1 layer stack every exterior zone scene must follow," and Doc 3 keeps 2–3 zones resident. So the world runs two or three full-screen `hint_screen_texture` `ColorRect`s stacked, each forcing its own backbuffer copy per frame, while `Weirdness` holds exactly one `_mat`.

**Fix:** delete row `+100 WeirdnessGrade` from Doc 3 §2.1's per-zone stack and §10's checklist. Move it to `world_root.tscn` (`00:295` already instantiates it and already owns the parallax for this reason). Add to `begin_session()`: `Weirdness.bind(world_root.get_node(^"WeirdnessGrade").material)`. Add a §12 check that exactly one node in the tree carries the weirdness shader.

### B10 · `Weirdness.level` is the target, not the applied value — High
Two different numbers wear the same name. `01:212` computes `level` as `maxf(_zone_floor, _event_level)` — instantaneous. `01:240` tweens `_apply`, which emits `level_changed` with the *smoothed* value. The shader and `AudioDirector._on_weirdness_changed` get the tweened value; anything reading the `level` **property** — `05:147`'s `set_rack_gain`, `05:310`'s whisper gain — gets the snapped target. During a zone crossfade the two actively fight: `05:172` tweens `set_rack_gain` (re-running `apply_weirdness` with the snapped level) while `_on_weirdness_changed` re-runs it with the tweened level, both writing `volume_db` in the same frame. Last writer wins, nondeterministically.

This attacks the headline decision directly. `README:43` promises "One float runs the supernatural." In practice there are two scales — a 1.2 s eased visual ramp and a step-function audio ramp — most visibly out of step at exactly the authored moments (`06:301`, `06:315`, and the Act 0→1 drop at `06:184` that the doc calls "the hook"). **Doc 6 §13 question 4 asks whether the coupling reads as one thing; the honest answer today is that they are already decoupled by accident, and the gate would be measuring an implementation bug as a design verdict.**

**Fix:** add `var applied: float`, set inside `_apply` (`01:245`), and make it the only value gameplay reads. Rename the computed property `target_level`. Point `05:147` and `05:310` at `Weirdness.applied`. Remove the double-write so exactly one path writes `volume_db`.

### B11 · Chapter 1's audio manifest is short two pieces, and one zone has no BGM at all — Medium
`06:850` says 12 stems (3 pieces × 4). The arithmetic is right, the list is wrong: Chapter 1 also reaches `bgm_menu` (`00:272`, `00:327`) and `bgm_attic` (`00:778`, and Doc 5 §4.1 specs it as the safety cue). That is 5 pieces / 20 stems. And **`int_living_room`, authored at `06:804`, appears in no BGM assignment in any document.**

`05:166`'s `set_zone` does `_library[bgm_id]` with no guard — an unregistered id is a missing-key index and the subsequent `piece.stems[stem]` dereferences null. **Hard crash on entering the living room, which sits on the mandatory path to the attic** (`06:231`).

**Fix:** correct `06:850` to 5 pieces / 20 stems; assign `int_living_room` → `bgm_shack`; add a guard-and-fail-loud at `05:160`; add to Doc 00 §12 that every registered `ZoneDef` has a non-empty `bgm_id` present in the library.

---

## 3. Target risk — the web export

Three findings are web-only or web-dominant. They share a property: **none of them are visible from a local dev server.** They appear on a real itch.io upload.

### B12 · Seamless streaming assumes a background thread the web export may not have — Critical (web)
`ResourceLoader.load_threaded_request` on HTML5 only runs off-thread when the build has threads enabled, which needs `SharedArrayBuffer`, which needs the host to send COOP/COEP headers. Without them Godot loads **synchronously on the main thread** and `_poll_loads()` (`03:278`) returns `THREAD_LOAD_LOADED` on the next frame, having stalled for the full load.

The entire architecture of Doc 3 §3 — `STREAM_MARGIN`, the `SeamBlocker` soft block, `SEAM_BLOCK_GRACE`, `SEAM_FALLBACK_REQUEST`, the `SeamLink`-vs-`GateTransition` distinction — exists to hide a load behind player movement. With no thread there is nothing to hide, and the seam crossing `06:269` calls "the single most important test in the slice" becomes a multi-hundred-millisecond freeze. `06:861`'s stated pivot (raise `STREAM_MARGIN`) does not address this at all — more margin only moves *when* the stall happens.

**Fix:** make it an explicit hard requirement, not an assumption. Doc 3 §0: *"Export target Web requires Thread Support enabled and a host serving COOP/COEP; on itch.io this is the SharedArrayBuffer project flag."* Add a boot `assert(OS.get_name() != "Web" or OS.has_feature("threads"))`. Add a Doc 6 §13 row: *"Does the seam hold on the actual itch.io build, not just in-editor?"* — with the pivot being *all Act I travel becomes gated*, which is already the fallback `06:861` names for the texture case.

### B13 · The placeholder bake is off by orders of magnitude, and blocks the main thread — Critical (web) / High (native)
`00:271` says "Blocking, **<1 s**"; `05:494` says "the whole score bakes in **well under a second**." Doc 5 §9 specifies 16 pieces × 4 stems + 23 boss stems = **87 stems**, each `22050 × 2.5 × 8` = 441,000 samples — **38.4 M iterations** of an interpreted GDScript loop doing `fposmod`, `sin`/`pow`, an envelope call, a clamp, and `encode_s16`. Plus ~120 SFX bakes. Memory: 87 × 441,000 × 2 bytes ≈ **77 MB resident PCM**, on top of Doc 3's 90 MB texture budget, inside a WASM heap that also has to fit the engine.

Native, this is tens of seconds of frozen window at every launch. On web, GDScript-in-WASM is slower again with no worker to move it to — an unresponsive tab, no canvas, no progress bar.

**The decision is right.** `05:416` correctly rejects `AudioStreamGenerator` for the underrun reason, and baking to `AudioStreamWAV` is correct. Only the cost model is wrong.

**Fix (either, or both):**
- **Cheapest:** bake **lazily on first `set_zone`/`play_sfx`** rather than at boot — Chapter 1 touches 5 pieces, not 87 — and drop placeholder `BARS` from 8 to 2 (a 5 s loop is enough to test crossfade and ducking; cuts time and memory 4×). Replace `00:271`'s claim with a measured budget and a stated fallback.
- **TB's version, and it is better:** run the same synth **once, offline**, as `tools/bake_placeholders.gd`, and commit the WAVs. Identical output, zero boot cost, zero underrun risk, and any single file can later be swapped for a real recording without touching code.

### B14 · Doc 1's own zone table contradicts its only stated web mitigation — High
`01:251` claims the grade `ColorRect` is `visible = false` below `level < 0.01`, "skipping the backbuffer copy entirely in the **~60% of gameplay that sits at zero weirdness**." Fifteen lines above, the zone table assigns `ambient_weirdness` per zone: woods 0.05, town 0.02, lake 0.05, mansion 0.15, dusk2dawn 0.45, basement 0.35, bunker 0.40, mindscape 0.75, weirdmageddon 1.00. **Exactly one entry is 0.00** — `pal_shack_interior`. `00:670`'s `activate_zone()` sets the floor on every zone entry, so `level` is above 0.01 essentially everywhere outside the Shack.

The optimization never fires, and the doc's confidence that web is affordable rests on a number its own next section contradicts.

**Fix:** raise the skip threshold to `level < 0.06` — covering woods/town/lake, the actual majority of Act I — and state it: *"Below 0.06 the grade is not perceptible; the shader is skipped and the zone floor applies as a flat `CanvasModulate` tint instead."* Or delete the 60% claim and budget the copy as always-on.

### B15 · The `user://` flush the web-save invariant depends on has no name — Medium
`00:885` says IndexedDB "requires an explicit flush. **Call it** once per write." Godot 4 exposes no GDScript-callable IndexedDB flush — it syncs IDBFS internally after file handles close. `OS.is_userfs_persistent()` reports whether persistence is available at all, a different question. A builder reading this will search for an API that doesn't exist or invent a `JavaScriptBridge` call.

**Fix:** *"Godot syncs `user://` to IndexedDB after the file handle closes; there is no explicit flush call. Guard against unavailability instead — check `OS.is_userfs_persistent()` at boot and, if false, surface a one-time warning that progress will not persist."*

---

## 4. Model corrections — where a stated justification is wrong

### B16 · Polled overlaps do not mean what §4.1 says — High
`00:354` claims `get_overlapping_areas()` at priority 100 "reflects the state of the world after everything moved this tick." In Godot 4, `Area2D`'s overlap lists are refreshed by the physics server during its own step, which runs **after** all `_physics_process` callbacks. The call returns the state as of the *previous* completed step, regardless of `process_physics_priority`. Priority 100 orders you relative to other scripts, not to the physics server.

Not fatal — the staleness is a uniform one frame, exactly like the queue's own accepted latency at `00:258`. But the *justification* is wrong and §4.3's whole rule derives from it. Concretely, check 5 ("a hitbox already active **in the frame** defeats a dodge request") is written against a false model: a hitbox arming via animation call-track this frame is invisible to the resolver this frame, so a same-tick dodge *will* win, contradicting `00:1169` and `00:459`. The harness stubs overlaps, so it passes; live play disagrees. **That is exactly Doc 6 §13 question 10's failure mode — green headless, red in play — and it will be blamed on the harness rather than the model.**

**Fix:** amend `00:354` to state the truth and keep the rule: *"`get_overlapping_areas()` reflects the world as of the last completed physics step — one tick stale, uniformly. The resolver therefore sees a hitbox on the tick after it arms. Accepted for the same reason §2.5's one-frame latency is."* Restate §4.3 as "a hit active as of last tick's physics step wins," and adjust check 5's wording to test the model that ships.

### B17 · `stretch_aspect = expand` makes the visible world a property of the display — Medium
`01:14` sets `stretch_aspect = expand`. Every MacBook display is 16:10 (1440×900, 2560×1600, 3024×1964), so the native target's viewport resolves to roughly 1920×1200 and the player sees 120 px more world above and below than the design is authored against. Three consequences, none addressed: (1) Doc 4's absolute pixel layout — dialogue box at `y = 732`, Journal at `x = 1056` — floats 168 px off the bottom; (2) Doc 3 sizes the world in 1920×1080 `CELL` units and requires `TileGround` sized to `grid_size * CELL` exactly, warning at `03:624` that "a short tilemap leaves a visible void at a seam" — on 16:10 the camera sees past the vertical edge; (3) it is a gameplay difference — scan range and off-screen spawns behave differently on 16:10 than on the 16:9 the web build mostly runs.

**Fix — needs your call (§6):** recommendation is `stretch_aspect = keep`. Identical visible world everywhere, Doc 4's absolute coordinates become correct, `CELL` becomes honest. If letterbox bars are unacceptable on a MacBook, keep `expand` and add two rules: Doc 4 §1.1 becomes anchor-relative with a documented safe area, and Doc 3 §10 requires 120 px `TileGround` overscan on every edge.

### B18 · 2× authoring and 1×-derived UVs are never reconciled — Medium
`01:23` authors all art at **2× reference scale** "imported at `scale = 0.5`". `01:414` computes `hose_texture_size()` "**at 1x reference scale**", and `01:401` notes `Polygon2D.uv` is in **texture pixels**, not normalized. `Polygon2D` has no import-time scale-0.5; the correct knob is `Polygon2D.texture_scale`, mentioned in no document. As written the UVs address the top-left quarter of every hose texture. Like B1, invisible through the entire Chapter 1 gate because the placeholder path has `texture == null`.

**Fix:** state the knob at `01:401`: *"With 2× authored art, set `Polygon2D.texture_scale = Vector2(0.5, 0.5)` so texture-pixel UVs computed at 1× address the full 2× image."* Extend the §11 assert to pin the two scales together by test rather than by paragraph.

### B19 · Doc 1 §6.1 Y-sorts the parts group; §6.2 assigns fixed z_index — Medium
`01:519` marks `Parts` "Y-sorted internally"; `01:523` titles §6.2 "**Fixed `z_index` per part**" with a table (`arm_far_hose` −20, `torso` 0, `arm_near_hose` +40) that assumes they are not. Two sorting systems on one node. A swinging arm whose polygon origin crosses the torso's Y re-sorts mid-animation — limb pop-through during `walk` and `run`, intermittent and hard to attribute.

**Fix:** delete "Y-sorted internally" from `01:519`. `Parts` is a plain `Node2D` with `y_sort_enabled = false`; §6.2's z_index table is sole authority within a character, `YSort` at zone level between them.

### B20 · Other confirmed defects, briefly
| Finding | Where | Fix |
|---|---|---|
| Player scene has two canonical paths — `res://actors/dipper.tscn` vs `res://rigs/dipper.tscn`. `preload()` of a missing path is a parse-time error in the booting autoload ✓verified | `00:287` vs `01:725` | One authority. Extend Doc 1 §10's tree with `runtime/`, `world/`, `chapters/`, `systems/`, `ui/` — all already referenced in file headers — or adopt §5's tree. Add to `00:17`'s ownership table: *"`res://` paths — Doc 1 §10."* |
| A new game must hardcode a world coordinate, which `03:25` forbids. Checkpoint carries raw `Vector2` and no marker; transitions carry `spawn_marker` and no position. `06:138` papers over it with `<sp_ch01_coldopen>` — a marker name in a `Vector2` field | `00:901`, `06:138` | Add `&"spawn_marker": StringName` to the checkpoint schema, make it authoritative, demote `position` to a fallback. `mount_initial(zone_id, marker, fallback_pos)` resolves after instantiation. |
| Interiors excluded from culling in prose only. `00:770` says "Never" culled; `03:300-307`'s `_cull_distant()` has no `is_interior` check — only `_stream_neighbors()` does. And **every** interior shares `grid_offset = (-1,-1)`, so all occupy an identical world rect | `00:770`, `03:300` | One line: `if id == current_zone or _defs[id].is_interior: continue`. Give each interior a distinct off-grid offset; extend Doc 3 §11's overlap loop to include them. Chapter 1 runs three interiors back to back (`06:231`) — a cull-during-transition here presents as a black screen with no error. |
| `seam_chapter` is a per-zone field carrying per-edge data. `is_seam_open` reconstructs an edge property as `maxi(a, b)`, which reproduces `03:70-78`'s table only because the adjacency happens to be a monotonic tree. One cycle-closing edge breaks it silently | `03:102`, `03:319` | `ZoneDef.neighbors` becomes `Array[SeamLink]` with `{to, seam_chapter}`. Add the missing test: assert `is_seam_open` matches the §1.3 table row for row. |
| Zone crossfade is not bar-aligned. `05:228` levies 96 BPM / D-minor on all 16 pieces and 64 stems to enable a crossfade that starts the incoming rack at sample 0 against an arbitrary outgoing bar position. `seconds_to_next_bar()` exists at `05:244` and is used only for boss cuts | `05:160-177` | Delay the incoming rack's `play()` by `seconds_to_next_bar()`, start the gain tween at the same instant; the outgoing tail covers the gap. Then §4.3's constraint earns its cost. The `bgm_shack → bgm_woods` blend is the first thing the player hears at the moment `06:269` calls the most important test in the slice. |
| Doc 4 declares no fixed-height text containers, then fixes one at 216 px inside a 300 px box. `resolve_mode` promotes to `BOX` above 90 chars with no upper bound; `06:244`'s 137-char Stan line wraps to 4 lines at `text_scale = 1.5` | `04:67`, `04:246`, `04:604` | Bottom-anchor the box from `y = 1032` with `custom_minimum_size.y = 300` and delete the fixed 216. This clips at the largest setting — the setting used by people who need it. |
| §6.2's publisher table names one intent publisher out of eleven. Nine of fifteen resolver priority rows have no defined source. Worst: with `PROCESS_MODE_PAUSABLE` on every gameplay node, `_unhandled_input` is suspended while paused, so whoever publishes `PAUSE_REQUEST` cannot publish the *un*pause | `00:616-628`, `00:1028` | Add rows naming a single `PlayerInput` node on the player as publisher for all nine. State the exception: *"Pausing is a `PAUSE_REQUEST`; unpausing is the pause menu's own affordance and does not go through the resolver, because the resolver is not running."* |
| Chapter 1 gates verbs by mutating the `InputMap` at runtime — the same map Doc 4 §7.3's remap screen rewrites and `00:271` loads from `user://settings.cfg` *before* `GameState`. A stale settings file can hand a New Game the Journal | `06:314`, `06:714` | Bind `journal`/`uv_light`/`scan` at boot like everything else; gate at the resolver. `00:432` already reads "only in a permitted player state" — extend it to require the inventory item. One condition, one place, testable in the §12 harness, survives remap and reload. |
| Four of Chapter 1's checks are tautologies over hand-maintained constants (`WRITTEN_FLAGS`, `GRANTS_VEHICLE`, `DIRECT_GAMESTATE_WRITES` — the last asserts `false` inside a loop over an empty array). Doc 00 gets the equivalents right as **static scans** (`00:1174`, `00:1194`) | `06:898`, `06:912`, `06:1024` | Make them the same static scan: regex `res://chapters/ch01/*.gd` for `GameState\.\w+\s*=` and for non-`ch01_`/`zone_`/`npc_`/`sys_` flag writes. A green tautology is worse than no test — it retires the concern. |
| A wrong identification grants a permanent real damage bonus. `06:493`'s Norman scan returns `entry_zombie` as "a partial match with a confidence warning" — a third scan outcome with no confidence field, no third UI state in Doc 4 §6.2, and no test — and `entry_zombie` ships verified, so `06:1019` hands out ×1.45 vs. zombies for a false positive | `06:493`, `02:486` | Cheapest version keeping the beat: don't unlock the entry. The scan returns *no* entry plus a Dipper line — "Closest thing in here is the zombie page. It's… close enough." The wrongness stays narrative. Deletes the third UI state, the confidence field, and the bonus, and keeps `06:495`'s "the game does not correct him" intact. |

### B21 · Bookkeeping
- `06:966` and `06:1004` are **both numbered check 15**; the sequence runs 11, 12, 15, 13, 14, 15, 16, 17, 18 — and `06:80`, `06:567`, `06:675`, `06:726` cite checks by number.
- Mabel's state count: `06:18` and `06:750` say six; the table at `06:452-458` has seven rows and `06:1051` says seven. `06:948`'s check 11 comment says "state 6 must instantiate exactly one new follower" — state 6 is Decoy, state 7 is Follower. Off-by-one in the guard against a companion leak.
- `README:20` marks chapters 06–25 "Not started" while `docs/06` is complete; the table omits Doc 00 entirely; `README:60-64` lists 5 test scripts where 7 exist.
- `00:120` defines `THREAT_LINGER := 4.0` commented "matches Doc 4's HUD idle-hide delay" — a duplicated constant, in the document whose §0.1 opens *"a duplicated constant is a constant that will drift."*
- `03:715-719`'s streaming-budget assert measures from zone **centres**, where the nearest other zone is 2880 px away — it always yields `near == 1` against a budget of 3 and cannot fail. The real risk is the corner at `(9600, 5400)` where three zones meet. Test rect corners.
- Undefined but load-bearing: `_mount_budget_ticks()` (`00:485`), `StemRack.playback_position()`/`.unload` (`05:174`), `ItemDB` (`06:981`), `Ch01Harness`/`RuntimeHarness`, `ZoneManager.mount_initial`/`.bind`/`.has_def`.
- `02:304` binds `item_cycle` to "Mouse wheel / Tab"; `04:434` requires "**Hold** `item_cycle`". A wheel cannot be held.
- `00:878` autosaves on every `activate_zone()` — every seam crossing, both directions — writing nothing positional the checkpoint autosave hasn't (Doc 3 §9 puts a checkpoint at every zone entrance). On web that is the most expensive write path in the game, for no gain.

---

## 5. TB — the laziness verdict

### The cut list (top of 29, ranked by complexity removed)

| Cut | Where | Replace with | Build it when |
|---|---|---|---|
| **The golf cart, both uses** — Act 0 cold-open chase and boss phase 2. Removes `DRIVING`, `golf_cart.gd`, the 4-layer engine audio, 2 scripted corridor scenes, 8 audio files, vehicle board/exit at priority 8, and Doc 00 §5.3 entirely | `06:109-190`, `06:532-571`, `00:573-595` | Cart is open on arrival at the Shack. Boss phase 2 is the same chase **on foot** — same corridor, same escort, same thrown-gnome hazards (`HeightBody` already covers them) | Chapter 9, where the cart is an earned verb |
| **Cross-zone respawn + `encounter` block + named phase-setup registry** — `ENCOUNTER_STATE_REQUEST`, `checkpoint.encounter`, setup registration, checks 24/25/28 | `00:1070-1124` | Cascades away with the cart — phase 2 on foot keeps the fight in one zone. If mid-boss resume is still wanted: store `boss_phase: int` on the checkpoint and let the boss node read it. One int, no registry | A boss fight genuinely spans two zones |
| **Threaded zone streaming** — `_stream_neighbors`, `_poll_loads`, `_cull_distant`, margins, `SeamBlocker`, `SEAM_FALLBACK_REQUEST`, grace wipe | `03:254-347` | Ch 1 has two exterior zones. `preload` both into `world_root`; `ZoneActivationVolume` still commits palette/BGM. **Also retires B12 for the slice** — ~15 lines instead of ~120 | A third zone can be resident (Ch 3, town) |
| **`ProcBaker` runtime synthesis** — `StemSpec`, 4 oscillators, envelope, blocking boot step | `05:412-509` | Same code run once as `tools/bake_placeholders.gd`; commit the WAVs. **This is the B13 fix** | Never — offline is strictly better |
| **`StemRack`'s four hand-synced players** and the "never `play()`/`stop()`, start on the same frame" rule the class exists to enforce | `05:123-148` | `AudioStreamSynchronized` + `set_sync_stream_volume(i, db)`. The engine guarantees the sync. Keep `stem_gain()` — 12 pure lines with a real test | Never |
| **`TextAccessibility.plain()`** RegEx tag-stripping | `04:380-400` | Don't bake decorative tags into the text. Doc 4 §4.4 already has a per-speaker **wrapper** column — apply at render time, skip when `text_effects_enabled` is off. `[color]`/`[pause]` stay in the string, untouched | Never |
| **`TransitionTeardown` as a `Resource`** — class file, `.tres`, 6 `@export`s, reflection test 21 | `00:721-752` | Flags in the `GATED_ZONE_REQUEST` payload `Dictionary`. Same no-`Callable` property, one fewer class. Exactly one instance exists project-wide | A second chapter declares one |
| **`on_complete_intent`** — enum field, 3-value legal set, validation, resolver branch, check 23 | `00:825-836` | The cutscene's completion handler enqueues `JOURNAL_TOGGLE_REQUEST`. That's what the field does, written at the one callsite using it | Three chapters want it |
| **Map tab + Zodiac tab** | `04:446-452` | Ch 1 discovers 2 zones and 2 sigils. A 1:640 map of two rectangles and a wheel of 8 silhouettes are both worse than nothing | 4+ zones / 4+ sigils (~Ch 5) |
| **Item radial** — 8 segments, hold-to-open | `04:434` | Ch 1 has one item usable in a fight (leaf blower, last 3 minutes). `item_cycle` covers it | 3+ combat items |
| **`Tokens` as an Autoload** | `00:94` | `class_name Tokens` with `const`s. GDScript resolves it globally; an Autoload buys nothing for constants | Never |
| **`CombatDirector`/`CutsceneDirector`/`TransitionDirector` as separate Autoloads** | `00:98-99` | Fold into `RuntimeDirector` — all three are resolver-adjacent state only the resolver commits. 12 autoloads → 8 | One exceeds ~150 lines |
| **24 portrait PNGs** | `04:525` | Render the live rig into a 240 px `SubViewport` with the Doc 1 §5.3 brow preset. The expression system exists; portraits become free | An artist wants better ones |
| **~40 key-glyph PNGs** | `04:524` | `InputMap.action_get_events()` + `OS.get_keycode_string()` in a `StyleBoxFlat`. Also stays correct after a rebind | Never |
| **`TimeRecorder`** | `02:678-754` | Nothing — unreferenced by Ch 1 | Chapter 7 |
| **Chapter Select + scratch slot** | `00:993-1006` | Nothing. `06` §11 already admits it can't be covered with one chapter | Chapter 3 |
| **Save migration runner** | `00:970` | Keep the version *field* and the refuse-a-newer-save check. Delete the chain — there are no old saves | First bump |

Also cut: `SkyController.set_backdrop()` (one `Parallax2D` sky for Act I); `Tube.hose_uv`/`hose_texture_size` and the §8.1 atlas spec (zero PNGs exist — but see B1/B18, the *geometry* fix still lands now); `HudVisibility` contextual fade (always show it in Ch 1); the grapple ownership flag `ch01_grapple_owner`; 6 unbuilt `ZoneDef` entries and 6 unused palettes; 5 of 8 TileSet terrain sets; `LIFT`/`ORBIT`/`INVERT` anomaly kinds; the Bill's-eye menu easter egg; 4 settings toggles with no Ch 1 surface.

### The keep list — load-bearing, do not cut
`RuntimeEvents`/`RuntimeDirector` single-commit resolver · `Weirdness` as one float driving shader + stems + buses + pitch · `activate_zone()` as sole writer of zone/palette/BGM, **interiors included** · three shapes per character with origin at ground contact · `DEPTH_RATIO` applied to velocity, never input · tick-counted durations, no `SceneTree` timers · flag namespacing + missing-keys-read-as-defaults · `journal_overrides` in the save instead of mutating `JournalEntry` · `rig_humanoid.tscn` as an inherited base · `Polygon2D` rendering `color` until a `texture` is assigned · autosave-only, slot 0 · `Cipher` as one static class + the non-cipher-alternative rule · `Settings` in `user://settings.cfg`, never in a save · `ZoneActivationVolume` 96 px inside the destination edge.

### Chapter 1's real audio number
`06:850` says 12 stems. The honest figure is **~80 of the 192 slots touched** — 20 BGM stems (5 pieces), 12 Journal SFX, ~14 combat/UI, 12 footsteps, 6 blips, 4 whispers, 4 ambience beds, 0 cart. But **distinct placeholder sources needed: ~12** — four oscillator recipes cover all 20 stems, footstep variants are pitch-shifts of one noise burst, UI cues are three envelopes.

> The 192-file manifest is a purchase order for a composer who does not exist. Fine as a document; it must not become a checklist anyone works through before the slice is playable.

### Test consolidation
7 files / ~90 asserts today. Roughly half compare two literals against each other — `walked.y < walked.x`, `SNAP_TIME < FADE_TIME`, `BAR_SECONDS == 2.5`, `ADVANCE_TO == 2`, `GRANTS_VEHICLE == false`, hose-UV bounds when no texture exists. **Cut those; keep what fails silently**: all cipher known-vectors, `FUMBLE_DURATION < IFRAME_DURATION`, `HeightBody` returns to ground, `snap_8`, capsule winding, hose weight partition-of-unity (**plus B1's new in-band assert**), pupil-in-sclera, stem gain curve endpoints, stutter determinism, `resolve_mode` combat downgrade, grid overlap/adjacency, resolver ordering checks 4/5/7/16/17/19, and Ch 1 checks 1/2/14/15/16. Result: **one `tests/test_all.gd`, ~40 asserts.**

### Where TB refuses to be lazy
**Save integrity** — `.tmp` + rename, refuse-a-newer-version, the web persistence guard, and the round-trip and new-game-leak tests. The bug those guard — a shared `JournalEntry` `.tres` carrying the last player's handwriting into New Game — is invisible and permanent. **Input validation at the trust boundary** — the resolver's re-verify at commit, monotonic chapter advance with `push_error`, player text through `_normalize()` and never near `Expression`, and the no-`Callable`-in-declarative-data rule (which survives the `TransitionTeardown` cut as a rule). **Accessibility** — not polish here: Mabel's `[rainbow]` runs in the first five minutes and the shader hits 0.55 aberration in the first minute. Ship `text_effects_enabled`, `text_scale`, `reduce_flashing` (and `reduce_flashing` must actually clamp `aberration_px`, not just disable strobes). Keep `TextAccessibility.render()` as the single choke point even after cutting the regex — the choke point was the valuable part. Every action stays an `InputMap` action so the remap screen is additive later. **The §0.1 thesis** — `06:887`'s check is the only test whose job is to stop a future session from "helpfully" filling in `entry_gnomes.weakness`. Keep it verbatim, comment included.

### The locked project tree — a genuine gap
**No tree is locked anywhere.** Two partial ones (`01:709`, `06:792`) plus paths scattered through code comments across all seven docs. That produces B20's dipper-path fork, three fuzzy buckets for gameplay code (`physics/`, `systems/`, `runtime/` — `Checkpoint` and `AnomalyField` are both world `Area2D`s in different folders), tests interleaved with shipping code, and no stated home for enemies, items, `.tres` instances, the `Theme`, fonts, or **audio assets** (`res://audio/` holds audio *scripts*, so the WAVs collide).

For a build running across many separate sessions, this is the omission that costs most — every session invents its own layout.

```
res://
├── autoload/       # exactly the scripts registered as Autoloads
│   weirdness.gd  settings.gd  game_state.gd  runtime_events.gd
│   runtime_director.gd        # absorbs Combat/Cutscene/Transition
│   zone_manager.gd  audio_director.gd  session_director.gd
├── core/           # class_name scripts, no scene, no Autoload
│   tokens.gd  tube.gd  eyes.gd  cipher.gd  stem_rack.gd  runtime_event.gd
│   palette.gd  character_proportions.gd  zone_def.gd
│   journal_entry.gd  journal_db.gd  save_data.gd
├── actors/
│   rig_humanoid.tscn/.gd      # inherited base — every character inherits this
│   eye_pair.tscn/.gd
│   player/  dipper.tscn  player_controller.gd  health.gd  stamina.gd
│            height_body.gd  interactor.gd  scanner.gd  journal.gd
│   npc/     mabel.tscn  stan.tscn  soos.tscn  wendy.tscn
│            npc_template.tscn  companion_follower.gd
│   enemy/   gnome.tscn  gnomonster.tscn
├── world/
│   world_root.tscn            # owns parallax AND the single WeirdnessGrade (B9)
│   zones/                     # one .tscn per BUILT zone, stem == ZoneDef.id
│     z_shack_ext  z_woods_south  int_giftshop  int_living_room  int_attic
│   nodes/                     # the zone-authoring vocabulary
│     zone_boundary.gd  door_boundary.gd  zone_activation_volume.gd
│     checkpoint.gd  secret_trigger.gd  anomaly_field.gd
│     overhead_fade.gd  palette_region.gd  prop_interactable.gd  prop_scannable.gd
│   tilesets/  gf_terrain.tres
├── ui/
│   hud/       hud.tscn  health_pips.gd  stamina_ribbon.gd  item_slot.gd
│   journal/   journal.tscn  tab_entries.gd  tab_items.gd  tab_ciphers.gd
│   dialogue/  dialogue_box.tscn  speech_bubble.tscn  typewriter.gd
│              stutter.gd  rich_text_cipher.gd  text_accessibility.gd
│   menus/     main_menu.tscn  pause_menu.tscn  settings_menu.tscn  chapter_card.tscn
│   gf_theme.tres
├── chapters/ch01/  ch01_director.gd  ch01_dialogue.tres  ch01_boss.gd
├── resources/      # authored .tres, one subdir per class it instances
│   palettes/  proportions/  zones/  journal/
├── assets/         # supplied art & audio. No code, ever.
│   characters/<name>/  fx/  props/  tiles/  ui/  fonts/
│   audio/ bgm/ sfx/ blips/        # placeholder WAVs live here too
├── shaders/  weirdness.gdshader  uv_reveal.gdshader
└── tests/    test_all.gd  harness.gd

tools/              # outside res:// — never shipped, never run at boot
└── bake_placeholders.gd
```

**Naming:** `snake_case.gd/.tscn/.tres` for files; `PascalCase` for `class_name` and Autoload names. A scene and its root script share a stem. Zone triple-lock — scene stem == `.tres` stem == `ZoneDef.id`, asserted in `test_all.gd`. Id prefixes stay exactly as the docs already set them (`z_`, `int_`, `sp_`, `cp_`, `bgm_`, `entry_`, `pal_`, `prop_`/`npc_`/`sigil_`/`uv_`); save-flag prefixes stay `chNN_`/`zone_`/`sys_`/`npc_`. Add `tests/` to the export filter on day one.

**Placement rule:** *a script goes where the thing it drives lives* — beside its scene if it has one, in `core/` if it's a `class_name` with no scene, in `autoload/` if registered as one. Authored `.tres` → `resources/<class>/`. Anything an artist or composer supplies → `assets/`. Anything existing for exactly one chapter → `chapters/chNN/`, and nothing outside that folder may name it. **Create no folder before its first file.**

---

## 6. The most expensive-to-reverse decision

**`Skeleton2D` cutout rigs with weight-blended, single-`Polygon2D`, one-texture-per-limb tube limbs** — `01:16`, `01:369-397`, `README:34`.

Not the resolver, not the live-world Journal, not the `Weirdness` float, not the web target. The obvious candidates are all cheaper than they look:

- **The resolver** touches everything, so it *feels* expensive. It is the best decision in the set and its shape should not change a line. `00:200-258`'s reasoning about idle-frame input flush is the sharpest technical paragraph in the project.
- **The live-world Journal** reads as expensive because `06:860` says so — "cheap now, catastrophic at Ch 10." That is backwards. Reversing it is a *deletion*: drop the fumble, the boundary blocker, the camera offset, the 118 px/s state. Deletions stay cheap.
- **`Weirdness` as one float** is two floats and two curves from being decoupled — and B10 shows it already is, by accident.
- **The web target** is cheap to drop: you stop exporting. The constraints it imposed are worth keeping regardless.
- **The rig** is the one with no cheap exit, because its cost is not in code — it is in deliverables produced by someone else. `01:667-703` is an asset manifest: sixteen parts per character, limbs as four continuous hose textures drawn straight and unbent, delivered untrimmed at precise dimensions with 1 px margins and pivots at the proximal joint. `01:733` multiplies it across "all 30+ characters." Reversing to sprite sheets or segmented limbs invalidates every PNG drawn, every keyframe in Doc 1 §7, the §8.1 atlas pipeline, and the §9.3 manifest — after an artist has been working to that spec for months.

**Verdict: the decision is right, and the specification of it is broken.** Cutout rigging is correct here — it is the only approach where a solo dev gets 8-direction locomotion, a `talk` layer, and per-character retargeting without drawing thousands of frames, and `01:647`'s texture-null placeholder path is genuinely excellent.

**The risky assumption is that two bones and a 24% blend band produce a rubber hose.** B1 shows that assumption is currently false *by construction*. Even after B1's fix adds shaft subdivision, a 2-bone linear-blend skin with no volume preservation will pinch at sharp bends, and the fixed ear-clip triangulation will fold past roughly 90° of elbow.

**What makes this the dangerous one is that the Chapter 1 gate cannot see it.** `06:836` — "The slice is fully playable with zero supplied assets" — is exactly what hides it. §13 question 9 asks "Is placeholder-everything actually playable?", which is the wrong question. The right one is never asked.

**Fallback if the assumption is false:** three bones per limb (`b_arm_l_upper → b_arm_l_mid → b_arm_l_fore`) with two overlapping blend bands. Still one polygon, one texture, authored straight, same `hose_texture_size`, same manifest — **the artist's deliverables do not change at all.** It is a rig-file change plus `hose_weights` returning `Vector3`, and it is the standard fix for candy-wrapper collapse.

**Do this now, before any art exists:** add an eleventh gate question to Doc 6 §13 — *"Does a real texture survive the hose bend?"* Author **one** limb texture: a straight vertical bar with three horizontal stripes. Assign it to Dipper's `arm_hose_l`. Play `walk` and `run`. If the stripes stay evenly spaced through the elbow, two bones hold. If they pinch or the fill folds, take the three-bone fallback immediately, while exactly one texture exists.

That single striped PNG is the cheapest insurance in this audit.

---

## 7. Complexity ratings

Conceptual = how hard the idea is to hold correctly. Integration = how many systems must agree. Unknown = what cannot be resolved before it runs. **Dev effort deliberately excluded.**

| System | Conceptual | Integration | Unknown | Where the unknowns actually are |
|---|---|---|---|---|
| Runtime resolver | High | **High** | Low | Well specified and self-consistent. Its one risk (B16) is knowable today by reading engine source, not by running. |
| **Character rigs & hose limbs** | Medium | Low | **High** | **The real unknowns live here.** Low integration is what makes it deceptive — nothing else breaks when it fails, so nothing else warns you. |
| Weirdness pipeline | Low | **High** | Medium | Concept is one float; integration touches shader, three buses, stem racks, zone activation, every chapter. Unknown: whether the coupling reads as intentional, and the true web backbuffer cost once B14 is corrected. |
| **Zone streaming & seams** | Medium | High | **High** | Web threading (B12) is unresolvable from the docs and invalidates the central premise on one of two targets. |
| Journal system | Medium | **High** | Medium | Conceptually clear. The unknown is behavioural, not technical — does anyone read mid-fight. |
| **Save & persistence** | Medium | High | **High** | No format chosen, three API shapes, no migration registry, a web flush that doesn't exist. Lowest-specified system relative to its lifetime. Nothing here is hard; everything here is undecided. |
| Audio engine | Medium | Medium | Medium | Vertical stems and bake-don't-stream are sound. Unknowns are bake cost (measurable) and crossfade phase (designable). |
| UI / HUD / dialogue | Low | Medium | Low | Ownership errors and internal contradictions, not hard problems. |
| Combat | Low | Medium | Medium | Deliberately thin. Unknown is whether a boss without a health bar reads as fair — design question. |
| Chapter 1 as a slice | Medium | **High** | Medium | Highest integration here by construction; that is its job and it does it. Its unknown is that the coverage matrix has a blind spot exactly where the least-reversible decision lives. |

**The unknowns concentrate in three places** — the hose rig (invisible until art lands), web streaming and bake behaviour (invisible until you export to itch, not to a local server), and the save format (invisible until the first schema change, ~Chapter 3). All three share the property that **Chapter 1's gate as currently written passes without touching them.**

---

## 8. Open questions — these need your answer

1. **Is the web export negotiable?** Three of the four highest-severity findings (B12, B13, B14) are web-dominant. If web is nice-to-have, say so and cut it — cheapest large simplification available, and it retires B12 entirely. If it is a requirement, the itch.io SharedArrayBuffer flag must be verified on a real upload before Chapter 2, not after.
2. **Will anyone other than you draw the art?** If yes, §6's striped-texture test is urgent and B18's `texture_scale` reconciliation must be pinned before the `01:667` manifest is handed over. If you're drawing it yourself and iteratively, the risk drops sharply — you'll see the pinch on the first limb.
3. **`stretch_aspect`: are letterbox bars acceptable on a MacBook?** B17 has no correct answer without this.
4. **Does the Chapter 1 phase-2 chase have to cross a zone boundary?** `06:571` argues the harder version is right for a gate, and the reasoning is sound. But it is the sole reason Chapter 1 needs cross-zone respawn, the `encounter` block, vehicle-crosses-seam, and escort-NPC-survives-transition — four mechanisms stacked on the slice's least-recoverable beat. TB's cut #1 removes all four by putting phase 2 on foot. Worth the coverage, or not?
5. **How much of `seam_chapter`/`SeamLink` is real?** Chapter 1 runs the streamed model on day one, so "hub-and-spoke → semi-open by Act IV" (`README:36`) is not what's being built — streaming is load-bearing from the first playable minute. Is dual `GateTransition`/`SeamLink` authoring on every boundary a requirement, or insurance for a progression that no longer exists?
6. **Chapters 2–25: outline, or intent?** The flag namespace, `SAVE_VERSION` migration, the sigil spread, the four-cipher progression, `boss_bill`'s seven stems, and Chapter Select are all priced against twenty chapters. If the honest scope is "Chapter 1, then reassess," a meaningful amount of Doc 00 §9 and Doc 3 §6 is speculative.
7. **`Journal` ownership (B5) is your call.** Recommendation is a node on the player. `06:314`'s "becomes available" reads like you were thinking singleton — if so the fix changes shape: an autoload holding state with the constants moved out, and `02:362`'s `on_owner_damaged()` needs a different owner reference.

---

## 9. Two closing observations

**The Chapter 1 gate is a genuinely good idea, and it currently cannot see the thing it most needs to see.** Doc 6 §11's coverage matrix is the most rigorous artifact in the project and §13's ten questions with stated pivots are exactly right. But every system in that matrix is exercised through placeholders, and the two least-reversible decisions — the hose rig and the web export — both fail *only* under conditions the slice deliberately avoids: real textures, and a real itch.io upload. **Add those two rows.** They are the cheapest changes in this report and they protect the most.

**The supersession table at `00:37-50` is a promise with no mechanism.** Doc 00 declares it wins over Docs 1–5 and names each override. But Docs 1–5 still contain the superseded text, and B2 is the pattern's real failure — Doc 00 superseded an *enum*, and the `match` statement consuming it was never updated, in a document already marked superseded and therefore looking handled. A builder reading Doc 2 §3.3 top to bottom sees a superseded-notice comment above a controller body that is still wrong. **Either edit Docs 1–5 in place and keep the table as a changelog, or accept that anything Doc 00 supersedes must be quoted in full in Doc 00 rather than referenced.** The current halfway position is where the next three of these will hide.

---

## 10. Coverage not obtained

This audit ran ARCH and TB only. Not reviewed, and worth knowing you're going without:

- **DG (design-girl)** — the one persona whose lane overlaps a real finding here. B17 (`stretch_aspect`), B19 (limb pop-through), and Doc 4's text-scale clipping (B20) all have a visual-design read that no technical persona is qualified to give.
- **PH (product-head)** — whether "playable first slice" is the right unit, and whether Chapter 1's scope is the right first chapter.
- **SM (security-master)** — low stakes for a local single-player game. One item already caught in passing: keep user saves as JSON, never `.tres` from `user://`, which is a script-execution surface.
- **DO, LB, FB, COO** — not meaningfully applicable to a personal non-commercial project, except LB on the IP-fidelity posture in `foundation.md:3`, which is a deliberate accepted risk for personal use and stays that way as long as it is never distributed.

---

## 11. Applied changes — 2026-07-28

Decisions taken on §8's blocking questions:

| Question | Answer | What it changed |
|---|---|---|
| Web export | **Best-effort. macOS native is the primary target.** | Doc 1 §0 states the precedence; every web caveat is now marked **(web)** and is a note, not a blocker. Streaming keeps its thread requirement with a documented gated-travel fallback. |
| `Journal` ownership | **Node on the player**, `RuntimeDirector.player.journal` | Timings moved to a static `JournalConst`; Doc 00 §2.2 states why the autoload table must not gain a `Journal` row. |
| Canvas aspect | **`stretch_aspect = keep`** | True 16:9 everywhere, so `CELL` and Doc 4's absolute coordinates are honest. Doc 1 §0 carries the reasoning. |
| Golf cart in Ch 1 | **Stays — the coverage is the point** | Cross-zone respawn, the `encounter` block, vehicle-crosses-seam, and escort-survives-transition all remain in the slice. TB's cut #1 and #2 were **not** applied. |

### Fixed

**Doc 00** — supersession table now records that every row was applied *at source*, plus seven new rows · `Journal`/`Health`/`Stamina` ownership stated · boot no longer bakes audio and no longer gates verbs via `InputMap` · `Weirdness.bind()` now has a caller in `begin_session()` · polled-overlap model corrected to "last completed physics step" with §4.3 restated against it · `PlayerInput` added to §6.2 as the publisher for all nine orphaned intents, plus the unpause carve-out · `Weirdness` declared presentation state with no resolver requirement · save rewritten around a `SaveData` value type with JSON + a stated normalization rule, atomic temp-and-rename writes, and `spawn_marker` as the authoritative checkpoint position · `THREAT_LINGER` de-duplicated · ten new §12 checks (31–40) · nine new §14 contracts (29–37).

**Doc 01** — `Tube.capsule` gained `shaft_segs`, so the blend band actually contains vertices; §11 asserts it and the vertex count moved 18 → 28 · `texture_scale = 0.5` reconciliation for 2× art stated · grade skip threshold 0.01 → 0.06 with the honest reason · single-grade-on-`world_root` rule · `Weirdness` split into `target_level` and `applied` with one writer · `Parts` Y-sort contradiction removed · **§10 rewritten as the locked project tree**, naming conventions, and placement rule — now the sole authority for every `res://` path.

**Doc 02** — `match` gained arms for all four of Doc 00's new states, with no silent default · `Scanner` polls `get_overlapping_areas()` and resolves `area.owner` · `scan` is a first-class action on Left Shift / RT, not a chord · `item_radial` split from `item_cycle` · `JournalConst` introduced · verb-gating-at-the-resolver rule stated.

**Doc 03** — interiors excluded from culling in code, not just prose, and given distinct off-grid offsets · `seam_chapter` moved onto a new `SeamLink` edge resource · `WeirdnessGrade` removed from the per-zone layer stack · streaming-budget test samples rect corners instead of centres · thread requirement and gated fallback documented · `PaletteRegion` scope narrowed to its own subtree · 6-screen zones noted in the memory budget.

**Doc 04** — HUD reads `RuntimeDirector.player`, not `GameState`; `recently_changed_item` replaced with a real timestamp · story box bottom-anchored and grows, so 1.5× text scale cannot clip · radial rebound to `item_radial`.

**Doc 05** — placeholder bake moved offline to `tools/bake_placeholders.gd`, `BARS` 8 → 2, false "<1 s" claim deleted · `set_zone` guards an unregistered `bgm_id` · crossfade delayed to the next bar line so §4.3's tempo constraint earns its cost · `set_rack_gain` no longer double-writes `volume_db` · all reads point at `Weirdness.applied`.

**Doc 06** — checkpoint names a marker, not a coordinate · Norman's scan returns no entry, so a wrong identification cannot grant +45% · audio corrected to 5 pieces / 20 stems with `int_living_room` assigned · checks renumbered 1–19 with no duplicates · three tautological checks replaced with static scans · `GameState` API unified on `GameState.data` · Mabel's state count reconciled to seven · Journal acquisition gates on inventory, not a runtime binding · footprint trail moved off `SecretTrigger` · **two new gate rows: the striped-texture hose test, and a real itch.io build check.**

**README** — Doc 00 and Doc 06 added to the table, both marked complete · stack table corrected · one test command instead of five.

**Repo-wide** — 70 `res://` path references normalized to Doc 1 §10's tree, resolving the `dipper.tscn` fork and the tests-beside-shipping-code problem.

### Not applied — still open

- **TB's cut list (§5).** Cuts #1 and #2 are ruled out by the golf-cart decision. The rest — `TransitionTeardown` as a resource, `on_complete_intent`, the Map and Zodiac tabs, `TimeRecorder`, Chapter Select, folding three directors into `RuntimeDirector`, `Tokens` as an autoload — are live options, none blocking.
- **§8 questions 2, 5, 6** — who draws the art, how much of `SeamLink` is real, and whether chapters 2–25 are an outline or an intent.
- **The striped-texture test** (Doc 6 §13 Q11) is specified but not yet run. It is the cheapest insurance in this audit and wants doing before any character is rigged.
