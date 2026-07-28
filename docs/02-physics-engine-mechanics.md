# DOCUMENT 2 — Game Physics Engine & Mechanics

**Consumes:** Doc 1 (tokens, rigs, anchors, `Weirdness`)
**Feeds:** Doc 3 (zone collision authoring), Doc 4 (HUD bindings), Doc 5 (SFX triggers), Docs 6–25 (every chapter)

---

## 0. Locked decisions

| Decision | Value |
|---|---|
| View | Top-down 3/4, 8-direction movement |
| Playable | Dipper only; chapter companion follows via AI |
| Failure | Health pips → black out → checkpoint respawn, no progress loss |
| Journal | Right-half overlay, **world stays live**, movement penalty, damage force-closes |
| Physics tick | 60 Hz fixed (`_physics_process`) |
| Body type | `CharacterBody2D` + `move_and_slide()` |

### 0.1 The one concept to internalize

**The collision shape is not the character.** In 3/4 top-down, a character's body collides as a small flat ellipse at their *feet only*. The head, torso, and tube limbs never collide with walls — they're drawn above the collision footprint and overlap scenery freely. This is why a character can stand next to a fence and have their head drawn over it and it looks correct.

Three separate shapes per character, and conflating them is the classic beginner bug:

| Shape | Node | Purpose |
|---|---|---|
| **Body** | `CollisionShape2D` on the `CharacterBody2D` | Blocks walls. Small ellipse at the feet. |
| **Hurtbox** | `Area2D` | Receives damage. Tall, covers torso + head. |
| **Hitbox** | `Area2D`, enabled only during attack frames | Deals damage. |

---

## 1. Space & depth

### 1.1 The depth ratio

3/4 view is foreshortened: the screen's Y axis represents ground depth viewed at an angle, so one pixel of vertical screen movement covers *more* world distance than one pixel of horizontal. To make a circle walked on the ground read as a circle, vertical velocity is scaled down.

```gdscript
const DEPTH_RATIO := 0.62
```

Applied to **velocity**, never to input — scaling input first breaks diagonal normalization and makes diagonals faster than cardinals.

```gdscript
var dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
var target: Vector2 = dir * current_speed
target.y *= DEPTH_RATIO          # ← foreshortening, applied last
```

`DEPTH_RATIO` also scales: shadow ellipses, ground-plane AoE radii, thrown-object arcs, and anomaly field shapes. Anything meant to be a circle *on the ground* is drawn as an ellipse with `scale.y = DEPTH_RATIO`.

### 1.2 Fake Z — how anything gets off the ground

Top-down 2D has no third axis, so height is faked with a single float. This one component powers jumping, floating artifacts, thrown objects, gravity anomalies, and Weirdmageddon's floating debris.

```gdscript
# res://actors/player/height_body.gd
class_name HeightBody
extends Node

## Visual height above the ground plane, in pixels. Collision is unaffected —
## a floating object still blocks at its ground footprint unless told otherwise.
@export var height: float = 0.0
@export var vertical_velocity: float = 0.0
@export var gravity_z: float = 2200.0     ## px/s² pulling height back to 0
@export var bounce: float = 0.0           ## 0 = thud, 0.5 = lively bounce
@export var grounded: bool = true

@export var visual: Node2D                ## sprite/rig root to offset
@export var shadow: Node2D                ## stays on the ground plane

const SHADOW_MIN_SCALE := 0.45
const SHADOW_FADE_HEIGHT := 260.0

func _physics_process(delta: float) -> void:
	if grounded and is_zero_approx(vertical_velocity):
		return
	vertical_velocity += gravity_z * delta
	height -= vertical_velocity * delta

	if height <= 0.0:
		height = 0.0
		if bounce > 0.0 and absf(vertical_velocity) > 120.0:
			vertical_velocity = -vertical_velocity * bounce
		else:
			vertical_velocity = 0.0
			grounded = true
	else:
		grounded = false

	_sync()

func _sync() -> void:
	if visual:
		visual.position.y = -height
	if shadow:
		var t := clampf(height / SHADOW_FADE_HEIGHT, 0.0, 1.0)
		var s := lerpf(1.0, SHADOW_MIN_SCALE, t)
		shadow.scale = Vector2(s, s * 0.62)   # DEPTH_RATIO
		shadow.modulate.a = lerpf(0.55, 0.15, t)

func launch(speed: float) -> void:
	vertical_velocity = -speed
	grounded = false
```

The shadow shrinking and fading as height rises is the entire visual language of "this is off the ground." Without it, a floating object just looks like it moved up-screen.

### 1.3 Y-sorting

World root has `y_sort_enabled = true`. Every character's sort key is its `CharacterRoot` origin — which Doc 1 §6.1 fixed at ground contact, feet-centered. That's why that convention mattered: a character standing "behind" a tree has a smaller Y and draws first. Floating objects sort by their **ground position**, not their visual height, so a floating artifact behind a tree stays behind it.

---

## 2. Collision bodies

### 2.1 Body ellipse dimensions

Derived from Doc 1 proportions. `leg_w` is the foot-span reference.

| Character | Body radius X | Body radius Y | Source |
|---|---|---|---|
| Dipper | 22 | 13 | `leg_w · 1.38` / `× DEPTH_RATIO` |
| Mabel | 22 | 13 | same |
| Wendy | 21 | 13 | |
| Stan | 26 | 16 | |
| Soos | 30 | 19 | widest footprint in the cast |
| NPC adult | 24 | 15 | |
| NPC kid | 21 | 13 | |

Godot has no ellipse collision primitive. Use a `CapsuleShape2D` rotated 90° (`rotation = PI/2`), giving a horizontal capsule — visually and behaviorally close enough to an ellipse, and far cheaper than a polygon.

```gdscript
static func body_shape(radius_x: float, radius_y: float) -> CapsuleShape2D:
	var s := CapsuleShape2D.new()
	s.radius = radius_y
	s.height = maxf(radius_x * 2.0, radius_y * 2.0 + 0.1)
	return s   # assign shape owner rotation = PI/2
```

