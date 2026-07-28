# Gravity Falls — 2D RPG

Technical architecture and execution blueprint for a 2D action-RPG based on the Disney series *Gravity Falls*.

**Personal, non-commercial, educational project.** Not affiliated with or endorsed by Disney.

---

## Status

System architecture and the first playable slice are specified. No code written yet — these documents are the specification the implementation will follow, and they have been through a pre-build audit ([`AUDIT.md`](docs/AUDIT.md)).

| Doc | Title | Status |
|---|---|---|
| [00](docs/00-game-loop.md) | Game Loop, Runtime Events & Session Lifecycle | ✅ Approved — **the runtime contract; wins over 01–05** |
| [01](docs/01-theme-animation-asset-tokens.md) | Theme, Animation & Asset Tokens | ✅ Approved — **owns the `res://` tree (§10)** |
| [02](docs/02-physics-engine-mechanics.md) | Game Physics Engine & Mechanics | ✅ Approved |
| [03](docs/03-world-maps-environment.md) | World Maps & Environment Architecture | ✅ Approved |
| [04](docs/04-ui-hud-menus.md) | Background UI, HUD & Menus | ✅ Approved |
| [05](docs/05-audio-engine-sfx.md) | Soundtracks, Audio Engine & SFX Triggers | ✅ Approved |
| [06](docs/06-chapter-01-tourist-trapped.md) | Chapter 1 — "Tourist Trapped" | ✅ Approved — the first playable slice |
| 07–25 | One per remaining story chapter | ⬜ Not started |

[`foundation.md`](foundation.md) is the original project brief. [`docs/AUDIT.md`](docs/AUDIT.md) is the pre-build audit — read its §8 open questions before starting Chapter 2.

**[`docs/TRACKER.md`](docs/TRACKER.md) is where the build runs from.** Priority-ordered rows, each with the check that proves it, resumable across sessions. Non-essential items and all refinements sit at the bottom at lowest priority and are not part of the Chapter 1 test flight.

## Strategy

**Functional first, art later.** The slice ships with flat palette fills and baked procedural audio, and that is success rather than a gap — real assets replace placeholders through the identical code path, so nothing is blocked on art. Chapters 2–25 are picked only once Chapter 1 proves the foundation.

One thing the placeholder strategy cannot see, and the reason for gate question 11: the hose-limb rig fails **only** under a real texture. One striped PNG tests it, and it wants doing before a second character is rigged.

---

## Stack

| | |
|---|---|
| Engine | Godot 4.x, GDScript |
| Targets | **macOS native `.app` (primary)**; Web (HTML5 / Itch.io) best-effort |
| Canvas | 1920×1080, `canvas_items` stretch, **`keep` aspect** (true 16:9 on every display) |
| View | Top-down 3/4, 8-direction movement |
| Characters | `Skeleton2D` cutout rigs, weight-blended `Polygon2D` tube limbs |
| Combat | Real-time action, item- and knowledge-driven |
| World | Progressive hub-and-spoke → streamed semi-open by Act IV |
| Playable | Dipper, with a chapter-appropriate AI companion |

---

## Core design decisions

**One float runs the supernatural.** `Weirdness.applied` (0.0–1.0) drives the screen colour grade, the audio stem mix, the reverb and low-pass, and a 1.5% master pitch drop — one value, one curve, read by everything. Weirdmageddon is a parameter change, not a re-authored world.

**The world never pauses.** The Journal stays live while open — you move at 56% speed, and taking damage drops the book for 0.80 s. Every fight asks whether you can afford to read. Only the pause menu may set `get_tree().paused`.

**Failure costs time, never progress.** Zero health means a blackout and a checkpoint respawn with a comedic beat. No game-over screen, no lost flags, items, or Journal entries.

**Nothing is blocked on art.** Every character part is a `Polygon2D` that renders as a flat palette fill until a texture is assigned — same node, same bones, same animations. Placeholder audio is procedurally synthesised **offline** by `tools/bake_placeholders.gd` and committed as WAVs, travelling the identical code path as real assets. The game is playable and mixable before any asset exists.

**One project tree, one authority.** Doc 1 §10 owns every `res://` path, plus the naming conventions and the one-line placement rule. No other document invents a directory, and no build session improvises a layout.

**Ciphers never wall progress.** Caesar → Atbash → A1Z26 → Vigenère follow the show's own progression, but every cipher-gated path has a non-cipher alternative.

---

## Verification

Every document contributes asserts to **one** headless suite, covering only the logic that can fail silently — geometry and the hose blend band, ciphers, depth ratio, fumble/i-frame timing, zone grid overlaps and adjacency, dialogue mode rules, stem curves, the resolver's tick ordering, and the save round-trip:

```bash
godot --headless --script res://tests/test_all.gd
```

Asserts that compare two constants against each other were cut — a test that cannot fail is worse than no test, because it retires the concern.

---

## Assets

No art or audio assets exist yet. Each document's **► ASSETS YOU NEED TO SUPPLY** section is the complete manifest with exact dimensions and formats — Doc 1 §9.3 (characters), Doc 4 §9 (UI), Doc 5 §9 (audio, ~192 files).

Those manifests are purchase orders, not checklists to work through before the slice is playable. Chapter 1 needs roughly **12 distinct placeholder audio sources** and **zero** PNGs.

**One PNG is worth authoring early, though.** Doc 6 §13 question 11: a straight vertical bar with three horizontal stripes, assigned to Dipper's `arm_hose_l`, played through `walk` and `run`. It is the only thing that tests whether two-bone hose limbs actually bend before thirty characters are drawn to that spec — the least reversible decision in the project, and the one the placeholder build cannot see.
