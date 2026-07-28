# DOCUMENT 6 — CHAPTER 1: "Tourist Trapped"

**Source:** Season 1, Episode 1
**Consumes:** Doc 00 (runtime contract), Doc 1 (tokens), Doc 2 (physics, Journal), Doc 3 (zones), Doc 4 (UI), Doc 5 (audio)
**Feeds:** Chapter 2 (`z_lake`, Gobblewonker)
**Status:** **First playable slice.** This chapter is the project's architectural decision gate — §12 defines what to judge and §13 defines what to pivot if it fails.

---

## 0. Locked decisions

| Decision | Value | Why |
|---|---|---|
| Episode scope | S1E1 only, complete | One chapter, one episode. Chapters 2+ may combine |
| Slice depth | **Full vertical** — every Doc 1–5 system exercised at least once (§11) | A gate that skips the risky systems is not a gate |
| Opening | Playable cold-open cart chase, then "let's rewind" | Mirrors the episode; teaches movement before mechanics |
| Golf cart | **Scripted set-piece only.** Free-roam still unlocks Ch 9 (Doc 3 §7) | Doc 3's Act I walking scale survives; the verb is taught early, earned later |
| Mabel | Seven states in one chapter (§6.2) | Exercises Doc 2 §9's follower through create, free, and re-create |
| Dialogue | Authored in-voice per Doc 4 §4.4; `[TRANSCRIPT]` markers where you may paste exact lines | §2.3 |
| Cipher | Caesar −3 (Doc 3 §6.1's Ch 1–7 band) | Matches the episode's own end-credits cryptogram |
| Target length | 40–50 min first playthrough | Long enough to expose pacing, short enough to replay while tuning |

### 0.1 The one design beat that matters

**The Journal does not have the answer.**

Doc 2 §5.4 promises that scanning a creature reveals its weakness and grants a damage bonus. Chapter 1 is the single place in the game where that promise visibly fails: scanning a gnome unlocks the entry, and the weakness field reads `UNKNOWN — ` in Ford's hand, with blank ruled space beneath it. The player beats the Gnomonster by improvising with a leaf blower, and the chapter ends with Dipper **writing the weakness in himself**.

This is faithful — the show's gnome page is blank there, and Dipper fills it in later in his own blue ink — and it is the correct tutorial. It teaches in one chapter that the Journal is a tool, not an oracle; that Ford was a person who ran out of time; and that the player is expected to add to it. Every later chapter's scan reward reads as earned because Chapter 1 withheld it once.

Do not "fix" this by giving the gnome entry a weakness. It is the chapter's thesis.

---

## 1. Beat map

| Act | Beat | Zone / scene | Player verb taught | Runtime systems proven |
|---|---|---|---|---|
| **0** | Cold-open chase | `z_woods_south` (scripted path) | Vehicle steering | `DRIVING`, HUD snap-in, boss BGM cut |
| — | "Let's rewind" | — | — | `CutsceneDirector`, chapter card |
| **1** | Arrival, the Shack | `z_shack_ext` | Move, interact | Boot → `begin_session()`, dialogue box |
| 1 | Gift shop, Soos & Wendy | `int_giftshop` | Interact targeting | Interior as `ZoneDef` (Doc 00 §7.6) |
| 1 | The attic | `int_attic` | — | Checkpoint + autosave, Pine Tree sigil |
| **2** | Flyer errand | `z_shack_ext` → `z_woods_south` | Run, stamina | **Seamless activation**, BGM crossfade, streaming |
| 2 | The metal tree | `z_woods_south` | — | `SecretTrigger`, Weirdness pulse |
| 2 | **Journal 3 acquired** | — | `J` — open/close | Journal state machine, camera offset, UI |
| 2 | First scan | Gnome tracks | Hold scan | Scan ring, entry unlock, the §0.1 failure |
| 2 | UV marking | Ford's warning | `F` | UV shader, cipher fragment |
| **3** | Mabel leaves | `z_shack_ext` | — | Companion despawn |
| 3 | The clearing | `z_woods_south` NW | Attack, dodge | Combat, **Journal fumble**, i-frames |
| 3 | Abduction | — | — | Cutscene during combat, bubble dialogue |
| **4** | Gnomonster ph. 1 | Clearing | Item use | `boss_phase`, anomaly field |
| 4 | Gnomonster ph. 2 | Scripted cart path | Vehicle dodge | `DRIVING` under threat, escort |
| 4 | Gnomonster ph. 3 | — | Leaf blower | Item verb, boss defeat |
| **5** | Gift shop reward | `int_giftshop` | — | Inventory, **grappling hook unlock** |
| 5 | Journal entry, chapter card | `int_attic` | Cipher decode | Cipher UI, `CHAPTER_ADVANCE_REQUEST` |
| 5 | Vending machine stinger | `int_giftshop` | — | Locked interactable, refusal line |

---

## 2. Cast, voice & dialogue

### 2.1 Speakers in this chapter

Doc 4 §4.4 owns reveal rate, wrapper tags, and name tint. Doc 5 §6 owns blip pitch. Chapter 1 uses six of the nine:

| Speaker | Role in Ch 1 | Portrait expressions needed |
|---|---|---|
| Dipper | Player character, narrator in Act 0 | neutral, anxious, determined, exhausted |
| Mabel | Companion, abductee | neutral, delighted, smitten, defiant |
| Stan | Quest giver, reward giver | neutral, grifting, gruff, evasive |
| Soos | Gift shop, comic relief | neutral, cheerful, confused, earnest |
| Wendy | Counter, deadpan | neutral, bored, amused, alert |
| **Jeff** (gnome) | Antagonist | neutral, charming, furious, defeated |

Jeff is Chapter 1's addition to the roster, and he is already carried into Doc 4 §4.4 and Doc 5 §6: **reveal 52 cps, no wrapper by default, name tint `#6B8F4E` (`moss`), blip pitch 1.22 / variance ±0.09, timbre reedy square.** His register is a salesman's: warm, over-familiar, and it drops to flat menace the instant he is refused. That switch is the character.

### 2.2 Authoring rules carried from Doc 4

- Every mid-fight line is `Mode.BUBBLE`. Doc 4 §3.2 downgrades a `BOX` during combat and warns; Chapter 1 must never trigger that warning. §14 check 6 asserts it.
- Dipper's anxious lines set `anxious = true` for Doc 4 §4.3's stutter. Use it in Act 2 (alone in the woods) and Act 3 (Mabel taken), **not** in Act 0 — the cold open is Dipper narrating after the fact, and he is calm about it.
- Mabel's `[rainbow]` wrapper is her default. Drop it for exactly one line, in Act 3 when she realizes what Norman is. The absence lands harder than any effect.
- No line needs `pause_player` — that field is gone (Doc 00 §8.4). Lines that hold the player are authored as cutscenes.

### 2.3 Dialogue fidelity

Lines below are **authored in-voice**, not transcribed. They carry the scene's intent and each character's register per Doc 4 §4.4, and the chapter is complete and buildable as written.

Where a moment is iconic enough that fans would notice a substitution, the line is marked:

```
[TRANSCRIPT: <act> — <whose line, and which beat>]
```

Paste the exact line from the episode yourself if you want verbatim fidelity. Every marker has a working authored fallback beside it, so the build never blocks on an unfilled marker.

**There are 5 markers in this chapter**, one per act:

| Act | § | Beat |
|---|---|---|
| 0 | §3 | Dipper's opening narration |
| 2 | §5.3 | Dipper on opening the compartment |
| 3 | §6.5 | Jeff's proposal to Mabel |
| 4 | §7.3 | Mabel's line before firing the leaf blower |
| 5 | §9.1 | Mabel's reaction to the grappling hook |

---

## 3. Act 0 — Cold open

**Zone:** `z_woods_south`, scripted corridor. **Length:** ~90 s. **Player state:** `DRIVING`.

The game opens mid-disaster, exactly as the episode does.

```text
1. begin_session() mounts z_woods_south at spawn "sp_ch01_coldopen".
   Doc 00 §3.2 — lock held, overlay opaque.
2. Fade in on the cart already moving. Player has steering only.
3. Gnomonster is behind, gaining. CombatDirector.boss_active = true,
   boss_phase = 0 (cold-open variant, no damage possible).
4. AudioDirector cuts to boss_gnome on a bar boundary (Doc 5 §4.2, §4.4).
5. Three scripted swerve prompts. Missing one costs nothing — this beat
   cannot be failed, and the HUD proves it by never showing damage.
6. Hard freeze-frame on the cart mid-air. Dipper's narration begins.
7. Chapter card (Doc 4 §7.4) wipes to Act 1 via §3.2's handoff.
```

**Why it cannot be failed:** the player has had the controller for eleven seconds. A death here teaches nothing and costs a first impression. `Health` is present and the HUD is live so the player learns to read it, but every hitbox in Act 0 is disabled.

### 3.1 New-game state

`GameState.new_game()` seeds the checkpoint before `begin_session()` runs, because Doc 00 §3.2 mounts from `GameState.data.checkpoint` and a new game has no other source of truth:

```gdscript
GameState.data.checkpoint = {
	&"id": &"cp_ch01_coldopen",
	&"zone_id": &"z_woods_south",
	&"spawn_marker": &"sp_ch01_coldopen",   ## resolved after the zone instantiates
	&"position": Vector2.ZERO,              ## unused: the marker wins (Doc 00 §9.2)
	&"wake_line_id": &"",
	&"encounter": {},
}
```

The checkpoint names a **marker**, not a coordinate — a new game cannot know where `sp_ch01_coldopen` is until `z_woods_south` has instantiated, and Doc 3 §1.1 forbids hardcoding world positions precisely so that moving a marker during level editing does not silently invalidate every checkpoint written before it.

Act 0 is therefore savable and resumable like any other beat. Doc 00 §9.1's autosave-on-zone-activation fires normally, and a player who quits during the cold open resumes by replaying it — 90 seconds, and it is the best 90 seconds in the chapter to see twice. No autosave-suppression mechanism is needed, and none is added.

### 3.2 The rewind handoff

The "let's rewind" cut is a **gated zone transition** (Doc 00 §7.4), not a scene swap. Running it through the normal path means the chapter's first transition is the same code every later transition uses.

```text
1. Freeze-frame holds. Player state → CUTSCENE.
2. Narration completes. Ch01Director enqueues GATED_ZONE_REQUEST
   { to: z_shack_ext, spawn_marker: sp_ch01_arrival }.
3. Resolver takes the lock; TransitionDirector fades to opaque.
4. RuntimeDirector applies the declared teardown at Doc 00 §7.4 step 5a.
5. activate_zone(z_shack_ext) commits palette, weirdness floor 0.05, bgm_shack.
6. Chapter card renders over the opaque overlay, 2.5 s, skippable.
7. Fade in. Lock releases. Arrival grace (Doc 00 §7.7), then Act 1.
```

The cold open leaves `CombatDirector` in a boss state, the player in `DRIVING`, and `Weirdness` at an event-driven 0.55 — none of which a zone change resets on its own. The chapter **declares** that cleanup as a `TransitionTeardown` (Doc 00 §7.4.1) and `RuntimeDirector` commits it; `Ch01Director` mutates nothing:

```gdscript
# res://chapters/ch01/rewind_teardown.tres
clear_combat            = true    # boss_active false, boss_phase 0, aggro clear
exit_vehicle            = true    # DRIVING → FREE, cart despawned, not stored (§7.2)
restore_health          = true    # the cold open cost nothing
release_weirdness       = true    # event level → 0; the zone floor takes over
clear_pending_blackout  = false
set_checkpoint          = { id: cp_ch01_porch, zone_id: z_shack_ext,
                            spawn_marker: sp_ch01_porch }   # marker, never a coordinate
```

```gdscript
RuntimeEvents.enqueue(RuntimeEvent.Type.GATED_ZONE_REQUEST, self, {
	&"to": &"z_shack_ext",
	&"spawn_marker": &"sp_ch01_arrival",
	&"teardown": preload("res://chapters/ch01/rewind_teardown.tres"),
})
```

This is the chapter that motivated Doc 00 §7.4.1 existing, and it uses five of the resource's six fields — which is the argument for the fixed field set over a callback. Everything Chapter 1 needs is nameable in advance.

Once `cp_ch01_porch` is written, `cp_ch01_coldopen` is unreachable for the rest of the game. That is intended: Act 0 is not replayable except via Chapter Select (Doc 00 §9.5).

**Weirdness:** 0.55 for the duration — high, unexplained, and it drops to 0.05 the instant Act 1 begins. The contrast is the hook, and it exercises Doc 1 §2's shader at a real value in the first minute.

> **Dipper** (`neutral`, narration): "Okay. So. Some of this is going to sound made up."
> [TRANSCRIPT: cold open — Dipper's opening narration]
> **Dipper:** "It didn't start like this. It started with a bus, and a suitcase, and my sister eating a whole bag of gummy worms in one sitting."
> **Mabel** (`delighted`, bubble, over the engine): "I regret nothing!"

---

## 4. Act 1 — Arrival and the Mystery Shack

**Zones:** `z_shack_ext`, `int_giftshop`, `int_living_room`, `int_attic`. **Length:** ~10 min.

### 4.1 Objectives

| ID | Objective | Completion |
|---|---|---|
| `ch01_o1_meet_stan` | Talk to Stan on the porch | Dialogue complete |
| `ch01_o2_gift_shop` | Enter the gift shop | `activate_zone(int_giftshop)` |
| `ch01_o3_meet_staff` | Talk to Soos and Wendy | Both dialogues complete |
| `ch01_o4_attic` | Find your room | Reach the attic checkpoint |

### 4.2 Interaction nodes

| Node | Zone | Verb | Result |
|---|---|---|---|
| `npc_stan_porch` | `z_shack_ext` | Talk | Sets `ch01_met_stan`, gives the flyer errand |
| `prop_totem_pole` | `z_shack_ext` | Read | Flavor. First `PropScannable` the player will later re-scan |
| `npc_soos` | `int_giftshop` | Talk | Sets `ch01_met_soos` |
| `npc_wendy` | `int_giftshop` | Talk | Sets `ch01_met_wendy` |
| `prop_vending_machine` | `int_giftshop` | Turn | **Refused** — see §9.4 |
| `prop_attic_bed` | `int_attic` | Rest | Checkpoint + autosave (Doc 00 §9.1) |
| `sigil_pine_tree` | `int_attic` | — | Granted on first entry (Doc 3 §6.2) |

### 4.3 Interior route

Doc 3 §5.1 fixes the Shack's internal topology: the gift shop is the hub, the living room hangs off it, and the attic is up the living-room stairs. Chapter 1 authors every door on that path, and no others.

| `DoorBoundary` | From → To | Spawn marker | Notes |
|---|---|---|---|
| `door_shack_front` | `z_shack_ext` → `int_giftshop` | `sp_giftshop_front` | Gated, 0.25 s wipe (Doc 00 §7.6) |
| `door_giftshop_out` | `int_giftshop` → `z_shack_ext` | `sp_shack_porch` | Return leg |
| `door_giftshop_house` | `int_giftshop` → `int_living_room` | `sp_living_from_shop` | Behind Stan's counter |
| `door_living_shop` | `int_living_room` → `int_giftshop` | `sp_giftshop_house` | Return leg |
| `door_living_stairs` | `int_living_room` → `int_attic` | `sp_attic_stairs` | The stairs |
| `door_attic_down` | `int_attic` → `int_living_room` | `sp_living_stairs` | Return leg |

Six doors, three round trips. **`ch01_o4_attic` is `z_shack_ext → int_giftshop → int_living_room → int_attic`** — three gated transitions in a row, which is worth having early: it is the densest transition sequence in the chapter and the cheapest place for a lock or spawn-marker bug to surface.

Two doors are authored as **refusals**, not routes, so the Shack reads as bigger than the slice:

| Door | Refusal |
|---|---|
| `door_living_kitchen` | Stan: it's not a tour, and there's nothing in there but expired ham |
| `door_living_stan_room` | Locked. Doc 3 §5.1 opens it at Ch 12 |

Both use Doc 00 §7.5's refusal path — the resolver emits the line, so a refusal can never fire mid-fade.

### 4.4 Dialogue

> **Stan** (`grifting`, box): "You must be the kids. Congratulations, you're employees now. Don't touch anything with a price tag, and everything's got a price tag."
> **Dipper** (`anxious`): "We just got here."
> **Stan:** "And already you're behind."

> **Soos** (`cheerful`, `[wave]`, box): "Hey. Hey, you're the new kids. I'm Soos. I fix stuff, mostly by hitting it. Sometimes that's the right call."
> **Wendy** (`bored`, box, from behind the counter): "Don't let him sell you a mystery. They're all just raccoons in hats."
> **Soos:** "One of them is a raccoon in a hat. The rest are legit, dude."

Wendy's line is doing structural work: it plants the tourist-trap framing the whole game will spend twenty chapters undermining.

### 4.5 The errand

Stan sends Dipper into the woods with a staple gun and a stack of flyers. This is the chapter's inciting excuse, and it is also the tutorial's cover story for teaching run and stamina.

> **Stan** (`gruff`): "Take these into the trees. Staple 'em where a tourist can see 'em and a health inspector can't."
> **Mabel** (`delighted`, `[rainbow]`): "Team siblings! I'll hold the flyers and provide moral support and also commentary!"

Mabel joins as a companion here (Doc 2 §9 breadcrumb follower). She is present for all of Act 2 up to the Journal discovery.

---

## 5. Act 2 — The woods and the Journal

**Zones:** `z_shack_ext` → `z_woods_south` (**seamless**, Doc 00 §7.3). **Length:** ~15 min.

This act is the single most important test in the slice. It crosses a streamed seam, changes BGM mid-walk with no fade, ramps the Weirdness shader, and hands the player the game's core verb — all without a loading screen. If any of that stutters, §13's pivot list applies.

### 5.1 Objectives

| ID | Objective | Completion |
|---|---|---|
| `ch01_o5_flyers` | Staple 3 flyers | Counter reaches 3 |
| `ch01_o6_metal_tree` | Investigate the strange tree | Interact with `prop_metal_tree` |
| `ch01_o7_journal` | **Take the Journal** | Item acquired, `J` unlocked |
| `ch01_o8_scan_gnome` | Scan something you don't recognize | First `scan_completed` |

### 5.2 Flyer placement

Three `PropInteractable` targets, deliberately spaced to force the seam crossing:

| Flyer | Location | Teaches |
|---|---|---|
| 1 | `z_shack_ext`, treeline | Interaction prompt, verb badge |
| 2 | `z_woods_south`, first clearing | The seam crossing itself |
| 3 | `z_woods_south`, NW toward gnome territory | Run + stamina drain over distance |

Doc 3 §5.2's clearing-grid rule applies: flyer 2 and flyer 3 sit in hand-placed clearings, so the player learns to navigate by landmark before the woods ever get hostile.

### 5.3 The metal tree

Ford's disguised machine. A `PropInteractable` with a two-stage reveal:

```text
1. Approach within 300 px → Weirdness.pulse(0.30, 0.8). The grade shifts and
   Doc 5 §2's unease stem rises. Nothing is said. The player just feels it.
2. Interact once  → Dipper brushes moss aside. Metal panel exposed.
3. Interact twice → the lever. Compartment opens. Journal 3.
```

Two interactions rather than one because the discovery deserves a beat, and because it proves the resolver re-verifies `can_interact()` at commit time (Doc 00 §6.1) with a target whose state changed between presses.

> **Dipper** (`anxious`): "That's not bark. That's a hinge."
> [TRANSCRIPT: the metal tree — Dipper's line on opening the compartment]

### 5.4 Journal 3 — acquisition

The moment the item lands:

1. `GameState.data.inventory[&"journal_3"] = 1` and `ch01_journal_acquired = true`.
2. `GameState.data.inventory[&"uv_penlight"] = 1` and `ch01_uv_acquired = true` — the penlight is taped inside the cover (§5.5) and is granted by the same pickup, never separately.
3. `GameState.data.inventory[&"journal_3"] = 1` — which is what unlocks the verb. `J` and `F` were bound at boot like every other action (Doc 2 §3.5); the resolver refuses `JOURNAL_TOGGLE_REQUEST` and `UV_TOGGLE_REQUEST` until the item is held (Doc 00 §4.2 rows 11–12), so this line is the whole gate. The Doc 4 §2.4 spine tab fades in bottom-left with a gold pulse.
4. `Weirdness.pulse(0.65, 1.4)` — the single largest spike in Act 2.
5. A first-open cutscene: the Journal turns in Dipper's hands, one page, Ford's hand.
6. The cutscene declares `on_complete_intent = JOURNAL_TOGGLE_REQUEST` (Doc 00 §8.2.1).

Step 6 is the runtime-supported form of "the player ends up reading." Doc 00 §8.1 step 6 is absolute — a cutscene returns `FREE` with the Journal `CLOSED` — so the chapter cannot simply hand back control mid-read. The declared intent resolves on the following tick at priority 11 and opens the book through the ordinary 0.42 s `OPENING` path.

The player's first Journal open is therefore the same animation, the same state machine, and the same 118 px/s movement penalty as every open afterward. Nothing about it is special-cased, which is exactly what makes it a tutorial.

**Contents at acquisition** — three entries, one locked:

| Entry | State | Purpose |
|---|---|---|
| `entry_welcome` | Unlocked | Ford's introduction. Carries the §8 cipher fragment |
| `entry_gnomes` | **Locked** — silhouette | Unlocks on the Act 2 scan. Weakness field blank (§0.1) |
| `entry_trust_no_one` | Unlocked, UV-only | Invisible until `F`. §8.2 |

### 5.5 The blacklight — a flagged deviation

Doc 2 §5.5's UV mechanic needs a light source, and the show does not hand Dipper one in this episode.

**Decision: the compartment contains a small blacklight penlight alongside the Journal.** One line of dialogue covers it, and it costs nothing later.

This is a deliberate deviation from the source, taken because the vertical slice must exercise the UV shader and the alternative is deferring UV to a chapter that has no natural place for it either. It is the **only** invented item in Chapter 1. If §13's playtest says the UV beat is weak, cut the penlight rather than moving it.

> **Dipper:** "There's a little flashlight taped inside the cover. Purple bulb. That's… not a normal flashlight."

### 5.6 The first scan

Target: `gnome_tracks`, a `PropScannable` at the edge of gnome territory — small boot prints in a ring, far too many for one creature.

The scan runs Doc 2 §5.4's full 1.40 s with the ring, the three audible increments (Doc 5 §5.1), and the completion chime. Then:

- `entry_gnomes` unlocks. Sketch, habitat, behavior — all present.
- **Weakness: `UNKNOWN`.** Blank ruled lines beneath.
- No damage multiplier is granted. The HUD's weakness slot shows an empty field, not a hidden one.

> **Dipper** (`anxious`): "He wrote down everything. Everything except the part I need."

This is §0.1 landing. Let it sit — no NPC comments on it.

### 5.7 Two scan-completion paths

§0.1 only works if the scan system has an explicit **incomplete-entry** branch. Doc 2 §5.4 describes the populated path only, and a naive implementation will either always grant a weakness or always withhold one. Both are wrong.

`JournalEntry` gains one field, and `scan_completed` branches on it:

```gdscript
# res://core/journal_entry.gd
class_name JournalEntry
extends Resource

@export var id: StringName
@export var title: String
@export_multiline var body: String
@export var sketch: Texture2D

## Empty means Ford never determined it. This is a real authored state, not
## a missing value — see Doc 6 §0.1. Entries may ship deliberately blank.
@export var weakness: String = ""
## What would verify a player's answer. Authored, and present even on a blank
## entry — a weakness Ford never found is still a weakness that exists.
@export var accepted_answers: PackedStringArray = PackedStringArray()

## Pure comparison. Holds no player state — see below.
func verifies(text: String) -> bool:
	var norm := _normalize(text)
	for a in accepted_answers:
		if _normalize(a) == norm:
			return true
	return false

static func _normalize(t: String) -> String:
	var s := t.strip_edges().to_lower()
	for article in ["a ", "an ", "the "]:
		if s.begins_with(article):
			s = s.substr(article.length())
	return s.trim_suffix("s")                      # blower / blowers
```

**`JournalEntry` is authored, immutable, shared data and holds nothing the player did.** What the player wrote and whether it verified live in `GameState.data.journal_overrides`, read through `JournalDB` (Doc 00 §9.2.1). Writing to the resource instead would lose the player's handwriting on reload *and* carry it into the next New Game, since `.tres` files are shared in memory and never saved.

Reads and the single write:

```gdscript
JournalDB.weakness_written(&"entry_gnomes")   # "" until the player writes
JournalDB.is_verified(&"entry_gnomes")        # false until they get it right
JournalDB.damage_multiplier(&"entry_gnomes")  # 1.0, then 1.45
# writing goes through the resolver — see §9.3, never called from UI
JournalDB.submit_weakness(&"entry_gnomes", text)   # the only writer
```

`entry_gnomes` ships `weakness = ""` and `accepted_answers = ["leaf blower"]`, which `_normalize` also matches against "leaf blowers", "Leaf Blowers", and "a leaf blower".

| Path | Condition | Scan result |
|---|---|---|
| **Populated** | `weakness` non-empty | Entry unlocks, weakness shown in the HUD, ×1.45 granted. Doc 2 §5.4 unchanged |
| **Incomplete** | `weakness` empty | Entry unlocks with sketch and body. Weakness renders as `UNKNOWN —` over blank ruled lines. **No multiplier** until `JournalDB.is_verified()`. `journal_scan_done` still plays — the scan succeeded; the book is what failed |

**The distinction the UI must carry:** an incomplete entry is not a locked entry. Doc 4 §6.2's locked entries show a torn-page silhouette; an incomplete one shows a *complete-looking page with an empty field*. If a player reads "no weakness found" as "scan failed", §13 question 7 fires.

**Written and verified are two different things**, and conflating them would have made "banana" worth ×1.45. The page renders whatever the player typed, verbatim and permanently — that is the charm, and typing nonsense is explicitly allowed by §9.3. The damage bonus keys off `JournalDB.is_verified()` instead, so only the right answer earns it.

A correct answer grants the ×1.45 retroactively. That is the payoff for §0.1's withholding, and it lands one chapter later, which is exactly when the player next fights something.

An unverified entry can be resubmitted at any time from the Entries tab. The game never says the answer was wrong — the bonus simply is not there, and a player who later works it out can go back. Ford's entries are trusted on sight; the player's have to be right.

Chapter 1 ships **one** incomplete entry. Every other entry in the game is populated unless a chapter doc says otherwise and states why.

### 5.8 Combat introduction

Two or three gnomes ambush after the scan. They are weak, slow, and telegraph heavily. What the encounter actually teaches:

| Beat | Lesson |
|---|---|
| Gnome closes, windup is long | Read the telegraph, use dodge (Doc 2 §3.4) |
| Player is very likely reading | **Damage → Journal fumble** (Doc 2 §5.2), 0.80 s |
| Fumble sits inside i-frames | You lost tempo, not a second pip (Doc 2 §7.1) |
| Improvised melee feels mediocre | Correct. Dipper is not a fighter (Doc 2 §4) |

The fumble is the most important 0.8 seconds in the slice. If playtesting says players do not read mid-combat at all, §13 lists the levers.

---

## 6. Act 3 — Norman, and the abduction

**Zones:** `z_shack_ext`, `z_woods_south` NW clearing. **Length:** ~8 min.

### 6.1 Objectives

See §6.3 — the act's four objectives are listed there with their triggers, because the route and the objectives are the same thing.

### 6.2 Mabel's lifecycle

Doc 2 §9's follower is created, destroyed, and recreated within this chapter, so a leak surfaces at the gate rather than in Chapter 12. That only holds if every transition has a named trigger. It does:

| # | State | Begins on | Ends on | Node |
|---|---|---|---|---|
| 1 | **Follower** | `ch01_met_stan` — she joins for the errand (§4.5) | `ch01_journal_acquired` | `CompanionFollower`, leader = player |
| 2 | **Scripted exit** | `ch01_journal_acquired` | ~6 s later | Same node, `leader = null`, walks a fixed path off-screen |
| 3 | **Absent** | Exit path completes → `queue_free()` | `ch01_norman_revealed` | None. `ch01_mabel_present = false` |
| 4 | **Captive** | `ch01_norman_revealed` | Phase 1 ends — she boards the cart (§7.1) | Static `Node2D` parented to the Gnomonster rig, not a follower |
| 5 | **Escort** | Phase 2 begins (§7.2) | Phase 3 begins | Cart passenger seat, no pathing |
| 6 | **Decoy** | Phase 3 begins (§7.3) | Jeff released | Scripted `Node2D` beside Jeff, stalling him |
| 7 | **Follower** | `ch01_boss_defeated` | Chapter end | New `CompanionFollower` instance |

State 2 is the piece the chapter previously left implicit. **`ch01_journal_acquired` is the despawn trigger**, and the exit is a walk-off rather than a cut, so the player sees her leave. She calls back over her shoulder; Dipper is reading and does not look up. That is the whole Act 2/3 pivot in one staged exit, and it costs one scripted path.

> **Mabel** (`smitten`, `[rainbow]`, bubble, walking away): "His name is Norman and he's TALL and he doesn't talk much which I think means he's mysterious!"
> **Dipper** (`anxious`, not looking up): "Or it means something's wrong with his throat."
> **Mabel** (fading): "Mysterious throat!"

**States 4, 5, and 6 do not overlap**, and the boundaries are the phase transitions themselves:

- **4 → 5 is the rescue**, and it is the beat phase 1 exists to earn. On phase 1's exit condition, the Gnomonster's grip fails on the side Mabel is held — the same six gnomes the player knocked loose were the ones holding her. She drops, Dipper reaches the cart, both board. Roughly 5 s, scripted, unskippable, and it is the only reward phase 1 pays out.
- **5 → 6 is her choice.** Reaching `z_shack_ext` ends phase 2; Mabel gets out and walks toward Jeff while Dipper goes for the leaf blower. The player is not consulted. She is not a passenger for the ending.
- **6 → 7 is the boss defeat.** The decoy node is freed and a fresh `CompanionFollower` instantiated.

State 3 → 4 has no player-visible spawn: Mabel is already in the clearing when the cutscene begins. The follower node is genuinely freed at the end of state 2 and a **new** node is instantiated for state 7, which is the leak test — §14 check 11 asserts the instance count returns to zero during state 3.

### 6.3 The return trip and the trail

The document previously jumped from the woods to "back at the Shack" with no route. The route is an objective:

| ID | Objective | Trigger | Completion |
|---|---|---|---|
| `ch01_o9_return` | Head back and show Mabel what you found | `ch01_journal_acquired` | Reach `z_shack_ext` |
| `ch01_o10_norman` | Find out what Norman is | Mabel's exit completes | Scan `npc_norman` |
| `ch01_o11_follow` | Follow the trail | `ch01_norman_scanned` | Reach the NW clearing |
| `ch01_o12_rescue` | Get Mabel back | `ch01_norman_revealed` | Boss defeated |

**The return leg is not filler.** It is the seam crossed a second time, in the opposite direction, with the Journal now in hand — the first chance the player has to walk a known route while reading, and the first time `Journal.blocks_zone_travel()` (Doc 00 §7.5) can plausibly fire. Expect players to hit the boundary blocker here. That is the intended teaching moment for it.

**`npc_norman` spawn:** on the Shack porch, on arrival, as a scripted appearance during the return fade — never popped in on-screen. He is a `PropScannable` as well as an NPC, because §6.4's scan needs a target.

**The trail:** eight footprint decals from the porch to the NW clearing, on `TileDecal`, each faded in by its own `Area2D` as the player approaches — the same two-line pattern as Doc 3 §2.2's canopy fade. **They are not `SecretTrigger`s.** Doc 3 §6's `Reveal` enum is a closed set of six values describing how a *secret* is uncovered; a wayfinding decal that simply must not be missed is not a secret, and adding a seventh enum value for it would put route-marking into the secrets system permanently. They are visible without the penlight. They are visible without the penlight; using the penlight on them reveals a second set of prints — five sets, all the same size, which is the clue the game never says out loud.

### 6.4 Dipper's wrong theory

The player scans Norman at range. **The scan returns no entry** — and Dipper says why, in his own voice:

> **Dipper** (`nervous`, bubble): "Nothing solid. Closest thing in here is the zombie page, and it's… close enough."

Dipper concludes zombie. He is wrong. The game does not correct him; the player finds out with him.

**The wrongness is narrative, not a data state, and that is deliberate.** An earlier draft had the scan unlock `entry_zombie` as a "partial match with a confidence warning" — which would have cost three things for nothing. It needs a confidence field on `JournalEntry` that no other beat uses; it needs a third entry-render state in Doc 4 §6.2, where §5.7 already warns that even a second state ("no weakness found") is a comprehension risk; and worst, `entry_zombie` ships *authored and verified*, so unlocking it here would hand the player a permanent **+45% damage against zombies as a reward for being fooled**. Returning nothing keeps the beat exactly — Dipper is still wrong, out loud, and the game still does not correct him — and adds no state at all. §14 check 18 asserts the entry stays locked.

Mechanically this is a second, quieter lesson: a scan can mislead. It rhymes with §0.1 and it is the last time the game undermines the Journal for a long while.

### 6.5 The clearing

Dipper arrives to find Norman coming apart. Five gnomes, one trenchcoat.

Cutscene, `CUTSCENE_REQUEST` per Doc 00 §8.2, with `on_complete_flag = ch01_norman_revealed`. Combat begins immediately on completion — which tests Doc 00 §8.1's ordering, since the boss's first hitbox arms on the same tick control returns.

> **Jeff** (`charming`, bubble): "Hi there! Big misunderstanding. We're not a boyfriend. We're a committee."
> **Mabel** (`defiant`, **no `[rainbow]`**): "You lied about your whole entire body."
> [TRANSCRIPT: the reveal — Jeff's proposal to Mabel]
> **Jeff** (`furious`): "Then we do this the traditional way. Gnomes! Assemble the big guy!"

---

## 7. Act 4 — The Gnomonster

**Boss:** `boss_gnome` (Doc 5 §4.2). **Phases:** 3. **Length:** ~6 min.

`CombatDirector.boss_active = true`, `boss_phase` advanced by this document. Doc 5 §4.2 already gates `boss_gnome` on `boss_phase`; what follows is the phase *content* that gating refers to.

### 7.1 Phase 1 — The clearing (on foot)

| Property | Value |
|---|---|
| Player state | `FREE` |
| Gnomonster | Stationary, sweeps a fist arm across the clearing |
| Attack 1 | Ground slam — telegraphed 0.9 s, `PUSH` anomaly field on impact (Doc 2 §6.1) |
| Attack 2 | Gnome throw — a single gnome as a projectile, dodgeable |
| Damage source | Loose gnomes, 1 pip each |
| Exit condition | Survive 45 s, or knock 6 gnomes loose with melee. **Both end in the rescue beat** (§6.2, state 4→5) |
| Weirdness | 0.50 |

The `PUSH` field on the slam is the slice's proof that Doc 2 §6.1's anomaly fields write `external_force` correctly under combat load, not just in a quiet gravity-hill test.

### 7.2 Phase 2 — The cart chase (scripted)

Stan's golf cart is parked at the clearing edge — Mabel got it there, and how is a joke, not a plot hole.

| Property | Value |
|---|---|
| Player state | `DRIVING` (Doc 00 §5.3) |
| Path | Scripted corridor, `z_woods_south` → `z_shack_ext` |
| **Cart ownership** | **None.** Not added to inventory, not persistent. Doc 3 §7's free-roam unlock stays at Ch 9 |
| Steering | Full player control within the corridor |
| Hazards | Thrown gnomes, falling trees — dodge by steering |
| Mabel | Escort passenger, delivers bubble lines |
| Failure | Blackout → `cp_ch01_clearing`, phase 2 **resumes** via the encounter block. **This is a cross-zone respawn** once the seam is crossed — see below |
| Weirdness | 0.60 |
| Exit condition | Reach `z_shack_ext` — **crosses a zone boundary while `DRIVING`** |

That last row is not incidental. Doc 00 §5.3 asserts vehicles cross boundaries; this is the chapter that proves it, under threat, with an escort NPC and an active boss. If it breaks, it breaks here rather than in Chapter 9 when the cart is real.

**Dying after the seam is a cross-zone respawn**, and Chapter 1 claims it as coverage rather than avoiding it. The checkpoint (`cp_ch01_clearing`) is in `z_woods_south`; the player can die in `z_shack_ext`. Doc 00 §11.2 step 3 therefore runs its gated-travel branch, with the overlay already opaque from the blackout.

Everything about that path is load-bearing and none of it is exercised anywhere else in the chapter: the destination zone must mount, the boss must resume at phase 2 rather than restart at phase 1, the cart must be re-placed at the corridor start, and Mabel must return to escort state.

Doc 00 §11.2's ordinary respawn does the opposite of all that — step 5 calls `CombatDirector.reset()`, which would drop the player back at the clearing with no boss and an unwinnable chapter. The supported path is Doc 00 §11.3's **encounter block**, armed on the checkpoint when the phase begins:

```gdscript
# armed on entering phase 2 — a request, not a write (Doc 00 §11.3)
RuntimeEvents.enqueue(RuntimeEvent.Type.ENCOUNTER_STATE_REQUEST, self, {
	&"boss_id": &"boss_gnome",
	&"phase": 2,
	&"setup": &"ch01_gnomonster_ph2",   # registered with CombatDirector at _ready
})
```

`ch01_gnomonster_ph2` is a named setup, not a script: the Gnomonster rig at the corridor start, the cart at its spawn, and Mabel in the passenger seat. Doc 00 §11.3 instantiates it in place of step 5's reset.

**The block is cleared on `ch01_boss_defeated`** — an `ENCOUNTER_STATE_REQUEST` with an empty payload. A player who walks back to that clearing in a later chapter finds it empty, not haunted by a boss that respawns forever. §14 check 12 covers both directions.

`Ch01Director` writes neither the checkpoint nor the encounter block. It registers `ch01_gnomonster_ph2` with `CombatDirector` at `_ready()` and enqueues two events across the whole fight.

The alternative — keeping the chase inside one zone — would be simpler and would test less. Given that this chapter exists to be a gate, the harder version is the right one.

### 7.3 Phase 3 — The leaf blower

Mabel's kissing-practice leaf blower is on the Shack porch. The player grabs it as an item.

```text
1. Reaching z_shack_ext ends phase 2. Player exits the cart (forced).
2. Leaf blower is a ground pickup → equipped to the item slot (Doc 4 §2.3).
3. Mabel stalls Jeff by feigning acceptance. Scripted, ~12 s.
4. Item use aims a suction cone. Holding it pulls Jeff off the Gnomonster.
5. Release fires him. The Gnomonster collapses — the whole creature was
   holding together on his authority, and that is the actual mechanic.
```

**The boss is not defeated by damage.** Its health bar, if one is shown at all, never empties. It comes apart because its leadership was removed. That is what the episode is about, and a health-bar solution would say the opposite.

> **Mabel** (`defiant`): "You want a queen? Queens get to make one royal decree."
> [TRANSCRIPT: the leaf blower — Mabel's line before firing]
> **Jeff** (`defeated`, doppler-shifted bubble): "This isn't ovaaaaaa—"

### 7.4 Boss audio

| Phase | Stems | Doc 5 reference |
|---|---|---|
| 0 (cold open) | `base` + `dread` only | §2.2 |
| 1 | `base` + `unease` | Cut on bar boundary, §4.4 |
| 2 | All four, `dread` at 0.7 | Crossfade over one bar |
| 3 | `dread` solo, then hard stop on Jeff's release | §4.2 |

The hard stop lands the instant the leaf blower releases Jeff — a beat of near-silence before the collapse SFX. It costs nothing and it is the loudest moment in the chapter.

---

## 8. Ciphers & secrets

### 8.1 The chapter cipher — Caesar −3

Doc 3 §6.1 assigns Caesar (−3) to Chapters 1–7. The episode's own end-credits cryptogram is exactly this cipher, so Chapter 1 uses it verbatim:

```
Ciphertext:  ZHOFRPH WR JUDYLWB IDOOV
Cipher:      Caesar, shift −3
Plaintext:   WELCOME TO GRAVITY FALLS
```

Presented twice, deliberately:

1. **In the world** — carved into the Shack's welcome sign, visible from the first minute of Act 1, meaningless until Act 5.
2. **On the chapter card** (Doc 4 §7.4), encoded, as the standing invitation to open the Ciphers tab.

Solving it is optional and unlocks `entry_welcome_decoded` plus the `ch01_cipher_solved` flag. Per Doc 2 §12.9 it gates nothing.

### 8.2 UV markings

| ID | Location | Reveals |
|---|---|---|
| `uv_ch01_trust` | Inside the Journal cover | `TRUST NO ONE` in `journal_ink_red` |
| `uv_ch01_tree` | Metal tree trunk, after the Journal | Ford's six-fingered hand and a date |
| `uv_ch01_clearing` | Clearing stone, gnome territory | A tally of previous "queens" — played straight, not for laughs |

`uv_ch01_clearing` is the chapter's one genuinely unsettling detail and it is entirely optional. Doc 3 §6's `SecretTrigger` handles all three.

### 8.3 Zodiac sigils reachable in Chapter 1

Doc 3 §6.2 places two within reach:

| Sigil | Location | Method |
|---|---|---|
| Pine Tree | `int_attic` | **Given** on first entry, Act 1 |
| Shooting Star | `z_shack_ext` (10880, 6120) | `COORD_SEQUENCE`, 3 spots |

The Shooting Star sequence is the slice's test of Doc 3 §6's `COORD_SEQUENCE` type — no hint until the first spot is stood on. Expect most players to miss it. That is correct; it is what makes the Zodiac tab worth revisiting in Act IV.

---

## 9. Chapter close

### 9.1 The reward

Stan lets each twin take one item from the gift shop.

| Recipient | Item | Mechanical effect |
|---|---|---|
| Dipper | The pine-tree hat | **Cosmetic.** Rig swap per Doc 1. Becomes his sprite for the rest of the game |
| Mabel | Grappling hook | **Verb unlock**, but not immediately and not for her — see §9.2 |

### 9.2 The grapple handoff

Mabel picks the grappling hook. Dipper is the only playable character (Doc 2 §0). The ownership transfer has to be recorded, or the item exists in narrative and not in the save.

**Chapter 1 grants nothing playable.** The hook enters the save as a party item flagged to Mabel:

```gdscript
GameState.data.inventory[&"grappling_hook"] = 1
GameState.data.flags[&"ch01_grapple_owner"] = &"mabel"     # not yet Dipper's
```

While `ch01_grapple_owner == &"mabel"`, the hook does **not** appear in Doc 4 §6.3's items grid, is not selectable in the radial, and `item_use` cannot fire it. It is visible in the Journal's Items tab as a greyed entry captioned in Mabel's voice, which is the only place the player learns it exists as a real object.

**Chapter 2 performs the handoff** in one scripted beat: Mabel gets bored of it inside a day, and it moves to Dipper. That sets `ch01_grapple_owner = &"dipper"`, at which point Doc 2 §7.2's 20-stamina grapple becomes a live verb.

Two reasons to split it across chapters rather than granting it here. It is funnier — the joke is that she loses interest, and the joke needs a gap to land in. And it keeps Chapter 1's verb count honest: the slice already teaches move, run, interact, journal, scan, UV, attack, dodge, item use, and drive. An eleventh verb in the final two minutes would be taught to nobody.

§14 check 14 asserts the hook is un-equippable while owned by Mabel — the one place a player could otherwise carry a Chapter 2 verb into a Chapter 1 replay.

> [TRANSCRIPT: gift shop — Mabel's reaction to the grappling hook]
> **Mabel** (`delighted`, `[rainbow]`, fallback): "Grappling hook! I'm never walking anywhere again!"
> **Stan** (`gruff`): "That was forty dollars of merchandise."
> **Dipper:** "You said one item each."
> **Stan:** "I say a lot of things."

The grappling hook going to Mabel and the verb going to the player is intentional. Chapter 2 explains it in one line: she gets bored of it in a day.

### 9.3 The Journal entry

In the attic, Dipper writes. The player is handed the pen: a short text-entry beat where the weakness field of `entry_gnomes` is filled in.

The field accepts anything. Typing nonsense is permitted and the game does not correct it — but the canonical `leaf blowers` earns `ch01_weakness_written` and a small gold flourish. This is the chapter's thesis made interactive: the player added to the Journal.

The UI collects the text and nothing more. It enqueues `JOURNAL_SUBMIT_REQUEST { kind: weakness, target: entry_gnomes, text }` (Doc 00 §8.3); the resolver calls `JournalDB.submit_weakness()` at priority 12, writes `GameState.data.journal_overrides`, marks the save dirty, and emits `journal_submit_committed` for the page to render from. Whatever the player typed is on that page for the rest of the playthrough, in their words, and it survives every reload.

### 9.4 The stinger

Player control returns for ~20 seconds in the gift shop, at night, with nothing to do.

`prop_vending_machine` is interactable and **refuses**: Dipper notes it is unplugged and the coin slot is fake. `zone_vending_code_known` stays false. Then a scripted beat — Stan crosses behind the player, the vending machine opens, and the scene cuts before the player can reach it.

No dialogue. No stinger sound. Doc 5's `bgm_shack` simply stops.

Then `CHAPTER_ADVANCE_REQUEST { to: 2, from: 1 }` per Doc 00 §9.4.

---

## 10. Flags & objectives

All flags carry the `ch01_` prefix per Doc 00 §9.2, except the two shared-namespace writes noted.

| Flag | Set by | Read by |
|---|---|---|
| `ch01_met_stan` | §4.2 | §4.5 errand gate |
| `ch01_met_soos` · `ch01_met_wendy` | §4.2 | Ch 2 greeting variants |
| `ch01_flyers_stapled` (int 0–3) | §5.2 | `ch01_o5_flyers` |
| `ch01_journal_acquired` | §5.4 | **Everything.** Mirrors `inventory["journal_3"]`, which is the actual gate the resolver reads |
| `ch01_uv_acquired` | §5.4 | Doc 2 §5.5 `F` binding. Granted with the Journal, never separately |
| `ch01_gnomes_scanned` | §5.6 | `entry_gnomes` unlock |
| `ch01_norman_scanned` | §6.4 | `ch01_o11_follow` gate |
| `ch01_norman_revealed` | §6.5 | Boss start |
| `ch01_boss_defeated` | §7.3 | §9.1 reward |
| `ch01_grapple_owner` (StringName) | §9.2 | Ch 2 handoff; gates the grapple verb |
| `ch01_weakness_written` | §9.3 | Ch 20 Zodiac epilogue text |
| `ch01_cipher_solved` | §8.1 | Optional; Ciphers tab count |
| `zone_shack_unlocked` | §4.1 | Shared namespace — Doc 3 zone gating |
| `npc_wendy_trust` = 1 | §4.4 | Shared namespace — Ch 6+ |

`ch01_journal_acquired` mirrors `inventory["journal_3"]`, and the inventory entry — not the flag, and never a runtime `InputMap` edit — is what the resolver actually gates on (Doc 2 §3.5). Keeping the gate in inventory rather than in the input map is what makes it survive a remap, a reload, and a stale `user://settings.cfg`, none of which a runtime binding would. It is still the one piece of state whose absence would make a mid-chapter save unplayable if it were ever cleared — §14 check 4 covers both halves.

---

## 11. System coverage matrix

**This is the gate.** Every row must be observable by a human playing the slice, or the checkpoint is not measuring what it claims to.

| Doc | System | Where in Ch 1 | Observable as |
|---|---|---|---|
| 1 §1 | Zone palettes | Shack ↔ woods ↔ interiors | Color grade shifts on entry |
| 1 §2 | Weirdness shader | Act 0 (0.55), §5.3 pulse, boss (0.60) | Aberration + vignette |
| 1 §3–7 | Character rigs, 8-dir anim | Throughout | Dipper, Mabel, 4 NPCs, gnomes |
| 2 §1.2 | Fake-Z `HeightBody` | Thrown gnomes, phase 1 | Shadow shrink on arc |
| 2 §3 | Movement, run, stamina | §5.2 flyer 3 | Stamina ribbon drains |
| 2 §3.4 | Dodge + i-frames | §5.8 | Roll, brief invulnerability |
| 2 §4 | Melee, item use | §5.8, §7.3 | Attack, leaf blower |
| 2 §5.1–5.3 | Journal state machine | §5.4 onward | Open 0.42 s, camera offset |
| 2 §5.2 | **Fumble** | §5.8 | Book dropped, 0.80 s lockout |
| 2 §5.4 | Scan | §5.6, §5.7, §6.4 | Ring fills, entry unlocks |
| 2 §5.5 | UV | §8.2 | Beam, ink reveal |
| 2 §5.6 | Ciphers | §8.1 | Decode pane, live preview |
| 2 §6.1 | Anomaly fields | §7.1 slam | Knockback from `PUSH` |
| 2 §7 | Health, blackout, checkpoint | §7.2 failure | Respawn, no progress lost |
| 2 §9 | Companion follower | §6.2 — all seven states | Follows, despawns, escorts |
| 3 §2 | Layer stack, Y-sort | Throughout | Dipper behind/in front of trees |
| 3 §2.2 | Canopy fade | `z_woods_south` | Canopy goes translucent |
| 3 §3 | **Streaming + seam** | §5 crossing | No hitch, no fade |
| 3 §6 | Secret triggers | §8.2, §8.3 | UV markings, sigils |
| 3 §7 | Vehicle handling | Act 0, §7.2 | Cart steering |
| 3 §8 | Interiors | §4.2 | Door wipe, camera bounds |
| 4 §2 | HUD | Throughout | Pine pips, ribbon, item slot |
| 4 §2.7 | Contextual fade | Quiet woods vs. combat | Snap in, drift out |
| 4 §3 | Dialogue box + bubble | Throughout | Both modes, never box in combat |
| 4 §4 | Rich text, per-voice | Mabel, Dipper, Jeff | Rainbow, stutter, reveal rates |
| 4 §5 | Accessibility | Settings toggle | FX strip, text scale |
| 4 §6 | Journal UI, 5 tabs | §5.4 onward | All five tabs populated |
| 4 §7 | Menus, chapter card | Boot, §3, §9.4 | Main menu, card |
| 5 §1–2 | Buses, 4-stem rack | §5.3 unease rise | Stems shift with weirdness |
| 5 §3 | Zone crossfade | §5 seam | 2.5 s BGM blend |
| 5 §4.2 | Boss audio, phases | Act 4 | Cut on bar, phase changes |
| 5 §5 | SFX cues | Throughout | Journal, footsteps, combat |
| 5 §6 | Dialogue blips | All dialogue | Per-speaker pitch |
| 5 §7 | Procedural placeholders | Everywhere | **Ships with zero real audio** |
| 00 §3 | Boot, session | Launch | Menu → New Game → play |
| 00 §7 | Zone travel, both kinds | §5, §4.2 | Seamless and gated |
| 00 §9 | Save, autosave, chapter | §4.2, §9.4 | Quit and continue mid-chapter |
| 00 §10 | Pause | Anywhere | Esc, and it refuses mid-fade |
| 00 §11 | Blackout, respawn | §7.2 | Wake at checkpoint |
| 00 §11.2 | **Cross-zone respawn** | §7.2, dying after the seam | Destination zone re-mounts, boss resumes at phase 2 |

**Three systems are deliberately NOT exercised in Chapter 1**, and each is flagged so the gate does not falsely claim coverage:

| Not covered | First covered | Why not here |
|---|---|---|
| Time recorder / rewind (Doc 2 §6.2) | Ch 7 | No time mechanic in this episode |
| Boat traversal (Doc 3 §5.3) | Ch 2 | Lake is Ch 2 |
| Chapter Select scratch save (Doc 00 §9.5) | Needs 2 chapters | Nothing to select yet |


---

## 12. Build & run

### 12.1 Scenes to author

Placement follows Doc 1 §10's tree and its placement rule — nothing here invents a directory, and everything that exists only for this chapter lives under `chapters/ch01/`.

```
res://chapters/ch01/
├── ch01_director.gd          # objectives, flags, boss phases, chapter advance
├── ch01_dialogue.tres        # every DialogueLine in this doc
├── ch01_coldopen_path.tscn   # Act 0 scripted corridor
└── ch01_chase_path.tscn      # Act 4 phase 2 corridor

res://world/zones/            # scene stem == ZoneDef.id == .tres stem
├── z_shack_ext.tscn          # Doc 3 §10 checklist, all 11 items
├── z_woods_south.tscn        # ditto
├── int_giftshop.tscn         # ZoneDef, is_interior, bgm_shack
├── int_living_room.tscn      # bgm_shack — it is on the path to the attic
└── int_attic.tscn            # checkpoint, save point, Pine Tree sigil, bgm_attic
```

§14's asserts go into `res://tests/test_all.gd` with every other document's — one suite, one command.

Five zone scenes. `int_kitchen`, `int_stan_room`, and the lab levels are **not** authored in Chapter 1 — their doors exist and refuse.

### 12.2 Running it

```bash
godot --path . --verbose
```

One headless suite, which must pass before hand-play is meaningful:

```bash
godot --headless --script res://tests/test_all.gd
```

```bash
godot --headless --script res://tests/test_all.gd
```

### 12.3 Assets you need to supply

Everything below has a working placeholder per Doc 1 §9.3 and Doc 4 §9. **The slice is fully playable with zero supplied assets** — that is the point of Doc 5 §7's procedural bake and Doc 1's placeholder rigs.

| Asset | Spec | Count | Placeholder |
|---|---|---|---|
| Dipper rig | Doc 1 §3, pre- and post-hat | 2 | Procedural |
| Mabel, Stan, Soos, Wendy rigs | Doc 1 §3 | 4 | Procedural |
| Gnome rig | Doc 1 NPC template, small | 1 | Procedural |
| Gnomonster | Composite, 3 phase states | 1 | Stacked gnome instances |
| Portraits | 240×240, 4 expressions, 6 speakers | 24 | Placeholder head |
| Shack exterior props | Doc 3 §4.2 | ~20 | Palette blocks |
| Woods props, canopies | ditto | ~15 | Palette blocks |
| Interior props ×3 rooms | ditto | ~25 | Palette blocks |
| Journal page art | Doc 4 §9 | 6 pages | `journal_page` fills |
| Item icons | Journal, penlight, leaf blower, hat, grapple | 5 | 96×96 flats |
| Audio | Doc 5 §9 subset — `bgm_shack`, `bgm_woods`, **`bgm_attic`**, **`bgm_menu`**, `boss_gnome` | **20 stems** (5 pieces × 4) | **Procedural, baked offline** |

**The audio figure is five pieces, not three.** Chapter 1 reaches the main menu (`bgm_menu`, Doc 00 §3.1 and `end_session()`) and the attic (`bgm_attic`, Doc 5 §4.1's safety cue, and the chapter ends there). Counting only the two exteriors and the boss misses both. Note also that **`int_living_room` must carry a `bgm_id`** — `bgm_shack`, since it is the Shack — because it sits on the mandatory path to the attic and Doc 5 §3's `set_zone` now hard-errors on an unregistered id rather than crashing on a null stem.

Across the whole chapter roughly **80 of Doc 5 §9's 192 slots** are touched once footsteps, blips, Journal cues, UI and ambience are counted — but they need only about **12 distinct placeholder sources**: four oscillator recipes cover all 20 stems, footstep variants are pitch-shifts of one noise burst, and the UI cues are three envelopes. The 192-file manifest is a purchase order for a composer, not a checklist to work through before the slice is playable.

---

## 13. The decision gate

The reason this chapter exists in this form. Play it start to finish, then answer these. Each has a **stated pivot** — the change to make now, while one chapter is written and nineteen are not.

| # | Question | If the answer is bad | Pivot |
|---|---|---|---|
| 1 | Does reading the Journal mid-combat ever feel worth it? | Nobody opens it in a fight | Raise `journal_speed`, or cut `FUMBLE_DURATION` (Doc 2 §10). If neither helps, **the live-world Journal is wrong** and it becomes a pause screen — a Doc 2 §0 reversal, cheap now, catastrophic at Ch 10 |
| 2 | Does the seamless crossing actually hide the seam? | Visible hitch or audio pop | Raise `STREAM_MARGIN` (Doc 3 §3.3). If the hitch is texture upload, not load time, **reconsider seam model B entirely** and make all Act I travel gated |
| 3 | Is 3/4 top-down readable with `DEPTH_RATIO = 0.62`? | Diagonals feel wrong, depth unclear | Retune the ratio. If it still reads flat, the shadow/`HeightBody` language needs strengthening before any zone art is painted |
| 4 | Does the Weirdness float driving both shader and stems read as one thing? | Effects feel unrelated | This coupling is Doc 1 §12.4's core bet. Decouple into separate visual/audio curves now, or commit |
| 5 | Is the web export viable at this scale? | Frame drops, long load, audio underrun | Doc 1 §2.1's backbuffer note and Doc 3 §3.4's 90 MB budget are the first suspects. Worst case, **drop the web target** — a Doc 1 §0 decision |
| 6 | Does a 40–50 min chapter feel like a chapter? | Too short / too long | Rescope the 20-chapter plan to 15 or 25 before Chapter 2 |
| 7 | Does the "Journal has no answer" beat land, or read as a bug? | Players think the scan failed | Strengthen the presentation — blank ruled lines, Dipper's line, an explicit HUD empty-state. Do not add a weakness |
| 8 | Is the boss fun without a health bar? | Feels arbitrary | The leadership mechanic may need a visible gauge — "gnome cohesion" — rather than reverting to HP |
| 9 | Is placeholder-everything actually playable? | Can't tell what anything is | Doc 1's placeholder strategy needs work before 19 more chapters depend on it |
| 10 | Did the tick contract hold under a real chapter? | Any Doc 00 §12 check goes red in play but green headless | The harness is testing the wrong thing. Fix the harness before Chapter 2 |
| **11** | **Does a real texture survive the hose bend?** | Stripes pinch, or the fill folds past ~90° of elbow | Go to **three bones per limb** (`b_arm_l_upper → b_arm_l_mid → b_arm_l_fore`) with two overlapping blend bands. Still one polygon, one texture, authored straight, same `hose_texture_size` — **the asset manifest does not change at all.** It is a rig-file change plus `hose_weights` returning `Vector3` |
| **12** | **(web)** Does the build actually hold on a real itch.io upload? | Seam hitches, save does not survive a reload, or the tab locks at boot | Threads (Doc 3 §3.3) and `OS.is_userfs_persistent()` (Doc 00 §9.1) are the two suspects. Fallback is **all Act I travel gated** — every boundary already authors a `GateTransition`. Web is best-effort (Doc 1 §0); macOS native is the target and takes precedence |

Questions 1, 2, 4, 5, and 11 are the expensive ones. Question 11 is new and it is the one this gate would otherwise miss entirely.

**Why 11 and 12 had to be added.** Every other row is exercised by playing the slice — but §12's whole premise is that the chapter is *fully playable with zero supplied assets*, and that is exactly what hides the two least-reversible decisions in the project. The hose rig fails only under a real texture; the web export fails only on a real upload. Neither condition occurs while playing the placeholder build, so a gate made only of the first ten questions passes cleanly while both risks sit untouched.

Question 11 costs one PNG. **Author a single limb texture — a straight vertical bar with three evenly spaced horizontal stripes — assign it to Dipper's `arm_hose_l`, and play `walk` and `run`.** If the stripes stay evenly spaced through the elbow, the two-bone assumption holds and every character can be rigged against it. If they pinch, take the three-bone fallback while exactly one texture exists rather than after thirty characters are drawn to the spec. Doc 1 §11's blend-band assert catches the *geometry* failure; only a real texture catches the *deformation* one.

---

## 14. Validation

```gdscript
# res://tests/test_all.gd
# godot --headless --script res://tests/test_all.gd
extends SceneTree

func _init() -> void:
	# --- 1. The chapter cipher must be the episode's own -------------------
	assert(Cipher.caesar("ZHOFRPH WR JUDYLWB IDOOV", -3) == "WELCOME TO GRAVITY FALLS",
		"Ch 1 cryptogram must decode with the Doc 3 §6.1 Caesar shift")

	# --- 2. The gnome entry must ship WITHOUT a weakness (§0.1) ------------
	var e := JournalDB.entry(&"entry_gnomes")
	assert(e.weakness.is_empty(),
		"entry_gnomes must ship blank — the player writes it in (§9.3)")
	assert(not JournalDB.is_verified(&"entry_gnomes")
		and JournalDB.damage_multiplier(&"entry_gnomes") == 1.0,
		"a scan with no weakness must grant no damage bonus")
	assert(not e.accepted_answers.is_empty(),
		"a deliberately blank entry must still declare what would verify it")

	# --- 3. Every flag this chapter writes is in its own namespace --------
	# A STATIC SCAN over the chapter's source, not a walk over a hand-maintained
	# constant. A director that writes an out-of-namespace flag simply would not
	# have added itself to a WRITTEN_FLAGS list, and the check would pass forever
	# over an incomplete array — a green tautology, which is worse than no test
	# because it retires the concern. Doc 00 §12 checks 10 and 30 scan for the
	# same reason.
	var flag_writes := RegEx.create_from_string(r'flags\[&"([a-z0-9_]+)"\]\s*=')
	for path in _gd_files("res://chapters/ch01/"):
		for m in flag_writes.search_all(FileAccess.get_file_as_string(path)):
			var f: String = m.get_string(1)
			assert(f.begins_with("ch01_") or f.begins_with("zone_")
				or f.begins_with("npc_") or f.begins_with("sys_"),
				"Ch 1 wrote out-of-namespace flag: %s (%s)" % [f, path])

	# --- 4. Journal acquisition gates the verb, and survives a save -------
	GameState.new_game()
	var s := GameState.data
	assert(not s.flags.get(&"ch01_journal_acquired", false),
		"the Journal verb must start locked")
	s.flags[&"ch01_journal_acquired"] = true
	var round_trip := GameState.deserialize(GameState.serialize(s))
	assert(round_trip.flags.get(&"ch01_journal_acquired", false),
		"journal acquisition must survive a save round-trip")
	# The gate is inventory at the resolver, never an unbound action (Doc 2 §3.5).
	assert(InputMap.has_action(&"journal") and InputMap.has_action(&"scan"),
		"verbs are bound at boot and refused at the resolver, never left unbound")

	# --- 5. The cart is a set-piece, never property (§7.2) ----------------
	# Assert the OUTCOME, not a self-declared constant.
	var hcart := Ch01Harness.new()
	hcart.play_through()
	assert(not GameState.data.inventory.has(&"golf_cart"),
		"Ch 1 must not add the cart to inventory — Doc 3 §7 unlocks it at Ch 9")

	# --- 6. No authored line may be BOX during combat (Doc 4 §11.1) -------
	CombatDirector.threat_active = true
	for line in Ch01Dialogue.combat_lines():
		assert(DialogueLine.resolve_mode(line) == DialogueLine.Mode.BUBBLE,
			"Ch 1 combat line would render as BOX: %s" % line.speaker_id)
	CombatDirector.threat_active = false

	# --- 7. Boss phases advance monotonically and end the fight -----------
	var phases: Array[int] = Ch01Director.BOSS_PHASE_SEQUENCE
	for i in range(1, phases.size()):
		assert(phases[i] == phases[i - 1] + 1, "boss phases must not skip")
	assert(phases.back() == 3, "Gnomonster must resolve at phase 3")

	# --- 8. Chapter advance is exactly +1 (Doc 00 §9.4) -------------------
	assert(Ch01Director.ADVANCE_TO == 2 and Ch01Director.ADVANCE_FROM == 1,
		"chapter advance must be monotonic by one")

	# --- 9. Every objective is reachable from the flags that gate it ------
	for o in Ch01Director.OBJECTIVES:
		assert(Ch01Director.is_satisfiable(o),
			"objective has an unsatisfiable precondition: %s" % o)

	# --- 10. Every zone this chapter names exists in the Doc 3 registry ---
	for z in Ch01Director.ZONES:
		assert(ZoneManager.has_def(z), "Ch 1 references unregistered zone: %s" % z)

	# --- 11. Mabel's follower is genuinely freed, not just hidden (§6.2) --
	var h := Ch01Harness.new()
	h.advance_to(&"ch01_journal_acquired")
	h.run_ticks(360)                       # cover the 6 s scripted exit
	assert(h.follower_instance_count() == 0,
		"Mabel's follower must be freed during state 3, not parked off-screen")
	h.advance_to(&"ch01_boss_defeated")
	assert(h.follower_instance_count() == 1,
		"state 7 (Follower) must instantiate exactly one new follower")

	# --- 12. Cross-zone respawn resumes the fight, not restarts it (§7.2) -
	h.reset()
	h.enter_boss_phase(2)
	h.cross_seam_to(&"z_shack_ext")
	h.kill_player()
	h.run_until_player_free()
	assert(ZoneManager.current_zone == &"z_woods_south",
		"respawn must re-mount the checkpoint's zone")
	assert(CombatDirector.boss_active, "the boss fight is still on after a respawn")
	assert(CombatDirector.boss_phase == 2, "respawn must resume phase 2, not phase 1")
	assert(h.mabel_state == Ch01Harness.MabelState.ESCORT, "Mabel returns as escort")
	h.defeat_boss()
	assert(GameState.data.checkpoint.encounter.is_empty(),
		"defeating the boss must clear the encounter block, or the clearing stays haunted")

	# --- 13. Mabel's states never overlap (§6.2) --------------------------
	h.reset()
	var seen: Array[int] = []
	h.play_through(func(state: int) -> void:
		if seen.is_empty() or seen.back() != state:
			assert(not seen.has(state) or state == Ch01Harness.MabelState.FOLLOWER,
				"Mabel re-entered a non-follower state: %d" % state)
			seen.append(state))
	assert(h.concurrent_mabel_nodes_max() == 1,
		"captive, escort, and decoy must never be live at the same time")

	# --- 14. The grapple is inert while Mabel owns it (§9.2) --------------
	GameState.new_game()
	var g := GameState.data
	g.inventory[&"grappling_hook"] = 1
	g.flags[&"ch01_grapple_owner"] = &"mabel"
	assert(not ItemDB.is_equippable(&"grappling_hook", g),
		"the hook must not be usable until Ch 2's handoff")
	g.flags[&"ch01_grapple_owner"] = &"dipper"
	assert(ItemDB.is_equippable(&"grappling_hook", g),
		"the hook must become usable once transferred")

	# --- 15. The incomplete-entry branch, both directions (§5.7) ---------
	GameState.new_game()
	const GN := &"entry_gnomes"
	assert(JournalDB.weakness_written(GN).is_empty()
		and JournalDB.damage_multiplier(GN) == 1.0,
		"a blank entry starts unwritten and grants no bonus")

	assert(JournalDB.submit_weakness(GN, "banana") == false, "nonsense must not verify")
	assert(JournalDB.weakness_written(GN) == "banana",
		"nonsense is still written to the page, verbatim — it just earns nothing")
	assert(JournalDB.damage_multiplier(GN) == 1.0, "an unverified entry grants no bonus")

	assert(JournalDB.submit_weakness(GN, "  Leaf Blowers ") == true,
		"case, whitespace, plural, and articles must all normalize")
	assert(JournalDB.damage_multiplier(GN) == 1.45,
		"a verified entry grants the bonus retroactively")

	# --- 16. The player's writing survives a reload (Doc 00 §9.2.1) ------
	var reloaded := GameState.deserialize(GameState.serialize(GameState.data))
	assert(reloaded.journal_overrides[GN][&"weakness_written"] == "  Leaf Blowers ",
		"the player's exact text must round-trip")
	assert(reloaded.journal_overrides[GN][&"weakness_verified"],
		"the verified bonus must survive a reload")

	# --- 17. A new game carries no handwriting from the last one ---------
	GameState.new_game()
	assert(GameState.data.journal_overrides.is_empty(),
		"JournalEntry resources are shared — a new game must start clean")
	assert(JournalDB.damage_multiplier(GN) == 1.0,
		"the previous playthrough's bonus must not leak into a new game")

	# --- 18. Ford's own entries are trusted without verification ----------
	# entry_shapeshifter is authored WITH a weakness and is never scanned in Ch 1
	# — it is the control case for "a populated entry needs no player input".
	# entry_zombie is deliberately NOT used here: §6.4's Norman scan must not
	# unlock it, or a wrong identification would hand out a permanent +45%.
	assert(JournalDB.is_verified(&"entry_shapeshifter")
		and JournalDB.damage_multiplier(&"entry_shapeshifter") == 1.45,
		"an authored weakness needs no player verification")
	assert(not GameState.data.journal_entries.has(&"entry_zombie"),
		"Norman's scan must not unlock the zombie entry — see §6.4")

	# --- 19. The encounter block is armed by event, never written --------
	# Another STATIC SCAN. The previous form iterated a hand-maintained
	# DIRECT_GAMESTATE_WRITES constant and asserted false inside the loop — over
	# an array that is empty by construction, since a director that writes
	# GameState directly would not list itself. It could never fail. Doc 00 §12
	# check 30 scans res://ui/ for exactly this reason.
	var direct_write := RegEx.create_from_string(r'GameState\.data\.\w+\s*(\[|=[^=])')
	for path in _gd_files("res://chapters/ch01/"):
		var src := FileAccess.get_file_as_string(path)
		assert(direct_write.search(src) == null,
			"Ch01Director must not write GameState directly (%s) — arm it with an event" % path)

	print("ch01: all checks passed")
	quit()

## Every .gd under a directory, recursively. Used by the static scans above.
static func _gd_files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in ResourceLoader.list_directory(dir):
		if f.ends_with("/"):
			out.append_array(_gd_files(dir + f))
		elif f.ends_with(".gd"):
			out.append(dir + f)
	return out
```

Check 2 is the one to watch. It is the only automated test in the project whose purpose is to stop a future contributor from "fixing" a deliberate design decision.

**Checks 3, 5, and 19 are static scans, deliberately.** Each was originally a loop over a constant the chapter declared about itself — `WRITTEN_FLAGS`, `GRANTS_VEHICLE`, `DIRECT_GAMESTATE_WRITES`. A chapter that breaks one of those rules would not have added itself to the list, so those checks were green over empty arrays and could not fail. **A test that cannot fail is worse than no test: it retires the concern.** These three enforce the invariants that have to hold across twenty chapter docs written months apart, which is exactly where a self-declared constant rots first.

---

## 15. Contracts this chapter exports

1. **Chapter 1 is the vertical slice.** Every system in Docs 1–5 is exercised here at least once, per §11's matrix, or explicitly listed as deferred.
2. The Journal ships with `entry_gnomes` weakness blank. The player writes it. No later chapter may pre-fill it.
3. The golf cart is a scripted set-piece in Chapter 1 and grants no persistent vehicle. Doc 3 §7's Chapter 9 unlock stands.
4. Jeff is in Doc 4 §4.4's speaker table and Doc 5 §6's blip table: 52 cps, `moss` tint, blip 1.22 / ±0.09.
5. `boss_gnome`'s three phases are defined here; Doc 5 §4.2 gates them on `CombatDirector.boss_phase`.
6. The UV penlight is Chapter 1's only invented item, taken to exercise Doc 2 §5.5. It is a flagged deviation (§5.5), not a precedent.
7. The grappling hook is granted at chapter end and is usable from Chapter 2 (Doc 2 §7.2 pricing).
8. Chapter 1 writes only `ch01_`, `zone_`, and `npc_` flags, per Doc 00 §9.2.
9. `JournalEntry.weakness` may ship deliberately empty. **Written and verified are separate:** the page renders whatever the player typed, and only a match against `accepted_answers` earns Doc 2 §5.4's ×1.45.
9a. The player's writing lives in `GameState.data.journal_overrides` and is read through `JournalDB` (Doc 00 §9.2.1). No chapter mutates a `JournalEntry` resource.
10. Chapter 1 grants no usable grapple. `ch01_grapple_owner` gates the verb, and Chapter 2 performs the handoff.
11. Act 0 seeds `cp_ch01_coldopen` and is resumable. The rewind handoff declares a `TransitionTeardown` (Doc 00 §7.4.1); `Ch01Director` commits nothing itself.
12. The first Journal open is a cutscene `on_complete_intent` (Doc 00 §8.2.1), so it plays the ordinary `OPENING` path and can lose to a same-tick hit.
13. The phase-2 checkpoint carries an `encounter` block, armed and cleared by `ENCOUNTER_STATE_REQUEST` (Doc 00 §11.3). `Ch01Director` writes no `GameState` field directly — its entire mutation surface is enqueued events and two declarative resources.
14. Mabel occupies exactly one of the seven states at a time (§6.2); captive, escort, and decoy never overlap.
15. Chapter 2 opens the morning after, at the attic checkpoint, with the Journal, penlight, and hat in hand — and the grapple in Mabel's.
