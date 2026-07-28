# DOCUMENT 1 — Theme, Animation & Asset Tokens

**Project:** Gravity Falls 2D RPG · Godot 4.x · GDScript
**Status:** Foundation layer. Every later document consumes these tokens; nothing here should be redefined downstream.

---

## 0. Locked stack (decisions carried into every doc)

| Decision | Value |
|---|---|
| Engine | Godot 4.x, GDScript |
| Export targets | macOS native `.app`, Web (HTML5) for Itch.io |
| Canvas | 1920×1080, `stretch_mode = canvas_items`, `stretch_aspect = expand` |
| Character rendering | `Skeleton2D` cutout rigs, `Polygon2D` parts with bone weights |
| Combat | Real-time action |
| World | Progressive hub-and-spoke → semi-open by Act IV |
| Art state | None authored yet — procedural placeholders ship first, PNGs hook in later |
| Rig scope (this doc) | Dipper, Mabel, Stan, Soos, Wendy + one parameterized NPC template |
| Global FX | Single-uniform `weirdness` palette-ramp shader |
| Token format | `Resource` (`.tres`) + `Tokens` autoload of typed constants |

**Authoring resolution rule:** all character and prop art is authored at **2× reference scale** and imported at `scale = 0.5`. Retina MacBook displays render the 1920×1080 canvas at up to 2880×1800; 2× source keeps vector line work crisp under that upscale without shipping 4× textures to the web build.

---

## 1. Color system

### 1.1 Palette A — Earthy Northwest Woods

The default world grade. Desaturated, cool-leaning, heavy on value separation rather than hue variety — the show's exteriors read as flat vector planes, so contrast has to come from value, not saturation.

| Token | Hex | Use |
|---|---|---|
| `pine_deep` | `#1B3B2F` | Far treeline, canopy shadow, silhouette layer |
| `pine_mid` | `#2E5D45` | Mid-ground conifers, primary foliage mass |
| `moss` | `#6B8F4E` | Ground cover, undergrowth, near-camera foliage |
| `fern_light` | `#9CB46A` | Rim-lit leaf edges, sunlit grass |
| `bark_dark` | `#3A2A1E` | Trunk shadow side, root systems |
| `bark_mid` | `#5C4033` | Trunk base tone, fallen logs, wooden signage |
| `soil` | `#7A5C3E` | Dirt paths, cliff faces, trail texture |
| `fog_grey` | `#B9C4BC` | Atmospheric depth layer, distance haze |
| `sky_summer` | `#8FC1DE` | Daytime sky flat |
| `sunbeam` | `#F2D98D` | God rays, warm highlight passes |
| `stone_cold` | `#6E7B78` | Rock formations, the cliffside water tower |

### 1.2 Palette B — Mystery Shack interiors

Warmer, more saturated, lower value range. The Shack should feel enclosed and lamp-lit against the cool exterior — the palette swap on entering is a deliberate emotional beat.

| Token | Hex | Use |
|---|---|---|
| `shack_wall` | `#6B4A2F` | Interior plank walls |
| `shack_floor` | `#4A3220` | Floorboards, stair treads |
| `shack_shingle` | `#3D2B1F` | Roof, exterior siding shadow |
| `lamp_warm` | `#E8B75C` | Bulb bodies, lit window panes from outside |
| `lamp_glow` | `#FFE3A3` | Light falloff gradient inner stop |
| `gift_shop_red` | `#A6392E` | Merch shelving, "MYSTERY SHACK" signage |
| `curtain_purple` | `#4B2E5A` | Attic drapes, Mabel's side of the room |
| `dust_beam` | `#D9C7A0` | Floating dust motes in window shafts |
| `vending_teal` | `#2F6B6B` | The vending machine (portal door) |
| `taxidermy_tan` | `#B08D5F` | Wall-mounted oddities, jackalope, fake exhibits |

### 1.3 Palette C — Supernatural neons

Never used in Palette A/B zones at full strength. These are *intrusions* — the visual grammar is that neon appearing in an earthy frame means something is wrong.

| Token | Hex | Use |
|---|---|---|
| `bill_yellow` | `#FFD23F` | Bill Cipher body fill |
| `bill_yellow_hot` | `#FFE873` | Bill's glow bloom, rage-state saturation |
| `bill_black` | `#0E0E0E` | Bill's brick lines, hat, bowtie, all cipher glyphs |
| `portal_blue` | `#2BD9FF` | Portal core, Ford's tech, quantum destabilizer |
| `portal_cyan_pale` | `#A8F2FF` | Portal edge bleed, rift hairlines |
| `portal_pink` | `#FF3FA4` | Portal counter-rotation ring, rift interior |
| `portal_magenta_deep` | `#8B1E5B` | Portal shadow side, dimensional tear depth |
| `anomaly_green` | `#39FF88` | Anomaly scanner overlay, gnome/creature aura |
| `mindscape_violet` | `#6A2CE0` | Dreamscape void, mindscape ground plane |
| `weird_red` | `#E8382A` | Weirdmageddon sky, Bill's throne, endgame vignette |
| `uv_ink` | `#7CFF3F` | Journal invisible ink, revealed |
| `uv_beam` | `#9B6BFF` | Blacklight cone from the UV flashlight |

### 1.4 Palette D — Journal & document surfaces

| Token | Hex | Use |
|---|---|---|
| `journal_cover` | `#7A3B2E` | Journal 1/2/3 leather binding |
| `journal_gold` | `#C9A227` | Six-fingered hand, embossed numeral |
| `journal_page` | `#E8DCC0` | Page substrate |
| `journal_page_aged` | `#D2C09A` | Edge staining, older entries |
| `journal_ink` | `#2B2118` | Handwritten body text |
| `journal_ink_red` | `#8C2F22` | Ford's warnings, "TRUST NO ONE" |
| `journal_sketch` | `#5A4A38` | Diagram line work |

