# Build tracker — Chapter 1 test flight

**Goal: a functional game.** Placeholders throughout — flat `Polygon2D` fills, baked procedural audio, no PNGs. Real art and audio replace placeholders later through the same code path, which is the whole reason the tokens layer exists.

**Build order is priority order. Do not cherry-pick.** Every row depends only on rows above it. The bottom two sections — **Deferred** and **Refinements** — are the lowest priority in the project and are not part of the test flight. Nothing in them gets built until §6's gate has been played.

---

## How a session uses this file

1. Read this tracker. Find the **first row that is not Done** and whose dependencies are Done. That is the task.
2. Set it to **WIP**.
3. Build it to the spec in the linked doc section. **Locked decisions are locked** — if reality makes one impossible, mark the row **Blocked**, write why, and stop rather than silently swapping it.
4. Write its **Verify** column into `res://tests/test_all.gd` and make it pass. A row is not Done until its check runs green.
5. Set it **Done**, fill Notes, commit referencing the row id.
6. If budget remains, go to 1.

**Status:** `⬜ Todo` · `🔨 WIP` · `✅ Done` · `🚫 Blocked` · `⏸ Deferred`

**One test command:**

```bash
godot --headless --script res://tests/test_all.gd
```

Checks marked **(scene)** need a real tree and run from `res://tests/scene_harness.tscn`; the rest run against the pure harness. Both are entered from `test_all.gd`.

**Check references:** `00§12·n` = Doc 00 §12 check n · `06§14·n` = Doc 06 §14 check n · `01§11`, `02§11`, `03§11`, `04§10`, `05§10` = that doc's validation section.

---

## Definition of done for the test flight

The slice is functional when all of these are true, and no earlier:

- `test_all.gd` exits green.
- New Game → Act 0 → chapter card → Acts 1–5 → chapter advance, playable start to finish without a crash or a soft-lock.
- Quit mid-chapter, relaunch, Continue resumes at the last checkpoint with flags, inventory, entries, and the player's Journal handwriting intact.
- Dying at any point costs time only — never a flag, an item, or an entry.
- Every visual is a flat palette fill and every sound is a baked placeholder. **That is success, not a gap.**

---

## P0 · Runtime spine

Nothing is playable until this is done, and everything else assumes it. Build it first even though there is nothing to look at.

| # | Task | Spec | Verify | Status | Notes |
|---|---|---|---|---|---|
| 0.1 | Godot 4.x project; `project.godot`; macOS export preset; `stretch_mode = canvas_items`, `stretch_aspect = keep`, 1920×1080 | 01§0 | Window opens at true 16:9 on a 16:10 panel — letterboxed, not stretched | ✅ | Godot 4.7.1. Settings asserted in `test_all.gd`. **The letterbox observation is carried to 1.1** — it needs something on screen, and no scene exists yet |
| 0.2 | Folder tree exactly per the locked layout; `tests/` and `tools/` added to the export filter | 01§10 | Every directory in the tree exists or is absent-by-design; no file outside it | ✅ | Placement rule is the tie-breaker for anything new. Structure walk in `test_all.gd` enforces it. **Repo root is the project root**, so `tools/` sits inside `res://` and the export `exclude_filter` — not the path — is what keeps it unshipped |
| 0.3 | `tests/test_all.gd` + `harness.gd` skeleton that runs and prints | 00§12 | `godot --headless --script res://tests/test_all.gd` exits 0 | ✅ | Every later row appends here. `harness.gd` uses recorded `expect()`, not `assert()` — release builds strip asserts. `scene_harness.tscn` unbuilt until a row needs a tree |
| 0.4 | `Tokens` (constants), `Palette`, `CharacterProportions` resources | 01§1, §3 | Palette `.tres` loads; proportion segments sum to declared height | ⬜ | |
| 0.5 | `Tube.capsule` / `hose_weights`, `Eyes.geometry` / `pupil_offset` | 01§4, §5 | `01§11` — capsule winding + bounds, **blend band contains ≥4 vertices**, weights partition to 1.0, pupil never escapes sclera | ⬜ | The blend-band assert is the one that matters; see AUDIT B1 |
| 0.6 | `Weirdness` autoload: `target_level` / `applied`, `bind()`, `pulse`/`release`/`set_zone_floor`, weirdness shader | 01§2 | `00§12·36` — `level_changed` carries `applied`; a `pulse` mid-tween leaves one writer of any driven value | ⬜ | |
| 0.7 | `Settings` autoload → `user://settings.cfg`; three toggles: `text_effects_enabled`, `text_scale`, `reduce_flashing` | 04§5.1 | Settings survive New Game; `reduce_flashing` clamps the shader's `aberration_px`, not just strobes | ⬜ | Accessibility is not deferrable |
| 0.8 | `SaveData` + `GameState.data`; JSON `serialize`/`deserialize` with `StringName`-key and `Vector2` normalization; atomic temp-then-rename write | 00§9.2 | `00§12·32` round-trips every field **including key types**; `00§12·33` kill mid-write leaves slot 0 loadable | ⬜ | No manual save UI, ever |
| 0.9 | `RuntimeEvent` + `RuntimeEvents` double-buffered queue with `swap`/`enqueue`/`defer`/`take` | 00§2.5 | `00§12·16` — an event published outside the physics pass survives to the next resolve, seen exactly once | ⬜ | The input-loss regression test |
| 0.10 | `RuntimeDirector`: `process_physics_priority = 100`, `_resolve()` priority ladder, `_resolve_locked()`, tick durations | 00§4 | `00§12·15` priority is above every gameplay node; `00§12·4` damage cancels interact; `00§12·17` seamless takes no lock; `00§12·20` control releases on `_lock_ticks == 0` with tweens stubbed | ⬜ | Pure function of (queue, state) — keep it that way |
| 0.11 | `CombatDirector`, `CutsceneDirector`, `TransitionDirector` | 00§2.3, §7.4, §8 | `threat_active` lingers after aggro empties; `boss_phase` is the sole stem gate | ⬜ | Folding these into `RuntimeDirector` is a live option — see Deferred D18 |
| 0.12 | `SessionDirector`: boot sequence, `begin_session()`, `end_session()`, `Weirdness.bind()` on `world_root` | 00§3 | `00§12·12` `end_session()` leaves no freed-node reference and a re-`begin` is playable; `00§12·35` exactly one node carries the weirdness shader | ⬜ | Player instantiates **before** the first zone |

