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
| Mabel | Companion → absent → escort, within one chapter | Exercises Doc 2 §9's follower in all three states |
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

Jeff is Chapter 1's addition to the roster. He is not in Doc 4 §4.4's table — add him: **reveal 52 cps, no wrapper by default, name tint `#6B8F4E` (`moss`), blip pitch 1.22 / variance ±0.09, timbre reedy square.** His register is a salesman's: warm, over-familiar, and it drops to flat menace the instant he is refused. That switch is the character.

### 2.2 Authoring rules carried from Doc 4

- Every mid-fight line is `Mode.BUBBLE`. Doc 4 §3.2 downgrades a `BOX` during combat and warns; Chapter 1 must never trigger that warning. §14 check 6 asserts it.
- Dipper's anxious lines set `anxious = true` for Doc 4 §4.3's stutter. Use it in Act 2 (alone in the woods) and Act 3 (Mabel taken), **not** in Act 0 — the cold open is Dipper narrating after the fact, and he is calm about it.
- Mabel's `[rainbow]` wrapper is her default. Drop it for exactly one line, in Act 3 when she realizes what Norman is. The absence lands harder than any effect.
- No line needs `pause_player` — that field is gone (Doc 00 §8.3). Lines that hold the player are authored as cutscenes.

### 2.3 Dialogue fidelity

Lines below are **authored in-voice**, not transcribed. They carry the scene's intent and each character's register per Doc 4 §4.4, and the chapter is complete and buildable as written.

Where a moment is iconic enough that fans would notice a substitution, the line is marked:

```
[TRANSCRIPT: gift shop — Mabel's reaction to the grappling hook]
```

