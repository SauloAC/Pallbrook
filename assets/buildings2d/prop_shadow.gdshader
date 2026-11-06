shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

// The shadow a piece of furniture casts on the floor, down and right of it (its footprint, from
// art_source/tools/furniture/finish.py): a soft dark purple laid over the boards, as the references
// draw theirs. Lies flat just over the floor (art_source/tools/b2d/scene.py).
uniform sampler2D tex : filter_nearest;
uniform vec4 tint : source_color = vec4(0.12, 0.03, 0.1, 0.32);

void fragment() {
	ALBEDO = tint.rgb;
	ALPHA = texture(tex, UV).a * tint.a;
}