The body shape's **center sits at `y = -radius_y`** relative to the character origin, so the ellipse rests on the ground line rather than straddling it.

### 2.2 Hurtbox

A vertical capsule covering torso and head — where getting hit *reads* as getting hit. Sized from Doc 1: `height = 0.58 · H`, `radius = 0.30 · D`, centered at `y = -0.42 · H`.

| Character | Hurtbox radius | Hurtbox height | Center Y |
|---|---|---|---|
| Dipper | 25 | 150 | −108 |
| Mabel | 25 | 145 | −105 |
| Stan | 26 | 172 | −124 |
| Soos | 27 | 174 | −126 |

The hurtbox is **larger than the body** on purpose. Enemies should connect when they look like they connect; players forgive a generous hurtbox on enemies far more than a stingy one.

### 2.3 Physics layers

| Bit | Name | Notes |
|---|---|---|
| 1 | `world_static` | Walls, cliffs, buildings |
| 2 | `world_dynamic` | Pushable crates, golf cart, doors |
| 3 | `player_body` | Dipper |
| 4 | `companion_body` | **Does not collide with `player_body`** — companions never shove you |
| 5 | `npc_body` | Townsfolk |
| 6 | `enemy_body` | |
| 7 | `player_hurtbox` | |
| 8 | `enemy_hurtbox` | |
| 9 | `player_hitbox` | Active only during attack frames |
| 10 | `enemy_hitbox` | |
| 11 | `interactable` | E-prompt targets |
| 12 | `anomaly_field` | Gravity/time regions |
| 13 | `projectile` | |
| 14 | `trigger_volume` | Cutscene/chapter triggers, zero collision |
| 15 | `scannable` | Journal scan targets |
| 16 | `ledge_oneway` | Drop-down ledges |

---

## 3. Movement

### 3.1 Speed table

Pixels/second at the 1920×1080 reference canvas.

| State | Speed | Notes |
|---|---|---|
| Walk | 210 | Default |
| Run | 340 | Drains stamina |
| Journal open | **118** | 56% of walk — the cost of reading |
| Sneak | 105 | Dusk 2 Dawn, Northwest Mansion |
| Carrying heavy | 140 | Scripted chapter states |
| Wading (shallow water) | 130 | |
| Companion catch-up | 380 | Only when trailing far |

### 3.2 Acceleration

| Constant | Value | Feel |
|---|---|---|
| `ACCEL_GROUND` | 1800 px/s² | ~0.12 s to full walk — responsive, not twitchy |
| `FRICTION_GROUND` | 2400 px/s² | Snappy stop, slight slide |
| `FRICTION_ICE` | 380 px/s² | Frozen lake, Weirdmageddon glass |
| `FRICTION_KNOCKBACK` | 900 px/s² | Long skid on hit |
| `ACCEL_AIRBORNE` | 620 px/s² | Reduced control while `height > 0` |

### 3.3 Controller

```gdscript
# res://actors/player/player_controller.gd
class_name PlayerController
extends CharacterBody2D

const DEPTH_RATIO := 0.62
const ACCEL_GROUND := 1800.0
const FRICTION_GROUND := 2400.0
const ACCEL_AIRBORNE := 620.0

## Superseded by Doc 00 §5.1, which adds ATTACKING, DRIVING, ZONE_TRANSITION,
## and BLACKOUT. The six states below keep their exact meaning.
enum State { FREE, JOURNAL, DODGING, HURT, FUMBLING, CUTSCENE }

@export var walk_speed := 210.0
@export var run_speed := 340.0
@export var journal_speed := 118.0

var state: State = State.FREE
var facing := Vector2.DOWN
var external_force := Vector2.ZERO      ## anomaly fields write here
var surface_friction := FRICTION_GROUND

@onready var height_body: HeightBody = $HeightBody
@onready var stamina: Stamina = $Stamina

## EVERY State value needs an arm. Doc 00 §5.1 adds four states to this enum, and
## a state with no arm never writes `velocity` — so the body silently coasts at
## whatever it last held while move_and_slide() keeps applying it. The worst case
## is BLACKOUT: the invisible player body is the save/checkpoint anchor (Doc 00
## §5.3), so it would drift away from the death site for the whole blackout.
## There is deliberately no `_:` default — a new state must be classified here,
## not absorbed silently.
func _physics_process(delta: float) -> void:
	match state:
		State.FREE, State.JOURNAL:
			_move(delta, _read_input())
		State.DODGING:
			_move(delta, Vector2.ZERO)      # velocity preserved, no steering
		State.HURT, State.FUMBLING:
			_move(delta, Vector2.ZERO)
		State.ATTACKING:
			_move(delta, Vector2.ZERO)      # drifts, no steering (Doc 00 §5.1)
		State.DRIVING:
			return                          # vehicle owns the transform entirely
		State.CUTSCENE, State.ZONE_TRANSITION, State.BLACKOUT:
			velocity = Vector2.ZERO

	velocity += external_force * delta
	external_force = Vector2.ZERO         # fields re-apply every tick
	move_and_slide()

func _read_input() -> Vector2:
	if state == State.CUTSCENE:
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func _move(delta: float, dir: Vector2) -> void:
	if dir != Vector2.ZERO:
		facing = _snap_8(dir)

	var speed := current_speed()
	var target := dir * speed
	target.y *= DEPTH_RATIO                # foreshortening, applied last

	var rate := ACCEL_GROUND if height_body.grounded else ACCEL_AIRBORNE
	if dir == Vector2.ZERO:
		rate = surface_friction
	velocity = velocity.move_toward(target, rate * delta)

func current_speed() -> float:
	if state == State.JOURNAL:
		return journal_speed
	var running := Input.is_action_pressed("run") and stamina.can_run()
	return run_speed if running else walk_speed

## Collapse an analog/diagonal vector to one of 8 facings for animation choice.
static func _snap_8(v: Vector2) -> Vector2:
	var a := snappedf(v.angle(), PI / 4.0)
	return Vector2(cos(a), sin(a)).round().normalized()
```

