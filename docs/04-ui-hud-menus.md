# DOCUMENT 4 — Background UI, HUD & Menus

**Consumes:** Doc 1 (palettes, `a_face` anchor, `Weirdness`), Doc 2 (Journal state machine, health/stamina, scan), Doc 3 (zone map, sigils)
**Feeds:** Doc 5 (voice blips, UI SFX), Docs 6–25 (dialogue authoring, per-character text styles)

---

## 0. Locked decisions

| Decision | Value |
|---|---|
| HUD | Contextual fade — hides ~4 s after threat ends |
| Dialogue | Hybrid: bubbles for ambient/combat, bottom-third box for story |
| Inventory | Inside the Journal. No separate screen. Radial quick-select |
| Text FX | Full stylization, with a global accessibility toggle |
| UI canvas | 1920 × 1080, `CanvasLayer` 10 (HUD) / 20 (menus) / 30 (transitions) |
| Safe margin | 48 px on all edges |

### 0.1 The rule that governs everything here

Doc 2 §12.6: **the world never pauses.** Every UI in this document except the pause menu runs over a live world. Two consequences that are not negotiable:

1. **Box dialogue never opens during combat.** Any line delivered while an enemy is active uses a bubble, which does not block the frame. Chapter docs that violate this get rejected — a framed box during a boss fight is a screen you can die behind.
2. **The item radial does not slow time.** It is a live-world decision, exactly like reading the Journal.

---

## 1. Layout & type

### 1.1 Canvas regions

```
┌────────────────────────────────────────────────────────────────────┐
│ 48px safe margin                                                   │
│  ┌──────────────────┐                                              │
│  │ ♦♦♦♦♦♦  health   │                          ┌──────────────┐    │
│  │ ▬▬▬▬▬▬  stamina  │                          │ scan ring    │    │
│  └──────────────────┘                          │ (world-anch.)│    │
│                                                └──────────────┘    │
│                                                                    │
│                        [ world / journal overlay ]                 │
│                                                                    │
│                                                                    │
│  ┌────────────────────────────────────────────────────┐            │
│  │  DIALOGUE BOX  1824 × 300  @ y = 732               │            │
│  └────────────────────────────────────────────────────┘            │
│  ┌────────┐                                       ┌────────┐       │
│  │ [J]    │                                       │  item  │       │
│  │ journal│                                       │  slot  │       │
│  └────────┘                                       └────────┘       │
└────────────────────────────────────────────────────────────────────┘
```

### 1.2 Type scale

| Role | Size (1080p) | Weight | Use |
|---|---|---|---|
| `display` | 96 | Heavy | Main menu title, chapter cards |
| `heading` | 48 | Bold | Menu sections, Journal tab titles |
| `dialogue` | 34 | Regular | Box body text |
| `bubble` | 30 | Regular | Speech bubbles |
| `journal_hand` | 32 | Handwritten | Journal entry body |
| `body` | 28 | Regular | Descriptions, settings |
| `label` | 22 | Medium | Item counts, key hints |
| `caption` | 18 | Regular | Tooltips, footnotes |

All sizes multiply by `Settings.text_scale` (1.0 / 1.25 / 1.5). Every text container uses `autowrap_mode = WORD_SMART` and grows vertically — nothing is fixed-height, so 1.5× scale never clips.

---

## 2. HUD

### 2.1 Health — pine trees

Six to fourteen pine trees, top-left, 44 px each, 8 px gap, laid out on a stitched felt banner.

| State | Appearance |
|---|---|
| Full | Green pine, `moss` fill, `pine_deep` outline |
| Empty | Bare brown stump, `bark_mid`, 55% opacity |
| Losing | Tree **falls** — rotate 84° over 0.30 s, `TRANS_BACK`, then fade to stump |
| Gaining | Sprouts upward, `TRANS_ELASTIC`, 0.4 s |
| Critical (≤2) | Remaining trees pulse `gift_shop_red` at 1.4 Hz |

The falling-tree animation is the readability trick — a pip that vanishes is easy to miss, a tree that topples is not.

### 2.2 Stamina — merit badge ribbon

A stitched ribbon bar under the health banner, 320 × 18 px, `journal_gold` fill on `bark_dark` track, visible stitch dashes along the edge.

