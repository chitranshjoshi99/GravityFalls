# DOCUMENT 3 — World Maps & Environment Architecture

**Consumes:** Doc 1 (palettes, `Weirdness`), Doc 2 (collision layers, `DEPTH_RATIO`, checkpoints, anomaly fields)
**Feeds:** Doc 4 (map UI), Doc 5 (zone BGM), Docs 6–25 (chapter gating, set-pieces)

---

## 0. Locked decisions

| Decision | Value |
|---|---|
| Seam model | **B — stream neighbors, hide the seam.** 2–3 zones resident max |
| Environment art | Tileable ground + hand-painted prop PNGs |
| Scale | Compact. Shack → Town ≈ 41 s walking, ≈ 18 s by cart |
| Vehicle | Golf cart, unlocks Ch 9, roads only |
| Tile size | 128 × 128 px |
| Interiors | Separate scenes, not streamed |

---

## 1. Coordinate system

### 1.1 One world space

Every exterior zone lives in a **single shared world coordinate space**. A zone's scene is authored at local origin `(0, 0)`, and `ZoneManager` positions its root at the zone's world offset when instantiated. Nothing in a zone scene ever hardcodes a world coordinate — always local, always offset at load.

```
world_position = zone_local_position + zone.grid_offset * CELL
CELL = Vector2(1920, 1080)   # one screen
```

Grid units are screens. A zone at `grid_offset = (5, 5)` with `grid_size = (2, 2)` occupies world rect `(9600, 5400)` → `(13440, 7560)`.

### 1.2 The exterior grid

Hand-laid so every claimed neighbor is genuinely edge-adjacent. §11 validates this — the grid is the easiest thing in the project to break silently.

```
        col 0      col 1      col 2      col 3      col 4      col 5      col 6
      ┌──────────┬──────────┬──────────┬──────────┬──────────┬──────────┬──────────┐
row 0 │          │          │          │                     │          │          │
row 1 │          │          │          │       LAKE 2×2      │          │          │
      ├──────────┼──────────┼──────────┼──────────┼──────────┼──────────┼──────────┤
row 2 │          │                     │                     │                     │
row 3 │          │     CLIFFS 2×2      │   WOODS NORTH 2×3   │   MANSION GR. 2×2   │
row 4 │          │                     │                     │                     │
      ├──────────┴──────────┴──────────┼──────────┴──────────┼──────────┴──────────┤
row 5 │                                │                     │                     │
row 6 │           TOWN 3×2             │  WOODS SOUTH 2×2    │    SHACK EXT 2×2    │
      ├──────────┬──────────┬──────────┼──────────┴──────────┼──────────┴──────────┤
row 7 │          │ DUSK 1×1 │          │
      └──────────┴──────────┴──────────┘
```

| Zone ID | Offset (cells) | Size | World origin | World px | Unlocks |
|---|---|---|---|---|---|
| `z_shack_ext` | (5, 5) | 2×2 | (9600, 5400) | 3840×2160 | Ch 1 |
| `z_woods_south` | (3, 5) | 2×2 | (5760, 5400) | 3840×2160 | Ch 1 |
| `z_woods_north` | (3, 2) | 2×3 | (5760, 2160) | 3840×3240 | Ch 2 |
| `z_town` | (0, 5) | 3×2 | (0, 5400) | 5760×2160 | Ch 3 |
| `z_lake` | (3, 0) | 2×2 | (5760, 0) | 3840×2160 | Ch 2 |
| `z_dusk2dawn_lot` | (1, 7) | 1×1 | (1920, 7560) | 1920×1080 | Ch 4 |
| `z_cliffs` | (1, 2) | 2×2 | (1920, 2160) | 3840×2160 | Ch 5 |
| `z_mansion_grounds` | (5, 2) | 2×2 | (9600, 2160) | 3840×2160 | Ch 16 |

33 exterior screens total. Shack centre `(11520, 6480)` → Town centre `(2880, 6480)` = **8640 px ≈ 41 s** at walk speed 210, **18 s** by cart at 480.

### 1.3 Adjacency graph

| Boundary | Shared edge | Seam opens |
|---|---|---|
| `z_shack_ext` ↔ `z_woods_south` | col 4\|5, rows 5–6 | Ch 1 (open from the start) |
| `z_woods_south` ↔ `z_town` | col 2\|3, rows 5–6 | Ch 3 |
| `z_woods_south` ↔ `z_woods_north` | row 4\|5, cols 3–4 | Ch 2 |
| `z_woods_north` ↔ `z_lake` | row 1\|2, cols 3–4 | Ch 2 |
| `z_woods_north` ↔ `z_cliffs` | col 2\|3, rows 2–3 | Ch 5 |
| `z_woods_north` ↔ `z_mansion_grounds` | col 4\|5, rows 2–3 | Ch 16 |
| `z_town` ↔ `z_dusk2dawn_lot` | row 6\|7, col 1 | Ch 4 |