### 3.4 Dodge roll

| Property | Value |
|---|---|
| Impulse | 520 px/s in `facing` |
| Duration | 0.32 s |
| Invulnerability window | 0.05 – 0.26 s (not the full roll — the tail is punishable) |
| Stamina cost | 25 |
| Recovery lockout | 0.14 s |
| **Force-closes Journal** | Yes — you drop the book to dive |

The i-frame window starting at 0.05 s rather than 0 means panic-rolling *into* an already-landing attack still gets hit. That's deliberate: it rewards reading the telegraph rather than mashing.

### 3.5 Input map

| Action | Keyboard | Gamepad |
|---|---|---|
| `move_*` | WASD / Arrows | Left stick + D-pad |
| `interact` | **E** | A / Cross |
| `journal` | **J** | Y / Triangle |
| `run` | Shift | Left stick click |
| `dodge` | Space | B / Circle |
| `attack` | Left Mouse / Ctrl | Right trigger |
| `item_use` | Q | Left trigger |
| `uv_light` | F | Right stick click |
| `item_cycle` | Mouse wheel | Bumpers |
| `item_radial` | **Tab (hold)** | **Left bumper (hold)** |
| `scan` | **Left Shift** | **Right trigger** |
| `pause` | Esc | Start |

Every action is remappable via `InputMap` at runtime — one settings screen, spec'd in Doc 4.

**`scan` is a plain action, not a chord.** An earlier draft bound it to "hold `J` + `attack`", which cannot work: `InputMap` has no chord or modifier-combination action, so `Input.is_action_pressed("scan")` requires `scan` to be its own registered action with its own events. The chord also fought itself — `J` is the `journal` toggle, so holding it means the toggle already fired on keydown, and Doc 00 §4.2 rejects `ATTACK_REQUEST` outside `FREE`, making `attack` a dead input while the Journal is open. And a chord is not remappable, contradicting the line above it.

`Left Shift` is free while the Journal is open because `run` is inert at journal speed, and the right trigger is free for the same reason on a gamepad. The one binding collision that would make scanning unreachable is `scan` == `journal`; Doc 4 §7.3's remap screen rejects that pair explicitly.

**Verb gating is the resolver's job, not the `InputMap`'s.** `journal`, `uv_light`, and `scan` are bound at boot like every other action, even before Dipper owns the Journal. A verb the player has not earned yet is refused at the resolver — Doc 00 §4.2 priority 11 and 12 additionally require the corresponding inventory item. Binding actions at runtime to gate a story beat would put a gameplay gate inside `Settings`, which loads from `user://settings.cfg` before `GameState` exists and survives New Game — so a stale settings file could hand a fresh playthrough the Journal.

---

## 4. Combat verbs

Dipper is not a fighter, and the combat design says so. He has no sword. His verbs are **positioning, items, and knowledge** — which is also why the Journal being live matters.

| Verb | Input | Notes |
|---|---|---|
| **Improvised melee** | `attack` | Whatever's in hand — branch, golf club, grappling hook haft. 0.28 s windup, 0.12 s active, 0.22 s recovery. Deliberately mediocre. |
| **Item use** | `item_use` | Flashlight beam, grappling hook, thrown object. The real damage. |
| **Dodge** | `dodge` | §3.4 |
| **Scan** | Hold `scan` | §5.4 — reveals weakness, then items exploit it |

**The core combat loop:** a creature is damage-resistant until scanned. Scanning takes 1.4 s of standing still with the Journal open at 56% move speed. So every fight asks the same question — *do I risk reading now, or fight blind?* That is the whole design, and it's why the world staying live was the right call.

### 4.1 Hitbox timing

Hitboxes are `Area2D` children with `monitoring` toggled by `AnimationPlayer` call-tracks — never by timers in script. The animation is the source of truth, so retiming an attack is a keyframe move, not a code change.

---

## 5. The Journal

### 5.1 State machine

```gdscript
enum JournalState { CLOSED, OPENING, OPEN, CLOSING, FUMBLED }
```

| Transition | Duration | Interruptible |
|---|---|---|
| `CLOSED → OPENING` | 0.42 s | Yes, by damage/dodge |
| `OPENING → OPEN` | — | |
| `OPEN → CLOSING` | 0.30 s | |
| **Any → `FUMBLED`** | instant | **On damage taken** |
| `FUMBLED → CLOSED` | **0.80 s** | **No — this is the punish** |

`OPEN_TIME = 0.42` is the **canonical Journal timing across every document.** Doc 1 §7.1 splits the character animation into a 0.42 s gating `journal_raise` and a 0.48 s non-gating `journal_settle`; Doc 4 §6.1 completes the page-flip UI at 0.42 s; Doc 5 §5.1 matches the SFX length. The character is still visibly settling into the read pose until 0.90 s, but **the state machine reaches `OPEN` at 0.42 s and everything mechanical — movement penalty, scan availability, UI interactivity — switches there.** No system may wait on the settle.

### 5.2 The fumble

Taking damage with the Journal open drops the book. Dipper scrambles for it for 0.80 s: no movement, no dodge, no attack. The book lands on the ground with an `fx_impact_star` puff and snaps back to his hand.

This single rule is what makes the live world a real threat rather than a cosmetic choice. 0.80 s is long enough to eat a second hit from most enemies, short enough that it doesn't chain into a death spiral.

The three constants below are canonical. **The call path is superseded by Doc 00 §2.4 and
§5.2:** `on_owner_damaged()` is invoked by `RuntimeDirector` during damage resolution, not from
a hitbox callback, and the fumble is counted in physics ticks rather than by a `SceneTree`
timer — a timer mutates state outside the resolver, does not survive pause predictably, and
cannot be stepped by Doc 00 §12's headless harness.

