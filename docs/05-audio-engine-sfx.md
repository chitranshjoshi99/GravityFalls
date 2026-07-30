# DOCUMENT 5 — Soundtracks, Audio Engine & SFX Triggers

**Consumes:** Doc 1 (`Weirdness`), Doc 2 (Journal timings, cart physics, scan duration), Doc 3 (zone BGM ids, footstep materials), Doc 4 (dialogue reveal, UI)
**Feeds:** Docs 6–25 (per-chapter cues, boss phase audio)

---

## 0. Locked decisions

| Decision | Value |
|---|---|
| BGM model | Vertical stems within a zone, crossfade between zones |
| Stem driver | `Weirdness.applied` — the same float, on the same curve, driving Doc 1's shader |
| Placeholder | Procedural, **baked to PCM at startup** (§7) |
| Dialogue | Per-character pitched blips |
| Score scope | 16 pieces + 5 boss themes |
| Middleware | None. Native Godot `AudioServer` buses |
| Tempo | **All non-boss tracks 96 BPM, 4/4** (§4.3) |

---

## 1. Bus architecture

```
Master  ── Limiter (-1.0 dB ceiling)
├── BGM ─────────── LowPassFilter (cutoff driven by weirdness + context)
│   ├── BGM_A          current zone stem rack
│   └── BGM_B          incoming zone stem rack
├── SFX
│   ├── SFX_World      footsteps, props, doors, environment
│   ├── SFX_Combat     hits, dodges, enemy vocals
│   └── SFX_UI         menu, journal, HUD
├── Dialogue ──────── blips
└── Ambience ─────── Reverb (per-zone preset)
    ├── AMB_Bed        continuous loops
    └── AMB_Oneshot    whispers, creaks, distant events
```

### 1.1 Weirdness-driven bus effects

The audio equivalent of Doc 1's palette ramp. One float, three parameters:

| Bus | Effect | At `w = 0` | At `w = 1` |
|---|---|---|---|
| `BGM` | LowPass cutoff | 20000 Hz (open) | 3400 Hz (muffled, underwater-adjacent) |
| `Ambience` | Reverb wet | 0.12 | 0.55 |
| `Ambience` | Reverb room size | 0.4 | 0.9 |
| `Master` | Pitch scale | 1.0 | 0.985 (barely flat — felt, not heard) |

```gdscript
# res://autoload/audio_director.gd — Autoload "AudioDirector" (excerpt)
func _on_weirdness_changed(w: float) -> void:
	var lp: AudioEffectLowPassFilter = AudioServer.get_bus_effect(_bus_bgm, 0)
	lp.cutoff_hz = lerpf(20000.0, 3400.0, ease(w, 2.2))

	var rv: AudioEffectReverb = AudioServer.get_bus_effect(_bus_amb, 0)
	rv.wet = lerpf(0.12, 0.55, w)
	rv.room_size = lerpf(0.4, 0.9, w)

	_stem_rack_a.apply_weirdness(w)
	_stem_rack_b.apply_weirdness(w)
```

The Master pitch drop of 1.5% at full weirdness is the single cheapest unsettling trick available. Nobody consciously hears it. Everybody feels it.

---

## 2. Vertical stems

### 2.1 The four stems

Every non-boss piece is authored as four synchronized stems, same length, same tempo, same key.

| Stem | Instrumentation | Role |
|---|---|---|
| `base` | Acoustic guitar, banjo, ukulele, brushed kit | The show's identity. **Never fully silent** |
| `warm` | Strings, Rhodes, melodic lead, whistling | Nostalgic summer. Fades out as things go wrong |
| `unease` | Detuned pad, bowed metal, prepared piano, reversed cymbal | The wrongness creeping in |
| `dread` | Sub bass, distorted synth, arrhythmic low percussion | Full supernatural |

### 2.2 Gain curves