### 1.4 `ZoneDef` resource

```gdscript
# res://world/zone_def.gd
class_name ZoneDef
extends Resource

@export var id: StringName
@export_file("*.tscn") var scene_path: String
@export var grid_offset: Vector2i
@export var grid_size: Vector2i = Vector2i.ONE

@export_group("Presentation")
@export var palette: Palette
@export var bgm_id: StringName
@export_range(0.0, 1.0) var ambient_weirdness: float = 0.0
@export var is_interior: bool = false

@export_group("Progression")
## Chapter at which this zone becomes reachable at all.
@export var unlock_chapter: int = 1
## Chapter at which its boundaries become streamed seams instead of gated fades.
@export var seam_chapter: int = 17
@export var neighbors: Array[StringName] = []

func world_rect() -> Rect2:
	var cell := ZoneManager.CELL
	return Rect2(Vector2(grid_offset) * cell, Vector2(grid_size) * cell)

func world_origin() -> Vector2:
	return Vector2(grid_offset) * ZoneManager.CELL
```

---

## 2. Layer architecture

The brief's requirement — foreground interaction isolated from atmospheric background — is enforced by a fixed layer stack every exterior zone scene must follow. Deviating breaks Y-sorting.

### 2.1 The stack

| `z_index` | Layer node | Y-sorted | Contents |
|---|---|---|---|
| −100 | `ParallaxFar` | ✗ | Sky, distant mountains. Scroll 0.15× |
| −80 | `ParallaxMid` | ✗ | Distant treeline, town skyline. Scroll 0.45× |
| −50 | `TileGround` | ✗ | Terrain TileMapLayer — grass, dirt, path, floor, water |
| −40 | `TileDecal` | ✗ | Puddles, leaf litter, cracks, painted shadows |
| −20 | `PropsBehind` | ✗ | Low scenery the player always walks in front of: kerbs, rugs, low fences |
| **0** | **`YSort`** | **✓** | **Everything that sorts with the player** — actors, trees, buildings, interactables, enemies |
| +40 | `Overhead` | ✗ | Tree canopies, roof overhangs, bridges. Always drawn over actors |
| +60 | `Weather` | ✗ | Rain, snow, dust motes, fireflies |
| +80 | `LightingOverlay` | ✗ | `CanvasModulate` + `Light2D` nodes |
| +100 | `WeirdnessGrade` | ✗ | Doc 1 §2 `ColorRect`. Own `CanvasLayer` |

`YSort` is the only layer with `y_sort_enabled = true`. Doc 1 §6.1 put every character's origin at ground contact, and Doc 2 rested the body ellipse on that line — that's what makes sorting correct here. A tree's `Node2D` origin goes at its **trunk base**, not its centre, for exactly the same reason.

### 2.2 Canopy fade

Anything on `Overhead` covering walkable ground carries a fade trigger, or players get lost under a tree.

```gdscript
# res://world/overhead_fade.gd
class_name OverheadFade
extends Area2D

@export var target: CanvasItem
@export var faded_alpha: float = 0.42
@export var fade_time: float = 0.22

var _tween: Tween

func _ready() -> void:
	body_entered.connect(_on_change.bind(true))
	body_exited.connect(_on_change.bind(false))

func _on_change(body: Node2D, entering: bool) -> void:
	if not body.is_in_group(&"player"):
		return
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(target, "modulate:a",
		faded_alpha if entering else 1.0, fade_time)
```

The trigger `Area2D` matches the canopy's **ground footprint**, not its drawn extent — they differ, because the canopy is drawn well above the trunk it belongs to.

### 2.3 Parallax and the streaming problem

Godot's `Parallax2D` scrolls relative to the camera, which works fine within one zone but **tears at a streamed seam** — two adjacent zones each carrying their own parallax produce a visible discontinuity as you cross.

Fix: parallax lives on the **world root, not the zone**. One `ParallaxFar` and one `ParallaxMid` for the entire exterior world, with layer textures swapped by cross-fade on zone change (0.8 s). Zone scenes contain no parallax nodes at all.

```gdscript
# res://world/sky_controller.gd — on the world root, above all zones
func set_backdrop(far: Texture2D, mid: Texture2D, duration := 0.8) -> void:
	var t := create_tween().set_parallel()
	t.tween_property($ParallaxFar/Next, "texture", far, 0.0)
	t.tween_property($ParallaxFar/Next, "modulate:a", 1.0, duration)
	t.tween_property($ParallaxMid/Next, "texture", mid, 0.0)
	t.tween_property($ParallaxMid/Next, "modulate:a", 1.0, duration)
	t.chain().tween_callback(_promote_next)
```