**Where the Journal lives, and why the constants live somewhere else.** `Journal` is a **node on the player**, reached as `RuntimeDirector.player.journal` — never a singleton. Doc 00 §2.2's autoload table has no `Journal` row, and it must not gain one: in Godot 4 an autoload named `Journal` and a `class_name Journal` occupy the same global identifier and the engine errors on the collision, so `Journal.state` (instance) and `Journal.FUMBLE_DURATION` (constant) could never both resolve from that name.

The three timings therefore live in a tiny static class, `JournalConst`, which anything may read at parse time — Doc 00 §2.4 derives its tick counts from them before any node exists. `Journal` the node holds state; `JournalConst` holds numbers. Neither holds the other's job.

```gdscript
# res://core/journal_const.gd
class_name JournalConst
const FUMBLE_DURATION := 0.80
const OPEN_TIME := 0.42
const CLOSE_TIME := 0.30
```

```gdscript
# res://actors/player/journal.gd  (excerpt)
const FUMBLE_TICKS := int(round(JournalConst.FUMBLE_DURATION / (1.0 / 60.0)))   # 48

var _fumble_ticks_left := 0

## Called by RuntimeDirector at damage commit. Never from a signal callback.
func on_owner_damaged() -> void:
	if state == JournalState.CLOSED:
		return
	_cancel_scan()
	state = JournalState.FUMBLED
	fumbled.emit()
	AudioDirector.play_sfx(&"journal_drop")
	_fumble_ticks_left = FUMBLE_TICKS

## Called by RuntimeDirector once per resolved tick (Doc 00 §4.1 step 5b).
func tick() -> void:
	if _fumble_ticks_left <= 0:
		return
	_fumble_ticks_left -= 1
	if _fumble_ticks_left == 0:
		state = JournalState.CLOSED
		recovered.emit()
```

### 5.3 Layout & world visibility

Journal occupies the right **45%** of the canvas (864 px of 1920). On open:

- Camera offsets **left by 190 px** over 0.35 s, so Dipper sits at roughly 28% screen width instead of centered — the play space stays visible.
- Camera zooms out to **0.88×** — more world visible, compensating for the lost width.
- The left edge gets a 60 px gradient scrim so world detail doesn't fight the page text.

Full visual spec is Doc 4's. What Doc 2 guarantees: **the world never pauses, never slows, and never stops spawning.**

### 5.4 Scanning

| Property | Value |
|---|---|
| Range | 420 px |
| Cone | 38° half-angle from `facing` |
| Duration | 1.40 s |
| Movement allowed | Yes, at journal speed — but leaving the cone resets progress |
| Line of sight | Required, raycast against `world_static` |
| Interrupted by | Damage, dodge, target leaving cone/range/LOS |
| Progress on interrupt | **Resets to 0** |

```gdscript
# res://actors/player/scanner.gd
class_name Scanner
extends Node2D

signal scan_completed(entity: Node2D, entry_id: StringName)
signal scan_progress(t: float)

const SCAN_RANGE := 420.0
const SCAN_CONE_COS := 0.788     # cos(38°)
const SCAN_DURATION := 1.40

var _target: Node2D = null
var _elapsed := 0.0

func _physics_process(delta: float) -> void:
	if not _is_scanning():
		_reset()
		return

	var candidate := _best_target()
	if candidate != _target:
		_target = candidate
		_elapsed = 0.0                       # switching targets restarts
	if _target == null:
		_reset()
		return

	_elapsed += delta
	scan_progress.emit(_elapsed / SCAN_DURATION)

	if _elapsed >= SCAN_DURATION:
		var entry: StringName = _target.get_meta(&"journal_entry", &"")
		scan_completed.emit(_target, entry)
		_reset()

## A scan target is ALWAYS an Area2D on the `scannable` layer — never a body.
## Doc 3 §4.2 authors every PropScannable as an Area2D, so get_overlapping_bodies()
## would return an empty list forever: Area2D.get_overlapping_bodies() yields
## PhysicsBody2D only and can never yield an Area2D. An NPC that is scannable
## carries a `scannable` Area2D as a CHILD rather than being scanned as a body,
## so there is one target shape and no branch. `area.owner` resolves back to the
## prop or actor that carries the metadata.
func _best_target() -> Node2D:
	var best: Node2D = null
	var best_score := -1.0
	for area in $ScanArea.get_overlapping_areas():
		if not area.is_in_group(&"scannable"):
			continue
		var subject: Node2D = area.owner as Node2D
		if subject == null:
			continue
		var to: Vector2 = area.global_position - global_position
		var dist := to.length()
		if dist > SCAN_RANGE or dist < 1.0:
			continue
		var align: float = to.normalized().dot(owner.facing)
		if align < SCAN_CONE_COS:
			continue
		if not _has_line_of_sight(area):
			continue
		var score: float = align * (1.0 - dist / SCAN_RANGE)
		if score > best_score:
			best_score = score
			best = subject
	return best

func _has_line_of_sight(target: Node2D) -> bool:
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(
		global_position, target.global_position, 1 << 0)   # world_static
	return space.intersect_ray(q).is_empty()

func _reset() -> void:
	if _elapsed > 0.0:
		scan_progress.emit(0.0)
	_target = null
	_elapsed = 0.0

func _is_scanning() -> bool:
	return Input.is_action_pressed("scan") and owner.state == PlayerController.State.JOURNAL
```

**Scan reward:** unlocks the creature's Journal entry, permanently reveals its weakness in the HUD, and applies a **`+45%` damage multiplier** against that species for the rest of the game. Scanning is never wasted effort and never needs repeating.

### 5.5 UV / invisible ink

`F` toggles the blacklight. Works in two places off one mechanic:

**On the page.** Each Journal page has an optional `uv_layer` texture composited under the visible ink. The UV cone is a radial mask in page-space, following the mouse or right stick.

