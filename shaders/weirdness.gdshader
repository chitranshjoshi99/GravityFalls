// The weirdness grade — Doc 01 §2.
//
// One float drives the entire supernatural visual axis. Doc 02 raises it on
// anomaly proximity, Doc 03 sets a floor per zone, Doc 05 keys the audio
// crossfade to the same value. Weirdmageddon is a parameter change, not a
// re-authored world.
//
// hint_screen_texture costs a full-screen backbuffer copy every frame — the
// single largest per-frame cost this design introduces. Doc 01 §2 skips it by
// hiding the grade below level 0.06; that skip lives on the grade ColorRect
// (tracker row 2.2), not here.

shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

uniform float weirdness : hint_range(0.0, 1.0) = 0.0;
uniform vec3  tint_hot  : source_color = vec3(1.000, 0.824, 0.247); // bill_yellow
uniform vec3  tint_cold : source_color = vec3(1.000, 0.247, 0.643); // portal_pink
// Stays a uniform: Doc 04 §5.1's reduce_flashing toggle clamps it (row 0.7).
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