---

## P1 · The player

| # | Task | Spec | Verify | Status | Notes |
|---|---|---|---|---|---|
| 1.1 | `rig_humanoid.tscn` — `Skeleton2D`, bones, `Polygon2D` parts, anchors, `Parts` with `y_sort_enabled = false` | 01§6 | Rig instantiates; §6.2 z_index table is the only sort inside a character | ⬜ | |
| 1.2 | 8 animations: idle, walk, run, hurt, dodge, attack, journal_raise, talk | 01§7 | `journal_raise` gates at exactly 0.42 s | ⬜ | `journal_settle`/surprise/fall/land are Deferred |
| 1.3 | `dipper.tscn` inheriting the rig, binding `prop_dipper.tres` | 01§10 | Loads at `res://actors/player/dipper.tscn` — the path `SessionDirector` preloads | ⬜ | |
| 1.4 | `PlayerController`: 10-state enum, **an arm for every state**, `DEPTH_RATIO` on velocity not input, `_snap_8` | 02§3, 00§5.1 | `00§12·31` — every state, one tick at nonzero velocity, displacement matches that arm; `BLACKOUT`/`ZONE_TRANSITION` exactly zero. `02§11` `snap_8`, walked.y < walked.x | ⬜ | AUDIT B2 — no silent default |
| 1.5 | `HeightBody`, `Stamina`, `Health` (pips, i-frames as tick counts) | 02§6, §7 | `02§11` height body returns to ground; `FUMBLE_DURATION < IFRAME_DURATION` | ⬜ | |
| 1.6 | `PlayerInput` — the one publisher for all nine intents | 00§6.2 | Every intent type in the enum has a publisher; unpause is the menu's own affordance | ⬜ | |
| 1.7 | `InputMap` — every action bound at boot **including unearned verbs** | 02§3.5 | `00§12·40` `journal`, `uv_light`, `scan` all resolve before they are earned | ⬜ | Verbs gate at the resolver, never by unbinding |
| 1.8 | `Interactor` — best target by range and facing, publishes `INTERACT_REQUEST` | 02§8 | `00§12·4` damage + `E` same tick: health drops, `interact()` never called | ⬜ | Re-verify range at commit |
| 1.9 | `JournalConst` + `Journal` node — state machine, 0.42/0.30/0.80, fumble, `blocks_zone_travel()` | 02§5, 00§5.2 | `00§12·3` blocker holds while not `CLOSED`; `00§12·8` cutscene closes once and never reopens | ⬜ | Node on the player — **never** an autoload |
| 1.10 | `Scanner` — `get_overlapping_areas()`, `area.owner`, cone + LOS, 1.4 s | 02§5.4 | `00§12·38` a stub `PropScannable` **and** a stub scannable NPC both resolve; a bare body resolves to null | ⬜ | AUDIT B3 |
| 1.11 | `Cipher` static class — caesar, atbash, a1z26, vigenère + `_normalize` | 02§5.6 | `02§11` all known vectors; vigenère advances its key only on alphabetic chars | ⬜ | Never lazy here — a wrong cipher is an unsolvable puzzle |
| 1.12 | `JournalEntry` (immutable) + `JournalDB` + `journal_overrides` | 00§9.2.1 | `00§12·26` override round-trips; `00§12·27` New Game leaves none behind | ⬜ | The shared-`.tres` leak is silent and permanent |