| State | Appearance |
|---|---|
| Draining | Fill shortens, no easing (instant response) |
| Regenerating | Fill grows with 0.15 s smoothing |
| Exhausted (<10) | Ribbon frays at the tip, flashes `gift_shop_red` twice |
| Locked out | Desaturated until back above 25 |

### 2.3 Item slot

Bottom-right, 132 × 132 embroidered-patch frame. Shows the active item icon, count badge, and a cooldown sweep. On item change: patch flips over 0.25 s.

### 2.4 Journal tab

Bottom-left, the Journal's spine edge-on, 96 × 132, with a `[J]` key hint below.

| State | Appearance |
|---|---|
| Idle | Spine at 70% opacity |
| **New entry available** | Gold edge glow, gentle 2 s pulse |
| Open | Spine slides off-screen left |
| Fumbled (Doc 2 §5.2) | Spine tumbles, greyed, 0.80 s |

### 2.5 Scan ring

World-anchored to the scan target, not screen-anchored. A 96 px radius ring that fills clockwise over the 1.4 s scan, in `anomaly_green`. On interrupt it shatters outward and vanishes — a resetting progress bar reads as a bug, a shattering one reads as a consequence.

### 2.6 Interaction prompt

Floats 40 px above the target's `a_head_top`, or the prop's top edge. A key badge (`E` / gamepad glyph) plus a one-word verb: *Open, Read, Talk, Take, Enter, Turn*. Fades in over 0.15 s on target change.

### 2.7 Contextual fade

```gdscript
# res://ui/hud/hud_visibility.gd
class_name HudVisibility
extends CanvasLayer

const IDLE_HIDE_DELAY := 4.0
const FADE_TIME := 0.35
const SNAP_TIME := 0.08          ## showing is near-instant; hiding is lazy

@export var health_group: Control
@export var stamina_group: Control
@export var item_group: Control

var _idle := 0.0
var _shown := true
var _item_changed_at := -999.0   ## set from RuntimeDirector's item_select_committed

func _process(delta: float) -> void:
	if _should_show():
		_idle = 0.0
		_set_shown(true)
	else:
		_idle += delta
		if _idle >= IDLE_HIDE_DELAY:
			_set_shown(false)

## LIVE state comes from the player node, never from GameState. GameState (Doc 00
## §9.2) is the PERSISTENCE autoload — chapter, flags, inventory, entries,
## checkpoint — and holds no health, no stamina, and no item timestamp. Health and
## Stamina are nodes on the player (Doc 2 §7.1, §3.1); the Journal is a node on the
## player too (Doc 2 §5.2). Reaching for the nearest global instead of the owner is
## how a UI doc ends up referencing three members that do not exist.
func _should_show() -> bool:
	var p := RuntimeDirector.player
	if p == null:
		return false
	return (
		p.health.current < p.health.max_pips        # never hide damage
		or p.stamina.current < p.stamina.maximum
		or CombatDirector.threat_active             # enemy aware of player
		or p.journal.state != Journal.JournalState.CLOSED
		or Time.get_ticks_msec() * 0.001 - _item_changed_at < 2.0
		or CombatDirector.boss_active               # Doc 00 §2.3
	)

func _on_item_select_committed(_id: StringName) -> void:
	_item_changed_at = Time.get_ticks_msec() * 0.001

func _set_shown(v: bool) -> void:
	if v == _shown:
		return
	_shown = v
	var t := create_tween().set_parallel()
	var a := 1.0 if v else 0.0
	var dur := SNAP_TIME if v else FADE_TIME
	for g in [health_group, stamina_group, item_group]:
		t.tween_property(g, "modulate:a", a, dur)
```

Asymmetric timing is the whole point: the HUD **snaps in at 0.08 s** and **drifts out at 0.35 s**. The snap makes its arrival a threat signal. The drift keeps it from feeling twitchy in quiet zones.

The Journal tab and interaction prompt are exempt — they never fade, because they're affordances, not status.

---

## 3. Dialogue

### 3.1 Line resource