```gdscript
# res://core/stem_rack.gd
class_name StemRack
extends Node

enum Stem { BASE, WARM, UNEASE, DREAD }

const SILENCE_DB := -80.0

## Linear gain 0..1 for a stem at a given weirdness level.
static func stem_gain(stem: Stem, w: float) -> float:
	match stem:
		Stem.BASE:
			# Drops but never vanishes — the cozy core survives Weirdmageddon.
			return lerpf(1.0, 0.55, smoothstep(0.0, 1.0, w))
		Stem.WARM:
			return 1.0 - smoothstep(0.10, 0.55, w)
		Stem.UNEASE:
			# Rises through the middle, backs off slightly once dread takes over.
			return smoothstep(0.15, 0.60, w) * (1.0 - smoothstep(0.85, 1.0, w) * 0.35)
		Stem.DREAD:
			return smoothstep(0.45, 1.0, w)
	return 0.0

static func to_db(linear: float) -> float:
	return SILENCE_DB if linear <= 0.0001 else linear_to_db(linear)
```

| `w` | base | warm | unease | dread | Reads as |
|---|---|---|---|---|---|
| 0.00 | 1.00 | 1.00 | 0.00 | 0.00 | Cozy summer afternoon |
| 0.25 | 0.94 | 0.55 | 0.14 | 0.00 | Something's slightly off |
| 0.50 | 0.78 | 0.00 | 0.68 | 0.02 | Actively wrong |
| 0.75 | 0.65 | 0.00 | 0.97 | 0.55 | Supernatural, committed |
| 1.00 | 0.55 | 0.00 | 0.65 | 1.00 | Weirdmageddon |

### 2.3 The rule that makes it work

**All four stems play continuously from the moment the rack starts. Only gain changes — never `play()` or `stop()`.** Starting a stem late puts it out of phase with the others, and the resulting flam is instantly audible. This is the single most common way vertical layering gets broken.

```gdscript
# res://core/stem_rack.gd (continued)
var _players: Dictionary = {}          # Stem -> AudioStreamPlayer
var _rack_gain := 1.0                  # crossfade multiplier, set by AudioDirector

func load_piece(piece: BgmPiece) -> void:
	for stem in [Stem.BASE, Stem.WARM, Stem.UNEASE, Stem.DREAD]:
		var p := AudioStreamPlayer.new()
		p.stream = piece.stems[stem]
		p.bus = bus_name
		p.volume_db = SILENCE_DB
		add_child(p)
		_players[stem] = p
	# Start every stem on the same frame, in sync, all silent.
	for p in _players.values():
		p.play()

## The ONLY writer of volume_db. Driven by Weirdness.level_changed and by nothing
## else, so there is exactly one path to a stem's gain.
func apply_weirdness(w: float) -> void:
	for stem in _players:
		var g: float = stem_gain(stem, w) * _rack_gain
		_players[stem].volume_db = to_db(g)

## Stores the rack gain and returns. It must NOT re-apply here: during a crossfade
## this is being tweened every frame while Weirdness.level_changed is also firing,
## and two callers writing volume_db in one frame means last-writer-wins,
## nondeterministically. The next level_changed picks the new _rack_gain up.
func set_rack_gain(g: float) -> void:
	_rack_gain = g
```

**Read `Weirdness.applied`, never `Weirdness.target_level`.** `applied` is where the tween *is*; `target_level` is where it is *headed* and snaps the instant a pulse is requested. Mixing against the snapped value while the shader follows the eased one is how "one float runs the supernatural" quietly becomes two floats on two curves — audible as audio arriving ahead of the colour grade at exactly the authored beats where the coupling is supposed to sell itself.

---

## 3. Zone crossfade

Two racks, A and B. Doc 3's `ZoneManager.activate_zone()` (Doc 00 §7.2) already calls `AudioDirector.set_zone(def.bgm_id)` — and it is the only thing that does, for interiors as well as exteriors.

