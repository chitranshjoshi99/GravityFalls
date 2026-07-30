extends Node
## Boot, the world root, player instancing, session begin/end — Doc 00 §3.
##
## "Nothing in Docs 1-5 mounts the first zone or creates the player" (§3.3's
## opening line). This file is the answer to that, and it is the ONE place a
## session comes into existence or stops existing.
##
## **It commits no gameplay state.** §14.1 keeps every gameplay mutation inside
## `RuntimeDirector._resolve()`, so what happens here is boot-time WIRING —
## create the world root, bind the one grade, instantiate the player, hand the
## resolver its handles, take the boot lock — and then nothing. There is no
## `_physics_process` in this file and no per-tick behaviour of any kind; §2.2's
## table gives `SessionDirector` no priority for exactly that reason.
##
## **How it reaches what does not exist yet.** Four of §3.2's collaborators are
## unbuilt: `ZoneManager` (tracker row 2.3), `AudioDirector` (3.2),
## `world_root.tscn` (2.2) and `dipper.tscn` (1.1). Naming an unregistered
## autoload as a global identifier is a parse error, and `preload()` of a
## nonexistent path is a parse error too — and under
## `godot --headless --script res://tests/test_all.gd` a parse error exits 0 with
## zero checks run (tracker row 6.1). So the two autoloads are held as nullable
## handles resolved by node path in `_ready()`, and the two scenes are loaded
## behind a `ResourceLoader.exists()` guard with a code-built minimum standing in
## until the authored scene lands. Each fallback carries a `ponytail:` comment
## naming the row that deletes it. This is rows 0.10 and 0.11's pattern — commit
## what this row genuinely owns, name the row that finishes the rest, invent no
## placeholder subsystem.
##
## **§3.1's boot sequence, steps 1-5, is deliberately not a method here.** Step 1
## is the engine's autoload order (§2.2, enforced by `project.godot`), step 2 is
## `AudioDirector._ready()`, step 3 is `Settings._ready()` — which already calls
## `load_settings()`, so preferences are applied before any UI draws — and steps
## 4-5 are the main menu's own (Doc 04 §7.1, row 3.5) calling
## `GameState.new_game()` or `load_slot(0)`. A `boot()` here would be a method
## with an empty body and no caller. What this file owns is step 6 and, through
## the resolver's countdown, step 7.

const WORLD_SCENE_PATH := "res://world/world_root.tscn"
const PLAYER_SCENE_PATH := "res://actors/player/dipper.tscn"
const GRADE_SHADER_PATH := "res://shaders/weirdness.gdshader"

## Doc 01 §2.1 names the node; §3.2 looks it up. One spelling, in one place.
const GRADE_NAME := "WeirdnessGrade"
const ACTORS_NAME := "Actors"

## Doc 01 §2.1: the one grade ColorRect lives "on its own `CanvasLayer` at layer
## 100" — above the world, below Doc 04 §0's HUD (10), menus (20) and
## transitions (30)... which are all LOWER numbers, so the grade sits under them
## deliberately: an overlay fade is not something the weirdness shader grades.
const GRADE_LAYER := 100

## §3.3's "AudioDirector.set_zone(&"bgm_menu")", and §3.1 step 4's same call.
const MENU_BGM := &"bgm_menu"

var world_root: Node2D
var player: PlayerController

## Registered ABOVE this autoload in §2.2's table (10th and 6th of 12) but
## nonexistent until rows 2.3 and 3.2, so they are reached by path rather than by
## global identifier — a name that resolves to nothing is a parse error, and this
## file must parse today. Public, because the one other writer is the suite,
## which substitutes a stub to observe §3.2's ordering.
var zone_manager: Node
var audio_director: Node


func _ready() -> void:
	zone_manager = get_node_or_null(^"/root/ZoneManager")
	audio_director = get_node_or_null(^"/root/AudioDirector")