```glsl
// res://shaders/uv_reveal.gdshader
shader_type canvas_item;

uniform sampler2D uv_layer : source_color;
uniform vec2  beam_pos = vec2(0.5);
uniform float beam_radius : hint_range(0.0, 1.0) = 0.22;
uniform float beam_softness : hint_range(0.01, 0.5) = 0.12;
uniform float beam_on : hint_range(0.0, 1.0) = 0.0;
uniform vec3  ink_color : source_color = vec3(0.486, 1.0, 0.247);  // uv_ink
uniform vec3  wash_color : source_color = vec3(0.608, 0.420, 1.0); // uv_beam

void fragment() {
    vec4 page = texture(TEXTURE, UV);
    vec4 hidden = texture(uv_layer, UV);

    float d = distance(UV, beam_pos);
    float mask = (1.0 - smoothstep(beam_radius, beam_radius + beam_softness, d)) * beam_on;

    // Blacklight washes the page violet, then hidden ink glows through.
    page.rgb = mix(page.rgb, page.rgb * wash_color * 1.35, mask * 0.65);
    page.rgb = mix(page.rgb, ink_color, hidden.a * mask);

    COLOR = page;
}
```

**In the world.** The same beam reveals `uv_marking` nodes — cipher glyphs on walls, hidden door outlines, Ford's warnings. These are `CanvasItem`s at `modulate.a = 0` that fade in with the beam's world-space overlap. Doc 3 places them as coordinate triggers.

UV mode costs no stamina but sets `Weirdness.pulse(0.25)` while active — the world gets slightly wrong-looking when you're looking at it wrong.

### 5.6 Ciphers

The show's ciphers are systemic, not per-chapter one-offs. One class, used by every chapter doc. Cipher progression per chapter is set in the Doc 6+ schedule (Caesar → Atbash → A1Z26 → Vigenère).

```gdscript
# res://core/cipher.gd
class_name Cipher

static func caesar(text: String, shift: int) -> String:
	var out := ""
	for i in text.length():
		var c := text.unicode_at(i)
		if c >= 65 and c <= 90:
			out += char(posmod(c - 65 + shift, 26) + 65)
		elif c >= 97 and c <= 122:
			out += char(posmod(c - 97 + shift, 26) + 97)
		else:
			out += text[i]
	return out

static func atbash(text: String) -> String:
	var out := ""
	for i in text.length():
		var c := text.unicode_at(i)
		if c >= 65 and c <= 90:
			out += char(25 - (c - 65) + 65)
		elif c >= 97 and c <= 122:
			out += char(25 - (c - 97) + 97)
		else:
			out += text[i]
	return out

## "4-9-16-16-5-18" -> "DIPPER". Any non-digit separates numbers.
static func a1z26_decode(text: String) -> String:
	var out := ""
	var num := ""
	for i in text.length() + 1:
		var ch := text[i] if i < text.length() else " "
		if ch >= "0" and ch <= "9":
			num += ch
		else:
			if not num.is_empty():
				var n := int(num)
				if n >= 1 and n <= 26:
					out += char(64 + n)
				num = ""
			if ch == " ":
				out += " " if not out.ends_with(" ") else ""
	return out.strip_edges()

static func a1z26_encode(text: String) -> String:
	var parts: PackedStringArray = []
	for i in text.length():
		var c := text.to_upper().unicode_at(i)
		if c >= 65 and c <= 90:
			parts.append(str(c - 64))
	return "-".join(parts)

## Key advances only on alphabetic characters — true Vigenère.
static func vigenere(text: String, key: String, decode := false) -> String:
	if key.is_empty():
		return text
	var k := key.to_upper()
	var out := ""
	var ki := 0
	for i in text.length():
		var c := text.unicode_at(i)
		var upper := c >= 65 and c <= 90
		var lower := c >= 97 and c <= 122
		if not (upper or lower):
			out += text[i]
			continue
		var base := 65 if upper else 97
		var shift := k.unicode_at(ki % k.length()) - 65
		if decode:
			shift = -shift
		out += char(posmod(c - base + shift, 26) + base)
		ki += 1
	return out
```

**Cipher puzzle flow:** a glyph string is found in the world (wall, page, UV marking) → the player opens the Journal's decode pane → types the plaintext → the pane enqueues `JOURNAL_SUBMIT_REQUEST` (Doc 00 §8.3) → at priority 12 the resolver runs `CipherLock`, which validates case-insensitively, ignoring non-alphanumerics → the entry unlocks. Wrong answers are unlimited and free. These are flavor and discovery, never a progress wall — **every cipher-locked door has a non-cipher path**, because a player stuck on a Vigenère key should not be stuck on the chapter.

---

## 6. Anomalous physics

Three systems cover every supernatural physical effect in the series.

### 6.1 Anomaly fields (gravity shifts)

An `Area2D` writing into `external_force` on any body inside it. Doc 3 paints these into zones.