---

## 3. Zone streaming

The system that makes the Act IV semi-open world work. Written once, then left alone.

### 3.1 Two boundary states

Every boundary carries both, and swaps on a chapter flag:

| State | Active when | Behaviour |
|---|---|---|
| **`GateTransition`** | `chapter < seam_chapter`, or neighbour locked | Walk into it → 0.35 s fade → old zone freed, new zone loaded → fade in. A visible transition |
| **`SeamLink`** | `chapter >= seam_chapter` and neighbour unlocked | Neighbour is already loaded and aligned. Walk straight across. No fade, no hitch |

Both are authored on the same `ZoneBoundary` node at zone-edge midpoints, so flipping to seamless is a flag change, not a re-authoring pass.

```gdscript
# res://world/zone_boundary.gd
class_name ZoneBoundary
extends Area2D

@export var to_zone: StringName
@export var spawn_marker: StringName          ## marker in the destination scene
@export var edge_normal: Vector2 = Vector2.RIGHT

func _ready() -> void:
	body_entered.connect(_on_entered)

## Superseded by Doc 00 §6.2, §7.5 — the boundary publishes a request and never
## starts a transition itself. Validation (unlocked? Journal closed? player FREE
## or DRIVING?) happens at RuntimeDirector priority 2.
func _on_entered(body: Node2D) -> void:
	if not body.is_in_group(&"player"):
		return
	if ZoneManager.is_seam_open(ZoneManager.current_zone, to_zone):
		return                                # SeamLink: activation volume handles it
	RuntimeEvents.enqueue(RuntimeEvent.Type.GATED_ZONE_REQUEST, self,
		{&"to": to_zone, &"spawn_marker": spawn_marker})
```

A locked destination is refused by the resolver, which emits the in-character "not yet" line — so a refusal cannot fire while the player is mid-fade, mid-cutscene, or already blacked out.

### 3.2 `ZoneManager`

```gdscript
# res://world/zone_manager.gd — Autoload "ZoneManager"
extends Node

const CELL := Vector2(1920, 1080)
const STREAM_MARGIN := 720.0      ## start loading a neighbour this close to its edge
const UNLOAD_MARGIN := 2400.0     ## free a zone once this far from its bounds
const SEAM_BLOCK_GRACE := 0.25    ## fallback wipe if the player beats the loader

signal zone_entered(id: StringName)
signal zone_loaded(id: StringName)

@export var registry: Array[ZoneDef] = []

var current_zone: StringName = &""
var _defs: Dictionary = {}                    # StringName -> ZoneDef
var _live: Dictionary = {}                    # StringName -> Node2D
var _loading: Dictionary = {}                 # StringName -> path
var _world_root: Node2D
var _player: Node2D

func _ready() -> void:
	for d in registry:
		_defs[d.id] = d

func _physics_process(_delta: float) -> void:
	if _player == null or current_zone == &"":
		return
	_poll_loads()
	_stream_neighbors()
	_cull_distant()

# --- streaming ------------------------------------------------------------

func _stream_neighbors() -> void:
	var def: ZoneDef = _defs[current_zone]
	for nid in def.neighbors:
		if _live.has(nid) or _loading.has(nid):
			continue
		if not is_unlocked(nid) or not is_seam_open(current_zone, nid):
			continue
		var ndef: ZoneDef = _defs[nid]
		if ndef.is_interior:
			continue                          # Doc 00 §7.6 — interiors never stream
		if _distance_to_rect(_player.global_position, ndef.world_rect()) > STREAM_MARGIN:
			continue
		_loading[nid] = ndef.scene_path
		ResourceLoader.load_threaded_request(ndef.scene_path)

func _poll_loads() -> void:
	for nid in _loading.keys():
		var path: String = _loading[nid]
		match ResourceLoader.load_threaded_get_status(path):
			ResourceLoader.THREAD_LOAD_LOADED:
				_instantiate(nid, ResourceLoader.load_threaded_get(path))
				_loading.erase(nid)
			ResourceLoader.THREAD_LOAD_FAILED:
				push_error("Zone load failed: %s" % path)
				_loading.erase(nid)
			_:
				pass                          # still in flight

func _instantiate(id: StringName, packed: PackedScene) -> void:
	var def: ZoneDef = _defs[id]
	var inst: Node2D = packed.instantiate()
	inst.name = String(id)
	inst.position = def.world_origin()        # ← the whole trick
	_world_root.add_child(inst)
	_live[id] = inst
	zone_loaded.emit(id)

func _cull_distant() -> void:
	for id in _live.keys():
		if id == current_zone:
			continue
		var def: ZoneDef = _defs[id]
		if _distance_to_rect(_player.global_position, def.world_rect()) > UNLOAD_MARGIN:
			_live[id].queue_free()
			_live.erase(id)

# --- queries --------------------------------------------------------------

func is_unlocked(id: StringName) -> bool:
	return GameState.chapter >= (_defs[id] as ZoneDef).unlock_chapter

func is_seam_open(from_id: StringName, to_id: StringName) -> bool:
	if not _defs.has(from_id) or not _defs.has(to_id):
		return false
	var a: ZoneDef = _defs[from_id]
	var b: ZoneDef = _defs[to_id]
	return GameState.chapter >= maxi(a.seam_chapter, b.seam_chapter) \
		and is_unlocked(to_id)

## Renamed to activate_zone() by Doc 00 §7.2, which makes this the single commit
## path for current zone, palette floor, and BGM — exteriors and interiors alike.
## Called only by RuntimeDirector, never by a ZoneActivationVolume directly.
func activate_zone(id: StringName) -> void:
	if id == current_zone:
		return
	current_zone = id
	var def: ZoneDef = _defs[id]
	Weirdness.set_zone_floor(def.ambient_weirdness)
	AudioDirector.set_zone(def.bgm_id)
	zone_entered.emit(id)

static func _distance_to_rect(p: Vector2, r: Rect2) -> float:
	var dx: float = maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dy: float = maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return Vector2(dx, dy).length()
```