---

## P2 · The world

| # | Task | Spec | Verify | Status | Notes |
|---|---|---|---|---|---|
| 2.1 | `ZoneDef` + `SeamLink` resources; zone registry | 03§1.4 | `00§12·37` `is_seam_open()` reproduces the §1.3 adjacency table row for row | ⬜ | `seam_chapter` lives on the edge |
| 2.2 | `world_root.tscn` — parallax + **the single** `WeirdnessGrade` | 03§2, 01§2.1 | `00§12·35` (also covers 0.12) | ⬜ | Not in any zone scene |
| 2.3 | `ZoneManager` — `activate_zone()` as the sole commit path, `mount_initial(zone, marker, fallback)` | 03§3.2, 00§7.2 | `00§12·2` one `activate_zone()` per crossing updates zone + palette + BGM together; `00§12·1` preload does **not** set BGM | ⬜ | |
| 2.4 | 5 zone scenes: `z_shack_ext`, `z_woods_south`, `int_giftshop`, `int_living_room`, `int_attic` — full layer stack, tilemaps sized to `grid_size × CELL`, spawn markers | 03§10 | `03§11` no rect overlap (**interiors included**), every claimed neighbour shares an edge, Shack→Town walk within window; `00§12·34` **every zone has a registered `bgm_id`** | ⬜ | `int_living_room` → `bgm_shack`. Missing it is a hard crash |
| 2.5 | `ZoneBoundary`, `ZoneActivationVolume`, `SeamBlocker`, `DoorBoundary` | 03§3, 00§7 | `00§12·17` seamless takes no lock and does not shield a same-tick hit; gated locks and ends the tick | ⬜ | Activation is 96 px inside the destination |
| 2.6 | Streaming + culling | 03§3.3 | `00§12·39` `_cull_distant()` never frees an interior; no two interiors share a rect | ⬜ | Preloading both Act I exteriors is acceptable — see Deferred D3 |
| 2.7 | `Checkpoint` node + respawn sequence + blackout | 00§11 | `00§12·14` cross-zone respawn restores health and clears aggro; `00§12·19` a blackout always reaches `FREE` and never deadlocks | ⬜ | Respawn reads memory, never disk |
| 2.8 | `TransitionTeardown` handling (as an event payload) | 00§7.4.1 | `00§12·22` applies at step 5a, never while a trigger is armed; **no `Callable` in declarative data** | ⬜ | Payload dict, not a Resource — Deferred D1 |
| 2.9 | `SecretTrigger`, `AnomalyField` (`PUSH`), `OverheadFade`, `PaletteRegion`, `PropInteractable`, `PropScannable` | 02§6, 03§4, §6 | `00§12·6` destination triggers do not commit during a gated transition; a preloaded neighbour changes no screen-wide colour | ⬜ | |

---

## P3 · Audio & UI, minimum viable