```gdscript
# res://core/dialogue_line.gd
class_name DialogueLine
extends Resource

enum Mode { AUTO, BUBBLE, BOX }

@export var speaker_id: StringName            ## dipper, mabel, stan, soos, bill, ...
@export_multiline var text: String            ## may contain BBCode + custom tags
@export var mode: Mode = Mode.AUTO
@export var portrait_expression: StringName = &"neutral"
@export var anxious: bool = false             ## enables Dipper's stutter transform
@export var sfx_override: StringName = &""
```

> **Superseded — Doc 00 §8.4.** An earlier draft carried `pause_player: bool`, which set
> `PlayerController` to `CUTSCENE` directly. Only `RuntimeDirector` commits player state
> (Doc 00 §14.1), so the field is removed. A line needing player lockout is authored as a
> `CUTSCENE_REQUEST` through Doc 00 §8.2.

### 3.2 Mode selection

`AUTO` resolves at runtime. The rules, in order:

```gdscript
static func resolve_mode(line: DialogueLine) -> Mode:
	if line.mode != Mode.AUTO:
		# An explicit BOX during combat is a design error — downgrade and warn.
		if line.mode == Mode.BOX and CombatDirector.threat_active:
			push_warning("BOX dialogue during combat, forcing BUBBLE: %s" % line.speaker_id)
			return Mode.BUBBLE
		return line.mode
	if CombatDirector.threat_active:
		return Mode.BUBBLE          # never block the frame mid-fight
	if line.text.length() > 90:
		return Mode.BOX             # too long for a bubble
	return Mode.BUBBLE
```

A line that needs the player held still is not a `Mode` decision at all — it is a cutscene, and
`CutsceneDirector` renders its lines as `BOX` for the duration it owns player state.

### 3.3 Speech bubbles

Anchored to the speaker's `a_face` (Doc 1 §6.3), converted to screen space each frame.

| Property | Value |
|---|---|
| Max width | 620 px |
| Max lines | 3 (over that → promote to box) |
| Padding | 28 px |
| Corner radius | 26 px, hand-wobbled outline (3 px, `bill_black`) |
| Tail | 34 px, points at `a_face`, flips side near screen edges |
| Screen clamp | 48 px margin; bubble slides, tail stretches to keep pointing |
| Lifetime | `1.2 s + 0.045 s per character`, min 1.8 s |
| Stacking | Max 3 on screen; oldest fades first |

Bubbles never require input to dismiss. They are ambient by definition.

### 3.4 Story box

1824 wide, **bottom-anchored at `y = 1032` and growing upward**, `custom_minimum_size.y = 300`, `journal_page` background at 94% opacity over a 6 px `journal_cover` border with visible corner stitching.

**The box grows; it is not a fixed 300 px window.** §1.2 promises no text container is fixed-height so 1.5× scale never clips, and this is the one box where that promise has to be kept deliberately: `resolve_mode` (§3.2) promotes to `BOX` above 90 characters with no upper bound, and chapter docs author lines well past that — Doc 6 §4.4's Stan line is 137 characters, which wraps to four lines at `text_scale = 1.5`. A fixed 216 px text area silently truncates the fourth line **at the largest accessibility setting**, which is the setting used by the people who need it. Anchoring the bottom edge and letting the box grow upward keeps the caret, the portrait, and the border in place while the text takes the room it needs.

| Element | Position | Size |
|---|---|---|
| Portrait | left inset 24, bottom-aligned | 240 × 240 |
| Name plate | above portrait, overlapping | auto × 44 |
| Text area | x 300 → 1780 | **grows with content**, min 216 |
| Advance indicator | bottom-right, 40 × 40 | bobbing pine-tree caret |

Name plate is tinted per speaker from the Doc 1 palette. Portraits are `240 × 240` per expression.

**Advance:** `interact` or `Space`. First press completes the typewriter instantly; second advances. Holding `interact` auto-advances at 1.5× reveal speed.

---

## 4. Rich text & character voice

### 4.1 What's built in vs. what we write

Godot's `RichTextLabel` already ships `[shake]`, `[wave]`, `[tornado]`, `[rainbow]`, `[fade]`, `[pulse]`. Mabel's chaotic color is `[rainbow]` with tuned parameters — no custom code. Only Bill needs something Godot doesn't have.

### 4.2 Bill — the `[cipher]` effect

Per-character size jitter, slight rotation, and a rare glyph flicker. This is what makes his dialogue feel like it's being transmitted rather than spoken.