```gdscript
# res://autoload/audio_director.gd (excerpt)
const ZONE_CROSSFADE := 2.5

func set_zone(bgm_id: StringName) -> void:
	if bgm_id == _current_bgm_id:
		return
	# Fail loud, not into a null deref. An unregistered or empty bgm_id would
	# otherwise index a missing key and the next piece.stems[stem] would crash —
	# taking the build down on entering whichever zone was authored without one.
	if not _library.has(bgm_id):
		push_error("no BGM piece registered for zone id '%s'" % bgm_id)
		return
	_current_bgm_id = bgm_id

	var incoming := _idle_rack()
	incoming.load_piece(_library[bgm_id])
	incoming.set_rack_gain(0.0)

	var outgoing := _active_rack

	# Start the incoming rack ON A BAR LINE, not immediately. Shared tempo and key
	# (§4.3) only blend if the two pieces are also phase-aligned — starting the
	# incoming rack at sample 0 against an arbitrary outgoing bar position gives
	# 2.5 s of two drum patterns a fraction of a beat apart, which is audibly
	# worse than crossfading pieces at different tempos. The outgoing tail covers
	# the delay, and this is what makes §4.3's constraint earn its cost.
	var delay: float = outgoing.seconds_to_next_bar() if outgoing.is_playing() else 0.0

	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	t.tween_callback(incoming.play).set_delay(delay)
	t.tween_method(incoming.set_rack_gain, 0.0, 1.0, ZONE_CROSSFADE).set_delay(delay)
	t.tween_method(outgoing.set_rack_gain, 1.0, 0.0, ZONE_CROSSFADE).set_delay(delay)
	t.chain().tween_callback(outgoing.unload)

	_active_rack = incoming
```

Crossfading eight stems at once (four out, four in) is why §4.3's shared-tempo rule exists — and the bar-line delay above is what lets that rule actually do its job.

**Every registered `ZoneDef` must carry a non-empty `bgm_id` that exists in `_library`.** Doc 00 §12 asserts it as a static check over the zone registry, because the failure mode is a hard crash on first entry to whichever zone was missed rather than a quiet fallback to silence.

### 3.1 Streaming and audio

Doc 3 streams neighbouring zones before you cross the seam, but **audio must not crossfade until the player actually crosses.** `set_zone` fires on `zone_entered`, not on `zone_loaded`. Otherwise music changes while you're still standing in the old zone.

---

## 4. Score

### 4.1 The 16 pieces

| ID | Zone / context | `base` character |
|---|---|---|
| `bgm_shack` | Shack exterior + gift shop | Banjo, ukulele, hand percussion. The main theme |
| `bgm_woods` | Deep Woods north & south | Fingerpicked acoustic, distant birdsong |
| `bgm_town` | Town | Upright bass, brushed kit, small-town shuffle |
| `bgm_lake` | Lake, Scuttlebutt Island | Slide guitar, lapping water in the bed |
| `bgm_cliffs` | Cliffs, water tower | Sparse, windy, harmonica |
| `bgm_mansion` | Northwest Mansion | Harpsichord, chamber strings. Wealth as coldness |
| `bgm_dusk2dawn` | Dusk 2 Dawn | Dead fluorescent hum, warped muzak |
| `bgm_lab` | Basement, lab, portal chamber | Analogue tape hiss, oscilloscope tones |
| `bgm_bunker` | Ford's bunker | Low drone, ventilation, isolation |
| `bgm_attic` | Attic, save rooms | Music box, minimal. **Safety cue** |
| `bgm_mystery` | Investigation, cipher solving | Pizzicato, vibraphone, curious |
| `bgm_chase` | Generic pursuit | Driving percussion, no melody |
| `bgm_mindscape` | Dreamscape | No `base` acoustic — inverted, floating |
| `bgm_weirdmageddon` | Act V overworld | The main theme, destroyed and rebuilt wrong |
| `bgm_menu` | Main menu | The theme, solo instrument, distant |
| `bgm_credits` | End credits | Full arrangement, warm, resolved |

### 4.2 Boss themes

Bosses **cut** rather than crossfade — the shock is the point.

| ID | Boss | Chapter | Phase handling |
|---|---|---|---|
| `boss_gnome` | Gnomonster | 1 | **3 phases** via `boss_phase` (Doc 6 §7.4) |
| `boss_gobblewonker` | Gobblewonker | 2 | Single |
| `boss_gideonbot` | Gideon's robot | 12 | 2 phases via `dread` gate |
| `boss_shapeshifter` | Shape Shifter | 13 | Stems shuffle on each morph |
| `boss_bill` | Bill Cipher | 19–20 | **5 phases, stems as phase states** |

`boss_bill` is the one piece authored with more than four stems — seven, gated by phase index rather than weirdness. Its spec lives in the Chapter 20 doc.

### 4.3 Composer constraints

Non-negotiable, because the crossfade system depends on them:

1. **96 BPM, 4/4**, every non-boss piece.
2. Keyed in **D minor / F major** or a relative — any two pieces may crossfade.
3. All four stems: **identical length**, loop-aligned, no stem-specific tails.
4. Loop points on bar boundaries. Bar = **2.5 s**.
5. `base` must stand alone musically — at `w = 1.0` it's still audible under everything.
6. No stem may contain the full melody alone; melody lives in `warm`, countermelody in `unease`.

### 4.4 Beat clock

Boss transitions and stingers quantize to the next bar. Cheap, and it's the difference between a cue that lands and one that stumbles.

```gdscript
const BPM := 96.0
const BEATS_PER_BAR := 4
const BAR_SECONDS := 60.0 / BPM * BEATS_PER_BAR      # 2.5 s

func seconds_to_next_bar() -> float:
	var pos := _active_rack.playback_position() \
		+ AudioServer.get_time_since_last_mix() \
		- AudioServer.get_output_latency()
	return BAR_SECONDS - fposmod(pos, BAR_SECONDS)
```

---

## 5. SFX

### 5.1 Journal — timings locked to Doc 2

Every cue's length matches its animation exactly. A 0.6 s page riffle over a 0.42 s open reads as broken.

| Cue | Length | Trigger | Description |
|---|---|---|---|
| `journal_open` | **0.42 s** | Doc 2 §5.1 `CLOSED→OPENING` | Leather creak, then page riffle resolving on a soft thump **exactly as the book becomes usable** |
| `journal_settle` | 0.48 s | At `t = 0.42`, layered | Quiet cloth/leather shift under the settle animation (Doc 1 §7.1). **Purely cosmetic** — may be cut off mid-play with no consequence |
| `journal_close` | **0.30 s** | `OPEN→CLOSING` | Reverse riffle, cover slap |
| `journal_drop` | 0.25 s | **Fumble** (Doc 2 §5.2) | Heavy book hitting dirt, pages fanning |
| `journal_recover` | 0.35 s | Fumble end, at **0.80 s** | Scrabble, snatch, cover slap |
| `journal_page_turn` | 0.18 s | Tab/page change | Single sheet |
| `journal_uv_on` | 0.30 s | `F` | Capacitor whine rising, ballast tick |
| `journal_uv_loop` | loop | UV held | 60 Hz electrical hum, faint |
| `journal_scan_loop` | **1.40 s** | Doc 2 §5.4 scan | Rising tone, 3 stepped increments, **resolves exactly at completion** |
| `journal_scan_done` | 0.5 s | Scan complete | Clean chime, `anomaly_green` in sound |
| `journal_scan_fail` | 0.3 s | Scan interrupted | Glass shatter, downward |
| `secret_found` | 0.9 s | `SecretTrigger` | Low bell + reversed shimmer |

`journal_scan_loop` stepping in three audible increments is what lets players time a scan by ear while watching the enemy instead of the ring.

### 5.2 Golf cart — layered engine

Four simultaneous layers, gain and pitch driven by speed (Doc 3 §7).