### 1.5 `Palette` resource

```gdscript
# res://tokens/palette.gd
class_name Palette
extends Resource

@export_group("Foliage & Terrain")
@export var pine_deep: Color = Color("1b3b2f")
@export var pine_mid: Color = Color("2e5d45")
@export var moss: Color = Color("6b8f4e")
@export var fern_light: Color = Color("9cb46a")
@export var bark_dark: Color = Color("3a2a1e")
@export var bark_mid: Color = Color("5c4033")
@export var soil: Color = Color("7a5c3e")
@export var stone_cold: Color = Color("6e7b78")

@export_group("Atmosphere")
@export var fog: Color = Color("b9c4bc")
@export var sky: Color = Color("8fc1de")
@export var light_warm: Color = Color("f2d98d")

@export_group("Interior")
@export var wall: Color = Color("6b4a2f")
@export var floor_tone: Color = Color("4a3220")
@export var accent: Color = Color("a6392e")

@export_group("Anomaly")
@export var anomaly_primary: Color = Color("2bd9ff")
@export var anomaly_secondary: Color = Color("ff3fa4")
@export var anomaly_glow: Color = Color("39ff88")

@export_group("Grade")
## Baseline weirdness applied on zone entry, before event-driven spikes.
@export_range(0.0, 1.0) var ambient_weirdness: float = 0.0
```

### 1.6 Zone palette instances

One `.tres` per zone. Doc 3 binds these to map scenes; each zone's `PaletteRegion` node applies its palette on `_ready()` and tweens the grade on transition.

| File | Zone | `ambient_weirdness` |
|---|---|---|
| `pal_woods.tres` | Deep Woods, trails | 0.05 |
| `pal_shack_interior.tres` | Mystery Shack, gift shop, attic | 0.00 |
| `pal_shack_basement.tres` | Lab levels, portal room | 0.35 |
| `pal_town.tres` | Main street, diner, arcade | 0.02 |
| `pal_lake.tres` | Lake Gravity Falls, boathouse | 0.05 |
| `pal_mansion.tres` | Northwest Mansion | 0.15 |
| `pal_dusk2dawn.tres` | Dusk 2 Dawn convenience store | 0.45 |
| `pal_bunker.tres` | Ford's bunker, Shape Shifter chamber | 0.40 |
| `pal_mindscape.tres` | Dreamscape / mindscape | 0.75 |
| `pal_weirdmageddon.tres` | Act V overworld | 1.00 |

---

## 2. The weirdness grade — global palette-ramp shader

One float drives the entire supernatural visual axis. Doc 2 raises it on anomaly proximity, Doc 3 sets a floor per zone, Doc 5 keys the audio crossfade to the same value. Weirdmageddon becomes a parameter change, not a re-authored world.

```glsl
// res://shaders/weirdness.gdshader
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

uniform float weirdness : hint_range(0.0, 1.0) = 0.0;
uniform vec3  tint_hot  : source_color = vec3(1.000, 0.824, 0.247); // bill_yellow
uniform vec3  tint_cold : source_color = vec3(1.000, 0.247, 0.643); // portal_pink
uniform float aberration_px = 6.0;
uniform float vignette_strength = 0.55;
uniform float saturation_push = 0.6;

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 shift = SCREEN_PIXEL_SIZE * aberration_px * weirdness;

    // Channel separation — reality coming apart at the seams.
    vec3 col;
    col.r = texture(screen_tex, uv + shift).r;
    col.g = texture(screen_tex, uv).g;
    col.b = texture(screen_tex, uv - shift).b;

    float luma = dot(col, vec3(0.299, 0.587, 0.114));

    // Highlights bend toward Bill-yellow, shadows toward portal-pink.
    vec3 graded = mix(tint_cold, tint_hot, smoothstep(0.35, 0.85, luma));
    col = mix(col, col * graded * 1.15, weirdness * 0.75);

    // Saturation climbs with weirdness.
    col = mix(vec3(luma), col, 1.0 + weirdness * saturation_push);

    // Vignette closes in as the world destabilizes.
    float d = distance(uv, vec2(0.5));
    col = mix(col, col * (1.0 - d * vignette_strength), weirdness);

    COLOR = vec4(col, 1.0);
}
```

### 2.1 `Weirdness` autoload

```gdscript
# res://tokens/weirdness.gd  — Autoload singleton "Weirdness"
extends Node

signal level_changed(value: float)

const DEFAULT_FADE := 1.2

var _zone_floor: float = 0.0
var _event_level: float = 0.0
var _mat: ShaderMaterial
var _tween: Tween

## Effective level is the stronger of the zone baseline and any active event.
var level: float:
	get: return maxf(_zone_floor, _event_level)

func bind(mat: ShaderMaterial) -> void:
	_mat = mat
	_apply(level)

## Called by PaletteRegion on zone entry. Persistent until the next zone.
func set_zone_floor(value: float, duration: float = DEFAULT_FADE) -> void:
	_zone_floor = clampf(value, 0.0, 1.0)
	_retween(duration)

## Called by anomalies, boss phases, cutscenes. Decays back to the zone floor.
func pulse(value: float, duration: float = 0.4) -> void:
	_event_level = clampf(value, 0.0, 1.0)
	_retween(duration)

func release(duration: float = DEFAULT_FADE) -> void:
	_event_level = 0.0
	_retween(duration)

func _retween(duration: float) -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	var target := level
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_apply, _current(), target, duration)

func _current() -> float:
	return _mat.get_shader_parameter("weirdness") if _mat else 0.0

func _apply(v: float) -> void:
	if _mat:
		_mat.set_shader_parameter("weirdness", v)
	level_changed.emit(v)
```