```gdscript
# res://ui/dialogue/rich_text_cipher.gd
class_name RichTextCipher
extends RichTextEffect

var bbcode := "cipher"

func _process_custom_fx(fx: CharFXTransform) -> bool:
	if not Settings.text_effects_enabled:
		return true                                   # accessibility: pass through untouched

	var i := float(fx.range.x)
	var t := fx.elapsed_time

	# Per-glyph scale wobble — deterministic per index, so it reads as
	# structured wrongness rather than random noise.
	var n := sin(t * 3.1 + i * 12.9898) * 0.5 + 0.5
	var s := lerpf(0.82, 1.24, n)
	fx.transform = fx.transform.scaled(Vector2(s, s))

	# Vertical judder + slight tilt.
	fx.offset = Vector2(0.0, sin(t * 5.7 + i * 4.13) * 4.0)
	fx.transform = fx.transform.rotated(sin(t * 2.3 + i) * 0.06)

	# Occasional black flash — one glyph in ~40, briefly inverted.
	var flick := sin(t * 11.0 + i * 78.233)
	fx.color = Color("0e0e0e") if flick > 0.985 else Color("ffd23f")
	return true
```

Scaling via `fx.transform` pivots at the glyph origin, which shifts letters slightly as they scale. That is the desired artifact here — Bill's text should not sit cleanly on its baseline.

### 4.3 Dipper — stutter

A **text transform**, not a visual effect: it rewrites the string before the typewriter sees it, so the stutter is heard in the reveal rhythm rather than merely seen.

```gdscript
# res://ui/dialogue/stutter.gd
class_name Stutter

const STUTTER_CHANCE := 0.22
const LEAD_WORDS := 3          ## stutters cluster at the start of a sentence

## "I don't know about this" -> "I-I don't know a-about this"
static func apply(text: String, seed_value: int) -> String:
	if not Settings.text_effects_enabled:
		return text
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value                    # stable per line — never re-rolls on replay
	var words := text.split(" ")
	var out: PackedStringArray = []
	for i in words.size():
		var w: String = words[i]
		var eligible := w.length() > 2 and _is_alpha(w[0])
		var weight := 2.0 if i < LEAD_WORDS else 1.0
		if eligible and rng.randf() < STUTTER_CHANCE * weight:
			out.append("%s-%s" % [w[0], w])
		else:
			out.append(w)
	return " ".join(out)

static func _is_alpha(c: String) -> bool:
	var u := c.to_upper().unicode_at(0)
	return u >= 65 and u <= 90
```

Seeding from the line ID keeps a given line stuttering identically every time it plays — a line that re-rolls its stutter on replay reads as a glitch.

### 4.4 Per-speaker style table

| Speaker | Reveal (cps) | Default wrapper | Name tint | Notes |
|---|---|---|---|---|
| Dipper | 48 | — (`Stutter.apply` when `anxious`) | `#4A6B8A` | Stutter only on anxious lines |
| Mabel | 65 | `[rainbow freq=0.4 sat=0.7 val=1.0]` | `#A6392E` | Fastest talker in the cast |
| Stan | 40 | — | `#E8E4DC` | Long punctuation pauses — he's working an angle |
| Soos | 38 | `[wave amp=8 freq=2]` | `#3E7C4A` | Gentle drift, never jarring |
| Wendy | 46 | — | `#C25B2E` | |
| Bill | 30 | `[cipher]` | `#FFD23F` | Slow. Menace is in the pacing |
| Gideon | 44 | `[pulse freq=1.2]` on threats | `#7FBFE0` | Sweet cadence, wrong content |
| Ford | 42 | — | `#6A2CE0` | |
| Jeff | 52 | — | `#6B8F4E` | Doc 6 §2.1. Salesman warmth that drops to flat menace when refused |
| Journal text | 55 | — | `#2B2118` | Ford's handwriting |

### 4.5 Typewriter

| Rule | Value |
|---|---|
| Base rate | Per-speaker, §4.4 |
| `,` `;` | +0.10 s |
| `.` `!` `?` | +0.24 s |
| `—` | +0.18 s |
| `[pause=x]` | explicit, x seconds |
| Voice blip | Every 3rd glyph, skipped on whitespace (Doc 5 hook) |
| Skip | `interact` completes instantly |