```gdscript
# res://world/nodes/anomaly_field.gd
class_name AnomalyField
extends Area2D

enum Kind {
	PULL,        ## toward center — the gravity hill, portal suction
	PUSH,        ## away from center — repulsion wards, blast zones
	DRIFT,       ## constant vector — wind, current, conveyor
	ORBIT,       ## tangential — swirling debris, portal accretion
	LIFT,        ## fake-Z upward — floating anomalies
	INVERT,      ## reverses input direction — mindscape, Bipper's influence
}

@export var kind: Kind = Kind.PULL
@export var strength: float = 900.0       ## px/s²
@export var drift_vector := Vector2.ZERO  ## DRIFT only
@export var falloff := true               ## linear falloff to the edge
@export var radius: float = 300.0
@export_range(0.0, 1.0) var weirdness_contribution: float = 0.4

func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if not body is CharacterBody2D and not body.has_method("apply_field"):
			continue
		var to_center: Vector2 = global_position - body.global_position
		var dist := to_center.length()
		var scale_f := 1.0
		if falloff and radius > 0.0:
			scale_f = clampf(1.0 - dist / radius, 0.0, 1.0)

		var force := Vector2.ZERO
		match kind:
			Kind.PULL:   force = to_center.normalized() * strength * scale_f
			Kind.PUSH:   force = -to_center.normalized() * strength * scale_f
			Kind.DRIFT:  force = drift_vector * scale_f
			Kind.ORBIT:  force = to_center.normalized().orthogonal() * strength * scale_f
			Kind.LIFT:
				var hb: HeightBody = body.get_node_or_null("HeightBody")
				if hb:
					hb.vertical_velocity -= strength * scale_f * _delta
					hb.grounded = false
			Kind.INVERT: force = -body.velocity * 2.0 * scale_f

		force.y *= 0.62                      # DEPTH_RATIO
		if body is CharacterBody2D and "external_force" in body:
			body.external_force += force

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		Weirdness.pulse(weirdness_contribution)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		Weirdness.release()
```

**Canonical uses:** the gravity anomaly hill (`LIFT` + `ORBIT`), the portal chamber (`PULL`, ramping with the activation sequence), the bottomless pit (`PULL` + `LIFT` inverted), Weirdmageddon's floating landmass fields (`LIFT` + `DRIFT`), the mindscape (`INVERT`).

### 6.2 Time loops & rewind

A ring buffer of state snapshots. Powers Blendin's time tape, the Chapter 7 loop puzzles, and Globnar.

```gdscript
# res://core/time_recorder.gd
class_name TimeRecorder
extends Node

const SAMPLE_HZ := 20.0
const BUFFER_SECONDS := 30.0
const MAX_SAMPLES := int(SAMPLE_HZ * BUFFER_SECONDS)   # 600

class Snapshot:
	var t: float
	var position: Vector2
	var velocity: Vector2
	var facing: Vector2
	var height: float
	var anim: StringName
	var health: int

var _buffer: Array[Snapshot] = []
var _accum := 0.0
var recording := true

@export var target: Node2D

func _physics_process(delta: float) -> void:
	if not recording:
		return
	_accum += delta
	if _accum < 1.0 / SAMPLE_HZ:
		return
	_accum = 0.0

	var s := Snapshot.new()
	s.t = Time.get_ticks_msec() / 1000.0
	s.position = target.global_position
	s.velocity = target.velocity if "velocity" in target else Vector2.ZERO
	s.facing = target.facing if "facing" in target else Vector2.DOWN
	s.height = target.get_node("HeightBody").height if target.has_node("HeightBody") else 0.0
	s.anim = target.current_animation if "current_animation" in target else &"idle"
	s.health = target.health.current if target.has_node("Health") else 0

	_buffer.append(s)
	if _buffer.size() > MAX_SAMPLES:
		_buffer.pop_front()

## Rewind N seconds. Returns false if the buffer doesn't reach back that far.
func rewind(seconds: float) -> bool:
	var steps := int(seconds * SAMPLE_HZ)
	if _buffer.size() <= steps:
		return false
	var s: Snapshot = _buffer[_buffer.size() - 1 - steps]
	_buffer.resize(_buffer.size() - steps)
	_apply(s)
	return true

## Replay this recording as a non-interactive ghost — the "past self" in loops.
func spawn_ghost(ghost_scene: PackedScene) -> Node2D:
	var g := ghost_scene.instantiate()
	g.set_meta(&"snapshots", _buffer.duplicate())
	return g

func _apply(s: Snapshot) -> void:
	target.global_position = s.position
	if "velocity" in target:
		target.velocity = s.velocity
	if target.has_node("HeightBody"):
		target.get_node("HeightBody").height = s.height
	if target.has_node("Health"):
		target.get_node("Health").set_current(s.health)
```

600 snapshots × ~60 bytes ≈ 36 KB per recorded entity. Recording the player plus three entities is under 150 KB — irrelevant, including on web.

**Time loop puzzles** work by recording a segment, resetting the region, and spawning a ghost that replays it — so "past Dipper" holds a lever while "present Dipper" walks through the door. The ghost is `enemy_body` layer-off and `world_static` collision-on, so it can stand on pressure plates but never blocks you.

### 6.3 Floating artifacts

Any prop with a `HeightBody` and `gravity_z = 0`, plus a bob:

```gdscript
# res://world/nodes/floating_prop.gd
extends Node2D

@export var bob_amplitude := 14.0
@export var bob_period := 3.2
@export var spin_speed := 0.4
@export var base_height := 90.0

@onready var _hb: HeightBody = $HeightBody
var _phase := 0.0

func _ready() -> void:
	_phase = randf() * TAU          # desync a room full of them
	_hb.gravity_z = 0.0
	_hb.grounded = false

func _physics_process(delta: float) -> void:
	_phase += TAU / bob_period * delta
	_hb.height = base_height + sin(_phase) * bob_amplitude
	_hb._sync()
	$Visual.rotation += spin_speed * delta
```

Randomizing `_phase` per instance is the difference between "eerie floating debris" and "obviously the same animation eight times."

---

## 7. Health, stamina, failure

### 7.1 Health