### 3.3 The race condition, and the fallback

The failure case: the player sprints at a boundary and arrives before the background load finishes. Handled in two stages.

1. **Soft block.** Each `SeamLink` owns a thin `StaticBody2D` on `world_static`, disabled by default. If the player is inside `STREAM_MARGIN` and the neighbour is still `_loading`, it enables — Dipper bumps a half-second and the load lands. Almost always invisible.
2. **Grace wipe.** If the player is still pressed against the block after `SEAM_BLOCK_GRACE` (0.25 s), fall through to a `GateTransition` with a fast wipe. Ugly-ish, extremely rare, and always better than a stall.

`STREAM_MARGIN = 720` gives 3.4 s of warning at walk speed, 2.1 s at run — comfortably more than a zone load takes on any target machine. Retune it only if stage 2 ever actually fires.

### 3.4 Budget

Worst case is a corner where three zones meet: current + two neighbours resident. At ~28 MB of texture per exterior zone, peak is roughly **90 MB** regardless of world size. That is the number that keeps the web export viable, and it does not grow as chapters are added.

---

## 4. Environment authoring

### 4.1 TileSet

| Property | Value |
|---|---|
| Tile size | 128 × 128 |
| Terrain sets | `grass`, `dirt_path`, `stone_path`, `wood_floor`, `carpet`, `water_edge`, `snow`, `weird_flesh` (Act V) |
| Autotiling | Godot terrain bitmask, 47-tile blob per terrain |
| Physics layer | `world_static` (bit 1), authored per tile |
| Custom data | `footstep_material: StringName` → Doc 5 SFX; `is_road: bool` → cart speed |

Placeholder tiles are flat 128 × 128 fills of Doc 1 palette colours with a 2 px darker border — enough to read terrain boundaries while playtesting layout, and they swap for real tiles with no re-authoring.

### 4.2 Props

Individually painted PNGs on the `YSort` layer, origin at ground contact.

| Prop class | Y-sorted | Collision | Examples |
|---|---|---|---|
| `PropBlocking` | ✓ | Ellipse at base | Trees, the Shack, boulders, totem pole |
| `PropDecor` | ✓ | none | Bushes, signs, crates |
| `PropOverhead` | ✗ (`Overhead`) | none | Canopies, roof overhangs |
| `PropInteractable` | ✓ | `interactable` Area2D | Doors, chests, vending machine, readables |
| `PropScannable` | ✓ | `scannable` Area2D | Anomalous flora, creature nests, glyph stones |

Collision ellipses use `DEPTH_RATIO`: a tree trunk 90 px wide gets `radius_x = 45, radius_y = 28`.

---

## 5. Core zone specifications

### 5.1 The Mystery Shack

The hub. Exterior streams; interiors are separate scenes reached through doors.

**`z_shack_ext`** (3840 × 2160) — the Shack building, gift-shop porch, totem pole, golf cart parking, the sign with the falling **S**, the woods treeline north and east, the road west.

**Interiors** (separate scenes, no streaming):

