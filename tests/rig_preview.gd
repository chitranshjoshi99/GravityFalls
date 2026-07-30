extends Node2D
##
## Row 1.1's VISUAL gate, and the other half of row 0.1's.
##
## Row 0.1 deferred "window opens at true 16:9 on a 16:10 panel — letterboxed,
## not stretched" to 1.1, because a letterbox is only visible when something is
## drawn inside it and no scene existed yet. `rig_humanoid.tscn` is that
## something, so both observations are made from this one fixture:
##
##   1. LETTERBOX — run windowed at a 16:10 size and look at the window. At
##      1440x900 the canvas must scale by min(1440/1920, 900/1080) = 0.75 and
##      render 1440x810, leaving 45 px bars top and bottom in the window's clear
##      colour. The background here is deliberately NOT that clear colour, so the
##      bars are unambiguous in a capture.
##   2. SILHOUETTE — the rig, in its §9.2 placeholder fills, must read as a
##      humanoid: head above torso, two arms, two legs, feet on the ground line,
##      eyes on the face. Every numeric check in the suite can pass with a limb
##      parked at the origin or a head at the feet; only an eye catches that.
##
## Not a test and never run by `test_all.gd` — it needs a window, and the suite
## is headless. Run it by hand:
##
##     godot --path <project> --resolution 1440x900 res://tests/rig_preview.tscn
##
## `tests/` is in the export preset's exclude_filter, so nothing here ships.
##
## ponytail: no framework, no reusable screenshot harness, no CLI flags — two
## environment variables and a frame counter. It is run by a human roughly once
## per rig change. Build the harness the day a THIRD row needs a capture.

## Where to write the in-engine capture. Empty (the default) skips it. This is
## the 1920x1080 canvas ONLY — the letterbox bars are outside the canvas by
## definition, so this PNG proves observation 2 and says nothing about 1.
const OUT_ENV := "RIG_PREVIEW_PNG"

## Seconds to keep the window up after capturing, so an external window grab
## (`screencapture` on macOS) has something to grab. Default 0 — quit at once.
const HOLD_ENV := "RIG_PREVIEW_HOLD"

## Frame to capture on. Frame 0 is the clear colour before anything has drawn.
const CAPTURE_FRAME := 4

var _frames := 0
var _captured := false


func _ready() -> void:
	_report()


func _process(_delta: float) -> void:
	_frames += 1
	if _frames < CAPTURE_FRAME or _captured:
		return
	_captured = true
	# Frame 1 is measured too: `_ready()` runs before the window has been resized
	# to `--resolution`, and the stretch transform is only final once it has.
	_report()
	var out := OS.get_environment(OUT_ENV)
	if out != "":
		var image := get_viewport().get_texture().get_image()
		var err := image.save_png(out)
		print("rig_preview: canvas capture %dx%d -> %s (err %d)"
			% [image.get_width(), image.get_height(), out, err])
	else:
		print("rig_preview: %s unset, no in-engine capture" % OUT_ENV)
	var hold := float(OS.get_environment(HOLD_ENV))
	if hold > 0.0:
		print("rig_preview: holding the window open for %.1f s" % hold)
		await get_tree().create_timer(hold).timeout
	get_tree().quit()


## The numbers behind observation 1, so it is not purely a matter of eyeballing
## a PNG. At 1440x900 against project.godot's locked 1920x1080 / canvas_items /
## keep, the final transform must be a uniform 0.75 with origin (0, 45).
func _report() -> void:
	var window := get_window()
	var final := window.get_final_transform()
	print("rig_preview: --- frame %d ---" % _frames)
	print("  DisplayServer.window_get_size  = %s" % DisplayServer.window_get_size())
	print("  Window.size                    = %s" % window.size)
	print("  Window.content_scale_size      = %s" % window.content_scale_size)
	print("  Window.content_scale_mode      = %d (1 = CANVAS_ITEMS)" % window.content_scale_mode)
	print("  Window.content_scale_aspect    = %d (1 = KEEP)" % window.content_scale_aspect)
	print("  Window.content_scale_factor    = %s" % window.content_scale_factor)
	print("  Viewport.get_visible_rect      = %s" % get_viewport().get_visible_rect())
	print("  Window.get_final_transform     = %s" % final)
	print("  Viewport.get_screen_transform  = %s" % get_viewport().get_screen_transform())
	print("  -> scale %s  offset %s" % [final.get_scale(), final.origin])
	print("  DisplayServer.window_get_position = %s" % DisplayServer.window_get_position())