**Web export note:** `hint_screen_texture` requires a screen-reading backbuffer. On the HTML5 target this forces a copy each frame. Budget it: the grade `ColorRect` lives on a single `CanvasLayer` at layer 100 and is set `visible = false` whenever `level < 0.01`, skipping the backbuffer copy entirely in the ~60% of gameplay that sits at zero weirdness.

---

## 3. Character proportion system

### 3.1 Units

All character geometry derives from two numbers: **total height `H`** (pixels at reference scale 1.0) and the **head ratio `k`**. Head diameter `D = H · k`. Everything else is a fraction of `H` or `D`. Rescaling a character to a new size is one field change, not a re-measure.

**Origin convention:** every character's root `Node2D` origin sits at **ground contact, horizontally centered between the feet**. Y-sorting, shadow placement, and Doc 2's collision capsule all key off this. Never offset it.

### 3.2 Segment fractions (shared across all humanoids)

| Segment | Length | Width |
|---|---|---|
| `torso` | `0.26 · H` | `0.62 · D` (×`torso_scale`) |
| `arm_upper` | `0.19 · H` | `arm_w` |
| `arm_fore` | `0.17 · H` | `arm_w · 0.92` |
| `hand` | `0.055 · H` | `arm_w · 1.5` (mitten, no fingers) |
| `leg_upper` | `0.20 · H` | `leg_w` |
| `leg_lower` | `0.18 · H` | `leg_w · 0.90` |
| `foot` | `0.05 · H` | `leg_w · 1.7` |
| `neck` | **none** | Head mounts directly to torso top — the show has no visible neck on kids |

These are **bone lengths, not art pieces.** The skeleton keeps two bones per limb (§6.1), but the geometry and texture spanning them is single and continuous (§4.2–4.3). A limb's hose length is `arm_upper + arm_fore` (or `leg_upper + leg_lower`); its width runs from `arm_w` at the shoulder to `arm_w · 0.92` at the wrist, tapering across the one polygon via `Tube.capsule(..., width_end)`.

### 3.3 Core cast

| Character | `H` | `k` | `D` | `arm_w` | `leg_w` | `torso_scale` | Notes |
|---|---|---|---|---|---|---|---|
| **Dipper** | 258 | 0.32 | 82 | 13 | 16 | 1.00 | Cap is a separate part with its own bone — must survive `surprise` head-snap without clipping |
| **Mabel** | 250 | 0.33 | 82 | 13 | 16 | 1.15 | Sweater bulks the torso and *swallows the upper arm*: `sleeve_occlusion = 0.40` shortens the hose so it emerges at the cuff. Her `arm_hose` PNG is correspondingly shorter than Dipper's; the cuff itself belongs to the torso polygon |
| **Wendy** | 300 | 0.27 | 81 | 13 | 15 | 0.95 | Tallest silhouette in the core cast; hair is a 3-part chain with its own trailing bones |
| **Soos** | 300 | 0.30 | 90 | 17 | 20 | 1.45 | Widest torso; arms read shorter because the torso mass is larger, not because the bones changed |
| **Stan** | 296 | 0.29 | 86 | 15 | 19 | 1.30 | Fez + glasses are separate parts on the head bone; heaviest hunch — `torso` bone rests at −6° |
| **NPC adult** | 296 | 0.28 | 83 | 14 | 18 | 1.00 | Parameterized template |
| **NPC kid** | 250 | 0.32 | 80 | 12 | 15 | 1.00 | Parameterized template |

> Bill Cipher is **not** a humanoid rig and is deliberately excluded here. His geometry (equilateral triangle, single eye, floating limbs with no torso attachment, and a body that is itself a shader surface) is specified in his own chapter document. Gideon and Ford use the humanoid template with overrides and are specified at first appearance.

### 3.4 `CharacterProportions` resource

```gdscript
# res://tokens/character_proportions.gd
class_name CharacterProportions
extends Resource

@export var display_name: String = "NPC"
@export var height: float = 258.0
@export_range(0.20, 0.40) var head_ratio: float = 0.32
@export var arm_width: float = 13.0
@export var leg_width: float = 16.0
@export var torso_scale: float = 1.0
## Fraction of the upper arm hidden by clothing (Mabel's sweater = 0.4).
@export_range(0.0, 0.8) var sleeve_occlusion: float = 0.0

var head_diameter: float:
	get: return height * head_ratio

func segment(name: StringName) -> Vector2:
	## Returns Vector2(length, width) for a named segment.
	match name:
		&"torso":     return Vector2(height * 0.26, head_diameter * 0.62 * torso_scale)
		&"arm_upper": return Vector2(height * 0.19 * (1.0 - sleeve_occlusion), arm_width)
		&"arm_fore":  return Vector2(height * 0.17, arm_width * 0.92)
		&"hand":      return Vector2(height * 0.055, arm_width * 1.5)
		&"leg_upper": return Vector2(height * 0.20, leg_width)
		&"leg_lower": return Vector2(height * 0.18, leg_width * 0.90)
		&"foot":      return Vector2(height * 0.05, leg_width * 1.7)
	push_error("Unknown segment: %s" % name)
	return Vector2.ZERO
```

---

## 4. Tube-limb geometry