| Scene | Access | Notes |
|---|---|---|
| `int_giftshop` | Front door | Hub of the hub. Stan's counter, merch shelves, the vending machine |
| `int_living_room` | Gift shop door | TV, armchair. Chapter cutscene stage |
| `int_kitchen` | Living room | |
| `int_attic` | Stairs | Dipper + Mabel's room. **Save point, Journal upgrades** |
| `int_stan_room` | Living room, locked until Ch 12 | |
| `int_lab_l1` | **Vending machine**, code entry | Unlocks Ch 12 |
| `int_lab_l2` | Elevator | Ford's study, the desk, cipher wheel |
| `int_lab_l3` | Elevator | **Portal chamber.** `PULL` anomaly field, ramps across Ch 12→17 |
| `int_ford_study` | Bookshelf in `int_lab_l2` | Hidden. Journals 1 & 2 |

**Vending machine.** A `PropInteractable` whose interaction is a 4-button code entry. Correct code is discoverable three ways: found written in Journal 3 under UV (Ch 11), overheard from Stan (Ch 12 cutscene), or brute-forced (496 combinations — tedious but permitted, per Doc 2 §5.6's no-hard-walls rule).

**Portal chamber weirdness ramp** — the room's `ambient_weirdness` is chapter-driven, so the same scene gets steadily more wrong without being re-authored:

| Chapter | `ambient_weirdness` | Read |
|---|---|---|
| 12 | 0.35 | Cold, dormant, humming |
| 13–16 | 0.45 | Active but stable |
| 17 | 0.85 | Countdown — full grade, aberration, vignette |
| 18+ | 0.60 | Spent, cracked, leaking |

### 5.2 Deep Woods

Two zones (`z_woods_north` 2×3, `z_woods_south` 2×2) — the connective tissue. Every other zone touches one of them.

- **Canopy density** drives navigation. `Overhead` canopies are heavy enough that the woods read as enclosed; the fade system (§2.2) keeps it playable.
- **The clearing grid.** Nine hand-placed clearings act as landmarks and checkpoints. Without them a tiled forest is unnavigable — this is the single most important layout rule in the zone.
- **Gnome territory** (Ch 1), north-west of `z_woods_south`.
- **The gravity anomaly hill** — `z_woods_north`, world `(7200, 3400)`. `LIFT` + `ORBIT` fields, floating debris props. Introduced Ch 5, used as a traversal shortcut once the cart exists.
- **Ford's bunker hatch** — `z_woods_north`, world `(6400, 4100)`, under a hollow tree. Invisible until scanned (Ch 13).

### 5.3 Lake Gravity Falls

`z_lake` (3840 × 2160). Water uses a `water_edge` terrain with a shader (scrolling normal + `DEPTH_RATIO`-squashed reflection ellipses).

- Boathouse and dock, north shore. Boat rental — the Ch 2 Gobblewonker set-piece launches here.
- **Boat traversal:** `HeightBody` bobbing, `DRIFT` anomaly field for current, walk disabled on deck.
- Shallows are walkable at 130 px/s (Doc 2 §3.1); deep water is `world_static` with a shoreline nudge rather than drowning.
- **Scuttlebutt Island**, north-east, reachable only by boat. Cipher-heavy. Hosts one of the ten sigils.

### 5.4 Northwest Mansion

`z_mansion_grounds` (3840 × 2160) + `int_mansion` interior. Locked until Ch 16.

- Grounds: topiary maze, wrought-iron gate, fountain. The maze is a genuine navigation puzzle with a UV-marked correct route.
- Interior is **one scene with room-based camera framing**, not separate scenes per room — Ch 16's ghost pursuit requires unbroken movement between rooms. The camera snaps to per-room bounds via `Camera2D.limit_*` set by room trigger volumes.
- **Room-count matters mechanically:** the ghost tracks the player across the whole interior, so it must all be resident.
- Palette override: `pal_mansion` — colder, higher-contrast, `ambient_weirdness` 0.15 rising to 0.70 during the haunting.

### 5.5 Dusk 2 Dawn

`z_dusk2dawn_lot` (1920 × 1080) + `int_dusk2dawn`. Chapter 4.

Smallest exterior zone, deliberately — it's a pressure-cooker. `ambient_weirdness` 0.45 baseline, the highest of any Act I location.

- Interior is a single room, aisles as `PropBlocking`, deliberately sightline-hostile.
- Lighting: `CanvasModulate` near-black, player flashlight cone is the only light. Doc 2's UV beam reveals the ghosts' handwriting on the walls.
- **Ma & Pa ghost fight** uses `INVERT` anomaly fields (Doc 2 §6.1) on the aisle floors — the store literally turns your controls against you.

---

## 6. Hidden coordinate triggers

The brief's requirement: ciphers and secrets baked into level geometry rather than bolted on. Six trigger types, all `Area2D` on `trigger_volume`, all registered with world coordinates.

| Type | Revealed by | Payload |
|---|---|---|
| `UV_MARKING` | UV beam (Doc 2 §5.5) | Cipher text, hidden door outline, Ford's warning |
| `CIPHER_GLYPH` | Line of sight, always visible | Feeds the Journal decode pane |
| `COORD_SEQUENCE` | Standing on N spots in order | Opens a cache; no visual hint until the first spot is found |
| `SCAN_ONLY` | Journal scan | Reveals an invisible prop — the bunker hatch, a hollow tree |
| `DIG_SPOT` | Shovel item + UV | Buried caches |
| `ZODIAC_SIGIL` | Varies per sigil | **Collectible — see §6.2** |

```gdscript
# res://world/secret_trigger.gd
class_name SecretTrigger
extends Area2D

enum Reveal { UV_MARKING, CIPHER_GLYPH, COORD_SEQUENCE, SCAN_ONLY, DIG_SPOT, ZODIAC_SIGIL }

@export var secret_id: StringName
@export var reveal: Reveal = Reveal.UV_MARKING
@export var journal_entry: StringName
@export_multiline var cipher_text: String
@export var cipher_kind: StringName = &"caesar"     ## caesar | atbash | a1z26 | vigenere
@export var cipher_key: String = ""
@export var visual: CanvasItem

func _ready() -> void:
	if visual:
		visual.modulate.a = 0.0
	if GameState.is_secret_found(secret_id):
		_reveal_now()

## Called by RuntimeDirector at priority 14, only while triggers are armed
## (Doc 00 §6.3). The Area2D callback publishes SECRET_REVEAL_REQUEST and stops.
func try_reveal(method: Reveal) -> bool:
	if method != reveal or GameState.is_secret_found(secret_id):
		return false
	GameState.mark_secret_found(secret_id)
	_reveal_now()
	Journal.unlock_entry(journal_entry)
	AudioDirector.play_sfx(&"secret_found")
	Weirdness.pulse(0.35, 0.2)
	return true

func _reveal_now() -> void:
	if visual:
		create_tween().tween_property(visual, "modulate:a", 1.0, 0.45)
```

### 6.1 Cipher schedule by zone

Matches the show's own progression and the Doc 6+ chapter schedule.

| Chapters | Cipher | Zones seeded |
|---|---|---|
| 1–7 | Caesar (−3) | `z_shack_ext`, `z_woods_south`, `z_lake` |
| 8–12 | Atbash | `z_town`, `z_woods_north`, `z_cliffs` |
| 13–17 | A1Z26 | `int_lab_l2`, `int_ford_study`, `z_mansion_grounds` |
| 18–20 | Vigenère | All zones, keys drawn from chapter-specific plot words |

### 6.2 The Zodiac sigils

Ten symbols from Bill's wheel, one per zone, hidden by a different reveal method each. Collecting all ten is **not required** to finish the game — but doing so unlocks the full Zodiac ritual option in Chapter 20, which is a materially better ending than the fallback.

| Sigil | Owner | Zone | World coords | Reveal |
|---|---|---|---|---|
| Pine Tree | Dipper | `int_attic` | local (640, 380) | Given, Ch 1 |
| Shooting Star | Mabel | `z_shack_ext` | (10880, 6120) | `COORD_SEQUENCE`, 3 spots |
| Question Mark | Soos | `int_giftshop` | local (1180, 720) | `SCAN_ONLY` |
| Six-Fingered Hand | Ford | `int_ford_study` | local (420, 300) | Given, Ch 17 |
| Ice Bag | Stan | `int_kitchen` | local (890, 540) | `UV_MARKING` |
| Glasses | McGucket | `z_cliffs` | (2760, 3010) | `DIG_SPOT` |
| Pentagram | Gideon | `z_town` | (1640, 6300) | `CIPHER_GLYPH`, Atbash |
| Llama | Pacifica | `z_mansion_grounds` | (10420, 2880) | `UV_MARKING`, maze centre |
| Stitched Heart | Robbie | `z_dusk2dawn_lot` | (2510, 7990) | `SCAN_ONLY` |
| Crescent Moon | Wendy | `z_lake` | (7180, 640) | `COORD_SEQUENCE`, Scuttlebutt Island |

Placing them across all ten zones means the sigil hunt is what actually motivates re-walking the world once the seams open in Act IV. That's the payoff for building the streaming system.

---

## 7. Golf cart

Unlocks Chapter 9. Roads only — a `is_road` custom-data flag on tiles.

| Property | Value |
|---|---|
| Top speed (road) | 480 px/s |
| Top speed (off-road) | 165 px/s |
| Acceleration | 420 px/s² |
| Braking | 900 px/s² |
| Turn rate | 2.6 rad/s at speed, scaling to 0 when stopped |
| Body ellipse | 54 × 34 |
| Passengers | Driver + 1 companion (auto-boards) |

```gdscript
# res://vehicles/golf_cart.gd  (excerpt)
func _physics_process(delta: float) -> void:
	var throttle := Input.get_axis("move_down", "move_up")
	var steer := Input.get_axis("move_left", "move_right")

	var on_road := _tile_flag_here(&"is_road")
	var cap := ROAD_SPEED if on_road else OFFROAD_SPEED

	_speed = move_toward(_speed, throttle * cap,
		(ACCEL if throttle != 0.0 else BRAKE) * delta)

	# No turning while stopped — carts pivot on momentum, not on the spot.
	rotation += steer * TURN_RATE * (_speed / ROAD_SPEED) * delta

	velocity = Vector2.RIGHT.rotated(rotation) * _speed
	velocity.y *= 0.62                       # DEPTH_RATIO
	move_and_slide()
```

Off-road speed being *below* walking is deliberate — it keeps the cart a road vehicle without needing invisible walls, and it makes the road network itself readable as level design.

---

## 8. Interiors

Interiors are separate scenes, entered through `DoorBoundary` (a `GateTransition` variant with a 0.25 s wipe). They are never streamed: they're small, they're bounded, and the wipe is diegetic — you walked through a door.

> **Superseded by Doc 00 §7.6.** An earlier draft said "no zone-manager involvement." Interiors
> still swap palette *and* BGM (`bgm_attic`, `bgm_lab`), so they register as `ZoneDef`s with
> `is_interior = true` and commit through the same `activate_zone()` path — excluded from
> `_stream_neighbors()` and `_cull_distant()`, always gated, off-grid at `grid_offset =
> Vector2i(-1, -1)`. Everything below stands; only the commit path is shared.

| Rule | Value |
|---|---|
| Camera | Bounded to the room via `Camera2D.limit_*` |
| Palette | Interior `.tres`, applied on `_ready()` |
| Y-sort | Same stack as exteriors |
| Exterior | Freed on entry, reloaded on exit at the door marker |
| Exception | `int_mansion` — one scene, room-based camera limits (§5.4) |

---

## 9. Checkpoints

Doc 2 §7.3 placement rule applied to this grid.

| Zone | Checkpoints |
|---|---|
| `z_shack_ext` | Porch, cart park |
| `int_attic` | Bedside — **primary save point** |
| `z_woods_south` | Two clearings |
| `z_woods_north` | Three clearings, anomaly hill, bunker hatch |
| `z_town` | Main street centre, diner, arcade |
| `z_lake` | Dock, Scuttlebutt landing |
| `z_cliffs` | Water tower base |
| `z_dusk2dawn_lot` | Lot entrance (**not** inside — the store is the pressure) |
| `z_mansion_grounds` | Gate, maze exit |
| `int_lab_l3` | Chamber entrance only |

---

## 10. Zone-scene authoring checklist

Every exterior zone scene must have, in order:

1. Root `Node2D` named for its zone ID, at local `(0, 0)`.
2. The §2.1 layer stack, exact names, exact `z_index`. **No parallax nodes.**
3. `TileGround` sized to `grid_size * CELL` exactly — a short tilemap leaves a visible void at a seam.
4. `ZoneBoundary` areas at every edge listed in §1.3, `edge_normal` pointing outward.
5. Spawn `Marker2D`s matching every inbound boundary's `spawn_marker`.
6. Checkpoints per §9.
7. `PaletteRegion` with the zone's `.tres`.
8. `SecretTrigger`s at the §6 coordinates.
9. `OverheadFade` on every canopy covering walkable ground.
10. A `ZoneActivationVolume` 96 px inside every seamless inbound edge — **one per inbound direction, not one per boundary**. Doc 00 §7.1. This is the only node permitted to request `activate_zone()`.
11. A `SeamBlocker` on every seam-capable boundary, disabled by default. Doc 00 §7.1; it owns §3.3's soft block and publishes the grace-wipe fallback.

---

## 11. Validation

The hand-laid grid in §1.2 is the highest-risk artefact in this document — an overlap or a false adjacency produces zones that visibly intersect or seams that never open, and neither fails loudly.

```gdscript
# res://world/test_world.gd — godot --headless --script res://world/test_world.gd
extends SceneTree

const CELL := Vector2(1920, 1080)

func _init() -> void:
	var zones := {
		# id: [offset_x, offset_y, size_x, size_y]
		"z_shack_ext":       [5, 5, 2, 2],
		"z_woods_south":     [3, 5, 2, 2],
		"z_woods_north":     [3, 2, 2, 3],
		"z_town":            [0, 5, 3, 2],
		"z_lake":            [3, 0, 2, 2],
		"z_dusk2dawn_lot":   [1, 7, 1, 1],
		"z_cliffs":          [1, 2, 2, 2],
		"z_mansion_grounds": [5, 2, 2, 2],
	}
	var adjacency := [
		["z_shack_ext", "z_woods_south"],
		["z_woods_south", "z_town"],
		["z_woods_south", "z_woods_north"],
		["z_woods_north", "z_lake"],
		["z_woods_north", "z_cliffs"],
		["z_woods_north", "z_mansion_grounds"],
		["z_town", "z_dusk2dawn_lot"],
	]

	# --- no two zones may overlap ------------------------------------------
	var ids := zones.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a := _rect(zones[ids[i]])
			var b := _rect(zones[ids[j]])
			assert(not a.intersects(b),
				"zones overlap: %s and %s" % [ids[i], ids[j]])

	# --- every declared neighbour must actually share an edge --------------
	for pair in adjacency:
		var a := _rect(zones[pair[0]])
		var b := _rect(zones[pair[1]])
		assert(_shares_edge(a, b),
			"declared neighbours are not edge-adjacent: %s <-> %s" % pair)

	# --- adjacency must be symmetric ---------------------------------------
	var graph := {}
	for id in ids:
		graph[id] = []
	for pair in adjacency:
		graph[pair[0]].append(pair[1])
		graph[pair[1]].append(pair[0])

	# --- every zone reachable from the starting zone -----------------------
	var seen := {}
	var queue: Array = ["z_shack_ext"]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		if seen.has(cur):
			continue
		seen[cur] = true
		for n in graph[cur]:
			queue.append(n)
	for id in ids:
		assert(seen.has(id), "zone unreachable from z_shack_ext: %s" % id)

	# --- the stated walk time must hold ------------------------------------
	var shack := _rect(zones["z_shack_ext"]).get_center()
	var town := _rect(zones["z_town"]).get_center()
	var seconds := shack.distance_to(town) / 210.0
	assert(seconds > 30.0 and seconds < 55.0,
		"Shack->Town walk is %.1fs, outside the compact-scale target" % seconds)

	# --- streaming budget: at most 3 zones within margin of any point ------
	for id in ids:
		var c := _rect(zones[id]).get_center()
		var near := 0
		for other in ids:
			if _dist_to_rect(c, _rect(zones[other])) <= 720.0:
				near += 1
		assert(near <= 3, "%s has %d zones within stream margin (budget 3)" % [id, near])

	print("world: all checks passed")
	quit()

static func _rect(d: Array) -> Rect2:
	return Rect2(Vector2(d[0], d[1]) * CELL, Vector2(d[2], d[3]) * CELL)

static func _shares_edge(a: Rect2, b: Rect2) -> bool:
	var touch_v := is_equal_approx(a.end.x, b.position.x) or is_equal_approx(b.end.x, a.position.x)
	var touch_h := is_equal_approx(a.end.y, b.position.y) or is_equal_approx(b.end.y, a.position.y)
	var overlap_y: float = minf(a.end.y, b.end.y) - maxf(a.position.y, b.position.y)
	var overlap_x: float = minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x)
	return (touch_v and overlap_y > 0.0) or (touch_h and overlap_x > 0.0)

static func _dist_to_rect(p: Vector2, r: Rect2) -> float:
	var dx: float = maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dy: float = maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return Vector2(dx, dy).length()
```

---

## 12. Contracts this document exports

1. One world coordinate space. Zone scenes author at local `(0,0)`; `ZoneManager` applies `grid_offset * CELL`.
2. The §2.1 layer stack is mandatory. `YSort` is the only Y-sorted layer.
3. **No zone scene contains parallax.** Sky and mid-ground live on the world root.
4. Every boundary carries both `GateTransition` and `SeamLink`; `seam_chapter` selects.
5. At most 3 zones resident. Peak texture budget ~90 MB, flat as the world grows.
6. Prop and character origins sit at ground contact — required for correct sorting.
7. Interiors are separate scenes and never stream. `int_mansion` is the sole one-scene exception.
8. Ten Zodiac sigils, one per zone, optional but ending-affecting.
9. Every cipher-gated secret has a non-cipher path (Doc 2 §5.6 carried forward).
