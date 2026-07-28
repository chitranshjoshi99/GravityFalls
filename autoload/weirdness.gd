extends Node
## The single supernatural-intensity float — Doc 01 §2.1.
##
## Presentation state, and the one system with no resolver requirement. Any
## system may call pulse() / release() directly from anywhere: it already
## clamps, already tweens, already reconciles floor against event, and nothing
## it holds can corrupt a save or desync gameplay. set_zone_floor() is the
## exception — that one belongs to ZoneManager.activate_zone() alone
## (Doc 00 §7.2), because it is part of the zone commit. PaletteRegion applies
## colours only and must never touch the grade, or a streamed neighbour's
## _ready() would change the grade of the zone you are standing in.

signal level_changed(value: float)

const DEFAULT_FADE := 1.2

var _zone_floor: float = 0.0
var _event_level: float = 0.0
var _mat: ShaderMaterial
var _tween: Tween

## Where the tween is HEADED — the stronger of the zone baseline and any active
## event. This is a target, not a value anything should render or mix against.
var target_level: float:
	get: return maxf(_zone_floor, _event_level)

## Where the tween IS. THIS is the number every system reads: the shader, the
## audio stems, the bus sends, the whisper gain, everything. Set only in _apply().
##
## The distinction is load-bearing. `target_level` snaps the instant a pulse is
## requested; `applied` eases toward it over the tween's duration. If visuals
## follow the smooth one and audio reads the snapped one, "one float runs the
## supernatural" quietly becomes two floats on two curves — most visibly out of
## step at exactly the authored moments that matter. One writer, one value, one
## curve. Doc 00 §12 check 36 is what keeps it that way.
var applied: float = 0.0


## Bound to the one grade ColorRect by SessionDirector.begin_session()
## (Doc 00 §3.2). Applies immediately so a freshly bound material is never a
## frame stale.
func bind(mat: ShaderMaterial) -> void:
	_mat = mat
	_apply(target_level)


## ZoneManager.activate_zone() only. Persistent until the next zone.
func set_zone_floor(value: float, duration: float = DEFAULT_FADE) -> void:
	_zone_floor = clampf(value, 0.0, 1.0)
	_retween(duration)


## Anomalies, boss phases, cutscenes. Decays back to the zone floor.
func pulse(value: float, duration: float = 0.4) -> void:
	_event_level = clampf(value, 0.0, 1.0)
	_retween(duration)


func release(duration: float = DEFAULT_FADE) -> void:
	_event_level = 0.0
	_retween(duration)


## Killing the running tween first is what guarantees exactly one writer of
## `applied` in any frame — a pulse landing mid-tween must replace the curve,
## never race it.
func _retween(duration: float) -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_apply, applied, target_level, duration)


func _apply(v: float) -> void:
	applied = v
	if _mat:
		_mat.set_shader_parameter("weirdness", v)
	level_changed.emit(v)
