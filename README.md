# Gravity Falls — 2D RPG

Technical architecture and execution blueprint for a 2D action-RPG based on the Disney series *Gravity Falls*.

**Personal, non-commercial, educational project.** Not affiliated with or endorsed by Disney.

---

## Status

System architecture complete (Docs 1–5). Chapter implementation docs (6–25) not yet started. No code written yet — these documents are the specification the implementation will follow.

| Doc | Title | Status |
|---|---|---|
| [01](docs/01-theme-animation-asset-tokens.md) | Theme, Animation & Asset Tokens | ✅ Approved |
| [02](docs/02-physics-engine-mechanics.md) | Game Physics Engine & Mechanics | ✅ Approved |
| [03](docs/03-world-maps-environment.md) | World Maps & Environment Architecture | ✅ Approved |
| [04](docs/04-ui-hud-menus.md) | Background UI, HUD & Menus | ✅ Approved |
| [05](docs/05-audio-engine-sfx.md) | Soundtracks, Audio Engine & SFX Triggers | ✅ Approved |
| 06–25 | One per story chapter | ⬜ Not started |

[`foundation.md`](foundation.md) is the original project brief.

---

## Stack

| | |
|---|---|
| Engine | Godot 4.x, GDScript |
| Targets | macOS native `.app`, Web (HTML5 / Itch.io) |
| Canvas | 1920×1080, `canvas_items` stretch, `expand` aspect |
| View | Top-down 3/4, 8-direction movement |
| Characters | `Skeleton2D` cutout rigs, weight-blended `Polygon2D` tube limbs |
| Combat | Real-time action, item- and knowledge-driven |
| World | Progressive hub-and-spoke → streamed semi-open by Act IV |
| Playable | Dipper, with a chapter-appropriate AI companion |

---

## Core design decisions

**One float runs the supernatural.** `Weirdness.level` (0.0–1.0) drives the screen colour grade, the audio stem mix, the reverb and low-pass, and a 1.5% master pitch drop. Weirdmageddon is a parameter change, not a re-authored world.

**The world never pauses.** The Journal stays live while open — you move at 56% speed, and taking damage drops the book for 0.80 s. Every fight asks whether you can afford to read. Only the pause menu may set `get_tree().paused`.

**Failure costs time, never progress.** Zero health means a blackout and a checkpoint respawn with a comedic beat. No game-over screen, no lost flags, items, or Journal entries.

**Nothing is blocked on art.** Every character part is a `Polygon2D` that renders as a flat palette fill until a texture is assigned — same node, same bones, same animations. Placeholder audio is procedurally synthesised and baked to PCM at startup, travelling the identical code path as real assets. The game is playable and mixable before any asset exists.

**Ciphers never wall progress.** Caesar → Atbash → A1Z26 → Vigenère follow the show's own progression, but every cipher-gated path has a non-cipher alternative.

---

## Verification

Each system document ends with a headless assert-based check covering the logic that fails silently:

```bash
godot --headless --script res://tokens/test_tokens.gd     # geometry, eye math, hose UVs
godot --headless --script res://physics/test_physics.gd   # ciphers, depth ratio, fumble/i-frame timing
godot --headless --script res://world/test_world.gd       # zone grid overlaps, adjacency, walk time
godot --headless --script res://ui/test_ui.gd             # tag stripping, combat dialogue rules
godot --headless --script res://audio/test_audio.gd       # stem curves, cue lengths, placeholder bake
```

---

## Assets

No art or audio assets exist yet. Each document's **► ASSETS YOU NEED TO SUPPLY** section is the complete manifest with exact dimensions and formats — Doc 1 §9.3 (characters), Doc 4 §9 (UI), Doc 5 §9 (audio, ~192 files).