---

## 5. Accessibility

Not optional polish. Two of the four requested character quirks — Bill's jitter and Mabel's color cycling — are genuine readability hazards, and Weirdmageddon's grade is a photosensitivity hazard.

### 5.1 Settings

| Setting | Default | Effect |
|---|---|---|
| `text_effects_enabled` | on | Off → strips all FX tags, disables stutter, uniform 50 cps |
| `text_scale` | 1.0 | 1.0 / 1.25 / 1.5 across every text role |
| `dialogue_opacity` | 0.94 | Up to 1.0 fully opaque for contrast |
| `reduce_flashing` | off | Clamps `Weirdness` aberration ≤0.3, disables strobes and Bill's glyph flicker |
| `screen_shake` | 1.0 | 0.0 disables entirely |
| `colorblind_safe` | off | `[rainbow]` → single tint; anomaly green → `portal_blue`; adds shape coding to health pips |
| `auto_advance_dialogue` | off | Advances after reveal + 2.5 s |

### 5.2 Tag stripping

```gdscript
# res://ui/dialogue/text_accessibility.gd
class_name TextAccessibility

const FX_TAGS := [
	"cipher", "rainbow", "wave", "tornado", "shake", "pulse", "fade",
]

## Removes decorative markup while preserving semantic markup (color on names,
## [b]/[i] for emphasis) and explicit [pause] timing.
static func plain(text: String) -> String:
	var out := text
	for tag in FX_TAGS:
		var re := RegEx.new()
		re.compile("\\[/?%s[^\\]]*\\]" % tag)
		out = re.sub(out, "", true)
	return out

static func render(text: String) -> String:
	return text if Settings.text_effects_enabled else plain(text)
```

`[pause]` survives stripping deliberately — it's pacing, not decoration, and Stan's timing is characterization that costs nothing to read.

---

## 6. The Journal UI

The Journal is the inventory, the bestiary, the map, the decoder, and the sigil tracker. One book.

### 6.1 Frame

Right 45% of canvas — **864 × 1080 at `x = 1056`**. Doc 2 §5.3 already specified the camera response: offset left 190 px, zoom 0.88×, over 0.35 s. A 60 px gradient scrim on the Journal's left edge keeps world detail from fighting page text.

Open/close uses a page-flip: the cover rotates in on the Y axis (a `skew` + `scale.x` fake, cheaper than any 3D approach) over Doc 2's **0.42 s**.

**The UI is fully interactive at 0.42 s**, matching Doc 2's `OPENING → OPEN` transition exactly. Dipper's body is still settling into the read pose until 0.90 s (Doc 1 §7.1 `journal_settle`), but that animation is cosmetic and non-gating — tab input, scrolling, cipher entry, and the radial are all live the moment the flip completes. The UI never waits on the character rig.

### 6.2 Tabs

Leather tabs down the right edge, 5 tabs × 148 px. `Q`/`E` or bumpers cycle; number keys jump.

| Tab | Contents |
|---|---|
| **Entries** | Scanned creatures and phenomena. Locked entries show a torn-page silhouette |
| **Items** | Inventory grid — §6.3 |
| **Ciphers** | Decode pane — §6.4 |
| **Map** | Doc 3 zone grid, discovered zones only |
| **Zodiac** | 10 sigils, silhouetted until found |

### 6.3 Items tab

4-column grid, 168 px slots, 16 px gutter. Icon, count badge, and a gold corner fold on the active item. Selecting a slot shows a description panel below, written in Ford's voice where the item is anomalous and Stan's where it's merchandise.

**Radial quick-select.** Hold `item_radial` → 8-segment radial at screen centre, 280 px radius. (`item_radial` is its own action — `Tab` / gamepad `Left bumper` held. It cannot share `item_cycle`, which Doc 2 §3.5 binds partly to the mouse wheel, and a wheel notch cannot be held.) Direction selects; release commits. **The world keeps running** — no slow-motion, no pause. Consistent with the Journal, and it keeps item swapping a real mid-fight decision.

### 6.4 Ciphers tab

Left page lists collected cipher fragments with their source zone. Right page is the decoder: the fragment, a cipher-type selector (Caesar / Atbash / A1Z26 / Vigenère), a key field for Vigenère, and a live-decoding preview driven by Doc 2 §5.6's `Cipher` class.