| # | Task | Spec | Verify | Status | Notes |
|---|---|---|---|---|---|
| 3.1 | `tools/bake_placeholders.gd`; run once; commit WAVs to `assets/audio/` | 05§7 | Baked PCM is the right length and **not silent**; boot loads files and synthesises nothing | ⬜ | ~12 distinct sources cover Chapter 1 |
| 3.2 | Bus layout, `StemRack`, `stem_gain` curves, `AudioDirector` | 05§1, §2 | `05§10` gain curve endpoints, `base ≥ 0.5`, `to_db(0) ≤ -80` | ⬜ | Reads `Weirdness.applied` |
| 3.3 | Zone crossfade, bar-aligned; ducking table | 05§3, §8 | Incoming rack starts on a bar line from an arbitrary outgoing position | ⬜ | Otherwise §4.3's tempo constraint buys nothing |
| 3.4 | SFX cues for Chapter 1 — Journal ×12, combat/UI, footsteps, blips, whispers, ambience | 05§5, §6 | Every cue in the Chapter 1 path resolves; no missing-key errors | ⬜ | Whispers are a brief requirement, not optional |
| 3.5 | HUD — pine-tree health, stamina ribbon, item slot, Journal tab, interaction prompt, scan ring. **Always visible** | 04§2 | Reads `RuntimeDirector.player`, never `GameState` | ⬜ | Contextual fade is Deferred D9 |
| 3.6 | Dialogue — box (bottom-anchored, grows), bubble, typewriter, `resolve_mode`, `Stutter`, `RichTextCipher`, blips | 04§3, §4 | `04§10` combat downgrades `BOX`→`BUBBLE`; stutter is deterministic; longest authored line fits at `text_scale = 1.5` | ⬜ | |
| 3.7 | Journal UI — Entries, Items, Ciphers tabs; weakness field; UV overlay | 04§6 | `00§12·30` no UI script calls `submit_weakness()` or a validator directly (static scan) | ⬜ | Map and Zodiac tabs are Deferred D5 |
| 3.8 | Menus — main (Continue hidden without a save), pause, settings, chapter card | 04§7 | `00§12·9` `PAUSE_REQUEST` dropped in `CUTSCENE`/`ZONE_TRANSITION`/`BLACKOUT`, accepted elsewhere | ⬜ | Pause menu is the only legal `get_tree().paused` |

---

## P4 · Combat

| # | Task | Spec | Verify | Status | Notes |
|---|---|---|---|---|---|
| 4.1 | Attack — windup/active/recovery, hitboxes on animation call tracks | 02§4 | `00§12·5` an already-active hitbox defeats a dodge request; an active i-frame defeats a later hit | ⬜ | Resolver sees a hitbox the tick **after** it arms |
| 4.2 | Dodge — impulse, i-frame window 0.05–0.26, force-closes the Journal | 02§3.4 | Journal force-closes on dodge without the 0.80 s fumble | ⬜ | |
| 4.3 | Gnome enemy — aggro register/deregister, thrown-gnome hazard via `HeightBody` | 06§7 | `threat_active` true while aggro is non-empty, lingers after | ⬜ | |
| 4.4 | Gnomonster — composite of stacked gnome instances, 3 phases | 06§7 | `06§14·7` phases advance monotonically and resolve at 3 | ⬜ | No health bar — leadership mechanic |
| 4.5 | Golf cart — `golf_cart.tscn`, `DRIVING` state, board/exit, cart audio layers, crosses seams | 03§7, 00§5.3 | Boarding requires `FREE` + Journal `CLOSED`; exit requires \|speed\| < 20; cart crosses a boundary with the player | ⬜ | **Kept deliberately** — the coverage is the point |
| 4.6 | Cross-zone respawn mid-boss — `encounter` block, `ENCOUNTER_STATE_REQUEST` | 00§11.3 | `00§12·24` restores `boss_active`/`boss_id`/`boss_phase`; `00§12·25` defeating the boss clears the block; `00§12·28` an unregistered setup is rejected | ⬜ | Exists because of 4.5 |

---

## P5 · Chapter 1 content