Rubber-hose limbs have **constant width along their length and fully rounded caps** — no tapering, no visible elbow or knee vertex. A limb is a capsule, and it bends by *deforming*, not by hinging.

### 4.1 Capsule generation

```gdscript
# res://tokens/tube.gd
class_name Tube

## Vertical capsule spanning a WHOLE limb (shoulder to wrist, hip to ankle).
## Origin at the top-center attachment point, extending +Y.
## Godot 2D is Y-down, so +Y is "away from the joint."
## `width_end` defaults to `width` (constant hose); pass a smaller value for the
## slight taper §3.2 specifies toward the wrist/ankle.
static func capsule(length: float, width: float, seg: int = 8,
		width_end: float = -1.0) -> PackedVector2Array:
	var w0 := width * 0.5
	var w1 := (width if width_end < 0.0 else width_end) * 0.5
	var pts := PackedVector2Array()

	pts.append(Vector2(w0, 0.0))       # top-right
	pts.append(Vector2(w1, length))    # bottom-right

	for i in range(1, seg):            # bottom cap, radius w1, right -> left
		var a := PI * float(i) / float(seg)
		pts.append(Vector2(cos(a) * w1, length + sin(a) * w1))

	pts.append(Vector2(-w1, length))   # bottom-left
	pts.append(Vector2(-w0, 0.0))      # top-left

	for i in range(1, seg):            # top cap, radius w0, left -> right
		var a := PI + PI * float(i) / float(seg)
		pts.append(Vector2(cos(a) * w0, sin(a) * w0))

	return pts
```

A limb is **one capsule spanning both bones**, not two capsules stacked. §4.3 maps a single texture onto it.

At `seg = 8` a limb is 18 vertices. The core cast plus four on-screen NPCs runs ~1,400 character vertices per frame — negligible, and it keeps the silhouette smooth at 2× Retina scale where a 4-segment cap would visibly facet.

### 4.2 Bone weighting — the actual hose bend

This is the part that makes or breaks the style. A limb is **one `Polygon2D`**, not two, spanning both bones and weight-blended across the middle. Two separate polygons hinged at a shared point produce a hard mechanical elbow — exactly the look to avoid.

Weight profile along the limb, parameter `t = 0` at shoulder, `t = 1` at wrist:

| `t` range | `bone_upper` weight | `bone_fore` weight |
|---|---|---|
| 0.00 – 0.38 | 1.0 | 0.0 |
| 0.38 – 0.62 | `1 - smoothstep(0.38, 0.62, t)` | `smoothstep(0.38, 0.62, t)` |
| 0.62 – 1.00 | 0.0 | 1.0 |

The 24%-of-length blend band is the hose. Narrower reads as a joint; wider reads as a noodle with no structure. Legs use the same profile with the band shifted to `0.42 – 0.66` — knees sit slightly lower proportionally than elbows.

```gdscript
static func hose_weights(t: float, blend_start := 0.38, blend_end := 0.62) -> Vector2:
	var f := smoothstep(blend_start, blend_end, t)
	return Vector2(1.0 - f, f)  # (upper, fore)
```

Applied via `Polygon2D.add_bone(path, weights)` where `weights` is a `PackedFloat32Array` with one entry per polygon vertex, `t` computed from each vertex's Y position over the limb length.

### 4.3 One texture per limb — the hose pipeline

**A limb is one polygon, so it is one texture.** There is no `arm_upper.png` and no `arm_fore.png`; there is `arm_hose_l.png`, authored as a single continuous shape from shoulder cap to wrist cap.

This is not a preference — it's forced by §4.2. The polygon's mid-region vertices are weighted to *both* bones, so as the elbow bends those vertices move to positions that belong to neither bone's local space. Two textures meeting at that band would shear apart exactly where the hose is supposed to be smoothest. One texture stretched across the whole polygon deforms with it, which is the entire reason for the single-polygon approach.

**Authoring:** the hose texture is drawn **vertically, straight, unbent** — shoulder at the top, wrist at the bottom. The rig does the bending. Any curvature painted into the texture fights the bone deformation and reads as a broken elbow.

```gdscript
## Map capsule vertices into hose-texture space.
## Polygon2D.uv is in TEXTURE PIXELS, not normalized 0..1.
static func hose_uv(points: PackedVector2Array, width: float,
		width_end: float = -1.0, margin: float = 1.0) -> PackedVector2Array:
	var w_max: float = maxf(width, width if width_end < 0.0 else width_end)
	var w0 := width * 0.5
	var uv := PackedVector2Array()
	for p in points:
		uv.append(Vector2(
			p.x + w_max * 0.5 + margin,   # x: polygon is centered on 0
			p.y + w0 + margin              # y: top cap extends to -w0
		))
	return uv

## Required source dimensions for a hose texture, at 1x reference scale.
static func hose_texture_size(length: float, width: float,
		width_end: float = -1.0, margin: float = 1.0) -> Vector2:
	var w_end: float = width if width_end < 0.0 else width_end
	return Vector2(
		maxf(width, w_end) + margin * 2.0,
		length + width * 0.5 + w_end * 0.5 + margin * 2.0
	)
```

The `margin` is the 1 px transparent border §8.1 requires; the UV offset accounts for it so linear filtering never samples outside the hose.

### 4.4 Hand and foot mounting

Hands and feet are **rigid** — weight 1.0 to the terminal bone, no blending. They are mittens: a rounded quad with a thumb bump, never articulated fingers. Feet are a single rounded wedge; the show never shows a distinct ankle.

---

## 5. Eye rendering math

The signature feature. Two large circles that touch or slightly overlap, reading as a single merged shape with a shared outline.

### 5.1 Geometry