```gdscript
# res://actors/player/health.gd
class_name Health
extends Node

signal damaged(amount: int, from: Node2D)
signal depleted
signal healed(amount: int)

@export var max_pips: int = 6
var current: int = 6

const IFRAME_DURATION := 0.90
const KNOCKBACK_SPEED := 340.0

const IFRAME_TICKS := int(round(IFRAME_DURATION / (1.0 / 60.0)))   # 54

var _invulnerable := false
var _iframe_ticks_left := 0

## Superseded call path — Doc 00 §2.4, §0.2. take_damage() is called only by
## RuntimeDirector at priority 3/4; an enemy hitbox publishes a DAMAGE event and
## never calls this. The i-frame window is counted in ticks by tick(), below.
func take_damage(amount: int, from: Node2D = null) -> bool:
	if _invulnerable or current <= 0:
		return false
	current = maxi(current - amount, 0)
	_invulnerable = true
	damaged.emit(amount, from)

	if from and owner is CharacterBody2D:
		var dir: Vector2 = (owner.global_position - from.global_position).normalized()
		dir.y *= 0.62
		owner.velocity = dir * KNOCKBACK_SPEED
		owner.surface_friction = PlayerController.FRICTION_KNOCKBACK

	if current == 0:
		depleted.emit()

	_iframe_ticks_left = IFRAME_TICKS
	return true

## Called by RuntimeDirector once per resolved tick (Doc 00 §4.1 step 5b).
func tick() -> void:
	if _iframe_ticks_left <= 0:
		return
	_iframe_ticks_left -= 1
	if _iframe_ticks_left == 0:
		_invulnerable = false
```

Base 6 pips, +2 per upgrade to a cap of 14. Most enemies deal 1; bosses deal 2–3.

**i-frames are 0.90 s** — generous. The Journal fumble is 0.80 s, which fits *inside* the i-frame window. That is deliberate and load-bearing: getting hit while reading costs you tempo and control, but cannot immediately cost you a second pip. The punish is real without being a death spiral.

### 7.2 Stamina

| Property | Value |
|---|---|
| Max | 100 |
| Run drain | 18/s |
| Dodge cost | 25 flat |
| Grapple cost | 20 flat |
| Regen | 30/s |
| Regen delay after use | 0.60 s |
| Exhausted lockout | Cannot run below 10; hard lock until 25 |

Stamina does **not** gate walking, interacting, reading, or scanning. Exploration is never taxed.

### 7.3 Blackout & checkpoints

At zero pips: no game-over screen. Screen desaturates over 0.6 s, Dipper crumples, cut to black, and he wakes at the last checkpoint with a short in-character beat (Mabel poking him, Soos apologizing for something unrelated, Stan denying that anything happened).

| Rule | Value |
|---|---|
| Progress lost | **None.** Flags, items, Journal entries, and ciphers all persist |
| Position | Last activated checkpoint |
| Health on wake | Full |
| Cost | Time, and any in-progress scan |
| Enemies | Respawned in the current room only |

```gdscript
# res://world/nodes/checkpoint.gd
class_name Checkpoint
extends Area2D

@export var checkpoint_id: StringName
@export var zone_id: StringName
@export var wake_line_id: StringName     ## dialogue played on respawn here

## Superseded by Doc 00 §6.2 — publish only. A checkpoint must never commit while
## a gated transition is fading, and RuntimeDirector's arming check owns that.
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		RuntimeEvents.enqueue(RuntimeEvent.Type.CHECKPOINT_REACHED, self, {
			&"id": checkpoint_id, &"zone_id": zone_id,
			&"position": global_position, &"wake_line_id": wake_line_id,
		})
```

Committing a checkpoint also triggers an autosave (Doc 00 §9.1), which is why the commit has to be resolver-owned rather than fired from an overlap.

Checkpoint placement rule for Doc 3: every zone entrance, every boss arena door, and any point where backtracking would exceed ~90 s.

---

## 8. Interaction

```gdscript
# res://actors/player/interactor.gd
class_name Interactor
extends Area2D

const RADIUS := 46.0
const FORWARD_OFFSET := 28.0
const FACING_WEIGHT := 0.35

signal target_changed(target: Node2D)

var current: Node2D = null

func _physics_process(_delta: float) -> void:
	position = owner.facing * FORWARD_OFFSET
	var best: Node2D = null
	var best_score := -INF

	for a in get_overlapping_areas():
		if not a.is_in_group(&"interactable") or not a.get("enabled"):
			continue
		var to: Vector2 = a.global_position - owner.global_position
		var dist := to.length()
		if dist > RADIUS + FORWARD_OFFSET:
			continue
		var align: float = to.normalized().dot(owner.facing)
		var score: float = -dist + align * FACING_WEIGHT * RADIUS
		if score > best_score:
			best_score = score
			best = a

	if best != current:
		current = best
		target_changed.emit(current)

## Superseded by Doc 00 §6.1 — `E` publishes an intent; it never calls interact()
## directly, because a same-tick hit must be able to cancel it.
func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed(&"interact") and current:
		RuntimeEvents.enqueue(RuntimeEvent.Type.INTERACT_REQUEST, self,
			{&"target": current})
		get_viewport().set_input_as_handled()
```

Weighting by facing as well as distance stops the maddening case of two adjacent objects where the "wrong" one is 3 px closer.

Target selection above is unchanged and still runs every physics tick. `RuntimeDirector` re-verifies range, facing, and `can_interact()` at commit time (Doc 00 §6.1), because the target may have moved or despawned since the intent was published.

---

## 9. Companion AI

No pathfinding. A breadcrumb queue: the companion walks the path *you already walked*, delayed. It looks natural, is impossible to get stuck, and costs nothing.

```gdscript
# res://actors/npc/companion_follower.gd
class_name CompanionFollower
extends CharacterBody2D

const CRUMB_INTERVAL := 0.10
const FOLLOW_DELAY := 0.85          ## seconds behind the player
const TELEPORT_DISTANCE := 620.0
const ARRIVE_RADIUS := 34.0
const CATCHUP_SPEED := 380.0
const WALK_SPEED := 210.0

@export var leader: Node2D

var _crumbs: Array[Vector2] = []
var _accum := 0.0

func _physics_process(delta: float) -> void:
	_accum += delta
	if _accum >= CRUMB_INTERVAL:
		_accum = 0.0
		_crumbs.append(leader.global_position)
		var max_crumbs := int(FOLLOW_DELAY / CRUMB_INTERVAL) + 4
		while _crumbs.size() > max_crumbs:
			_crumbs.pop_front()

	if global_position.distance_to(leader.global_position) > TELEPORT_DISTANCE:
		_warp_behind_camera()
		return

	if _crumbs.is_empty():
		return

	var goal: Vector2 = _crumbs[0]
	var to := goal - global_position
	if to.length() < ARRIVE_RADIUS:
		velocity = velocity.move_toward(Vector2.ZERO, 2400.0 * delta)
	else:
		var gap := global_position.distance_to(leader.global_position)
		var speed := CATCHUP_SPEED if gap > 260.0 else WALK_SPEED
		var target := to.normalized() * speed
		target.y *= 0.62
		velocity = velocity.move_toward(target, 1800.0 * delta)

	move_and_slide()

func _warp_behind_camera() -> void:
	_crumbs.clear()
	global_position = leader.global_position - leader.facing * 90.0
	velocity = Vector2.ZERO
```