| # | Task | Spec | Verify | Status | Notes |
|---|---|---|---|---|---|
| 5.1 | `Ch01Director` — objectives, flags, boss phases, chapter advance | 06§10 | `06§14·3` **static scan**: no out-of-namespace flag write; `06§14·19` no direct `GameState` write | ⬜ | Scans, not self-declared constants |
| 5.2 | `Ch01Dialogue.tres` — every line in the doc, with speaker styling | 06§2 | `06§14·6` no authored line renders as `BOX` during combat | ⬜ | Transcript fidelity is a brief requirement |
| 5.3 | 5 more rigs from the base: Mabel, Stan, Soos, Wendy, gnome | 01§10 | Each instantiates and animates from the shared base | ⬜ | Flat fills |
| 5.4 | Act 0 — cold open, cart chase, rewind handoff via gated transition + teardown | 06§3 | Teardown clears combat, exits the vehicle, restores health, releases weirdness, sets `cp_ch01_porch` | ⬜ | Weirdness 0.55 → 0.05 is the hook |
| 5.5 | Act 1 — arrival, Shack interiors, the errand | 06§4 | Three interiors back to back without a cull or spawn-marker fault | ⬜ | Cheapest place for a lock bug to surface |
| 5.6 | Act 2 — seam crossing, woods, Journal acquisition, penlight | 06§5 | `06§14·4` acquisition survives a round-trip; verbs stay bound throughout | ⬜ | Gate is inventory, not a runtime binding |
| 5.7 | **The `entry_gnomes` blank-weakness beat** + player submission | 06§0.1, §5.7 | `06§14·2` the entry ships with **no** weakness and grants no bonus; `06§14·15` both branches; `06§14·16` the player's exact text round-trips | ⬜ | **The chapter's thesis. Build this first within P5.** Check 2 exists to stop a future session "fixing" it |
| 5.8 | Act 3 — Norman; scan returns **no** entry | 06§6 | `06§14·18` `entry_zombie` stays locked | ⬜ | Wrongness is narrative, not a data state |
| 5.9 | Act 4 — the clearing, boss fight, leaf blower | 06§7 | `06§14·12` cross-zone respawn resumes phase 2 and clears the block on defeat | ⬜ | |
| 5.10 | Mabel's 7-state lifecycle | 06§6.2 | `06§14·11` follower count returns to 0 in state 3 and exactly 1 new one in state 7; `06§14·13` states never overlap | ⬜ | The companion-leak guard |
| 5.11 | Act 5 — attic, Caesar cipher, sigil, chapter card, `CHAPTER_ADVANCE_REQUEST` | 06§8 | `06§14·1` the cryptogram decodes; `06§14·8` advance is exactly +1 | ⬜ | Every cipher gate has a non-cipher path |
| 5.12 | Objectives + zone registry coherence | 06§10 | `06§14·9` every objective is satisfiable; `06§14·10` every named zone is registered | ⬜ | |

---

## P6 · The gate

Not optional. This is why Chapter 1 was written in this form.

| # | Task | Spec | Verify | Status | Notes |
|---|---|---|---|---|---|
| 6.1 | `test_all.gd` fully green | all | Exit 0, every check above | ⬜ | |
| 6.2 | Play start to finish; answer gate questions 1–10 | 06§13 | Each has a **stated pivot** — take it now or commit | ⬜ | Q1, Q2, Q4, Q5 are the expensive ones |
| 6.3 | **Striped-texture hose test** (Q11) | 06§13 | One PNG: vertical bar, three horizontal stripes, on `arm_hose_l`. Play `walk` + `run`. Stripes stay evenly spaced through the elbow | ⬜ | Cheapest insurance in the project. **Do before rigging a second character** |
| 6.4 | Quit-and-continue on a real build | 00§9 | Mid-chapter quit → relaunch → Continue restores checkpoint, flags, inventory, handwriting | ⬜ | |

---

## ⏸ Deferred — not in the test flight

**Lowest priority in the project.** None of these is built until P6 is done. Each has a trigger that says when it stops being deferred. Anything here that turns out to be needed earlier is a finding, not a surprise — record it and move it up.