Paste the exact line from the episode yourself if you want verbatim fidelity. Every marker has a working authored fallback beside it, so the build never blocks on an unfilled marker. There are **9 markers** in this chapter, all in Acts 0, 3, 4, and 5.

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
7. Chapter card (Doc 4 §7.4) wipes to Act 1.
```

**Why it cannot be failed:** the player has had the controller for eleven seconds. A death here teaches nothing and costs a first impression. `Health` is present and the HUD is live so the player learns to read it, but every hitbox in Act 0 is disabled.

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
| `door_giftshop` | `z_shack_ext` | Enter | Gated interior, 0.25 s wipe (Doc 00 §7.6) |
| `npc_soos` | `int_giftshop` | Talk | Sets `ch01_met_soos` |
| `npc_wendy` | `int_giftshop` | Talk | Sets `ch01_met_wendy` |
| `prop_vending_machine` | `int_giftshop` | Turn | **Refused** — see §9.3 |
| `prop_attic_bed` | `int_attic` | Rest | Checkpoint + autosave (Doc 00 §9.1) |
| `sigil_pine_tree` | `int_attic` | — | Granted on first entry (Doc 3 §6.2) |

### 4.3 Dialogue

> **Stan** (`grifting`, box): "You must be the kids. Congratulations, you're employees now. Don't touch anything with a price tag, and everything's got a price tag."
> **Dipper** (`anxious`): "We just got here."
> **Stan:** "And already you're behind."

> **Soos** (`cheerful`, `[wave]`, box): "Hey. Hey, you're the new kids. I'm Soos. I fix stuff, mostly by hitting it. Sometimes that's the right call."
> **Wendy** (`bored`, box, from behind the counter): "Don't let him sell you a mystery. They're all just raccoons in hats."
> **Soos:** "One of them is a raccoon in a hat. The rest are legit, dude."

Wendy's line is doing structural work: it plants the tourist-trap framing the whole game will spend twenty chapters undermining.

### 4.4 The errand

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

1. `GameState.inventory[&"journal_3"] = 1`.
2. `Journal` autoload becomes available; `J` is bound and the Doc 4 §2.4 spine tab fades in bottom-left with a gold pulse.
3. `Weirdness.pulse(0.65, 1.4)` — the single largest spike in Act 2.
4. A forced-first-open cutscene: the Journal opens itself, one page, Ford's hand.
5. Control returns with the Journal `OPEN`, so the player's first Journal experience is already inside the book.

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

### 5.7 Combat introduction

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

| ID | Objective | Completion |
|---|---|---|
| `ch01_o9_norman` | Find out what Norman is | Scan Norman |
| `ch01_o10_follow` | Follow Mabel | Reach the clearing |
| `ch01_o11_rescue` | Get Mabel back | Boss defeated (Act 4) |

### 6.2 Mabel departs

Back at the Shack, Mabel leaves with Norman. Companion despawns — and this is deliberately load-bearing: Doc 2 §9's follower is created, destroyed, and recreated within one chapter, so a leak shows up at the gate rather than in Chapter 12.

> **Mabel** (`smitten`, `[rainbow]`): "His name is Norman and he's TALL and he doesn't talk much which I think means he's mysterious!"
> **Dipper** (`anxious`): "Or it means something's wrong with his throat."
> **Mabel:** "Mysterious throat!"

### 6.3 Dipper's wrong theory

The player scans Norman at range. The scan returns `entry_zombie` as a **partial match with a confidence warning** — Ford's zombie page, flagged as inconclusive.

Dipper concludes zombie. He is wrong. The game does not correct him; the player finds out with him.

Mechanically this is a second, quieter lesson: a scan can mislead. It rhymes with §0.1 and it is the last time the game undermines the Journal for a long while.

### 6.4 The clearing

Dipper arrives to find Norman coming apart. Five gnomes, one trenchcoat.

Cutscene, `CUTSCENE_REQUEST` per Doc 00 §8.2, with `on_complete_flag = ch01_norman_revealed`. Combat begins immediately on completion — which tests Doc 00 §8.1's ordering, since the boss's first hitbox arms on the same tick control returns.

> **Jeff** (`charming`, bubble): "Hi there! Big misunderstanding. We're not a boyfriend. We're a committee."
> **Mabel** (`defiant`, **no `[rainbow]`**): "You lied about your whole entire body."
> [TRANSCRIPT: the reveal — Jeff's proposal to Mabel]
> **Jeff** (`furious`): "Then we do this the traditional way. Gnomes! Assemble the big guy!"

---

## 7. Act 4 — The Gnomonster

**Boss:** `boss_gnome` (Doc 5 §4.2). **Phases:** 3. **Length:** ~6 min.

`CombatDirector.boss_active = true`, `boss_phase` advanced by this document. Doc 5 §4.2 lists `boss_gnome` as single-stem; Chapter 1 amends that to **phase-gated on `boss_phase`**, matching the pattern `boss_gideonbot` already uses.

### 7.1 Phase 1 — The clearing (on foot)

| Property | Value |
|---|---|
| Player state | `FREE` |
| Gnomonster | Stationary, sweeps a fist arm across the clearing |
| Attack 1 | Ground slam — telegraphed 0.9 s, `PUSH` anomaly field on impact (Doc 2 §6.1) |
| Attack 2 | Gnome throw — a single gnome as a projectile, dodgeable |
| Damage source | Loose gnomes, 1 pip each |
| Exit condition | Survive 45 s, or knock 6 gnomes loose with melee |
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
| Failure | Blackout → checkpoint at the clearing entrance, phase 2 restarts |
| Weirdness | 0.60 |
| Exit condition | Reach `z_shack_ext` — **crosses a zone boundary while `DRIVING`** |

That last row is not incidental. Doc 00 §5.3 asserts vehicles cross boundaries; this is the chapter that proves it, under threat, with an escort NPC and an active boss. If it breaks, it breaks here rather than in Chapter 9 when the cart is real.

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
| 3 | `dread` solo, then hard stop on the fire | §4.2 |

The hard stop in phase 3 is a beat of near-silence before the collapse SFX. It costs nothing and it is the loudest moment in the chapter.

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
| Mabel | Grappling hook | **Verb unlock.** Doc 2 §7.2's 20-stamina grapple, usable from Ch 2 |

> [TRANSCRIPT: gift shop — Mabel's reaction to the grappling hook]
> **Mabel** (`delighted`, `[rainbow]`, fallback): "Grappling hook! I'm never walking anywhere again!"
> **Stan** (`gruff`): "That was forty dollars of merchandise."
> **Dipper:** "You said one item each."
> **Stan:** "I say a lot of things."

The grappling hook going to Mabel and the verb going to the player is intentional. Chapter 2 explains it in one line: she gets bored of it in a day.

### 9.2 The Journal entry

In the attic, Dipper writes. The player is handed the pen: a short text-entry beat where the weakness field of `entry_gnomes` is filled in.

The field accepts anything. Typing nonsense is permitted and the game does not correct it — but the canonical `leaf blowers` earns `ch01_weakness_written` and a small gold flourish. This is the chapter's thesis made interactive: the player added to the Journal.

### 9.3 The stinger

Player control returns for ~20 seconds in the gift shop, at night, with nothing to do.

`prop_vending_machine` is interactable and **refuses**: Dipper notes it is unplugged and the coin slot is fake. `zone_vending_code_known` stays false. Then a scripted beat — Stan crosses behind the player, the vending machine opens, and the scene cuts before the player can reach it.

No dialogue. No stinger sound. Doc 5's `bgm_shack` simply stops.

Then `CHAPTER_ADVANCE_REQUEST { to: 2, from: 1 }` per Doc 00 §9.4.

---

## 10. Flags & objectives

All flags carry the `ch01_` prefix per Doc 00 §9.2, except the two shared-namespace writes noted.

| Flag | Set by | Read by |
|---|---|---|
| `ch01_met_stan` | §4.2 | §4.4 errand gate |
| `ch01_met_soos` · `ch01_met_wendy` | §4.2 | Ch 2 greeting variants |
| `ch01_flyers_stapled` (int 0–3) | §5.2 | `ch01_o5_flyers` |
| `ch01_journal_acquired` | §5.4 | **Everything.** Global gate on the `J` binding |
| `ch01_uv_acquired` | §5.5 | Doc 2 §5.5 `F` binding |
| `ch01_gnomes_scanned` | §5.6 | `entry_gnomes` unlock |
| `ch01_norman_revealed` | §6.4 | Boss start |
| `ch01_boss_defeated` | §7.3 | §9.1 reward |
| `ch01_weakness_written` | §9.2 | Ch 20 Zodiac epilogue text |
| `ch01_cipher_solved` | §8.1 | Optional; Ciphers tab count |
| `zone_shack_unlocked` | §4.1 | Shared namespace — Doc 3 zone gating |
| `npc_wendy_trust` = 1 | §4.3 | Shared namespace — Ch 6+ |

`ch01_journal_acquired` is the only flag in the chapter that alters the input map at runtime. It is worth calling out because it is the one flag whose absence would make a mid-chapter save unloadable if it were ever cleared — §14 check 4 covers it.

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
| 2 §3.4 | Dodge + i-frames | §5.7 | Roll, brief invulnerability |
| 2 §4 | Melee, item use | §5.7, §7.3 | Attack, leaf blower |
| 2 §5.1–5.3 | Journal state machine | §5.4 onward | Open 0.42 s, camera offset |
| 2 §5.2 | **Fumble** | §5.7 | Book dropped, 0.80 s lockout |
| 2 §5.4 | Scan | §5.6, §6.3 | Ring fills, entry unlocks |
| 2 §5.5 | UV | §8.2 | Beam, ink reveal |
| 2 §5.6 | Ciphers | §8.1 | Decode pane, live preview |
| 2 §6.1 | Anomaly fields | §7.1 slam | Knockback from `PUSH` |
| 2 §7 | Health, blackout, checkpoint | §7.2 failure | Respawn, no progress lost |
| 2 §9 | Companion follower | §4.4, §6.2, §7.2 | Follows, despawns, escorts |
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
| 4 §7 | Menus, chapter card | Boot, §3, §9.3 | Main menu, card |
| 5 §1–2 | Buses, 4-stem rack | §5.3 unease rise | Stems shift with weirdness |
| 5 §3 | Zone crossfade | §5 seam | 2.5 s BGM blend |
| 5 §4.2 | Boss audio, phases | Act 4 | Cut on bar, phase changes |
| 5 §5 | SFX cues | Throughout | Journal, footsteps, combat |
| 5 §6 | Dialogue blips | All dialogue | Per-speaker pitch |
| 5 §7 | Procedural placeholders | Everywhere | **Ships with zero real audio** |
| 00 §3 | Boot, session | Launch | Menu → New Game → play |
| 00 §7 | Zone travel, both kinds | §5, §4.2 | Seamless and gated |
| 00 §9 | Save, autosave, chapter | §4.2, §9.3 | Quit and continue mid-chapter |
| 00 §10 | Pause | Anywhere | Esc, and it refuses mid-fade |
| 00 §11 | Blackout, respawn | §7.2 | Wake at checkpoint |

**Four systems are deliberately NOT exercised in Chapter 1**, and each is flagged so the gate does not falsely claim coverage:

| Not covered | First covered | Why not here |
|---|---|---|
| Time recorder / rewind (Doc 2 §6.2) | Ch 7 | No time mechanic in this episode |
| Boat traversal (Doc 3 §5.3) | Ch 2 | Lake is Ch 2 |
| Chapter Select scratch save (Doc 00 §9.5) | Needs 2 chapters | Nothing to select yet |
| Cross-zone respawn (Doc 00 §11.2) | Ch 3 | Both Ch 1 checkpoints are in the death zone |

---

## 12. Build & run

### 12.1 Scenes to author

```
res://chapters/ch01/
├── ch01_director.gd          # objectives, flags, boss phases, chapter advance
├── ch01_dialogue.tres        # every DialogueLine in this doc
├── ch01_coldopen_path.tscn   # Act 0 scripted corridor
├── ch01_chase_path.tscn      # Act 4 phase 2 corridor
└── test_ch01.gd              # §14