| Layer | Behaviour |
|---|---|
| `cart_idle` | Loop. Gain `1 - speed_ratio`, fades out as you accelerate |
| `cart_run` | Loop. Gain `speed_ratio`, **pitch `0.80 + 0.70 × speed_ratio`** |
| `cart_rattle` | Loop. Only off-road. Gain `speed_ratio × 0.8` — the suspension complaining |
| `cart_electric` | Loop. Constant faint motor whine (it's a golf cart, not a car) |

```gdscript
# res://actors/vehicle/cart_audio.gd
func _physics_process(_d: float) -> void:
	var ratio: float = absf(cart.speed) / GolfCart.ROAD_SPEED

	_idle.volume_db  = StemRack.to_db(1.0 - ratio)
	_run.volume_db   = StemRack.to_db(ratio)
	_run.pitch_scale = 0.80 + 0.70 * ratio
	_rattle.volume_db = StemRack.to_db(ratio * 0.8 if not cart.on_road else 0.0)
```

Plus one-shots: `cart_start` (1.2 s, reluctant ignition), `cart_stop`, `cart_horn`, `cart_impact`.

### 5.3 Paranormal whispers

Positional, attached to anomaly fields and haunted zones. The design rule is what makes them work:

> **Whispers are audible only when the player is still.** Volume scales with `1 - speed_ratio`, so movement masks them and stopping reveals them.

Players discover this on their own and it changes how they move through the woods. It costs four lines of code.

| Cue | Behaviour |
|---|---|
| `whisper_bed` | Loop, positional. Gain = `Weirdness.applied × (1 - speed_ratio) × proximity` |
| `whisper_oneshot_01..08` | Random every 8–24 s when `weirdness > 0.3`. Hard-panned L or R at random |
| `whisper_name` | **Rare (2% per one-shot roll): says "Dipper."** Only above `weirdness > 0.6`. Never explained, never referenced |
| `whisper_swell` | On entering an anomaly field |

`whisper_name` is deliberately rare enough that players doubt they heard it.

### 5.4 Portal hum

Three oscillator layers whose gains follow the portal's activation stage — which Doc 3 §5.1 already ramps by chapter.

| Layer | Freq | Rises with |
|---|---|---|
| `portal_sub` | 40 Hz sine | Stage 1+. Felt more than heard |
| `portal_mid` | 110 Hz + harmonics | Stage 2+ |
| `portal_shimmer` | 2–6 kHz filtered noise, slow sweep | Stage 3 only |

| Chapter | Stage | Sub | Mid | Shimmer |
|---|---|---|---|---|
| 12 | 1 | 0.5 | 0.0 | 0.0 |
| 13–16 | 2 | 0.7 | 0.4 | 0.0 |
| 17 | 3 | 1.0 | 1.0 | 0.8 |
| 18+ | spent | 0.3 | 0.15 | 0.0 |

One-shots: `portal_surge`, `portal_open` (4.5 s, the Ch 17 set-piece), `portal_collapse`.

### 5.5 Footsteps

Driven by Doc 3's `footstep_material` tile custom data. Fired from `AnimationPlayer` call-tracks in `walk`/`run` — two per cycle, so cadence automatically matches Doc 2's speed states.

| Material | Character |
|---|---|
| `grass` | Soft, dry rustle |
| `dirt` | Scuff with grit |
| `wood` | Hollow board creak (the Shack) |
| `stone` | Hard, slight tail |
| `carpet` | Muffled, almost nothing (Mansion) |
| `water` | Shallow splash |
| `snow` | Compressed squeak |
| `weird_flesh` | Wet, organic. Act V only |

4 variants each, **round-robin with no-repeat** — random selection audibly repeats and reads as a bug.

### 5.6 Combat & UI

| Cue | Trigger |
|---|---|
| `hit_light` / `hit_heavy` | Damage dealt |
| `player_hurt` | Damage taken. Ducks BGM 4 dB for 0.3 s |
| `dodge_whoosh` | Doc 2 §3.4, on i-frame start |
| `stamina_empty` | Exhausted lockout |
| `health_critical` | Loop, ≤2 pips. Heartbeat, on `Ambience` |
| `blackout` | Zero pips. Everything ducks to −24 dB over 0.6 s |
| `ui_move`, `ui_select`, `ui_back`, `ui_denied` | Menus |
| `pip_lost` | Timed to the pine tree's 0.30 s fall |
| `item_pickup`, `item_equip` | |
| `chapter_card` | Doc 4 §7.4 |

---

## 6. Dialogue blips

Doc 4 §4.5 fires a blip every 3rd glyph, skipping whitespace and punctuation.

| Speaker | Pitch | Variance | Timbre |
|---|---|---|---|
| Dipper | 1.15 | ±0.06 | Soft square |
| Mabel | 1.35 | **±0.12** | Bright triangle — widest variance, reads as chaotic |
| Stan | 0.78 | ±0.04 | Gravel sine |
| Soos | 0.92 | ±0.05 | Round, warm |
| Wendy | 1.05 | ±0.05 | Flat, unbothered |
| Bill | **0.62** | **±0.30** | Detuned saw, 8% chance of a reversed blip |
| Gideon | 1.28 | **±0.03** | Sweet, *too even* — uncanny by uniformity |
| Jeff | 1.22 | ±0.09 | Reedy square. Doc 6 §2.1 |
| Ford | 0.88 | ±0.04 | Clipped, precise |
| McGucket | 1.42 | ±0.18 | Cracked, thin |

Two cheap touches that do a lot:

```gdscript
# res://ui/dialogue/dialogue_blips.gd
func blip(speaker: StringName, glyph_index: int, total: int, ends_with: String) -> void:
	var v: Dictionary = VOICES[speaker]
	var p: float = v.pitch + randf_range(-v.variance, v.variance)

	# Sentence-final intonation: questions rise, statements settle.
	var progress := float(glyph_index) / maxf(float(total), 1.0)
	if progress > 0.75:
		match ends_with:
			"?": p *= lerpf(1.0, 1.18, (progress - 0.75) / 0.25)
			".": p *= lerpf(1.0, 0.92, (progress - 0.75) / 0.25)

	_player.pitch_scale = p
	_player.stream = v.sample
	_player.play()
```

- **Gideon's ±0.03 variance is the point.** Every other character's blips wander; his don't. Nobody consciously notices, and he sounds wrong.
- Dialogue ducks `BGM` by 4 dB while a line reveals.

---

## 7. Procedural placeholder audio

Real audio arrives late; audio *bugs* arrive early. Shipping silence means the mixing, crossfade, ducking, and layering systems stay untested until a composer delivers — which is exactly backwards.

### 7.1 Bake offline, don't stream — and don't bake at startup either

Generating audio in real time via `AudioStreamGenerator` risks buffer underruns. **Synthesize into an `AudioStreamWAV`** and play it through the ordinary `AudioStreamPlayer` path — the placeholder is then indistinguishable from a real asset to every other system: same buses, same crossfades, same loops, same code path that ships.

**Run the synthesizer once, offline, as an editor tool — never at boot.** An earlier draft baked every placeholder during startup and budgeted it at "under a second." That number was wrong by orders of magnitude: 16 pieces × 4 stems plus 23 boss stems is 87 stems, each `22050 × 2.5 × 8` = 441,000 samples, so ~38 M iterations of an interpreted GDScript loop doing `fposmod`, an oscillator, an envelope, a clamp and `encode_s16` — plus ~120 SFX bakes. That is tens of seconds of frozen window on native, and worse in WASM where there is no worker thread to move it to. The resident cost is as bad as the time: 87 × 441,000 × 2 bytes ≈ **77 MB of PCM**, on top of Doc 3 §3.4's 90 MB texture budget.

So `bake_placeholders.gd` lives in `tools/`, outside `res://`, and is run by hand when a placeholder spec changes. It writes WAVs into `res://assets/audio/`, which are committed like any other asset. Boot loads files. Three things fall out of this for free: startup is instant, any single placeholder can be replaced by a real recording without touching code, and the shipped build carries no synthesizer at all.

```gdscript
# tools/bake_placeholders.gd — run from the editor, NOT at runtime.
class_name ProcBaker

const MIX_RATE := 22050          # placeholder-grade; halves bake time and memory
const BARS := 2                  # a 5 s loop is enough to exercise crossfade + ducking
const BAR_SECONDS := 2.5

enum Wave { SINE, SAW, TRI, NOISE }

class StemSpec extends RefCounted:
	var wave: Wave = Wave.SINE
	var root_hz: float = 110.0
	var steps: PackedFloat32Array = PackedFloat32Array()   # semitone offsets, -99 = rest
	var step_len := 0.25                                    # in bars
	var attack := 0.01
	var release := 0.18
	var gain := 0.30
	var detune := 0.0

static func bake(spec: StemSpec) -> AudioStreamWAV:
	var total := int(MIX_RATE * BAR_SECONDS * BARS)
	var data := PackedByteArray()
	data.resize(total * 2)                                  # 16-bit mono

	var step_samples := int(MIX_RATE * BAR_SECONDS * spec.step_len)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(spec.root_hz) + spec.steps.size()

	for i in total:
		var step_i := (i / step_samples) % maxi(spec.steps.size(), 1)
		var semi: float = spec.steps[step_i] if spec.steps.size() > 0 else 0.0

		var sample := 0.0
		if semi > -90.0:
			var hz: float = spec.root_hz * pow(2.0, semi / 12.0) + spec.detune
			phase = fposmod(phase + TAU * hz / MIX_RATE, TAU)
			sample = _osc(spec.wave, phase, rng)
			sample *= _envelope(float(i % step_samples) / float(step_samples),
				spec.attack, spec.release)
		sample *= spec.gain

		var v := int(clampf(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)

	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = MIX_RATE
	s.stereo = false
	s.data = data
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = total
	return s

static func _osc(w: Wave, phase: float, rng: RandomNumberGenerator) -> float:
	match w:
		Wave.SINE:  return sin(phase)
		Wave.SAW:   return (phase / PI) - 1.0
		Wave.TRI:   return 1.0 - 4.0 * absf(fposmod(phase / TAU + 0.25, 1.0) - 0.5)
		Wave.NOISE: return rng.randf_range(-1.0, 1.0)
	return 0.0

static func _envelope(t: float, attack: float, release: float) -> float:
	if t < attack:
		return t / maxf(attack, 0.0001)
	if t > 1.0 - release:
		return (1.0 - t) / maxf(release, 0.0001)
	return 1.0
```

### 7.2 Placeholder stem recipes

Each piece's four stems get a spec. Baking the whole score is a one-off editor run, not a startup cost — see §7.1.

| Stem | Wave | Root | Pattern | Reads as |
|---|---|---|---|---|
| `base` | TRI | 220 Hz | `[0, 4, 7, 4]` arpeggio, 1/4 bar | Plucky, cheerful |
| `warm` | SINE | 330 Hz | `[7, -99, 5, -99]` sustained | Melodic pad |
| `unease` | SAW | 110 Hz | `[0, 1, 0, -1]`, detune +3 Hz | Beating, sour |
| `dread` | SINE | 41 Hz | `[0, 0, -99, 0]` | Sub pulse |

Per-piece variation is a root-note and pattern change — `bgm_mansion` shifts to a minor arpeggio, `bgm_mindscape` drops `base` entirely.

`unease`'s +3 Hz detune against its own root produces a 3 Hz beat frequency. That's the same acoustic trick real horror scoring uses, and it costs one float.

### 7.3 Placeholder SFX

Short bakes with the same synth: `journal_open` is a 0.42 s noise burst with a fast decay envelope, `pip_lost` is a 0.30 s falling triangle, blips are 40 ms square pulses pitched per §6. Every timing constraint in §5 is honoured by the placeholder, so cue-timing bugs surface immediately rather than after real audio arrives.

---

## 8. Ducking

| Trigger | Target | Amount | Attack / release |
|---|---|---|---|
| Dialogue revealing | `BGM` | −4 dB | 0.10 / 0.40 |
| `player_hurt` | `BGM` | −4 dB | 0.02 / 0.30 |
| Boss stinger | `Ambience` | −8 dB | 0.05 / 1.20 |
| **Journal open** | `SFX_World` | −2 dB | 0.20 / 0.35 |
| **Journal open** | `Ambience` | **+2 dB** | 0.20 / 0.35 |
| Pause menu | `Master` | −12 dB + lowpass 900 Hz | 0.15 / 0.15 |
| `blackout` | `Master` | −24 dB | 0.60 / 1.00 |

The Journal case is the interesting one: world SFX drop while ambience *rises*. Opening the book pulls you inward and makes the environment louder around you — which, given the world stays live, is also a fair warning system.

---

## 9. ► ASSETS YOU NEED TO SUPPLY

| Asset | Spec | Count |
|---|---|---|
| **BGM stems** | 4 per piece × 16 pieces, OGG, 96 BPM, loop-aligned, §4.3 rules | 64 |
| **Boss themes** | 4 stems × 4 bosses + 7 for `boss_bill` | 23 |
| Journal SFX | §5.1, exact lengths | 12 |
| Cart SFX | 4 loops + 4 one-shots | 8 |
| Whispers | Bed loop + 8 one-shots + `whisper_name` + swell | 11 |
| Portal | 3 loops + 3 one-shots | 6 |
| Footsteps | 8 materials × 4 variants | 32 |
| Combat / UI | §5.6 | ~18 |
| Dialogue blips | 9 speakers, one 40–80 ms sample each | 9 |
| Ambience beds | One per zone, incl. weather | 10 |

**~192 audio files.** Every one has a procedural placeholder, and the game is fully playable and fully mixable before any of them exist.

---

## 10. Validation

```gdscript
# res://tests/test_all.gd — godot --headless --script res://tests/test_all.gd
extends SceneTree

func _init() -> void:
	# --- Stem curves must produce the intended emotional endpoints ---------
	assert(is_equal_approx(StemRack.stem_gain(StemRack.Stem.WARM, 0.0), 1.0),
		"warm must be full at zero weirdness")
	assert(StemRack.stem_gain(StemRack.Stem.DREAD, 0.0) == 0.0,
		"dread must be silent at zero weirdness")
	assert(StemRack.stem_gain(StemRack.Stem.WARM, 1.0) == 0.0,
		"warm must be gone at full weirdness")
	assert(is_equal_approx(StemRack.stem_gain(StemRack.Stem.DREAD, 1.0), 1.0),
		"dread must be full at full weirdness")

	# --- The cozy core never disappears -----------------------------------
	for i in 21:
		var w := float(i) / 20.0
		assert(StemRack.stem_gain(StemRack.Stem.BASE, w) >= 0.5,
			"base stem dropped to %f at w=%f — it must always be audible"
			% [StemRack.stem_gain(StemRack.Stem.BASE, w), w])

	# --- Something must always be playing ---------------------------------
	for i in 21:
		var w := float(i) / 20.0
		var total := 0.0
		for s in [StemRack.Stem.BASE, StemRack.Stem.WARM,
				StemRack.Stem.UNEASE, StemRack.Stem.DREAD]:
			total += StemRack.stem_gain(s, w)
		assert(total > 0.5, "all stems near-silent at w=%f" % w)

	# --- Silence must map to true silence, not -0 dB ----------------------
	assert(StemRack.to_db(0.0) <= -80.0, "zero gain must be silent")

	# --- Cue lengths must match the animations they cover -----------------
	assert(is_equal_approx(AudioDirector.sfx_length(&"journal_open"), 0.42),
		"journal_open must match Doc 2 OPEN_TIME")
	assert(is_equal_approx(AudioDirector.sfx_length(&"journal_close"), 0.30),
		"journal_close must match Doc 2 CLOSE_TIME")
	assert(is_equal_approx(AudioDirector.sfx_length(&"journal_scan_loop"), 1.40),
		"scan loop must match Doc 2 SCAN_DURATION")

	# --- Bar maths ---------------------------------------------------------
	assert(is_equal_approx(AudioDirector.BAR_SECONDS, 2.5),
		"96 BPM 4/4 must give a 2.5s bar")

	# --- Blip voices must be distinguishable ------------------------------
	var pitches: Array = []
	for id in DialogueBlips.VOICES:
		pitches.append(DialogueBlips.VOICES[id].pitch)
	pitches.sort()
	for i in range(1, pitches.size()):
		assert(absf(pitches[i] - pitches[i - 1]) > 0.02,
			"two speakers have indistinguishable blip pitches")

	# --- Placeholder bake produces valid, looping, non-silent audio -------
	var spec := ProcBaker.StemSpec.new()
	spec.steps = PackedFloat32Array([0.0, 4.0, 7.0, 4.0])
	var wav := ProcBaker.bake(spec)
	assert(wav.data.size() == int(ProcBaker.MIX_RATE * 2.5 * ProcBaker.BARS) * 2,
		"baked PCM is the wrong length")
	assert(wav.loop_mode == AudioStreamWAV.LOOP_FORWARD, "placeholder must loop")
	var peak := 0
	for i in range(0, wav.data.size(), 2):
		peak = maxi(peak, absi(wav.data.decode_s16(i)))
	assert(peak > 1000, "baked placeholder is silent (peak %d)" % peak)

	print("audio: all checks passed")
	quit()
```

---

## 11. Contracts this document exports

1. **All four stems play continuously and in sync.** Gain is the only thing that changes. Never `play()`/`stop()` a stem mid-piece.
2. `base` never falls below 0.55 linear. The show's identity survives Weirdmageddon.
3. Every non-boss piece is 96 BPM, 4/4, D minor / F major family. Any two may crossfade.
4. Bosses cut on a bar boundary; zones crossfade over 2.5 s.
5. Zone music changes on `zone_entered`, never on `zone_loaded`.
6. SFX cue lengths match the animation they accompany — §10 enforces the Journal ones.
7. Whispers are masked by movement and revealed by stillness.
8. Placeholder audio is **baked to PCM**, not streamed, and travels the identical code path as real assets.
9. Dialogue blip pitches must stay ≥0.02 apart across speakers.