| Quantity | Formula | Dipper (`D = 82`) |
|---|---|---|
| Eye radius `R` | `0.21 · D` | 17.2 px |
| Center separation | `2R · (1 − overlap)`, `overlap = 0.06` | 32.4 px |
| Vertical center | `0.46 · D` below head top | 37.7 px |
| Pupil radius | `0.34 · R` | 5.9 px |
| Pupil max offset from eye center | `R − pupil_r − 2` | 9.3 px |
| Outline width | `0.055 · R`, min 2 px | 2 px |

```gdscript
# res://tokens/eyes.gd
class_name Eyes

const RADIUS_RATIO   := 0.21
const OVERLAP        := 0.06
const CENTER_Y_RATIO := 0.46
const PUPIL_RATIO    := 0.34
const OUTLINE_RATIO  := 0.055

static func geometry(head_diameter: float) -> Dictionary:
	var r := head_diameter * RADIUS_RATIO
	var pupil_r := r * PUPIL_RATIO
	return {
		"radius": r,
		"separation": 2.0 * r * (1.0 - OVERLAP),
		"center_y": head_diameter * CENTER_Y_RATIO,
		"pupil_radius": pupil_r,
		"pupil_max_offset": maxf(r - pupil_r - 2.0, 0.0),
		"outline_width": maxf(r * OUTLINE_RATIO, 2.0),
	}

## Pupil position for a look-at target, clamped inside the sclera.
static func pupil_offset(look_dir: Vector2, max_offset: float) -> Vector2:
	return look_dir.limit_length(1.0) * max_offset
```

### 5.2 The merged outline trick

Do **not** compute a boolean union of the two circles. Instead, draw in four passes:

1. Two circles of radius `R + outline_width`, filled `bill_black`.
2. Two circles of radius `R`, filled white.
3. Two pupil circles at their offset positions.
4. Brows, on their own bones, above.

Because the outline circles overlap by the same amount as the sclera circles, the union outline emerges for free as a peanut silhouette — no geometry math, no seam artifact where the circles meet. This is a `_draw()`-based `EyePair` node so it stays correct at any head size.

### 5.3 Blink and expression

Blink is a **`scale.y` squash on the eye group node**, not a sprite swap: `1.0 → 0.06` over 0.06 s, hold 0.03 s, `→ 1.0` over 0.08 s. Pivot at eye center, so lids close toward the middle. Random blink interval: `randf_range(2.4, 5.8)` seconds, suppressed during `surprise` and any dialogue line tagged `wide_eyed`.

Expression is driven by **brow bones only** (rotation + Y offset) plus pupil scale. Four presets in the `Tokens` autoload:

| Preset | Brow rot (L/R) | Brow Y | Pupil scale |
|---|---|---|---|
| `neutral` | 0° / 0° | 0 | 1.00 |
| `worried` (Dipper default) | +12° / −12° | −0.04·D | 1.10 |
| `delighted` (Mabel default) | −8° / +8° | −0.08·D | 1.25 |
| `suspicious` (Stan default) | −14° / −6° | +0.05·D | 0.85 |

---

## 6. Bone hierarchy & anchor points

### 6.1 `Skeleton2D` tree

```
CharacterRoot (Node2D)          ← origin at ground contact, feet-centered
├── Shadow (Polygon2D)          ← ellipse, unparented from skeleton
├── Skeleton2D
│   └── b_hips
│       ├── b_torso
│       │   ├── b_head
│       │   │   ├── b_brow_l
│       │   │   ├── b_brow_r
│       │   │   ├── b_jaw          ← mouth part mount
│       │   │   └── b_hair_01 → b_hair_02 → b_hair_03   (Wendy/Mabel only)
│       │   ├── b_arm_l_upper → b_arm_l_fore → b_hand_l
│       │   └── b_arm_r_upper → b_arm_r_fore → b_hand_r
│       ├── b_leg_l_upper → b_leg_l_lower → b_foot_l
│       └── b_leg_r_upper → b_leg_r_lower → b_foot_r
├── Parts (Node2D)              ← all Polygon2D geometry, Y-sorted internally
└── Anchors (Node2D)
```

### 6.2 Draw order within `Parts`

Fixed `z_index` per part. Front-facing is the default; side-facing swaps the two arm groups.

| `z_index` | Part |
|---|---|
| −20 | `arm_far_hose`, `hand_far` |
| −10 | `leg_hose_l`, `leg_hose_r`, `foot_l`, `foot_r` |
| 0 | `torso` |
| 10 | `head_base`, `hair_back` |
| 20 | `eyes`, `brows`, `mouth` |
| 30 | `hair_front`, `hat` |
| 40 | `arm_near_hose`, `hand_near` |
| 50 | `held_item` |

### 6.3 Anchors

`Marker2D` nodes parented to bones. Doc 2 mounts equipment here; Doc 4 spawns UI from them.

| Anchor | Parent bone | Purpose |
|---|---|---|
| `a_hand_r` | `b_hand_r` | Flashlight, grappling hook, Journal (one-handed carry) |
| `a_hand_l` | `b_hand_l` | Journal (two-handed read pose), secondary item |
| `a_head_top` | `b_head` | Hat mount, status icons, "!" alert bubble |
| `a_face` | `b_head` | Dialogue portrait origin, emote spawn, speech-tail target |
| `a_back` | `b_torso` | Backpack, grappling hook when stowed |
| `a_chest` | `b_torso` | Damage flash origin, item-pickup arc destination |
| `a_ground` | `CharacterRoot` | Shadow, footstep dust, Doc 2 collision capsule base |
| `a_interact` | `b_hips` | Interaction-range probe origin (Doc 2 defines the radius) |

