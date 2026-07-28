class_name RuntimeEvent
extends RefCounted
## One queued request — Doc 00 §2.5. A record and nothing more: the queue owns
## its lifetime, RuntimeDirector owns what it means.
##
## The enum's order and grouping are authored, not incidental. Doc 00 §4.2's
## priority ladder and every later resolver arm are written against these names,
## so a rename or a reorder is a silent breakage rather than a compile error.

enum Type {
	# --- lifecycle & travel ------------------------------------------------
	ZONE_ACTIVATION_REQUEST,   # seamless: activation volume crossed
	GATED_ZONE_REQUEST,        # gated: boundary entered, fade required
	SEAM_FALLBACK_REQUEST,     # Doc 3 §3.3 grace wipe — loader lost the race
	RESPAWN_REQUEST,           # blackout complete, return at checkpoint
	CHAPTER_ADVANCE_REQUEST,   # §9.4

	# --- forced ------------------------------------------------------------
	LETHAL_DAMAGE,
	DAMAGE,
	CUTSCENE_REQUEST,

	# --- player intents ----------------------------------------------------
	PAUSE_REQUEST,
	DODGE_REQUEST,
	VEHICLE_BOARD_REQUEST,
	VEHICLE_EXIT_REQUEST,
	ATTACK_REQUEST,
	ITEM_USE_REQUEST,
	ITEM_SELECT_REQUEST,       # radial commit, Doc 4 §6.3
	JOURNAL_TOGGLE_REQUEST,
	JOURNAL_SUBMIT_REQUEST,    # player text: a weakness or a cipher answer (§8.3)
	UV_TOGGLE_REQUEST,
	INTERACT_REQUEST,

	# --- passive progression -----------------------------------------------
	CHECKPOINT_REACHED,
	ENCOUNTER_STATE_REQUEST,   # arm/clear a checkpoint's encounter block (§11.3)
	SECRET_REVEAL_REQUEST,
	ANOMALY_ENTERED,
	ANOMALY_EXITED,
}

var type: Type
var source: NodePath
var payload: Dictionary
var physics_frame: int
## Monotonic queue order within this physics tick. A deterministic tie-breaker
## within one type only — gameplay precedence comes from §4.2 and nothing else.
var order: int