res://world/zones/
├── z_shack_ext.tscn          # Doc 3 §10 checklist, all 11 items
├── z_woods_south.tscn        # ditto
├── int_giftshop.tscn         # ZoneDef, is_interior
├── int_living_room.tscn
└── int_attic.tscn            # checkpoint, save point, Pine Tree sigil
```

Five zone scenes. `int_kitchen`, `int_stan_room`, and the lab levels are **not** authored in Chapter 1 — their doors exist and refuse.

### 12.2 Running it

```bash
godot --path . --verbose
```

Headless suites, all four of which must pass before hand-play is meaningful:

```bash
godot --headless --script res://runtime/test_runtime.gd
```

```bash
godot --headless --script res://physics/test_physics.gd
```

```bash
godot --headless --script res://world/test_world.gd
```

```bash
godot --headless --script res://chapters/ch01/test_ch01.gd
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
| Audio | Doc 5 §9 subset — `bgm_shack`, `bgm_woods`, `boss_gnome` | 12 stems | **Procedural** |

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

Questions 1, 2, 4, and 5 are the expensive ones. They are exactly the four that a "core loop only" slice would have deferred.

---

## 14. Validation

```gdscript
# res://chapters/ch01/test_ch01.gd
# godot --headless --script res://chapters/ch01/test_ch01.gd
extends SceneTree

func _init() -> void:
	# --- 1. The chapter cipher must be the episode's own -------------------
	assert(Cipher.caesar("ZHOFRPH WR JUDYLWB IDOOV", -3) == "WELCOME TO GRAVITY FALLS",
		"Ch 1 cryptogram must decode with the Doc 3 §6.1 Caesar shift")

	# --- 2. The gnome entry must ship WITHOUT a weakness (§0.1) ------------
	var e := JournalDB.entry(&"entry_gnomes")
	assert(e.weakness.is_empty(),
		"entry_gnomes must ship blank — the player writes it in (§9.2)")
	assert(e.damage_multiplier == 1.0,
		"a scan with no weakness must grant no damage bonus")

	# --- 3. Every flag this chapter writes is in its own namespace --------
	for f in Ch01Director.WRITTEN_FLAGS:
		assert(f.begins_with("ch01_") or f.begins_with("zone_")
			or f.begins_with("npc_") or f.begins_with("sys_"),
			"Ch 1 wrote out-of-namespace flag: %s" % f)

	# --- 4. Journal acquisition gates the J binding, and survives a save --
	var s := GameState.new_game()
	assert(not s.flags.get(&"ch01_journal_acquired", false), "J must start locked")
	s.flags[&"ch01_journal_acquired"] = true
	var round_trip := GameState.deserialize(GameState.serialize(s))
	assert(round_trip.flags.get(&"ch01_journal_acquired", false),
		"journal acquisition must survive a save round-trip")

	# --- 5. The cart is a set-piece, never property (§7.2) ----------------
	assert(not Ch01Director.GRANTS_VEHICLE,
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

	print("ch01: all checks passed")
	quit()
```