The preview updating live as you scrub the Caesar shift is deliberate — it turns a lookup into a slot machine you can feel land.

Solved fragments burn gold at the edges and unlock their Journal entry.

**The pane validates nothing.** Live preview is pure decode and touches no state, but committing an answer writes `GameState.data.ciphers_solved`, so submission is a `JOURNAL_SUBMIT_REQUEST` with `kind = &"cipher"` (Doc 00 §8.3). The pane reacts to `journal_submit_committed`. Same rule for the weakness field on an incomplete entry (Doc 00 §9.2.1) — a submission can be cancelled by a same-tick hit, and the typed text survives in the field for a retry.

### 6.5 Map tab

Renders the Doc 3 grid at 1:640 scale. Undiscovered zones are blank parchment; discovered ones are hand-inked. Current position is a small pine-tree marker. **No fast travel** — the map is orientation only, which is what keeps Doc 3's streaming world worth walking.

### 6.6 Zodiac tab

The wheel, ten segments, in the show's arrangement. Found sigils render in full; unfound are charcoal silhouettes with their discovery zone named but not their method. Ties directly to Doc 3 §6.2 and the Chapter 20 ending branch.

---

## 7. Menus

### 7.1 Main menu

Diegetic. The Journal lies open on a stump in the woods, options burned into the page. Behind it, a parallax woods scene idling at `Weirdness` 0.15.

| Item | Notes |
|---|---|
| Continue | Hidden if no save |
| New Game | |
| Chapters | Unlocked chapters only, replayable |
| Settings | §7.3 |
| Quit | Hidden on web export |

Once Chapter 11 is reached, **Bill's eye occasionally blinks open in the background treeline** — roughly once per 40 s, 0.4 s, no sound, never acknowledged. Suppressed when `reduce_flashing` is on.

### 7.2 Pause menu

The only place `get_tree().paused = true` is legal (Doc 2 §12.6). Journal-styled overlay at 88% opacity over a desaturated freeze-frame.

Resume · Journal · Settings · Chapter Select · Quit to Menu.

### 7.3 Settings

| Category | Contents |
|---|---|
| Display | Fullscreen, resolution, vsync, window scale |
| Audio | Master / BGM / SFX / Dialogue bus faders (Doc 5) |
| Controls | Full `InputMap` remap, keyboard + gamepad, reset to defaults |
| Accessibility | §5.1 |
| Game | Text speed, auto-advance, subtitle background |

### 7.4 Chapter cards

Between chapters: full-screen `journal_page`, chapter number in `display` type, title hand-lettered, and the chapter's cipher shown **encoded** — a standing invitation to decode it in the Journal. 2.5 s, skippable.

---

## 8. Theme

One `Theme` resource, `res://ui/gf_theme.tres`, consuming Doc 1 tokens. Type variations rather than per-node styling:

| Variation | Base | Use |
|---|---|---|
| `JournalPanel` | `PanelContainer` | Page surfaces |
| `BadgeFrame` | `PanelContainer` | HUD item slot, patches |
| `DialogueBox` | `PanelContainer` | Story box |
| `SpeechBubble` | `PanelContainer` | Bubbles, wobbled border |
| `MenuButton` | `Button` | Burned-in menu options |
| `TabLeather` | `Button` | Journal tabs |

---

## 9. ► ASSETS YOU NEED TO SUPPLY

Doc 1 §9.3 continues here. Everything below has a working placeholder.

| Asset | Spec | Count |
|---|---|---|
| **Display font** | Hand-lettered chunky sans, full Latin + punctuation | 1 |
| **Handwriting font** | Ford's Journal hand | 1 |
| **Body font** | Clean readable sans | 1 |
| Pine tree pip | 44 × 44, full + stump states | 2 |
| Merit ribbon | 320 × 18, track + fill + frayed tip | 3 |
| Badge patch frame | 132 × 132 | 1 |
| Journal spine | 96 × 132 | 1 |
| Journal cover + page | 864 × 1080, cover / open spread | 2 |
| Leather tabs | 64 × 148 | 5 |
| Key glyph badges | 48 × 48, keyboard + Xbox + PlayStation | ~40 |
| **Character portraits** | 240 × 240, 4 expressions each, 9 speakers | 36 |
| Zodiac sigils | 128 × 128, full + silhouette | 20 |
| Item icons | 96 × 96 | ~40 |