Companions are on layer `companion_body`, which does **not** mask `player_body`. They pass through you. Every top-down game that lets a follower physically block a doorway regrets it.

Companion combat behavior is per-chapter and scripted — Mabel grapples, Soos body-blocks, Wendy throws. Specced in each chapter doc, not here.

---

## 10. Tuning table

**If it feels wrong, these are the numbers to change.** All in one place, all safe to adjust without touching logic.

| Symptom | Constant | File |
|---|---|---|
| Movement feels sluggish | `ACCEL_GROUND` ↑ | `player_controller.gd` |
| Character slides after stopping | `FRICTION_GROUND` ↑ | `player_controller.gd` |
| Diagonal movement looks wrong | `DEPTH_RATIO` | `player_controller.gd` |
| Journal too safe / too punishing | `FUMBLE_DURATION` | `journal.gd` |
| Reading mid-fight never worth it | `journal_speed` ↑ | `player_controller.gd` |
| Scanning too tedious | `SCAN_DURATION` ↓ | `scanner.gd` |
| Combat too hard | `IFRAME_DURATION` ↑ | `health.gd` |
| Dodge feels unreliable | i-frame window start | `dodge` state |
| Floating looks static | `bob_amplitude`, `_phase` randomization | `floating_prop.gd` |
| Companion gets left behind | `CATCHUP_SPEED` ↑ / `FOLLOW_DELAY` ↓ | `companion_follower.gd` |

---

## 11. Validation

```gdscript
# res://tests/test_all.gd — godot --headless --script res://tests/test_all.gd
extends SceneTree

func _init() -> void:
	# --- Ciphers, against known vectors -------------------------------------
	assert(Cipher.caesar("HELLO", 3) == "KHOOR", "caesar encode")
	assert(Cipher.caesar("KHOOR", -3) == "HELLO", "caesar decode")
	assert(Cipher.caesar("ABC", -3) == "XYZ", "caesar negative wrap")
	assert(Cipher.atbash("HELLO") == "SVOOL", "atbash")
	assert(Cipher.atbash(Cipher.atbash("GRAVITY")) == "GRAVITY", "atbash involution")
	assert(Cipher.a1z26_decode("4-9-16-16-5-18") == "DIPPER", "a1z26 decode")
	assert(Cipher.a1z26_encode("MABEL") == "13-1-2-5-12", "a1z26 encode")
	assert(Cipher.vigenere("ATTACKATDAWN", "LEMON") == "LXFOPVEFRNHR", "vigenere encode")
	assert(Cipher.vigenere("LXFOPVEFRNHR", "LEMON", true) == "ATTACKATDAWN", "vigenere decode")
	assert(Cipher.vigenere("BILL, CIPHER!", "KEY", true).length() == 13, "vigenere preserves punctuation")

	# --- Depth ratio: a ground circle must render as the right ellipse -------
	var walked := Vector2(100.0, 100.0).normalized() * 210.0
	walked.y *= 0.62
	assert(walked.y < walked.x, "vertical movement must be foreshortened")

	# --- 8-way facing snap --------------------------------------------------
	assert(PlayerController._snap_8(Vector2(0.9, 0.1)) == Vector2.RIGHT, "snap east")
	assert(PlayerController._snap_8(Vector2(-0.7, -0.7)).is_equal_approx(
		Vector2(-1, -1).normalized()), "snap northwest")

	# --- Fumble must fit inside i-frames, or damage chains ------------------
	assert(JournalConst.FUMBLE_DURATION < Health.IFRAME_DURATION,
		"fumble (%f) must be shorter than i-frames (%f) or players get chain-hit"
		% [JournalConst.FUMBLE_DURATION, Health.IFRAME_DURATION])

	# --- Height body: what goes up must come down ---------------------------
	var hb := HeightBody.new()
	hb.launch(600.0)
	assert(not hb.grounded, "launch must leave the ground")
	for i in 240:
		hb._physics_process(1.0 / 60.0)
	assert(hb.grounded and is_zero_approx(hb.height), "must return to ground")

	print("physics: all checks passed")
	quit()
```

---

## 12. Contracts this document exports

1. `DEPTH_RATIO = 0.62`. Anything circular on the ground is drawn with `scale.y = 0.62`.
2. Character origin = ground contact (Doc 1 §6.1). Body ellipse rests on it; Y-sort keys off it.
3. Three shapes per character: body (feet), hurtbox (torso+head), hitbox (attack frames only).
4. Height is fake, via `HeightBody.height`, and only ever affects visuals + shadow — never collision.
5. `external_force` is the only channel by which the world pushes a body. Fields write it; it clears every tick.
6. **The world never pauses.** No system may call `get_tree().paused = true` outside the pause menu.
7. Damage force-closes the Journal for 0.80 s. Every enemy design must account for a reading player.
7a. **`OPEN_TIME = 0.42 s` is canonical everywhere.** Character animation may continue past it (Doc 1 §7.1) but must never gate input, movement, scanning, or UI.
8. Scanning is permanent and global — a species is never scanned twice.
9. Every cipher-locked path has a non-cipher alternative.
10. Failure costs time, never progress.