**Journal two-handed pose:** when open, the Journal reparents to `a_hand_l`, `b_arm_r_fore` drives a page-turn IK target, and the head bone tilts −8° to look down at it. This is a named pose in every character's `AnimationPlayer`, not a bespoke cutscene.

---

## 7. Animation set

Cutout rigs are keyframed on bone transforms via `AnimationPlayer` — durations, not frame counts. All timings tuned for 60 fps playback with `TRANS_SINE` easing unless noted.

| Animation | Duration | Loop | Notes |
|---|---|---|---|
| `idle` | 1.60 s | ✅ | Breathing: torso `scale.y` ±1.5%, head bob ±1.2 px, 8° arm sway |
| `walk` | 0.80 s | ✅ | 4 keys per limb; hips rise 3 px at mid-stride |
| `run` | 0.55 s | ✅ | Torso pitches +9° forward, arm swing amplitude ×1.8 |
| `interact` | 0.50 s | ❌ | Near arm reaches to `a_interact`, returns |
| `journal_raise` | **0.42 s** | ❌ | **Gating.** Book comes up to the read position. Matches Doc 2 `OPEN_TIME` exactly |
| `journal_settle` | 0.48 s | ❌ | **Non-gating.** Cosmetic follow-through — shoulders relax, head tilts down. Runs on the `UpperBody` blend layer, interruptible on any frame |
| `journal_read` | 2.40 s | ✅ | Page-flutter idle, head tilt held |
| `hurt` | 0.35 s | ❌ | Torso recoil −14°, `TRANS_BACK`, damage flash on `a_chest` |
| `surprise` | 0.60 s | ❌ | Head-snap, blink suppressed, pupils to 1.4× then settle |
| `talk` | 0.40 s | ✅ | **Jaw bone + mouth part only** — layers over any body animation |
| `fall` | — | ✅ | Static pose, limbs trail from vertical velocity |
| `land` | 0.25 s | ❌ | Knee compression 22%, `TRANS_BOUNCE` |

`talk` runs on a **separate `AnimationPlayer` targeting only `b_jaw`**, so dialogue plays over walking, reading, or falling without a combinatorial explosion of blended clips.

### 7.1 Journal opening — the 0.42 s contract

The Journal's *mechanical* open time is **0.42 s** (Doc 2 §5.1, Doc 4 §6.1, Doc 5 §5.1). The character's *visible* motion runs 0.90 s. These are not in conflict, but only because the split is explicit and one-directional:

| `t` | State | Animation | Input |
|---|---|---|---|
| 0.00 | `CLOSED → OPENING` | `journal_raise` starts. `journal_open` SFX starts | J consumed |
| **0.42** | **`OPENING → OPEN`** | `journal_raise` ends → `journal_settle` begins on `UpperBody` | **Fully live.** Speed drops to 118 px/s, scanning enabled, UI interactive |
| 0.90 | — | `journal_settle` ends, blends into `journal_read` | unchanged |

**The invariant: no gameplay state, input gate, or UI affordance depends on anything after `t = 0.42`.** `journal_settle` is presentation only. It exists so the pose doesn't snap, and it may be cut off mid-frame at any time with no mechanical consequence.

This works because `journal_settle` targets only `b_torso`, `b_head`, and the two arm chains, played through an `AnimationTree` `BlendTree` on a dedicated `UpperBody` layer — the same layering trick `talk` uses. Locomotion keeps running underneath it, so walking at journal speed during the settle is already correct without a blended walk-while-raising clip.

**Interrupts** all blend from the current pose, never from a fixed frame:

| Event | At any `t` | Result |
|---|---|---|
| `J` pressed again | ≥ 0.42 | `journal_close`, 0.30 s, from current blend pose |
| Damage taken | ≥ 0.00 | `FUMBLED`, 0.80 s (Doc 2 §5.2). Cancels raise *and* settle |
| Dodge | ≥ 0.00 | Force-close, book drops (Doc 2 §3.4) |

Because the settle is interruptible and non-gating, a player who opens and immediately closes the Journal at `t = 0.45` gets a clean blended transition rather than a desync — the mechanical state machine and the animation never need to agree on anything except the single 0.42 s boundary.

---

## 8. Sprite sheet & atlas specification

Two distinct pipelines. Do not mix them.

### 8.1 Part atlases (cutout characters — the primary pipeline)

| Property | Value |
|---|---|
| Atlas size | 2048×2048 max, one atlas per character |
| Authoring scale | 2× reference (see §0) |
| Padding | 4 px between parts, 4 px atlas border |
| Format | PNG-24 + straight alpha (**not** premultiplied) |
| Trim | Tight-trimmed with pivot metadata preserved |
| Import | `Filter: Linear`, `Mipmaps: On`, `Compress: Lossless` (macOS) / `VRAM Compressed` (web) |
| Naming | `char_<name>_<part>[_<variant>].png` |

Each part PNG must include a **1 px transparent margin** on every edge. Without it, linear filtering samples adjacent atlas pixels and produces a visible seam at the limb caps when the character scales.

**Pivot rule:** every limb hose's pivot sits at its **proximal joint** — the shoulder for `arm_hose`, the hip for `leg_hose` — matching the `Tube.capsule` origin at `(0, 0)`, offset by the 1 px margin. There is no mid-limb pivot, because there is no mid-limb seam. The head's pivot is at the base of the skull, not its center. Hands and feet pivot at their wrist/ankle attachment.