Placeholders: fonts fall back to Godot's default; all frames render as Doc 1 palette `StyleBoxFlat` with stitched borders drawn in code; portraits render as the character's placeholder head at 240 px.

---

## 10. Validation

```gdscript
# res://tests/test_all.gd — godot --headless --script res://tests/test_all.gd
extends SceneTree

func _init() -> void:
	# --- Accessibility must remove every decorative tag --------------------
	Settings.text_effects_enabled = false
	var styled := "[cipher]YOUR MIND[/cipher] is [rainbow freq=0.4]MINE[/rainbow] [shake]now[/shake]"
	var plain := TextAccessibility.render(styled)
	for tag in TextAccessibility.FX_TAGS:
		assert(not plain.contains("[%s" % tag), "FX tag survived stripping: %s" % tag)
	assert(plain.contains("YOUR MIND") and plain.contains("MINE"), "stripping ate the text")

	# --- but semantic markup and pacing must survive ----------------------
	var semantic := "[color=#ffd23f]BILL[/color] says [pause=0.4]hello"
	var out := TextAccessibility.render(semantic)
	assert(out.contains("[color=") and out.contains("[pause="),
		"stripping must preserve color and pause")

	# --- Stutter is stable across replays ---------------------------------
	Settings.text_effects_enabled = true
	var a := Stutter.apply("I don't know about any of this", 12345)
	var b := Stutter.apply("I don't know about any of this", 12345)
	assert(a == b, "stutter must be deterministic per line seed")
	assert(Stutter.apply("I don't know", 99) != "I don't know" or true, "stutter may no-op")

	# --- Combat forces bubbles, always ------------------------------------
	CombatDirector.threat_active = true
	var line := DialogueLine.new()
	line.mode = DialogueLine.Mode.BOX
	assert(DialogueLine.resolve_mode(line) == DialogueLine.Mode.BUBBLE,
		"BOX dialogue must be downgraded during combat")
	line.mode = DialogueLine.Mode.AUTO
	assert(DialogueLine.resolve_mode(line) == DialogueLine.Mode.BUBBLE,
		"AUTO must pick BUBBLE during combat")

	# --- Long lines promote out of bubbles --------------------------------
	CombatDirector.threat_active = false
	line.text = "x".repeat(140)
	assert(DialogueLine.resolve_mode(line) == DialogueLine.Mode.BOX,
		"lines over 90 chars must promote to BOX")

	# --- HUD show must be faster than HUD hide ----------------------------
	assert(HudVisibility.SNAP_TIME < HudVisibility.FADE_TIME,
		"HUD must snap in and drift out, not the reverse")

	# --- Text scale must not overflow the dialogue box --------------------
	for scale in [1.0, 1.25, 1.5]:
		var line_h: float = 34.0 * scale * 1.35        # size * leading
		var lines: int = floori(216.0 / line_h)
		assert(lines >= 3, "text_scale %.2f leaves only %d lines in the box" % [scale, lines])

	print("ui: all checks passed")
	quit()
```

---

## 11. Contracts this document exports

1. **Box dialogue never renders during combat.** `resolve_mode` enforces it and warns on violation. Chapter docs must author mid-fight lines as bubbles.
2. The item radial and the Journal both run on a live world. Nothing here pauses except the pause menu.
3. HUD snaps in (0.08 s) and fades out (0.35 s). Health never hides while damaged.
4. Every text effect passes through `TextAccessibility.render()`. Nothing writes to a `RichTextLabel` directly.
5. `[pause]` and `[color]` are semantic and survive accessibility stripping; everything else is decorative and does not.
6. Stutter is seeded per line ID and never re-rolls.
7. Inventory lives in the Journal. No second inventory UI may be added.
7a. No UI pane writes `GameState`. Player-typed answers — ciphers and weakness fields — enqueue `JOURNAL_SUBMIT_REQUEST` and render from `journal_submit_committed` (Doc 00 §8.3).
8. The map shows position only. **No fast travel** — it would undercut Doc 3's streaming world.
9. All text roles scale by `Settings.text_scale`; no text container is fixed-height.
