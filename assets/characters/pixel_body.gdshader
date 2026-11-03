shader_type spatial;
render_mode specular_disabled, cull_disabled;

// The picture of a pixel-art body (PixelRig), lit like the painted buildings (sprite_surface.gdshader):
// part of its colour shows as drawn by day, part is shaped by the town's light and shadow, and at night
// the drawn part cools to moonlight. Otherwise a body in the shade went much darker than the walls.
uniform sampler2D tex : source_color, filter_nearest;
uniform float lit_share = 0.5;
uniform float own_light = 0.85;
uniform vec3 night_tint : source_color = vec3(0.55, 0.66, 0.95);
uniform vec4 tint : source_color = vec4(1.0);  // Pallor, the servant's grey, the night shade
uniform float fade = 0.0;                       // See-through (hiding): every other pixel left out
global uniform float sprite_daylight;

void fragment() {
	vec4 c = texture(tex, UV);
	if (c.a < 0.5) {
		discard;
	}
	if (fade > 0.25) {
		ivec2 p = ivec2(FRAGCOORD.xy / 2.0);
		if ((p.x + p.y) % 2 == 0) {
			discard;
		}
	}
	vec3 col = c.rgb * tint.rgb;
	ALBEDO = col * lit_share;
	vec3 moon = mix(night_tint, vec3(1.0), smoothstep(0.12, 0.8, sprite_daylight));
	EMISSION = col * own_light * sprite_daylight * moon;
	ROUGHNESS = 1.0;
}