**Hose textures are exempt from tight-trimming.** They must be delivered at exactly the `Tube.hose_texture_size()` dimensions with the margin intact, because §4.3's UV mapping is computed from those dimensions rather than read from per-part metadata. Trimming a hose breaks its UVs.

### 8.2 Frame sheets (FX, props, background characters)

| Property | Value |
|---|---|
| Cell size | 256×256, uniform, **untrimmed** |
| Columns | 8, fixed |
| Rows | One per animation |
| Read order | Left→right, top→bottom |
| Sheet max | 2048×2048 (8×8 = 64 frames) |
| Naming | `fx_<name>_<anim>.png` / `prop_<name>.png` |

Uniform untrimmed cells mean `AtlasTexture` regions are pure arithmetic — `Rect2(col * 256, row * 256, 256, 256)` — with no per-frame metadata to author or drift out of sync.

**FX sheets to author** (used across many chapters, so they justify their own frames): `fx_portal_swirl`, `fx_uv_reveal`, `fx_anomaly_scan`, `fx_dust_motes`, `fx_impact_star`, `fx_bill_flame`, `fx_rift_crack`.

---

## 9. Placeholder system & PNG hook points

### 9.1 How the swap works — no node replacement

Every character part is a **`Polygon2D`**. `Polygon2D` has both a `color` and a `texture` property:

- **Texture is `null`** → renders as a flat `color` fill from the palette. This is the placeholder.
- **Texture is assigned** → renders your artwork, UV-mapped to the same polygon.

The node, the bone weights, the animations, the anchors, and the collision are **identical in both cases**. Supplying art is assigning a texture in the Inspector. There is no placeholder mode to switch off and no second code path to maintain — the game is fully playable from Chapter 1 with zero PNGs, and every chapter's animation work carries over unchanged when art lands.

### 9.2 Placeholder color assignment

Flat fills tuned so the placeholder silhouette still reads as the right character at a glance — different enough per-character that playtesting a crowd scene is not confusing.

| Character | Torso | Limbs | Head | Hat/hair |
|---|---|---|---|---|
| Dipper | `#4A6B8A` | `#D9C3A5` | `#F0D5B8` | `#E8E4DC` |
| Mabel | `#A6392E` | `#D9C3A5` | `#F0D5B8` | `#5C4033` |
| Stan | `#E8E4DC` | `#C9AE90` | `#DCC0A8` | `#A6392E` |
| Soos | `#3E7C4A` | `#B58A63` | `#C89A72` | `#5C4033` |
| Wendy | `#7A9E4C` | `#E0C9AE` | `#F0D5B8` | `#C25B2E` |
| NPC template | `Palette.accent` | `#C9AE90` | `#DCC0A8` | `Palette.wall` |

### 9.3 ► ASSETS YOU NEED TO SUPPLY

**This is the section to hand to whoever draws the art.** Everything below is a PNG the framework has a hook waiting for. Nothing else in this document requires external files.

**Per core character — 16 parts.** Drop into `res://art/characters/<name>/`, authored at 2× the §3.3 dimensions, pivots per §8.1.

**Limbs are four files, not eight.** Each arm and leg is a *single* continuous hose texture (§4.3), drawn straight and unbent, delivered at exactly the listed size with its 1 px transparent margin. Do not supply separate upper/forearm or thigh/shin pieces — they cannot be made seam-free across the weight-blend band, and their UVs would not map.

Dimensions below are Dipper's. For any other character, compute with `Tube.hose_texture_size(length, width, width_end)` from their §3.3 row and double it.

| Part file | Source dimensions (2×, Dipper example) |
|---|---|
| `head_base.png` | 164 × 164 |
| `hair_back.png` | 180 × 140 |
| `hair_front.png` | 180 × 120 |
| `hat.png` | 190 × 110 (Dipper cap, Stan fez, Soos cap — omit for Mabel/Wendy) |
| `brow_l.png`, `brow_r.png` | 44 × 16 each |
| `mouth_sheet.png` | 8 cells × 96 × 64 — closed, open-small, open-wide, smile, frown, grimace, "o", teeth |
| `torso.png` | 102 × 134 (×`torso_scale`) |
| **`arm_hose_l/r.png`** | **30 × 215 each** — one continuous shoulder-to-wrist piece, drawn straight |
| `hand_l/r.png` | 39 × 39 each |
| **`leg_hose_l/r.png`** | **36 × 231 each** — one continuous hip-to-ankle piece, drawn straight |
| `foot_l/r.png` | 54 × 26 each |

**Eyes are procedural.** Do not supply eye PNGs — §5's four-pass draw handles all sizes, blinks, and look-at directions. Supplying eye art would break the blink squash and the merged outline.

**Additionally required:**

| Asset | Spec | Blocks |
|---|---|---|
| `journal_cover.png` | 512 × 700, six-fingered hand + numeral 3 | Doc 2 Journal system |
| `journal_page_bg.png` | 1024 × 700, tiling paper texture | Doc 2 |
| FX sheets (§8.2, seven of them) | 256 px cells, 8 cols | Docs 2, 3, 5 |
| Zone background plates | Per-zone, spec'd in Doc 3 | Doc 3 |
| HUD badge set | Per-element, spec'd in Doc 4 | Doc 4 |

**Everything above has a working placeholder.** No chapter is blocked on any of it.

---

## 10. File layout