Check 2 is the one to watch. It is the only automated test in the project whose purpose is to stop a future contributor from "fixing" a deliberate design decision.

---

## 15. Contracts this chapter exports

1. **Chapter 1 is the vertical slice.** Every system in Docs 1–5 is exercised here at least once, per §11's matrix, or explicitly listed as deferred.
2. The Journal ships with `entry_gnomes` weakness blank. The player writes it. No later chapter may pre-fill it.
3. The golf cart is a scripted set-piece in Chapter 1 and grants no persistent vehicle. Doc 3 §7's Chapter 9 unlock stands.
4. Jeff joins Doc 4 §4.4's speaker table: 52 cps, `moss` tint, blip 1.22 / ±0.09.
5. `boss_gnome` is phase-gated on `CombatDirector.boss_phase`, amending Doc 5 §4.2's "single".
6. The UV penlight is Chapter 1's only invented item, taken to exercise Doc 2 §5.5. It is a flagged deviation (§5.5), not a precedent.
7. The grappling hook is granted at chapter end and is usable from Chapter 2 (Doc 2 §7.2 pricing).
8. Chapter 1 writes only `ch01_`, `zone_`, and `npc_` flags, per Doc 00 §9.2.
9. Chapter 2 opens the morning after, at the attic checkpoint, with the Journal, penlight, hat, and grapple already in hand.