## §3.2. New Game, Continue, and §9.5's scratch session all arrive here after
## `GameState` already holds the state to begin against.
func begin_session() -> void:
	# 1. World root: owns the Doc 3 §2.3 parallax, hosts every zone instance, and
	#    carries THE one weirdness grade for the whole game.
	world_root = _make_world_root()
	get_tree().root.add_child(world_root)

	# 1b. Bind the grade. Doc 1 §2.1 defines Weirdness.bind() and NOTHING called
	#     it until this line — the shader would have sat at its default forever.
	#     It binds here, once, to the single ColorRect on world_root. NOT per
	#     zone: three resident zones would mean three chained backbuffer copies
	#     with only one of them actually driven (Doc 3 §2.3 says the same).
	#
	#     Found recursively, which is now what §3.2 itself says: Doc 01 §2.1 puts
	#     the ColorRect on its own CanvasLayer at layer 100, so it is a GRANDCHILD,
	#     and §3.2's original flat `get_node(^"WeirdnessGrade")` could not resolve
	#     the node §2.1 specifies. Row 0.12 found that and the doc was corrected.
	#     The recursive find accepts both shapes, so row 2.2 may author either
	#     without editing this file.
	var grade := world_root.find_child(GRADE_NAME, true, false)
	if grade is CanvasItem and grade.material is ShaderMaterial:
		Weirdness.bind(grade.material)
	else:
		# Doc 00 §12 check 35 is what normally catches this, but a session that
		# boots with an ungraded world is a bug worth naming at the moment it
		# happens rather than only in the suite.
		push_error("world_root carries no %s with a ShaderMaterial — Doc 01 §2.1" % GRADE_NAME)

	# 2. Player exists before any zone does, so triggers never fire into a null.
	#    Reversing this is the classic first-frame null (§3.2's own closing note):
	#    destination Area2Ds at the spawn marker fire their one `body_entered`
	#    against whatever body is already there.
	player = _make_player()
	player.state = PlayerController.State.ZONE_TRANSITION   # locked until mounted
	_actors_parent().add_child(player)

	# 3. Wire the systems that Doc 3 §3.2 left unassigned.
	if zone_manager != null:
		zone_manager.bind(world_root, player)
	# RuntimeDirector's own docstring names this row as the only writer of both
	# handles. §3.2 lists `RuntimeDirector.bind(player)` alone because it was
	# written before the resolver needed a duck-typed zone handle (row 0.10).
	RuntimeDirector.zone_manager = zone_manager
	RuntimeDirector.bind(player)
	CombatDirector.reset()

	# 4. Mount behind an already-opaque overlay — no fade-out, we start black.
	var cp: Dictionary = GameState.data.checkpoint
	TransitionDirector.set_opaque(true)
	if zone_manager != null:
		# Marker first, raw coordinate only as a fallback (§9.2). A new game names
		# a marker it cannot resolve until the zone instantiates, which is exactly
		# why the marker — not a Vector2 — is what the checkpoint carries.
		#
		# The `await` is legitimate and is the only one in this file: it waits on
		# `ResourceLoader`, which is genuinely asynchronous, not on a tween (§3.2).
		# It sits inside this branch rather than above it so that with no
		# ZoneManager registered `begin_session()` completes synchronously — row
		# 2.3 is where the call site gains its own `await`.
		await zone_manager.mount_initial(
			cp.get(&"zone_id", &""), cp.get(&"spawn_marker", &""),
			cp.get(&"position", Vector2.ZERO)
		)
		# activate_zone() has now committed palette, weirdness floor, and BGM.

	# 5. Hand the lock to the resolver. It counts the fade in ticks and releases
	#    the player itself; the tween only mirrors it (§4.5). Boot does not await
	#    an animation to decide when gameplay starts, and `_lock_ticks` reaching
	#    zero is what starts §7.7's arrival grace — the same path a gated
	#    transition and a respawn take, so boot is not a special case.
	RuntimeDirector.take_lock(RuntimeDirector.FADE_TICKS)
	TransitionDirector.play_fade_in(RuntimeDirector.FADE_TICKS)