```
res://
├── tokens/
│   ├── tokens.gd                    # Autoload "Tokens" — constants, expression presets
│   ├── weirdness.gd                 # Autoload "Weirdness"
│   ├── palette.gd                   # class_name Palette
│   ├── character_proportions.gd     # class_name CharacterProportions
│   ├── tube.gd                      # class_name Tube
│   ├── eyes.gd                      # class_name Eyes
│   ├── palettes/                    # pal_woods.tres, pal_shack_interior.tres, ...
│   └── proportions/                 # prop_dipper.tres, prop_mabel.tres, ...
├── shaders/
│   └── weirdness.gdshader
├── rigs/
│   ├── rig_humanoid.tscn            # Base scene — skeleton, parts, anchors, animations
│   ├── eye_pair.tscn                # _draw()-based, §5
│   ├── dipper.tscn                  # inherits rig_humanoid, binds prop_dipper.tres
│   ├── mabel.tscn  stan.tscn  soos.tscn  wendy.tscn
│   └── npc_template.tscn
└── art/
    ├── characters/<name>/           # ► your PNGs land here
    └── fx/
```

`rig_humanoid.tscn` is an **inherited scene** base. Every character scene inherits it, overriding only the `CharacterProportions` resource and part textures. A change to the walk cycle or the hose blend band propagates to all 30+ characters at once.

---

## 11. Validation

One runnable check for the non-trivial geometry — capsule winding, weight blending, and eye clamping are exactly the things that fail silently and look subtly wrong for hours.

```gdscript
# res://tokens/test_tokens.gd  — run headless: godot --headless --script res://tokens/test_tokens.gd
extends SceneTree

func _init() -> void:
	# Capsule: closed, correct vertex count, respects width bounds.
	var c := Tube.capsule(100.0, 20.0, 8)
	assert(c.size() == 18, "capsule vertex count changed: %d" % c.size())
	for p in c:
		assert(absf(p.x) <= 10.001, "capsule exceeds half-width at %s" % p)
		assert(p.y >= -10.001 and p.y <= 110.001, "capsule exceeds cap bounds at %s" % p)

	# Tapered capsule: still closed, still 18 verts, narrower at the wrist end.
	var tap := Tube.capsule(100.0, 20.0, 8, 16.0)
	assert(tap.size() == 18, "tapered capsule vertex count changed")
	assert(absf(tap[0].x) > absf(tap[1].x), "taper must narrow toward the far end")

	# Hose UVs: every vertex must land inside the texture, margin included.
	var p := CharacterProportions.new()
	var arm_len: float = p.segment(&"arm_upper").x + p.segment(&"arm_fore").x
	var arm_w: float = p.segment(&"arm_upper").y
	var arm_w_end: float = p.segment(&"arm_fore").y
	var hose := Tube.capsule(arm_len, arm_w, 8, arm_w_end)
	var uv := Tube.hose_uv(hose, arm_w, arm_w_end)
	var tex := Tube.hose_texture_size(arm_len, arm_w, arm_w_end)
	assert(uv.size() == hose.size(), "one UV per vertex")
	for q in uv:
		assert(q.x >= 0.0 and q.x <= tex.x, "UV x=%f outside texture width %f" % [q.x, tex.x])
		assert(q.y >= 0.0 and q.y <= tex.y, "UV y=%f outside texture height %f" % [q.y, tex.y])

	# Hose weights: partition of unity, monotonic, correct at the ends.
	for i in 21:
		var t := float(i) / 20.0
		var w := Tube.hose_weights(t)
		assert(is_equal_approx(w.x + w.y, 1.0), "weights must sum to 1 at t=%f" % t)
	assert(Tube.hose_weights(0.0).x == 1.0, "shoulder must be fully upper-bone")
	assert(Tube.hose_weights(1.0).y == 1.0, "wrist must be fully fore-bone")

	# Eyes: pupil never escapes the sclera, even at extreme look angles.
	var g := Eyes.geometry(82.0)
	var off := Eyes.pupil_offset(Vector2(9.0, -4.0), g.pupil_max_offset)
	assert(off.length() <= g.pupil_max_offset + 0.001, "pupil escaped sclera")
	assert(g.pupil_radius + g.pupil_max_offset <= g.radius, "pupil geometry overflows eye")

	# Proportions: segments sum to roughly total height.
	var stack: float = p.head_diameter + p.segment(&"torso").x \
		+ p.segment(&"leg_upper").x + p.segment(&"leg_lower").x + p.segment(&"foot").x
	assert(absf(stack - p.height) < p.height * 0.05,
		"segment stack %f drifted from height %f" % [stack, p.height])

	print("tokens: all checks passed")
	quit()
```

---

## 12. Contracts this document exports

What Docs 2–5 and every chapter doc are entitled to assume:

1. `Tokens`, `Weirdness` autoloads exist and are safe to call from anywhere.
2. Character origin = ground contact, feet-centered. Y-sort and collision key off it.
3. `a_hand_r`, `a_hand_l`, `a_head_top`, `a_face`, `a_back`, `a_chest`, `a_ground`, `a_interact` exist on every humanoid rig.
4. `Weirdness.level` is the single float that supernatural intensity is expressed in — visuals, audio, and physics all read it. Nothing invents a parallel scale.
5. Every zone has a `Palette` resource with an `ambient_weirdness` floor.
6. Animation names in §7 exist on every humanoid; `talk` and `journal_settle` layer independently.
7. No art asset is a hard dependency. Placeholders render everything.
8. **A limb is one polygon and one texture.** `arm_hose_l/r`, `leg_hose_l/r` — never split at the elbow or knee. Two bones drive one continuous surface (§4.2–4.3).
9. Hose textures are authored straight and untrimmed, at exactly `Tube.hose_texture_size()`, margin included. The rig supplies all bending.
10. **The Journal is mechanically open at `t = 0.42 s`.** Nothing after that boundary may gate input, movement, scanning, or UI (§7.1).