| # | Item | Why it waits | Replace with, for now | Revisit when |
|---|---|---|---|---|
| D1 | `TransitionTeardown` as a `Resource` | One instance exists project-wide | Flags in the `GATED_ZONE_REQUEST` payload dict | A second chapter declares one |
| D2 | `on_complete_intent` field + validation | One callsite | That callsite enqueues `JOURNAL_TOGGLE_REQUEST` directly | Three chapters want it |
| D3 | Threaded streaming, `_cull_distant`, `SeamBlocker`, grace wipe | Act I has two exterior zones | `preload` both into `world_root` | A third zone can be resident (Ch 3, town) |
| D4 | Save-migration runner | There are no old saves | Keep the version field and the refuse-a-newer-save check | First `SAVE_VERSION` bump |
| D5 | Journal Map tab + Zodiac tab | 2 zones, 2 sigils — both read worse than nothing | 3 tabs: Entries, Items, Ciphers | 4+ zones discovered / 4+ sigils reachable |
| D6 | Item radial (8 segments, hold-to-open) | One item is usable in a fight, in the last 3 minutes | `item_cycle` on the wheel/bumpers | 3+ items usable in combat |
| D7 | Chapter Select + scratch save slot | Cannot be exercised with one chapter | Nothing | Chapter 3 |
| D8 | `TimeRecorder` / rewind / ghosts | Unreferenced by Chapter 1 | Nothing | Chapter 7 |
| D9 | `HudVisibility` contextual fade | Cosmetic; the logic is a fade timer | HUD always visible | The HUD demonstrably clutters play |
| D10 | `SkyController.set_backdrop()` cross-fade | Needs two visually distinct skies to exist | One `Parallax2D` sky for Act I | Town or lake adds a second backdrop |
| D11 | `hose_uv` / `hose_texture_size` / §8.1 atlas spec | Zero PNGs exist; `Polygon2D.texture` stays null | `Tube.capsule` draws the placeholder | The first hose PNG — **and P6.3 passes** |
| D12 | 24 portrait PNGs | Art-blocked, and avoidable | `SubViewport` render of the live rig + brow preset | An artist wants to draw better ones |
| D13 | ~40 key-glyph PNGs | Would go stale on any rebind | `InputMap` + `OS.get_keycode_string()` in a `StyleBoxFlat` | Never |
| D14 | `InputMap` remap screen | Default map covers keyboard-only and gamepad-only | Ship the default map | First playtester who cannot play on defaults |
| D15 | Grapple ownership flag `ch01_grapple_owner` | State for a joke | Mabel takes it narratively; Ch 2 grants the item | Never |
| D16 | 6 unbuilt `ZoneDef` entries + 6 unused palettes | Registry rows for zones that do not exist | Register the 5 that do | Per zone, as authored |
| D17 | 5 of 8 TileSet terrain sets | Chapter 1 uses grass, dirt path, wood floor | Those 3 | Per zone, as authored |
| D18 | Folding `Combat`/`Cutscene`/`Transition` directors into `RuntimeDirector` | Refactor, not a feature — do it when the shape is settled | Three small autoloads | After P6, if any is under ~150 lines |
| D19 | `Tokens` as an Autoload → `class_name` with `const`s | Same refactor bucket | Leave as an autoload | After P6 |
| D20 | `LIFT` / `ORBIT` / `INVERT` anomaly kinds | Chapter 1 uses `PUSH` | `PUSH`/`PULL`/`DRIFT` | Ch 4 (`INVERT`), Ch 5 (`LIFT`+`ORBIT`) |
| D21 | `journal_settle`, `surprise`, `fall`, `land` animations | Explicitly non-gating cosmetic | 8 animations | A scene needs them |
| D22 | 4 settings toggles with no Chapter 1 surface | Nothing to toggle yet | The 3 accessibility toggles in 0.7 | Each gets a thing to toggle |
| D23 | Bill's-eye main-menu easter egg | Nothing | Nothing | Chapter 11 |
| D24 | **Web (HTML5 / itch.io) export** | Best-effort by decision; macOS native is the target | Native only | After P6, if wanted — needs the SharedArrayBuffer flag, and gated Act I travel is the fallback |
| D25 | Chapters 2–25 | Picked after the slice proves the foundation | — | After P6.2's answers |

---

## 🎨 Refinements — only after a functional product

Nothing here starts until the game is playable end to end and P6 is answered.

| # | Item | Notes |
|---|---|---|
| R1 | Real character art — Doc 1 §9.3 manifest | **Gated on P6.3.** Assign textures to the same `Polygon2D` nodes; no code changes. If the striped test failed, the three-bone rig lands first |
| R2 | Real environment art — zone plates, tilesets, props | Same node graph; palette fills become textures |
| R3 | Real audio — Doc 5 §9's ~192 files | Each replaces a baked placeholder file-for-file; same buses, same crossfades, same code path |
| R4 | Real UI art — Doc 4 §9 badges, frames, journal pages | |
| R5 | Text-effect polish — per-character quirks tuned against real type | Brief requirement; the mechanism ships in 3.6, the tuning is here |
| R6 | Performance pass — backbuffer cost, texture budget, load times | Measure first. Doc 1 §2.1's skip threshold and Doc 3 §3.4's budget are the first suspects |
| R7 | Combat feel — hitstop, screen shake, knockback curves | Only meaningful once animations are real |
| R8 | Music mix — stem balance, ducking, crossfade timing | Needs real stems |

---

## Log

| Date | Row | Change |
|---|---|---|
| 2026-07-28 | — | Tracker created from `AUDIT.md` findings and the four locked decisions: web best-effort, `Journal` on the player, `stretch_aspect = keep`, golf cart kept in Chapter 1 |
| 2026-07-28 | 0.1–0.3 | Done. Godot 4.7.1 installed; project created; suite green at 5 checks. Plan file: `executions/p0-bootstrap.json`. One deviation recorded on 0.2 — `tools/` cannot be outside `res://` without a project subdirectory, which would break this file's one test command; the export filter enforces §10's intent instead |