## §3.3. Quit to Menu, or the credits.
##
## Every line below exists to satisfy one sentence: "No gameplay autoload holds a
## reference to a freed node afterward — §12 check 12 proves it." The order is
## unbind first, free last, so nothing is ever pointed at a half-freed subtree.
func end_session() -> void:
	# §9.1's write-trigger table lists `end_session()`, and §9.1's own rule is
	# that writes are deferred to a dirty flag and flushed off the physics frame.
	# `mark_dirty()` is therefore the flush: one write site in the project, and no
	# second code path that could disagree with the autosave about what a save is.
	GameState.mark_dirty()

	RuntimeDirector.player = null
	RuntimeDirector.zone_manager = null
	if zone_manager != null:
		# §3.3 step 3. ZoneManager holds `_world_root` and `_player` (Doc 3 §3.2),
		# both about to be freed, and check 12 admits no exceptions. Row 0.12 found
		# that §3.3 named neither this nor the unbind below; both are in the doc now.
		# ponytail: unbinding is all row 0.12 can do. Freeing the resident zone
		# instances and clearing `_live`/`_loading` is the rest of step 3 and
		# belongs to row 2.3, in the file that owns those dictionaries.
		zone_manager.bind(null, null)

	CombatDirector.reset()
	Weirdness.set_zone_floor(0.0)
	# §3.3 step 5: the material belongs to the grade in the subtree below, so
	# leaving it bound would leave `Weirdness` driving a shader on dead scenery for
	# the whole time the menu is up. `bind()` on the next session's grade (§3.2
	# step 1b) is what re-arms it.
	Weirdness.bind(null)

	# "RuntimeEvents is cleared." Two swaps drain both buffers — the queue's only
	# clearing operation, and deliberately so (§2.5: nothing else clears either
	# one). Anything a quitting session published dies here rather than resolving
	# into the next one.
	RuntimeEvents.swap()
	RuntimeEvents.swap()

	if audio_director != null:
		audio_director.set_zone(MENU_BGM)
	# ponytail: "then load the menu scene" is Doc 04 §7.1's scene, row 3.5. The
	# session is fully torn down either way, which is what this method owes.

	if world_root != null:
		# queue_free(), not free(): §3.3's caller is a menu button's `pressed`
		# handler, and freeing a node in the tree from inside a signal callback is
		# the one shape Godot asks you not to use.
		world_root.queue_free()
	world_root = null
	player = null


## Row 2.2 authors `world_root.tscn` — the Doc 3 §2.3 parallax stack and the
## grade's own CanvasLayer, its 0.06 visibility skip and its CanvasModulate
## fallback all belong to that row.
# ponytail: the guard and the fallback both disappear the day row 2.2 lands; this
# becomes §3.2's `preload(WORLD_SCENE_PATH).instantiate()` and nothing else here
# changes, because every caller above reaches the grade and the actors by name.
func _make_world_root() -> Node2D:
	if ResourceLoader.exists(WORLD_SCENE_PATH):
		var packed: PackedScene = load(WORLD_SCENE_PATH)
		return packed.instantiate()
	return _minimum_world_root()


## The least world a session can begin against: somewhere to put the player, and
## THE one node in the tree that carries the weirdness shader (§12 check 35).
func _minimum_world_root() -> Node2D:
	var root := Node2D.new()
	root.name = "WorldRoot"

	var layer := CanvasLayer.new()
	layer.name = "Grade"
	layer.layer = GRADE_LAYER
	var grade := ColorRect.new()
	grade.name = GRADE_NAME
	# Full-rect by anchor preset and click-through by the native filter, for the
	# same two reasons TransitionDirector's overlay does both: Doc 01 §0's
	# `canvas_items` + `keep` makes the preset correct at every window size, and an
	# overlay that eats clicks at any alpha is felt as dead UI.
	grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load(GRADE_SHADER_PATH)
	grade.material = mat
	layer.add_child(grade)
	root.add_child(layer)

	var actors := Node2D.new()
	actors.name = ACTORS_NAME
	root.add_child(actors)
	return root


## Row 1.1 authors `dipper.tscn` on top of row 1.4's controller.
# ponytail: `PlayerController.new()` until then — the class exists (row 0.10 made
# it for the resolver's enum), the scene does not. The bare body has no sprite and
# no collision shape, which is exactly the difference row 1.1 fills in.
func _make_player() -> PlayerController:
	if ResourceLoader.exists(PLAYER_SCENE_PATH):
		var packed: PackedScene = load(PLAYER_SCENE_PATH)
		return packed.instantiate()
	return PlayerController.new()


## §3.2 step 2's `world_root.get_node(^"Actors")`, found the same recursive way
## the grade is, and falling back to the root itself: a world with nowhere named
## to put actors still has to be able to hold the player.
func _actors_parent() -> Node:
	var actors := world_root.find_child(ACTORS_NAME, true, false)
	return actors if actors != null else world_root
